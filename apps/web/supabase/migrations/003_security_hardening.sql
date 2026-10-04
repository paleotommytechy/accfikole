-- ACCF Ikole production-safe security hardening
--
-- This migration was aligned against the live ACCF production schema on
-- 2026-10-04. It is intentionally backward compatible with the existing
-- accfikolewebsite-dashboard RPC signatures while introducing safer accf_*
-- RPCs for the Turborepo Prototype.
--
-- It does NOT delete or rewrite existing production rows.

-- Future rewards created by the hardened RPCs use an accf:* idempotency key.
-- Historical rows are intentionally excluded because production already
-- contains a legacy duplicate reward that requires a separate business review.
create unique index if not exists coin_transactions_accf_reward_unique
  on public.coin_transactions (user_id, source_type, source_id)
  where source_id like 'accf:%';

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
      and ur.role = any (allowed_roles)
  );
$$;

revoke all on function public.accf_current_user_has_role(text[]) from public, anon, authenticated;

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
    coalesce(nullif(trim(p_email), ''), (select u.email from auth.users u where u.id = v_user_id)),
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

revoke all on function public.accf_bootstrap_current_user(text, text, text) from public, anon;
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
  v_source_id text;
  v_tx_id bigint;
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

  v_source_id := 'accf:onboarding:' || p_action;

  insert into public.coin_transactions (
    user_id, source_type, source_id, coin_amount, status, reason
  )
  values (
    v_user_id, 'onboarding', v_source_id, 25, 'pending',
    case p_action
      when 'profile_completion' then 'Completed profile'
      when 'first_rsvp' then 'First event RSVP'
      else 'Sent first message'
    end
  )
  on conflict (user_id, source_type, source_id)
    where source_id like 'accf:%'
  do nothing
  returning id into v_tx_id;

  return v_tx_id is not null;
end
$$;

revoke all on function public.accf_claim_onboarding_reward(text) from public, anon;
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
  v_tx_id bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select ta.task_id, coalesce(t.coin_reward, 0)::integer
  into v_task_id, v_reward
  from public.tasks_assignments ta
  join public.tasks t on t.id = ta.task_id
  where ta.id = p_assignment_id
    and ta.assignee_id = v_user_id
  for update of ta;

  if not found then
    raise exception 'Task assignment not found for current user';
  end if;

  update public.tasks_assignments
  set status = case when p_complete then 'done'::assignment_status else 'assigned'::assignment_status end,
      completed_at = case when p_complete then now() else null end
  where id = p_assignment_id
    and assignee_id = v_user_id;

  if p_complete and v_reward > 0 then
    insert into public.coin_transactions (
      user_id, source_type, source_id, coin_amount, status, reason
    )
    values (
      v_user_id,
      'task',
      'accf:task-assignment:' || p_assignment_id::text,
      v_reward,
      'pending',
      'Completed task'
    )
    on conflict (user_id, source_type, source_id)
      where source_id like 'accf:%'
    do nothing
    returning id into v_tx_id;
  end if;

  return v_tx_id is not null;
end
$$;

revoke all on function public.accf_set_task_completion(uuid, boolean) from public, anon;
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
  v_tx_id bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select coalesce(wc.coin_reward, 0)::integer, coalesce(wc.has_quiz, false)
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
      v_user_id,
      'challenge',
      'accf:challenge:' || p_challenge_id::text,
      v_reward,
      'pending',
      'Completed weekly challenge'
    )
    on conflict (user_id, source_type, source_id)
      where source_id like 'accf:%'
    do nothing
    returning id into v_tx_id;
  end if;

  return v_tx_id is not null;
end
$$;

revoke all on function public.accf_complete_weekly_challenge(uuid) from public, anon;
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

  select q.challenge_id, q.pass_threshold, coalesce(q.coin_reward, 0), coalesce(wc.coin_reward, 0)::integer
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
       select count(distinct submitted.question_id)::integer
       from unnest(p_question_ids) as submitted(question_id)
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
        v_user_id,
        'quiz',
        'accf:quiz:' || p_quiz_id::text,
        v_quiz_reward,
        'pending',
        'Passed weekly challenge quiz'
      )
      on conflict (user_id, source_type, source_id)
        where source_id like 'accf:%'
      do nothing;
    end if;

    if v_challenge_reward > 0 then
      insert into public.coin_transactions (
        user_id, source_type, source_id, coin_amount, status, reason
      )
      values (
        v_user_id,
        'challenge',
        'accf:challenge:' || v_challenge_id::text,
        v_challenge_reward,
        'pending',
        'Completed weekly challenge'
      )
      on conflict (user_id, source_type, source_id)
        where source_id like 'accf:%'
      do nothing;
    end if;
  end if;

  return query select v_score, v_passed;
