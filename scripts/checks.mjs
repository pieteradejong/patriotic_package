// Repo checks that are easier in Node than in shell. test.sh calls one section at a
// time and reads one verdict per line: "PASS|FAIL|WARN|SKIP<TAB>message".
//
//   node scripts/checks.mjs deps      package.json, lockfile and node_modules agree
//   node scripts/checks.mjs config    pins, Node versions, license, vercel.json, workflow SHAs
//   node scripts/checks.mjs content   items, links, images, CREDITS.md
//   node scripts/checks.mjs links     links inside the built page (needs dist/)
//   node scripts/checks.mjs network [dist]  every outbound link answers (needs the network)
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const out = (v, m) => console.log(`${v}\t${m}`);
const pass = (m) => out('PASS', m);
const fail = (m) => out('FAIL', m);
const warn = (m) => out('WARN', m);
const skip = (m) => out('SKIP', m);
const read = (f) => readFileSync(f, 'utf8');
const json = (f) => JSON.parse(read(f));

const ITEMS_DIR = 'src/content/items';
const IMAGE_BUDGET_KB = 120;
const CARD_SIZE = [800, 600];
const BANNER = 'src/assets/eagle-banner.webp';
const BANNER_SIZE = [2000, 720];
const HOLDER = 'Pieter de Jong';

// Minimal frontmatter reader: the item files use flat keys plus one nested `link`.
function items() {
	return readdirSync(ITEMS_DIR)
		.filter((f) => f.endsWith('.md') && !f.startsWith('_'))
		.map((f) => {
			const text = read(join(ITEMS_DIR, f));
			const fm = text.split('\n---')[0];
			const get = (re) => (fm.match(re) || [])[1]?.replace(/^"|"$/g, '');
			return {
				id: f.replace(/\.md$/, ''),
				image: get(/^image:\s*(.+)$/m),
				imageAlt: get(/^imageAlt:\s*(.+)$/m),
				url: get(/^\s+url:\s*(.+)$/m),
				label: get(/^\s+label:\s*(.+)$/m),
			};
		});
}

function deps() {
	const pkg = json('package.json');
	const lock = json('package-lock.json');
	const root = lock.packages?.[''] ?? {};
	for (const field of ['dependencies', 'devDependencies']) {
		const want = pkg[field] ?? {};
		const got = root[field] ?? {};
		const diff = [...new Set([...Object.keys(want), ...Object.keys(got)])].filter((k) => want[k] !== got[k]);
		diff.length ? fail(`package-lock.json ${field} differ from package.json: ${diff.join(', ')} (run npm install)`)
			: pass(`package-lock.json ${field} match package.json`);
	}
	const stale = [];
	for (const name of Object.keys({ ...pkg.dependencies, ...pkg.devDependencies })) {
		const f = join('node_modules', name, 'package.json');
		const want = lock.packages?.[`node_modules/${name}`]?.version;
		if (!existsSync(f)) stale.push(`${name} missing`);
		else if (json(f).version !== want) stale.push(`${name} ${json(f).version} != lock ${want}`);
	}
	stale.length ? fail(`node_modules out of date: ${stale.join('; ')} (run ./init.sh)`)
		: pass('node_modules matches the lockfile for every direct dependency');
}

function config() {
	const pkg = json('package.json');
	const ranges = Object.entries({ ...pkg.dependencies, ...pkg.devDependencies }).filter(([, v]) => !/^\d+\.\d+\.\d+$/.test(v));
	ranges.length ? fail(`not an exact pin: ${ranges.map(([k, v]) => `${k}@${v}`).join(', ')}`)
		: pass('every dependency is an exact pin');

	const nvm = read('.nvmrc').trim();
	const engines = pkg.engines?.node ?? '';
	engines.split('.')[0] === nvm.split('.')[0]
		? pass(`.nvmrc (${nvm}) and engines.node (${engines}) agree`)
		: fail(`.nvmrc is ${nvm} but engines.node is ${engines} (Vercel uses engines, CI uses .nvmrc)`);

	pkg.license === 'CC0-1.0' ? pass('package.json license is CC0-1.0') : fail(`package.json license is ${pkg.license}`);
	const lic = read('LICENSE');
	lic.includes(HOLDER) && lic.includes('CC0 1.0 Universal')
		? pass(`LICENSE is CC0 1.0 and names ${HOLDER}`)
		: fail(`LICENSE must be CC0 1.0 and name ${HOLDER} (the push gate's license-holder check)`);

	try {
		const v = json('vercel.json');
		v.framework === 'astro' && v.outputDirectory === 'dist'
			? pass('vercel.json pins framework astro and output dist')
			: fail(`vercel.json has framework ${v.framework}, output ${v.outputDirectory}`);
	} catch (e) { fail(`vercel.json does not parse: ${e.message}`); }

	const bad = [];
	let security = false;
	for (const f of readdirSync('.github/workflows').filter((f) => /\.ya?ml$/.test(f))) {
		for (const [, ref] of read(join('.github/workflows', f)).matchAll(/^\s*(?:-\s*)?uses:\s*(\S+)/gm)) {
			if (ref.startsWith('pieteradejong/dotfiles/.github/workflows/security-reusable.yml@')) { security = true; continue; }
			if (!/@[0-9a-f]{40}$/.test(ref)) bad.push(`${f}: ${ref}`);
		}
	}
	bad.length ? fail(`actions not pinned by commit SHA: ${bad.join(', ')}`) : pass('every action is pinned by commit SHA');
	security ? pass('a workflow calls security-reusable.yml') : fail('no workflow calls security-reusable.yml');
}

