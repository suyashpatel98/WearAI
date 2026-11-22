# Shared helpers for mise file tasks. Source it: . "$MISE_PROJECT_ROOT/scripts/lib.sh"
set -euo pipefail
cd "${MISE_PROJECT_ROOT:?run tasks with mise run}"

LOCAL_API_URL="http://127.0.0.1:54321"
LOCAL_DB_CONTAINER="supabase_db_wearai"

die() { printf '✗ %s\n' "$*" >&2; exit 1; }
step() { printf '\n── %s\n' "$*"; }

# One line before anything that talks to Supabase (docs/spec/dev-ex.md#which-environment-a-command-targets).
banner_local() { printf '▸ local  %s\n' "$LOCAL_API_URL"; }
banner_hosted() { printf '▸ hosted  wearai (ref %s)\n' "${HOSTED_PROJECT_REF:?}"; }

# For :hosted tasks that change hosted. Prints the plan, then asks. SUPABASE_YES=1 (CI) skips the prompt.
confirm_hosted() {
  banner_hosted
  printf 'This will change hosted:\n'
  printf '  • %s\n' "$@"
  if [ "${SUPABASE_YES:-}" = "1" ]; then
    printf 'SUPABASE_YES=1, continuing.\n'
    return
  fi
  [ -t 0 ] || die "Refusing to change hosted without a terminal. Agents never run this task."
  local answer
  read -r -p "Type 'hosted' to continue: " answer
  [ "$answer" = "hosted" ] || die "Cancelled. Nothing was changed."
}

docker_ready() { command -v docker >/dev/null && docker info >/dev/null 2>&1; }
local_db_running() { docker_ready && [ -n "$(docker ps -q --filter "name=^${LOCAL_DB_CONTAINER}$")" ]; }

# Export the app's public values for APP_ENV (local|hosted). Variables already in the environment
# win over Expo's own .env.local loading, so this is what picks the environment.
load_app_env() {
  local env="${1:-${APP_ENV:-local}}"
  case "$env" in local | hosted) ;; *) die "APP_ENV must be local or hosted, not '$env'" ;; esac
  set -a
  # shellcheck disable=SC1090
  . "./.env.$env"
  set +a
  export APP_ENV="$env"
}

require_phone() {
  command -v adb >/dev/null || die "adb not found. Run: mise run setup"
  if ! adb devices | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
    cat >&2 <<'MSG'
✗ No phone found by `adb devices`.
  1. Connect the OnePlus 7T to the Mac with a USB cable.
  2. On the phone: Settings → About phone → tap Build number 7 times.
  3. Settings → System → Developer options → turn on USB debugging.
  4. Unlock the phone and accept "Allow USB debugging?" for this Mac.
  Then check with: adb devices
MSG
    exit 1
  fi
}

# Run expo prebuild for an APP_VARIANT (development|release), cleaning android/ only when the
# variant changed, so the two variants never share native project files.
prebuild_android() {
  local variant="$1" marker="android/.wearai-variant"
  local clean=()
  if [ -d android ] && [ "$(cat "$marker" 2>/dev/null)" != "$variant" ]; then clean=(--clean); fi
  APP_VARIANT="$variant" pnpm expo prebuild --platform android --no-install ${clean[@]+"${clean[@]}"}
  printf '%s\n' "$variant" >"$marker"
}
