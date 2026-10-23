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
const searchEl = document.getElementById("config-search");
if (searchEl) searchEl.addEventListener("input", () => render(lastPayload));

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

const ERROR_LABELS = {
  invalid_number: "Nombre invalide",
  invalid_boolean: "Valeur oui/non invalide",
  invalid_json: "JSON invalide",
  not_in_options: "Valeur non autorisée",
  forbidden: "Permission refusée",
};

function describeError(code) {
  const raw = String(code || "");
  if (raw.startsWith("below_min:")) return `Minimum : ${raw.split(":")[1]}`;
  if (raw.startsWith("above_max:")) return `Maximum : ${raw.split(":")[1]}`;
  return ERROR_LABELS[raw] || raw || "Échec";
}

/* Champ adapté au type de la clé ; getValue() renvoie la valeur à envoyer. */
function buildInput(row) {
  const type = row.valueType || "string";
  if (type === "boolean") {
    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = row.value === true || row.value === "true" || row.value === "1" || row.value === 1;
    return { el: box, getValue: () => box.checked };
  }
  if (type === "number") {
    const num = document.createElement("input");
    num.type = "number";
    num.step = "any";
    if (row.min != null) num.min = String(row.min);
    if (row.max != null) num.max = String(row.max);
    num.value = row.value == null ? "" : String(row.value);
    return { el: num, getValue: () => num.value };
  }
  if (Array.isArray(row.options) && row.options.length > 0) {
    const sel = document.createElement("select");
    for (const opt of row.options) {
      const o = document.createElement("option");
      o.value = String(opt);
      o.textContent = String(opt);
      sel.appendChild(o);
    }
    sel.value = row.value == null ? "" : String(row.value);
    return { el: sel, getValue: () => sel.value };
  }
  const text = document.createElement("input");
  text.type = "text";
  text.value = row.value == null ? "" : String(row.value);
  return { el: text, getValue: () => text.value };
}

let lastPayload = {};
const openNamespaces = new Set();

function matches(row, term) {
  if (!term) return true;
  const hay = `${row.namespace} ${row.key} ${row.label || ""} ${row.description || ""}`.toLowerCase();
  return hay.includes(term);
}

function render(payload) {
  lastPayload = payload;
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
  const term = (searchEl ? searchEl.value : "").trim().toLowerCase();
  listEl.innerHTML = "";
  let shown = 0;
  for (const [ns, allRows] of groupByNamespace(entries)) {
    const rows = allRows.filter((r) => matches(r, term));
    if (rows.length === 0) continue;
    shown += rows.length;
    const wrap = document.createElement("details");
    wrap.className = "ns";
    // Recherche active : tout est déplié ; sinon on mémorise les groupes ouverts.
    wrap.open = term !== "" || openNamespaces.has(ns);
    wrap.addEventListener("toggle", () => {
      if (term !== "") return;
      if (wrap.open) openNamespaces.add(ns);
      else openNamespaces.delete(ns);
    });
    const title = document.createElement("summary");
    title.className = "ns-title";
    title.textContent = `${ns} (${rows.length})`;
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
      const hintText = [row.description, row.min != null || row.max != null ? `[${row.min ?? "…"} – ${row.max ?? "…"}]` : null]
        .filter(Boolean)
        .join(" ");
      if (hintText) {
        const hint = document.createElement("span");
        hint.className = "hint";
        hint.textContent = hintText;
        labelCol.appendChild(hint);
      }
      const field = buildInput(row);
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "save";
      btn.textContent = "Sauver";
      btn.addEventListener("click", async () => {
        toastEl.textContent = "Enregistrement…";
        const result = await nuiPost("config:set", {
          namespace: row.namespace,
          key: row.key,
          value: field.getValue(),
        });
        if (!result || !result.ok) {
          toastEl.textContent = describeError(result && result.error);
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
      el.appendChild(field.el);
      el.appendChild(btn);
      wrap.appendChild(el);
    }
    listEl.appendChild(wrap);
  }
  if (shown === 0) {
    const empty = document.createElement("div");
    empty.className = "hint";
    empty.textContent = term ? "Aucun réglage ne correspond à la recherche." : "Aucun réglage enregistré.";
    listEl.appendChild(empty);
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
