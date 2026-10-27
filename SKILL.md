---
name: hermes-doctor
description: >-
  Diagnose Hermes Agent health: profile identity, skills, tools, memory,
  config drift, cron, sessions. Use whenever the user asks how Hermes is
  doing, whether anything is broken, to "check/diagnose/audit" the agent,
  or before/after a config change. Also use when behavior seems off
  (missing tools, ghost skills, stale sessions) and you need ground truth
  instead of guessing.
---

# Hermes doctor

Run `scripts/doctor.sh` for a fast, deterministic health report:

```bash
scripts/doctor.sh            # report for active profile
HERMES_PROFILE=<name> scripts/doctor.sh
```

It checks profile/config/skills/tools/memory/cron/sessions/logs and exits
non-zero on failures. Read the report, then reason about it — do not just
relay it verbatim.

## What the script does not judge, and you must

- **Config drift.** `hermes config check` prints known drift keys; compare
  against `hermes config show` and explain any that matter to the user's
  setup. Suggest `hermes config migrate` only after listing the keys.
- **Duplicate skills.** The script counts skills per source directory.
  A skill name appearing under BOTH `~/.hermes/skills/` and
  `~/.hermes/profiles/<active>/skills/` is a shadowing duplicate: the
  profile copy wins, but the user-visible list will be confusing. Flag and
  offer to remove the orphan (usually the global copy, unless it is a
  bundled default managed by the curator).
- **Orphan processes.** Anything the script flags (upload server, doc store,
  llama-server) that the user did not ask to keep alive should be reported
  with its port and PID so the user can decide.
- **Log errors.** The script tails error lines from gateway/hermes logs;
  interpret whether they are current or stale noise before alarming the user.

## Ground truth, not cached belief

Always re-run the script after config changes — never report health from
memory of a previous run. `hermes skills list` marks built-in skills as
`[local]` here; treat only the script's source counts for duplication
logic.

## Safe repair boundaries

Never run `hermes update`, delete skills, or touch another profile's files
without explicit user confirmation. `hermes sessions repair` is safe to run
when the script flags session store problems; report before/after counts.
