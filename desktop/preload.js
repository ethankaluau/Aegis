// Aegis desktop — preload. Injects a Refresh button + status pill into the page
// and talks to the main process over IPC directly. Runs in the isolated preload
// world, which still shares the page's DOM — so it can add UI without touching
// index.html (keeping one codebase for web + desktop).

const { ipcRenderer } = require('electron');

window.addEventListener('DOMContentLoaded', () => {
  const bar = document.createElement('div');
  bar.id = 'aegis-refresh-bar';
  bar.innerHTML =
    '<button id="aegis-refresh-btn" title="Fetch today\'s latest numbers">&#8635; Refresh</button>' +
    '<span id="aegis-refresh-status"></span>';
  const style = document.createElement('style');
  style.textContent = `
    #aegis-refresh-bar{position:fixed;top:12px;right:14px;z-index:9999;display:flex;
      align-items:center;gap:10px;font:13px/1.4 system-ui,Segoe UI,sans-serif}
    #aegis-refresh-btn{background:#3fb98c;color:#06231a;border:0;border-radius:20px;
      padding:7px 14px;font-weight:800;font-size:13px;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,.3)}
    #aegis-refresh-btn:hover{filter:brightness(1.07)}
    #aegis-refresh-btn:disabled{opacity:.55;cursor:default}
    #aegis-refresh-status{color:#9fb2c2;font-variant-numeric:tabular-nums}
    @media (prefers-color-scheme: light){ #aegis-refresh-btn{color:#fff;background:#127a53} #aegis-refresh-status{color:#5a6b78} }
  `;
  document.head.appendChild(style);
  document.body.appendChild(bar);

  const btn = document.getElementById('aegis-refresh-btn');
  const stat = document.getElementById('aegis-refresh-status');

  btn.addEventListener('click', () => {
    btn.disabled = true;
    ipcRenderer.invoke('aegis-refresh'); // main runs the scripts, then reloads the page
  });

  ipcRenderer.on('aegis-status', (_e, msg) => {
    if (msg === 'done') {
      stat.textContent = '';
      btn.disabled = false;
    } else {
      stat.textContent = msg;
      btn.disabled = true;
    }
  });
});
