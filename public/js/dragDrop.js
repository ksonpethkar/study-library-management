/**
 * dragDrop.js - Full Drag & Drop Engine
 * Powered by Sortable.js (loaded via CDN as window.Sortable)
 *
 * Exports:
 *   DragDropList       - Generic sortable list/container
 *   SidebarSortable    - Sidebar nav reorder (saved to API + localStorage)
 *   DashboardSortable  - Dashboard widget reorder (saved to localStorage)
 *   KanbanBoard        - Multi-column drag-between-columns (waiting list)
 *   makeRowsSortable   - Table tbody row sorting
 */

function getSortable() {
  if (typeof window !== "undefined" && window.Sortable) return window.Sortable;
  console.warn("Sortable.js not loaded - drag & drop disabled");
  return null;
}

// 1. DragDropList - Generic sortable list
export class DragDropList {
  constructor(containerId, { onReorder, handle, group, animation = 150, ghostClass = "sortable-ghost" } = {}) {
    this.containerId = containerId;
    this.container = typeof containerId === "string"
      ? document.getElementById(containerId)
      : containerId;
    this.onReorder = onReorder;
    this.handle = handle;
    this.group = group;
    this.animation = animation;
    this.ghostClass = ghostClass;
    this._instance = null;
    if (this.container) this.enable();
  }

  enable() {
    const Sortable = getSortable();
    if (!Sortable || !this.container) return;
    if (this._instance) { try { this._instance.destroy(); } catch (e) {} }
    const opts = {
      animation: this.animation,
      ghostClass: this.ghostClass,
      chosenClass: "sortable-chosen",
      dragClass: "sortable-drag",
      onEnd: () => { if (typeof this.onReorder === "function") this.onReorder(this.getOrder()); }
    };
    if (this.handle) opts.handle = this.handle;
    if (this.group) opts.group = this.group;
    this._instance = Sortable.create(this.container, opts);
  }

  disable() {
    if (this._instance) { try { this._instance.destroy(); } catch (e) {} this._instance = null; }
  }

  getOrder() {
    if (!this.container) return [];
    return Array.from(this.container.children)
      .map(c => c.dataset.id || c.dataset.widgetId || c.id || "")
      .filter(Boolean);
  }

  destroy() { this.disable(); }
}

// 2. SidebarSortable - Reorder sidebar nav, save to API + localStorage
export const SidebarSortable = {
  _instance: null,

  init() {
    const Sortable = getSortable();
    const nav = document.querySelector("nav.sidebar-nav");
    if (!Sortable || !nav) return;
    this._restoreOrder(nav);
    if (this._instance) { try { this._instance.destroy(); } catch (e) {} }
    this._instance = Sortable.create(nav, {
      animation: 200,
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      onEnd: () => this._saveOrder(nav)
    });
  },

  _getNavOrder(nav) {
    return Array.from(nav.querySelectorAll(".nav-item"))
      .map(el => el.getAttribute("href") || el.getAttribute("data-href") || "")
      .filter(Boolean);
  },

  _restoreOrder(nav) {
    try {
      const saved = localStorage.getItem("sl_sidebar_order");
      if (!saved) return;
      const order = JSON.parse(saved);
      if (!Array.isArray(order) || !order.length) return;
      const items = Array.from(nav.querySelectorAll(".nav-item"));
      const frag = document.createDocumentFragment();
      order.forEach(href => {
        const el = items.find(i => i.getAttribute("href") === href || i.getAttribute("data-href") === href);
        if (el) frag.appendChild(el);
      });
      items.forEach(el => {
        const href = el.getAttribute("href") || el.getAttribute("data-href") || "";
        if (!order.includes(href)) frag.appendChild(el);
      });
      nav.appendChild(frag);
    } catch (e) {}
  },

  async _saveOrder(nav) {
    const order = this._getNavOrder(nav);
    try { localStorage.setItem("sl_sidebar_order", JSON.stringify(order)); } catch (e) {}
    try {
      const token = localStorage.getItem("sl_token") || "";
      const res = await fetch("/api/settings/sidebar-config", {
        method: "PUT",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer " + token },
        body: JSON.stringify({ navOrder: order })
      });
      if (res.ok && window.Toast) window.Toast.success("Sidebar order saved");
    } catch (e) {}
  },

  destroy() {
    if (this._instance) { try { this._instance.destroy(); } catch (e) {} this._instance = null; }
  }
};

