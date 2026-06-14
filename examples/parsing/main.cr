require "../../src/kebab"

@[Kebab::Command(summary: "Print a greeting")]
struct Greet
  include Kebab::Parseable

  @[Kebab::Argument(description: "Name to greet")]
  getter name : String

  @[Kebab::Option(short: 'l', description: "Make it loud")]
  getter? loud : Bool = false
end

case result = Greet.parse(ARGV)
in Greet
  message = "Hello, #{result.name}!"
  message = message.upcase if result.loud?
  puts message
in Kebab::Help
  puts result
in Kebab::Errors
  STDERR.puts(result)
  exit(1)
end
