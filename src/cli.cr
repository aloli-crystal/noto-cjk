require "option_parser"
require "./crystal_noto_cjk"

# crystal-noto-cjk CLI — manages the on-disk Noto Sans CJK cache.
#
# Examples (shell):
#   $ crystal-noto-cjk pull                            # default variant = sc
#   $ crystal-noto-cjk pull --variant jp               # Japanese only
#   $ crystal-noto-cjk pull --variant sc,jp            # both
#   $ crystal-noto-cjk pull --variant all              # all four (~80 MB)
#   $ crystal-noto-cjk pull --source https://mirror/   # private mirror
#   $ crystal-noto-cjk pull --system                   # /var/cache/...
#   $ crystal-noto-cjk info                            # list installed
#   $ crystal-noto-cjk purge                           # delete every variant

source = CrystalNotoCJK::Cache::DEFAULT_SOURCE
system_cache = false
variant_arg = "sc"

parser = OptionParser.new do |p|
  p.banner = <<-BANNER
    Usage : crystal-noto-cjk SOUS-COMMANDE [options]

    Sous-commandes :
      pull          Télécharge la/les variante(s) Noto Sans CJK dans le cache
      info          Affiche l'emplacement et les variantes installées
      purge         Vide le cache local

    Options :
    BANNER

  p.on("-V VARIANT", "--variant VARIANT", "Variante(s) à télécharger : sc, tc, jp, kr, all, ou liste séparée par des virgules (défaut : sc)") { |v| variant_arg = v }
  p.on("-s URL", "--source URL", "URL source (défaut : Noto upstream sur GitHub)") { |v| source = v }
  p.on("--system", "Écrit dans le cache système (/var/cache/crystal-noto-cjk)") { system_cache = true }

  p.separator ""
  p.separator "Aide :"
  p.on("-v", "--version", "Afficher la version") do
    puts "crystal-noto-cjk #{CrystalNotoCJK::VERSION}"
    exit 0
  end
  p.on("-h", "--help", "Afficher l'aide") do
    puts p
    exit 0
  end

  p.invalid_option do |flag|
    STDERR.puts "Option inconnue : #{flag}"
    STDERR.puts p
    exit 1
  end
end

positional = [] of String
parser.unknown_args { |args| positional = args }
parser.parse(ARGV)

if positional.empty?
  STDERR.puts "Erreur : aucune sous-commande spécifiée"
  STDERR.puts parser
  exit 1
end

# Parse the variant argument : "sc", "all", or "sc,jp". Returns
# the matching `Symbol`s — Crystal can't build symbols from
# arbitrary strings at runtime, so we pattern-match against the
# known set.
def parse_variants(arg : String) : Array(Symbol)
  if arg.downcase == "all"
    CrystalNotoCJK::VARIANTS
  else
    arg.split(',').map do |s|
      case s.strip.downcase
      when "sc" then :sc
      when "tc" then :tc
      when "jp" then :jp
      when "kr" then :kr
      else
        STDERR.puts "Variante inconnue : #{s}"
        STDERR.puts "Variantes valides : sc, tc, jp, kr, all"
        exit 1
      end
    end
  end
end

case positional.first
when "pull"
  variants = parse_variants(variant_arg)
  unknown = variants - CrystalNotoCJK::VARIANTS
  unless unknown.empty?
    STDERR.puts "Erreur : variante(s) inconnue(s) : #{unknown.map(&.to_s).join(", ")}"
    STDERR.puts "Variantes valides : sc, tc, jp, kr, all"
    exit 1
  end
  target = CrystalNotoCJK::Cache.dir(system: system_cache)
  puts "Téléchargement vers : #{target}"
  puts "Source              : #{source}"
  puts "Variantes           : #{variants.map(&.to_s).join(", ")}"
  puts "Patientez (≈ 16-20 Mo par variante)..."
  count = CrystalNotoCJK::Cache.pull(variants: variants, source: source, system: system_cache)
  installed = CrystalNotoCJK::Cache.installed(system: system_cache)
  puts "Téléchargé : #{count} nouvelle(s) variante(s) (cache total : #{installed.size} variante(s) — #{installed.map(&.to_s).join(", ")})"
when "info"
  installed = CrystalNotoCJK::Cache.installed(system: system_cache)
  puts "Emplacement : #{CrystalNotoCJK::Cache.dir(system: system_cache)}"
  puts "Variantes installées : #{installed.empty? ? "(aucune)" : installed.map(&.to_s).join(", ")}"
  puts "Variantes disponibles : #{CrystalNotoCJK::VARIANTS.map(&.to_s).join(", ")}"
when "purge"
  count = CrystalNotoCJK::Cache.purge(system: system_cache)
  puts "Cache vidé : #{count} fichier(s) supprimé(s) dans #{CrystalNotoCJK::Cache.dir(system: system_cache)}"
else
  STDERR.puts "Erreur : sous-commande inconnue « #{positional.first} »"
  STDERR.puts parser
  exit 1
end
