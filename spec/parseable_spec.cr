require "./spec_helper"

struct SpecDuration
  def self.parse(input : String) : self | Kebab::Convert::Failure
    if minutes = input.to_i32?
      new(minutes)
    else
      Kebab::Convert.failure("expected a duration in minutes", name: "duration")
    end
  end

  def initialize(@minutes : Int32); end

  getter minutes : Int32
end

module UpcaseConverter
  def self.parse(input : String) : String | Kebab::Convert::Failure
    input.upcase
  end
end

private struct Punch
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Clock in at a past time")]
  getter at : String?

  @[Kebab::Option(short: 's')]
  getter? skip_validations : Bool = false

  @[Kebab::Option]
  getter? verbose : Bool = false

  @[Kebab::Option]
  getter weeks : Int32 = 4

  @[Kebab::Option(converter: UpcaseConverter)]
  getter shout : String?

  @[Kebab::Option(long: "duration")]
  getter pause : SpecDuration?
end

private struct Trim
  include Kebab::Parseable

  @[Kebab::Argument]
  getter path : String

  @[Kebab::Argument]
  getter limit : Int32 = 10
end

private struct ConvertedArg
  include Kebab::Parseable

  @[Kebab::Argument(converter: UpcaseConverter)]
  getter value : String
end

private struct RequiredOption
  include Kebab::Parseable

  @[Kebab::Option]
  getter token : String
end

private struct FloatHaver
  include Kebab::Parseable

  @[Kebab::Option]
  getter ratio : Float64 = 0.5
end

private struct ConstantDefault
  include Kebab::Parseable

  MAX_WEEKS = 52

  @[Kebab::Option]
  getter weeks : Int32 = MAX_WEEKS
end

private def parse_punch!(args : Array(String)) : Punch
  Punch.parse(args).as(Punch)
end

private def parse_punch_error!(args : Array(String)) : Kebab::Errors
  Punch.parse(args).as(Kebab::Errors)
end

