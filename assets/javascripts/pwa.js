// On every page: registers the service worker (makes Redmine installable), and
// - when opened as an installed app: a back button in the header (installed apps have no browser buttons, and
//   iPhones have no back gesture or button of their own there);
// - the status bar matches the header's colour, including in dark mode;
// - "Install app" in the menu: Android's install prompt, or on iPhone how to add it to the home screen.
(function () {
  'use strict';

  var config = window.RedminePwa || {};
  var labels = config.labels || {};
  var standalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  var ios = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var installPrompt = null;

  if ('serviceWorker' in navigator && config.serviceWorker) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register(config.serviceWorker).catch(function () {});
    });
  }
  if (standalone) document.documentElement.classList.add('pwa-standalone');

  // Android: keep the browser's install prompt for our menu link
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    installPrompt = e;
    showInstallLinks();
  });
  window.addEventListener('appinstalled', function () {
    installPrompt = null;
    document.querySelectorAll('.pwa-install').forEach(function (el) { el.remove(); });
  });

  function updateThemeColor() {
    var header = document.getElementById('header');
    var meta = document.querySelector('meta[name="theme-color"]');
    if (!header || !meta) return;
    var color = getComputedStyle(header).backgroundColor;
    if (color && color !== 'rgba(0, 0, 0, 0)' && color !== 'transparent') meta.setAttribute('content', color);
  }

  function addBackButton() {
    var header = document.getElementById('header');
    if (!header || window.history.length <= 1) return;
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'pwa-back';
    button.title = labels.back || 'Back';
    button.setAttribute('aria-label', labels.back || 'Back');
    button.innerHTML = '<svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true"><path d="M15 6l-6 6 6 6" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    button.addEventListener('click', function () { window.history.back(); });
    header.insertBefore(button, header.firstChild);
  }

  function showIosSteps() {
    var overlay = document.createElement('div');
    overlay.className = 'pwa-dialog-overlay';
    var dialog = document.createElement('div');
    dialog.className = 'pwa-dialog';
    dialog.setAttribute('role', 'dialog');
    dialog.setAttribute('aria-modal', 'true');
    var title = document.createElement('h3');
    title.textContent = labels.iosTitle;
    var steps = document.createElement('p');
    steps.textContent = labels.iosSteps;
    var ok = document.createElement('button');
    ok.type = 'button';
    ok.className = 'pwa-button';
    ok.textContent = labels.ok || 'OK';
    function close() { overlay.remove(); }
    ok.addEventListener('click', close);
    overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
    dialog.appendChild(title);
    dialog.appendChild(steps);
    dialog.appendChild(ok);
    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
    ok.focus();
  }

  function install(e) {
    e.preventDefault();
    if (installPrompt) {
      installPrompt.prompt();
      installPrompt.userChoice.finally(function () { installPrompt = null; });
    } else if (ios) {
      showIosSteps();
    }
  }

  // In the phone menu (the top bar is hidden on phones), and in the top bar on computers
  function showInstallLinks() {
    if (standalone || !config.loggedIn || document.querySelector('.pwa-install')) return;
    if (!installPrompt && !ios) return;
    var flyout = document.querySelector('.js-flyout-menu');
    if (flyout) {
      var list = document.createElement('ul');
      list.className = 'pwa-install pwa-install-flyout';
      list.innerHTML = '<li><a href="#"></a></li>';
      flyout.appendChild(list);
    }
    var account = document.querySelector('#top-menu #account ul');
    if (account) {
      var item = document.createElement('li');
      item.className = 'pwa-install';
      item.innerHTML = '<a href="#"></a>';
      account.insertBefore(item, account.firstChild);
    }
    document.querySelectorAll('.pwa-install a').forEach(function (a) {
      a.textContent = labels.install;
      a.addEventListener('click', install);
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (standalone) addBackButton();
    updateThemeColor();
    showInstallLinks();
    // Dark mode switched, or the page crossed the phone/computer width (the header colour differs)
    document.addEventListener('redmine:color-scheme', function () { requestAnimationFrame(updateThemeColor); });
    var phone = window.matchMedia('(max-width: 899px)');
    if (phone.addEventListener) phone.addEventListener('change', updateThemeColor);
    // Signing out forgets anything shared but not yet added to an issue
    document.addEventListener('click', function (e) {
      if (e.target.closest && e.target.closest('a.logout') && 'caches' in window) caches.delete('redmine-pwa-shared');
    });
  });
})();
