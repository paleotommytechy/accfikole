# ACCF Ikole — Copilot repository instructions

Read the root `AGENTS.md` and `MIGRATION_MATRIX.md` before planning changes. Follow `docs/agency/WORKFLOWS.md` for role routing, handoffs and evidence.

The specialist files in `.github/agents/` are project-specific adaptations of [The Agency](https://github.com/msitarzewski/agency-agents); select the smallest relevant role set. Do not presume that merely having these profiles causes parallel multi-agent execution.

Protect the existing production Supabase data, schema compatibility, trusted authorization/RLS, transactional reward/finance operations and legacy parity. No automatic production mutations or merges. Record actual checks and the reviewed SHA.
