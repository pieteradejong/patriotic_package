# Deployment

The site is hosted on **Vercel** as project `patriot-package` (team `pieteradejongs-projects`) and
served at **https://patriot-package.vercel.app**. Why it works this way: `docs/DECISIONS.md` #2.

## How a change goes live

- **Push to `main`.** Vercel builds (`astro build`, with Node from `package.json` `engines`) and
  publishes `dist/` as production. There is no deploy script.
- **Any other branch or a pull request** gets a preview URL, which Vercel posts on the PR.

Vercel does not run the tests. GitHub runs workflow `site` (`.github/workflows/ci.yml`):

| Job | When | Runs |
|---|---|---|
| `tests` | every push to `main` and every PR | `./test.sh` |
| `live` | Vercel reports a successful production deployment | `./test.sh --live https://patriot-package.vercel.app` |

Before `live` runs its tests, it waits until the site serves the deployed commit. It reads that
from `<meta name="build-commit">`, so if production lags behind the commit, the job fails.
Workflow `security` runs gitleaks and the gate on every push and PR.

To check a deployment by hand:

```bash
./test.sh --live https://patriot-package.vercel.app
gh workflow run ci.yml -f url=https://patriot-package.vercel.app && gh run watch
```

## Rollback

```bash
vercel rollback                  # back to the previous production deployment
vercel ls patriot-package        # list deployments
```

The dashboard has the same under the project's Deployments tab. A rollback is undone by the next
push to `main`.

## Configuration

- **Build settings live in `vercel.json`** (framework `astro`, `npm run build`, output `dist`), not in
  the dashboard. The project was created by the CLI with preset "Other" and output `public`, which
  would have deployed the wrong directory.
- **Output:** fully static. Add the `@astrojs/vercel` adapter only when a page needs server
  rendering.
- **Environment variables:** none.
- **Analytics:** Vercel Web Analytics (cookie-less), via `<Analytics />` in `src/layouts/Base.astro`.
  It needs Web Analytics turned on for the project; until then, `test.sh --live` warns that the
  script is not served.
- **Node:** `engines` `22.x` in `package.json` decides the version on Vercel; CI reads `.nvmrc`.
  Change both together.
- **Local link:** `vercel link` writes `.vercel/` (gitignored), which only the CLI needs.

## Plan limits

Hobby (free) plan: personal, non-commercial use only. Move to Pro before the site sells anything.
