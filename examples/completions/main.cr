require "../../src/kebab"

@[Kebab::Command(name: "add", summary: "Add a task")]
struct Add
  include Kebab::Parseable

  @[Kebab::Argument(description: "Task description")]
  getter description : String

  @[Kebab::Option(short: 'p', description: "Priority (1-9)")]
  getter priority : Int32 = 1

  def run : Nil
    puts "Added (p#{priority}): #{description}"
  end
end

@[Kebab::Command(name: "list", summary: "List tasks")]
struct List
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Include completed")]
  getter? all : Bool = false

  def run : Nil
    puts all? ? "All tasks" : "Pending tasks"
  end
end

# A normal subcommand. The shell is a typed enum, parsed by kebab, so an
# unknown shell is a parse error listing the valid ones (no hand-rolled check).
@[Kebab::Command(name: "completions", summary: "Print a shell completion script")]
struct Completions
  include Kebab::Parseable

  @[Kebab::Argument(description: "Shell", converter: Kebab::Convert::Enum(Kebab::Completion::Shell))]
  getter shell : Kebab::Completion::Shell

  def run : Nil
    puts shell.generate(Todo.schema)
  end
end

@[Kebab::Command(name: "todo", summary: "A tiny todo app")]
struct Todo
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : Add | List | Completions
end

exit(1) unless Todo.run(ARGV)
