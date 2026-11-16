# Agency Agents — provenance and role map

Source: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)

Snapshot revision: [`8ae6164602c95ca78828b148b9052460ee426885`](https://github.com/msitarzewski/agency-agents/tree/8ae6164602c95ca78828b148b9052460ee426885)

License: MIT, copyright (c) 2025 AgentLand Contributors. The license text is preserved in [UPSTREAM_LICENSE.md](UPSTREAM_LICENSE.md).

The GitHub Copilot agent profiles under `.github/agents/` reproduce the corresponding upstream Markdown role instructions, with upstream YAML frontmatter replaced by valid Copilot profile metadata and an ACCF-specific safety/engineering preface. Existing GitHub workflow files and application code were not changed.

| Repository profile | The Agency source | Primary responsibility |
| --- | --- | --- |
| [ACCF Codebase Guide](../../.github/agents/codebase-guide.agent.md) | [engineering/engineering-codebase-onboarding-engineer.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/engineering/engineering-codebase-onboarding-engineer.md) | Read-only exploration of ACCF Ikole repository architecture and actual implementation paths. |
| [ACCF Software Architect](../../.github/agents/software-architect.agent.md) | [engineering/engineering-software-architect.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/engineering/engineering-software-architect.md) | Designs the ACCF Turborepo boundaries and migration architecture before implementation. |
| [ACCF Backend Architect](../../.github/agents/backend-architect.agent.md) | [engineering/engineering-backend-architect.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/engineering/engineering-backend-architect.md) | Plans Supabase PostgreSQL migrations, backend APIs, roles and reliable data operations for ACCF. |
| [ACCF Frontend Developer](../../.github/agents/frontend-developer.agent.md) | [engineering/engineering-frontend-developer.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/engineering/engineering-frontend-developer.md) | Implements and reviews React/TypeScript web flows for the ACCF prototype. |
| [ACCF Mobile Builder](../../.github/agents/mobile-builder.agent.md) | [engineering/engineering-mobile-app-builder.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/engineering/engineering-mobile-app-builder.md) | Plans future Expo/React Native Android and iOS workflows without claiming mobile parity exists. |
| [ACCF AppSec Reviewer](../../.github/agents/appsec-reviewer.agent.md) | [security/security-appsec-engineer.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/security/security-appsec-engineer.md) | Reviews ACCF Supabase RLS, auth, secrets, authorization and cross-user data isolation. |
| [ACCF Test Automation Engineer](../../.github/agents/test-automation.agent.md) | [testing/testing-test-automation-engineer.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/testing/testing-test-automation-engineer.md) | Develops deterministic tests for ACCF web, backend and future mobile functionality. |
| [ACCF Reality Checker](../../.github/agents/reality-checker.agent.md) | [testing/testing-reality-checker.md](https://github.com/msitarzewski/agency-agents/blob/8ae6164602c95ca78828b148b9052460ee426885/testing/testing-reality-checker.md) | Independently assesses evidence for the exact ACCF PR head and gives a conservative merge-readiness verdict. |

When updating, review upstream diffs, preserve license attribution, re-apply project-specific constraints, and run the repository checks. Never automatically track an unreviewed upstream `main` branch or execute upstream installer scripts in CI.
