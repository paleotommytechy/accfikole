-- ACCF Ikole production-safe security hardening
--
-- IMPORTANT:
--   * This migration is additive and does not delete production rows.
--   * Apply it only after 002_tasks_and_roles.sql passes against the live schema.
--   * A duplicate reward record aborts the migration rather than silently
--     deleting or rewriting production history.

create or replace function public.accf_current_user_has_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role::text = any (allowed_roles)
  );
$$;

revoke all on function public.accf_current_user_has_role(text[]) from public;
grant execute on function public.accf_current_user_has_role(text[]) to authenticated;

do $$
begin
  if exists (
    select 1
    from public.coin_transactions
    where source_id is not null
    group by user_id, source_type, source_id
    having count(*) > 1
  ) then
    raise exception
      'Duplicate coin reward records exist. Reconcile them manually before adding the idempotency index; no rows were changed.';
  end if;
end
$$;

create unique index if not exists coin_transactions_user_source_unique
  on public.coin_transactions (user_id, source_type, source_id)
  where source_id is not null;

create or replace function public.accf_bootstrap_current_user(
  p_email text,
  p_full_name text default null,
  p_avatar_url text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    v_user_id,
    coalesce(nullif(trim(p_email), ''), (select email from auth.users where id = v_user_id)),
    nullif(trim(coalesce(p_full_name, '')), ''),
    nullif(trim(coalesce(p_avatar_url, '')), '')
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role)
  values (v_user_id, 'member')
  on conflict (user_id) do nothing;

  insert into public.onboarding_progress (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;
end
$$;

revoke all on function public.accf_bootstrap_current_user(text, text, text) from public;
grant execute on function public.accf_bootstrap_current_user(text, text, text) to authenticated;

create or replace function public.accf_claim_onboarding_reward(p_action text)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_eligible boolean := false;
  v_inserted_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  insert into public.onboarding_progress (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  if p_action = 'profile_completion' then
    select exists (
      select 1
      from public.profiles p
      where p.id = v_user_id
        and nullif(trim(coalesce(p.full_name, '')), '') is not null
        and nullif(trim(coalesce(p.department, '')), '') is not null
        and nullif(trim(coalesce(p.whatsapp, '')), '') is not null
    ) into v_eligible;

    if v_eligible then
      update public.onboarding_progress
      set completed_profile = true
      where user_id = v_user_id;
    end if;
  elsif p_action = 'first_rsvp' then
    select exists (
      select 1 from public.event_rsvps er where er.user_id = v_user_id
    ) into v_eligible;

    if v_eligible then
      update public.onboarding_progress
      set rsvpd_to_event = true
      where user_id = v_user_id;
    end if;
  elsif p_action = 'first_message' then
    select exists (
      select 1 from public.messages m where m.sender_id = v_user_id
    ) into v_eligible;

    if v_eligible then
      update public.onboarding_progress
      set sent_first_message = true
      where user_id = v_user_id;
    end if;
  else
    raise exception 'Unsupported onboarding reward action';
  end if;

  if not v_eligible then
    raise exception 'Onboarding reward requirements are not satisfied';
  end if;

  insert into public.coin_transactions (
    user_id, source_type, source_id, coin_amount, status, reason
  )
  values (
    v_user_id, 'onboarding', p_action, 25, 'pending',
    case p_action
      when 'profile_completion' then 'Completed profile'
      when 'first_rsvp' then 'First event RSVP'
      else 'Sent first message'
    end
  )
  on conflict (user_id, source_type, source_id)
    where source_id is not null
  do nothing;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count > 0;
end
$$;

revoke all on function public.accf_claim_onboarding_reward(text) from public;
grant execute on function public.accf_claim_onboarding_reward(text) to authenticated;

create or replace function public.accf_set_task_completion(
  p_assignment_id uuid,
  p_complete boolean
)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_task_id uuid;
  v_reward integer;
  v_inserted_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select ta.task_id, coalesce(t.coin_reward, 0)
  into v_task_id, v_reward
  from public.tasks_assignments ta
  join public.tasks t on t.id = ta.task_id
  where ta.id = p_assignment_id
    and ta.assignee_id = v_user_id
  for update of ta;

  if v_task_id is null then
    raise exception 'Task assignment not found for current user';
  end if;

  update public.tasks_assignments
  set status = case when p_complete then 'done' else 'assigned' end,
      completed_at = case when p_complete then now() else null end
  where id = p_assignment_id
    and assignee_id = v_user_id;

  if p_complete and v_reward > 0 then
    insert into public.coin_transactions (
      user_id, source_type, source_id, coin_amount, status, reason
    )
    values (
      v_user_id, 'task', v_task_id::text, v_reward, 'pending', 'Completed task'
    )
    on conflict (user_id, source_type, source_id)
      where source_id is not null
    do nothing;
    get diagnostics v_inserted = row_count;
  end if;

  return v_inserted;
end
$$;

revoke all on function public.accf_set_task_completion(uuid, boolean) from public;
grant execute on function public.accf_set_task_completion(uuid, boolean) to authenticated;

create or replace function public.accf_complete_weekly_challenge(p_challenge_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_reward integer;
  v_has_quiz boolean;
  v_inserted_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select coalesce(wc.coin_reward, 0), coalesce(wc.has_quiz, false)
  into v_reward, v_has_quiz
  from public.weekly_challenges wc
  where wc.id = p_challenge_id;

  if not found then
    raise exception 'Weekly challenge not found';
  end if;

  if v_has_quiz then
    raise exception 'This challenge must be completed through its quiz';
  end if;

  update public.weekly_participants
  set progress = 100
  where challenge_id = p_challenge_id
    and user_id = v_user_id;

  if not found then
    raise exception 'Join the challenge before completing it';
  end if;

  if v_reward > 0 then
    insert into public.coin_transactions (
      user_id, source_type, source_id, coin_amount, status, reason
    )
    values (
      v_user_id, 'challenge', p_challenge_id::text, v_reward, 'pending', 'Completed weekly challenge'
    )
    on conflict (user_id, source_type, source_id)
      where source_id is not null
    do nothing;
    get diagnostics v_inserted = row_count;
  end if;

  return v_inserted;
end
$$;

revoke all on function public.accf_complete_weekly_challenge(uuid) from public;
grant execute on function public.accf_complete_weekly_challenge(uuid) to authenticated;

create or replace function public.accf_submit_weekly_quiz(
  p_quiz_id uuid,
  p_question_ids uuid[],
  p_answers integer[]
)
returns table(score integer, passed boolean)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_challenge_id uuid;
  v_threshold integer;
  v_quiz_reward integer;
  v_challenge_reward integer;
  v_total integer;
  v_score integer;
  v_passed boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if cardinality(p_question_ids) is distinct from cardinality(p_answers)
     or coalesce(cardinality(p_question_ids), 0) = 0 then
    raise exception 'Invalid quiz submission';
  end if;

  select q.challenge_id, q.pass_threshold, coalesce(q.coin_reward, 0), coalesce(wc.coin_reward, 0)
  into v_challenge_id, v_threshold, v_quiz_reward, v_challenge_reward
  from public.quizzes q
  join public.weekly_challenges wc on wc.id = q.challenge_id
  where q.id = p_quiz_id;

  if not found then
    raise exception 'Quiz not found';
  end if;

  if not exists (
    select 1
    from public.weekly_participants wp
    where wp.challenge_id = v_challenge_id and wp.user_id = v_user_id
  ) then
    raise exception 'Join the challenge before taking its quiz';
  end if;

  select count(*)::integer
  into v_total
  from public.quiz_questions qq
  where qq.quiz_id = p_quiz_id;

  if v_total <> cardinality(p_question_ids)
     or v_total <> (
       select count(distinct q.question_id)::integer
       from unnest(p_question_ids) as q(question_id)
     ) then
    raise exception 'Quiz submission does not match the current question set';
  end if;

  select count(*) filter (where qq.correct_option_index = submitted.answer_index)::integer
  into v_score
  from unnest(p_question_ids, p_answers) as submitted(question_id, answer_index)
  join public.quiz_questions qq
    on qq.id = submitted.question_id
   and qq.quiz_id = p_quiz_id;

  v_passed := v_score >= v_threshold;

  insert into public.quiz_attempts (user_id, quiz_id, score, passed)
  values (v_user_id, p_quiz_id, v_score, v_passed)
  on conflict (user_id, quiz_id)
  do update set score = excluded.score, passed = excluded.passed;

  if v_passed then
    update public.weekly_participants
    set progress = 100
    where challenge_id = v_challenge_id and user_id = v_user_id;

    if v_quiz_reward > 0 then
      insert into public.coin_transactions (
        user_id, source_type, source_id, coin_amount, status, reason
      )
      values (
        v_user_id, 'quiz', p_quiz_id::text, v_quiz_reward, 'pending', 'Passed weekly challenge quiz'
      )
      on conflict (user_id, source_type, source_id)
        where source_id is not null
      do nothing;
    end if;

    if v_challenge_reward > 0 then
      insert into public.coin_transactions (
        user_id, source_type, source_id, coin_amount, status, reason
      )
      values (
        v_user_id, 'challenge', v_challenge_id::text, v_challenge_reward, 'pending', 'Completed weekly challenge'
      )
      on conflict (user_id, source_type, source_id)
        where source_id is not null
      do nothing;
    end if;
  end if;

  return query select v_score, v_passed;
end
$$;

revoke all on function public.accf_submit_weekly_quiz(uuid, uuid[], integer[]) from public;
grant execute on function public.accf_submit_weekly_quiz(uuid, uuid[], integer[]) to authenticated;

create or replace function public.accf_submit_material_quiz(
  p_quiz_id uuid,
  p_question_ids uuid[],
  p_answers integer[]
)
returns table(score integer, total_questions integer, perfect boolean)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_total integer;
  v_score integer;
  v_tx_id bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if cardinality(p_question_ids) is distinct from cardinality(p_answers)
     or coalesce(cardinality(p_question_ids), 0) = 0 then
    raise exception 'Invalid quiz submission';
  end if;

  if not exists (select 1 from public.material_quizzes mq where mq.id = p_quiz_id) then
    raise exception 'Material quiz not found';
  end if;

  select count(*)::integer
  into v_total
  from public.material_quiz_questions mqq
  where mqq.quiz_id = p_quiz_id;

  if v_total <> cardinality(p_question_ids)
     or v_total <> (
       select count(distinct question_id)::integer
       from unnest(p_question_ids) as question_id
     ) then
    raise exception 'Quiz submission does not match the current question set';
  end if;

  select count(*) filter (where mqq.correct_option_index = submitted.answer_index)::integer
  into v_score
  from unnest(p_question_ids, p_answers) as submitted(question_id, answer_index)
  join public.material_quiz_questions mqq
    on mqq.id = submitted.question_id
   and mqq.quiz_id = p_quiz_id;

  insert into public.material_quiz_attempts (quiz_id, user_id, score, total_questions)
  values (p_quiz_id, v_user_id, v_score, v_total);

  if v_score = v_total and v_total > 0 then
    insert into public.coin_transactions (
      user_id, source_type, source_id, coin_amount, status, reason
    )
    values (
      v_user_id, 'quiz', 'material:' || p_quiz_id::text, 10, 'approved', 'Perfect material quiz score'
    )
    on conflict (user_id, source_type, source_id)
      where source_id is not null
    do nothing
    returning id into v_tx_id;

    if v_tx_id is not null then
      update public.profiles
      set coins = coalesce(coins, 0) + 10
      where id = v_user_id;
    end if;
  end if;

  return query select v_score, v_total, (v_score = v_total and v_total > 0);
end
$$;

revoke all on function public.accf_submit_material_quiz(uuid, uuid[], integer[]) from public;
grant execute on function public.accf_submit_material_quiz(uuid, uuid[], integer[]) to authenticated;

create or replace function public.accf_claim_focus_material_reward(p_material_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_title text;
  v_inserted_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select ucm.title
  into v_title
  from public.user_course_materials ucm
  where ucm.id = p_material_id
    and ucm.status = 'approved';

  if not found then
    raise exception 'Approved study material not found';
  end if;

  insert into public.coin_transactions (
    user_id, source_type, source_id, coin_amount, status, reason
  )
  values (
    v_user_id, 'task', 'focus:' || p_material_id::text, 10, 'pending', 'Focus Session: ' || v_title
  )
  on conflict (user_id, source_type, source_id)
    where source_id is not null
  do nothing;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count > 0;
end
$$;

revoke all on function public.accf_claim_focus_material_reward(uuid) from public;
grant execute on function public.accf_claim_focus_material_reward(uuid) to authenticated;

create or replace function public.accf_approve_coin_transaction(p_transaction_id bigint)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_tx record;
begin
  if not public.accf_current_user_has_role(array['admin']) then
    raise exception 'Admin role required';
  end if;

  select *
  into v_tx
  from public.coin_transactions
  where id = p_transaction_id
  for update;

  if not found then
    raise exception 'Coin transaction not found';
  end if;

  if v_tx.status = 'approved' then
    return;
  end if;

  if v_tx.status <> 'pending' then
    raise exception 'Only pending transactions can be approved';
  end if;

  update public.coin_transactions
  set status = 'approved'
  where id = p_transaction_id;

  update public.profiles
  set coins = coalesce(coins, 0) + v_tx.coin_amount
  where id = v_tx.user_id;

  insert into public.notifications (user_id, type, message, link)
  values (
    v_tx.user_id,
    'coin_approved',
    'Your coin reward was approved.',
    '/tasks'
  );
end
$$;

revoke all on function public.accf_approve_coin_transaction(bigint) from public;
grant execute on function public.accf_approve_coin_transaction(bigint) to authenticated;

create or replace function public.accf_assign_task_to_all_users(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  user_record record;
  task_record record;
begin
  if not public.accf_current_user_has_role(array['admin']) then
    raise exception 'Admin role required';
  end if;

  select * into task_record from public.tasks where id = p_task_id;
  if not found then
    raise exception 'Task not found';
  end if;

  for user_record in
    select u.id, ur.role::text as role
    from auth.users u
    left join public.user_roles ur on u.id = ur.user_id
  loop
    if not exists (
      select 1
      from public.tasks_assignments ta
      where ta.assignee_id = user_record.id
        and ta.task_id = p_task_id
        and ta.created_at >= date_trunc('day', now())
        and ta.created_at < date_trunc('day', now()) + interval '1 day'
    ) then
      insert into public.tasks_assignments (task_id, assignee_id, status)
      values (p_task_id, user_record.id, 'assigned');

      if user_record.role is distinct from 'admin' then
        insert into public.notifications (user_id, type, message, link)
        values (
          user_record.id,
          'task_assigned',
          'Your daily task "' || task_record.title || '" has been assigned.',
          '/tasks'
        );
      end if;
    end if;
  end loop;
end
$$;

revoke all on function public.accf_assign_task_to_all_users(uuid) from public;
grant execute on function public.accf_assign_task_to_all_users(uuid) to authenticated;

-- Block direct browser writes to reward ledgers. Trusted SECURITY DEFINER RPCs
-- above remain able to write as their function owner.
revoke insert, update, delete on public.coin_transactions from anon, authenticated;
revoke insert, update on public.quiz_attempts from anon, authenticated;
revoke insert, update on public.material_quiz_attempts from anon, authenticated;

-- Remove public/authenticated access to legacy privileged functions by name,
-- regardless of their historical overload signatures. Clients are migrated to
-- the accf_* replacements in this change.
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('approve_coin_transaction', 'assign_task_to_all_users', 'increment_coins')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn.signature);
  end loop;
end
$$;
