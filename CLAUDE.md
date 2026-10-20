# CLAUDE.md

## Overview
Static Astro 7 site for the Patriot Package gift list, deployed to
https://patriot-package.vercel.app by Vercel's Git integration. Items are Markdown files in
`src/content/items/`, validated by `src/content.config.ts`.

## Commands
```bash
./init.sh                 # Node ≥22.12 check, npm ci
./run.sh                  # dev server :4321   (./run.sh stop ends dev/preview daemons)
./test.sh                 # everything CI runs; starts `astro preview` on :4322
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
  (`docs/DECISIONS.md` #6). The schema refuses `image` without `imageAlt`.
- usmint.gov and america250.org return 403 (a Cloudflare challenge) to `curl` and headless
  Chromium. Check those links in a real browser.
- Item categories are listed in `src/consts.ts`. Add a key there, or the schema rejects the
  file.
