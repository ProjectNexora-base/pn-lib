/* pn-lib NUI: WebRTC stub + configuration panel */

const resourceName =
  typeof GetParentResourceName === "function"
    ? GetParentResourceName()
    : "pn-lib";

function nuiPost(event, data) {
  return fetch(`https://${resourceName}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data ?? {}),
  }).then((r) => r.json().catch(() => ({})));
}

/* --- WebRTC --- */
window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data) return;
  if (data.action === "webrtc:signal") {
    console.debug("[pn-lib] signal", data.payload);
    return;
  }
  if (data.action === "config:open") {
    openConfig(data.payload || {});
    return;
  }
  if (data.action === "config:close") {
    closeConfigUiOnly();
  }
});

fetch(`https://${resourceName}/webrtc:ready`, {
  method: "POST",
  headers: { "Content-Type": "application/json; charset=UTF-8" },
  body: "{}",
}).catch(() => {});

/* --- Config panel --- */
const root = document.getElementById("config-root");
const listEl = document.getElementById("list");
const metaEl = document.getElementById("config-meta");
const bannerEl = document.getElementById("banner");
const toastEl = document.getElementById("toast");
const btnClose = document.getElementById("btn-close");

function closeConfigUiOnly() {
  if (root) {
    root.classList.remove("open");
    root.setAttribute("aria-hidden", "true");
  }
}

function closeConfig() {
  closeConfigUiOnly();
  nuiPost("config:close", {});
}

function groupByNamespace(items) {
  const map = new Map();
  for (const e of items) {
    const ns = e.namespace || "default";
    if (!map.has(ns)) map.set(ns, []);
    map.get(ns).push(e);
  }
  return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
}

function render(payload) {
  const entries = Array.isArray(payload.entries) ? payload.entries : [];
  if (metaEl) {
    const hash = String(payload.hash || "");
    metaEl.textContent = payload.tableOk
      ? `MySQL OK · ${entries.length} clés · hash ${hash.slice(0, 24)}…`
      : `Table MySQL indisponible · ${entries.length} clés (mémoire)`;
  }
  if (bannerEl) {
    if (!payload.tableOk) {
      bannerEl.style.display = "block";
      bannerEl.textContent =
        "La table pn_config est indisponible. Les changements restent en mémoire jusqu'à restauration / réparation MySQL.";
    } else {
      bannerEl.style.display = "none";
    }
  }
  if (!listEl) return;
  listEl.innerHTML = "";
  for (const [ns, rows] of groupByNamespace(entries)) {
    const wrap = document.createElement("div");
    wrap.className = "ns";
    const title = document.createElement("div");
    title.className = "ns-title";
    title.textContent = ns;
    wrap.appendChild(title);
    for (const row of rows) {
      const el = document.createElement("div");
      el.className = "row";
      const labelCol = document.createElement("div");
      const lab = document.createElement("label");
      lab.textContent = row.label || row.key;
      if (row.requiresRestart) {
        const badge = document.createElement("span");
        badge.className = "badge";
        badge.textContent = "restart requis";
        lab.appendChild(badge);
      }
      labelCol.appendChild(lab);
      if (row.description) {
        const hint = document.createElement("span");
        hint.className = "hint";
        hint.textContent = row.description;
        labelCol.appendChild(hint);
      }
      const input = document.createElement("input");
      input.type = "text";
      input.value = row.value == null ? "" : String(row.value);
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "save";
      btn.textContent = "Sauver";
      btn.addEventListener("click", async () => {
        toastEl.textContent = "Enregistrement…";
        const result = await nuiPost("config:set", {
          namespace: row.namespace,
          key: row.key,
          value: input.value,
        });
        if (!result || !result.ok) {
          toastEl.textContent = (result && result.error) || "Échec";
          return;
        }
        if (result.requiresRestart) {
          toastEl.textContent =
            "Enregistré — un redémarrage de resource peut être nécessaire (aucun restart auto).";
        } else {
          toastEl.textContent = "Enregistré (sync panel ~5s).";
        }
        if (result.entries) {
          render({
            ...payload,
            entries: result.entries,
            hash: result.hash,
            tableOk: payload.tableOk,
          });
        }
      });
      el.appendChild(labelCol);
      el.appendChild(input);
      el.appendChild(btn);
      wrap.appendChild(el);
    }
    listEl.appendChild(wrap);
  }
}

function openConfig(payload) {
  if (root) {
    root.classList.add("open");
    root.setAttribute("aria-hidden", "false");
  }
  if (toastEl) toastEl.textContent = "";
  render(payload || {});
}

if (btnClose) btnClose.addEventListener("click", closeConfig);

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && root && root.classList.contains("open")) {
    closeConfig();
  }
});
