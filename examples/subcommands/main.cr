require "../../src/kebab"

@[Kebab::Command(summary: "Add a task")]
struct Add
  include Kebab::Parseable

  @[Kebab::Argument(description: "Task description")]
  getter description : String

  def run : Nil
    puts "Added: #{description}"
  end
end

@[Kebab::Command(summary: "Show all tasks")]
struct List
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Include completed")]
  getter? all : Bool = false

  def run : Nil
    puts all? ? "Showing all tasks" : "Showing pending tasks"
  end
end

@[Kebab::Command(name: "tasks", summary: "A tiny todo app")]
struct Tasks
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : Add | List
end

exit(1) unless Tasks.run(ARGV)
