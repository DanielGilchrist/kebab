require "../../src/kebab"

@[Kebab::Command(summary: "Add a task")]
struct Add
  include Kebab::Parseable

  @[Kebab::Argument(description: "Task description")]
  getter description : String

  @[Kebab::Option(short: 'p', description: "Priority (1-9)")]
  getter priority : Int32 = 1
end

@[Kebab::Command(summary: "List tasks")]
struct List
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Include completed")]
  getter? all : Bool = false
end

@[Kebab::Command(summary: "Print a shell completion script")]
struct Completions
  include Kebab::Parseable

  @[Kebab::Argument(description: "Shell")]
  getter shell : Kebab::Completion::Shell
end

@[Kebab::Command(summary: "A tiny todo app")]
struct Todo
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : Add | List | Completions
end

case result = Todo.parse
in Todo
  case sub = result.command
  in Add
    puts "Added (p#{sub.priority}): #{sub.description}"
  in List
    puts sub.all? ? "All tasks" : "Pending tasks"
  in Completions
    puts sub.shell.generate(Todo.schema)
  end
in Kebab::Help
  puts result
in Kebab::Errors
  STDERR.puts result
  exit(1)
end