async function content() {
	const list = items();
	const credits = existsSync('CREDITS.md') ? read('CREDITS.md') : '';
	if (!credits) fail('CREDITS.md is missing');

	const noLink = list.filter((i) => !i.url).map((i) => i.id);
	noLink.length ? fail(`items without a link: ${noLink.join(', ')}`) : pass(`all ${list.length} items have a link`);
	const insecure = list.filter((i) => i.url && !i.url.startsWith('https://')).map((i) => i.id);
	insecure.length ? fail(`links not on https: ${insecure.join(', ')}`) : pass('every link is https');

	const noImage = list.filter((i) => !i.image).map((i) => i.id);
	noImage.length ? warn(`items without a photo: ${noImage.join(', ')}`) : pass('every item has a photo');

	let sharp;
	try { sharp = (await import('sharp')).default; } catch { skip('sharp not installed; image dimensions not checked'); }

	const assets = [
		BANNER,
		...readdirSync('src/assets/items').filter((f) => !f.startsWith('.')).map((f) => `src/assets/items/${f}`),
	];
	const referenced = new Set(list.filter((i) => i.image).map((i) => join(ITEMS_DIR, i.image)));
	referenced.add(BANNER);
	for (const r of referenced) if (!existsSync(r)) fail(`referenced image missing: ${r}`);

	for (const a of assets) {
		const problems = [];
		if (!a.endsWith('.webp')) problems.push('not WebP');
		if (!referenced.has(a)) problems.push('not used by any item');
		if (!credits.includes('`' + a + '`')) problems.push('no row in CREDITS.md');
		const kb = Math.round(statSync(a).size / 1024);
		if (kb > IMAGE_BUDGET_KB) problems.push(`${kb} KB > ${IMAGE_BUDGET_KB} KB`);
		if (sharp) {
			const { width, height } = await sharp(a).metadata();
			const [w, h] = a === BANNER ? BANNER_SIZE : CARD_SIZE;
			if (width !== w || height !== h) problems.push(`${width}x${height}, expected ${w}x${h}`);
		}
		problems.length ? fail(`${a}: ${problems.join('; ')}`) : pass(`${a} (${kb} KB)`);
	}
	for (const [, f] of credits.matchAll(/^\| `([^`]+)`/gm)) if (!existsSync(f)) fail(`CREDITS.md lists ${f}, which does not exist`);
	const licenses = [...credits.matchAll(/^\| `[^`]+` \| ([^|]+) \|/gm)].map((m) => m[1].trim());
	const notFree = licenses.filter((l) => !['Public domain', 'CC0', 'No restrictions'].includes(l));
	notFree.length ? fail(`CREDITS.md has images that are not public domain or CC0: ${notFree.join(', ')}`)
		: pass(`all ${licenses.length} credited images are public domain, CC0 or no restrictions`);
}

