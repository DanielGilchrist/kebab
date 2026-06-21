require "./spec_helper"

@[Kebab::Command(name: "add", summary: "Add a task")]
private struct SchemaAdd
  include Kebab::Parseable

  @[Kebab::Argument(description: "Task description")]
  getter description : String

  @[Kebab::Option(short: 'p', description: "Priority")]
  getter priority : Int32 = 0
end

@[Kebab::Command(name: "list", summary: "List tasks")]
private struct SchemaList
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Include completed")]
  getter? all : Bool = false
end

@[Kebab::Command(name: "tasks", summary: "A todo app")]
private struct SchemaTasks
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : SchemaAdd | SchemaList
end

describe "Kebab::Parseable.schema" do
  it "builds a recursive command tree" do
    schema = SchemaTasks.schema

    schema.name.should eq("tasks")
    schema.path.should eq(["tasks"])
    schema.summary.should eq("A todo app")
    schema.requires_subcommand?.should be_false
  end

  it "lists subcommands sorted with a synthetic help entry, prefixing the path" do
    schema = SchemaTasks.schema

    schema.subcommands.map(&.name).should eq(["add", "list", "help"])
    add = schema.subcommands.find!(&.name.== "add")
    add.path.should eq(["tasks", "add"])
    add.summary.should eq("Add a task")
  end

  it "carries each command's own arguments and options, with synthetic --help" do
    add = SchemaTasks.schema.subcommands.find!(&.name.== "add")

    add.arguments.map(&.name).should eq(["description"])
    add.options.map(&.long).should eq(["priority", "help"])
    add.has_options?.should be_true
  end

  it "marks a parent that declares no options of its own" do
    SchemaTasks.schema.has_options?.should be_false
  end

  it "honours parent_path so a child node knows its full path" do
    SchemaAdd.schema(["tasks"]).path.should eq(["tasks", "add"])
  end

  it "derives the usage line from the node shape" do
    SchemaTasks.schema.usage.to_s.should eq("tasks <command>")
    SchemaTasks.schema.subcommands.find!(&.name.== "add").usage.to_s.should eq("tasks add [options] <description>")
  end

  it "treats a leaf command as having no subcommands" do
    SchemaAdd.schema.subcommands.should be_empty
  end
end
