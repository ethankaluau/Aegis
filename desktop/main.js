// Aegis desktop — Electron main process.
// Wraps the existing web app (index.html + data .js) in a native window and
// reuses the PowerShell refresh scripts to pull live data. App code (html/ps1)
// ships read-only inside the package; user data (watchlist + last-good numbers)
// lives in a writable folder so it survives updates.

const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');
// electron-updater is required lazily inside checkForUpdates() — importing it at
// module load triggers it to read app.getVersion() before the app is ready.

// Where the bundled web-app payload lives (packaged vs. dev).
const bundledDir = app.isPackaged
  ? path.join(process.resourcesPath, 'app-payload')
  : path.join(__dirname, 'app');

// Writable working copy: watchlists + generated data + a runnable copy of the app.
const dataDir = path.join(app.getPath('userData'), 'data');

// Files that belong to the USER (preserve edits / last-good data): copy only if missing.
// Everything else is app code (index.html, *.ps1): overwrite each launch so updates land.
const USER_FILES = new Set(['watchlist.txt', 'crypto-watchlist.txt']);
const isUserData = f => USER_FILES.has(f) || f.endsWith('.js');

// Run in order, each with the label shown to the user if it fails. Sequential on
// purpose: several scripts hit the same price API, and firing all five at once
// risks throttling — the full pass takes ~40s.
const REFRESH_SCRIPTS = [
  { file: 'refresh-stocks.ps1', label: 'stocks' },
  { file: 'refresh-crypto.ps1', label: 'crypto' },
  { file: 'refresh-signals.ps1', label: 'signals' },
  { file: 'refresh-data.ps1', label: 'funds' },
  { file: 'refresh-fundamentals.ps1', label: 'fundamentals' },
];

let win = null;
let refreshing = false;
// Outcome of the last pass. Survives the post-refresh reload so the page can ask
// for it once the preload re-injects — otherwise the warning would be wiped by
// the very reload that shows the new numbers.
let lastRefresh = null;

function seedDataDir() {
  fs.mkdirSync(dataDir, { recursive: true });
  for (const f of fs.readdirSync(bundledDir)) {
    const src = path.join(bundledDir, f);
    const dst = path.join(dataDir, f);
    if (isUserData(f)) {
      if (!fs.existsSync(dst)) fs.copyFileSync(src, dst); // keep user's version
    } else {
      fs.copyFileSync(src, dst); // refresh app code every launch
    }
  }
}

function runScript(name) {
  return new Promise(resolve => {
    execFile(
      'powershell.exe',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(dataDir, name)],
      { cwd: dataDir, windowsHide: true, timeout: 90000, maxBuffer: 8 * 1024 * 1024 },
      (err, stdout, stderr) => resolve({ name, ok: !err, err, stdout, stderr })
    );
  });
}

function status(msg) {
  if (win && !win.isDestroyed()) win.webContents.send('aegis-status', msg);
}

async function refreshAll() {
  if (refreshing) return;
  refreshing = true;
  try {
    const failed = [];
    let n = 0;
    for (const s of REFRESH_SCRIPTS) {
      n++;
      status(`Getting today's numbers… (${n}/${REFRESH_SCRIPTS.length})`);
      const r = await runScript(s.file);
      if (!r.ok) {
        failed.push(s.label);
        // Surface the reason in the console; the user gets the short version.
        console.error(`refresh failed: ${s.file}`, (r.err && r.err.message) || '', r.stderr || '');
      }
    }
    lastRefresh = { failed, at: Date.now() };
    status(failed.length ? 'stale' : 'done');
    if (win && !win.isDestroyed()) win.webContents.reload();
  } finally {
    refreshing = false;
  }
}

function createWindow() {
  win = new BrowserWindow({
    width: 1040,
    height: 920,
    minWidth: 380,
    backgroundColor: '#0f1720',
    title: 'Aegis',
    icon: path.join(__dirname, 'build', 'icon.ico'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setMenuBarVisibility(false);
  win.loadFile(path.join(dataDir, 'index.html'));

  // Open external links (if any) in the real browser, not inside the app.
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  // Show last-good data instantly, then refresh in the background on first load.
  win.webContents.once('did-finish-load', () => { refreshAll(); });
}

ipcMain.handle('aegis-refresh', async () => { await refreshAll(); });
// Asked for by the preload after every page load, including the reload that ends
// a refresh — this is how a failed fetch stays visible instead of being cleared.
ipcMain.handle('aegis-last-refresh', () => lastRefresh);

function checkForUpdates() {
  if (!app.isPackaged) return; // only the installed build can self-update
  const { autoUpdater } = require('electron-updater');
  autoUpdater.autoDownload = true;
  autoUpdater.on('update-downloaded', () => status('An update is ready — it will install when you close Aegis.'));
  autoUpdater.on('error', err => console.error('auto-update error:', err && err.message));
  autoUpdater.checkForUpdatesAndNotify().catch(() => {});
}

app.whenReady().then(() => {
  seedDataDir();
  createWindow();
  checkForUpdates();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
