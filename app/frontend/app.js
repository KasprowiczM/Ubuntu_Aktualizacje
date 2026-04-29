// Ubuntu_Aktualizacje dashboard — vanilla SPA
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

const api = {
  async get(path) {
    const r = await fetch(path);
    if (!r.ok) throw new Error(`${path}: ${r.status}`);
    return r.json();
  },
  async post(path, body) {
    const r = await fetch(path, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!r.ok) {
      const t = await r.text();
      const err = new Error(`${path}: ${r.status} ${t}`);
      err.status = r.status;
      err.body = t;
      throw err;
    }
    return r.json();
  },
};

// ── sudo modal ──────────────────────────────────────────────────────────────
const sudoMgr = {
  pending: null,  // resolve() of in-flight prompt
  open(reason) {
    return new Promise(resolve => {
      this.pending = resolve;
      const m = $("#sudo-modal");
      $("#sudo-error").textContent = reason || "";
      $("#sudo-pass").value = "";
      m.classList.remove("hidden");
      setTimeout(() => $("#sudo-pass").focus(), 50);
    });
  },
  close(authenticated) {
    $("#sudo-modal").classList.add("hidden");
    if (this.pending) {
      const r = this.pending; this.pending = null;
      r(authenticated);
    }
    sudoMgr.refreshIndicator();
  },
  async refreshIndicator() {
    try {
      const s = await api.get("/sudo/status");
      const ind = $("#sudo-indicator");
      ind.innerHTML = s.cached
        ? '<span class="badge ok">sudo cached</span>'
        : '<span class="badge warn">sudo not cached</span>';
    } catch {}
  },
  async ensure() {
    const s = await api.get("/sudo/status");
    if (s.cached) return true;
    return this.open("sudo cache empty — enter password to authenticate");
  },
};

