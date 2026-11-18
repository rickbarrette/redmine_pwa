#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Adds photos and files to an issue from the phone. Each file is uploaded on its own (#upload), so a slow connection
# shows progress and one file never makes the request too big. Then #attach adds them all to the issue, with the
# note, as one entry in the issue's history. (Redmine's own /uploads.json only accepts API keys.)
class PwaUploadsController < ApplicationController
  before_action :require_login
  before_action :find_issue

  def upload
    file = params[:file]
    return render_errors([l(:error_pwa_no_file)]) unless file.respond_to?(:original_filename)

    attachment = Attachment.new(file: file, author: User.current)
    if attachment.save
      render json: { token: attachment.token, filename: attachment.filename }
    else
      render_errors(attachment.errors.full_messages.map { |m| "#{file.original_filename}: #{m}" })
    end
  end

  def attach
    tokens = Array(params[:tokens]).compact_blank
    notes = params[:notes].to_s.strip
    return render_errors([l(:error_pwa_nothing_to_add)]) if tokens.empty? && notes.empty?
    return deny_access if notes.present? && !@issue.notes_addable?
    # Only files this user just uploaded
    unless tokens.all? { |token| Attachment.find_by_token(token)&.author_id == User.current.id }
      return render_errors([l(:error_pwa_upload_expired)])
    end

    @issue.init_journal(User.current, notes)
    @issue.save_attachments(tokens.map { |token| { 'token' => token } })
    if @issue.save
      render json: { url: issue_path(@issue) }
    else
      render_errors(@issue.errors.full_messages)
    end
  end

  private

  def find_issue
    @issue = Issue.visible.find_by(id: params[:issue_id])
    return render_404 unless @issue

    deny_access unless @issue.attachments_addable?
  end

  def render_errors(messages)
    render json: { errors: messages }, status: :unprocessable_content
  end
end
