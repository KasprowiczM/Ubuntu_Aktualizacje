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
    $$("a[data-view]").forEach(a => a.classList.toggle("active", a.dataset.view === view));
    location.hash = view;
    // Lazy-load on first visit only. Subsequent tab switches reuse the cached
    // data — user explicitly clicks "Refresh" (or finishes a run, which calls
    // ui.invalidateCaches()) to re-fetch. This avoids the per-visit spinner
    // for slow scans (inventory takes seconds).
    ui._loaded = ui._loaded || {};
    if (view === "overview"   && !ui._loaded.overview)   { ui._loaded.overview = true;   ui.loadOverview(); }
    if (view === "categories" && !ui._loaded.categories) { ui._loaded.categories = true; ui.loadCategories(); }
    if (view === "history"    && !ui._loaded.history)    { ui._loaded.history = true;    ui.loadHistory(); }
    if (view === "sync"       && !ui._loaded.sync)       { ui._loaded.sync = true;       ui.loadSync(); }
    if (view === "settings"   && !ui._loaded.settings)   { ui._loaded.settings = true;   ui.loadSettings(); }
    if (view === "hosts"      && !ui._loaded.hosts)      { ui._loaded.hosts = true;      ui.loadHosts(); }
    if (view === "apps"       && !ui._loaded.apps)       { ui._loaded.apps = true;       ui.loadApps(); }
    if (view === "suggest"    && !ui._loaded.suggest)    { ui._loaded.suggest = true;    ui.loadSuggestions(); }
    // Run Center is special: must always (re)bind active-stream subscription.
    if (view === "run") ui.loadRunCenter();
  },
  invalidateCaches() {
    // Called after a run completes or when the user hits "Refresh".
    ui._loaded = {};
    window.INV_SUMMARY = null;
  },

  async maybeShowWizard() {
    try {
      const s = await api.get("/onboarding/state");
      if (s.onboarded) return;
      $("#wizard-modal").classList.remove("hidden");
    } catch {}
  },

  async finishWizard(skip) {
    const modal = $("#wizard-modal");
    const langPick = (document.querySelector("input[name=wiz-lang]:checked") || {}).value || "en";
    const choices = skip ? {skipped: true} : {
      language:        langPick,
      default_profile: (document.querySelector("input[name=wiz-profile]:checked") || {}).value || "safe",
      schedule:        $("#wiz-schedule").checked,
      snapshot_before_apply: $("#wiz-snapshot").checked,
    };
    if (!skip) {
      // Apply language change immediately so the rest of the dashboard switches.
      window.UI_LANG = langPick;
      try { window.applyI18n(); } catch {}
    }
    try {
      await api.post("/onboarding/complete", choices);
      if (!skip) {
        // Persist into settings.json so next sessions honour the choices.
        const cur = window.SETTINGS_CACHE || (await api.get("/settings"));
        const merged = {
          ...cur,
          default_profile: choices.default_profile,
          snapshot_before_apply: !!choices.snapshot_before_apply,
        };
        await fetch("/settings", {method:"PUT", headers:{"content-type":"application/json"},
                                  body: JSON.stringify(merged)});
        if (choices.schedule) {
          await api.post("/scheduler/install", {calendar:"Sun *-*-* 03:00:00",
                                                profile: choices.default_profile});
        }
      }
    } catch (e) { console.warn("wizard:", e); }
    modal.classList.add("hidden");
  },

  async checkRebootBanner() {
    try {
      const p = await api.get("/preflight");
      const banner = $("#reboot-banner");
      if (p.needs_reboot) banner.classList.remove("hidden");
      else                banner.classList.add("hidden");
    } catch {}
  },

  async rebootNow() {
    if (!confirm(
      tr("overview.reboot_confirm")
      || "Restart the computer now? Any unsaved work will be lost."
    )) return;
    const ok = await sudoMgr.ensure();
    if (!ok) { ui.status(tr("overview.reboot_no_sudo") || "sudo required"); return; }
    try {
      await api.post("/system/reboot?delay=5", {});
      ui.status(tr("overview.reboot_scheduled") || "reboot scheduled in 5s — saving your work now is recommended");
      $("#reboot-banner").innerHTML =
        `<span class="reboot-banner-icon">⏻</span> rebooting in 5 seconds…`;
    } catch (e) { ui.status(String(e)); }
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

  async loadHealth() {
    const card = $("#health-card");
    if (!card) return;
    try {
      const h = await api.get("/health/check");
      if (!h.available) {
        card.innerHTML = `<p class="dim">${tr("health.no_data")}</p>`;
        return;
      }
      const score = h.score ?? 0;
      const cls = score >= 85 ? "good" : score >= 60 ? "warn" : "bad";
      const lbl = score >= 85 ? tr("health.good")
                : score >= 60 ? tr("health.warn")
                : tr("health.bad");
      const issues = h.issues || [];
      card.innerHTML =
        `<div class="health-score ${cls}">${score}<span style="font-size:0.5em;color:var(--dim)">/100</span></div>
         <div style="text-align:center"><b>${lbl}</b></div>
         ${issues.length ? `<div class="health-issues"><ul>${issues.map(i =>
            `<li><span class="badge ${i.severity === "err" ? "fail" : "warn"}">${i.severity}</span> ${i.msg}</li>`
          ).join("")}</ul></div>` : ""}
         ${h.run_id ? `<div class="dim" style="font-size:0.7rem;margin-top:0.4rem">run: <code>${h.run_id}</code></div>` : ""}`;
    } catch (e) { card.innerHTML = `<p class="dim">${e}</p>`; }
  },

  async loadSuggestions() {
    const wrap = $("#suggest-list");
    wrap.innerHTML = `<span class="spinner"></span> ${tr("overview.scanning")}`;
    try {
      const items = (await api.get("/suggestions")).items || [];
      if (!items.length) {
        wrap.innerHTML = `<p class="dim">${tr("suggest.empty")}</p>`;
      } else {
        wrap.innerHTML = items.map(s => {
          const conf = s.confidence === "high" ? "confidence-high" :
                       s.confidence === "med"  ? "confidence-med" : "confidence-low";
          const confLbl = s.confidence === "high" ? tr("suggest.conf_high")
                        : s.confidence === "med"  ? tr("suggest.conf_med")
                        :                            tr("suggest.conf_low");
          const diffStr = (s.diff||[]).map(d => {
            const adds = (d.add||[]).map(L => `<span class="add">+ ${L}</span>`).join("\n");
            const dels = (d.remove||[]).map(L => `<span class="del">- ${L}</span>`).join("\n");
            return `${d.file}\n${[adds, dels].filter(Boolean).join("\n")}`;
          }).join("\n\n");
          return `
            <div class="suggestion ${conf}" data-sid="${s.id}">
              <h4>${s.title}</h4>
              <div class="meta">${confLbl} · ${s.category} · source: ${s.source}</div>
              <p>${s.rationale}</p>
              ${diffStr ? `<pre class="diff">${diffStr}</pre>` : ""}
              <div class="actions">
                ${(s.diff||[]).length ? `<button data-sg-apply='${JSON.stringify({id:s.id,diff:s.diff})}'>${tr("suggest.btn_apply")}</button>` : ""}
                <button class="secondary" data-sg-dismiss="${s.id}">${tr("suggest.btn_dismiss")}</button>
              </div>
            </div>`;
        }).join("");
      }
      // Load AI form values
      const s = await api.get("/settings");
      const ai = s.ai || {};
      const f = $("#ai-form");
      if (f) {
        f.elements.ai_provider.value = ai.provider || "";
        f.elements.ai_api_key.value  = ai.api_key  || "";
        f.elements.ai_model.value    = ai.model    || "";
      }
    } catch (e) {
      wrap.innerHTML = `<p class="badge fail">${e}</p>`;
    }
  },

  async applySuggestion(payload) {
    try {
      const r = await api.post("/suggestions/apply", payload);
      ui.status(`applied: ${(r.changes||[]).map(c=>c.file).join(", ")}`);
      ui._loaded.suggest = false; ui.loadSuggestions();
    } catch (e) { ui.status(String(e)); }
  },
  async dismissSuggestion(sid) {
    try { await api.post("/suggestions/dismiss", {id: sid}); }
    catch (e) { ui.status(String(e)); return; }
    ui._loaded.suggest = false; ui.loadSuggestions();
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
    ui.loadHealth();
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

  async loadApps() {
    const wrap = $("#apps-table-wrap");
    const summary = $("#apps-summary");
    wrap.innerHTML = `<span class="spinner"></span> ${tr("overview.scanning") || "Scanning…"}`;
    summary.textContent = "";
    try {
      const [data, excl] = await Promise.all([
        api.get("/apps/detect"),
        api.get("/exclusions").catch(() => ({items:[], category_skipped:[]})),
      ]);
      const s = data.summary || {tracked:0, detected:0, missing:0};
      const exclSet = new Set((excl.items||[]).map(e => `${e.category}:${e.package}`));
      const exclCats = new Set(excl.category_skipped || []);
      summary.innerHTML = `
        <span class="st-pill st-info">tracked ${s.tracked}</span>
        <span class="st-pill st-warn">detected ${s.detected}</span>
        <span class="st-pill st-err">missing ${s.missing}</span>
        <span class="st-pill st-skip">excluded ${exclSet.size}${exclCats.size?` +${exclCats.size} cats`:""}</span>`;
      const items = data.items || [];
      const rank = {missing:0, detected:1, tracked:2};
      items.sort((a,b) =>
        (rank[a.state]??9) - (rank[b.state]??9) ||
        a.category.localeCompare(b.category) ||
        a.package.localeCompare(b.package));
      const stCls = {tracked:"st-info", detected:"st-warn", missing:"st-err"};
      const rows = items.map(it => {
        const key = `${it.category}:${it.package}`;
        const isExcl = exclSet.has(key) || exclCats.has(it.category);
        return `
        <tr class="${isExcl ? "excluded" : ""}">
          <td>${it.category}</td>
          <td class="col-mono pkg-name">${it.package}</td>
          <td><span class="st-pill ${stCls[it.state]||"st-skip"}">${it.state}</span></td>
          <td class="excl-toggle">
            <label title="Skip this package on apply phases">
              <input type="checkbox" data-excl-toggle data-pkg="${it.package}" data-cat="${it.category}" ${isExcl ? "checked" : ""} />
              skip
            </label>
          </td>
          <td>
            ${it.state === "detected"
              ? `<button class="secondary" data-apps-add data-pkg="${it.package}" data-cat="${it.category}">+ Add to config</button>`
              : it.state === "tracked"
              ? `<button class="secondary" data-apps-rm data-pkg="${it.package}" data-cat="${it.category}">Remove</button>`
              : `<span class="dim">${it.suggested||""}</span>`}
          </td>
        </tr>`;
      }).join("");
      wrap.innerHTML = `
        <table class="tbl">
          <thead><tr><th>Category</th><th>Package</th><th>State</th><th>Auto-update</th><th>Action</th></tr></thead>
          <tbody>${rows||"<tr><td colspan='5' class='dim'>—</td></tr>"}</tbody>
        </table>`;
    } catch (e) {
      wrap.textContent = String(e);
    }
  },

  async toggleExclusion(pkg, cat, on) {
    try {
      await api.post(on ? "/exclusions/add" : "/exclusions/remove", {package: pkg, category: cat});
      ui.status(on ? `excluded ${cat}:${pkg}` : `un-excluded ${cat}:${pkg}`);
    } catch (e) { ui.status(String(e)); }
  },

  async appsAdd(pkg, cat) {
    try { await api.post("/apps/add", {package: pkg, category: cat}); }
    catch (e) { ui.status(String(e)); return; }
    ui._loaded.apps = false; ui.show("apps");
  },
  async appsRemove(pkg, cat) {
    if (!confirm(`Remove ${pkg} from ${cat} config? (does NOT uninstall)`)) return;
    try { await api.post("/apps/remove", {package: pkg, category: cat}); }
    catch (e) { ui.status(String(e)); return; }
    ui._loaded.apps = false; ui.show("apps");
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
          <div class="cat-actions">
            <button class="phase-check"   data-cat-run data-only="${c.id}" data-phase="check">check</button>
            <button class="phase-plan"    data-cat-run data-only="${c.id}" data-phase="plan">plan</button>
            <button class="phase-apply"   data-cat-run data-only="${c.id}" data-phase="apply">apply</button>
            <button class="phase-verify"  data-cat-run data-only="${c.id}" data-phase="verify">verify</button>
            <button class="phase-cleanup" data-cat-run data-only="${c.id}" data-phase="cleanup">cleanup</button>
            <button class="phase-all"     data-cat-run data-only="${c.id}" data-phase="" title="Run all phases for this category">▶ run all</button>
          </div>
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
    // Per-category phase buttons → start the run directly (with sudo for mutating).
    $$("#cats-table button[data-cat-run]").forEach(b => b.addEventListener("click", async e => {
      e.stopPropagation();
      const body = {
        only: b.dataset.only || null,
        phase: b.dataset.phase || null,
        dry_run: false,
      };
      try {
        const r = await startRunWithSudo(body);
        ui.show("run");
        ui.attachStream(r.run_id);
        $("#stop-btn").disabled = false;
        ui.status(`run ${r.run_id} started — ${body.only}/${body.phase || "all phases"}`);
      } catch (err) { ui.status(String(err)); }
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
            <th>Action</th>
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
                <td>${it.in_config
                  ? `<button class="secondary" data-cat-rm data-pkg="${it.name}" data-cat="${cat}" title="Remove from config (does NOT uninstall)">remove</button>`
                  : `<button class="secondary" data-cat-add data-pkg="${it.name}" data-cat="${cat}" title="Add to config so future updates include it">+ add</button>`}</td>
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
    const [rows, eta] = await Promise.all([
      api.get("/runs?limit=200").then(d => d.runs),
      api.get("/telemetry/eta").catch(() => ({profiles:{}})),
    ]);
    // Header line: shows expected duration for each profile based on history.
    const etaTxt = Object.entries(eta.profiles||{}).map(([prof, p]) =>
      `<span class="badge ${p.ok_pct>=90?"ok":p.ok_pct>=70?"warn":"fail"}">${prof}</span> avg ${Math.round(p.avg_seconds/60)}m, p90 ${Math.round(p.p90_seconds/60)}m, ${p.ok_pct}% ok (${p.samples})`
    ).join(" · ");
    $("#history-eta").innerHTML = etaTxt
      ? `Based on history: ${etaTxt}`
      : "<span class='dim'>No prior runs to compute ETA from yet.</span>";
    const tb = $("#history-table tbody");
    tb.innerHTML = "";
    for (const r of rows) {
      const tr = document.createElement("tr");
      const phaseSummary = r.summary && r.summary.phases
        ? `${r.summary.phases.length} phase(s)` : "—";
      let durStr = "—";
      if (r.started_at && r.ended_at) {
        try {
          const a = new Date(r.started_at), b = new Date(r.ended_at);
          const sec = Math.max(0, Math.round((b - a) / 1000));
          durStr = sec >= 60 ? `${Math.floor(sec/60)}m${sec%60}s` : `${sec}s`;
        } catch {}
      }
      tr.innerHTML = `
        <td>${ui.fmtTime(r.started_at)}</td>
        <td>${r.profile || "—"}${r.dry_run ? " <span class='dim'>(dry)</span>":""}</td>
        <td>${ui.badge(r.status)}</td>
        <td class="duration">${durStr}</td>
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
    const prog = $("#run-progress");
    const fill = prog.querySelector(".run-progress-fill");
    const lbl  = prog.querySelector(".run-progress-label");
    const rec  = prog.querySelector(".run-progress-recent");
    rec.innerHTML = ""; lbl.innerHTML = ""; fill.style.width = "0%";
    prog.classList.add("hidden");
    const stripAnsi = s => s.replace(/\x1b\[[0-9;]*m/g, "");

    // Parse PROGRESS|... markers emitted by lib/progress.sh + apt awk parser.
    function handleMarker(line) {
      const stripped = stripAnsi(line);
      if (!stripped.startsWith("PROGRESS|")) return false;
      const parts = stripped.split("|");
      const kind = parts[1];
      if (kind === "start") {
        const total = +parts[3]; const label = parts[4] || parts[2];
        prog.classList.remove("hidden");
        lbl.innerHTML = `<span><b>${label}</b> — 0/${total}</span><span class="dim">running…</span>`;
        fill.style.width = "0%";
        rec.innerHTML = "";
        prog._total = total;
      } else if (kind === "step") {
        const n = +parts[3], total = +parts[4], status = parts[5], msg = parts.slice(6).join("|");
        const pct = total > 0 ? Math.round((n/total) * 100) : 0;
        fill.style.width = pct + "%";
        lbl.innerHTML = `<span><b>${parts[2]}</b> — ${n}/${total}</span><span class="dim">${pct}%</span>`;
        const div = document.createElement("div");
        div.className = status;
        div.textContent = `[${n}/${total}] ${msg}`;
        rec.prepend(div);
        // Cap to last 12 entries to keep DOM light.
        while (rec.children.length > 12) rec.removeChild(rec.lastChild);
      } else if (kind === "done") {
        const ok = +parts[3], warn = +parts[4], err = +parts[5];
        lbl.innerHTML = `<span><b>${parts[2]}</b> — done</span>` +
          `<span><span class="badge ok">${ok}</span> ` +
          `<span class="badge ${warn?"warn":"ok"}">${warn} warn</span> ` +
          `<span class="badge ${err?"fail":"ok"}">${err} err</span></span>`;
        fill.style.width = "100%";
        // Auto-hide after a short delay; user still sees the recent list.
        setTimeout(() => { if (prog._total === +parts[3]) prog.classList.add("hidden"); }, 4000);
      }
      return true;
    }

    const es = new EventSource(`/runs/active/stream`);
    es.addEventListener("log", e => {
      const m = JSON.parse(e.data);
      const ln = m.line || "";
      if (!handleMarker(ln)) {
        log.textContent += ln + "\n";
        log.scrollTop = log.scrollHeight;
      }
    });
    es.addEventListener("done", e => {
      const m = JSON.parse(e.data);
      log.textContent += `\n[done — exit ${m.exit_code}]\n`;
      ui.status(`run ${runId} done (exit ${m.exit_code})`);
      $("#stop-btn").disabled = true;
      prog.classList.add("hidden");
      es.close();
      ui.invalidateCaches();
      ui.checkRebootBanner();
      ui.loadHealth();
    });
    es.onerror = () => { es.close(); };
  },
};

// Hook nav (works for both old top-nav and new sidebar nav-link)
document.addEventListener("click", e => {
  const a = e.target.closest("a[data-view]");
  if (!a) return;
  e.preventDefault();
  ui.show(a.dataset.view);
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

// Quick-action buttons. Use delegation so dynamically-added buttons (e.g.
// inside a re-rendered card) inherit the handler.
document.addEventListener("click", async e => {
  const b = e.target.closest("[data-quick]");
  if (!b) return;
  let body;
  try { body = JSON.parse(b.dataset.quick); } catch { return; }
  // Confirm destructive NVIDIA path.
  if ((body.extra_args || []).includes("--nvidia")) {
    if (!confirm("Apply NVIDIA driver upgrade?\n\nNVIDIA drivers are held by default because DKMS rebuilds can fail. The upgrade will run apt with --only-upgrade nvidia-driver-*, then verify nvidia-smi.")) return;
  }
  try {
    const r = await startRunWithSudo(body);
    ui.show("run");
    ui.attachStream(r.run_id);
    $("#stop-btn").disabled = false;
    ui.status(`run ${r.run_id} started`);
  } catch (err) { ui.status(String(err)); }
});

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

// First-run wizard
document.addEventListener("click", e => {
  if (e.target.id === "wizard-finish") ui.finishWizard(false);
  if (e.target.id === "wizard-skip")   ui.finishWizard(true);
});

// Reboot banner
document.addEventListener("click", e => {
  if (e.target.id === "reboot-now-btn")     ui.rebootNow();
  if (e.target.id === "reboot-dismiss-btn") $("#reboot-banner").classList.add("hidden");
  if (e.target.id === "overview-refresh-btn") {
    ui.invalidateCaches();
    ui._loaded.overview = true;
    ui.loadOverview();
    ui.checkRebootBanner();
  }
  if (e.target.id === "apps-refresh-btn") {
    ui._loaded.apps = false; ui.loadApps();
  }
  const addBtn = e.target.closest("[data-apps-add]");
  if (addBtn) ui.appsAdd(addBtn.dataset.pkg, addBtn.dataset.cat);
  const rmBtn = e.target.closest("[data-apps-rm]");
  if (rmBtn) ui.appsRemove(rmBtn.dataset.pkg, rmBtn.dataset.cat);
  if (e.target.id === "inv-refresh-btn") {
    // Inventory-only refresh: clears the backend cache too.
    api.post("/inventory/refresh", {}).catch(()=>{});
    window.INV_SUMMARY = null;
    ui.loadInventoryDashboard();
  }
});

// Hosts refresh
document.addEventListener("click", e => {
  if (e.target.id === "hosts-refresh-btn") ui.loadHosts();
});

// Suggestions panel
document.addEventListener("click", async e => {
  if (e.target.id === "suggest-refresh-btn") { ui._loaded.suggest = false; ui.loadSuggestions(); }
  const ap = e.target.closest("[data-sg-apply]");
  if (ap) {
    try { ui.applySuggestion(JSON.parse(ap.dataset.sgApply)); }
    catch (err) { ui.status(String(err)); }
  }
  const dm = e.target.closest("[data-sg-dismiss]");
  if (dm) ui.dismissSuggestion(dm.dataset.sgDismiss);
  if (e.target.id === "health-recheck-btn") {
    try { await api.post("/health/run"); } catch {}
    ui.loadHealth();
  }
  if (e.target.id === "backup-export-btn") {
    location.href = "/backup/export";
  }
});

// AI form (in Suggestions tab)
document.addEventListener("submit", async e => {
  if (e.target && e.target.id === "ai-form") {
    e.preventDefault();
    const f = e.target;
    const out = $("#ai-output");
    try {
      const cur = await api.get("/settings");
      const merged = {...cur, ai: {
        provider: f.elements.ai_provider.value,
        api_key:  f.elements.ai_api_key.value,
        model:    f.elements.ai_model.value,
      }};
      const r = await fetch("/settings", {method:"PUT",
        headers:{"content-type":"application/json"}, body: JSON.stringify(merged)});
      out.textContent = r.ok ? "saved" : `error ${r.status}`;
      ui._loaded.suggest = false; ui.loadSuggestions();
    } catch (err) { out.textContent = String(err); }
  }
});

// Exclusion checkboxes (in Apps tab)
document.addEventListener("change", e => {
  const t = e.target.closest("[data-excl-toggle]");
  if (t) ui.toggleExclusion(t.dataset.pkg, t.dataset.cat, t.checked);
});

// Backup import (file upload)
document.addEventListener("change", async e => {
  if (e.target && e.target.id === "backup-import-file") {
    const f = e.target.files[0];
    if (!f) return;
    const out = $("#backup-output");
    out.textContent = `Uploading ${f.name} (${Math.round(f.size/1024)}KB)…`;
    try {
      const r = await fetch("/backup/import", {
        method: "POST",
        headers: {"content-type": "application/gzip"},
        body: f,
      });
      const j = await r.json();
      out.textContent = r.ok
        ? `restored ${(j.restored||[]).length} files. Reload the page.`
        : `failed: ${JSON.stringify(j)}`;
    } catch (err) { out.textContent = String(err); }
  }
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

// ── Inject inline icons into nav + topbar buttons ──────────────────────
function injectIcons() {
  if (!window.ICONS) return;
  document.querySelectorAll("[data-icon]").forEach(el => {
    const slot = el.querySelector(".nav-icon");
    const target = slot || el;
    const ic = window.ICONS[el.dataset.icon];
    if (ic) target.innerHTML = ic;
  });
  // Topbar buttons get icons that reflect current state.
  const setBtn = (id, key) => {
    const b = document.getElementById(id);
    if (b && window.ICONS[key]) b.innerHTML = window.ICONS[key];
  };
  setBtn("sidebar-toggle", "menu");
  setBtn("lang-switcher",  "globe");
  setBtn("theme-switcher", (document.documentElement.dataset.theme === "dark") ? "moon" : "sun");
  setBtn("font-switcher",  "type");
}

// ── Sidebar drawer (mobile) ────────────────────────────────────────────
function bindSidebar() {
  const shell = document.body;
  const open  = () => { shell.classList.add("sidebar-open"); $("#sidebar-backdrop")?.classList.remove("hidden"); };
  const close = () => { shell.classList.remove("sidebar-open"); $("#sidebar-backdrop")?.classList.add("hidden"); };
  $("#sidebar-toggle")?.addEventListener("click", () => {
    shell.classList.contains("sidebar-open") ? close() : open();
  });
  $("#sidebar-backdrop")?.addEventListener("click", close);
  // Close drawer after picking a nav item on mobile.
  document.addEventListener("click", e => {
    if (window.matchMedia("(max-width: 768px)").matches && e.target.closest(".sidebar-nav .nav-link")) close();
  });
}

// ── Topbar switchers: theme / language / font-size ─────────────────────
function bindSwitchers() {
  const root = document.documentElement;
  // Theme cycle: auto → light → dark → auto
  $("#theme-switcher")?.addEventListener("click", () => {
    const order = ["auto", "light", "dark"];
    const cur = root.dataset.theme || "auto";
    const next = order[(order.indexOf(cur) + 1) % order.length];
    window.applyTheme(next);
    // Persist into settings.
    fetch("/settings", {method:"PUT", headers:{"content-type":"application/json"},
      body: JSON.stringify({...(window.SETTINGS_CACHE||{}), ui:{...((window.SETTINGS_CACHE||{}).ui||{}), theme: next}})}).catch(()=>{});
    // Repaint icon (sun/moon/auto).
    const k = next === "dark" ? "moon" : next === "light" ? "sun" : "globe";
    if (window.ICONS) $("#theme-switcher").innerHTML = window.ICONS[k];
    ui.status(`theme: ${next}`);
  });
  // Language cycle: en ↔ pl
  $("#lang-switcher")?.addEventListener("click", () => {
    const cur = window.UI_LANG || "en";
    const next = cur === "en" ? "pl" : "en";
    window.UI_LANG = next; window.applyI18n();
    fetch("/settings", {method:"PUT", headers:{"content-type":"application/json"},
      body: JSON.stringify({...(window.SETTINGS_CACHE||{}), ui:{...((window.SETTINGS_CACHE||{}).ui||{}), language: next}})}).catch(()=>{});
    ui.status(`language: ${next}`);
  });
  // Font cycle: sm → md → lg → sm
  $("#font-switcher")?.addEventListener("click", () => {
    const order = ["sm", "md", "lg"];
    const cur = root.dataset.font || "md";
    const next = order[(order.indexOf(cur) + 1) % order.length];
    root.dataset.font = next;
    try { localStorage.setItem("ui-font", next); } catch {}
    ui.status(`font size: ${next}`);
  });
  // Restore persisted font choice.
  try {
    const f = localStorage.getItem("ui-font");
    if (f && ["sm","md","lg"].includes(f)) root.dataset.font = f;
    else root.dataset.font = "md";
  } catch { root.dataset.font = "md"; }
}

// ── Categories add-widget: append package to a config list ─────────────
async function bindCatsAddWidget() {
  // Populate <select> with categories.
  try {
    const cats = (await api.get("/categories")).categories || [];
    const sel = $("#cats-add-cat");
    if (sel && !sel.options.length || (sel && sel.options.length <= 1)) {
      for (const c of cats) {
        if (!c.id) continue;
        // Skip categories without a config/*.list file (drivers, inventory).
        if (["drivers", "inventory"].includes(c.id)) continue;
        const o = document.createElement("option");
        o.value = c.id; o.textContent = c.id;
        sel.appendChild(o);
      }
    }
  } catch {}
}
// Inline +add / remove buttons inside Categories detail
document.addEventListener("click", async e => {
  const ad = e.target.closest("[data-cat-add]");
  if (ad) {
    try {
      await api.post("/apps/add", {package: ad.dataset.pkg, category: ad.dataset.cat});
      ui.status(`added ${ad.dataset.cat}:${ad.dataset.pkg}`);
      // Refresh just this expanded detail.
      ui.loadCategoryDetail(ad.dataset.cat);
    } catch (err) { ui.status(String(err)); }
  }
  const rm = e.target.closest("[data-cat-rm]");
  if (rm) {
    if (!confirm(`Remove ${rm.dataset.pkg} from ${rm.dataset.cat} config?\n(does NOT uninstall the package itself)`)) return;
    try {
      await api.post("/apps/remove", {package: rm.dataset.pkg, category: rm.dataset.cat});
      ui.status(`removed ${rm.dataset.cat}:${rm.dataset.pkg}`);
      ui.loadCategoryDetail(rm.dataset.cat);
    } catch (err) { ui.status(String(err)); }
  }
});

document.addEventListener("click", async e => {
  if (e.target.id === "cats-add-btn") {
    const cat = $("#cats-add-cat").value;
    const pkg = $("#cats-add-pkg").value.trim();
    const out = $("#cats-add-out");
    if (!cat || !pkg) { out.textContent = "pick a category and type a package name"; return; }
    out.textContent = "adding…";
    try {
      const r = await api.post("/apps/add", {package: pkg, category: cat});
      out.textContent = r.ok ? `added ${cat}:${pkg}` : `error: ${(r.stderr||"").slice(0,200)}`;
      $("#cats-add-pkg").value = "";
      ui._loaded.categories = false; ui._loaded.apps = false;
      // Re-render Categories so the new package shows in the detail expand.
      ui.show("categories");
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
  injectIcons();
  bindSidebar();
  bindSwitchers();
  bindCatsAddWidget();
  const start = location.hash.replace("#", "") || "overview";
  ui.show(start);
  ui.checkRebootBanner();
  ui.maybeShowWizard();
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
