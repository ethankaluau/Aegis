// Copies the web-app files from the repo root into ./app so they can be bundled
// into the desktop package. app/ is a build artifact (gitignored) — the repo root
// stays the single source of truth for the app's code and data.

const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..'); // repo root: Aegis\Aegis
const dst = path.join(__dirname, 'app');

const FILES = [
  'index.html',
  // seed data (shown instantly on first launch, before the first refresh)
  'funds.js', 'stocks.js', 'signals.js', 'crypto.js', 'fundamentals.js',
  // refresh scripts (run by the app to fetch live data)
  'refresh-stocks.ps1', 'refresh-crypto.ps1', 'refresh-signals.ps1',
  'refresh-data.ps1', 'refresh-fundamentals.ps1',
  // default watchlists
  'watchlist.txt', 'crypto-watchlist.txt',
];

fs.mkdirSync(dst, { recursive: true });
let n = 0;
for (const f of FILES) {
  const from = path.join(src, f);
  if (!fs.existsSync(from)) {
    console.error(`  MISSING: ${f} — not found in repo root`);
    process.exit(1);
  }
  fs.copyFileSync(from, path.join(dst, f));
  n++;
}
console.log(`Synced ${n} web files into app/`);
