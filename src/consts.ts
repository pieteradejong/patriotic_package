// Category keys used in item frontmatter, with the heading each gets on the page.
export const CATEGORIES = {
	document: 'Founding documents',
	book: 'Books',
	coin: 'Coins',
	keepsake: 'Keepsakes',
} as const;

export type Category = keyof typeof CATEGORIES;