const ui = {
  show(view) {
    $$(".view").forEach(v => v.classList.add("hidden"));
    $(`#view-${view}`).classList.remove("hidden");
    $$("nav a").forEach(a => a.classList.toggle("active", a.dataset.view === view));
    location.hash = view;
    // Lazy-load on view switch
    if (view === "overview")   ui.loadOverview();
    if (view === "categories") ui.loadCategories();
    if (view === "history")    ui.loadHistory();
    if (view === "run")        ui.loadRunCenter();
    if (view === "sync")       ui.loadSync();
    if (view === "settings")   ui.loadSettings();
    if (view === "hosts")      ui.loadHosts();
  },
  status(msg) { $("#status-line").textContent = msg; },
  badge(status) {
    const cls = (status || "").toLowerCase();
    return `<span class="badge ${cls}">${status || "?"}</span>`;
  },
  fmtTime(s) {
    if (!s) return "—";
    const d = new Date(s);
    if (isNaN(d.getTime())) return s;
    return d.toLocaleString();
  },

  async loadOverview() {
    try {
      const h = await api.get("/health");
      $("#hostbadge").textContent = h.repo_root || "";
    } catch {}
    try {
      const runs = (await api.get("/runs?limit=1")).runs;
      const last = runs[0];
      $("#last-run").innerHTML = last
        ? `${ui.badge(last.status)} <code>${last.id}</code><br>
           <span class="dim">${ui.fmtTime(last.started_at)} → ${ui.fmtTime(last.ended_at)}</span><br>
           profile: ${last.profile || "—"}, dry-run: ${last.dry_run ? "yes" : "no"}<br>
           ${last.needs_reboot ? `<b>${tr("overview.reboot_required")}</b>` : ""}`
        : `<span class='dim'>${tr("overview.no_runs")}</span>`;
    } catch (e) { $("#last-run").textContent = String(e); }
    try {
      const p = await api.get("/preflight");
      $("#preflight").innerHTML = `${p.needs_reboot ? `<b>${tr("overview.reboot_pending")}</b><br>` : ""}` +
        p.items.map(i => `<span class="badge ${i.present ? "ok" : "warn"}">${i.tool}</span>`).join(" ");
    } catch (e) { $("#preflight").textContent = String(e); }
    try {
      const g = await api.get("/git/status");
      $("#git-status").innerHTML = `branch <code>${g.branch}</code> ` +
        (g.dirty ? "<span class='badge warn'>dirty</span>" : "<span class='badge ok'>clean</span>") +
        ` <span class="dim">↑${g.ahead} ↓${g.behind}</span>`;
    } catch (e) { $("#git-status").textContent = String(e); }
    // Inventory charts (slow scan, runs after the rest paints)
    ui.loadInventoryDashboard();
  },

  // ── SVG donut + bar charts (pure DOM, no chart libs) ─────────────────
  renderDonut(elId, segments) {
    const total = segments.reduce((a, s) => a + (s.value||0), 0);
    if (total === 0) {
      $("#"+elId).innerHTML = `<p class="dim">—</p>`;
      return;
    }
    const r = 60, cx = 80, cy = 80, sw = 22;
    const C = 2 * Math.PI * r;
    let off = 0, arcs = "";
    for (const seg of segments) {
      if (!seg.value) continue;
      const len = (seg.value / total) * C;
      arcs += `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none"
                       stroke="${seg.color}" stroke-width="${sw}"
                       stroke-dasharray="${len.toFixed(2)} ${C.toFixed(2)}"
                       stroke-dashoffset="${(-off).toFixed(2)}" />`;
      off += len;
    }
    $("#"+elId).innerHTML = `
      <svg viewBox="0 0 160 160" width="180" height="180" role="img"
           aria-label="status donut" style="transform:rotate(-90deg)">
        <circle cx="${cx}" cy="${cy}" r="${r}" fill="none"
                stroke="var(--border)" stroke-width="${sw}" />
        ${arcs}
      </svg>
      <div style="text-align:center;margin-top:-2.6rem;font-size:1.4rem;font-weight:600;">${total}</div>
      <div class="donut-legend">
        ${segments.filter(s => s.value).map(s =>
          `<span><span class="swatch" style="background:${s.color}"></span>${s.label}: ${s.value}</span>`
        ).join("")}
      </div>`;
  },

  renderBars(elId, perCat) {
    const rows = Object.entries(perCat).map(([cat, c]) => {
      const total = c.total || 1;
      return `<div class="bar-row">
        <span class="bar-label mono">${cat}</span>
        <span class="bar-track">
          <span class="bar-fill-ok"       style="width:${(c.ok/total)*100}%"></span>
          <span class="bar-fill-outdated" style="width:${(c.outdated/total)*100}%"></span>
          <span class="bar-fill-missing"  style="width:${(c.missing/total)*100}%"></span>
        </span>
        <span class="bar-counts">${c.ok}/${c.outdated}/${c.missing} (${c.total})</span>
      </div>`;
    }).join("");
    $("#"+elId).innerHTML = rows + `
      <p class="dim" style="margin-top:0.5rem;font-size:0.75rem">
        <span style="color:var(--ok)">█ ok</span> /
        <span style="color:var(--warn)">█ outdated</span> /
        <span style="color:var(--err)">█ missing</span>
      </p>`;
  },

  async loadInventoryDashboard() {
    const spin = `<span class="spinner"></span> ${tr("overview.scanning")}`;
    $("#inv-donut").innerHTML  = spin;
    $("#inv-bars").innerHTML   = spin;
    $("#inv-updates").innerHTML = spin;
    try {
      const s = await api.get("/inventory/summary");
      window.INV_SUMMARY = s;
      ui.renderDonut("inv-donut", [
        { label: "ok",       value: s.totals.ok,       color: "var(--ok)" },
        { label: "outdated", value: s.totals.outdated, color: "var(--warn)" },
        { label: "missing",  value: s.totals.missing,  color: "var(--err)" },
      ]);
      ui.renderBars("inv-bars", s.categories);
    } catch (e) { $("#inv-donut").textContent = String(e); $("#inv-bars").textContent = ""; }
    try {
      const all = (await api.get("/inventory")).categories;
      const upd = [];
      for (const [cat, items] of Object.entries(all))
        for (const it of items) if (it.status === "outdated") upd.push({cat, ...it});
      if (!upd.length) {
        $("#inv-updates").innerHTML = `<p class="dim">${tr("overview.no_updates")}</p>`;
      } else {
        $("#inv-updates").innerHTML = `
          <table class="inv-table">
            <thead><tr>
              <th>${tr("categories.col_cat")}</th>
              <th>${tr("categories.col_pkg")}</th>
              <th>${tr("categories.col_inst")}</th>
              <th>${tr("categories.col_cand")}</th>
              <th>${tr("categories.col_source")}</th>
            </tr></thead>
            <tbody>${upd.map(u => `
              <tr class="status-outdated">
                <td>${u.cat}</td>
                <td class="pkg-name">${u.name}</td>
                <td class="dim mono">${u.installed||"—"}</td>
                <td class="mono"><b>${u.candidate||"—"}</b></td>
                <td class="dim">${u.source||""}</td>
              </tr>`).join("")}
            </tbody>
          </table>`;
      }
    } catch (e) { $("#inv-updates").textContent = String(e); }
  },

  async loadCategories() {
    const cats = (await api.get("/categories")).categories;
    const summary = window.INV_SUMMARY || (await api.get("/inventory/summary").catch(()=>({categories:{}})));
    window.INV_SUMMARY = summary;
    const tb = $("#cats-table tbody");
    tb.innerHTML = "";
    for (const c of cats) {
      const counts = (summary.categories && summary.categories[c.id]) || {ok:0,outdated:0,missing:0,total:0};
      const tr = document.createElement("tr");
      tr.className = "cat-row";
      tr.dataset.cat = c.id;
      tr.innerHTML = `
        <td><span class="toggle">▶</span></td>
        <td><b>${c.id}</b><br><span class="dim">${c.display_name}</span></td>
        <td class="mono">${counts.total}</td>
        <td><span class="badge ok">${counts.ok}</span></td>
        <td>${counts.outdated ? `<span class="badge warn">${counts.outdated}</span>` : `<span class="dim">${counts.outdated}</span>`}</td>
        <td>${counts.missing  ? `<span class="badge fail">${counts.missing}</span>`  : `<span class="dim">${counts.missing}</span>`}</td>
        <td>
          <button data-only="${c.id}" data-phase="check">check</button>
          <button data-only="${c.id}" data-phase="apply" class="secondary">apply</button>
        </td>`;
      tb.appendChild(tr);
      const det = document.createElement("tr");
      det.className = "cat-detail hidden";
      det.innerHTML = `<td colspan="7"><div class="cat-detail-inner" id="cat-detail-${c.id}"></div></td>`;
      tb.appendChild(det);
    }
    $$("#cats-table .cat-row").forEach(row => {
      row.addEventListener("click", e => {
        if (e.target.tagName === "BUTTON") return;
        const cat = row.dataset.cat;
        const det = row.nextElementSibling;
        if (det.classList.contains("hidden")) {
          det.classList.remove("hidden"); row.classList.add("open");
          ui.loadCategoryDetail(cat);
        } else {
          det.classList.add("hidden"); row.classList.remove("open");
        }
      });
    });
    $$("#cats-table tr.cat-row button").forEach(b => b.addEventListener("click", e => {
      e.stopPropagation();
      ui.show("run");
      $("#only-select").value  = b.dataset.only;
      $("select[name=phase]").value = b.dataset.phase;
    }));
  },

  async loadCategoryDetail(cat) {
    const target = $("#cat-detail-" + cat);
    target.innerHTML = `<span class="spinner"></span> ${tr("overview.scanning")}`;
    try {
      const items = (await api.get(`/inventory/${encodeURIComponent(cat)}`)).items;
      if (!items.length) {
        target.innerHTML = `<p class="dim">${tr("categories.no_items")}</p>`;
        return;
      }
      const order = {outdated:0, missing:1, ok:2, unknown:3};
      items.sort((a,b) => (order[a.status]||9) - (order[b.status]||9) || a.name.localeCompare(b.name));
      target.innerHTML = `
        <table class="inv-table">
          <thead><tr>
            <th>${tr("categories.col_pkg")}</th>
            <th>${tr("categories.col_inst")}</th>
            <th>${tr("categories.col_cand")}</th>
            <th>${tr("categories.col_status")}</th>
            <th>${tr("categories.col_source")}</th>
            <th>${tr("categories.col_in_cfg")}</th>
          </tr></thead>
          <tbody>
            ${items.map(it => `
              <tr class="status-${it.status}">
                <td class="pkg-name">${it.name}</td>
                <td class="mono">${it.installed||"—"}</td>
                <td class="mono">${it.candidate||"—"}</td>
                <td>${ui.badge(it.status)}</td>
                <td class="dim">${it.source||""}</td>
                <td>${it.in_config ? "✔" : "<span class='dim'>—</span>"}</td>
              </tr>`).join("")}
          </tbody>
        </table>`;
    } catch (e) {
      target.innerHTML = `<p class="badge fail">${e}</p>`;
    }
  },

  async loadRunCenter() {
    if (!$("#profile-select").options.length) {
      const profs = (await api.get("/profiles")).profiles;
      const sel = $("#profile-select");
      for (const p of profs) {
        const opt = document.createElement("option");
        opt.value = p.id;
        opt.textContent = `${p.id} — ${p.description}`;
        sel.appendChild(opt);
      }
      const cats = (await api.get("/categories")).categories;
      const onlySel = $("#only-select");
      for (const c of cats) {
        const opt = document.createElement("option");
        opt.value = c.id;
        opt.textContent = c.display_name;
        onlySel.appendChild(opt);
      }
    }
    // Existing active run?
    try {
      const a = (await api.get("/runs/active")).active;
      if (a && !a.finished) {
        ui.attachStream(a.run_id);
        $("#stop-btn").disabled = false;
      }
    } catch {}
  },

  async loadHistory() {
    const rows = (await api.get("/runs?limit=200")).runs;
    const tb = $("#history-table tbody");
    tb.innerHTML = "";
    for (const r of rows) {
      const tr = document.createElement("tr");
      const phaseSummary = r.summary && r.summary.phases
        ? `${r.summary.phases.length} phase(s)` : "—";
      tr.innerHTML = `
        <td>${ui.fmtTime(r.started_at)}</td>
        <td>${r.profile || "—"}${r.dry_run ? " <span class='dim'>(dry)</span>":""}</td>
        <td>${ui.badge(r.status)}</td>
        <td>${phaseSummary}</td>
        <td>${r.needs_reboot ? "yes" : "—"}</td>
        <td><a href="#logs" data-run="${r.id}">${r.id}</a></td>`;
      tb.appendChild(tr);
    }
    $$("a[data-run]").forEach(a => a.addEventListener("click", e => {
      e.preventDefault();
      ui.show("logs");
      ui.loadRunDetail(a.dataset.run);
    }));
  },

  async loadRunDetail(runId) {
    try {
      const r = (await api.get(`/runs/${runId}`)).run;
      const phases = r.phases || (r.run && r.run.phases) || [];
      let html = `<h3><code>${r.id || runId}</code> — ${ui.badge(r.status)}</h3>
        <p class="dim">${ui.fmtTime(r.started_at)} → ${ui.fmtTime(r.ended_at)}</p>
        <table><thead><tr>
          <th>Category</th><th>Phase</th><th>Exit</th><th>OK</th><th>Warn</th><th>Err</th><th>Sidecar</th>
        </tr></thead><tbody>`;
      for (const p of phases) {
        const s = p.summary || {};
        const cat = p.category, ph = p.phase || p.kind;
        html += `<tr>
          <td>${cat}</td>
          <td>${ph}</td>
          <td>${p.exit_code ?? "—"}</td>
          <td>${s.ok ?? "—"}</td>
          <td>${s.warn ?? "—"}</td>
          <td>${s.err ?? "—"}</td>
          <td>
            <a href="/runs/${runId}/phase/${cat}/${ph}" target="_blank">json</a> ·
            <a href="/runs/${runId}/phase/${cat}/${ph}/log" target="_blank">log</a>
          </td>
        </tr>`;
      }
      html += "</tbody></table>";
      $("#run-detail").innerHTML = html;
    } catch (e) {
      $("#run-detail").innerHTML = `<p class="badge fail">${e}</p>`;
    }
  },

  async loadHosts() {
    const tb = $("#hosts-table tbody");
    tb.innerHTML = '<tr><td colspan="7" class="dim">loading…</td></tr>';
    try {
      const hosts = (await api.get("/hosts")).hosts;
      if (!hosts.length) {
        tb.innerHTML = '<tr><td colspan="7" class="dim">No hosts configured. Copy <code>config/hosts.toml.example</code> → <code>config/hosts.toml</code> and add entries.</td></tr>';
        return;
      }
      tb.innerHTML = "";
      for (const h of hosts) {
        const tr = document.createElement("tr");
        tr.innerHTML = `
          <td><b>${h.id}</b><br><span class="dim">${h.display_name}</span></td>
          <td colspan="5" class="dim">checking…</td>
          <td>${ui.badge("running")}</td>`;
        tb.appendChild(tr);
        api.get(`/hosts/${encodeURIComponent(h.id)}/preflight`).then(p => {
          const lastRun = p.last_run ? `${p.last_run.status || "?"} (${p.last_run.run_id || ""})` : "—";
          tr.innerHTML = `
            <td><b>${h.id}</b><br><span class="dim">${h.display_name}</span></td>
            <td>${p.hostname || "—"}</td>
            <td>${p.os || "—"}</td>
            <td>${p.kernel || "—"}</td>
            <td>${p.repo_present ? `<span class='badge ok'>${p.git_head||""}</span>` : "<span class='badge warn'>missing</span>"}</td>
            <td>${lastRun}</td>
            <td>${p.ok ? ui.badge("ok") : ui.badge("fail")}<br><span class="dim">${(p.error||"").slice(0,80)}</span></td>`;
        }).catch(e => {
          tr.innerHTML = `<td><b>${h.id}</b></td><td colspan="5" class="dim">error: ${String(e).slice(0,200)}</td><td>${ui.badge("fail")}</td>`;
        });
      }
    } catch (e) {
      tb.innerHTML = `<tr><td colspan="7" class="badge fail">${e}</td></tr>`;
    }
  },

  async loadSettings() {
    const s = await api.get("/settings");
    window.SETTINGS_CACHE = s;
    const f = $("#settings-form");
    f.elements.default_profile.value = s.default_profile;
    f.elements.snapshot_before_apply.checked = !!s.snapshot_before_apply;
    f.elements.notifications_desktop.checked = !!(s.notifications && s.notifications.desktop);
    f.elements.ui_theme.value    = (s.ui && s.ui.theme)    || "auto";
    f.elements.ui_language.value = (s.ui && s.ui.language) || "auto";
    f.elements.scheduler_enabled.checked = !!(s.scheduler && s.scheduler.enabled);
    f.elements.scheduler_calendar.value = (s.scheduler && s.scheduler.calendar) || "Sun *-*-* 03:00:00";
    f.elements.scheduler_profile.value = (s.scheduler && s.scheduler.profile) || "safe";
    f.elements.scheduler_no_drivers.checked = !!(s.scheduler && s.scheduler.no_drivers);
  },

  collectSettings() {
    const f = $("#settings-form");
    return {
      default_profile: f.elements.default_profile.value,
      snapshot_before_apply: f.elements.snapshot_before_apply.checked,
      notifications: { desktop: f.elements.notifications_desktop.checked },
      ui: {
        theme:    f.elements.ui_theme.value,
        language: f.elements.ui_language.value,
      },
      scheduler: {
        enabled: f.elements.scheduler_enabled.checked,
        calendar: f.elements.scheduler_calendar.value,
        profile:  f.elements.scheduler_profile.value,
        no_drivers: f.elements.scheduler_no_drivers.checked,
      },
    };
  },

  async loadSync() {
    try {
      const g = await api.get("/git/status");
      $("#sync-git").innerHTML =
        `branch <code>${g.branch}</code> ` +
        (g.dirty ? "<span class='badge warn'>dirty</span>" : "<span class='badge ok'>clean</span>") +
        ` <span class="dim">↑${g.ahead} ↓${g.behind}</span>`;
    } catch (e) { $("#sync-git").textContent = String(e); }
    try {
      const s = await api.get("/sync/status");
      if (s.available) {
        $("#sync-cloud").innerHTML =
          `${ui.badge(s.overall === "PASS" ? "ok" : "warn")} ` +
          `last verify: <code>${s.log_path}</code><br>` +
          `<span class="dim">overall: ${s.overall}</span>`;
      } else {
        $("#sync-cloud").innerHTML = `<span class="dim">${s.reason}</span>`;
      }
    } catch (e) { $("#sync-cloud").textContent = String(e); }
  },

  async syncCall(label, fn) {
    const out = $("#sync-output");
    out.textContent = `[${label}] starting…\n`;
    try {
      const r = await fn();
      out.textContent += `[${label}] ok=${r.ok}\n`;
      if (r.stdout) out.textContent += "--- stdout ---\n" + r.stdout + "\n";
      if (r.stderr) out.textContent += "--- stderr ---\n" + r.stderr + "\n";
      ui.loadSync();
    } catch (e) {
      out.textContent += `[${label}] FAILED: ${e}\n`;
    }
  },

  attachStream(runId) {
    const log = $("#live-log");
    log.textContent = "";
    const es = new EventSource(`/runs/active/stream`);
    es.addEventListener("log", e => {
      const m = JSON.parse(e.data);
      log.textContent += (m.line || "") + "\n";
      log.scrollTop = log.scrollHeight;
    });
    es.addEventListener("done", e => {
      const m = JSON.parse(e.data);
      log.textContent += `\n[done — exit ${m.exit_code}]\n`;
      ui.status(`run ${runId} done (exit ${m.exit_code})`);
      $("#stop-btn").disabled = true;
      es.close();
    });
    es.onerror = () => { es.close(); };
  },
};

