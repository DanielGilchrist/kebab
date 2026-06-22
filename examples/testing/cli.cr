require "../../src/kebab"

# Stands in for whatever your commands depend on. Injecting it (rather than
# reaching for globals) is what keeps `run` testable.
record Context, output : IO

@[Kebab::Command(summary: "Greet someone")]
struct Greet
  include Kebab::Parseable

  @[Kebab::Argument(description: "Name to greet")]
  getter name : String

  @[Kebab::Option(short: 'l', description: "Make it loud")]
  getter? loud : Bool = false

  def run(context : Context) : Nil
    message = "Hello, #{name}!"
    message = message.upcase if loud?
    context.output.puts(message)
  end
end
