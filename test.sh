#!/usr/bin/env bash
# Test suite for the Patriot Package site.
#
# Offline (the default, and what CI runs on every push and pull request):
# toolchain, production build, content schema, every item rendered, 404 page,
# sitemap/robots, meta and Open Graph tags, WCAG AA colour contrast, page
# weight, repository hygiene, and the Playwright suite (desktop and phone
# widths) against `astro preview`.
#
# Live (CI runs it after Vercel reports a production deployment): the routes,
# the canonical host, the analytics script, the deployed commit against
# origin/main, and the Playwright suite against the real URL.
#
# A FAIL exits non-zero. A WARN is a known gap that is reported but never
# fails the run. A SKIP could not be determined.
#
# Usage: ./test.sh [--offline] [--live <url>]
#   --offline      same as no flag; kept for symmetry with CI
#   --live <url>   check only the deployed site at <url>

set -uo pipefail
cd "$(dirname "$0")" || exit 1
case "${1:-}" in -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

LIVE_URL=""
USAGE="usage: ./test.sh [--offline] [--live <url>]"
while [ $# -gt 0 ]; do
	case "$1" in
		--offline) shift ;;
		--live)    [ -n "${2:-}" ] || { echo "$USAGE" >&2; exit 2; }
		           LIVE_URL="${2%/}"; shift 2 ;;
		*)         echo "$USAGE" >&2; exit 2 ;;
	esac
done

PREVIEW_PORT=4322
PREVIEW_URL="http://localhost:$PREVIEW_PORT"
WEIGHT_BUDGET_KB=100

pass()    { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "  ${GREEN}PASS${NC} $1"; }
fail()    { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "  ${RED}FAIL${NC} $1"; }
warn()    { WARN_COUNT=$((WARN_COUNT + 1)); echo -e "  ${YELLOW}WARN${NC} $1"; }
skip()    { SKIP_COUNT=$((SKIP_COUNT + 1)); echo -e "  ${YELLOW}SKIP${NC} $1"; }
section() { echo; echo -e "${BLUE}== $1 ==${NC}"; }

PREVIEW_STARTED=0
cleanup() {
	[ "$PREVIEW_STARTED" = 1 ] && npx astro preview stop >/dev/null 2>&1
	return 0
}
trap cleanup EXIT

summary() {
	section "Summary"
	echo -e "${GREEN}${PASS_COUNT} passed${NC}, ${RED}${FAIL_COUNT} failed${NC}, ${YELLOW}${WARN_COUNT} warnings${NC}, ${YELLOW}${SKIP_COUNT} skipped${NC}"
	[ "$FAIL_COUNT" -gt 0 ] && exit 1
	exit 0
}

