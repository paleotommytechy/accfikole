# ACCF Ikole — repository instructions for coding agents

## Scope and current branch
- Repository: `paleotommytechy/accfikole`, a pnpm/Turborepo modernization of the production `paleotommytechy/accfikolewebsite-dashboard`.
- The active prototype is on `Prototype`. `main` and `staging` do not yet contain that prototype. Verify branch/base before changes; do not silently target the empty branches.
- Use `MIGRATION_MATRIX.md` to understand implemented, deferred, and production-parity claims. At this stage, `apps/web` is the active application; `apps/mobile` is intentionally deferred.
- Read `docs/agency/WORKFLOWS.md` for workflow routing and `docs/agency/ROLE_SOURCES.md` for the Agency Agents provenance. The `.github/agents/*.agent.md` files offer specialized guidance where supported.

## Mandatory engineering rules
1. Inspect the current files, relevant history, existing tests, branch and PR before proposing or editing code. Distinguish observed behavior from plans.
2. Design first for nontrivial features: problem, contract, data/security impact, test strategy, and rollback/migration concerns. Implement a scoped change, not an unsolicited rewrite.
3. Preserve existing production ACCF Supabase data. Do not reset databases, remove real rows, or apply schema changes to production automatically. Use additive, reviewable migrations, inspect real RLS/privileges, and verify compatibility.
4. Frontend route guards are not an authorization boundary. Protect user data through trusted backend/database checks. Never expose service-role keys or provider secrets in browser/mobile bundles, logs, or commits.
5. Tasks, coins, finance, donations and redemptions require authorized, idempotent and transactional mutations. Prevent duplicate approvals/rewards and cross-user data access.
6. Preserve legacy product behavior unless it is explicitly redesigned, deferred or deprecated. Update the migration matrix if a feature changes status. The legacy repo is a behavioral reference, not an architectural blueprint.
7. Use shared packages only where genuinely platform-independent. Do not invent mobile readiness; validate web, Android and iOS independently when those platforms exist.
8. Inspect existing package scripts before running commands. The root defines `pnpm lint`, `pnpm check-types`, `pnpm test`, and `pnpm build`; record outcomes, skipped checks and prerequisites accurately.
9. Work on a feature branch. Provide a reviewable PR and evidence, never self-merge. Avoid modifying unrelated files.
10. Distinguish specialist roles from actual independent agents. Agent profiles are instructions, not a guarantee of autonomous execution, memory or parallelism.

## Specialist handoff
For features: Codebase Guide → Software Architect / Backend Architect → Frontend Developer (and Mobile Builder only if in scope) → AppSec Reviewer + Test Automation Engineer → Reality Checker.
For isolated fixes: Codebase Guide → responsible implementer → tests/security as warranted → Reality Checker.
For PR QA: read-only Reality Checker + AppSec as needed; inspect the exact head and full current diff. Do not combine QA and implementation without an explicit request.

## Review evidence
Report the exact commit SHA, paths reviewed, commands actually run, outcomes, unverified areas, parity implications, security findings, and next actions. Classify findings as CONFIRMED DEFECT, STRONGLY SUPPORTED RISK, MISSING VERIFICATION, or OPTIONAL IMPROVEMENT, with proportional BLOCKER/HIGH/MEDIUM/LOW/NOTE severity. Do not invent successful tests, deployments, simulators or real-device evidence.
