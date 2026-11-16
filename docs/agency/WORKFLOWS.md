# Agency Agents workflows — ACCF Ikole

## Purpose
Use The Agency's engineering, security and testing specialist instructions with **explicit project state** and a human-governed development pipeline. This is a GitHub-hosted agent configuration, not a new runtime, dependency, background worker, or independently operating AI service. No local installation is required to retain and inspect the profiles in the repo.

## Source of truth
1. Current repository code and exact branch/PR head
2. `MIGRATION_MATRIX.md` and existing project requirements
3. Root `AGENTS.md` and project-specific QA policy
4. Appropriate `.github/agents/*.agent.md` profiles, adapted from The Agency
5. Upstream examples as optional reference only

Do not treat upstream role personas or claimed internal 'memory' as runtime capabilities.

## Workflow: a new feature (NEXUS-inspired small sprint)
1. **Discover** — Codebase Guide inventories the actual implementation, dependencies, ownership, risks and acceptance criteria, citing paths.
2. **Design** — Software/Backend Architect defines a minimal solution, data contract, RLS/authorization, migrations, compatibility and test plan. Record meaningful decisions.
3. **Implement** — Frontend Developer and/or Backend Architect make scoped changes. Mobile Builder participates only when mobile is actually in scope. Use feature branches and small PRs.
4. **Verify** — Test Automation Engineer exercises real entry points; AppSec Reviewer inspects threat boundaries, especially RLS, storage, auth, privileged RPC and secrets.
5. **Review** — Reality Checker independently inspects the **entire diff against its current base**, the exact head SHA, available CI evidence, migration matrix and unverified surfaces. Give a verdict without self-merging.
6. **Handoff** — Provide changed files, tests actually run, failures, security and data impacts, acceptance criteria status, open follow-ups and evidence links.

## Workflow: bug or production incident
Reproduce or isolate the symptom, identify the responsible layer, make the smallest safe fix, add a regression test, check for security/data impact, and verify on the correct branch. No production DB writes without explicit authorization and safeguards.

## Workflow: schema or authorization change
Inspect committed migrations and live-environment constraints where permitted. Propose a compatible migration with RLS and privileged-function checks. Validate against a safe environment; document backup and rollout/rollback concerns. Never assume schema-as-code permits destructive operations on the existing production Supabase project.

## Workflow: PR quality assurance
Keep QA **read-only** by default. Identify base/head SHAs, review complete diff and surrounding code, check existing concerns and CI for the exact candidate, classify issues with evidence and give the ACCF QA verdict. Never infer a device test from TypeScript success.

## Workflow: mobile milestone
Mobile remains deferred in the current prototype. When approved, first agree on shared domain/backend contracts and platform-specific design. Require Expo/Android and iOS build and device/simulator evidence separately.

## Execution boundaries
- GitHub-native Copilot can discover repository agent profiles in `.github/agents` when available to the account; choose them explicitly or through the host's selection mechanism.
- Codex automatically reads root `AGENTS.md` when run in the repository; companion specialist profiles must be explicitly loaded or configured in its own runtime.
- In an ordinary ChatGPT conversation, the files are not auto-mounted as executable assistants. A connected GitHub read of `AGENTS.md` and relevant profiles makes their guidance available for a requested task. Each future task is an actual new execution, not an always-running background team.
- No GitHub Action has been added to invoke models or apply code unattended. Existing CI workflows remain unchanged.

## Reuse in another project
Copy the general structure, select only relevant upstream roles, replace all ACCF-specific constraints with that repo's real architecture and QA policy, and introduce the integration on a new branch/PR. Do not copy assumptions about Supabase, Turborepo or platform readiness into unrelated repos.
