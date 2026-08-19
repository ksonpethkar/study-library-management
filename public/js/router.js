export default class Router {
  constructor() {
    this.routes = {};
    this.currentRoute = null;
    window.addEventListener('hashchange', this.handleHashChange.bind(this));
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

  handleHashChange() {
    let rawHash = window.location.hash || '';
    let basePath = rawHash.split('?')[0];

    // Alias: if navigating to #/branches, redirect to #/seats?tab=centers
    if (basePath === '#/branches') {
      window.location.hash = '#/seats?tab=centers';
      return;
    }

    if (!rawHash && this.routes['']) {
      this.routes['']();
      return;
    }
    
    if (!this.routes[basePath]) {
      basePath = '#/dashboard';
      this.navigate(basePath);
      return;
    }
    
    this.currentRoute = rawHash;
    this.updateSidebarActive(basePath);
    this.routes[basePath]();
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
    this.handleHashChange();
  }
}