// Hook nav
document.addEventListener("click", e => {
  if (e.target.matches("nav a[data-view]")) {
    e.preventDefault();
    ui.show(e.target.dataset.view);
  }
});

// Helper that retries a /runs POST after sudo modal if 401 SUDO-REQUIRED
async function startRunWithSudo(body) {
  const mutating = !body.dry_run && (!body.phase || ["apply","cleanup"].includes(body.phase));
  if (mutating) {
    const ok = await sudoMgr.ensure();
    if (!ok) throw new Error("sudo authentication cancelled");
  }
  try {
    return await api.post("/runs", body);
  } catch (e) {
    if (e.status === 401 && String(e.body || "").includes("SUDO-REQUIRED")) {
      const ok = await sudoMgr.open("sudo cache expired — re-authenticate");
      if (!ok) throw new Error("sudo authentication cancelled");
      return await api.post("/runs", body);
    }
    throw e;
  }
}

// Quick-action buttons
$$("[data-quick]").forEach(b => b.addEventListener("click", async () => {
  const body = JSON.parse(b.dataset.quick);
  try {
    const r = await startRunWithSudo(body);
    ui.show("run");
    ui.attachStream(r.run_id);
    $("#stop-btn").disabled = false;
    ui.status(`run ${r.run_id} started`);
  } catch (e) { ui.status(String(e)); }
}));

