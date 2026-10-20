// One Markdown file per package item in src/content/items/. A file that does
// not match this schema fails the build, so a typo never reaches the site.
import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { glob } from 'astro/loaders';
import { CATEGORIES, type Category } from './consts';

const items = defineCollection({
	loader: glob({ pattern: '**/[^_]*.md', base: './src/content/items' }),
	schema: ({ image }) => z.object({
		title: z.string().min(1),
		category: z.enum(Object.keys(CATEGORIES) as [Category, ...Category[]]),
		// confirmed: in the package. speculative: an idea not yet decided.
		status: z.enum(['confirmed', 'speculative']),
		order: z.number().int(),
		// A photo in src/assets/items/, public domain or CC0 only, credited in CREDITS.md.
		image: image().optional(),
		imageAlt: z.string().optional(),
		// Where to read about it or get it. Official sources only; check the URL resolves.
		link: z.object({ url: z.url({ protocol: /^https$/ }), label: z.string().min(1) }).optional(),
		source: z.string().optional(),
		priceUsd: z.number().positive().optional(),
	}).refine((d) => !d.image || !!d.imageAlt, { message: 'an item with an image needs imageAlt' }),
});

export const collections = { items };
