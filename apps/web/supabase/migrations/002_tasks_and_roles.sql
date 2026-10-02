-- ACCF Ikole production schema baseline guard
--
-- The Prototype branch uses the existing production Supabase project. This
-- migration intentionally does not recreate or delete production tables.
-- It converts the previously corrupted migration into valid UTF-8 SQL and
-- fails loudly when a required production object is missing.
--
-- Once the live Supabase connection is available, replace this guard with an
-- exact schema dump/migration chain captured from production. Do not infer or
-- reset production data from frontend TypeScript types.

do $$
declare
  required_table text;
  required_tables text[] := array[
    'profiles',
    'user_roles',
    'onboarding_progress',
    'tasks',
    'tasks_assignments',
    'weekly_challenges',
    'weekly_participants',
    'quizzes',
    'quiz_questions',
    'quiz_attempts',
    'coin_transactions',
    'events',
    'event_rsvps',
    'messages',
    'user_course_materials',
    'material_quizzes',
    'material_quiz_questions',
    'material_quiz_attempts',
    'notifications'
  ];
begin
  foreach required_table in array required_tables loop
    if to_regclass('public.' || required_table) is null then
      raise exception
        'ACCF production baseline is missing required table public.% . Capture/restore the production schema before applying hardening migrations.',
        required_table;
    end if;
  end loop;
end
$$;
