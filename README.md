# Redmine PWA

Install Redmine on your phone like an app, add photos and files to issues from the phone, and share them to Redmine from other apps.

## Features

* **Install on your phone.** Android: **Install app** in the menu (or Chrome's own install prompt). iPhone: **Install app** shows how (Share › Add to Home Screen). Redmine then opens full screen from its own icon.
* **Back button** in the header when opened as an installed app, since installed apps have no browser buttons.
* **Status bar matches the header**, including with redmine_dark_mode.
* **Shortcuts** when you long-press the icon: New issue, My issues, Calendar, Log time.
* **Take photo / Add files on every issue** (for people who can add notes or edit the issue). Pick several, remove any, add an optional note, then add them all in one history entry. Works on iPhone and Android.
* **Photos are shrunk on the phone before they upload**: by default the longest side is at most 2048 px, saved as JPEG at 82% (a 12 MP photo of 4–6 MB becomes about 0.4 MB). Shrinking also drops the photo's location data. Other files upload as they are. Redmine's attachment size limit is checked before uploading.
* **Share to Redmine from other apps** (Android only; iPhones don't let web apps join the share menu, so use Take photo / Add files there). Photos, files, links and text shared to Redmine open **Add to an issue**: pick from issues assigned to you or ones you've recently updated, or search by issue number, subject or (with redmine_qbo) customer name.
* **Offline page** when Redmine can't be reached.

Redmine's pages are never cached on the phone, so nothing one person saw is kept for the next (shared phones, redmine_impersonate). Things shared but not yet added to an issue are cleared on sign out.

## Requirements

* Redmine 7.0+
* HTTPS (browsers only install apps and run service workers over HTTPS)

## Installation

1. Clone into `plugins/redmine_pwa`.
2. Restart Redmine. There are no migrations.
3. Optional: Administration › Plugins › Redmine PWA plugin › Configure, to set the name under the icon and the photo size and quality.

To stay signed in on the phone, turn on **Administration › Settings › Authentication › Autologin** so people can tick "Stay logged in".

## How it works

* `/manifest.webmanifest` and `/service-worker.js` are served at the site root (so the worker covers every page) and are public, even when Redmine requires login. Neither holds anything about the user.
* A share from another app is a POST to `/pwa/share`. The service worker catches it, keeps the files in the browser's cache, and opens `/pwa/share`, which hands them to the uploader.
* Files upload one at a time to `/issues/:id/pwa/uploads` (progress shows, and no request gets too big), then `/issues/:id/pwa/attach` adds them to the issue with the note. Redmine's own `/uploads.json` only accepts API keys, not the signed-in session.

## Tests

```
bundle exec rake redmine:plugins:test NAME=redmine_pwa
```
