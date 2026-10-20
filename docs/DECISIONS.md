# Decisions

Append-only. Supersede an entry with a new one that links back.

## 1. A static Astro site, the same stack as astropieter
**Date:** 2026-10-20
**Context:** The repo was a Markdown list in the README. Pieter wanted it at a URL on Vercel with
real CI/CD.
**Decision:** Astro 7, static output. Each item is a Markdown file in `src/content/items/`, and a
schema (`src/content.config.ts`) fails the build on a bad entry. The setup copies astropieter
(`test.sh` harness, Playwright, the CI shape), so one way of working covers both sites.
Rejected:
- Plain HTML with no build: simplest, but no schema, and every new field means editing markup by
  hand.
- Next.js (`templates/vercel-stack`): server runtime, auth and database plumbing that a list page
  does not use. Reopen if the site starts taking orders or needs accounts.
**Verified:** `./test.sh` on 2026-10-20 → `38 passed, 0 failed, 0 warnings, 0 skipped` (build, 10
items rendered, meta, contrast, weight, hygiene, Playwright at 1280px and 375px). A file with
`category: spaceship` failed `astro build` with `InvalidContentEntryDataError … expected one of
"document"|"book"|"coin"|"keepsake"`.

## 2. Vercel's Git integration deploys; GitHub Actions only checks
**Date:** 2026-10-20
**Context:** "Great CI/CD" needs previews, a gate before merge, and proof that production works,
with no deploy credentials stored in GitHub.
**Decision:** Vercel project `patriot-package` (team `pieteradejongs-projects`) is connected to the
repo. A push to `main` deploys production, and every other branch and pull request gets a preview
URL. GitHub Actions never deploys. Workflow `site` runs `./test.sh` on every push and PR, and
`./test.sh --live` after each successful production deployment. That live run also checks that the
served build is the deployed commit (`<meta name="build-commit">`). `security` runs the reusable
gitleaks + gate workflow.
Rejected: `vercel deploy --prebuilt` from Actions with a `VERCEL_TOKEN` secret. It gates the deploy
on the tests, but it puts a long-lived deploy token in GitHub and duplicates what the integration
does. Branch protection gives the same gate for pull requests.
**Verified:** NOT YET — needs the first push, the production deployment and a green `live` job.

## 3. CC0 covers the code as well as the list
**Date:** 2026-10-20
**Context:** The repo was CC0-1.0 when it held only data. It now has site code.
**Decision:** Keep CC0-1.0 for everything. The code is small and has nothing worth protecting with
attribution. Rejected: MIT for the code and CC0 for the content, which means two licenses for a
repo this size.
**Verified:** `head -3 LICENSE` → `Creative Commons Legal Code` / `CC0 1.0 Universal`;
`jq -r .license package.json` → `CC0-1.0`.
