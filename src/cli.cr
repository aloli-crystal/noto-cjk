require "option_parser"
require "./noto-cjk"

# noto-cjk CLI — manages the on-disk Noto Sans CJK cache.
#
# Examples (shell):
#   $ noto-cjk pull                            # default variant = sc
#   $ noto-cjk pull --variant jp               # Japanese only
#   $ noto-cjk pull --variant sc,jp            # both
#   $ noto-cjk pull --variant all              # all four (~80 MB)
#   $ noto-cjk pull --source https://mirror/   # private mirror
#   $ noto-cjk pull --system                   # /var/cache/...
#   $ noto-cjk info                            # list installed
#   $ noto-cjk purge                           # delete every variant

source = NotoCjk::Cache::DEFAULT_SOURCE
system_cache = false
variant_arg = "sc"

parser = OptionParser.new do |p|
  p.banner = <<-BANNER
    Usage : noto-cjk SOUS-COMMANDE [options]

    Sous-commandes :
      pull          Télécharge la/les variante(s) Noto Sans CJK dans le cache
      info          Affiche l'emplacement et les variantes installées
      purge         Vide le cache local

    Options :
    BANNER

  p.on("-V VARIANT", "--variant VARIANT", "Variante(s) à télécharger : sc, tc, jp, kr, all, ou liste séparée par des virgules (défaut : sc)") { |v| variant_arg = v }
  p.on("-s URL", "--source URL", "URL source (défaut : Noto upstream sur GitHub)") { |v| source = v }
  p.on("--system", "Écrit dans le cache système (/var/cache/noto-cjk)") { system_cache = true }

  p.separator ""
  p.separator "Aide :"
  p.on("-v", "--version", "Afficher la version") do
    puts "noto-cjk #{NotoCjk::VERSION}"
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
    NotoCjk::VARIANTS
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
when "help", "-h", "--help"
  # UX standard `<cli> help [<sub>]` — cf. note mémoire ALOLI
  # `feedback_cli_help_subcommand.md`. Sans argument c'est l'aide
  # globale. Avec argument on filtre sur la sous-commande demandée.
  sub = positional[1]?
  if sub.nil? || sub.empty?
    puts parser
    exit 0
  end
  valid_subs = %w(pull info purge)
  unless valid_subs.includes?(sub.downcase)
    STDERR.puts "Aide indisponible pour « #{sub} » (sous-commandes : #{valid_subs.join(", ")})."
    STDERR.puts "Utilisez `noto-cjk help` pour l'aide globale."
    exit 1
  end
  full = parser.to_s
  puts full
  puts ""
  puts "─── Focus : #{sub} ───"
  # Restrict the focus search to the « Sous-commandes : » section so a
  # sub name appearing earlier (usage line, an option's description)
  # can't steal the match.
  in_subcommands = false
  full.lines.each_with_index do |line, i|
    in_subcommands = true if line.includes?("Sous-commandes :")
    next unless in_subcommands
    if line.includes?("  #{sub}  ") || line.lstrip.starts_with?("#{sub} ")
      full.lines[i, 6].each { |l| puts l.rstrip }
      break
    end
  end
  exit 0
when "pull"
  variants = parse_variants(variant_arg)
  unknown = variants - NotoCjk::VARIANTS
  unless unknown.empty?
    STDERR.puts "Erreur : variante(s) inconnue(s) : #{unknown.map(&.to_s).join(", ")}"
    STDERR.puts "Variantes valides : sc, tc, jp, kr, all"
    exit 1
  end
  target = NotoCjk::Cache.dir(system: system_cache)
  puts "Téléchargement vers : #{target}"
  puts "Source              : #{source}"
  puts "Variantes           : #{variants.map(&.to_s).join(", ")}"
  puts "Patientez (≈ 16-20 Mo par variante)..."
  count = NotoCjk::Cache.pull(variants: variants, source: source, system: system_cache)
  installed = NotoCjk::Cache.installed(system: system_cache)
  puts "Téléchargé : #{count} nouvelle(s) variante(s) (cache total : #{installed.size} variante(s) — #{installed.map(&.to_s).join(", ")})"
when "info"
  installed = NotoCjk::Cache.installed(system: system_cache)
  puts "Emplacement : #{NotoCjk::Cache.dir(system: system_cache)}"
  puts "Variantes installées : #{installed.empty? ? "(aucune)" : installed.map(&.to_s).join(", ")}"
  puts "Variantes disponibles : #{NotoCjk::VARIANTS.map(&.to_s).join(", ")}"
when "purge"
  count = NotoCjk::Cache.purge(system: system_cache)
  puts "Cache vidé : #{count} fichier(s) supprimé(s) dans #{NotoCjk::Cache.dir(system: system_cache)}"
else
  STDERR.puts "Erreur : sous-commande inconnue « #{positional.first} »"
  STDERR.puts parser
  exit 1
end
