#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module RedminePwa
  class Hooks < Redmine::Hook::ViewListener
    # Every page: the manifest (makes Redmine installable), phone app tags, and the script that registers the
    # service worker and adds the back button and "Install app" link
    def view_layouts_base_html_head(context = {})
      config = {
        serviceWorker: pwa_service_worker_path,
        loggedIn: User.current.logged?,
        labels: {
          back: l(:button_pwa_back),
          install: l(:label_pwa_install),
          iosTitle: l(:label_pwa_ios_title),
          iosSteps: l(:text_pwa_ios_steps),
          ok: l(:button_pwa_ok)
        }
      }
      safe_join([
        tag.link(rel: 'manifest', href: pwa_manifest_path),
        tag.meta(name: 'theme-color', content: RedminePwa::THEME_COLOR),
        tag.meta(name: 'mobile-web-app-capable', content: 'yes'),
        tag.meta(name: 'apple-mobile-web-app-capable', content: 'yes'),
        tag.meta(name: 'apple-mobile-web-app-title', content: RedminePwa.short_name),
        tag.meta(name: 'apple-mobile-web-app-status-bar-style', content: 'default'),
        tag.link(rel: 'apple-touch-icon', href: image_path('plugin_assets/redmine_pwa/apple-touch-icon.png')),
        javascript_tag("window.RedminePwa = #{config.to_json};"),
        stylesheet_link_tag('pwa', plugin: :redmine_pwa),
        javascript_include_tag('pwa', plugin: :redmine_pwa)
      ])
    end

    # The issue page: Take photo and Add files, for people who can add files to the issue
    render_on :view_issues_show_description_bottom, partial: 'redmine_pwa/issue_photos'
  end
end
