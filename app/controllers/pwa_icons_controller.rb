#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# The uploaded app icon: each size for phones and browsers (public, like the manifest), and uploading or removing
# it from the plugin's settings (administrators).
class PwaIconsController < ApplicationController
  skip_before_action :check_if_login_required, :check_password_change, :check_twofa_activation, raise: false,
                                                                                                 only: :show
  before_action :require_admin, except: :show

  def show
    return render_404 unless RedminePwa::Icon.custom?

    # The URL carries the icon's version, so it never changes: keep it for a year
    if params[:v] == RedminePwa::Icon.cache_key
      expires_in 1.year, public: true
    else
      expires_in 1.hour, public: true
    end
    send_file RedminePwa::Icon.file(params[:variant]), type: 'image/png', disposition: 'inline'
  rescue RedminePwa::Icon::Invalid
    render_404
  end

  def create
    upload = params[:icon]
    return render_errors(l(:error_pwa_icon_not_image)) unless upload.respond_to?(:path)

    version = RedminePwa::Icon.save(upload)
    RedminePwa.update_settings('icon_version' => version)
    render json: previews
  rescue RedminePwa::Icon::Invalid => e
    render_errors(e.message)
  end

  def destroy
    RedminePwa::Icon.remove
    RedminePwa.update_settings('icon_version' => '')
    render json: previews
  end

  private

  def previews
    {
      version: RedminePwa.settings['icon_version'],
      custom: RedminePwa::Icon.custom?,
      any: RedminePwa::Icon.url(helpers, 'any-192'),
      maskable: RedminePwa::Icon.url(helpers, 'maskable-512'),
      apple: RedminePwa::Icon.url(helpers, 'apple-180')
    }
  end

  def render_errors(message)
    render json: { errors: [message] }, status: :unprocessable_content
  end
end
