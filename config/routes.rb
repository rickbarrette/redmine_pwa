#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

RedmineApp::Application.routes.draw do
  # At the site root, so the service worker can look after every page
  get 'manifest.webmanifest', to: 'pwa#manifest', as: :pwa_manifest, format: false
  get 'service-worker.js', to: 'pwa#service_worker', as: :pwa_service_worker, format: false
  get 'pwa/offline', to: 'pwa#offline', as: :pwa_offline

  # The app icon uploaded in the plugin's settings, in each size phones need
  get 'pwa/icons/:variant.png', to: 'pwa_icons#show', as: :pwa_icon, format: false,
                                constraints: { variant: /any-192|any-512|maskable-512|apple-180/ }
  post 'pwa/icon', to: 'pwa_icons#create', as: :pwa_icon_upload
  delete 'pwa/icon', to: 'pwa_icons#destroy'

  # Files shared from another app land here (the service worker catches the POST and keeps the files)
  get 'pwa/share', to: 'pwa_share#show', as: :pwa_share
  post 'pwa/share', to: 'pwa_share#receive'
  get 'pwa/share/issues', to: 'pwa_share#issues', as: :pwa_share_issues

  # Each file uploads on its own, then all of them are added to the issue in one history entry with the note
  post 'issues/:issue_id/pwa/uploads', to: 'pwa_uploads#upload', as: :pwa_issue_upload
  post 'issues/:issue_id/pwa/attach', to: 'pwa_uploads#attach', as: :pwa_issue_attach
end
