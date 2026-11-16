# ACCF Agency Agents integration

Repository-native specialist instruction profiles sourced from [The Agency](https://github.com/msitarzewski/agency-agents) and customized for the ACCF Ikole Turborepo.

**Entry points:** [root AGENTS.md](../../AGENTS.md) for Codex and general coding agents; [Copilot repository instructions](../../.github/copilot-instructions.md); [specialist profiles](../../.github/agents/); [WORKFLOWS.md](WORKFLOWS.md) for role routing; [ROLE_SOURCES.md](ROLE_SOURCES.md) for pinned upstream provenance; [FEATURE_HANDOFF_TEMPLATE.md](FEATURE_HANDOFF_TEMPLATE.md) for outputs.

This approach keeps the useful parts of Agency Agents in GitHub without requiring the user to install its desktop application. It does not install an AI model, grant access to an external API, or run asynchronous agents automatically. Selecting an agent in a supported GitHub Copilot environment requires that environment/account's native agent support.

Existing ACCF Prototype and staging checks remain authoritative; no CI, deployment, production database or source-code changes are made by these documents alone.