// Run form
$("#run-form").addEventListener("submit", async e => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const body = {
    profile: fd.get("profile") || null,
    only:    fd.get("only")    || null,
    phase:   fd.get("phase")   || null,
    dry_run: fd.get("dry_run") === "on",
  };
  try {
    const r = await startRunWithSudo(body);
    ui.attachStream(r.run_id);
    $("#stop-btn").disabled = false;
    ui.status(`run ${r.run_id} started`);
  } catch (err) { ui.status(String(err)); }
});

// Sudo modal handlers
$("#sudo-form").addEventListener("submit", async e => {
  e.preventDefault();
  const pw = $("#sudo-pass").value;
  $("#sudo-error").textContent = "";
  if (!pw) {
    $("#sudo-error").textContent = "password required";
    return;
  }
  try {
    const r = await fetch("/sudo/auth", {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({password: pw}),
    });
    if (r.ok) {
      sudoMgr.close(true);
      ui.status("sudo authenticated");
    } else {
      const t = await r.text();
      $("#sudo-error").textContent = `auth failed: ${t.slice(0, 200)}`;
    }
  } catch (err) {
    $("#sudo-error").textContent = String(err);
  } finally {
    $("#sudo-pass").value = "";  // never linger
  }
});
$("#sudo-cancel").addEventListener("click", () => sudoMgr.close(false));
// Refresh sudo indicator on load + every 30s
sudoMgr.refreshIndicator();
setInterval(() => sudoMgr.refreshIndicator(), 30000);

