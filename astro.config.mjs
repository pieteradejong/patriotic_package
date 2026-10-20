// Static Astro site, deployed by Vercel's Git integration (DEPLOYMENT.md).
import { defineConfig } from 'astro/config';
import { execSync } from 'node:child_process';
import sitemap from '@astrojs/sitemap';

// Build stamp: the commit this build came from. Vercel sets
// VERCEL_GIT_COMMIT_SHA at build time; locally ask git. Base.astro writes it
// as <meta name="build-commit">, and `test.sh --live` compares it with
// origin/main, so production lagging the repo fails instead of going unnoticed.
const buildCommit = process.env.VERCEL_GIT_COMMIT_SHA
	|| (() => {
		try { return execSync('git rev-parse HEAD', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); }
		catch { return ''; }
	})();

export default defineConfig({
	site: 'https://patriot-package.vercel.app',
	integrations: [sitemap()],
	vite: {
		define: { __BUILD_COMMIT__: JSON.stringify(buildCommit) },
	},
});
