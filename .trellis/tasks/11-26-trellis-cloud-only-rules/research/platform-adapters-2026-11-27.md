# Portable Trellis platform-adapter inventory

Date: 2026-11-27.
Inspection revision: `a9a10880962262aee86b24ee7975fb7d0578aef3`.
Scope: 53 tracked Claude definitions and 17 distinct adapter/configuration files.
This is a preservation summary, not installation or cross-platform execution evidence.

## Sources and disposition

The 53 Claude paths below come from the tracked tree at the inspection revision.
The 17 adapter paths come from the earlier per-file cpp-trellis audit.
Their current source text and platform-specific differences were inspected again.
The external backup also contains the four platform directory layouts under
`portable-agent-definitions/`.

The machine-local backup root is:

```text
D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127
```

The generic workflow is already portable through `.trellis/` and the tracked Claude definitions.
The adapters carry discovery paths, dispatch descriptions, context selectors and hook schemas.
They do not add C/C++ application behavior.
They are not all byte-identical to their Claude counterparts.
Preserving the workflow does not establish that every host adapter works.

This pass does not add ignored directories, change configuration or create a broad ignore exception.
The summary and hashes preserve the disposition for a fresh clone.
Restoring any adapter requires an approved source change with hosted checks.
Keep session identity, local settings, credentials and caches out of that restoration.

## Complete tracked Claude inventory: 53 files

Counts: 3 agents, 2 commands, 4 hooks, 1 settings file, and 43 skill/reference files.
Every path in this block is relative to `.claude/`.

```text
agents/trellis-check.md
agents/trellis-implement.md
agents/trellis-research.md
commands/trellis/continue.md
commands/trellis/finish-work.md
hooks/inject-subagent-context.py
hooks/inject-workflow-state.py
hooks/session-start.py
hooks/statusline.py
settings.json
skills/trellis-before-dev/SKILL.md
skills/trellis-brainstorm/SKILL.md
skills/trellis-break-loop/SKILL.md
skills/trellis-channel/SKILL.md
skills/trellis-channel/references/command-reference.md
skills/trellis-channel/references/forum.md
skills/trellis-channel/references/progress-debugging.md
skills/trellis-channel/references/workers.md
skills/trellis-channel/references/workflows.md
skills/trellis-check/SKILL.md
skills/trellis-meta/SKILL.md
skills/trellis-meta/references/customize-local/add-project-local-conventions.md
skills/trellis-meta/references/customize-local/change-agents.md
skills/trellis-meta/references/customize-local/change-context-loading.md
skills/trellis-meta/references/customize-local/change-hooks.md
skills/trellis-meta/references/customize-local/change-skills-or-commands.md
skills/trellis-meta/references/customize-local/change-spec-structure.md
skills/trellis-meta/references/customize-local/change-task-lifecycle.md
skills/trellis-meta/references/customize-local/change-workflow.md
skills/trellis-meta/references/customize-local/overview.md
skills/trellis-meta/references/local-architecture/bundled-skills.md
skills/trellis-meta/references/local-architecture/context-injection.md
skills/trellis-meta/references/local-architecture/generated-files.md
skills/trellis-meta/references/local-architecture/multi-agent-channel.md
skills/trellis-meta/references/local-architecture/overview.md
skills/trellis-meta/references/local-architecture/spec-system.md
skills/trellis-meta/references/local-architecture/task-system.md
skills/trellis-meta/references/local-architecture/workflow.md
skills/trellis-meta/references/local-architecture/workspace-memory.md
skills/trellis-meta/references/platform-files/agents.md
skills/trellis-meta/references/platform-files/hooks-and-settings.md
skills/trellis-meta/references/platform-files/overview.md
skills/trellis-meta/references/platform-files/platform-map.md
skills/trellis-meta/references/platform-files/skills-and-commands.md
skills/trellis-session-insight/SKILL.md
skills/trellis-session-insight/references/cli-quick-reference.md
skills/trellis-session-insight/references/triggering-patterns.md
skills/trellis-spec-bootstrap/SKILL.md
skills/trellis-spec-bootstrap/references/mcp-setup.md
skills/trellis-spec-bootstrap/references/repository-analysis.md
skills/trellis-spec-bootstrap/references/spec-task-planning.md
skills/trellis-spec-bootstrap/references/spec-writing.md
skills/trellis-update-spec/SKILL.md
```

