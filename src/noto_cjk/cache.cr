require "http/client"
require "uri"

module NotoCjk
  # On-disk cache of Noto Sans CJK fonts. Each variant is a single
  # ~16-20 MB OpenType file ; we don't embed it in dependent
  # binaries (way too heavy), so the user pulls only the variant(s)
  # they actually need.
  #
  # **Two ways to populate the cache** :
  #
  # 1. **From your own Crystal app, via the API** :
  #
  #    ```
  # require "noto-cjk"
  #
  # # Pull the Simplified Chinese variant (default).
  # NotoCjk::Cache.pull(variants: [:sc])
  #
  # # Pull both Simplified Chinese and Japanese.
  # NotoCjk::Cache.pull(variants: [:sc, :jp])
  #
  # # Pull all four variants (SC + TC + JP + KR, ≈ 80 MB).
  # NotoCjk::Cache.pull(variants: NotoCjk::VARIANTS)
  #
  # # Override the source — useful for an internal mirror.
  # NotoCjk::Cache.pull(variants: [:sc],
  #   source: "https://nas.aloli.local/noto-cjk")
  #
  # # Inspection
  # NotoCjk::Cache.populated?(:sc) # => true / false
  # NotoCjk::Cache.path(:sc)       # => "/Users/.../NotoSansCJKsc-Regular.otf" or nil
  # NotoCjk::Cache.installed       # => [:sc, :jp]
  #    ```
  #
  # 2. **From the command line** :
  #
  #        $ noto-cjk pull                          # default = sc
  #        $ noto-cjk pull --variant jp
  #        $ noto-cjk pull --variant sc,jp
  #        $ noto-cjk pull --variant all
  #        $ noto-cjk pull --system                 # /var/cache/...
  #        $ noto-cjk pull --source https://...     # custom mirror
  module Cache
    # Default upstream source. Switch via the `source:` keyword to
    # pull from a private mirror.
    DEFAULT_SOURCE = "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF"

    # Subdirectory + filename for each variant in the upstream
    # Noto CJK repository. These names are stable across Noto
    # releases (changing them would break every consumer).
    VARIANT_FILES = {
      sc: {dir: "SimplifiedChinese", file: "NotoSansCJKsc-Regular.otf"},
      tc: {dir: "TraditionalChinese", file: "NotoSansCJKtc-Regular.otf"},
      jp: {dir: "Japanese", file: "NotoSansCJKjp-Regular.otf"},
      kr: {dir: "Korean", file: "NotoSansCJKkr-Regular.otf"},
    }

    # Returns the directory where the cache is read from / written
    # to. Honours `CRYSTAL_NOTO_CJK_CACHE_DIR` env var if set,
    # otherwise computes the XDG/macOS-conventional path.
    def self.dir(system : Bool = false) : String
      if (override = ENV["CRYSTAL_NOTO_CJK_CACHE_DIR"]?)
        return override
      end
      if system
        "/var/cache/noto-cjk"
      elsif (xdg = ENV["XDG_CACHE_HOME"]?)
        File.join(xdg, "noto-cjk")
      else
        case Crystal::DESCRIPTION
        when /darwin/, /macos/
          File.join(Path.home.to_s, "Library", "Caches", "noto-cjk")
        else
          File.join(Path.home.to_s, ".cache", "noto-cjk")
        end
      end
    end

    # Returns the on-disk path to the OTF file for `variant`, or
    # `nil` when the variant is not in the cache.
    def self.path(variant : Symbol, system : Bool = false) : String?
      info = VARIANT_FILES[variant]?
      return nil unless info
      file_path = File.join(dir(system: system), info[:file])
      File.exists?(file_path) ? file_path : nil
    end

    # `true` when `variant` is present in the cache.
    def self.populated?(variant : Symbol, system : Bool = false) : Bool
      !path(variant, system: system).nil?
    end

    # Returns the list of variants currently installed in the cache.
    def self.installed(system : Bool = false) : Array(Symbol)
      VARIANT_FILES.keys.select { |v| populated?(v, system: system) }
    end

    # Downloads one or several Noto Sans CJK variants into the
    # cache directory. `variants` is an array of `:sc`, `:tc`,
    # `:jp`, `:kr`. Defaults to `[:sc]` (the broadest single
    # variant — covers all CJK Unified Ideographs codepoints).
    #
    # Override `source:` to fetch from a private mirror. The
    # mirror must follow the same path layout as upstream :
    # `<source>/<variant_dir>/<variant_file>`.
    #
    # Returns the number of variants successfully downloaded
    # (skips ones that are already in the cache, idempotent).
    def self.pull(variants : Array(Symbol) = [:sc],
                  source : String = DEFAULT_SOURCE,
                  system : Bool = false) : Int32
      target_dir = dir(system: system)
      Dir.mkdir_p(target_dir)

      success = 0
      variants.each do |variant|
        info = VARIANT_FILES[variant]?
        unless info
          STDERR.puts "Variante inconnue : #{variant}. Variantes valides : #{VARIANT_FILES.keys.map(&.to_s).join(", ")}"
          next
        end

        path = File.join(target_dir, info[:file])
        if File.exists?(path)
          # Idempotent — skip already-cached variants.
          next
        end

        url = "#{source}/#{info[:dir]}/#{info[:file]}"
        if download(url, path)
          success += 1
        else
          STDERR.puts "Échec du téléchargement : #{url}"
        end
      end
      success
    end

    # Removes every cached font file. Returns the number of files
    # deleted.
    def self.purge(system : Bool = false) : Int32
      target_dir = dir(system: system)
      return 0 unless Dir.exists?(target_dir)

      deleted = 0
      Dir.children(target_dir).each do |entry|
        if entry.ends_with?(".otf")
          File.delete(File.join(target_dir, entry))
          deleted += 1
        end
      end
      deleted
    end

    # Downloads `url` to `path`, atomic via tmp-then-rename so a
    # partial download never leaves a corrupt OTF in the cache.
    # Returns true on success, false on any failure.
    private def self.download(url : String, path : String) : Bool
      uri = URI.parse(url)
      response = HTTP::Client.get(uri)
      return false unless response.success?
      tmp = "#{path}.tmp"
      File.write(tmp, response.body)
      File.rename(tmp, path)
      true
    rescue
      false
    end
  end
end