describe Kebab::Parseable do
  it "defaults everything with no args" do
    punch = parse_punch!([] of String)

    punch.at.should be_nil
    punch.skip_validations?.should be_false
    punch.verbose?.should be_false
    punch.weeks.should eq(4)
    punch.pause.should be_nil
  end

  it "parses space-separated long option values" do
    parse_punch!(["--at", "8:45"]).at.should eq("8:45")
  end

  it "parses inline long option values" do
    parse_punch!(["--at=8:45"]).at.should eq("8:45")
  end

  it "parses short option values" do
    parse_punch!(["-a", "8:45"]).at.should eq("8:45")
    parse_punch!(["-a=8:45"]).at.should eq("8:45")
  end

  it "parses long flags" do
    parse_punch!(["--verbose"]).verbose?.should be_true
  end

  it "kebab-cases multi-word ivar names into long flags" do
    parse_punch!(["--skip-validations"]).skip_validations?.should be_true
  end

  it "parses short flags and clusters" do
    parse_punch!(["-s"]).skip_validations?.should be_true

    punch = parse_punch!(["-sa", "8:45"])
    punch.skip_validations?.should be_true
    punch.at.should eq("8:45")
  end

  it "converts built-in number types" do
    parse_punch!(["--weeks", "12"]).weeks.should eq(12)
  end

  it "converts custom types via the parse protocol" do
    pause = parse_punch!(["--duration", "30"]).pause
    pause.should eq(SpecDuration.new(30))
  end

  it "applies converter overrides" do
    parse_punch!(["--shout", "hello"]).shout.should eq("HELLO")
  end

  it "errors on unknown long options" do
    error = parse_punch_error!(["--nope"])
    error.should be_a(Kebab::Error::UnknownOption)
    error.message.should eq("\"--nope\" isn't a recognised option.")
  end

  it "errors on unknown short options" do
    parse_punch_error!(["-z"]).should be_a(Kebab::Error::UnknownOption)
  end

  it "errors when a value is missing" do
    parse_punch_error!(["--at"]).should be_a(Kebab::Error::MissingValue)
    parse_punch_error!(["--at", "--verbose"]).should be_a(Kebab::Error::MissingValue)
  end

  it "errors when a valued short option is not last in a cluster" do
    parse_punch_error!(["-as", "8:45"]).should be_a(Kebab::Error::MissingValue)
  end

  it "errors when a built-in conversion fails" do
    error = parse_punch_error!(["--weeks", "potato"])
    error.should be_a(Kebab::Error::InvalidValue)
    error.message.should eq("\"potato\" isn't a valid whole number for \"--weeks\"")
  end

  it "errors when a custom conversion fails" do
    error = parse_punch_error!(["--duration", "potato"])
    error.should be_a(Kebab::Error::InvalidValue)
    error.message.should eq("\"potato\" isn't a valid duration for \"--duration\" (expected a duration in minutes)")
  end

  it "errors when a flag is given an inline value" do
    parse_punch_error!(["--verbose=true"]).should be_a(Kebab::Error::InvalidValue)
  end

  it "errors on unexpected positionals" do
    parse_punch_error!(["wat"]).should be_a(Kebab::Error::UnexpectedArgument)
  end

  it "treats everything after -- as positional" do
    parse_punch_error!(["--", "--verbose"]).should be_a(Kebab::Error::UnexpectedArgument)
  end

  it "binds positional arguments in declaration order" do
    trim = Trim.parse(["src/thing.cr", "5"]).as(Trim)
    trim.path.should eq("src/thing.cr")
    trim.limit.should eq(5)
  end

  it "defaults optional positional arguments" do
    trim = Trim.parse(["src/thing.cr"]).as(Trim)
    trim.limit.should eq(10)
  end

  it "errors when a required positional argument is missing" do
    error = Trim.parse([] of String).as(Kebab::Errors)
    error.should be_a(Kebab::Error::MissingArgument)
    error.message.should eq("argument \"<path>\" is required.")
  end

  it "accepts option values after the -- separator as positionals" do
    trim = Trim.parse(["--", "--weird-filename"]).as(Trim)
    trim.path.should eq("--weird-filename")
  end

  it "errors on a repeated long option" do
    error = parse_punch_error!(["--at", "8:45", "--at", "9:30"])
    error.should be_a(Kebab::Error::RepeatedOption)
    error.message.should eq("option \"--at\" was given more than once.")
  end

  it "errors on a repeated short option" do
    parse_punch_error!(["-a", "8:45", "-a", "9:30"]).should be_a(Kebab::Error::RepeatedOption)
  end

  it "errors on a repeated flag" do
    parse_punch_error!(["--verbose", "--verbose"]).should be_a(Kebab::Error::RepeatedOption)
  end

  it "errors on an empty short cluster" do
    error = parse_punch_error!(["-=foo"])
    error.should be_a(Kebab::Error::UnknownOption)
    error.message.should eq("\"-\" isn't a recognised option.")
  end

  it "errors when an option value looks like another option" do
    error = parse_punch_error!(["--at", "-3"])
    error.should be_a(Kebab::Error::MissingValue)
  end

  it "accepts negative-looking values via the inline = form" do
    parse_punch!(["--at=-3"]).at.should eq("-3")
  end

  it "errors when a required option is missing" do
    error = RequiredOption.parse([] of String).as(Kebab::Errors)
    error.should be_a(Kebab::Error::MissingOption)
    error.message.should eq("option \"--token\" is required.")
  end

  it "applies a converter to a positional argument" do
    ConvertedArg.parse(["hello"]).as(ConvertedArg).value.should eq("HELLO")
  end

  it "converts floats" do
    FloatHaver.parse(["--ratio", "0.25"]).as(FloatHaver).ratio.should eq(0.25)
  end

  it "errors on integer overflow" do
    error = parse_punch_error!(["--weeks", "99999999999999999999"])
    error.should be_a(Kebab::Error::InvalidValue)
  end

  it "resolves constants defined on the including struct as defaults" do
    ConstantDefault.parse([] of String).as(ConstantDefault).weeks.should eq(52)
  end

  it "exposes the typed input on UnknownOption" do
    error = parse_punch_error!(["--nope"]).as(Kebab::Error::UnknownOption)
    error.input.should eq("--nope")
  end

  it "exposes a Schema::Option on MissingValue" do
    error = parse_punch_error!(["--at"]).as(Kebab::Error::MissingValue)
    error.option.long.should eq("at")
  end

  it "carries the full option set and usage on MissingValue" do
    error = parse_punch_error!(["--at"]).as(Kebab::Error::MissingValue)
    error.options.map(&.long).should contain("at")
    error.usage.command_path.should eq(["punch"])
    error.to_s.should contain("Usage: punch")
    error.to_s.should contain("Options:")
  end

  it "exposes a Schema::Option on RepeatedOption" do
    error = parse_punch_error!(["--at", "8:45", "--at", "9:30"]).as(Kebab::Error::RepeatedOption)
    error.option.long.should eq("at")
  end

  it "carries the full option set and usage on RepeatedOption" do
    error = parse_punch_error!(["--at", "8:45", "--at", "9:30"]).as(Kebab::Error::RepeatedOption)
    error.options.map(&.long).should contain("at")
    error.usage.command_path.should eq(["punch"])
    error.to_s.should contain("Usage: punch")
    error.to_s.should contain("Options:")
  end

  it "exposes a Schema::Argument on MissingArgument" do
    error = Trim.parse([] of String).as(Kebab::Error::MissingArgument)
    error.argument.name.should eq("path")
  end

  it "exposes a Schema::Option on MissingOption" do
    error = RequiredOption.parse([] of String).as(Kebab::Error::MissingOption)
    error.option.long.should eq("token")
  end

  it "exposes the raw value on UnexpectedArgument" do
    error = parse_punch_error!(["wat"]).as(Kebab::Error::UnexpectedArgument)
    error.value.should eq("wat")
  end

  it "exposes structured fields on InvalidValue" do
    error = parse_punch_error!(["--weeks", "potato"]).as(Kebab::Error::InvalidValue)
    error.value.should eq("potato")
    error.target_type_name.should eq("Int32")
    error.target_name.should eq("whole number")
    error.reason.should be_nil
    case source = error.source
    in Kebab::Schema::Option   then source.long.should eq("weeks")
    in Kebab::Schema::Argument then fail "expected option source"
    end
    error.should be_a(Kebab::Error::InvalidValue::Typed(Int32, Punch))
  end

  it "narrows InvalidValue by target type via case" do
    error = parse_punch_error!(["--weeks", "potato"])
    case error
    when Kebab::Error::InvalidValue::Of(Int32)
      error.target_type.should eq(Int32)
    else
      fail "expected InvalidValue::Of(Int32)"
    end
  end
