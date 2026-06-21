require "../../src/kebab"

@[Kebab::Command(summary: "Add a task")]
struct Add
  include Kebab::Parseable

  @[Kebab::Argument(description: "Task description")]
  getter description : String
end

@[Kebab::Command(summary: "Show all tasks")]
struct List
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Include completed")]
  getter? all : Bool = false
end

@[Kebab::Command(name: "tasks", summary: "A tiny todo app")]
struct Tasks
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : Add | List
end

# Tasks.parse(ARGV) : Tasks | Kebab::Help | Kebab::Errors
case result = Tasks.parse(ARGV)
in Tasks
  # The chosen subcommand lives in result.command, typed Add | List.
  case sub = result.command
  in Add
    puts "Added: #{sub.description}"
  in List
    if sub.all?
      puts "Showing all tasks"
    else
      puts "Showing pending tasks"
    end
  end
in Kebab::Help
  puts result
in Kebab::Errors
  STDERR.puts result
  exit(1)
end