// Links inside the built page: every #anchor has its target, every local path is
// a file in dist/, and each card links to exactly the URL its item file names.
function links() {
	if (!existsSync('dist/index.html')) return fail('dist/index.html missing (build first)');
	const html = read('dist/index.html');
	const hrefs = [...html.matchAll(/<a\b[^>]*\bhref="([^"]*)"/g)].map((m) => m[1].replace(/&amp;/g, '&'));
	const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]));
	const anchors = hrefs.filter((h) => h.startsWith('#'));
	const brokenAnchors = anchors.filter((h) => !ids.has(h.slice(1)));
	brokenAnchors.length ? fail(`anchors with no target: ${brokenAnchors.join(', ')}`) : pass(`all ${anchors.length} in-page anchors have a target`);
	const html404 = existsSync('dist/404.html') ? read('dist/404.html') : '';
	const local = [...hrefs, ...[...html404.matchAll(/<a\b[^>]*\bhref="([^"]*)"/g)].map((m) => m[1])].filter((h) => h.startsWith('/'));
	const missing = local.filter((h) => {
		const path = join('dist', h.split(/[?#]/)[0]);
		return !(existsSync(path) && statSync(path).isFile()) && !existsSync(join(path, 'index.html'));
	});
	missing.length ? fail(`local links to missing files: ${missing.join(', ')}`) : pass(`all ${local.length} local links point to a built file`);
	const notFound = html404.match(/<a\b[^>]*\bhref="([^"]*)"[^>]*>Back to the package/);
	notFound?.[1] === '/' ? pass('404 page links back to /') : fail('404 page has no "Back to the package" link to /');
	const odd = hrefs.filter((h) => !/^(#|\/|https:\/\/)/.test(h));
	odd.length ? fail(`links that are not https, local or an anchor: ${odd.join(', ')}`) : pass('every link is https, local or an anchor');
	const wrong = [];
	for (const i of items()) {
		const card = html.match(new RegExp(`data-item="${i.id}"[\\s\\S]*?</li>`))?.[0] ?? '';
		const got = [...card.matchAll(/<a\b[^>]*class="more"[^>]*href="([^"]*)"|<a\b[^>]*href="([^"]*)"[^>]*class="more"/g)].map((m) => (m[1] ?? m[2]).replace(/&amp;/g, '&'));
		if (got.length !== 1 || got[0] !== i.url) wrong.push(`${i.id}: page has ${got.join(' ') || 'no link'}, item file says ${i.url}`);
	}
	wrong.length ? fail(`card links differ from the item files: ${wrong.join('; ')}`) : pass('every card links to the URL in its item file');
}

// Every outbound URL answers. From the built page when there is one (what visitors
// click), else from the item files; plus every source page in CREDITS.md. One retry
// on a network error or 5xx. A host answering a bot challenge (403 from Cloudflare)
// cannot be judged from a script and is skipped with that reason, never passed.
async function network() {
	const urls = new Map();
	const fromDist = process.argv[3] === 'dist' && existsSync('dist/index.html');
	if (fromDist) {
		for (const [, u] of read('dist/index.html').matchAll(/<a\b[^>]*\bhref="(https:[^"]+)"/g)) urls.set(u.replace(/&amp;/g, '&'), 'page');
	} else {
		for (const i of items()) if (i.url) urls.set(i.url, i.id);
	}
	for (const [, u] of read('CREDITS.md').matchAll(/\]\((https:[^)]+)\)/g)) urls.set(u, 'CREDITS.md');
	const get = (u) => fetch(u, { redirect: 'follow', signal: AbortSignal.timeout(20000), headers: { 'user-agent': 'Mozilla/5.0 patriot-package-linkcheck' } });
	await Promise.all([...urls].map(async ([u, from]) => {
		let r;
		for (let attempt = 1; attempt <= 2; attempt++) {
			try { r = await get(u); if (r.status < 500) break; } catch (e) { r = e; }
			await new Promise((ok) => setTimeout(ok, 2000));
		}
		if (r instanceof Error) fail(`${u} (${from}): ${r.cause?.code ?? r.message}`);
		else if (r.ok) pass(`${r.status} ${u}`);
		else if (r.status === 403 && (r.headers.get('cf-mitigated') || r.headers.get('server') === 'cloudflare')) skip(`${u} (${from}) answers a bot challenge; check it in a browser`);
		else fail(`${r.status} ${u} (${from})`);
	}));
	pass(`${urls.size} outbound URLs checked (${fromDist ? 'from the built page' : 'from the item files'} and CREDITS.md)`);
}

const sections = { deps, config, content, links, network };
const which = process.argv[2];
if (!sections[which]) { console.error(`usage: node scripts/checks.mjs ${Object.keys(sections).join('|')}`); process.exit(2); }
try { await sections[which](); } catch (e) { fail(`${which} check crashed: ${e.message}`); }
