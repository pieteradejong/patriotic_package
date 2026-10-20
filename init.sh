#!/usr/bin/env bash
# Set up everything needed to work on this repo. Exit 0 = ready. Safe to re-run:
# a second run reuses node_modules when it still matches the lockfile.
#
#   ./init.sh            check the toolchain, install dependencies, the test browser
#   ./init.sh --clean    delete node_modules, .astro and dist first, then set up
#   ./init.sh --test     set up, then run ./test.sh
#
# What it does:
#   1. Node: the major in .nvmrc (22) is what CI and Vercel use; 22.12+ is required.
#   2. npm ci from package-lock.json, only when node_modules is missing or stale.
#   3. Chromium for Playwright, unless Google Chrome is installed (playwright.config.ts
#      uses it then).
#   4. Checks the other tools ./test.sh needs (shellcheck, git) and says how to get them.
#   5. Generates Astro's types (.astro/) so the editor and astro check see the content schema.
# It needs no .env: the site has no secrets or environment variables.
set -euo pipefail
cd "$(dirname "$0")"

CLEAN=0
RUN_TESTS=0
for arg in "$@"; do
	case "$arg" in
		-h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		--clean)   CLEAN=1 ;;
		--test)    RUN_TESTS=1 ;;
		*)         echo "unknown option: $arg (see ./init.sh --help)" >&2; exit 2 ;;
	esac
done

if [ -t 1 ]; then
	GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
	GREEN=''; BLUE=''; YELLOW=''; RED=''; NC=''
fi
say()  { printf '%b\n' "${BLUE}$1${NC}"; }
ok()   { printf '%b\n' "  ${GREEN}✓${NC} $1"; }
note() { printf '%b\n' "  ${YELLOW}!${NC} $1"; }
die()  { printf '%b\n' "  ${RED}✗${NC} $1" >&2; exit 1; }

say "patriot-package — setup"

say "Toolchain"
WANT_NODE=$(cut -d. -f1 < .nvmrc)
command -v node >/dev/null 2>&1 || die "Node.js is not installed. With nvm: 'nvm install $WANT_NODE && nvm use'."
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=12)?0:1)' \
	|| die "Node $(node -v) found, but Astro 7 needs 22.12 or newer ('nvm install $WANT_NODE && nvm use')."
HAVE_NODE=$(node -p 'process.versions.node.split(".")[0]')
if [ "$HAVE_NODE" = "$WANT_NODE" ]; then
	ok "Node $(node -v)"
else
	note "Node $(node -v) works, but CI and Vercel run $WANT_NODE ('nvm use' in this directory to match)"
fi
command -v npm >/dev/null 2>&1 || die "npm is not installed."
ok "npm $(npm -v)"
command -v git >/dev/null 2>&1 && ok "git $(git --version | cut -d' ' -f3)" || note "git not found; ./test.sh skips its repository checks"
if command -v shellcheck >/dev/null 2>&1; then
	ok "shellcheck $(shellcheck --version | sed -n 2p | cut -d' ' -f2)"
else
	note "shellcheck not found; ./test.sh will fail its Scripts section ('brew install shellcheck')"
fi

if [ "$CLEAN" = 1 ]; then
	say "Cleaning"
	rm -rf node_modules .astro dist
	ok "removed node_modules, .astro and dist"
fi

say "Dependencies"
[ -f package-lock.json ] || die "package-lock.json is missing; this repo installs from the lockfile only."
# npm writes node_modules/.package-lock.json on every install. If it is newer than
# package-lock.json and every direct dependency matches, node_modules can stay.
STALE=1
if [ -f node_modules/.package-lock.json ] && [ node_modules/.package-lock.json -nt package-lock.json ] \
	&& ! node scripts/checks.mjs deps | grep -q '^FAIL'; then
	STALE=0
fi
if [ "$STALE" = 0 ]; then
	ok "node_modules matches package-lock.json (reused; --clean to reinstall)"
else
	npm ci --no-audit --no-fund
	ok "installed from package-lock.json"
fi

say "Test browser"
CHROME=""
for p in "${CHROME_PATH:-}" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" /usr/bin/google-chrome; do
	[ -n "$p" ] && [ -x "$p" ] && { CHROME="$p"; break; }
done
if [ -n "$CHROME" ]; then
	ok "using installed Chrome: $CHROME"
else
	# A no-op when this Playwright version's Chromium is already downloaded.
	npx playwright install chromium
	ok "Playwright Chromium ready"
fi

say "Astro types"
npx astro sync >/dev/null
ok "generated .astro/ (content schema types)"

if [ -d .git ] && command -v vercel >/dev/null 2>&1 && [ ! -d .vercel ]; then
	note "optional: 'vercel link --project patriot-package' to use 'vercel ls' and 'vercel rollback' here"
fi

say "Ready."
echo "  ./run.sh          dev server on http://localhost:4321/"
echo "  ./test.sh         every check (what CI runs)"

if [ "$RUN_TESTS" = 1 ]; then
	say "Running ./test.sh"
	exec ./test.sh
fi
