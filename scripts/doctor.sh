#!/usr/bin/env bash
# hermes-doctor: deterministic health snapshot for the active Hermes profile.
set -uo pipefail

fail=0
note() { printf '%-28s %s\n' "$1" "$2"; }
bad()  { fail=1; note "$1" "FAIL: $2"; }

echo "=== Hermes doctor ($(date -Iseconds)) ==="

# --- profile identity ---
prof=$(hermes profile show 2>/dev/null | grep -oE 'Profile:[[:space:]]+\S+' | head -1 | awk '{print $2}')
note profile "${prof:-unknown}"
[ -n "${prof:-}" ] || bad profile "hermes profile show failed"

# --- config validity & drift ---
if out=$(hermes config check 2>&1); then
  drift=$(printf '%s' "$out" | grep -ci 'drift' || true)
  note config "ok (drift mentions: $drift)"
else
  bad config "config check failed: $(printf '%s' "$out" | head -1)"
fi

# --- skills: per-source counts and duplicates ---
skills_dir=$HOME/.hermes/skills
prof_skills=$HOME/.hermes/profiles/$prof/skills
count_skill_dirs() {
  local d=$1
  [ -d "$d" ] || { echo 0; return; }
  find "$d" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l
}
g=$(count_skill_dirs "$skills_dir"); p=$(count_skill_dirs "$prof_skills")
note skills.global "$g"
note skills.profile "$p"
if [ -d "$prof_skills" ] && [ -d "$skills_dir" ]; then
  dup=$(comm -12 \
    <(find "$skills_dir" -mindepth 2 -maxdepth 2 -name SKILL.md | awk -F/ '{print $(NF-1)}' | sort -u) \
    <(find "$prof_skills" -mindepth 2 -maxdepth 2 -name SKILL.md | awk -F/ '{print $(NF-1)}' | sort -u))
  if [ -n "$dup" ]; then
    bad skills.duplicates "$(printf '%s' "$dup" | tr '\n' ' ')"
  else
    note skills.duplicates "none"
  fi
fi

# --- tools / platforms ---
note gateway "pid(s): $(pgrep -f 'hermes.*gateway' | tr '\n' ' ' || true)"
pgrep -f 'hermes.*gateway' >/dev/null || bad gateway "not running"

# --- memory files ---
for f in "$HOME/.hermes/memories/"*.md; do
  [ -e "$f" ] || continue
  sz=$(wc -c < "$f")
  note "memory:$(basename "$f")" "${sz} bytes"
done

# --- cron ---
if jobs=$(hermes cron list 2>/dev/null | grep -c . ); then
  note cron.entries "$jobs"
fi

# --- sessions ---
hermes sessions list 2>/dev/null | head -1 | grep -qi 'session' \
  && note sessions "store readable" || bad sessions "cannot read session store; try: hermes sessions repair"

# --- agent log errors (last 24h) ---
log=$HOME/.hermes/logs/agent.log
if [ -f "$log" ]; then
  errs=$(grep -iE '\bERROR\b|Traceback' "$log" | tail -5)
  if [ -n "$errs" ]; then
    note log.errors "recent error lines:"
    printf '%s\n' "$errs" | sed 's/^/    /'
  else
    note log.errors "none"
  fi
fi

# --- orphan long-running servers the user may have forgotten ---
for pat in 'docstore_app' 'upload_app' 'llama-server'; do
  pid=$(pgrep -f "$pat" | head -1)
  [ -n "$pid" ] && note "server:$pat" "pid $pid (orphan check)"
done

echo "=== exit: $([ $fail -eq 0 ] && echo healthy || echo ISSUES-FOUND) ==="
exit $fail
