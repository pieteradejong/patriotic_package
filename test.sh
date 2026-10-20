#!/usr/bin/env bash
# Every check this repo has, in one place. Exit 0 = green = safe to commit.
# CI runs `./test.sh --offline` on every push and PR, the full `./test.sh` weekly
# (links.yml), and `./test.sh --live <url>` after each production deploy.
# `./run.sh test` runs this script.
#
#   ./test.sh                 everything, including that every link works
#   ./test.sh --offline       skip only the outbound link check (needs the network)
#   ./test.sh --quick         static checks and outbound links: no type-check, build or browser
#   ./test.sh --live <url>    only the deployed site at <url>
#
# Offline sections: environment, dependencies against the lockfile, the
# scripts themselves (bash 3.2 syntax, shellcheck, --help), config (exact
# pins, Node versions, license, vercel.json, workflow SHAs), content (links,
# images, CREDITS.md), type-check, build, output, links inside the page
# (anchors, local paths, each card's link), meta, WCAG AA contrast, weight,
# repository hygiene, Playwright at 1280, 375 and 320px against `astro preview`,
# and every outbound link (product pages, image sources) answering. Every section runs even after an earlier one fails, except
# where it needs the build.
#
# A FAIL exits non-zero. A WARN is a known gap that is reported but never
# fails the run. A SKIP could not be determined here, and says why.

set -uo pipefail
cd "$(dirname "$0")" || exit 1

QUICK=0
NETWORK=1
LIVE_URL=""
USAGE="usage: ./test.sh [--offline] [--quick] [--live <url>] (--help for more)"
while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		--offline) NETWORK=0; shift ;;
		--quick)   QUICK=1; shift ;;
		--network) NETWORK=1; shift ;;   # the default; kept so older commands still work
		--live)    [ -n "${2:-}" ] || { echo "$USAGE" >&2; exit 2; }
		           LIVE_URL="${2%/}"; shift 2 ;;
		*)         echo "$USAGE" >&2; exit 2 ;;
	esac
done

if [ -t 1 ]; then
	GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
	GREEN=''; RED=''; BLUE=''; YELLOW=''; NC=''
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
FAILED_SECTIONS=""
CURRENT_SECTION=""

PREVIEW_PORT=4322
PREVIEW_URL="http://localhost:$PREVIEW_PORT"
WEIGHT_BUDGET_KB=100
CANONICAL="https://patriot-package.vercel.app/"
SCRIPTS="init.sh run.sh test.sh"

pass()    { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "  ${GREEN}PASS${NC} $1"; }
fail()    {
	FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "  ${RED}FAIL${NC} $1"
	case " $FAILED_SECTIONS " in *" $CURRENT_SECTION "*) ;; *) FAILED_SECTIONS="$FAILED_SECTIONS $CURRENT_SECTION" ;; esac
}
warn()    { WARN_COUNT=$((WARN_COUNT + 1)); echo -e "  ${YELLOW}WARN${NC} $1"; }
skip()    { SKIP_COUNT=$((SKIP_COUNT + 1)); echo -e "  ${YELLOW}SKIP${NC} $1"; }
section() { CURRENT_SECTION=$(echo "$1" | cut -d' ' -f1); echo; echo -e "${BLUE}== $1 ==${NC}"; }

# report: read "VERDICT<TAB>message" lines on stdin (scripts/checks.mjs, the
# browser report) and count each one. Runs in this shell, not a subshell.
report() {
	local verdict msg any=0
	while IFS=$'\t' read -r verdict msg; do
		[ -z "$verdict" ] && continue
		any=1
		case "$verdict" in
			PASS) pass "$msg" ;;
			WARN) warn "$msg" ;;
			SKIP) skip "$msg" ;;
			*)    fail "$msg" ;;
		esac
	done
	[ "$any" = 1 ] || fail "no results"
}
checks() { report < <(node scripts/checks.mjs "$1" 2>&1); }

PREVIEW_STARTED=0
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/patriot-test.XXXXXX")
cleanup() {
	[ "$PREVIEW_STARTED" = 1 ] && npx astro preview stop >/dev/null 2>&1
	rm -rf "$TMP_DIR"
	return 0
}
trap cleanup EXIT