end

enum SpecOutputFormat
  Json
  Yaml
  Text
end

private struct EnumHaver
  include Kebab::Parseable

  @[Kebab::Option(converter: Kebab::Convert::Enum(SpecOutputFormat))]
  getter format : SpecOutputFormat = SpecOutputFormat::Text
end

private struct VariadicRequired
  include Kebab::Parseable

  @[Kebab::Argument(description: "Output directory")]
  getter output : String

  @[Kebab::Argument(description: "Files")]
  getter files : Array(String)
end

private struct VariadicOptional
  include Kebab::Parseable

  @[Kebab::Argument(description: "Files")]
  getter files : Array(String) = [] of String
end

private struct VariadicTyped
  include Kebab::Parseable

  @[Kebab::Argument(description: "Numbers")]
  getter values : Array(Int32)
end

module VariadicDoubler
  def self.parse(input : String) : Int32 | Kebab::Convert::Failure
    if n = input.to_i32?
      n * 2
    else
      Kebab::Convert.failure("not a number", name: "doubled int")
    end
  end
end

private struct VariadicWithConverter
  include Kebab::Parseable

  @[Kebab::Argument(converter: VariadicDoubler)]
  getter values : Array(Int32)
end

describe "Kebab::Parseable variadic arguments" do
  it "collects multiple positionals into the variadic field" do
    result = VariadicRequired.parse(["out", "a.txt", "b.txt", "c.txt"]).as(VariadicRequired)
    result.output.should eq("out")
    result.files.should eq(["a.txt", "b.txt", "c.txt"])
  end

  it "accepts a single positional for the variadic field" do
    result = VariadicRequired.parse(["out", "only.txt"]).as(VariadicRequired)
    result.files.should eq(["only.txt"])
  end

  it "errors when a required variadic has no positionals" do
    error = VariadicRequired.parse(["out"]).as(Kebab::Errors)
    error.should be_a(Kebab::Error::MissingArgument)
  end

  it "defaults to empty array when variadic has a default and no positionals" do
    result = VariadicOptional.parse([] of String).as(VariadicOptional)
    result.files.should eq([] of String)
  end

  it "converts each variadic element via the element type's converter" do
    result = VariadicTyped.parse(["1", "2", "3"]).as(VariadicTyped)
    result.values.should eq([1, 2, 3])
  end

  it "reports the failing element when a variadic element fails to convert" do
    error = VariadicTyped.parse(["1", "potato", "3"]).as(Kebab::Error::InvalidValue)
    error.value.should eq("potato")
    case source = error.source
    in Kebab::Schema::Argument then source.name.should eq("values")
    in Kebab::Schema::Option   then fail "expected argument source"
    end
  end

  it "shows the variadic tail in the usage line and arguments section" do
    help = VariadicRequired.parse(["--help"]).as(Kebab::Help).text
    help.should contain("<output> <files>...")
    help.should contain("<files>...")
  end

  it "renders <name>... in the Arguments section" do
    error = VariadicRequired.parse(["out"]).as(Kebab::Error::MissingArgument)
    error.to_s.should contain("<files>...")
  end

  it "applies the converter to each variadic element" do
    result = VariadicWithConverter.parse(["1", "2", "3"]).as(VariadicWithConverter)
    result.values.should eq([2, 4, 6])
  end

  it "reports the failing element when a variadic-with-converter element fails" do
    error = VariadicWithConverter.parse(["1", "potato", "3"]).as(Kebab::Error::InvalidValue)
    error.value.should eq("potato")
    error.target_name.should eq("doubled int")
  end
