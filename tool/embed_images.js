'use strict';
// Скачивает картинки товаров из assets/data/catalog.json в assets/products/ и переписывает
// пути в каталоге на встроенные (assets/products/...). Можно запускать повторно (докачивает).
//   cd <корень проекта>
//   cd tool && npm install sharp && cd ..        (необязательно: сжатие картинок до 640px/webp)
//   node tool/embed_images.js
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const CATALOG = path.join(ROOT, 'assets', 'data', 'catalog.json');
const OUT = path.join(ROOT, 'assets', 'products');
const CONCURRENCY = 6;
const MAX_SIDE = 640;

let sharp = null;
try { sharp = require('sharp'); } catch (_) { console.log('! sharp не установлен — картинки сохраняются как есть (APK будет больше).'); }

const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
fs.mkdirSync(OUT, { recursive: true });

const urls = [...new Set(catalog.products.flatMap((p) => p.images || []).filter((u) => /^https?:/.test(u)))];
console.log(`Уникальных картинок: ${urls.length}`);

const nameFor = (u) => {
  const h = crypto.createHash('sha1').update(u).digest('hex').slice(0, 12);
  const ext = sharp ? '.webp' : (path.extname(new URL(u).pathname).toLowerCase() || '.jpg');
  return h + ext;
};

async function fetchBuf(u) {
  for (let a = 1; a <= 3; a++) {
    try {
      const r = await fetch(u, { signal: AbortSignal.timeout(30000), headers: { 'User-Agent': 'Mozilla/5.0' } });
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return Buffer.from(await r.arrayBuffer());
    } catch (e) {
      if (a === 3) throw e;
      await new Promise((res) => setTimeout(res, 800 * a));
    }
  }
}

const map = new Map();
let done = 0, failed = 0, bytes = 0;

async function work(u) {
  const name = nameFor(u);
  const file = path.join(OUT, name);
  try {
    if (!fs.existsSync(file)) {
      let buf = await fetchBuf(u);
      if (sharp) buf = await sharp(buf).resize(MAX_SIDE, MAX_SIDE, { fit: 'inside', withoutEnlargement: true }).webp({ quality: 74 }).toBuffer();
      fs.writeFileSync(file, buf);
    }
    bytes += fs.statSync(file).size;
    map.set(u, 'assets/products/' + name);
  } catch (e) {
    failed++;
    console.log('  не скачалась: ' + u + ' (' + e.message + ')');
  }
  done++;
  if (done % 50 === 0 || done === urls.length) console.log(`  ${done}/${urls.length}, ошибок ${failed}, ${(bytes / 1048576).toFixed(1)} МБ`);
}

(async () => {
  const queue = urls.slice();
  await Promise.all(Array.from({ length: CONCURRENCY }, async () => { while (queue.length) await work(queue.shift()); }));
  let withImg = 0;
  for (const p of catalog.products) {
    // скачанные заменяем на встроенные; нескачанные оставляем сетевыми ссылками
    p.images = (p.images || []).map((u) => map.get(u) || u);
    if (p.images.length) withImg++;
  }
  fs.writeFileSync(CATALOG, JSON.stringify(catalog));
  console.log(`Готово: встроено ${map.size} картинок (${(bytes / 1048576).toFixed(1)} МБ), товаров с фото ${withImg}, ошибок ${failed}.`);
})();
