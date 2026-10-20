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
The CLI created the project with `gitProviderOptions.createDeployments: disabled`. With that
setting Vercel posts commit statuses but no GitHub Deployments, so `deployment_status` never fires
and `live` never runs on its own. It is now `enabled`, the same as `padj`.
**Verified:** 2026-10-20:
- Push `7642e36` → `vercel ls patriot-package` showed `● Ready  Production`, and
  `curl -sI https://patriot-package.vercel.app` → `HTTP/2 200`.
- `site/tests` run 39419198454 → success. `security / gitleaks` and `security / gate` → success.
- `./test.sh --live https://patriot-package.vercel.app` → `17 passed, 0 failed, 0 warnings,
  0 skipped`, including `live site is built from 7642e36…`.
- `live` job by `workflow_dispatch` (run 39419382119) → success.
- `vercel api /v9/projects/patriot-package` → `"createDeployments":"enabled"`.
- Push `e333c03` → GitHub deployment `Production e333c03`. `site` run 39419777772, started by
  `deployment_status`: `live success`. `site` (push) and `security` (push) → success.

## 3. CC0 covers the code as well as the list
**Date:** 2026-10-20
**Context:** The repo was CC0-1.0 when it held only data. It now has site code.
**Decision:** Keep CC0-1.0 for everything. The code is small and has nothing worth protecting with
attribution. Rejected: MIT for the code and CC0 for the content, which means two licenses for a
repo this size.
LICENSE starts with CC0's dedication notice naming Pieter de Jong, because the public-repo gate
requires the canonical holder (`license-holder`) and the bare legal code names nobody.
**Verified:** `head -1 LICENSE` → `To the extent possible under law, Pieter de Jong has waived …`;
`grep -c 'CC0 1.0 Universal' LICENSE` → `2`; `jq -r .license package.json` → `CC0-1.0`.

## 4. Required checks on `main`, with admins exempt
**Date:** 2026-10-20
**Context:** Branch protection gates pull requests on CI. Pieter also pushes straight to `main`.
**Decision:** `main` requires `tests`, `security / gitleaks` and `security / gate`, and blocks force
pushes and deletion. `enforce_admins` is off, so Pieter's direct pushes still land and deploy, and
the checks run on them afterwards. Rejected:
- `enforce_admins` on: every change would need a PR, which is too heavy for one person editing a list.
- Requiring `live`: it runs after the deploy, so it cannot gate one.
**Verified:** `gh api repos/pieteradejong/patriotic_package/branches/main/protection` →
`{"admins":false,"checks":["tests","security / gitleaks","security / gate"],"force":false}`.

## 5. Category navigation is a sticky row of chips
**Date:** 2026-10-20
**Context:** On a 375px phone the page is about 5,000px tall, with 10 cards in 4 sections.
**Decision:** A `<nav>` of category chips under the header, built from the same groups as the
page. On phones it sticks to the top and scrolls sideways inside itself. From 481px it is a plain
row. Section headings carry `scroll-margin-top`, so a jump lands below the bar. Rejected:
- A hamburger menu: it hides four links behind a tap.
- Collapsible `<details>` sections: they hide the list, which is the page.
**Verified:** `./test.sh` → `59 passed, 0 failed, 0 warnings, 1 skipped`, including:
- `jump nav has one link per section and lands below the sticky bar` at 1280, 375 and 320px
- `jump nav stays at the top on phones` at 375 and 320px (skipped on desktop by design)
- `no horizontal scroll` at all three widths

## 6. Real public-domain photos, committed and small
**Date:** 2026-10-20
**Context:** Pieter asked for product pictures and chose real photos over drawn SVG or hotlinked
images. The workspace rule is "no media or large binaries in git".
**Decision:** Ten images from Wikimedia Commons, all public domain, CC0 or "No restrictions". They
are cropped to 800×600 (the eagle 320×320), WebP, 11–108 KB each, about 0.6 MB in total, and
committed in `src/assets/`. Astro builds 400px and 800px variants. Small optimized stills fit the
rule's intent, which targets video, audio, weights and datasets. Sources and licenses are in
`CREDITS.md`. Rejected:
- CC BY / BY-SA photos: they would add attribution and share-alike terms to a CC0 repo.
- Hotlinking Commons: a third-party dependency, visitors' requests going to Wikimedia, and links
  that can break.
