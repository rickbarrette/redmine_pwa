// Photos and files waiting to be added to an issue, used by the issue page (Take photo / Add files) and the
// "Add to an issue" page (things shared from other apps). Photos are shrunk on the phone first: a phone photo is
// 3-12 MB, which is slow on shop wifi and can pass Redmine's attachment size limit. Shrinking also drops the photo's
// location, since only the pixels are kept. Each file uploads on its own, then all of them are added to the issue,
// with the note, as one entry in the issue's history.
(function () {
  'use strict';

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }

  function humanSize(bytes) {
    if (bytes >= 1048576) return (bytes / 1048576).toFixed(1).replace(/\.0$/, '') + ' MB';
    return Math.max(1, Math.round(bytes / 1024)) + ' KB';
  }

  function loadImage(file) {
    return new Promise(function (resolve, reject) {
      var url = URL.createObjectURL(file);
      var img = new Image();
      img.onload = function () { resolve({ img: img, url: url }); };
      img.onerror = function () { URL.revokeObjectURL(url); reject(new Error('decode')); };
      img.src = url;
    });
  }

  // A smaller JPEG copy of a photo, or the file itself when it's not a photo, is already small, or can't be read
  // (e.g. HEIC on Android). Browsers turn the photo the right way up (EXIF orientation) when drawing it.
  function shrink(file, maxEdge, quality) {
    var photo = /^image\/(jpeg|png|webp|heic|heif)$/i.test(file.type);
    if (!photo) return Promise.resolve(file);
    // Screenshots stay sharp PNGs unless they're big
    if (/png/i.test(file.type) && file.size < 1572864) return Promise.resolve(file);
    return loadImage(file).then(function (loaded) {
      var img = loaded.img;
      var scale = Math.min(1, maxEdge / Math.max(img.naturalWidth, img.naturalHeight));
      if (scale === 1 && /jpeg/i.test(file.type) && file.size < 1048576) {
        URL.revokeObjectURL(loaded.url);
        return file;
      }
      var canvas = document.createElement('canvas');
      canvas.width = Math.round(img.naturalWidth * scale);
      canvas.height = Math.round(img.naturalHeight * scale);
      var ctx = canvas.getContext('2d');
      ctx.fillStyle = '#ffffff'; // transparent PNGs get a white backing, not black
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(loaded.url);
      return new Promise(function (resolve) {
        canvas.toBlob(function (blob) {
          if (!blob || blob.size >= file.size) return resolve(file);
          var name = (file.name || 'photo').replace(/\.[^.]+$/, '') + '.jpg';
          resolve(new File([blob], name, { type: 'image/jpeg', lastModified: file.lastModified || Date.now() }));
        }, 'image/jpeg', quality / 100);
      });
    }).catch(function () { return file; });
  }

  // POSTs a form with progress (fetch can't report upload progress)
  function post(url, form, onProgress) {
    return new Promise(function (resolve, reject) {
      var xhr = new XMLHttpRequest();
      xhr.open('POST', url);
      xhr.setRequestHeader('X-CSRF-Token', csrfToken());
      xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
      xhr.setRequestHeader('Accept', 'application/json');
      if (onProgress && xhr.upload) {
        xhr.upload.onprogress = function (e) { if (e.lengthComputable) onProgress(e.loaded / e.total); };
      }
      xhr.onload = function () {
        var body = null;
        try { body = JSON.parse(xhr.responseText); } catch (e) {}
        if (xhr.status >= 200 && xhr.status < 300 && body) return resolve(body);
        reject((body && body.errors) || [xhr.status ? 'HTTP ' + xhr.status : 'network']);
      };
      xhr.onerror = function () { reject(['network']); };
      xhr.send(form);
    });
  }

  function Uploader(root) {
    this.root = root;
    this.files = [];
    this.issueId = root.getAttribute('data-issue-id') || null;
    this.uploadUrl = root.getAttribute('data-upload-url');   // contains :issue_id
    this.attachUrl = root.getAttribute('data-attach-url');   // contains :issue_id
    this.maxEdge = parseInt(root.getAttribute('data-max-edge'), 10) || 2048;
    this.quality = parseInt(root.getAttribute('data-quality'), 10) || 82;
    this.maxSize = parseInt(root.getAttribute('data-max-size'), 10) || 0;
    this.labels = JSON.parse(root.getAttribute('data-labels') || '{}');
    this.tray = root.querySelector('[data-pwa-tray]');
    this.note = root.querySelector('[data-pwa-note]');
    this.status = root.querySelector('[data-pwa-status]');
    this.submitButton = root.querySelector('[data-pwa-submit]');
    this.busy = false;

    var self = this;
    root.querySelectorAll('input[type=file][data-pwa-input]').forEach(function (input) {
      input.addEventListener('change', function () {
        self.add(Array.prototype.slice.call(input.files));
        input.value = '';
      });
    });
    root.querySelectorAll('[data-pwa-pick]').forEach(function (button) {
      button.addEventListener('click', function () {
        var input = root.querySelector('input[data-pwa-input="' + button.getAttribute('data-pwa-pick') + '"]');
        if (input) input.click();
      });
    });
    if (this.note) this.note.addEventListener('input', function () { self.render(); });
    if (this.submitButton) this.submitButton.addEventListener('click', function () { self.submit(); });
    this.render();
  }

  Uploader.prototype.add = function (files) {
    var self = this;
    files.forEach(function (file) {
      var item = { file: file, url: /^image\//.test(file.type) ? URL.createObjectURL(file) : null };
      self.files.push(item);
    });
    this.showMessage('');
    this.render();
  };

  Uploader.prototype.remove = function (item) {
    if (item.url) URL.revokeObjectURL(item.url);
    this.files = this.files.filter(function (f) { return f !== item; });
    this.render();
  };

  Uploader.prototype.setIssue = function (id) {
    this.issueId = id ? String(id) : null;
    this.render();
  };

  Uploader.prototype.hasContent = function () {
    return this.files.length > 0 || (this.note && this.note.value.trim() !== '');
  };

  Uploader.prototype.render = function () {
    var self = this;
    this.root.classList.toggle('pwa-has-files', this.files.length > 0);
    this.root.classList.toggle('pwa-has-content', this.hasContent());
    if (this.tray) {
      this.tray.innerHTML = '';
      this.files.forEach(function (item) {
        var li = document.createElement('li');
        li.className = 'pwa-tray-item';
        if (item.url) {
          var img = document.createElement('img');
          img.src = item.url;
          img.alt = item.file.name || '';
          li.appendChild(img);
        } else {
          var name = document.createElement('span');
          name.className = 'pwa-tray-name icon icon-attachment';
          name.textContent = item.file.name || 'file';
          li.appendChild(name);
        }
        var remove = document.createElement('button');
        remove.type = 'button';
        remove.className = 'pwa-tray-remove';
        remove.setAttribute('aria-label', self.labels.remove || 'Remove');
        remove.textContent = '×';
        remove.disabled = self.busy;
        remove.addEventListener('click', function () { self.remove(item); });
        li.appendChild(remove);
        self.tray.appendChild(li);
      });
    }
    if (this.submitButton) {
      this.submitButton.disabled = this.busy || !this.issueId || !this.hasContent();
      if (this.issueId && this.labels.attach) this.submitButton.textContent = this.labels.attach.replace('%{id}', this.issueId);
    }
  };

  Uploader.prototype.showMessage = function (text, error) {
    if (!this.status) return;
    this.status.textContent = '';
    this.status.className = text ? (error ? 'flash error' : 'pwa-progress') : '';
    if (Array.isArray(text)) {
      var ul = document.createElement('ul');
      text.forEach(function (t) { var li = document.createElement('li'); li.textContent = t; ul.appendChild(li); });
      this.status.appendChild(ul);
    } else {
      this.status.textContent = text || '';
    }
  };

  Uploader.prototype.url = function (template) {
    return template.replace(':issue_id', encodeURIComponent(this.issueId));
  };

  Uploader.prototype.submit = function () {
    var self = this;
    if (this.busy || !this.issueId || !this.hasContent()) return Promise.resolve();
    this.busy = true;
    this.render();
    var labels = this.labels;
    this.showMessage(labels.shrinking);

    return Promise.all(this.files.map(function (item) { return shrink(item.file, self.maxEdge, self.quality); }))
      .then(function (ready) {
        var tooBig = self.maxSize ? ready.filter(function (f) { return f.size > self.maxSize; }) : [];
        if (tooBig.length) {
          throw tooBig.map(function (f) {
            return labels.tooBig.replace('%{name}', f.name).replace('%{max}', humanSize(self.maxSize));
          });
        }
        var tokens = [];
        var chain = Promise.resolve();
        ready.forEach(function (file, i) {
          chain = chain.then(function () {
            var form = new FormData();
            form.append('file', file, file.name);
            return post(self.url(self.uploadUrl), form, function (fraction) {
              var pct = Math.round(((i + fraction) / ready.length) * 100);
              self.showMessage(labels.uploading.replace('%{done}', i + 1).replace('%{total}', ready.length) + ' ' + pct + '%');
            }).then(function (body) { tokens.push(body.token); });
          });
        });
        return chain.then(function () { return tokens; });
      })
      .then(function (tokens) {
        self.showMessage(labels.saving);
        var form = new FormData();
        tokens.forEach(function (t) { form.append('tokens[]', t); });
        form.append('notes', self.note ? self.note.value : '');
        return post(self.url(self.attachUrl), form);
      })
      .then(function (body) {
        self.files.forEach(function (item) { if (item.url) URL.revokeObjectURL(item.url); });
        self.files = [];
        if (self.root.dispatchEvent(new CustomEvent('pwa:attached', { detail: body, cancelable: true }))) {
          window.location.href = body.url;
        }
      })
      .catch(function (errors) {
        if (!Array.isArray(errors)) errors = [String(errors && errors.message || errors)];
        if (errors.length === 1 && /^(network|HTTP \d+)$/.test(errors[0])) {
          errors = [labels.failed.replace('%{reason}', errors[0])];
        }
        self.busy = false;
        self.showMessage(errors, true);
        self.render();
      });
  };

  window.RedminePwaUploader = Uploader;

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-pwa-uploader]').forEach(function (root) {
      root.redminePwaUploader = new Uploader(root);
    });
  });
})();
