# ACCF Ikole Migration / Parity Matrix

This document records what the `Prototype` branch represents while the ACCF platform moves from the production `accfikolewebsite-dashboard` repository into the `accfikole` Turborepo.

## Source of truth

- **Behavior/UI reference:** `paleotommytechy/accfikolewebsite-dashboard`.
- **Production data/backend:** the existing ACCF Supabase project already used by the production dashboard.
- **Prototype web app:** `apps/web`; intended to preserve existing web behavior and design while changing repository/package-management infrastructure to pnpm/Turborepo.
- **Database evolution:** must be additive and production-data-safe. Existing production rows must not be recreated, replaced, or discarded merely to satisfy local development.
- **Mobile:** intentionally deferred at this Prototype stage. Absence of `apps/mobile` is not a claim that mobile parity is complete.

## Capability status

| Domain | Legacy production dashboard | Prototype web | Mobile | Migration note |
| --- | --- | --- | --- | --- |
| Authentication / OAuth / password recovery | Reference behavior | Replicated; backend hardening in progress | Deferred | Shared production Supabase auth is the target |
| Profile / onboarding | Reference behavior | Replicated; moving bootstrap to trusted DB RPC | Deferred | Existing production profiles must be preserved |
| Roles / privileged screens | Reference behavior | Replicated | Deferred | Backend/RLS remains authoritative |
| Dashboard | Reference behavior | Replicated | Deferred | No intentional visual redesign in Prototype |
| Tasks / coins / streaks | Reference behavior | Replicated; reward writes being hardened | Deferred | Reward amounts/idempotency belong in trusted DB logic |
| Weekly challenges / quizzes | Reference behavior | Replicated; reward writes being hardened | Deferred | Existing production records remain canonical |
| Academics / materials | Reference behavior | Replicated | Deferred | Uses existing production academic data |
| AI academic helpers | Reference behavior | Replicated; API boundary secured | Deferred | Gemini credentials remain server-only |
| Events / RSVP | Reference behavior | Replicated | Deferred | Existing event/RSVP tables remain canonical |
| Prayer requests | Reference behavior | Replicated | Deferred | No intentional Prototype redesign |
| Messaging | Reference behavior | Replicated | Deferred | Cross-user access depends on production RLS |
| In-app notifications | Reference behavior | Replicated | Deferred | Supabase realtime remains active |
| Web push | Incomplete/placeholder | Explicitly deferred until VAPID sender is configured | N/A | UI must not claim push is enabled without configuration |
| Blog / posts / comments | Reference behavior | Replicated; Markdown sanitized | Deferred | Existing content retained |
| Gallery / media | Reference behavior | Replicated | Deferred | Existing storage/data retained |
| Resources | Reference behavior | Replicated | Deferred | Existing production data retained |
| Giving / finance | Reference behavior | Replicated | Deferred | No replacement database |
| Store / redemptions | Reference behavior | Replicated | Deferred | Trusted production RPC/RLS required |
| Sponsorships | Reference behavior | Replicated | Deferred | Existing production data retained |
| Hymns / Bible study / game center / letterhead | Reference behavior | Replicated | Deferred | Feature parity reference only |

## Mobile milestone

A dedicated `apps/mobile` package will be introduced after the shared backend/security contract is stable enough to serve both platforms. At that point each domain above must be reclassified as implemented, redesigned, deferred, or intentionally unsupported on Android/iOS, with build/device evidence recorded separately.

## Production Supabase rule

Prototype migrations are schema-as-code and hardening artifacts for the **existing** production Supabase project. They are not authorization to reset that project. Before applying a migration to production:

1. inspect the live schema and existing policies/functions;
2. take an appropriate backup;
3. verify the migration is additive/idempotent against production;
4. test on a safe branch/staging database when available;
5. apply to production only after compatibility is confirmed.

