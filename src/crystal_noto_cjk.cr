require "./crystal_noto_cjk/version"
require "./crystal_noto_cjk/cache"

# CJK glyph coverage for Crystal — provides Noto Sans CJK fonts
# from https://github.com/notofonts/noto-cjk via an opt-in
# on-disk cache. Pure Crystal, no embedded payload (the OTF
# files weigh ~16-20 MB each, too heavy to ship in every
# dependent binary).
#
# **Usage** :
#
# ```
# require "crystal-noto-cjk"
#
# # First-time setup : download the variant(s) you need.
# CrystalNotoCJK::Cache.pull(variants: [:sc]) # ≈ 16 MB
#
# # Use as a font path in any TTF-aware library.
# if (path = CrystalNotoCJK.font_path)
#   theme.cjk_font_path = path # e.g. for crystal-asciidoctor-pdf
# end
# ```
#
# **Variants** :
#
# * `:sc` — Simplified Chinese (default; covers all CJK Unified
#   Ideographs codepoints, the broadest single-variant choice)
# * `:tc` — Traditional Chinese (Taiwan, Hong Kong)
# * `:jp` — Japanese (kanji + hiragana + katakana)
# * `:kr` — Korean (hangul + hanja)
#
# All four use the **same Unicode codepoints** for shared CJK
# Unified Ideographs, but glyph shapes differ by typographic
# convention. Pick the variant matching your authoring language ;
# default to `:sc` if you just want a fallback safety net.
module CrystalNotoCJK
  # All variant identifiers, in the order Noto upstream lists them.
  VARIANTS = [:sc, :tc, :jp, :kr] of Symbol

  # Returns the path to the OTF file for `variant`. When called
  # without a variant, returns the path of the first installed
  # variant (in `VARIANTS` order). Returns `nil` when nothing is
  # cached — call `Cache.pull` to populate.
  #
  # ```
  # CrystalNotoCJK.font_path      # => "/.../NotoSansCJKsc-Regular.otf" or nil
  # CrystalNotoCJK.font_path(:jp) # => "/.../NotoSansCJKjp-Regular.otf" or nil
  # ```
  def self.font_path(variant : Symbol? = nil) : String?
    if variant
      Cache.path(variant)
    else
      VARIANTS.each do |v|
        if (p = Cache.path(v))
          return p
        end
      end
      nil
    end
  end

  # `true` when at least one CJK variant is installed in the cache.
  def self.populated? : Bool
    !Cache.installed.empty?
  end
end
