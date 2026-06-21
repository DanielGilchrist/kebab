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

describe Kebab::Completion::Shell do
  describe "#file_name" do
    it "names the script per shell convention" do
      Kebab::Completion::Shell::Fish.file_name("tasks").should eq("tasks.fish")
      Kebab::Completion::Shell::Bash.file_name("tasks").should eq("tasks")
      Kebab::Completion::Shell::Zsh.file_name("tasks").should eq("_tasks")
    end
  end

  describe "#generate (fish)" do
    it "disables file completion and names the binary from the schema" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema)
      script.should contain("complete -c tasks -f")
    end

    it "offers subcommands gated to before a subcommand is chosen" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema)
      script.should contain("complete -c tasks -n '__fish_use_subcommand' -a 'add' -d 'Add a task'")
      script.should contain("-a 'help' -d 'Show this help'")
    end

    it "scopes a subcommand's options to that subcommand, marking value options" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema)
      script.should contain("complete -c tasks -n '__fish_seen_subcommand_from add' -s p -l priority -d 'Priority' -r")
    end

    it "honours a binary-name override" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema, "tw")
      script.should contain("complete -c tw -f")
    end
  end

  describe "#generate (bash)" do
    it "registers a completion function and dispatches on the command path" do
      script = Kebab::Completion::Shell::Bash.generate(CompTasks.schema)
      script.should contain("complete -F _tasks tasks")
      script.should contain("tasks)")
      script.should contain("tasks__add)")
      script.should contain("compgen -W")
    end
  end

  describe "#generate (zsh)" do
    it "emits a compdef function dispatching on the command path" do
      script = Kebab::Completion::Shell::Zsh.generate(CompTasks.schema)
      script.should contain("#compdef tasks")
      script.should contain("tasks__add)")
      script.should contain("compadd --")
    end
  end

  it "parses from the CLI via Convert::Enum" do
    Kebab::Convert::Enum(Kebab::Completion::Shell).parse("zsh").should eq(Kebab::Completion::Shell::Zsh)
  end
end
