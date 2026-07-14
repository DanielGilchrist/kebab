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

enum SchemaFormat
  Text
  Json
  PrettyJson
end

module SchemaAliasedFormat
  def self.convert(input : String) : SchemaFormat | Kebab::Convert::Failure
    SchemaFormat.parse?(input) || Kebab::Convert.failure
  end
end

@[Kebab::Command(name: "render", summary: "Render")]
private struct SchemaRender
  include Kebab::Parseable

  @[Kebab::Option(description: "Output format")]
  getter format : SchemaFormat = SchemaFormat::Text

  @[Kebab::Option(description: "Custom-converted format", converter: SchemaAliasedFormat)]
  getter aliased : SchemaFormat = SchemaFormat::Text

  @[Kebab::Option(description: "Free text")]
  getter label : String?

  @[Kebab::Argument(description: "Target format")]
  getter target : SchemaFormat = SchemaFormat::Text
end

@[Kebab::Command(name: "gather", summary: "Gather")]
private struct SchemaRepeat
  include Kebab::Parseable

  @[Kebab::Option(description: "Tags")]
  getter tag : Array(String) = [] of String

  @[Kebab::Option(count: true, description: "Verbosity")]
  getter verbosity : Int32 = 0

  @[Kebab::Option(description: "Label")]
  getter label : String?

  @[Kebab::Option(description: "Force")]
  getter? force : Bool = false
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

  it "derives the usage line from the node shape" do
    SchemaTasks.schema.usage.to_s.should eq("tasks <command>")
    SchemaTasks.schema.subcommands.find!(&.name.== "add").usage.to_s.should eq("tasks add [options] <description>")
  end

  it "treats a leaf command as having no subcommands" do
    SchemaAdd.schema.subcommands.should be_empty
  end

  describe "enum value choices" do
    it "lists an enum option's values, sorted and underscored" do
      format = SchemaRender.schema.options.find!(&.long.== "format")
      format.value_choices.should eq(["json", "pretty_json", "text"])
    end

    it "lists an enum argument's values" do
      target = SchemaRender.schema.arguments.find!(&.name.== "target")
      target.value_choices.should eq(["json", "pretty_json", "text"])
    end

    it "leaves choices empty for a non-enum option" do
      label = SchemaRender.schema.options.find!(&.long.== "label")
      label.value_choices.should be_empty
    end

    it "leaves choices empty for an enum behind a custom converter" do
      aliased = SchemaRender.schema.options.find!(&.long.== "aliased")
      aliased.value_choices.should be_empty
    end
  end

  describe "option repetition" do
    it "classifies how each option accumulates across occurrences" do
      options = SchemaRepeat.schema.options
      options.find!(&.long.== "tag").repetition.collect?.should be_true
      options.find!(&.long.== "verbosity").repetition.count?.should be_true
      options.find!(&.long.== "label").repetition.none?.should be_true
      options.find!(&.long.== "force").repetition.none?.should be_true
    end

    it "derives repeatable? from the repetition" do
      options = SchemaRepeat.schema.options
      options.find!(&.long.== "tag").repeatable?.should be_true
      options.find!(&.long.== "verbosity").repeatable?.should be_true
      options.find!(&.long.== "label").repeatable?.should be_false
      options.find!(&.long.== "force").repeatable?.should be_false
    end
  end
end
