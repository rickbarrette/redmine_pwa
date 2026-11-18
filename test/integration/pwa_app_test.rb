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

# The manifest, service worker and offline page, and the tags every page gets
class PwaAppTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :issues, :trackers,
           :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :workflows

  def test_manifest_is_public_even_when_login_is_required
    with_settings login_required: '1', app_title: 'Shop Redmine' do
      get '/manifest.webmanifest'
    end
    assert_response :success
    assert_equal 'application/manifest+json', response.media_type
    manifest = JSON.parse(response.body)
    assert_equal 'Shop Redmine', manifest['name']
    assert_equal 'standalone', manifest['display']
    assert_equal '/', manifest['start_url']
    assert_equal '/pwa/share', manifest.dig('share_target', 'action')
    assert_equal 'files', manifest.dig('share_target', 'params', 'files', 0, 'name')
    assert(manifest['icons'].any? { |i| i['purpose'] == 'maskable' })
    assert(manifest['icons'].all? { |i| i['src'].include?('plugin_assets/redmine_pwa/icon') })
    assert_equal '/issues/new', manifest['shortcuts'].first['url']
  end

  def test_short_name_setting
    with_settings plugin_redmine_pwa: { 'short_name' => 'Shop' }, app_title: 'Shop Redmine' do
      get '/manifest.webmanifest'
    end
    assert_equal 'Shop', JSON.parse(response.body)['short_name']
  end

  def test_service_worker_is_public_and_never_caches_pages
    with_settings login_required: '1' do
      get '/service-worker.js'
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type
    assert_equal 'no-cache', response.headers['Cache-Control']
    assert_equal '/', response.headers['Service-Worker-Allowed']
    assert_includes response.body, 'const SHARE = "/pwa/share"'
    assert_includes response.body, 'const OFFLINE = "/pwa/offline"'
  end

  def test_offline_page_is_public
    with_settings login_required: '1' do
      get '/pwa/offline'
    end
    assert_response :success
    assert_select 'h1', "You're offline"
  end

  def test_pages_link_the_manifest_and_script
    get '/'
    assert_select 'link[rel=manifest][href="/manifest.webmanifest"]'
    assert_select 'meta[name=theme-color]'
    assert_select 'link[rel=apple-touch-icon]'
    assert_includes response.body, 'window.RedminePwa = '
  end

  def test_issue_page_offers_photos_to_people_who_can_add_files
    log_user('jsmith', 'jsmith')
    get '/issues/1'
    assert_select '.pwa-issue-uploader[data-issue-id="1"]' do
      assert_select '[data-pwa-pick=camera]'
      assert_select 'input[type=file][capture=environment]'
      assert_select 'textarea[data-pwa-note]'
    end
  end

  def test_issue_page_has_no_photos_without_permission
    Role.anonymous.remove_permission!(:add_issues, :edit_issues, :add_issue_notes)
    Role.non_member.remove_permission!(:add_issues, :edit_issues, :add_issue_notes)
    get '/issues/1'
    assert_response :success
    assert_select '.pwa-issue-uploader', 0
  end
end
