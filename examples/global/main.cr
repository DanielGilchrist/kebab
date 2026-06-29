require "../../src/kebab"

@[Kebab::Command(summary: "Show the current status")]
struct Status
  include Kebab::Parseable
end

@[Kebab::Command(summary: "Show recent log entries")]
struct Log
  include Kebab::Parseable

  @[Kebab::Option(short: 'n', description: "How many entries")]
  getter limit : Int32 = 10
end

@[Kebab::Command(summary: "A tiny status app")]
struct App
  include Kebab::Parseable

  @[Kebab::Option(global: true, description: "Disable coloured output")]
  getter? no_colour : Bool = false

  @[Kebab::Subcommand]
  getter command : Status | Log
end

case result = App.parse
in App
  colour = result.no_colour? ? "off" : "on"
  case sub = result.command
  in Status
    puts "status (colour: #{colour})"
  in Log
    puts "last #{sub.limit} entries (colour: #{colour})"
  end
in Kebab::Help
  puts result
in Kebab::Errors
  STDERR.puts result
  exit(1)
end