// Hosts refresh
document.addEventListener("click", e => {
  if (e.target.id === "hosts-refresh-btn") ui.loadHosts();
});

$("#stop-btn").addEventListener("click", async () => {
  try {
    await api.post("/runs/active/stop");
    ui.status("stop sent");
  } catch (e) { ui.status(String(e)); }
});

// Sync screen buttons
document.addEventListener("click", e => {
  const id = e.target.id;
  if (id === "git-fetch-btn") ui.syncCall("git fetch", () => api.post("/git/fetch"));
  if (id === "git-pull-btn")  ui.syncCall("git pull",  () => api.post("/git/pull"));
  if (id === "git-push-btn")  ui.syncCall("git push",  () => api.post("/git/push"));
  if (id === "sync-export-dry-btn") ui.syncCall("sync export (dry)", () => api.post("/sync/export?dry_run=true"));
  if (id === "sync-export-btn")     ui.syncCall("sync export",       () => api.post("/sync/export?dry_run=false"));
});

// Settings form
const settingsForm = $("#settings-form");
if (settingsForm) {
  settingsForm.addEventListener("submit", async e => {
    e.preventDefault();
    const out = $("#settings-output");
    try {
      const r = await fetch("/settings", {
        method: "PUT",
        headers: {"content-type": "application/json"},
        body: JSON.stringify(ui.collectSettings()),
      });
      const j = await r.json();
      out.textContent = "saved:\n" + JSON.stringify(j, null, 2);
    } catch (err) { out.textContent = String(err); }
  });
}
document.addEventListener("click", async e => {
  const id = e.target.id;
  const out = $("#settings-output");
  if (id === "scheduler-install-btn") {
    try {
      const r = await api.post("/scheduler/install", ui.collectSettings().scheduler);
      out.textContent = "scheduler/install:\n" + JSON.stringify(r, null, 2);
      ui.loadSettings();
    } catch (err) { out.textContent = String(err); }
  }
  if (id === "scheduler-remove-btn") {
    try {
      const r = await api.post("/scheduler/remove");
      out.textContent = "scheduler/remove:\n" + JSON.stringify(r, null, 2);
      ui.loadSettings();
    } catch (err) { out.textContent = String(err); }
  }
});

