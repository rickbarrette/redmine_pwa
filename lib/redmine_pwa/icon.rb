#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'open3'

module RedminePwa
  # The app icon: the plugin's own, or one uploaded in the plugin's settings. An uploaded icon is kept as a PNG in
  # Redmine's files folder (which survives upgrades), and each size phones need is made from it with ImageMagick
  # the first time it's asked for.
  module Icon
    # name => [size, kind]
    #   any:      the whole picture, transparent around it if it isn't square
    #   maskable: Android crops these to a circle or squircle, so the picture sits inside the middle 80% on the
    #             background colour
    #   apple:    iPhones round the corners themselves and don't allow transparency: the picture on the background
    VARIANTS = {
      'any-192' => [192, :any],
      'any-512' => [512, :any],
      'maskable-512' => [512, :maskable],
      'apple-180' => [180, :apple]
    }.freeze

    # The plugin's own icons, used until one is uploaded
    BUNDLED = {
      'any-192' => 'icon-192.png',
      'any-512' => 'icon-512.png',
      'maskable-512' => 'icon-maskable-512.png',
      'apple-180' => 'apple-touch-icon.png'
    }.freeze

    MIN_SIZE = 192
    MAX_BYTES = 10.megabytes
    DEFAULT_BACKGROUND = '#ffffff'.freeze

    class Invalid < StandardError; end

    def self.dir
      File.join(Attachment.storage_path, 'redmine_pwa')
    end

    def self.original
      File.join(dir, 'icon.png')
    end

    def self.custom?
      RedminePwa.settings['icon_version'].present? && File.file?(original)
    end

    def self.background
      color = RedminePwa.settings['icon_background'].to_s
      color.match?(/\A#\h{6}\z/) ? color.downcase : DEFAULT_BACKGROUND
    end

    # Changes whenever the icon or its background does, so phones and browsers fetch the new one
    def self.cache_key
      Digest::SHA256.hexdigest("#{RedminePwa.settings['icon_version']}#{background}")[0, 12]
    end

    # Where a page or the manifest finds this size of the icon
    def self.url(view, variant)
      if custom?
        view.pwa_icon_path(variant: variant, v: cache_key)
      else
        view.image_path("plugin_assets/redmine_pwa/#{BUNDLED.fetch(variant)}")
      end
    end

    # The file for one size of the uploaded icon, made if it isn't there yet
    def self.file(variant)
      size, kind = VARIANTS.fetch(variant)
      path = File.join(dir, "#{variant}-#{cache_key}.png")
      return path if File.file?(path)

      args =
        case kind
        when :any
          ['-background', 'none', '-resize', "#{size}x#{size}", '-gravity', 'center', '-extent', "#{size}x#{size}"]
        when :maskable
          inner = (size * 0.8).round
          ['-background', background, '-resize', "#{inner}x#{inner}", '-gravity', 'center', '-extent', "#{size}x#{size}",
           '-flatten']
        when :apple
          ['-background', background, '-resize', "#{size}x#{size}", '-gravity', 'center', '-extent', "#{size}x#{size}",
           '-flatten']
        end
      tmp = "#{path}.#{SecureRandom.hex(4)}.tmp"
      convert!(original, *args, "png:#{tmp}")
      File.rename(tmp, path)
      path
    ensure
      FileUtils.rm_f(tmp) if tmp
    end

    # Keeps an uploaded picture as the icon. Returns its version (saved in the plugin's settings).
    def self.save(upload)
      raise Invalid, I18n.t(:error_pwa_icon_no_convert) unless Redmine::Thumbnail.convert_available?
      raise Invalid, I18n.t(:error_pwa_icon_too_big) if upload.size > MAX_BYTES

      FileUtils.mkdir_p(dir)
      tmp = File.join(dir, "upload_#{SecureRandom.hex(6)}.tmp")
      begin
        # Only the first frame, turned the right way up, as a PNG: anything that isn't a picture fails here
        convert!(upload.path + '[0]', '-auto-orient', '-strip', "png:#{tmp}")
        width, height = identify(tmp)
      rescue Invalid
        raise Invalid, I18n.t(:error_pwa_icon_not_image)
      end
      raise Invalid, I18n.t(:error_pwa_icon_too_small, size: MIN_SIZE) if [width, height].min < MIN_SIZE

      version = Digest::SHA256.file(tmp).hexdigest[0, 12]
      clear
      File.rename(tmp, original)
      version
    ensure
      FileUtils.rm_f(tmp) if tmp
    end

    # Back to the plugin's own icon
    def self.remove
      clear
      FileUtils.rm_f(original)
    end

    # The sizes made from an earlier icon or background
    def self.clear
      Dir.glob(File.join(dir, '*-*.png')).each { |f| FileUtils.rm_f(f) }
    end

    def self.identify(path)
      out = convert!(path, '-format', '%w %h', 'info:')
      out.split.map(&:to_i)
    end

    def self.convert!(*args)
      out, status = Open3.capture2e(Redmine::Thumbnail::CONVERT_BIN, *args)
      raise Invalid, out unless status.success?

      out
    end
  end
end
