# CLAUDE.md

## Overview
Static Astro 7 site for the Patriot Package gift list, deployed to
https://patriot-package.vercel.app by Vercel's Git integration. Items are Markdown files in
`src/content/items/`, validated by `src/content.config.ts`.

## Commands
```bash
./init.sh                 # idempotent setup; --clean reinstalls, --test runs ./test.sh after
./run.sh                  # dev server :4321   (./run.sh stop ends dev/preview daemons)
./run.sh lint             # shellcheck + astro check
./test.sh                 # everything, outbound links included; starts `astro preview` on :4322
./test.sh --offline       # what CI runs per push (no outbound links)
./test.sh --quick         # static checks + outbound links, no build
./test.sh --live <url>    # deployed site
```

## Architecture
- No deploy step in CI: Vercel deploys on push, and GitHub Actions only checks
  (`docs/DECISIONS.md` #2). `DEPLOYMENT.md` has the jobs and the rollback steps.
- `astro.config.mjs` stamps the commit into `<meta name="build-commit">`. `test.sh --live` compares
  it with `EXPECTED_COMMIT` (set by CI) or with `origin/main`.

## Gotchas
- `astro dev` and `astro preview` run as background daemons in Astro 7. Stop them with
  `npx astro preview stop` / `npx astro dev stop`.
- Off Vercel, `/_vercel/insights/script.js` returns 404. The Playwright console-error test ignores
  that URL only.
- Item photos: public domain or CC0 only, 800×600 WebP, and a row in `CREDITS.md` for each
  (`docs/DECISIONS.md` #6). The one exception is the book's seller photo (#13). The schema refuses
  an image without `imageAlt`.
- usmint.gov and america250.org return 403 (a Cloudflare challenge) to `curl` and headless
  Chromium. Check those links in a real browser. proudpatriots.com sometimes answers `429` from
  Cloudflare; the link check skips that too.
- The book's photo is hotlinked from the seller's CDN (`imageUrl`, `docs/DECISIONS.md` #13), so the
  Playwright photo test needs the network even under `--offline`.
- `typescript` is pinned to 6.0.3, not 7: `@astrojs/check` 0.9.10 declares `^5 || ^6`.
- npm 11 does not run esbuild's or fsevents' install scripts (`allowScripts`), and CI installs
  with `--ignore-scripts`. Both builds work without them; don't approve them just to quiet the
  warning.
- A new check goes in `scripts/checks.mjs` when it is easier in Node. Print `PASS|FAIL|WARN|SKIP`,
  a tab, then the message; `test.sh` counts the lines.
- The header images are generated: `scripts/header/make.sh` (macOS only: Vision, ImageMagick,
  cwebp) rebuilds `src/assets/header-{flag,eagle}.webp`. The flag's mottling is random, so each
  run gives a slightly different file.
- Item categories are listed in `src/consts.ts`. Add a key there, or the schema rejects the
  file.
