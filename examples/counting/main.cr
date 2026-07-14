require "../../src/kebab"

@[Kebab::Command(summary: "Run a build with adjustable verbosity")]
struct Build
  include Kebab::Parseable

  # Any int type works.
  @[Kebab::Option(short: 'v', count: true, description: "Increase verbosity, repeatable")]
  getter verbosity : UInt8 = 0

  @[Kebab::Option(short: 'q', description: "Suppress the summary line")]
  getter? quiet : Bool = false

  def run : Nil
    puts "verbosity #{verbosity}" unless quiet?
    puts "resolving dependencies" if verbosity >= 1
    puts "reading from cache" if verbosity >= 2
    puts "tracing every step" if verbosity >= 3
  end
end

exit(1) unless Build.run(ARGV)
