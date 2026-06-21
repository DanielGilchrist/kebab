require "./spec_helper"

@[Kebab::Command(name: "add", summary: "Add a task")]
private struct CompAdd
  include Kebab::Parseable

  @[Kebab::Argument(description: "Task description")]
  getter description : String

  @[Kebab::Option(short: 'p', description: "Priority")]
  getter priority : Int32 = 0
end

@[Kebab::Command(name: "list", summary: "List tasks")]
private struct CompList
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Include completed")]
  getter? all : Bool = false
end

@[Kebab::Command(name: "tasks", summary: "A todo app")]
private struct CompTasks
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : CompAdd | CompList
end

@[Kebab::Command(name: "greet", summary: "Greet someone")]
private struct CompGreet
  include Kebab::Parseable

  @[Kebab::Argument(description: "Name to greet")]
  getter name : String

  @[Kebab::Option(short: 'l', description: "Make it 'loud'")]
  getter? loud : Bool = false
end

describe "Kebab::Parseable.completion_fish" do
  it "disables file completion and sets the binary name" do
    script = CompTasks.completion_fish("tasks")
    script.should contain("complete -c tasks -f")
  end

  it "offers subcommands gated to before a subcommand is chosen" do
    script = CompTasks.completion_fish("tasks")
    script.should contain("complete -c tasks -n '__fish_use_subcommand' -a 'add' -d 'Add a task'")
    script.should contain("complete -c tasks -n '__fish_use_subcommand' -a 'list' -d 'List tasks'")
    script.should contain("-a 'help' -d 'Show this help'")
  end

  it "scopes a subcommand's options to that subcommand" do
    script = CompTasks.completion_fish("tasks")
    script.should contain("complete -c tasks -n '__fish_seen_subcommand_from add' -s p -l priority -d 'Priority' -r")
    script.should contain("complete -c tasks -n '__fish_seen_subcommand_from add' -s h -l help -d 'Show this help'")
  end

  it "marks value options with -r and leaves flags without it" do
    script = CompTasks.completion_fish("tasks")
    # boolean flag: no -r
    script.should contain("complete -c tasks -n '__fish_seen_subcommand_from list' -s a -l all -d 'Include completed'\n")
  end

  it "ungates options for a single command with no subcommands" do
    script = CompGreet.completion_fish("greet")
    script.should contain("complete -c greet -f\n")
    script.should contain("complete -c greet -s l -l loud -d 'Make it \\'loud\\''\n")
    script.should_not contain("__fish_use_subcommand")
  end
end
