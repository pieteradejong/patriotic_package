#!/usr/bin/env bash
# One-time setup for a fresh clone: checks the toolchain, installs the pinned
# dependencies from the lockfile and tells you what to run next. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in -h|--help) sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
say()  { printf '%b\n' "${BLUE}$1${NC}"; }
ok()   { printf '%b\n' "  ${GREEN}✓${NC} $1"; }
die()  { printf '%b\n' "  ${RED}✗${NC} $1" >&2; exit 1; }

say "patriot-package — initial setup"

# Node 22.12+ is Astro 7's floor. package.json pins engines to 22.x, which is what Vercel and CI use.
command -v node >/dev/null 2>&1 || die "Node.js is not installed. This machine uses nvm: 'nvm install 22 && nvm use 22'."
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=12)?0:1)' \
	|| die "Node $(node -v) found, but Astro 7 needs 22.12 or newer ('nvm install 22')."
ok "Node $(node -v)"
command -v npm >/dev/null 2>&1 || die "npm is not installed."
ok "npm $(npm -v)"

say "Installing dependencies (npm ci)…"
[ -f package-lock.json ] || die "package-lock.json is missing — this repo installs from the lockfile only."
npm ci --no-audit --no-fund
ok "dependencies installed"

say "Next:"
echo "  ./run.sh          dev server on http://localhost:4321/"
echo "  ./test.sh         build and run every check"