// Init: load settings first so theme/language are applied before paint flicker
async function bootstrap() {
  try {
    const s = await api.get("/settings");
    window.SETTINGS_CACHE = s;
    const themePref = (s.ui && s.ui.theme) || "auto";
    const langPref  = (s.ui && s.ui.language) || "auto";
    window.applyTheme(themePref);
    window.UI_LANG = (langPref === "en" || langPref === "pl")
      ? langPref
      : window.detectLanguage();
    window.applyI18n();
  } catch {
    window.applyTheme("auto");
    window.UI_LANG = window.detectLanguage();
    window.applyI18n();
  }
  const start = location.hash.replace("#", "") || "overview";
  ui.show(start);
  // React to OS theme switch when user picks "auto"
  if (window.matchMedia) {
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      const cur = (window.SETTINGS_CACHE && window.SETTINGS_CACHE.ui && window.SETTINGS_CACHE.ui.theme) || "auto";
      if (cur === "auto") window.applyTheme("auto");
    });
  }
}

// Apply settings live when the user changes theme/language in the form
document.addEventListener("change", e => {
  if (e.target && e.target.id === "ui-theme-select") {
    window.applyTheme(e.target.value);
  }
  if (e.target && e.target.id === "ui-language-select") {
    const v = e.target.value;
    window.UI_LANG = (v === "en" || v === "pl") ? v : window.detectLanguage();
    window.applyI18n();
  }
});

bootstrap();
window.ui = ui;
