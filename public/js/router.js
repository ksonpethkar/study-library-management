export default class Router {
  constructor() {
    this.routes = {};
    this.currentRoute = null;
    this._prevRoute = null;
    this._routeHistory = [];
    window.addEventListener('hashchange', this._onHashChange.bind(this));
  }

  addRoute(path, handler) {
    this.routes[path] = handler;
  }

  navigate(path) {
    window.location.hash = path;
  }

  getCurrentRoute() {
    return this.currentRoute;
  }

  _onHashChange(event) {
    const oldHash = event.oldURL ? '#' + (event.oldURL.split('#')[1] || '') : '';
    const newHash = event.newURL ? '#' + (event.newURL.split('#')[1] || '') : '';

    // Detect direction: forward if new route hasn't been visited, back if it has
    const histIdx = this._routeHistory.lastIndexOf(newHash.split('?')[0]);
    const isBack = histIdx !== -1 && histIdx < this._routeHistory.length - 1;

    this.handleHashChange(isBack ? 'back' : 'forward');
  }

  handleHashChange(direction = 'forward') {
    let rawHash = window.location.hash || '';
    let basePath = rawHash.split('?')[0];

    // ── RBAC Route Guard: Silently redirect student role to #/portal ────────
    try {
      const App = window.App || window.__app_instance;
      const currentUser = App?.getUser?.();
      if (currentUser && currentUser.role === 'student') {
        const allowedStudentRoutes = ['#/portal', '#/profile'];
        const isAllowed = allowedStudentRoutes.some(r => basePath === r || basePath.startsWith(r + '?'));
        if (!isAllowed) {
          window.location.hash = '#/portal';
          return;
        }
      }
    } catch (_) {}

    // Alias: if navigating to #/branches, redirect to #/seats?tab=centers
    if (basePath === '#/branches') {
      window.location.hash = '#/seats?tab=centers';
      return;
    }

    if (!rawHash && this.routes['']) {
      this._runWithTransition(this.routes[''], direction);
      return;
    }

    if (!this.routes[basePath]) {
      basePath = '#/dashboard';
      this.navigate(basePath);
      return;
    }

    // Track route history
    this._prevRoute = this.currentRoute;
    this.currentRoute = rawHash;
    if (!this._routeHistory.includes(basePath)) {
      this._routeHistory.push(basePath);
    }

    this.updateSidebarActive(basePath);

    // ── Phase D: Close mobile sidebar on every navigation ──────────────────
    // Catches programmatic nav (FAB, card clicks) not just sidebar link clicks
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebar-overlay');
    if (sidebar?.classList.contains('mobile-open')) {
      sidebar.classList.remove('mobile-open');
      overlay?.classList.remove('visible');
    }

    // ── Phase B: Scroll to top on every route change ──────────────────────
    // Critical for mobile — prevents arriving at new page mid-scroll
    const mainEl = document.getElementById('page-content') ||
                   document.getElementById('main-content') ||
                   document.querySelector('.main-content');
    if (mainEl) {
      mainEl.scrollTop = 0;
    }
    // Also scroll window for iOS standalone PWA
    window.scrollTo({ top: 0, behavior: 'instant' });

    // Unmount FAB on route change (each page re-mounts it)
    if (typeof window !== 'undefined' && window.FAB) {
      window.FAB.unmount();
    }

    this._runWithTransition(this.routes[basePath], direction);
  }

  _runWithTransition(fn, direction = 'forward') {
    fn();
  }

  updateSidebarActive(basePath) {
    document.querySelectorAll('.sidebar-nav .nav-item, .mobile-bottom-nav .mobile-tab-item, .mobile-nav .mobile-nav-item').forEach(link => {
      const linkHref = (link.getAttribute('href') || link.getAttribute('data-href') || '').split('?')[0];
      if (linkHref === basePath && linkHref !== 'javascript:void(0);' && linkHref !== 'action:menu') {
        link.classList.add('active');
      } else {
        link.classList.remove('active');
      }
    });
  }

  start() {
    this.handleHashChange('forward');
  }
}
