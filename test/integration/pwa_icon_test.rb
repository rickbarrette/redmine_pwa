#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path('../test_helper', __dir__)

# Uploading an app icon in the plugin's settings, and the sizes made from it
class PwaIconTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :trackers, :enabled_modules

  def setup
    set_tmp_attachments_directory
    RedminePwa::Icon.remove
    Setting.plugin_redmine_pwa = RedminePwa::DEFAULTS.dup
  end

  def teardown
    RedminePwa::Icon.remove
    Setting.plugin_redmine_pwa = RedminePwa::DEFAULTS.dup
  end

  def test_only_administrators_upload
    log_user('jsmith', 'jsmith')
    post '/pwa/icon', params: { icon: picture(600, 600) }
    assert_response :forbidden
    assert_not RedminePwa::Icon.custom?
  end

  def test_a_picture_becomes_the_icon
    log_user('admin', 'admin')
    post '/pwa/icon', params: { icon: picture(600, 400) }
    assert_response :success
    body = JSON.parse(response.body)
    assert body['custom']
    assert_equal RedminePwa.settings['icon_version'], body['version']
    assert_match %r{\A/pwa/icons/any-192\.png\?v=\h{12}\z}, body['any']

    reset!
    get '/manifest.webmanifest'
    icons = JSON.parse(response.body)['icons']
    assert(icons.all? { |i| i['src'].start_with?('/pwa/icons/') })

    get '/'
    assert_select 'link[rel=apple-touch-icon][href^="/pwa/icons/apple-180.png"]'
  end

  def test_each_size
    upload_icon(600, 400)
    { 'any-192' => [192, 192], 'any-512' => [512, 512], 'maskable-512' => [512, 512], 'apple-180' => [180, 180] }
      .each do |variant, size|
      get "/pwa/icons/#{variant}.png", params: { v: RedminePwa::Icon.cache_key }
      assert_response :success
      assert_equal 'image/png', response.media_type
      assert_includes response.headers['Cache-Control'], "max-age=#{1.year.to_i}"
      assert_equal size, dimensions(response.body), variant
    end
  end

  def test_background_fills_where_phones_crop
    upload_icon(600, 400)
    # A wide picture leaves room above it: see-through on the plain icon, the background colour on the others
    assert_equal 0, corner(RedminePwa::Icon.file('any-512'))[:alpha]
    assert_equal 'FFFFFF', corner(RedminePwa::Icon.file('maskable-512'))[:rgb]

    RedminePwa.update_settings('icon_background' => '#112233')
    assert_equal '112233', corner(RedminePwa::Icon.file('apple-180'))[:rgb]
  end

  def test_not_a_picture
    log_user('admin', 'admin')
    post '/pwa/icon', params: { icon: uploaded_test_file('testfile.txt', 'text/plain') }
    assert_response :unprocessable_content
    assert_match(/isn't a picture/, JSON.parse(response.body)['errors'].first)
    assert_not RedminePwa::Icon.custom?
  end

  def test_too_small
    log_user('admin', 'admin')
    post '/pwa/icon', params: { icon: picture(100, 100) }
    assert_response :unprocessable_content
    assert_match(/at least 192/, JSON.parse(response.body)['errors'].first)
  end

  def test_back_to_the_default_icon
    upload_icon(600, 600)
    delete '/pwa/icon'
    assert_response :success
    assert_not JSON.parse(response.body)['custom']
    assert_equal '', RedminePwa.settings['icon_version'].to_s

    get '/pwa/icons/any-192.png'
    assert_response :not_found
    get '/manifest.webmanifest'
    assert(JSON.parse(response.body)['icons'].all? { |i| i['src'].include?('plugin_assets/redmine_pwa/') })
  end

  def test_settings_page_keeps_the_icon_version
    upload_icon(600, 600)
    get '/settings/plugin/redmine_pwa'
    assert_response :success
    assert_select '.pwa-icon-setting.pwa-icon-custom'
    assert_select "input[type=hidden][name='settings[icon_version]'][value=?]", RedminePwa.settings['icon_version']
  end

  private

  def upload_icon(width, height)
    log_user('admin', 'admin')
    post '/pwa/icon', params: { icon: picture(width, height) }
    assert_response :success
  end

  # A red picture of this size
  def picture(width, height)
    path = Rails.root.join('tmp', "pwa-icon-#{width}x#{height}.png").to_s
    RedminePwa::Icon.convert!('-size', "#{width}x#{height}", 'xc:#ff0000', "png:#{path}")
    Rack::Test::UploadedFile.new(path, 'image/png')
  end

  def dimensions(png)
    Tempfile.create(['icon', '.png'], binmode: true) do |f|
      f.write(png)
      f.flush
      RedminePwa::Icon.identify(f.path)
    end
  end

  def corner(path)
    rgb, alpha = RedminePwa::Icon.convert!(path, '-format', '%[hex:p{0,0}] %[fx:int(255*p{0,0}.a)]', 'info:').split
    { rgb: rgb.first(6).upcase, alpha: alpha.to_i }
  end
end