These files preserve task planning, explicit task activation, implementation/check/research roles,
context injection and its read-based fallback, specifications, durable research and session knowledge.
Generic templates may describe local validation or automatic bookkeeping.
Repository `AGENTS.md` overrides those examples.
Nothing in this inventory grants local execution, staging, commits or journal writes.

## All 17 distinct adapter/configuration candidates

The count is 2 CodeBuddy, 6 Cursor, 4 DeepSeek Harness and 5 ZCode files.
It counts distinct unpublished adapter texts identified by the earlier audit.
It is not the total number of files in those platform directories.
All paths in the table are relative to the repository root.

| # | Path | Preserved difference or purpose |
| --- | --- | --- |
| 1 | `.codebuddy/commands/trellis/continue.md` | Uses `get_context.py --platform codebuddy` |
| 2 | `.codebuddy/settings.json` | CodeBuddy hook events, tool matchers and project-relative hook paths |
| 3 | `.cursor/agents/trellis-check.md` | Description explicitly selects the Trellis check agent and `check.jsonl` context |
| 4 | `.cursor/agents/trellis-implement.md` | Description selects the implementation agent and rejects generic substitutes |
| 5 | `.cursor/agents/trellis-research.md` | Description selects durable research under the active task |
| 6 | `.cursor/commands/trellis-continue.md` | Flat Cursor command layout and `--platform cursor` |
| 7 | `.cursor/commands/trellis-finish-work.md` | Flat command name `/trellis-finish-work` in the return-to-commit instruction |
| 8 | `.cursor/hooks.json` | Cursor hook schema and lower-camel-case event names |
| 9 | `.dsh/DSH.md` | Pull-based host overview, entry skills and absence of automatic context hooks |
| 10 | `.dsh/skills/trellis-continue/SKILL.md` | Resume routing with `--platform dsh` |
| 11 | `.dsh/skills/trellis-finish-work/SKILL.md` | Skill-based finish entry rather than a slash-command palette |
| 12 | `.dsh/skills/trellis-start/SKILL.md` | Manual session/context loading and inline workflow routing |
| 13 | `.zcode/agents/trellis-check.md` | Color metadata and a shorter check prompt with explicit context fallback |
| 14 | `.zcode/agents/trellis-implement.md` | Color metadata and ZCode-oriented wording around task inputs |
| 15 | `.zcode/agents/trellis-research.md` | Color metadata, ZCode scope wording and durable-research instructions |
| 16 | `.zcode/commands/trellis/continue.md` | Uses `get_context.py --platform zcode` |
| 17 | `.zcode/config.json` | Enabled event map and `${ZCODE_PROJECT_DIR}`-relative hook paths |

The Cursor agent differences are description/frontmatter changes in the inspected versions.
The ZCode prompts also differ in body wording and scope detail.
In particular, the shorter ZCode check prompt is not a substitute for the current authoritative task-artifact contract.
A future restoration must review those differences rather than copying the older prompt over newer rules.

## Hook and discovery details needed for restoration

| Host | Observed binding |
| --- | --- |
| CodeBuddy | `SessionStart` matchers `startup`, `clear`, `compact`, `PreToolUse` matchers `task\|Task` and `execute_command\|Bash\|PowerShell`, plus `UserPromptSubmit` |
| Cursor | Schema `version: 1`, `preToolUse` matcher `Task\|Subagent`, `sessionStart` and `beforeShellExecution` |
| ZCode | `hooks.enabled: true`, `hooks.events`, session matcher `startup\|clear\|compact`, tool matchers `Agent\|Task` and `Bash`, plus `UserPromptSubmit` |
| DeepSeek Harness | `.dsh/skills/` entry discovery, shared `.agents/skills/` workflow discovery, no shipped sub-agent surface |