# Item ids, one per Markdown file in src/content/items (underscore files are drafts).
item_ids() {
	local f
	for f in src/content/items/*.md; do
		f=$(basename "$f" .md)
		case "$f" in _*) ;; *) echo "$f" ;; esac
	done
}

# run_browser_tests <base-url>: run the Playwright suite and report each test
# as one PASS/FAIL line.
run_browser_tests() {
	local base="$1" pw_json results verdict msg
	pw_json=$(mktemp)
	BASE_URL="$base" PLAYWRIGHT_JSON_OUTPUT_NAME="$pw_json" \
		npx playwright test --reporter=json >/dev/null 2>&1
	results=$(node -e "
		let r; try { r = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); } catch { console.log('ERR\tno Playwright report'); process.exit(); }
		if (r.errors?.length) console.log('ERR\t' + r.errors[0].message.split('\n')[0]);
		const walk = (s) => {
			for (const sp of s.specs ?? []) for (const t of sp.tests) {
				if (t.status === 'skipped') { console.log('SKIP\t[' + t.projectName + '] ' + sp.title); continue; }
				const res = t.results.at(-1) ?? {};
				const ok = t.status === 'expected';
				const why = ok ? '' : (res.errors ?? [res.error]).filter(Boolean).map(e => (e.message ?? '').replace(/\x1b\[[0-9;]*m/g, '').split('\n').find(l => l.trim())).join(' | ');
				console.log((ok ? 'PASS' : 'FAIL') + '\t[' + t.projectName + '] ' + sp.title + (why ? ' — ' + why.trim() : ''));
			}
			for (const c of s.suites ?? []) walk(c);
		};
		(r.suites ?? []).forEach(walk);
	" "$pw_json")
	rm -f "$pw_json"
	if [ -z "$results" ]; then
		fail "browser tests produced no results (run: BASE_URL=$base npx playwright test)"
		return
	fi
	while IFS=$'\t' read -r verdict msg; do
		[ -z "$verdict" ] && continue
		case "$verdict" in
			PASS) pass "$msg" ;;
			SKIP) skip "$msg" ;;
			*)    fail "$msg" ;;
		esac
	done <<< "$results"
}

# ---------------------------------------------------------------- live mode
if [ -n "$LIVE_URL" ]; then
	echo "Checking the deployed site at $LIVE_URL"
	host=$(echo "$LIVE_URL" | sed -E 's#https?://([^/]+).*#\1#')

	section "Routes"
	for route in "/" "/404.html" "/sitemap-index.xml" "/robots.txt" "/favicon.svg"; do
		out=$(curl -s -o /dev/null -L --max-time 15 -w "%{http_code} %{url_effective}" "${LIVE_URL}${route}")
		code=${out%% *}
		final=$(echo "${out#* }" | sed -E 's#https?://([^/]+).*#\1#')
		if [ "$final" != "$host" ]; then
			fail "GET $route redirected off-site to $final (login wall or wrong host)"
		elif [ "$route" = "/404.html" ]; then
			case "$code" in 200|404) pass "GET $route -> $code" ;; *) fail "GET $route -> $code" ;; esac
		elif [ "$code" = "200" ]; then
			pass "GET $route -> 200"
		else
			fail "GET $route -> $code (expected 200)"
		fi
	done
	code=$(curl -s -o /dev/null --max-time 15 -w "%{http_code}" "$LIVE_URL/this-page-does-not-exist")
	[ "$code" = "404" ] && pass "missing route -> 404" || fail "missing route -> $code (expected 404)"

	section "Page"
	html=$(curl -s -L --max-time 15 "$LIVE_URL/")
	canon=$(echo "$html" | grep -o 'rel="canonical" href="[^"]*"' | sed -E 's/.*href="([^"]*)"/\1/')
	if [ "$canon" = "https://patriot-package.vercel.app/" ]; then
		pass "canonical URL is $canon"
	else
		fail "canonical URL is '$canon' (expected https://patriot-package.vercel.app/)"
	fi
	missing=""
	for id in $(item_ids); do
		echo "$html" | grep -q "data-item=\"$id\"" || missing="$missing $id"
	done
	[ -z "$missing" ] && pass "every content item is on the live page" || fail "items missing from the live page:$missing"
	if echo "$html" | grep -q '<vercel-analytics'; then
		pass "analytics component present"
		code=$(curl -s -o /dev/null --max-time 15 -w "%{http_code}" "$LIVE_URL/_vercel/insights/script.js")
		[ "$code" = "200" ] && pass "analytics script served" \
			|| warn "analytics script -> $code (enable Web Analytics on the Vercel project)"
	else
		fail "analytics component missing from the live page"
	fi

	section "Deployed commit"
	live_sha=$(echo "$html" | grep -o '<meta name="build-commit" content="[^"]*"' | sed -E 's/.*content="([^"]*)"/\1/')
	# CI passes the deployed commit; by hand, compare with what origin/main is now.
	want_sha="${EXPECTED_COMMIT:-$(git ls-remote origin refs/heads/main 2>/dev/null | cut -f1)}"
	if [ -z "$live_sha" ]; then
		fail "no build-commit meta tag on the live page"
	elif [ -z "$want_sha" ]; then
		skip "could not read origin/main to compare with $live_sha"
	elif [ "$live_sha" = "$want_sha" ]; then
		pass "live site is built from $live_sha"
	else
		fail "live site is built from $live_sha, expected $want_sha"
	fi

	section "Browser"
	run_browser_tests "$LIVE_URL"
	summary
fi

# ------------------------------------------------------------- offline mode
section "Environment"
if command -v node >/dev/null 2>&1; then
	node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=12)?0:1)' \
		&& pass "Node $(node -v)" || fail "Node $(node -v) is older than 22.12 (Astro 7's floor)"
else
	fail "node not found"; summary
fi
[ -d node_modules ] && pass "node_modules present" || { fail "node_modules missing (run ./init.sh)"; summary; }
[ -f package-lock.json ] && pass "package-lock.json present" || fail "package-lock.json missing"
if grep -Eq '"[\^~]' package.json; then fail "package.json has a ^ or ~ range (exact pins only)"; else pass "dependencies pinned exactly"; fi

section "Build"
build_log=$(mktemp)
if npx astro build >"$build_log" 2>&1; then
	pass "astro build"
	grep -q '\[WARN\]' "$build_log" && warn "build printed warnings: $(grep -m1 '\[WARN\]' "$build_log")"
else
	fail "astro build failed (schema errors show here):"
	tail -20 "$build_log" | sed 's/^/      /'
	rm -f "$build_log"; summary
fi
rm -f "$build_log"
for f in index.html 404.html sitemap-index.xml robots.txt favicon.svg; do
	[ -f "dist/$f" ] && pass "dist/$f" || fail "dist/$f missing"
done

section "Content"
count=0; missing=""
for id in $(item_ids); do
	count=$((count + 1))
	grep -q "data-item=\"$id\"" dist/index.html || missing="$missing $id"
done
[ "$count" -gt 0 ] && pass "$count content items" || fail "no content items in src/content/items"
[ -z "$missing" ] && pass "every item renders on /" || fail "items not on /:$missing"

section "Meta"
for pat in '<html lang="en"' 'rel="canonical" href="https://patriot-package.vercel.app/"' \
	'<meta name="description"' 'property="og:title"' 'property="og:description"' \
	'name="viewport"' 'name="theme-color"' '<meta name="build-commit" content="[0-9a-f]\{40\}"' '<vercel-analytics'; do
	grep -q "$pat" dist/index.html && pass "index.html has $pat" || fail "index.html lacks $pat"
done

section "Contrast (WCAG AA, 4.5:1 for body text)"
contrast=$(node -e '
	const css = require("fs").readFileSync("src/styles/global.css", "utf8");
	const v = (n) => (css.match(new RegExp("--" + n + ":\\s*(#[0-9a-fA-F]{6})")) || [])[1];
	const lum = (h) => { const c = [1,3,5].map(i => parseInt(h.slice(i, i+2), 16) / 255).map(x => x <= 0.03928 ? x/12.92 : ((x+0.055)/1.055) ** 2.4); return 0.2126*c[0] + 0.7152*c[1] + 0.0722*c[2]; };
	const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
	for (const [fg, bg] of [["ink","paper"],["ink","white"],["muted","paper"],["muted","white"],["blue","paper"],["blue","white"],["red","paper"],["red","white"]]) {
		const a = v(fg), b = v(bg);
		if (!a || !b) { console.log("FAIL\t--" + fg + " or --" + bg + " not found in global.css"); continue; }
		const r = ratio(a, b);
		console.log((r >= 4.5 ? "PASS" : "FAIL") + "\t--" + fg + " on --" + bg + ": " + r.toFixed(2) + ":1");
	}
')
while IFS=$'\t' read -r verdict msg; do
	[ "$verdict" = PASS ] && pass "$msg" || fail "$msg"
done <<< "$contrast"

section "Weight"
kb=$(find dist -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' \) -not -name '404.html' -exec cat {} + | wc -c | awk '{print int($1/1024)}')
[ "$kb" -le "$WEIGHT_BUDGET_KB" ] && pass "HTML+CSS+JS ${kb} KB (budget ${WEIGHT_BUDGET_KB} KB)" \
	|| fail "HTML+CSS+JS ${kb} KB is over the ${WEIGHT_BUDGET_KB} KB budget"

section "Repository hygiene"
if git rev-parse --git-dir >/dev/null 2>&1; then
	tracked=$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -Ev '\.env\.(example|template)$')
	[ -z "$tracked" ] && pass "no .env file tracked" || fail "tracked env files: $tracked"
	tracked=$(git ls-files | grep -E '^(node_modules|dist|\.astro|\.vercel)/' | head -1)
	[ -z "$tracked" ] && pass "no build output or dependencies tracked" || fail "tracked generated file: $tracked"
	big=$(git ls-files -z | xargs -0 du -k 2>/dev/null | awk '$1 > 1024 {print $2}' | grep -v '^package-lock.json$' | head -3)
	[ -z "$big" ] && pass "no tracked file over 1 MB" || fail "large tracked files: $big"
else
	skip "not a git checkout"
fi

section "Browser (astro preview on :$PREVIEW_PORT)"
if curl -s -o /dev/null --max-time 2 "$PREVIEW_URL/"; then
	warn "something is already listening on :$PREVIEW_PORT; testing it as is"
else
	npx astro preview --port "$PREVIEW_PORT" >/dev/null 2>&1 &
	PREVIEW_STARTED=1
	for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
		curl -s -o /dev/null --max-time 2 "$PREVIEW_URL/" && break
		sleep 1
	done
fi
if curl -s -o /dev/null --max-time 2 "$PREVIEW_URL/"; then
	run_browser_tests "$PREVIEW_URL"
else
	fail "preview server did not come up on :$PREVIEW_PORT"
fi

summary