summary() {
	section "Summary"
	echo -e "${GREEN}${PASS_COUNT} passed${NC}, ${RED}${FAIL_COUNT} failed${NC}, ${YELLOW}${WARN_COUNT} warnings${NC}, ${YELLOW}${SKIP_COUNT} skipped${NC}"
	if [ "$FAIL_COUNT" -gt 0 ]; then
		echo -e "${RED}Failed in:${FAILED_SECTIONS}${NC}"
		exit 1
	fi
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
# as one line.
run_browser_tests() {
	local base="$1" pw_json="$TMP_DIR/playwright.json"
	BASE_URL="$base" PLAYWRIGHT_JSON_OUTPUT_NAME="$pw_json" \
		npx playwright test --reporter=json >/dev/null 2>&1
	report < <(node -e "
		let r; try { r = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); } catch { console.log('FAIL\tno Playwright report (run: BASE_URL=$base npx playwright test)'); process.exit(); }
		if (r.errors?.length) console.log('FAIL\t' + r.errors[0].message.split('\n')[0]);
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
	[ "$canon" = "$CANONICAL" ] && pass "canonical URL is $canon" || fail "canonical URL is '$canon' (expected $CANONICAL)"
	missing=""
	for id in $(item_ids); do
		echo "$html" | grep -q "data-item=\"$id\"" || missing="$missing $id"
	done
	[ -z "$missing" ] && pass "every content item is on the live page" || fail "items missing from the live page:$missing"
	bad_img=""; n_img=0
	for src in $(echo "$html" | grep -o '<img [^>]*src="[^"]*"' | sed -E 's/.*src="([^"]*)"/\1/' | sed 's/&amp;/\&/g' | sort -u); do
		n_img=$((n_img + 1))
		case "$src" in http*) url="$src" ;; *) url="${LIVE_URL}${src}" ;; esac
		code=$(curl -s -o /dev/null --max-time 15 -w "%{http_code}" "$url")
		[ "$code" = "200" ] || bad_img="$bad_img $src->$code"
	done
	if [ "$n_img" -eq 0 ]; then fail "no images on the live page"
	elif [ -z "$bad_img" ]; then pass "all $n_img images on the live page are served"
	else fail "images not served:$bad_img"; fi
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
		&& pass "Node $(node -v) (Astro 7 needs 22.12+)" || fail "Node $(node -v) is older than 22.12 (Astro 7's floor)"
	want_major=$(cut -d. -f1 < .nvmrc)
	have_major=$(node -p 'process.versions.node.split(".")[0]')
	[ "$have_major" = "$want_major" ] && pass "Node major matches .nvmrc ($want_major)" \
		|| warn "Node $have_major here, $want_major in .nvmrc, CI and Vercel ('nvm use' to match)"
else
	fail "node not found (nvm install $(cat .nvmrc))"
	summary
fi
command -v npm >/dev/null 2>&1 && pass "npm $(npm -v)" || fail "npm not found"

section "Dependencies"
if [ -d node_modules ]; then
	pass "node_modules present"
	checks deps
else
	fail "node_modules missing (run ./init.sh)"
	summary
fi

section "Scripts"
for s in $SCRIPTS; do
	[ -x "$s" ] && pass "$s is executable" || fail "$s is not executable (chmod +x $s)"
	# macOS /bin/bash is 3.2, the oldest bash these scripts must run under.
	if [ -x /bin/bash ] && /bin/bash -n "$s" 2>"$TMP_DIR/syntax"; then
		pass "$s parses under $(/bin/bash -c 'echo bash $BASH_VERSION' | cut -d'(' -f1)"
	else
		fail "$s has a syntax error: $(head -1 "$TMP_DIR/syntax")"
	fi
	head -1 "$s" | grep -qx '#!/usr/bin/env bash' && pass "$s shebang is #!/usr/bin/env bash" || fail "$s shebang is not #!/usr/bin/env bash"
	out=$(./"$s" --help 2>&1) && [ -n "$out" ] && pass "$s --help prints its header" || fail "$s --help failed or printed nothing"
done
if command -v shellcheck >/dev/null 2>&1; then
	# No disable directives anywhere: fix findings instead.
	if shellcheck -S warning $SCRIPTS >"$TMP_DIR/shellcheck" 2>&1; then
		pass "shellcheck -S warning: clean ($SCRIPTS)"
	else
		fail "shellcheck -S warning: $(grep -c '^In ' "$TMP_DIR/shellcheck") finding(s)"
		sed 's/^/      /' "$TMP_DIR/shellcheck" | head -30
	fi
else
	fail "shellcheck not installed (brew install shellcheck)"
fi
node --check scripts/checks.mjs 2>"$TMP_DIR/nodecheck" && pass "scripts/checks.mjs parses" \
	|| fail "scripts/checks.mjs: $(head -1 "$TMP_DIR/nodecheck")"

section "Config"
checks config

section "Content"
checks content

section "Repository hygiene"
if git rev-parse --git-dir >/dev/null 2>&1; then
	tracked=$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -Ev '\.env\.(example|template)$')
	[ -z "$tracked" ] && pass "no .env file tracked" || fail "tracked env files: $tracked"
	tracked=$(git ls-files | grep -E '^(node_modules|dist|\.astro|\.vercel|test-results|playwright-report)/' | head -1)
	[ -z "$tracked" ] && pass "no build output or dependencies tracked" || fail "tracked generated file: $tracked"
	big=$(git ls-files -z | xargs -0 du -k 2>/dev/null | awk '$1 > 1024 {print $2}' | grep -v '^package-lock.json$' | head -3)
	[ -z "$big" ] && pass "no tracked file over 1 MB" || fail "large tracked files: $big"
	media=$(git ls-files | grep -Ei '\.(mp4|mov|webm|mp3|wav|m4a|zip|tar|gz|psd|tiff?)$' | head -3)
	[ -z "$media" ] && pass "no video, audio, archives or raw images tracked" || fail "media in git: $media"
	raw=$(git ls-files 'src/assets' 'public' | grep -Ei '\.(jpe?g|png)$' | head -3)
	[ -z "$raw" ] && pass "committed photos are WebP only" || fail "unoptimized images committed: $raw"