- The Great Seal for the header eagle: its display is restricted (18 U.S.C. § 713). A USFWS bald
  eagle photo is used instead.
- An image for "250 Years of American History": it is not yet a specific book, so there is no
  cover to show.
Product links point to official pages only. usmint.gov and america250.org answer automated
requests with a Cloudflare challenge (403), so those two paths come from search-indexed results.
They are not fetched by CI.
**Verified:**
- `du -ch src/assets/eagle.webp src/assets/items/*.webp | tail -1` → `584K total`.
- Commons API `LicenseShortName` for all ten: `Public domain` ×9, `No restrictions` ×1 (CREDITS.md).
- `curl -L -w '%{http_code}'` → `200` for archives.gov ×2, guides.loc.gov, nps.gov, aoc.gov ×2 and
  en.wikipedia.org.
- `./test.sh`: `photos load, have alt text and fit their card` and `every item links out over https`
  pass at all three widths.

## 7. The outbound link check runs on demand, not in CI
**Date:** 2026-10-20
**Context:** `./test.sh` gained a check that every product link and image source answers. CI could
run it on every push.
**Decision:** It sits behind `./test.sh --network` and does not run in CI. Three of the
official hosts (usmint.gov ×2, america250.org) answer automated requests with a Cloudflare
challenge, and any third-party outage would fail an unrelated push. Challenged hosts are reported
as SKIP with a reason, never as PASS. Rejected:
- In CI on every push: it fails on someone else's outage.
- A weekly scheduled job like astropieter's link report: worth adding once the list stops
  changing (TODO.md).
**Verified:** `./test.sh --quick --network`: 17 links `200`, 3 `SKIP … answers a bot challenge`,
0 failed. Its first run found four `CREDITS.md` links broken by unencoded parentheses (404), which
are now fixed.

## 8. `./test.sh` checks every link by default; CI checks them weekly (supersedes #7)
**Date:** 2026-10-20
**Context:** Pieter asked for `test.sh` to include the links working. #7 had put the outbound check
behind `--network`.
**Decision:**
- A plain `./test.sh` checks every link. A new "Links in the page" section (offline, after every
  build) checks that each anchor has its target, each local path is a built file, the 404 page
  links home, and each card links to exactly the URL in its item file.
- The outbound check now reads the built page, the URLs visitors actually click, plus every
  `CREDITS.md` source, with one retry on a network error or 5xx. `--offline` skips only the
  outbound check.
- CI per push runs `./test.sh --offline`. A new weekly workflow (`links.yml`, Mondays 13:00 UTC)
  runs the full `./test.sh`, so a dead product page fails within a week without an outside site's
  outage failing an unrelated push.
- Hosts that answer bots with a Cloudflare challenge (usmint.gov ×2, america250.org) stay SKIP with
  that reason. No script can see past it.

Rejected: the outbound check on every push. It is the same reason as in #7.
**Verified:**
- `./test.sh` → `129 passed, 0 failed, 2 warnings, 4 skipped`, including `22 outbound URLs checked
  (from the built page and CREDITS.md)` and 3 Cloudflare SKIPs.
- `./test.sh --offline` → `109 passed, 0 failed`, with `SKIP --offline: outbound links not checked`.
- Deliberate breaks in `dist/index.html` were each caught:
  - anchor `#h-coins`: `anchors with no target`
  - a card URL changed to `…federalist-paperz`: `card links differ from the item files`, and
    `404 https://guides.loc.gov/federalist-paperz`
