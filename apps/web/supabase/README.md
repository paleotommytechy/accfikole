# Supabase source of truth

The ACCF Ikole platform uses the existing production Supabase project `tblkfcafwjconemdcrpk` as the shared backend for the legacy dashboard, the new web app, and the future mobile app.

## Files

- `baseline/2026-10-04-production-schema.sql`
  - generated from the live production catalogs on 2026-10-04;
  - bootstrap-only snapshot for a **new** Supabase project;
  - includes current public tables, enum types, constraints, indexes, functions, triggers, RLS state/policies, grants, storage buckets/policies, and cron jobs;
  - intentionally excludes production data rows.
- `migrations/002_tasks_and_roles.sql`
  - production-baseline guard for required ACCF objects.
- `migrations/003_security_hardening.sql`
  - applied to production on 2026-10-04;
  - introduces authenticated, server-derived reward/privileged RPCs while keeping the legacy dashboard RPC signatures backward compatible.
- `proposed/004_enable_missing_rls.sql`
  - reviewed remediation for public tables that still have RLS disabled;
  - intentionally **not applied** automatically because enabling RLS changes production authorization behavior and must be explicitly approved.

## New environment bootstrap

For a brand-new Supabase project:

1. Start with a normal Supabase project so the managed `auth`, `storage`, `extensions`, and `cron` facilities exist.
2. Run `baseline/2026-10-04-production-schema.sql`.
3. Apply later committed migrations that post-date the snapshot.
4. Configure Auth providers/redirect URLs and deployment secrets separately.
5. Run cross-role verification for member/admin/blog/media/academics/pro/finance before using real data.

Do not run the baseline snapshot against the existing production project.

## Production rule

Never reset or recreate the live ACCF project merely to make local development easier. Production migrations must be additive/backward-compatible unless a separately reviewed data migration explicitly says otherwise.
