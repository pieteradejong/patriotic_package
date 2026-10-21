// Category keys used in item frontmatter, with the heading each gets on the page.
export const CATEGORIES = {
	document: 'Founding documents',
	book: 'Books',
	coin: 'Coins',
	keepsake: 'Keepsakes',
} as const;

export type Category = keyof typeof CATEGORIES;

// Hosts an item's imageUrl may point at: sellers whose product photo is shown
// from their own site, not copied into the repo (DECISIONS #13).
export const HOTLINK_HOSTS = ['proudpatriots.com'];
