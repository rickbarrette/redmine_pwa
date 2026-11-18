#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# The manifest, service worker and offline page. Browsers fetch the manifest without the user's cookies, and the
# app has to be installable from the login page, so these are public even when Redmine requires login. None of them
# holds anything about the user.
class PwaController < ApplicationController
  skip_before_action :check_if_login_required, :check_password_change, :check_twofa_activation, raise: false
  # Rails won't otherwise serve JavaScript to a plain GET (its guard against other sites embedding it). The service
  # worker holds nothing private, and browsers only run a service worker from its own site.
  skip_forgery_protection only: :service_worker

  def manifest
    expires_in 1.hour, public: true
    render json: manifest_data, content_type: 'application/manifest+json'
  end

  def service_worker
    # Always checked for a new version, so a plugin update reaches phones on their next visit
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Service-Worker-Allowed'] = root_path
    render template: 'pwa/service_worker', formats: [:js], content_type: 'text/javascript', layout: false
  end

  def offline
    render layout: false
  end

  private

  def manifest_data
    root = root_path
    {
      id: root,
      name: RedminePwa.app_name,
      short_name: RedminePwa.short_name,
      lang: current_language.to_s,
      start_url: root,
      scope: root,
      display: 'standalone',
      orientation: 'any',
      theme_color: RedminePwa::THEME_COLOR,
      background_color: '#ffffff',
      icons: [
        icon('any-192', '192x192', 'any'),
        icon('any-512', '512x512', 'any'),
        icon('maskable-512', '512x512', 'maskable')
      ],
      shortcuts: shortcuts,
      # Android only (iPhones can't add web apps to the share menu): files and text shared from other apps
      share_target: {
        action: pwa_share_path,
        method: 'POST',
        enctype: 'multipart/form-data',
        params: { title: 'title', text: 'text', url: 'url', files: [{ name: 'files', accept: ['*/*'] }] }
      }
    }
  end

  def icon(variant, sizes, purpose)
    { src: RedminePwa::Icon.url(helpers, variant), sizes: sizes, type: 'image/png', purpose: purpose }
  end

  # Long-press the app icon: the pages used most
  def shortcuts
    list = [
      [l(:label_issue_new), new_issue_path],
      [l(:label_pwa_my_issues), issues_path(set_filter: 1, assigned_to_id: 'me', status_id: 'o', sort: 'updated_on:desc')],
      [l(:label_calendar), url_for(controller: 'calendars', action: 'show', only_path: true)],
      [l(:button_log_time), new_time_entry_path]
    ]
    small = RedminePwa::Icon.url(helpers, 'any-192')
    list.map { |name, url| { name: name, url: url, icons: [{ src: small, sizes: '192x192' }] } }
  end
end
