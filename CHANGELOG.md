# Changelog

All notable changes to this site. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The site is unversioned (every push to `main` deploys).

## [Unreleased]

### Added
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
