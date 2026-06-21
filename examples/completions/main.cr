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

@[Kebab::Command(name: "todo", summary: "A tiny todo app")]
struct Todo
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : Add | List
end

# Completion generation is a meta-operation, so handle it before normal
# parsing. Kebab gives you the script as a string and you decide how to expose
# it (a hidden subcommand, a flag, a separate binary, whatever fits).
if ARGV.first? == "completions"
  case ARGV[1]?
  when "fish"
    puts Todo.completion_fish("todo")
  else
    STDERR.puts "usage: todo completions fish"
    exit(1)
  end
  exit
end

exit(1) unless Todo.run(ARGV)
