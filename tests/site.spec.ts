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

test('every link and chip is at least 24x24 px (WCAG 2.5.8)', async ({ page }) => {
	await page.goto('/');
	const small = await page.locator('a:visible').evaluateAll((els) =>
		els.map((e) => ({ t: e.textContent?.trim(), r: e.getBoundingClientRect() }))
			.filter(({ r }) => r.width < 24 || r.height < 24)
			.map(({ t, r }) => `${t} ${Math.round(r.width)}x${Math.round(r.height)}`));
	expect(small).toEqual([]);
});

test('jump nav has one link per section and lands below the sticky bar', async ({ page }) => {
	await page.goto('/');
	const sections = await page.locator('main section h2').count();
	await expect(page.locator('nav.jump a')).toHaveCount(sections);
	await page.locator('nav.jump a', { hasText: 'Coins' }).click();
	const heading = page.locator('#h-coin');
	await expect(heading).toBeInViewport();
	const navBottom = (await page.locator('nav.jump').boundingBox())!;
	const h = (await heading.boundingBox())!;
	expect(h.y).toBeGreaterThanOrEqual(Math.max(0, navBottom.y + navBottom.height) - 1);
});

test('jump nav stays at the top on phones', async ({ page }, info) => {
	test.skip(info.project.name === 'desktop', 'the nav is static on desktop');
	await page.goto('/');
	await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
	await expect.poll(async () => (await page.locator('nav.jump').boundingBox())!.y).toBe(0);
});

test('the Idea badge sits above the title on every idea card', async ({ page }) => {
	await page.goto('/');
	for (const card of await page.locator('[data-status="speculative"]').all()) {
		const badge = (await card.locator('.badge').boundingBox())!;
		const title = (await card.locator('h3').boundingBox())!;
		expect(badge.y + badge.height).toBeLessThanOrEqual(title.y + 1);
	}
});

test('photos load, have alt text and fit their card', async ({ page }) => {
	await page.goto('/');
	const photos = page.locator('img.photo');
	expect(await photos.count()).toBeGreaterThan(0);
	for (const img of await photos.all()) {
		await img.scrollIntoViewIfNeeded();
		await expect(img).toHaveAttribute('alt', /\S/);
		await expect.poll(() => img.evaluate((i: HTMLImageElement) => i.complete && i.naturalWidth > 0)).toBe(true);
		const box = (await img.boundingBox())!;
		const card = (await img.locator('xpath=ancestor::li[1]').boundingBox())!;
		expect(box.x).toBeGreaterThanOrEqual(card.x - 1);
		expect(box.x + box.width).toBeLessThanOrEqual(card.x + card.width + 1);
	}
	const eagle = page.locator('img.eagle');
	await expect(eagle).toHaveAttribute('alt', 'A bald eagle');
	await expect.poll(() => eagle.evaluate((i: HTMLImageElement) => i.complete && i.naturalWidth > 0)).toBe(true);
});

test('every item links out over https', async ({ page }) => {
	await page.goto('/');
	for (const id of ITEM_IDS) {
		await expect(page.locator(`[data-item="${id}"] a.more`)).toHaveAttribute('href', /^https:\/\//);
	}
});

test('the header counts match the cards and explain the Idea badge', async ({ page }) => {
	await page.goto('/');
	const inPackage = await page.locator('[data-status="confirmed"]').count();
	const ideas = await page.locator('[data-status="speculative"]').count();
	const count = page.getByTestId('count');
	await expect(count).toContainText(`${inPackage} items are in the package.`);
	await expect(count).toContainText(`${ideas} more are ideas still being decided, each marked Idea.`);
});
