# Image credits

Every picture on the site is public domain, CC0, or marked "No restrictions" by its holder. No
image under an attribution or share-alike license is used, so the repo stays CC0 (`docs/DECISIONS.md`
#6). Each was downloaded from Wikimedia Commons on 2026-10-20 (the header eagle on 2026-10-21), then cropped and re-encoded as WebP.
The source page has the full provenance.

| File | License | Author or source | Source page |
|---|---|---|---|
| `src/assets/items/capitol-flag.webp` | Public domain | USCapitol | [Commons](https://commons.wikimedia.org/wiki/File:Flickr_-_USCapitol_-_Flag_Flying_on_the_U.S._Capitol.jpg) |
| `src/assets/items/constitution.webp` | Public domain | Constitutional Convention | [Commons](https://commons.wikimedia.org/wiki/File:United_States_Constitution.jpg) |
| `src/assets/items/declaration-of-independence.webp` | No restrictions | The U.S. National Archives | [Commons](https://commons.wikimedia.org/wiki/File:Engrossed_Declaration_of_Independence_%283678682267%29.jpg) |
| `src/assets/header-eagle.webp` | Public domain | Lisa Hupp, U.S. Fish and Wildlife Service | [Commons](https://commons.wikimedia.org/wiki/File:Bald_eagle_in_flight_%2851080613667%29.jpg) |
| `src/assets/items/federalist-papers.webp` | Public domain | Publius (pseudonym) [Alexander Hamilton, John Jay, James Madison]. | [Commons](https://commons.wikimedia.org/wiki/File:The_Federalist_%281st_ed,_1788,_vol_I,_title_page%29.jpg) |
| `src/assets/items/founding-era-timeline.webp` | Public domain | John Trumbull | [Commons](https://commons.wikimedia.org/wiki/File:Declaration_of_Independence_%281819%29,_by_John_Trumbull.jpg) |
| `src/assets/items/historical-newspaper.webp` | Public domain | Pennsylvania Evening Post | [Commons](https://commons.wikimedia.org/wiki/File:Declaration_First_Newspaper_Printing.jpg) |
| `src/assets/items/liberty-bell-replica.webp` | Public domain | Robin Miller, National Park Service Digital Image Archives | [Commons](https://commons.wikimedia.org/wiki/File:Independence_National_Historical_Park_Liberty_Bell_at_the_LBC.jpg) |
| `src/assets/items/mint-coin-set.webp` | Public domain | United States Mint | [Commons](https://commons.wikimedia.org/wiki/File:2019_US_Mint_silver_proof_set.jpg) |
| `src/assets/items/silver-coin.webp` | Public domain | United States Mint | [Commons](https://commons.wikimedia.org/wiki/File:American_Silver_Eagle,_obverse,_2022.jpg) |

`src/assets/header-flag.webp`, the waving flag behind the eagle, was drawn for this site by
`scripts/header/make.sh` (generated, no source image) and is CC0 like the rest of the repo. The
eagle on it is the USFWS photo above, cut out of its sky by the same script. The Great Seal of the
United States was deliberately not used: 18 U.S.C. § 713 restricts its display.

## Shown from the seller's site, not in this repo

One product photo is loaded from the seller's own site when the page opens. It is not copied into
this repo, so the repo's CC0 does not cover it: the seller's copyright applies (`docs/DECISIONS.md`
#13). Hosts allowed for this are listed in `HOTLINK_HOSTS` in `src/consts.ts`.

| Item | Rights | Holder | Image |
|---|---|---|---|
| 250 Years of American History | All rights reserved | Proud Patriots | [illustration from the military chapter](https://proudpatriots.com/cdn/shop/files/Screenshot_2026-03-31_at_14.06.13.png?v=1774980491) |
