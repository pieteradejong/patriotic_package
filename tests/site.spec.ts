// Smoke tests for the package page, run at desktop and phone widths
// (playwright.config.ts projects) against BASE_URL.
import { readdirSync } from 'node:fs';
import { expect, test } from '@playwright/test';

const ITEM_IDS = readdirSync(new URL('../src/content/items/', import.meta.url))
	.filter((f) => f.endsWith('.md') && !f.startsWith('_'))
	.map((f) => f.replace(/\.md$/, ''));

test('home page renders every item with no console errors', async ({ page }) => {
	const errors: string[] = [];
	page.on('console', (m) => { if (m.type() === 'error') errors.push(`${m.text()} (${m.location().url})`); });
	page.on('pageerror', (e) => errors.push(e.message));
	const res = await page.goto('/');
	expect(res?.status()).toBe(200);
	await expect(page.getByRole('heading', { level: 1 })).toHaveText('Patriot Package');
	for (const id of ITEM_IDS) await expect(page.locator(`[data-item="${id}"]`)).toBeVisible();
	await expect(page.locator('[data-status="speculative"] .badge').first()).toBeVisible();
	// Vercel's analytics script 404s off Vercel; ignore it locally.
	expect(errors.filter((e) => !/_vercel\/insights/.test(e))).toEqual([]);
});

test('no horizontal scroll', async ({ page }) => {
	await page.goto('/');
	const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
	expect(overflow).toBeLessThanOrEqual(0);
});

test('missing route serves the 404 page', async ({ page }) => {
	const res = await page.goto('/this-page-does-not-exist');
	expect(res?.status()).toBe(404);
	await expect(page.getByRole('heading', { level: 1 })).toHaveText('Page not found');
	await expect(page.getByRole('link', { name: 'Back to the package' })).toHaveAttribute('href', '/');
});
