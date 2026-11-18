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

# Adding photos, files and notes to an issue, and the "Add to an issue" page for things shared from other apps
class PwaShareTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :issues, :trackers,
           :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :workflows, :journals,
           :journal_details, :attachments

  def setup
    set_tmp_attachments_directory
  end

  def test_share_page_needs_login
    get '/pwa/share'
    assert_redirected_to %r{/login}
  end

  def test_share_page_lists_issues_to_pick
    log_user('jsmith', 'jsmith')
    get '/pwa/share', params: { shared: 1 }
    assert_response :success
    assert_select '#pwa-share[data-pwa-uploader]'
    assert_select '.pwa-search'
    assert_select '.pwa-issue-list input[name=pwa_issue]'
  end

  def test_a_share_the_service_worker_missed_asks_to_try_again
    log_user('jsmith', 'jsmith')
    post '/pwa/share', params: { title: 'x' }
    assert_redirected_to '/pwa/share?missed=1'
    follow_redirect!
    assert_select '.flash.warning'
  end

  def test_search_by_number
    log_user('jsmith', 'jsmith')
    get '/pwa/share/issues', params: { q: '#1' }
    assert_response :success
    assert_equal [1], JSON.parse(response.body).pluck('id')
  end

  def test_search_by_subject
    log_user('jsmith', 'jsmith')
    get '/pwa/share/issues', params: { q: 'print recipes' }
    results = JSON.parse(response.body)
    assert_includes results.pluck('id'), 1
    assert_equal 'Cannot print recipes', results.find { |r| r['id'] == 1 }['subject']
  end

  def test_search_hides_issues_the_user_cannot_see
    log_user('dlopper', 'foo')
    get '/pwa/share/issues', params: { q: '#6' } # in a private project dlopper isn't in
    assert_equal [], JSON.parse(response.body)
  end

  def test_upload_then_attach_adds_one_history_entry
    log_user('jsmith', 'jsmith')
    tokens = [%w[testfile.txt text/plain], %w[hello.pdf application/pdf]].map do |name, type|
      post '/issues/1/pwa/uploads', params: { file: uploaded_test_file(name, type) }
      assert_response :success
      JSON.parse(response.body)['token']
    end

    assert_difference -> { Journal.count } => 1, -> { Issue.find(1).attachments.count } => 2 do
      post '/issues/1/pwa/attach', params: { tokens: tokens, notes: 'Photos at intake' }
    end
    assert_response :success
    assert_equal '/issues/1', JSON.parse(response.body)['url']
    journal = Issue.find(1).journals.last
    assert_equal 'Photos at intake', journal.notes
    assert_equal 2, journal.details.count { |d| d.property == 'attachment' }
  end

  def test_a_note_alone
    log_user('jsmith', 'jsmith')
    assert_difference -> { Journal.count } => 1 do
      post '/issues/1/pwa/attach', params: { notes: 'https://example.com/part' }
    end
    assert_response :success
  end

  def test_nothing_to_add
    log_user('jsmith', 'jsmith')
    post '/issues/1/pwa/attach', params: { notes: '  ' }
    assert_response :unprocessable_content
    assert JSON.parse(response.body)['errors'].any?
  end

  def test_files_uploaded_by_someone_else_are_refused
    log_user('dlopper', 'foo')
    post '/issues/1/pwa/uploads', params: { file: uploaded_test_file('testfile.txt', 'text/plain') }
    token = JSON.parse(response.body)['token']

    reset!
    log_user('jsmith', 'jsmith')
    assert_no_difference -> { Journal.count } do
      post '/issues/1/pwa/attach', params: { tokens: [token] }
    end
    assert_response :unprocessable_content
  end

  def test_too_big_a_file_is_refused
    log_user('jsmith', 'jsmith')
    with_settings attachment_max_size: '0' do
      post '/issues/1/pwa/uploads', params: { file: uploaded_test_file('testfile.txt', 'text/plain') }
    end
    assert_response :unprocessable_content
    assert_match(/testfile\.txt/, JSON.parse(response.body)['errors'].first)
  end

  def test_needs_permission_to_add_files
    Role.find(1).remove_permission!(:edit_issues, :add_issue_notes)
    log_user('jsmith', 'jsmith')
    post '/issues/1/pwa/uploads', params: { file: uploaded_test_file('testfile.txt', 'text/plain') }
    assert_response :forbidden
  end

  def test_unseen_issue
    log_user('jsmith', 'jsmith')
    post '/issues/999/pwa/attach', params: { notes: 'x' }
    assert_response :not_found
  end
end
