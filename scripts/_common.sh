#!/bin/bash
# _common.sh — Shared helpers for release scripts. Source this, don't run it.

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
step()  { printf "\n\033[1;34m→ %s\033[0m\n" "$*"; }
die()   { red "error: $*" >&2; exit 1; }

append_path_once() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    case ":$PATH:" in
        *":$dir:"*) ;;
        *) export PATH="$dir:$PATH" ;;
    esac
    return 0
}

setup_sparkle_tools() {
    local candidate=""
    local root=""
    local -a roots=()
    local derived_dir=""
    local -a derived_roots=()

    command -v generate_appcast >/dev/null 2>&1 && return 0

    [[ -n "${SPARKLE_BIN:-}" ]] && roots+=("$SPARKLE_BIN")
    [[ -n "${HOMEBREW_CASKROOM:-}" ]] && roots+=("${HOMEBREW_CASKROOM}/sparkle")
    roots+=("/opt/homebrew/Caskroom/sparkle" "/usr/local/Caskroom/sparkle")

    if command -v brew >/dev/null 2>&1; then
        candidate="$(brew --prefix 2>/dev/null || true)"
        [[ -n "$candidate" ]] && roots+=("$candidate/Caskroom/sparkle")
    fi

    derived_dir="${HOME}/Library/Developer/Xcode/DerivedData"
    if [[ -d "$derived_dir" ]]; then
        while IFS= read -r root; do
            derived_roots+=("$root")
        done < <(find "$derived_dir" -path '*/SourcePackages/artifacts/*/Sparkle/bin' -type d 2>/dev/null)

        if [[ ${#derived_roots[@]} -eq 0 ]]; then
            while IFS= read -r root; do
                derived_roots+=("$root")
            done < <(find "$derived_dir" -path '*/SourcePackages/artifacts/*/*/bin' -type d 2>/dev/null)
        fi

        roots+=("${derived_roots[@]}")
    fi

    for root in "${roots[@]}"; do
        if [[ "$root" == */bin ]]; then
            append_path_once "$root"
            command -v generate_appcast >/dev/null 2>&1 && return 0
            continue
        fi

        candidate=$(/bin/ls -d "$root"/*/bin 2>/dev/null | sort -V | tail -1 || true)
        [[ -n "$candidate" ]] || continue
        append_path_once "$candidate"
        command -v generate_appcast >/dev/null 2>&1 && return 0
    done

    return 1
}

prime_sparkle_tools_from_xcode() {
    command -v xcodebuild >/dev/null 2>&1 || return 1
    [[ -d "Ora.xcodeproj" ]] || return 1

    xcodebuild -project Ora.xcodeproj -scheme ora -resolvePackageDependencies >/dev/null 2>&1 || return 1
    setup_sparkle_tools
}

# load_env VAR1 VAR2 ... — source .env and verify required vars exist
load_env() {
    [[ -f ".env" ]] || die ".env not found."
    set -a; source .env; set +a
    for var in "$@"; do
        [[ -n "${!var:-}" ]] || die "Missing $var in .env"
    done
}
