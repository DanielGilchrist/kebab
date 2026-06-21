require "levenshtein"

require "../../src/kebab"

# Builds the "did you mean" hint shared by the handlers below. Returns an
# empty string when nothing is close enough.
module Suggest
  def self.hint(input : String, candidates : Enumerable(String)) : String
    if guess = Levenshtein.find(input, candidates)
      " (did you mean '#{guess}'?)"
    else
      ""
    end
  end
end

@[Kebab::Command(name: "deploy", summary: "Deploy a service")]
struct Deploy
  include Kebab::Parseable

  # Errors route to the command that produced them, so an unknown option on
  # `deploy` is handled here rather than on the parent.
  def self.on_parse_error(error : Kebab::Errors, stderr : IO) : Bool
    case error
    when Kebab::Error::UnknownOption
      name = error.input.lstrip('-')
      stderr.puts "unknown option: #{error.input}#{Suggest.hint(name, error.schema.options.map(&.long))}"
      true
    else
      false
    end
  end

  @[Kebab::Argument(description: "Service to deploy")]
  getter service : String

  @[Kebab::Option(short: 'e', description: "Target environment")]
  getter env : String = "staging"

  @[Kebab::Option(description: "Skip confirmation")]
  getter? force : Bool = false

  def run : Nil
    puts "deploying #{service} to #{env} (force=#{force?})"
  end
end

@[Kebab::Command(name: "status", summary: "Show deployment status")]
struct Status
  include Kebab::Parseable

  @[Kebab::Argument(description: "Service to inspect")]
  getter service : String

  def run : Nil
    puts "#{service}: ok"
  end
end

@[Kebab::Command(name: "fleet", summary: "Manage a fleet of services")]
struct Fleet
  include Kebab::Parseable

  def self.on_parse_error(error : Kebab::Errors, stderr : IO) : Bool
    case error
    when Kebab::Error::UnknownCommand
      stderr.puts "unknown command: #{error.input}#{Suggest.hint(error.input, error.schema.subcommands.map(&.name))}"
      true
    else
      false
    end
  end

  @[Kebab::Subcommand]
  getter command : Deploy | Status
end

exit(1) unless Fleet.run(ARGV)
