require "./spec_helper"

@[Kebab::Command(name: "week")]
struct GlobalSpecWeek
  include Kebab::Parseable

  getter at : String?
end

@[Kebab::Command(name: "day")]
struct GlobalSpecDay
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : GlobalSpecWeek
end

struct GlobalSpecRoot
  include Kebab::Parseable

  @[Kebab::Option(global: true)]
  getter? no_colour : Bool = false

  @[Kebab::Option(global: true, short: 's')]
  getter scope : String?

  @[Kebab::Subcommand]
  getter command : GlobalSpecWeek | GlobalSpecDay
end

struct GlobalSpecLeaf
  include Kebab::Parseable

  @[Kebab::Option(global: true)]
  getter? no_colour : Bool = false

  @[Kebab::Argument]
  getter name : String
end

@[Kebab::Command(name: "go")]
struct GlobalSpecGo
  include Kebab::Parseable

  @[Kebab::Option(short: 'f')]
  getter? force : Bool = false
end

struct GlobalSpecCluster
  include Kebab::Parseable

  @[Kebab::Option(global: true, short: 'v')]
  getter? verbose : Bool = false

  @[Kebab::Subcommand]
  getter command : GlobalSpecGo
end

private def parse_root!(args : Array(String)) : GlobalSpecRoot
  GlobalSpecRoot.parse(args).as(GlobalSpecRoot)
end

describe "Kebab::Parseable global options" do
  it "accepts a global flag before the subcommand" do
    root = parse_root!(["--no-colour", "week"])
    root.no_colour?.should be_true
    root.command.should be_a(GlobalSpecWeek)
  end

  it "accepts a global flag after the subcommand" do
    root = parse_root!(["week", "--no-colour"])
    root.no_colour?.should be_true
    root.command.should be_a(GlobalSpecWeek)
  end

  it "accepts a global value option after the subcommand" do
    parse_root!(["week", "--scope", "team"]).scope.should eq("team")
  end

  it "accepts a global value option's short form after the subcommand" do
    parse_root!(["week", "-s", "team"]).scope.should eq("team")
  end

  it "accepts a global value option as an inline value" do
    parse_root!(["week", "--scope=team"]).scope.should eq("team")
  end

  it "accepts a global flag after a nested subcommand" do
    root = parse_root!(["day", "week", "--no-colour"])
    root.no_colour?.should be_true
    root.command.as(GlobalSpecDay).command.should be_a(GlobalSpecWeek)
  end

  it "leaves globals unset when absent" do
    root = parse_root!(["week"])
    root.no_colour?.should be_false
    root.scope.should be_nil
  end

  it "errors when a global flag is repeated across the subcommand boundary" do
    GlobalSpecRoot.parse(["--no-colour", "week", "--no-colour"]).as(Kebab::Errors)
      .should be_a(Kebab::Error::RepeatedOption)
  end

  it "rejects an inline value on a global flag" do
    GlobalSpecRoot.parse(["--no-colour=x", "week"]).as(Kebab::Errors)
      .should be_a(Kebab::Error::InvalidValue)
  end

  it "stops collecting globals at `--`" do
    leaf = GlobalSpecLeaf.parse(["--", "--no-colour"]).as(GlobalSpecLeaf)
    leaf.no_colour?.should be_false
    leaf.name.should eq("--no-colour")
  end

  it "exposes a global option in the command's schema" do
    GlobalSpecRoot.schema.options.map(&.long).should contain("no-colour")
  end

  it "propagates a global into a subcommand's schema (so its help and completion list it)" do
    week = GlobalSpecRoot.schema.subcommands.find! { |command| command.name == "week" }
    week.options.map(&.long).should contain("no-colour")
    week.options.map(&.long).should contain("scope")
  end

  it "propagates a global down through nested subcommands" do
    day = GlobalSpecRoot.schema.subcommands.find! { |command| command.name == "day" }
    nested_week = day.subcommands.find! { |command| command.name == "week" }
    nested_week.options.map(&.long).should contain("no-colour")
  end

  it "extracts a global short from a cluster, leaving the rest for the subcommand" do
    root = GlobalSpecCluster.parse(["go", "-vf"]).as(GlobalSpecCluster)
    root.verbose?.should be_true
    root.command.as(GlobalSpecGo).force?.should be_true
  end

  it "extracts a global short regardless of its position in the cluster" do
    root = GlobalSpecCluster.parse(["go", "-fv"]).as(GlobalSpecCluster)
    root.verbose?.should be_true
    root.command.as(GlobalSpecGo).force?.should be_true
  end

  it "leaves a cluster untouched when it has no global short" do
    root = GlobalSpecCluster.parse(["go", "-f"]).as(GlobalSpecCluster)
    root.verbose?.should be_false
    root.command.as(GlobalSpecGo).force?.should be_true
  end
end
