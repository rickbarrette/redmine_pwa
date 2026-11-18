// The "Add to an issue" page: picks up what was shared from another app (kept by the service worker), lets the
// user find the issue, and hands everything to the uploader (pwa_upload.js).
(function () {
  'use strict';

  var SHARED_CACHE = 'redmine-pwa-shared';

  function loadShared(uploader) {
    if (!('caches' in window)) return Promise.resolve();
    return caches.open(SHARED_CACHE).then(function (cache) {
      return cache.keys().then(function (requests) {
        requests.sort(function (a, b) { return a.url.localeCompare(b.url, undefined, { numeric: true }); });
        return Promise.all(requests.map(function (request) {
          return cache.match(request).then(function (response) {
            if (/\/text$/.test(request.url)) return response.text().then(function (text) { return { text: text }; });
            var name = decodeURIComponent(response.headers.get('X-Filename') || 'file');
            var type = response.headers.get('Content-Type') || '';
            return response.blob().then(function (blob) { return { file: new File([blob], name, { type: type }) }; });
          });
        }));
      });
    }).then(function (items) {
      var files = items.filter(function (i) { return i.file; }).map(function (i) { return i.file; });
      var text = items.filter(function (i) { return i.text; }).map(function (i) { return i.text; }).join('\n');
      if (files.length) uploader.add(files);
      if (text && uploader.note && !uploader.note.value) uploader.note.value = text;
      uploader.render();
    }).catch(function () {});
  }

  function issueItem(issue) {
    var li = document.createElement('li');
    var label = document.createElement('label');
    var radio = document.createElement('input');
    radio.type = 'radio';
    radio.name = 'pwa_issue';
    radio.value = issue.id;
    var title = document.createElement('span');
    title.className = 'pwa-issue-title';
    title.textContent = '#' + issue.id + ' ' + issue.subject;
    var meta = document.createElement('span');
    meta.className = 'pwa-issue-meta';
    meta.textContent = [issue.project, issue.status, issue.customer].filter(Boolean).join(' · ');
    label.appendChild(radio);
    label.appendChild(title);
    label.appendChild(meta);
    li.appendChild(label);
    return li;
  }

  document.addEventListener('DOMContentLoaded', function () {
    var root = document.getElementById('pwa-share');
    if (!root || !window.RedminePwaUploader) return;
    var uploader = root.redminePwaUploader || (root.redminePwaUploader = new window.RedminePwaUploader(root));
    var picker = root.querySelector('.pwa-picker');
    var search = picker.querySelector('.pwa-search');
    var results = picker.querySelector('.pwa-results');
    var resultList = results.querySelector('.pwa-issue-list');

    loadShared(uploader);

    picker.addEventListener('change', function (e) {
      if (e.target.name !== 'pwa_issue') return;
      uploader.setIssue(e.target.value);
    });

    var timer = null;
    var latest = 0;
    search.addEventListener('input', function () {
      clearTimeout(timer);
      var q = search.value.trim();
      if (q.length < 1) { results.hidden = true; return; }
      timer = setTimeout(function () {
        var ticket = ++latest;
        fetch(picker.getAttribute('data-search-url') + '?q=' + encodeURIComponent(q), {
          credentials: 'same-origin', headers: { Accept: 'application/json' }
        }).then(function (r) { return r.json(); }).then(function (issues) {
          if (ticket !== latest) return;
          resultList.innerHTML = '';
          if (!issues.length) {
            var empty = document.createElement('li');
            empty.className = 'pwa-no-results';
            empty.textContent = picker.getAttribute('data-no-results');
            resultList.appendChild(empty);
          }
          issues.forEach(function (issue) {
            var li = issueItem(issue);
            if (uploader.issueId === String(issue.id)) li.querySelector('input').checked = true;
            resultList.appendChild(li);
          });
          results.hidden = false;
        }).catch(function () {});
      }, 250);
    });

    // Once added, forget what was shared, then go to the issue
    root.addEventListener('pwa:attached', function (e) {
      e.preventDefault();
      var go = function () { window.location.href = e.detail.url; };
      if ('caches' in window) caches.delete(SHARED_CACHE).then(go, go); else go();
    });
  });
})();
