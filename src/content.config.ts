// One Markdown file per package item in src/content/items/. A file that does
// not match this schema fails the build, so a typo never reaches the site.
import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { glob } from 'astro/loaders';
import { CATEGORIES, type Category, HOTLINK_HOSTS } from './consts';

const link = z.object({ url: z.url({ protocol: /^https$/ }), label: z.string().min(1) });
const hotlinkHost = (u: string) => HOTLINK_HOSTS.some((h) => new URL(u).hostname === h);

const items = defineCollection({
	loader: glob({ pattern: '**/[^_]*.md', base: './src/content/items' }),
	schema: ({ image }) => z.object({
		title: z.string().min(1),
		category: z.enum(Object.keys(CATEGORIES) as [Category, ...Category[]]),
		// confirmed: in the package. speculative: an idea not yet decided.
		status: z.enum(['confirmed', 'speculative']),
		order: z.number().int(),
		// One line under the title: author, pages, format.
		byline: z.string().min(1).optional(),
		// A photo in src/assets/items/, public domain or CC0 only, credited in CREDITS.md.
		image: image().optional(),
		// Or the seller's own product photo, shown from their site (DECISIONS #13).
		imageUrl: z.url({ protocol: /^https$/ }).refine(hotlinkHost, { message: `imageUrl host must be one of ${HOTLINK_HOSTS.join(', ')}` }).optional(),
		imageAlt: z.string().optional(),
		// Where to get it (a shop) or read about it. Check the URL resolves.
		link: link.optional(),
		// A second link, to background on the item from an official source (DECISIONS #14).
		about: link.optional(),
		source: z.string().optional(),
		priceUsd: z.number().positive().optional(),
	})
		.refine((d) => !(d.image && d.imageUrl), { message: 'use image or imageUrl, not both' })
		.refine((d) => !(d.image || d.imageUrl) || !!d.imageAlt, { message: 'an item with an image needs imageAlt' }),
});

export const collections = { items };
