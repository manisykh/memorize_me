(() => {
  const menuButton = document.querySelector('.menu-button');
  const nav = document.querySelector('.site-nav');
  menuButton?.addEventListener('click', () => {
    const open = menuButton.getAttribute('aria-expanded') === 'true';
    menuButton.setAttribute('aria-expanded', String(!open));
    nav?.classList.toggle('open', !open);
  });
  nav?.addEventListener('click', (event) => {
    if (event.target instanceof HTMLAnchorElement) {
      menuButton?.setAttribute('aria-expanded', 'false');
      nav.classList.remove('open');
    }
  });

  function setupTabs(root) {
    const tabs = [...root.querySelectorAll('[role="tab"]')];
    const panels = [...root.querySelectorAll('[role="tabpanel"]')];
    const activate = (tab) => {
      tabs.forEach((item) => {
        const active = item === tab;
        item.setAttribute('aria-selected', String(active));
        item.tabIndex = active ? 0 : -1;
      });
      panels.forEach((panel) => { panel.hidden = panel.id !== tab.getAttribute('aria-controls'); });
    };
    tabs.forEach((tab, index) => {
      tab.addEventListener('click', () => activate(tab));
      tab.addEventListener('keydown', (event) => {
        let next = null;
        if (event.key === 'ArrowRight') next = tabs[(index + 1) % tabs.length];
        if (event.key === 'ArrowLeft') next = tabs[(index - 1 + tabs.length) % tabs.length];
        if (event.key === 'Home') next = tabs[0];
        if (event.key === 'End') next = tabs[tabs.length - 1];
        if (next) { event.preventDefault(); activate(next); next.focus(); }
      });
    });
    if (root.dataset.tabs === 'modes') {
      root.querySelector('[data-mode-prev]')?.addEventListener('click', () => {
        const index = tabs.findIndex((tab) => tab.getAttribute('aria-selected') === 'true');
        tabs[(index - 1 + tabs.length) % tabs.length].click();
      });
      root.querySelector('[data-mode-next]')?.addEventListener('click', () => {
        const index = tabs.findIndex((tab) => tab.getAttribute('aria-selected') === 'true');
        tabs[(index + 1) % tabs.length].click();
      });
    }
  }
  document.querySelectorAll('[data-tabs]').forEach(setupTabs);
})();