// 3. DashboardSortable - Reorder dashboard widgets, save to localStorage
export const DashboardSortable = {
  _instance: null,
  _storageKey: "sl_dashboard_widget_order",

  init(containerSelector = ".dashboard-grid") {
    const Sortable = getSortable();
    const container = typeof containerSelector === "string"
      ? document.querySelector(containerSelector)
      : containerSelector;
    if (!Sortable || !container) return;
    this.restoreOrder(containerSelector);
    if (this._instance) { try { this._instance.destroy(); } catch (e) {} }
    this._instance = Sortable.create(container, {
      animation: 250,
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      handle: ".widget-drag-handle",
      onEnd: () => {
        const order = Array.from(container.children)
          .map(el => el.dataset.widgetId || el.id || "").filter(Boolean);
        try { localStorage.setItem(this._storageKey, JSON.stringify(order)); } catch (e) {}
      }
    });
  },

  restoreOrder(containerSelector = ".dashboard-grid") {
    try {
      const saved = localStorage.getItem(this._storageKey);
      if (!saved) return;
      const order = JSON.parse(saved);
      if (!Array.isArray(order) || !order.length) return;
      const container = typeof containerSelector === "string"
        ? document.querySelector(containerSelector)
        : containerSelector;
      if (!container) return;
      const children = Array.from(container.children);
      const frag = document.createDocumentFragment();
      order.forEach(id => {
        const el = children.find(c => (c.dataset.widgetId || c.id) === id);
        if (el) frag.appendChild(el);
      });
      children.forEach(el => {
        const id = el.dataset.widgetId || el.id || "";
        if (!order.includes(id)) frag.appendChild(el);
      });
      container.appendChild(frag);
    } catch (e) {}
  },

  destroy() {
    if (this._instance) { try { this._instance.destroy(); } catch (e) {} this._instance = null; }
  }
};

// 4. KanbanBoard - Multi-column drag-and-drop
export class KanbanBoard {
  constructor(containerEl, { columns = [], onCardMove } = {}) {
    this.container = containerEl;
    this.columns = columns;
    this.onCardMove = onCardMove;
    this._instances = [];
    if (this.container) this._init();
  }

  _init() {
    const Sortable = getSortable();
    if (!Sortable || !this.container) return;
    const columnEls = this.container.querySelectorAll("[data-column]");
    columnEls.forEach(colEl => {
      const fromColumn = colEl.dataset.column;
      const inst = Sortable.create(colEl, {
        group: "kanban",
        animation: 200,
        ghostClass: "kanban-ghost",
        chosenClass: "kanban-chosen",
        onEnd: (evt) => {
          const toColumn = evt.to.dataset.column;
          const cardId = evt.item.dataset.id || evt.item.id || "";
          if (typeof this.onCardMove === "function" && fromColumn !== toColumn) {
            this.onCardMove({ cardId, fromColumn, toColumn });
          }
        }
      });
      this._instances.push(inst);
    });
  }

  destroy() {
    this._instances.forEach(inst => { try { inst.destroy(); } catch (e) {} });
    this._instances = [];
  }
}

// 5. makeRowsSortable - Make tbody rows sortable with drag handle
export function makeRowsSortable(tableBodyEl, { onReorder, handle = ".drag-handle" } = {}) {
  const Sortable = getSortable();
  if (!Sortable || !tableBodyEl) return null;
  return Sortable.create(tableBodyEl, {
    handle,
    animation: 150,
    ghostClass: "sortable-ghost",
    chosenClass: "sortable-chosen",
    onEnd: () => {
      const order = Array.from(tableBodyEl.querySelectorAll("tr"))
        .map(row => row.dataset.id || row.id || "").filter(Boolean);
      if (typeof onReorder === "function") onReorder(order);
    }
  });
}

// Expose on window for non-module scripts
if (typeof window !== "undefined") {
  window.DragDropList = DragDropList;
  window.SidebarSortable = SidebarSortable;
  window.DashboardSortable = DashboardSortable;
  window.KanbanBoard = KanbanBoard;
  window.makeRowsSortable = makeRowsSortable;
}
