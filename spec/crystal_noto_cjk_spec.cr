require "./spec_helper"

# These tests focus on the parts that don't touch the network :
# directory resolution, variant lookup, lookup chain. The actual
# `Cache.pull` (HTTP download) is intentionally NOT exercised in
# CI because the upstream Noto repo is large and we don't want
# every CI run to pull ~16 MB.

describe NotoCjk do
  describe "VARIANTS" do
    it "lists the four official Noto Sans CJK regional variants" do
      NotoCjk::VARIANTS.should eq([:sc, :tc, :jp, :kr])
    end
  end

  describe ".font_path" do
    it "returns nil when the cache is empty" do
      # In a fresh CI environment the cache is empty unless seeded.
      # Skip this assertion if the developer has actually run a
      # `pull` locally (which they might).
      pending "skipped if local cache is populated" if NotoCjk.populated?
      NotoCjk.font_path.should be_nil
    end

    it "returns nil for an unknown variant identifier" do
      # `:xx` isn't a real variant — should not raise, just return nil.
      NotoCjk.font_path(:xx).should be_nil
    end
  end

  describe ".populated?" do
    it "is a boolean" do
      [true, false].should contain(NotoCjk.populated?)
    end
  end
end

describe NotoCjk::Cache do
  describe "VARIANT_FILES" do
    it "covers every variant" do
      NotoCjk::Cache::VARIANT_FILES.keys.to_a.sort.should eq([:jp, :kr, :sc, :tc])
    end

    it "uses the upstream Noto file naming convention" do
      NotoCjk::Cache::VARIANT_FILES[:sc][:file].should eq("NotoSansCJKsc-Regular.otf")
      NotoCjk::Cache::VARIANT_FILES[:jp][:file].should eq("NotoSansCJKjp-Regular.otf")
    end
  end

  describe ".dir" do
    it "honours CRYSTAL_NOTO_CJK_CACHE_DIR if set" do
      ENV["CRYSTAL_NOTO_CJK_CACHE_DIR"] = "/tmp/test-noto-cjk-cache"
      begin
        NotoCjk::Cache.dir.should eq("/tmp/test-noto-cjk-cache")
      ensure
        ENV.delete("CRYSTAL_NOTO_CJK_CACHE_DIR")
      end
    end

    it "uses /var/cache/noto-cjk for system mode" do
      NotoCjk::Cache.dir(system: true).should eq("/var/cache/noto-cjk")
    end

    it "falls back to a user-owned cache path otherwise" do
      ENV.delete("CRYSTAL_NOTO_CJK_CACHE_DIR") if ENV.has_key?("CRYSTAL_NOTO_CJK_CACHE_DIR")
      ENV.delete("XDG_CACHE_HOME") if ENV.has_key?("XDG_CACHE_HOME")
      path = NotoCjk::Cache.dir
      path.should contain("noto-cjk")
      path.should_not contain("/var/cache")
    end
  end

  describe ".path" do
    it "returns nil for an unknown variant" do
      NotoCjk::Cache.path(:xx).should be_nil
    end

    it "returns nil when the variant file is not on disk" do
      ENV["CRYSTAL_NOTO_CJK_CACHE_DIR"] = "/tmp/empty-noto-cache-#{Random.rand(1_000_000)}"
      begin
        NotoCjk::Cache.path(:sc).should be_nil
      ensure
        ENV.delete("CRYSTAL_NOTO_CJK_CACHE_DIR")
      end
    end
  end

  describe ".installed" do
    it "returns an empty array on a fresh cache" do
      ENV["CRYSTAL_NOTO_CJK_CACHE_DIR"] = "/tmp/empty-noto-cache-#{Random.rand(1_000_000)}"
      begin
        NotoCjk::Cache.installed.should be_empty
      ensure
        ENV.delete("CRYSTAL_NOTO_CJK_CACHE_DIR")
      end
    end
  end
end
