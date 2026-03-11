#!/bin/bash
# _common.sh — Shared helpers for release scripts. Source this, don't run it.

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
step()  { printf "\n\033[1;34m→ %s\033[0m\n" "$*"; }
die()   { red "error: $*" >&2; exit 1; }

# load_env VAR1 VAR2 ... — source .env and verify required vars exist
load_env() {
    [[ -f ".env" ]] || die ".env not found."
    set -a; source .env; set +a
    for var in "$@"; do
        [[ -n "${!var:-}" ]] || die "Missing $var in .env"
    done
}
