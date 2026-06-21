require "../../src/kebab"

@[Kebab::Command(summary: "Print a greeting")]
struct Greet
  include Kebab::Parseable

  @[Kebab::Argument(description: "Name to greet")]
  getter name : String

  @[Kebab::Option(short: 'l', description: "Make it loud")]
  getter? loud : Bool = false

  @[Kebab::Option(short: 'n', description: "Number of times to repeat")]
  getter times : Int32 = 1

  def run : Nil
    message = "Hello, #{name}!"
    message = message.upcase if loud?
    times.times { puts message }
  end
end

exit(1) unless Greet.run(ARGV)