end
$$;

revoke all on function public.accf_submit_weekly_quiz(uuid, uuid[], integer[]) from public, anon;
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
       select count(distinct submitted.question_id)::integer
       from unnest(p_question_ids) as submitted(question_id)
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
      v_user_id,
      'quiz',
      'accf:material-quiz:' || p_quiz_id::text,
      10,
      'approved',
      'Perfect material quiz score'
    )
    on conflict (user_id, source_type, source_id)
      where source_id like 'accf:%'
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

revoke all on function public.accf_submit_material_quiz(uuid, uuid[], integer[]) from public, anon;
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
  v_tx_id bigint;
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
    v_user_id,
    'task',
    'accf:focus:' || p_material_id::text,
    10,
    'pending',
    'Focus Session: ' || v_title
  )
  on conflict (user_id, source_type, source_id)
    where source_id like 'accf:%'
  do nothing
  returning id into v_tx_id;

  return v_tx_id is not null;
end
$$;

revoke all on function public.accf_claim_focus_material_reward(uuid) from public, anon;
grant execute on function public.accf_claim_focus_material_reward(uuid) to authenticated;

create or replace function public.accf_approve_coin_transaction(p_transaction_id bigint)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_tx public.coin_transactions%rowtype;
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
    '/store'
  );
end
$$;

revoke all on function public.accf_approve_coin_transaction(bigint) from public, anon;
grant execute on function public.accf_approve_coin_transaction(bigint) to authenticated;

create or replace function public.accf_reject_coin_transaction(p_transaction_id bigint)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.accf_current_user_has_role(array['admin']) then
    raise exception 'Admin role required';
  end if;

  update public.coin_transactions
  set status = 'rejected'
  where id = p_transaction_id
    and status = 'pending';

  if not found then
    raise exception 'Pending coin transaction not found';
  end if;
end
$$;

revoke all on function public.accf_reject_coin_transaction(bigint) from public, anon;
grant execute on function public.accf_reject_coin_transaction(bigint) to authenticated;

