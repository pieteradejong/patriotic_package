# Changelog

All notable changes to this site. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The site is unversioned (every push to `main` deploys).

## [Unreleased]

### Added
- A public-domain photo on nine of the ten items, and a link on every item to an official page
  (National Archives, U.S. Mint, Library of Congress, NPS, Architect of the Capitol) where one
  exists. A bald eagle sits in the header. Sources and licenses are in `CREDITS.md`, linked from
  the footer (DECISIONS #6).
- A category jump nav under the header: sticky chips on phones, a plain row on desktop
  (DECISIONS #5). `theme-color` for the mobile browser bar, and safe-area padding for notched
  phones.
- Browser tests at 320px. New tests: tap targets ≥ 24px, jump nav (including that it stays put on
  phones), badge position, photos loaded with alt text, and every item linking out over https.
  `test.sh` reports skipped browser tests as SKIP.
- The package list is a website: an Astro static site with one Markdown file per item in
  `src/content/items/`, grouped by category, with ideas not yet decided marked "Idea"
  (DECISIONS #1).
- `./init.sh`, `./run.sh` and `./test.sh` (`--live <url>` for the deployed site). The tests cover
  build, schema, content, meta, WCAG AA contrast, weight, hygiene and Playwright at desktop and
  phone widths.
- Deployment to https://patriot-package.vercel.app through Vercel's Git integration, with preview
  URLs for branches and pull requests. CI workflow `site` runs the tests on every push and PR and
  checks the live site after each production deploy. `security` runs gitleaks and the gate
  (DECISIONS #2). Build settings are pinned in `vercel.json`. `main` requires the CI
  checks (DECISIONS #4).

### Changed
- A full-width photo of a bald eagle in flight now runs across the top of the page, replacing the
  small round eagle portrait beside the title. Its shape is fixed up to 1280px. Wider screens get
  the photo's sky colour either side, with feathered edges; phones keep at least 150px of height.
  A browser test checks it at every width (DECISIONS #9).
- The header no longer says "4 items confirmed · 6 under consideration". It now reads "4 items are
  in the package. 6 more are ideas still being decided, each marked [Idea]." A browser test keeps
  both numbers in step with the cards.
- `./test.sh` checks every link by default. A new "Links in the page" section checks anchors, local
  paths, the 404 link home, and each card's URL against its item file. Outbound links are now read
  from the built page and retried once; `--offline` skips them. CI per push runs `--offline`, and
  the new weekly `links.yml` runs everything (DECISIONS #8).
- `./test.sh` now covers dependencies against the lockfile, the scripts themselves (bash 3.2,
  shellcheck, `--help`), config (pins, Node versions, license, `vercel.json`, Action SHAs), content
  and image rules against `CREDITS.md`, `astro check`, image output (`srcset`, lazy loading,
  dimensions) and media hygiene. Every section runs even after an earlier one fails, and the
  summary names the sections that failed. New flag: `--quick` (DECISIONS #7, superseded by #8).
- `./init.sh` is idempotent. It reuses `node_modules` while it matches the lockfile, installs the
  Playwright browser when there is no Chrome, generates Astro's types and checks for shellcheck.
  New flags: `--clean` and `--test`. `./run.sh` gains `lint` and `type-check`.
- Link schema: item links must be https (`z.url`).
- The "Idea" badge sits above the title on every card, instead of inline or wrapped depending on
  title length. Phones get less hero and card padding.
- Item frontmatter: `buyUrl` is replaced by `link` (`url` and `label`). `image` and `imageAlt` are
  new.

### Fixed
- Four Commons links in `CREDITS.md` contained parentheses and broke in Markdown; they are now
  percent-encoded. Found by `./test.sh --network`.
- The footer link was 16px tall on phones, below WCAG 2.5.8's 24px minimum target size; it is now
  44px.