Session/context hooks use a 30-second timeout where recorded.
Workflow-state hooks use 15 seconds.
Shell-session hooks use 5 seconds.
These are configuration values, not measured performance guarantees.
No hook was invoked during this audit.

The backup also retains companion hooks, commands and skill/reference files.
The earlier audit found many companion bodies identical to tracked Claude content or historical shared hooks.
Their directory layout still matters to the host loader.
The 17 distinct texts alone do not constitute a self-contained installation.
For example, the DeepSeek Harness entries expect shared workflow skills,
while the inspected main worktree has no `.agents/` skill tree.
Do not describe that host as ready merely because the four entry documents are preserved.

## Source-byte identities for the 17 candidates

SHA-256 and byte counts were read from the source files on 2026-11-27.
These are file identities, not Git blob IDs or execution attestations.
The source paths below correspond one-to-one to the numbered table.
No generated file was created to obtain these metadata values.

| # | Bytes | SHA-256 |
| --- | ---: | --- |
| 1 | 2382 | `1ab4fe6313615db66b6bc79926534524565d84d5b7aa2ad60fcbe5f401a0af69` |
| 2 | 1476 | `cc4e25867ee8b510d6be0ec505c0b8e1cdc03065395f5057d16220036069938b` |
| 3 | 3730 | `e54d3de996bab4abd7653eef4d64c171638fbc2859e9b1fe4aae2483df72de99` |
| 4 | 3536 | `636d55ebb56d9d3ea6ef9ec615c53bcaeab2b1afb3dc7e30ad51091efe5ab5ea` |
| 5 | 3796 | `e39b18734b4947ada2d1d6b2432f82daf58d16b6d98aa5b8b78e4a5364559617` |
| 6 | 2379 | `8ba4d26d2d6276c6b520eebbe5f1365733f35fa31beb03777887779c216c6e6d` |
| 7 | 3425 | `16006238f2b8410a87fd8b857b4ed3f9f529b28cd85fe97cfeabe79f95406e41` |
| 8 | 483 | `e751f3eb5293155c2dd0bc145353fcc15806a6ed79c099978a944c7f31525059` |
| 9 | 2675 | `648b18898d5088115959af4d1500dab5c0612813ce72a32b017a72441fb9dfc6` |
| 10 | 2680 | `ec33424e8aa81ea85044d630b59c3177c2451c7df52fcca506af98c91990c79b` |
| 11 | 3684 | `3ef6a459b85cb1b010eb98b32eb0af5b704dd934b747e358fddf91e62409ae05` |
| 12 | 2826 | `82bc71975d50347e776af1c3d64a3c5ea8af661d82e3df91c0d2144af181489e` |
| 13 | 3021 | `9d48b731d4e2cb034c0c85ff291b732c330d34deca88767c470e9c49884c9445` |
| 14 | 3329 | `a3c18fbc99ccecafdae869456075d8e81e2e6c1e3a69f1fe53b83ade18873f1d` |
| 15 | 3696 | `ef7fcddb131536eb5d9606c8ef3f789b2edeb2b3b68ae13c237faa4917cfc751` |
| 16 | 2378 | `a42c97fc35d15ca41db8945275f0b580e1c9d9317b8ea5279e763bd11f85be31` |
| 17 | 1235 | `11bf404a860f6a2a0b6f9ae952f1b5bd1b21ba5070da062f25c6c43209e8427a` |

## Acceptance boundary

Preserved source is not activated configuration.
Activated configuration is not proof of hook reachability or context correctness.
Hosted validation of a future restoration must cover path resolution, event payloads,
platform selectors, task-artifact fallback, no recursive dispatch and secret exclusion.
The coordinator owns publication and target-clone acceptance.
This pass ran no local tests, analysis or lint and made no adapter/configuration edits.
