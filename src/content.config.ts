// One Markdown file per package item in src/content/items/. A file that does
// not match this schema fails the build, so a typo never reaches the site.
import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { glob } from 'astro/loaders';
import { CATEGORIES, type Category } from './consts';

const items = defineCollection({
	loader: glob({ pattern: '**/[^_]*.md', base: './src/content/items' }),
	schema: z.object({
		title: z.string().min(1),
		category: z.enum(Object.keys(CATEGORIES) as [Category, ...Category[]]),
		// confirmed: in the package. speculative: an idea not yet decided.
		status: z.enum(['confirmed', 'speculative']),
		order: z.number().int(),
		source: z.string().optional(),
		buyUrl: z.string().url().optional(),
		priceUsd: z.number().positive().optional(),
	}),
});

export const collections = { items };
