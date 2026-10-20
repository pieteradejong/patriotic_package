import { existsSync } from 'node:fs';
import { defineConfig } from '@playwright/test';

// Browser tests for the built site. They run against a server that is already
// up — test.sh starts `astro preview` on :4322 (it daemonizes, which
// Playwright's webServer option cannot manage), and `test.sh --live` points
// BASE_URL at the deployment.
//
// Uses an installed Chrome when there is one; CHROME_PATH overrides. With none
// found (CI), Playwright falls back to its own Chromium
// (`npx playwright install chromium`).
const CHROME = [
	process.env.CHROME_PATH,
	'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
	'/usr/bin/google-chrome',
].find((p): p is string => !!p && existsSync(p));

export default defineConfig({
	testDir: './tests',
	fullyParallel: true,
	retries: 0,
	reporter: 'list',
	use: {
		baseURL: process.env.BASE_URL ?? 'http://localhost:4322',
		headless: true,
		launchOptions: CHROME ? { executablePath: CHROME } : {},
	},
	projects: [
		{ name: 'desktop', use: { viewport: { width: 1280, height: 800 } } },
		{ name: 'mobile', use: { viewport: { width: 375, height: 740 }, isMobile: true, hasTouch: true } },
	],
});
