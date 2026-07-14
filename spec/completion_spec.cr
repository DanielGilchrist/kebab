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

@[Kebab::Command(name: "deep", summary: "Deep leaf")]
private struct CompDeep
  include Kebab::Parseable
end

@[Kebab::Command(name: "mid", summary: "Middle command")]
private struct CompMid
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : CompDeep
end

@[Kebab::Command(name: "tri", summary: "Three levels")]
private struct CompTri
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : CompMid
end

@[Kebab::Command(name: "multi", summary: "Multi-value")]
private struct CompMulti
  include Kebab::Parseable

  @[Kebab::Option]
  getter pair : Tuple(Int32, Int32) = {0, 0}

  @[Kebab::Option(arity: 1..)]
  getter files : Array(String) = [] of String
end

describe Kebab::Completion::Shell do
  describe "#generate (fish)" do
    it "disables file completion and names the binary from the schema" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema)
      script.should contain("complete -c tasks -f")
    end

    it "offers root subcommands gated to the root path" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema)
      script.should contain("function __kebab_tasks_at")
      script.should contain("complete -c tasks -n '__kebab_tasks_at' -a 'add' -d 'Add a task'")
      script.should contain("-a 'help' -d 'Show this help'")
    end

    it "scopes a subcommand's options to that subcommand, marking value options" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema)
      script.should contain("complete -c tasks -n '__kebab_tasks_at add' -s p -l priority -d 'Priority' -r")
    end

    it "offers each node's candidates only at exactly its path" do
      script = Kebab::Completion::Shell::Fish.generate(CompTri.schema)
      script.should contain("complete -c tri -n '__kebab_tri_at' -a 'mid'")
      script.should contain("complete -c tri -n '__kebab_tri_at mid' -a 'deep'")
    end

    it "skips a valued option's value when rebuilding the path" do
      script = Kebab::Completion::Shell::Fish.generate(CompTasks.schema)
      script.should contain("case '--priority' '-p'")
      script.should contain("set skip 1")
    end

    it "skips multi-value and variable options by their counts" do
      script = Kebab::Completion::Shell::Fish.generate(CompMulti.schema)
      script.should contain("case '--pair'")
      script.should contain("set skip 2")
      script.should contain("case '--files'")
      script.should contain("set greedy 1")
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

    it "skips a valued option's value when rebuilding the path" do
      script = Kebab::Completion::Shell::Bash.generate(CompTasks.schema)
      script.should contain("--priority|-p) ((i+=1)) ;;")
    end

    it "skips multi-value and variable options by their counts" do
      script = Kebab::Completion::Shell::Bash.generate(CompMulti.schema)
      script.should contain("--pair) ((i+=2)) ;;")
      script.should contain("--files) while ((i + 1 < COMP_CWORD)) && [[ \"${COMP_WORDS[i+1]}\" != -* ]]; do ((i++)); done ;;")
    end
  end

  describe "#generate (zsh)" do
    it "emits a compdef function dispatching on the command path" do
      script = Kebab::Completion::Shell::Zsh.generate(CompTasks.schema)
      script.should contain("#compdef tasks")
      script.should contain("tasks__add)")
      script.should contain("compadd --")
    end

    it "skips a valued option's value when rebuilding the path" do
      script = Kebab::Completion::Shell::Zsh.generate(CompTasks.schema)
      script.should contain("--priority|-p) ((i+=1)) ;;")
    end

    it "skips multi-value and variable options by their counts" do
      script = Kebab::Completion::Shell::Zsh.generate(CompMulti.schema)
      script.should contain("--pair) ((i+=2)) ;;")
      script.should contain("--files) while ((i + 1 < CURRENT)) && [[ \"${words[i+1]}\" != -* ]]; do ((i++)); done ;;")
    end
  end

  it "parses from the CLI via Convert::Enum" do
    Kebab::Convert::Enum(Kebab::Completion::Shell).convert("zsh").should eq(Kebab::Completion::Shell::Zsh)
  end
end
