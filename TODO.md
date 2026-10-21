# TODO

- [x] See a `live` run started by `deployment_status` (not dispatch) go green, and complete `Verified:`, 2026-10-20 — docs/DECISIONS.md #2
- [x] Turn on Vercel Web Analytics for `patriot-package` (`test.sh --live` warns until then), 2026-10-20 — DEPLOYMENT.md § Configuration
- [ ] Decide the speculative items and add `source`/`priceUsd` (and a buy `link` where one exists) to the confirmed ones, 2026-10-20 — README § The list
- [x] Pick the actual "250 Years of American History" book, then add its cover (if licensable) and a buy link, 2026-10-20 — docs/DECISIONS.md #6
- [x] Add a weekly scheduled `./test.sh --network` job (like astropieter's link report) once the item list settles, 2026-10-20 — docs/DECISIONS.md #7
- [ ] Open the three Cloudflare-blocked links in a browser and confirm each page is right (usmint.gov American Eagle coins, usmint.gov proof sets, america250.org About; proudpatriots.com too if it starts answering 429), 2026-10-20 — docs/DECISIONS.md #8
- [ ] Answer the open questions in docs/shoppable.md (affiliate links, concierge fee, shops per item, claim link, delivery promise) and docs/package-builder.md (presets, price ceiling, Capitol flag, box), then pick the first step, 2026-10-20 — docs/shoppable.md § Suggested path
- [ ] Move the untracked `AUDIT_2026-09-01.md` out of the repo to `~/dev/audit-reports/` (audit output never goes in a git repo, so it was left out of the 2026-10-21 push), 2026-10-21 — ~/dev/CLAUDE.md § Hard rules
- [x] See the `site` and post-deploy `live` runs for `25d1285` (new eagle-and-flag header) go green, 2026-10-21 — docs/DECISIONS.md #15 — done 2026-10-21: push, security and deployment_status runs green; live build-commit is 25d1285
