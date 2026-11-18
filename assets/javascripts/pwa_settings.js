// The plugin's settings page: uploads a new app icon (saved straight away, outside the settings form) or goes back
// to the default one, and previews it as Android (cropped to a circle) and iPhone (rounded square) show it.
(function () {
  'use strict';

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }

  document.addEventListener('DOMContentLoaded', function () {
    var root = document.querySelector('.pwa-icon-setting');
    if (!root) return;
    var labels = JSON.parse(root.getAttribute('data-labels') || '{}');
    var url = root.getAttribute('data-upload-url');
    var file = root.querySelector('.pwa-icon-file');
    var remove = root.querySelector('.pwa-icon-remove');
    var status = root.querySelector('.pwa-icon-status');
    var version = root.querySelector('.pwa-icon-version');
    var color = root.querySelector('#settings_icon_background');
    var android = root.querySelector('.pwa-icon-android img');
    var iphone = root.querySelector('.pwa-icon-iphone img');

    function paint() {
      root.style.setProperty('--pwa-icon-background', color.value);
    }

    function show(body) {
      version.value = body.version || '';
      root.classList.toggle('pwa-icon-custom', !!body.custom);
      // An uploaded icon is shown on the chosen background; the default ones already have theirs
      android.src = body.custom ? body.any : body.maskable;
      iphone.src = body.custom ? body.any : body.apple;
      status.textContent = '';
      status.className = 'pwa-icon-status';
    }

    function fail(errors) {
      status.textContent = errors.join(' ');
      status.className = 'pwa-icon-status flash error';
    }

    function send(method, form) {
      status.textContent = labels.uploading;
      status.className = 'pwa-icon-status';
      return fetch(url, {
        method: method,
        body: form,
        credentials: 'same-origin',
        headers: { 'X-CSRF-Token': csrfToken(), 'X-Requested-With': 'XMLHttpRequest', Accept: 'application/json' }
      }).then(function (r) {
        return r.json().catch(function () { return { errors: [labels.failed.replace('%{reason}', 'HTTP ' + r.status)] }; })
          .then(function (body) { if (r.ok) show(body); else fail(body.errors || ['HTTP ' + r.status]); });
      }).catch(function () { fail([labels.failed.replace('%{reason}', 'network')]); });
    }

    file.addEventListener('change', function () {
      if (!file.files.length) return;
      var form = new FormData();
      form.append('icon', file.files[0]);
      send('POST', form).then(function () { file.value = ''; });
    });
    remove.addEventListener('click', function () {
      if (window.confirm(labels.confirmRemove)) send('DELETE', null);
    });
    color.addEventListener('input', paint);
    paint();
  });
})();
