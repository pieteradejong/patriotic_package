// Repo checks that are easier in Node than in shell. test.sh calls one section at a
// time and reads one verdict per line: "PASS|FAIL|WARN|SKIP<TAB>message".
//
//   node scripts/checks.mjs deps      package.json, lockfile and node_modules agree
//   node scripts/checks.mjs config    pins, Node versions, license, vercel.json, workflow SHAs
//   node scripts/checks.mjs content   items, links, images, CREDITS.md
//   node scripts/checks.mjs network   every outbound link answers (needs the network)
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
const EAGLE_SIZE = [320, 320];
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
		'src/assets/eagle.webp',
		...readdirSync('src/assets/items').filter((f) => !f.startsWith('.')).map((f) => `src/assets/items/${f}`),
	];
	const referenced = new Set(list.filter((i) => i.image).map((i) => join(ITEMS_DIR, i.image)));
	referenced.add('src/assets/eagle.webp');
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
			const [w, h] = a.endsWith('eagle.webp') ? EAGLE_SIZE : CARD_SIZE;
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

// A host answering a bot challenge (Cloudflare 403 + cf-mitigated) cannot be judged from here.
async function network() {
	const urls = new Map();
	for (const i of items()) if (i.url) urls.set(i.url, i.id);
	for (const [, u] of read('CREDITS.md').matchAll(/\]\((https:[^)]+)\)/g)) urls.set(u, 'CREDITS.md');
	await Promise.all([...urls].map(async ([u, from]) => {
		try {
			const r = await fetch(u, { redirect: 'follow', signal: AbortSignal.timeout(20000), headers: { 'user-agent': 'Mozilla/5.0 patriot-package-linkcheck' } });
			if (r.ok) pass(`${r.status} ${u}`);
			else if (r.status === 403 && (r.headers.get('cf-mitigated') || r.headers.get('server') === 'cloudflare')) skip(`${u} (${from}) answers a bot challenge; check it in a browser`);
			else fail(`${r.status} ${u} (${from})`);
		} catch (e) { fail(`${u} (${from}): ${e.cause?.code ?? e.message}`); }
	}));
}

const sections = { deps, config, content, network };
const which = process.argv[2];
if (!sections[which]) { console.error(`usage: node scripts/checks.mjs ${Object.keys(sections).join('|')}`); process.exit(2); }
try { await sections[which](); } catch (e) { fail(`${which} check crashed: ${e.message}`); }
