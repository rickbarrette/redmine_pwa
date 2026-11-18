#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Where files and text shared from another app (Android's share menu) are added to an issue. The service worker
# catches the shared POST, keeps the files in the browser and opens #show, which offers the issues to pick from.
class PwaShareController < ApplicationController
  before_action :require_login
  # A share from another app carries no form token. It's only ever redirected (see #receive).
  skip_forgery_protection only: :receive

  LIMIT = 15

  def show
    @assigned = addable(Issue.visible.open.where(assigned_to_id: [User.current.id] + User.current.group_ids)
                                    .order(updated_on: :desc).limit(LIMIT))
    @recent = addable(recent_issues.where.not(id: @assigned.map(&:id)).order(updated_on: :desc).limit(LIMIT))
    @missed = params[:missed].present?
  end

  # Reached only when the service worker didn't catch the share (e.g. the app hasn't been opened since it was
  # installed). The files can't be kept here, so ask for the share to be tried again.
  def receive
    redirect_to pwa_share_path(missed: 1)
  end

  # The search box: an issue number, or words from the subject (or the customer's name, with redmine_qbo)
  def issues
    q = params[:q].to_s.strip
    found =
      if q =~ /\A#?(\d+)\z/
        Issue.visible.where(id: Regexp.last_match(1).to_i)
      elsif q.length >= 2
        search(q)
      else
        Issue.none
      end
    render json: addable(found.limit(20)).map { |issue| issue_json(issue) }
  end

  private

  # Issues this user created or updated in the last 30 days
  def recent_issues
    updated = Journal.where(journalized_type: 'Issue', user_id: User.current.id)
                     .where('created_on > ?', 30.days.ago).select(:journalized_id)
    Issue.visible.where(author_id: User.current.id).where('issues.created_on > ?', 30.days.ago)
         .or(Issue.visible.where(id: updated))
  end

  def search(q)
    like = "%#{Issue.sanitize_sql_like(q)}%"
    scope = Issue.visible
    condition = Issue.arel_table[:subject].matches(like)
    if Issue.reflect_on_association(:customer)
      scope = scope.left_joins(:customer)
      condition = condition.or(Customer.arel_table[:name].matches(like))
    end
    # Open issues first, then the most recently updated
    scope.where(condition).includes(:status).order(IssueStatus.arel_table[:is_closed].asc, updated_on: :desc)
         .references(:status)
  end

  def addable(scope)
    scope.includes(:project, :status, :tracker).select(&:attachments_addable?)
  end

  def issue_json(issue)
    {
      id: issue.id,
      subject: issue.subject,
      project: issue.project.name,
      status: issue.status.name,
      tracker: issue.tracker.name,
      customer: issue.respond_to?(:customer) ? issue.customer&.name : nil
    }
  end
end
