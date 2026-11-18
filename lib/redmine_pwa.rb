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
  DEFAULTS = {
    # The name under the icon on the home screen; blank uses Redmine's application title
    'short_name' => '',
    # Photos are shrunk on the phone so their longest side is at most this many pixels...
    'photo_max_edge' => '2048',
    # ...and saved as JPEG at this quality (percent)
    'photo_quality' => '82',
    # The uploaded app icon's version (blank: the plugin's own icon), and the colour around it where phones crop
    # icons or don't allow transparency
    'icon_version' => '',
    'icon_background' => '#ffffff'
  }.freeze

  # The header colour on phones, used until the page's script reads the real one (themes and dark mode change it)
  THEME_COLOR = '#628db6'.freeze

  def self.setup
    RedminePwa::Hooks
  end

  def self.settings
    DEFAULTS.merge((Setting.plugin_redmine_pwa || {}).to_h.compact_blank)
  end

  # Changes some settings, keeping the rest
  def self.update_settings(values)
    Setting.plugin_redmine_pwa = (Setting.plugin_redmine_pwa || {}).to_h.merge(values)
  end

  def self.version
    Redmine::Plugin.find(:redmine_pwa).version
  end

  def self.app_name
    Setting.app_title.presence || 'Redmine'
  end

  def self.short_name
    settings['short_name'].presence || app_name.truncate(12, omission: '')
  end

  def self.photo_max_edge
    settings['photo_max_edge'].to_i.clamp(640, 8192)
  end

  def self.photo_quality
    settings['photo_quality'].to_i.clamp(40, 100)
  end

  # The data attributes for an uploader (pwa_upload.js), given a view to build URLs and labels with
  def self.uploader_data(view, issue_id = nil)
    {
      pwa_uploader: '',
      issue_id: issue_id,
      upload_url: view.pwa_issue_upload_path(issue_id: ':issue_id').sub('%3Aissue_id', ':issue_id'),
      attach_url: view.pwa_issue_attach_path(issue_id: ':issue_id').sub('%3Aissue_id', ':issue_id'),
      max_edge: photo_max_edge,
      quality: photo_quality,
      max_size: Setting.attachment_max_size.to_i.kilobytes,
      labels: {
        attach: view.l(:button_pwa_attach, id: '%{id}'),
        remove: view.l(:label_pwa_remove),
        shrinking: view.l(:label_pwa_shrinking),
        uploading: view.l(:label_pwa_uploading, done: '%{done}', total: '%{total}'),
        saving: view.l(:label_pwa_saving),
        tooBig: view.l(:text_pwa_too_big, name: '%{name}', max: '%{max}'),
        failed: view.l(:error_pwa_upload_failed, reason: '%{reason}')
      }.to_json
    }
  end
end
