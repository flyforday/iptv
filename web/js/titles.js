// Nettoyage des titres des fournisseurs IPTV (même logique que l'app Android,
// lib/utils/title_cleaner.dart) : « |FR| Resident Evil (4K) » → « Resident Evil »,
// version « 4K ». Sert aussi à regrouper les doublons.

const LANG =
  'FR|EN|UK|US|DE|ES|IT|PT|NL|AR|TR|BE|CH|CA|QC|AF|MULTI|VF|VFF|VFQ|VO|' +
  'VOST|VOSTFR|4K|UHD|FHD|HD|SD|3D|NF|AMZ|DSNP|ATV|HBO|ALL';

const PREFIX = new RegExp(
  `^\\s*(?:[|\\[(]\\s*(?:${LANG})\\s*[|\\])]|(?:${LANG})\\s*(?:\\||:|-|–|»)\\s)\\s*`,
);
const PIPE_TAG = /\|\s*([^|]{1,12}?)\s*\|/g;

const QUALITY = [
  '4K LIGHT', '4K ULTRA HD', '4K ULTRAHD', 'ULTRA HD', 'ULTRAHD', '2160P', '1080P',
  '720P', '2160p', '1080p', '720p', '4K', 'UHD', 'FHD', 'HDR10+', 'HDR10', 'HDR',
  'DOLBY VISION', 'DV', 'HEVC', 'H265', 'H.265', 'X265', 'HD', 'SD', '3D', 'MULTI',
  'MULTISUB', 'VOSTFR', 'VOST', 'VFF', 'VFQ', 'VF', 'VO', 'ATMOS', 'REMUX', 'BLURAY',
];
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const QALT = QUALITY.map(esc).join('|');
const SUFFIX = new RegExp(
  `(?:\\s*[\\(\\[]\\s*(${QALT})\\s*[\\)\\]]|\\s*(?:-|–|\\|)?\\s+(${QALT}))\\s*$`,
);

const isQuality = (c) => QUALITY.includes(c.toUpperCase());

function pretty(tag) {
  const t = tag.toUpperCase().replace(/\s+/g, ' ');
  switch (t) {
    case '4K ULTRA HD': case '4K ULTRAHD': case 'ULTRA HD': case 'ULTRAHD': return 'UHD';
    case '4K LIGHT': return '4K Light';
    case '2160P': return '4K';
    case '1080P': case 'FHD': return 'Full HD';
    case '720P': return 'HD';
    case 'MULTI': case 'MULTISUB': return 'Multi';
    case 'DOLBY VISION': return 'Dolby Vision';
    case 'ATMOS': return 'Atmos';
    default: return t;
  }
}

const cache = new Map();

export function parseTitle(raw = '') {
  const hit = cache.get(raw);
  if (hit) return hit;
  let s = String(raw).trim();
  const tags = [];
  for (let i = 0; i < 4; i++) {
    const m = s.match(PREFIX);
    if (!m) break;
    const code = m[0].replace(/[|[\]():\-–»\s]/g, '').toUpperCase();
    if (isQuality(code)) tags.push(pretty(code));
    s = s.slice(m[0].length);
  }
  s = s.replace(PIPE_TAG, (_, c) => {
    if (isQuality(c.trim())) tags.push(pretty(c.trim()));
    return ' ';
  });
  const suffix = [];
  for (let i = 0; i < 4; i++) {
    const m = s.match(SUFFIX);
    if (!m || m.index === 0) break;
    suffix.unshift(pretty(m[1] || m[2]));
    s = s.slice(0, m.index);
  }
  tags.push(...suffix);
  s = s.replace(/\s{2,}/g, ' ').trim().replace(/^[-–:|•]+\s*|\s*[-–:|•]+$/g, '').trim();
  if (!s) s = String(raw).trim();
  const key = s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/œ/g, 'oe')
    .replace(/æ/g, 'ae')
    .replace(/[^a-z0-9]/g, '') || s.toLowerCase();
  const info = { title: s, tags, key, version: tags.length ? tags.join(' · ') : 'Standard' };
  if (cache.size > 30000) cache.clear();
  cache.set(raw, info);
  return info;
}

export const cleanTitle = (raw) => parseTitle(raw).title;

/** Garde un seul élément par titre (la première version rencontrée). */
export function groupVersions(items, nameOf = (i) => i.name) {
  const seen = new Set();
  return items.filter((i) => {
    const k = parseTitle(nameOf(i)).key;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

export function qualityRank(name) {
  const t = parseTitle(name).tags.join(' ').toUpperCase();
  if (!t) return 0;
  if (t.includes('UHD')) return 4;
  if (t.includes('4K')) return 3;
  if (t.includes('HD')) return 1;
  return 2;
}