- `links.yml` run 39468086901 (workflow_dispatch on `a25afd6`) → success, `130 passed, 0 failed, 1 warnings, 4 skipped`. Per-push `site`, `security` and post-deploy `live` → success.

## 9. An eagle banner across the top replaces the round portrait
**Date:** 2026-10-20
**Context:** Pieter asked for an eagle at the top. The 88px round portrait beside the title read
as too small.
**Decision:** A full-width banner of a bald eagle in flight: USFWS, public domain, 2000×720 WebP,
17 KB. It keeps its shape up to 1280px; beyond that the sky colour (`#c9cbdb`) fills both sides and
the photo's edges are faded in, so the eagle never grows past about 460px tall. On phones it keeps
at least 150px of height and loses sky at the sides, not the eagle. The portrait is removed:
two eagles at the top would compete. Rejected:
- A bigger portrait above the title.
- An SVG emblem in the top stripe.
- The Great Seal: its display is restricted, as in #6.
**Verified:** `./test.sh` → `132 passed, 0 failed`, including `the eagle banner spans the top of
the page` at 1280, 375 and 320px and `src/assets/eagle-banner.webp (17 KB)`. Screenshots at 375,
1280 and 1920px show the whole eagle, wingtips to tail, with no seam at 1920.

## 10. Header bunting is a drawn SVG, not the reference photo
**Date:** 2026-10-20
**Context:** Pieter shared a photo of pleated half-fan bunting and asked for a ribbon like it in
the header. The photo looks like a retailer's product shot, and its license is unknown.
**Decision:** `public/bunting.svg`, drawn for the site. Bands run red, cream, navy with 13 white
stars, cream, then a red centre. Each of 16 pleats is shaded light and dark, and the hem is gently
scalloped. A CSS `repeat-x` hangs a row of fans across the top of every page, replacing the
dashed stripe. Rejected:
- Using the reference photo: unknown license, and a raster file that would blur when scaled.
- A single large fan: it competes with the eagle banner directly below.
**Verified:** `./test.sh` → `bunting hangs across the top of every page` passes on `/` and the 404
page at 1280, 375 and 320px, and `dist/bunting.svg` is present. Screenshots at 375 and 1280px show
an unbroken garland above the banner.

## 11. The eagle banner is a short fixed band (supersedes #9's sizing)
**Date:** 2026-10-20
**Context:** Pieter: the header banner needs to be less tall. At 1280px it was about 460px, which
pushed the title below the first screen.
**Decision:** `.banner-wrap` is `clamp(130px, 20vw, 260px)` tall. The photo is shown whole at that
height (`object-fit: contain`), centred on its sky colour with 10% faded edges at every width.
Rejected: cropping the photo shorter. In a 1280×260 frame that cuts the wingtips or the tail, and
the eagle is the point.
**Verified:** `./test.sh` → `the eagle banner spans the page directly under the bunting` passes at
1280, 375 and 320px. It asserts a height between 130 and 265px and `object-fit: contain`, which
never crops. Screenshots: 130px at 375, 256px at 1280, whole eagle in
both.

## 12. The site sells nothing itself; items come from other shops
**Date:** 2026-10-20
**Context:** Pieter: the items are offered by other shops (the silver coin by APMEX and others).
The goal is to make sending a package to a friend or relative as frictionless as possible.
**Decision:** No own stock and no own store. Shoppable means coordinating purchases at the shops
that sell each item: buy links with offers, then a guided checklist, then a hand-run concierge
pilot. The approaches and the path are in `docs/shoppable.md`. Rejected: the stock-holding options
in the first `docs/package-builder.md` draft (own checkout for stocked items, a hosted store
holding inventory).
**Verified:** `grep -c '^## ' docs/shoppable.md` → `6` sections, starting with "The goal".
`docs/package-builder.md` § Buying and sending points to it, and the stock options are removed
(`grep -c 'Checkout for stocked items' docs/package-builder.md` → `0`).