end

private struct HandlerSpecLeaf
  include Kebab::Parseable

  @[Kebab::Option]
  getter weeks : Int32 = 4

  def self.on_parse_error(error : Kebab::Errors, stderr : IO) : Bool
    case error
    when Kebab::Error::InvalidValue::Of(Int32)
      stderr.puts("custom: bad int")
      true
    else
      false
    end
  end
end

@[Kebab::Command(name: "parent")]
private struct HandlerSpecParent
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : HandlerSpecLeaf
end

describe "Kebab::Parseable in-command error handlers" do
  it "routes errors to the responsible command's on_parse_error" do
    stderr = IO::Memory.new
    result = HandlerSpecParent.run(["handler_spec_leaf", "--weeks", "potato"], stderr: stderr)
    result.should be_false
    stderr.to_s.should eq("custom: bad int\n")
  end

  it "falls back to default rendering when handler returns false" do
    stderr = IO::Memory.new
    HandlerSpecParent.run(["handler_spec_leaf", "--bogus"], stderr: stderr)
    stderr.to_s.should contain("isn't a recognised option")
  end
end

describe Kebab::Convert::Enum do
  it "parses a matching enum value (case-insensitive)" do
    EnumHaver.parse(["--format", "json"]).as(EnumHaver).format.should eq(SpecOutputFormat::Json)
    EnumHaver.parse(["--format", "YAML"]).as(EnumHaver).format.should eq(SpecOutputFormat::Yaml)
  end

  it "uses the default when not given" do
    EnumHaver.parse([] of String).as(EnumHaver).format.should eq(SpecOutputFormat::Text)
  end

  it "uses the leaf's on_parse_error handler when running via Type.run" do
    EnumHaver.parse(["--format", "xml"]).as(Kebab::Error::InvalidValue::Of(SpecOutputFormat))
  end

  it "errors with the valid names when unrecognised" do
    error = EnumHaver.parse(["--format", "xml"]).as(Kebab::Error::InvalidValue)
    error.reason.should eq("one of: json, yaml, text")
    error.value.should eq("xml")
    error.target_type_name.should eq("SpecOutputFormat")
    case source = error.source
    in Kebab::Schema::Option   then source.long.should eq("format")
    in Kebab::Schema::Argument then fail "expected option source"
    end
    error.should be_a(Kebab::Error::InvalidValue::Of(SpecOutputFormat))
  end
end

record SelfRunContext, log : Array(String)

private struct SelfRunLeaf
  include Kebab::Parseable

  @[Kebab::Option(short: 'v')]
  getter? verbose : Bool = false

  def run(context : SelfRunContext) : Nil
    context.log << "ran verbose=#{verbose?}"
  end
end

@[Kebab::Command(name: "parent")]
private struct SelfRunParent
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : SelfRunLeaf
end

describe "Kebab::Parseable.run (class-level)" do
  it "dispatches to the leaf's run when parsing succeeds" do
    ctx = SelfRunContext.new(log: [] of String)
    result = SelfRunLeaf.run(["-v"], ctx)
    result.should be_true
    ctx.log.should eq(["ran verbose=true"])
  end

  it "forwards through a subcommand parent to the leaf" do
    ctx = SelfRunContext.new(log: [] of String)
    SelfRunParent.run(["self_run_leaf", "-v"], ctx)
    ctx.log.should eq(["ran verbose=true"])
  end

  it "writes help to the provided stdout and returns true" do
    stdout = IO::Memory.new
    SelfRunLeaf.run(["--help"], SelfRunContext.new(log: [] of String), stdout: stdout).should be_true
    stdout.to_s.should contain("Usage: self_run_leaf")
  end

  it "writes errors to the provided stderr and returns false" do
    stderr = IO::Memory.new
    SelfRunLeaf.run(["--bogus"], SelfRunContext.new(log: [] of String), stderr: stderr).should be_false
    stderr.to_s.should contain("isn't a recognised option")
  end

  it "forwards multiple positional args to the leaf's run" do
    log = [] of String
    SelfRunMultiArg.run([] of String, log, "tag")
    log.should eq(["ran:tag"])
  end

  it "forwards keyword args to the leaf's run" do
    log = [] of String
    SelfRunKwarg.run([] of String, log, label: "kw")
    log.should eq(["ran:kw"])
  end
end

private struct SelfRunMultiArg
  include Kebab::Parseable

  def run(log : Array(String), tag : String) : Nil
    log << "ran:#{tag}"
  end
end

private struct SelfRunKwarg
  include Kebab::Parseable

  def run(log : Array(String), *, label : String) : Nil
    log << "ran:#{label}"
  end
end