else
	skip "not a git checkout"
fi

# network_section [dist]: every outbound link answers; from the built page when given.
network_section() {
	section "Outbound links"
	if [ "$NETWORK" = 1 ]; then
		report < <(node scripts/checks.mjs network "${1:-}" 2>&1)
	else
		skip "--offline: outbound links not checked"
	fi
}

if [ "$QUICK" = 1 ]; then
	network_section
	section "Type-check, build and browser"
	skip "--quick: type-check, build, output and browser tests not run"
	summary
fi

section "Type-check"
if npx astro check >"$TMP_DIR/check" 2>&1; then
	pass "astro check: $(grep -Eo '[0-9]+ errors?' "$TMP_DIR/check" | head -1), $(grep -Eo '[0-9]+ warnings?' "$TMP_DIR/check" | head -1), $(grep -Eo '[0-9]+ hints?' "$TMP_DIR/check" | head -1)"
	grep -Eq '^- [1-9][0-9]* (warnings?|hints?)' "$TMP_DIR/check" && warn "astro check has warnings or hints (npx astro check)"
else
	fail "astro check found errors:"
	grep -E 'error|Error' "$TMP_DIR/check" | head -10 | sed 's/^/      /'
fi

section "Build"
if npx astro build >"$TMP_DIR/build" 2>&1; then
	pass "astro build"
	grep -q '\[WARN\]' "$TMP_DIR/build" && warn "build printed warnings: $(grep -m1 '\[WARN\]' "$TMP_DIR/build")"
	BUILT=1
else
	fail "astro build failed (schema errors show here):"
	tail -20 "$TMP_DIR/build" | sed 's/^/      /'
	BUILT=0
fi

if [ "$BUILT" = 1 ]; then
	section "Output"
	for f in index.html 404.html sitemap-index.xml robots.txt favicon.svg; do
		[ -f "dist/$f" ] && pass "dist/$f" || fail "dist/$f missing"
	done
	count=0; missing=""
	for id in $(item_ids); do
		count=$((count + 1))
		grep -q "data-item=\"$id\"" dist/index.html || missing="$missing $id"
	done
	[ -z "$missing" ] && pass "all $count items render on /" || fail "items not on /:$missing"
	n_src=$(grep -o 'srcset="[^"]*"' dist/index.html | grep -c '400w.*800w')
	n_photo=$(grep -o 'class="photo"' dist/index.html | wc -l | tr -d ' ')
	[ "$n_photo" -gt 0 ] && [ "$n_src" = "$n_photo" ] && pass "$n_photo photos, each with a 400w/800w srcset" \
		|| fail "$n_photo photos but $n_src with a 400w/800w srcset"
	lazy=$(grep -o '<img [^>]*class="photo"[^>]*>' dist/index.html | grep -vc 'loading="lazy"')
	[ "$lazy" = 0 ] && pass "card photos load lazily" || fail "$lazy card photos are not loading=lazy"
	nodims=$(grep -o '<img [^>]*>' dist/index.html | grep -v 'width=' | grep -vc 'height=')
	[ "$nodims" = 0 ] && pass "every img has width and height (no layout shift)" || fail "$nodims img tags lack width/height"

	section "Links in the page"
	checks links

	section "Meta"
	for pat in '<html lang="en"' "rel=\"canonical\" href=\"$CANONICAL\"" \
		'<meta name="description"' 'property="og:title"' 'property="og:description"' \
		'name="viewport"' 'name="theme-color"' '<meta name="build-commit" content="[0-9a-f]\{40\}"' '<vercel-analytics'; do
		grep -q "$pat" dist/index.html && pass "index.html has $pat" || fail "index.html lacks $pat"
	done

	section "Contrast (WCAG AA, 4.5:1 for body text)"
	report < <(node -e '
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

	section "Weight"
	kb=$(find dist -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' \) -not -name '404.html' -exec cat {} + | wc -c | awk '{print int($1/1024)}')
	[ "$kb" -le "$WEIGHT_BUDGET_KB" ] && pass "HTML+CSS+JS ${kb} KB (budget ${WEIGHT_BUDGET_KB} KB)" \
		|| fail "HTML+CSS+JS ${kb} KB is over the ${WEIGHT_BUDGET_KB} KB budget"
	img_kb=$(find dist/_astro -type f -name '*.webp' -exec cat {} + 2>/dev/null | wc -c | awk '{print int($1/1024)}')
	pass "optimized images in dist: ${img_kb} KB across all sizes"

	section "Browser (astro preview on :$PREVIEW_PORT)"
	if curl -s -o /dev/null --max-time 2 "$PREVIEW_URL/"; then
		warn "something is already listening on :$PREVIEW_PORT; testing it as is (./run.sh stop)"
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
else
	section "Output, links, meta, contrast, weight, browser"
	skip "the build failed, so nothing built can be checked"
fi

network_section "$([ "$BUILT" = 1 ] && echo dist)"

summary