create or replace function public.accf_assign_task_to_all_users(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user record;
  v_task public.tasks%rowtype;
begin
  if not public.accf_current_user_has_role(array['admin']) then
    raise exception 'Admin role required';
  end if;

  select * into v_task from public.tasks where id = p_task_id;
  if not found then
    raise exception 'Task not found';
  end if;

  for v_user in
    select u.id, ur.role
    from auth.users u
    left join public.user_roles ur on u.id = ur.user_id
  loop
    if not exists (
      select 1
      from public.tasks_assignments ta
      where ta.assignee_id = v_user.id
        and ta.task_id = p_task_id
        and ta.created_at >= date_trunc('day', now())
        and ta.created_at < date_trunc('day', now()) + interval '1 day'
    ) then
      insert into public.tasks_assignments (task_id, assignee_id, status)
      values (p_task_id, v_user.id, 'assigned');

      if v_user.role is distinct from 'admin' then
        insert into public.notifications (user_id, type, message, link)
        values (
          v_user.id,
          'task_assigned',
          'Your daily task "' || v_task.title || '" has been assigned.',
          '/tasks'
        );
      end if;
    end if;
  end loop;
end
$$;

revoke all on function public.accf_assign_task_to_all_users(uuid) from public, anon;
grant execute on function public.accf_assign_task_to_all_users(uuid) to authenticated;

create or replace function public.accf_update_current_user_streak()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_yesterday date := ((now() at time zone 'utc') - interval '1 day')::date;
  v_last date;
  v_total integer;
  v_completed integer;
  v_current integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select count(*)::integer
  into v_total
  from public.tasks_assignments ta
  join public.tasks t on t.id = ta.task_id
  where ta.assignee_id = v_user_id
    and t.frequency = 'daily'
    and (ta.created_at at time zone 'utc')::date = v_today;

  if v_total = 0 then
    return;
  end if;

  select count(*)::integer
  into v_completed
  from public.tasks_assignments ta
  join public.tasks t on t.id = ta.task_id
  where ta.assignee_id = v_user_id
    and t.frequency = 'daily'
    and (ta.created_at at time zone 'utc')::date = v_today
    and ta.status = 'done';

  if v_completed <> v_total then
    return;
  end if;

  select coalesce(current_streak, 0), last_streak_day
  into v_current, v_last
  from public.profiles
  where id = v_user_id
  for update;

  if not found or v_last = v_today then
    return;
  end if;

  v_current := case when v_last = v_yesterday then v_current + 1 else 1 end;

  update public.profiles
  set current_streak = v_current,
      longest_streak = greatest(coalesce(longest_streak, 0), v_current),
      last_streak_day = v_today
  where id = v_user_id;
end
$$;

revoke all on function public.accf_update_current_user_streak() from public, anon;
grant execute on function public.accf_update_current_user_streak() to authenticated;

create or replace function public.accf_update_user_role(
  p_target_user_id uuid,
  p_new_role text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.accf_current_user_has_role(array['admin']) then
    raise exception 'Admin role required';
  end if;

  if p_new_role not in ('member', 'admin', 'blog', 'media', 'academics', 'pro', 'finance') then
    raise exception 'Unsupported role';
  end if;

  insert into public.user_roles (user_id, role)
  values (p_target_user_id, p_new_role)
  on conflict (user_id) do update set role = excluded.role;
end
$$;

revoke all on function public.accf_update_user_role(uuid, text) from public, anon;
grant execute on function public.accf_update_user_role(uuid, text) to authenticated;

create or replace function public.accf_admin_adjust_coins(
  p_target_user_id uuid,
  p_amount integer,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_balance integer;
begin
  if not public.accf_current_user_has_role(array['admin']) then
    raise exception 'Admin role required';
  end if;

  if p_amount = 0 then
    raise exception 'Adjustment amount must not be zero';
  end if;

  select coalesce(coins, 0)
  into v_balance
  from public.profiles
  where id = p_target_user_id
  for update;

  if not found then
    raise exception 'Target profile not found';
  end if;

  if v_balance + p_amount < 0 then
    raise exception 'Adjustment would create a negative balance';
  end if;

  update public.profiles
  set coins = v_balance + p_amount
  where id = p_target_user_id;

  insert into public.coin_transactions (
    user_id, source_type, source_id, coin_amount, status, reason
  )
  values (
    p_target_user_id,
    'admin_adjustment',
    'accf:admin-adjustment:' || gen_random_uuid()::text,
    p_amount,
    'approved',
    nullif(trim(coalesce(p_reason, '')), '')
  );
end
$$;

revoke all on function public.accf_admin_adjust_coins(uuid, integer, text) from public, anon;
grant execute on function public.accf_admin_adjust_coins(uuid, integer, text) to authenticated;

create or replace function public.accf_delete_user_account(p_target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.accf_current_user_has_role(array['admin']) then
    raise exception 'Admin role required';
  end if;

  if p_target_user_id = auth.uid() then
    raise exception 'Administrators cannot delete their own account from this screen';
  end if;

  delete from auth.users where id = p_target_user_id;
  if not found then
    raise exception 'User account not found';
  end if;
end
$$;

revoke all on function public.accf_delete_user_account(uuid) from public, anon;
grant execute on function public.accf_delete_user_account(uuid) to authenticated;

create or replace function public.accf_update_donation_status(
  p_donation_id uuid,
  p_new_status text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_donation public.donations%rowtype;
  v_message text;
begin
  if not public.accf_current_user_has_role(array['admin', 'finance']) then
    raise exception 'Finance or admin role required';
  end if;

  select *
  into v_donation
  from public.donations
  where id = p_donation_id
  for update;

  if not found then
    raise exception 'Donation not found';
  end if;

  if p_new_status not in ('confirmed', 'rejected') then
    raise exception 'Unsupported donation status';
  end if;

  update public.donations
  set status = p_new_status,
      confirmed_at = case when p_new_status = 'confirmed' then now() else null end
  where id = p_donation_id;

  v_message := case
    when p_new_status = 'confirmed'
      then 'Your donation of ₦' || v_donation.amount::text || ' for "' || v_donation.fund_name || '" has been confirmed. Thank you so much for your generosity! God bless you.'
    else
      'There was an issue confirming your donation of ₦' || v_donation.amount::text || '. An admin will contact you shortly to clarify.'
  end;

  insert into public.notifications (user_id, type, message, link, metadata)
  values (
    v_donation.user_id,
    'custom',
    v_message,
    '/giving',
    jsonb_build_object('donationId', p_donation_id)
  );

  insert into public.messages (sender_id, recipient_id, text)
  values (auth.uid(), v_donation.user_id, v_message);
end
$$;

revoke all on function public.accf_update_donation_status(uuid, text) from public, anon;
grant execute on function public.accf_update_donation_status(uuid, text) to authenticated;

create or replace function public.accf_process_store_redemption(
  p_purchase_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_purchase public.user_store_purchases%rowtype;
  v_tx_id bigint;
begin
  if not public.accf_current_user_has_role(array['admin', 'finance']) then
    raise exception 'Finance or admin role required';
  end if;

  select *
  into v_purchase
  from public.user_store_purchases
  where id = p_purchase_id
  for update;

  if not found then
    raise exception 'Store purchase not found';
  end if;

  if v_purchase.status <> 'pending' then
    raise exception 'Store purchase has already been processed';
  end if;

  if p_status not in ('fulfilled', 'rejected') then
    raise exception 'Unsupported redemption status';
  end if;

  update public.user_store_purchases
  set status = p_status,
      processed_at = now()
  where id = p_purchase_id;

  if p_status = 'rejected' then
    insert into public.coin_transactions (
      user_id, source_type, source_id, coin_amount, status, reason
    )
    values (
      v_purchase.user_id,
      'admin_adjustment',
      'accf:store-refund:' || p_purchase_id::text,
      v_purchase.cost,
      'approved',
      'Refund for rejected store redemption'
    )
    on conflict (user_id, source_type, source_id)
      where source_id like 'accf:%'
    do nothing
    returning id into v_tx_id;

    if v_tx_id is not null then
      update public.profiles
      set coins = coalesce(coins, 0) + v_purchase.cost
      where id = v_purchase.user_id;
    end if;
  end if;

  insert into public.notifications (user_id, type, message, link)
  values (
    v_purchase.user_id,
    'custom',
    case when p_status = 'fulfilled'
      then 'Your store redemption has been fulfilled.'
      else 'Your store redemption was rejected and your coins were refunded.'
    end,
    '/store'
  );
end
$$;

revoke all on function public.accf_process_store_redemption(uuid, text) from public, anon;
grant execute on function public.accf_process_store_redemption(uuid, text) to authenticated;

create or replace function public.accf_approve_material_upload(p_material_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_material public.user_course_materials%rowtype;
  v_reward integer;
  v_tx_id bigint;
begin
  if not public.accf_current_user_has_role(array['admin', 'academics']) then
    raise exception 'Academics or admin role required';
  end if;

  select *
  into v_material
  from public.user_course_materials
  where id = p_material_id
  for update;

  if not found then
    raise exception 'Material upload not found';
  end if;

  if v_material.status = 'approved' then
    return;
  end if;

  v_reward := case when v_material.material_type = 'past_question' then 50 else 100 end;

  update public.user_course_materials
  set status = 'approved'
  where id = p_material_id;

  insert into public.coin_transactions (
    user_id, source_type, source_id, coin_amount, status, reason
  )
  values (
    v_material.uploader_id,
    'task',
    'accf:material-upload:' || p_material_id::text,
    v_reward,
    'approved',
    'Reward for uploading: ' || v_material.title
  )
  on conflict (user_id, source_type, source_id)
    where source_id like 'accf:%'
  do nothing
  returning id into v_tx_id;

  if v_tx_id is not null then
    update public.profiles
    set coins = coalesce(coins, 0) + v_reward
    where id = v_material.uploader_id;
  end if;

  insert into public.notifications (user_id, type, message, link)
  values (
    v_material.uploader_id,
    'coin_approved',
    'Your material "' || v_material.title || '" was approved! You earned ' || v_reward::text || ' coins.',
    '/academics'
  );
end
$$;

revoke all on function public.accf_approve_material_upload(uuid) from public, anon;
grant execute on function public.accf_approve_material_upload(uuid) to authenticated;

create or replace function public.accf_purchase_store_item(
  p_item_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_item public.store_items%rowtype;
  v_balance integer;
  v_purchase_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_item
  from public.store_items
  where id = p_item_id
    and coalesce(is_active, true);

  if not found then
    raise exception 'Store item not found or inactive';
  end if;

  if v_item.cost is null or v_item.cost <= 0 then
    raise exception 'Store item cost is not configured';
  end if;

  select coalesce(coins, 0)
  into v_balance
  from public.profiles
  where id = v_user_id
  for update;

  if not found then
    raise exception 'Profile not found';
  end if;

  if v_balance < v_item.cost then
    raise exception 'Insufficient coins';
  end if;

  update public.profiles
  set coins = v_balance - v_item.cost
  where id = v_user_id;

  insert into public.user_store_purchases (
    user_id, item_id, item_name, cost, status, purchase_metadata
  )
  values (
    v_user_id, p_item_id, v_item.name, v_item.cost, 'pending', coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_purchase_id;

  insert into public.coin_transactions (
    user_id, source_type, source_id, coin_amount, status, reason
  )
  values (
    v_user_id,
    'store_purchase',
    'accf:store-purchase:' || v_purchase_id::text,
    -v_item.cost,
    'approved',
    'Purchased ' || v_item.name
  );

  return v_purchase_id;
end
$$;

revoke all on function public.accf_purchase_store_item(uuid, jsonb) from public, anon;
grant execute on function public.accf_purchase_store_item(uuid, jsonb) to authenticated;

-- Keep the production dashboard's existing RPC signatures working, but make
-- them delegate to the hardened implementations and ignore caller-controlled
-- identity/reward parameters.

create or replace function public.approve_coin_transaction(p_transaction_id bigint)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.accf_approve_coin_transaction(p_transaction_id);
end
$$;

create or replace function public.assign_task_to_all_users(task_id_to_assign uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.accf_assign_task_to_all_users(task_id_to_assign);
end
$$;

create or replace function public.update_user_streak(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if p_user_id is distinct from auth.uid() then
    raise exception 'Users may update only their own streak';
  end if;
  perform public.accf_update_current_user_streak();
end
$$;

create or replace function public.update_user_role(target_user_id uuid, new_role text)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.accf_update_user_role(target_user_id, new_role);
end
$$;

create or replace function public.admin_adjust_coins(target_user_id uuid, amount integer, reason text)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.accf_admin_adjust_coins(target_user_id, amount, reason);
end
$$;

create or replace function public.delete_user_account(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.accf_delete_user_account(target_user_id);
end
$$;

create or replace function public.update_donation_status(
  p_donation_id uuid,
  p_new_status text,
  p_admin_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if p_admin_id is distinct from auth.uid() then
    raise exception 'Caller identity mismatch';
  end if;
  perform public.accf_update_donation_status(p_donation_id, p_new_status);
end
$$;

create or replace function public.process_store_redemption(
  p_purchase_id uuid,
  p_status text,
  p_admin_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if p_admin_id is distinct from auth.uid() then
    raise exception 'Caller identity mismatch';
  end if;
  perform public.accf_process_store_redemption(p_purchase_id, p_status);
end
$$;

create or replace function public.approve_material_upload(
  p_material_id uuid,
  p_admin_id uuid,
  p_coin_reward integer
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if p_admin_id is distinct from auth.uid() then
    raise exception 'Caller identity mismatch';
  end if;
  -- p_coin_reward is intentionally ignored; the reward is derived server-side.
  perform public.accf_approve_material_upload(p_material_id);
end
$$;

create or replace function public.purchase_store_item(
  p_item_id uuid,
  p_user_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if p_user_id is distinct from auth.uid() then
    raise exception 'Users may purchase only for themselves';
  end if;
  perform public.accf_purchase_store_item(p_item_id, p_metadata);
end
$$;

-- Harden the auth bootstrap trigger that already exists in production.
create or replace function public.handle_new_user_setup()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, 'member')
  on conflict (user_id) do nothing;

  insert into public.onboarding_progress (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end
$$;

revoke all on function public.handle_new_user_setup() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;

-- Existing dashboard clients call these legacy RPCs as authenticated users.
-- Anonymous/PUBLIC execution is removed, while authenticated execution remains.
revoke all on function public.approve_coin_transaction(bigint) from public, anon;
grant execute on function public.approve_coin_transaction(bigint) to authenticated;

revoke all on function public.assign_task_to_all_users(uuid) from public, anon;
grant execute on function public.assign_task_to_all_users(uuid) to authenticated;

revoke all on function public.update_user_streak(uuid) from public, anon;
grant execute on function public.update_user_streak(uuid) to authenticated;

revoke all on function public.update_user_role(uuid, text) from public, anon;
grant execute on function public.update_user_role(uuid, text) to authenticated;

revoke all on function public.admin_adjust_coins(uuid, integer, text) from public, anon;
grant execute on function public.admin_adjust_coins(uuid, integer, text) to authenticated;

revoke all on function public.delete_user_account(uuid) from public, anon;
grant execute on function public.delete_user_account(uuid) to authenticated;

revoke all on function public.update_donation_status(uuid, text, uuid) from public, anon;
grant execute on function public.update_donation_status(uuid, text, uuid) to authenticated;

revoke all on function public.process_store_redemption(uuid, text, uuid) from public, anon;
grant execute on function public.process_store_redemption(uuid, text, uuid) to authenticated;

revoke all on function public.approve_material_upload(uuid, uuid, integer) from public, anon;
grant execute on function public.approve_material_upload(uuid, uuid, integer) to authenticated;

revoke all on function public.purchase_store_item(uuid, uuid, jsonb) from public, anon;
grant execute on function public.purchase_store_item(uuid, uuid, jsonb) to authenticated;
