require "./spec_helper"

struct SpecDuration
  def self.convert(input : String) : self | Kebab::Convert::Failure
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
  def self.convert(input : String) : String | Kebab::Convert::Failure
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

  @[Kebab::Option(long: "duration", converter: SpecDuration)]
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

module StrictTagSet
  def self.convert(input : String) : String | Kebab::Convert::Failure
    input
  end

  def self.collect(values : Array(String)) : Set(String) | Kebab::Convert::Failure
    set = values.to_set
    return Kebab::Convert.failure("duplicate tags", name: "tags") if set.size != values.size
    set
  end
end

module SpecSetConverter(T)
  def self.convert(input : String) : T | Kebab::Convert::Failure
    Kebab::Convert.convert(T, input)
  end

  def self.collect(values : Array(T)) : Set(T) | Kebab::Convert::Failure
    values.to_set
  end
end

module SumConverter
  def self.convert(input : String) : Int32 | Kebab::Convert::Failure
    Kebab::Convert.convert(Int32, input)
  end

  def self.collect(values : Array(Int32)) : Int32 | Kebab::Convert::Failure
    values.sum
  end
end

private struct Repeater
  include Kebab::Parseable

  @[Kebab::Option]
  getter tag : Array(String) = [] of String

  @[Kebab::Option(short: 'n')]
  getter num : Array(Int32) = [] of Int32

  @[Kebab::Option(converter: VariadicDoubler)]
  getter doubled : Array(Int32) = [] of Int32

  @[Kebab::Option]
  getter maybe : Array(String)?
end

private struct RequiredRepeat
  include Kebab::Parseable

  @[Kebab::Option]
  getter tag : Array(String)
end

module ExactlyTwo
  def self.convert(input : String) : String | Kebab::Convert::Failure
    input
  end

  def self.collect(values : Array(String)) : Set(String) | Kebab::Convert::Failure
    return Kebab::Convert.failure if values.size != 2
    values.to_set
  end
end

private struct PairHaver
  include Kebab::Parseable

  @[Kebab::Option(converter: ExactlyTwo)]
  getter pair : Set(String) = Set(String).new
end

private struct SetHaver
  include Kebab::Parseable

  @[Kebab::Option(converter: StrictTagSet)]
  getter tags : Set(String) = Set(String).new

  @[Kebab::Option(converter: SpecSetConverter(Int32))]
  getter ids : Set(Int32) = Set(Int32).new

  @[Kebab::Option(converter: SumConverter)]
  getter total : Int32 = 0
end

module ExtendSelfConverter
  extend self

  def convert(input : String) : Int32 | Kebab::Convert::Failure
    input.to_i * 2
  end
end

private struct ExtendSelfHaver
  include Kebab::Parseable

  @[Kebab::Option(converter: ExtendSelfConverter)]
  getter doubled : Int32?
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

  it "takes an attached value on a short option" do
    parse_punch!(["-a8:45"]).at.should eq("8:45")
    parse_punch!(["-a=8:45"]).at.should eq("8:45")
    parse_punch!(["-a", "8:45"]).at.should eq("8:45")
  end

  it "keeps an equals sign inside an attached short value" do
    parse_punch!(["-afoo=bar"]).at.should eq("foo=bar")
    parse_punch!(["-safoo=bar"]).at.should eq("foo=bar")
  end

  it "ends a cluster at the first valued short and takes the rest as its value" do
    punch = parse_punch!(["-sa8:45"])
    punch.skip_validations?.should be_true
    punch.at.should eq("8:45")

    # `a` is valued, so `-as` reads `s` as its value rather than a second flag.
    parse_punch!(["-as"]).at.should eq("s")
  end

  it "takes an attached negative value on a short option" do
    parse_punch!(["-a-3"]).at.should eq("-3")
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

  it "reports the raw token for a malformed short like -=foo" do
    error = parse_punch_error!(["-=foo"])
    error.should be_a(Kebab::Error::UnknownOption)
    error.message.should eq("\"-=foo\" isn't a recognised option.")
  end

  it "errors when an option value looks like another option" do
    error = parse_punch_error!(["--at", "--verbose"])
    error.should be_a(Kebab::Error::MissingValue)
  end

  it "lets a declared digit short win over negative-looking tokens" do
    DigitShort.parse(["-1"]).as(DigitShort).one?.should be_true
    DigitShort.parse(["-5"]).should be_a(Kebab::Error::UnknownOption)
    DigitShort.parse(["--", "-5"]).as(DigitShort).offset.should eq(-5)
  end

  it "parses multi-digit and decimal negative positionals" do
    NegativeArgs.parse(["-19", "-1.5"]).as(NegativeArgs).offset.should eq(-19)
    NegativeArgs.parse(["-19", "-1.5"]).as(NegativeArgs).scales.should eq([-1.5])
  end

  it "lets the field judge a dash-digit token that isn't a clean number" do
    error = NegativeArgs.parse(["-5abc"]).as(Kebab::Error::InvalidValue)
    error.value.should eq("-5abc")
    NegativeText.parse(["-5abc"]).as(NegativeText).text.should eq("-5abc")
  end

  it "keeps a letter short unknown even when a String positional could take it" do
    NegativeText.parse(["-x"]).should be_a(Kebab::Error::UnknownOption)
  end

  it "parses scientific notation through a float field" do
    NegativeArgs.parse(["-19", "-1e5"]).as(NegativeArgs).scales.should eq([-100_000.0])
  end

  it "reports a malformed negative decimal through the field" do
    error = NegativeArgs.parse(["-19", "-1.2.3"]).as(Kebab::Error::InvalidValue)
    error.value.should eq("-1.2.3")
  end

  it "passes a bare dash through as a positional" do
    NegativeText.parse(["-"]).as(NegativeText).text.should eq("-")
  end

  it "keeps a dash-dot without a digit as an option" do
    NegativeText.parse(["-."]).should be_a(Kebab::Error::UnknownOption)
  end

  it "keeps a dash-digit long option unknown" do
    NegativeText.parse(["--5"]).should be_a(Kebab::Error::UnknownOption)
  end

  it "treats a digit inside a cluster as a short on a digit-short command" do
    DigitShort.parse(["-19"]).should be_a(Kebab::Error::UnknownOption)
  end

  it "accepts negative numbers as option values regardless of digit shorts" do
    parse_punch!(["--at", "-19"]).at.should eq("-19")
  end

  it "parses negative numbers as positionals" do
    parsed = NegativeArgs.parse(["-5", "-0.5", "-.25"]).as(NegativeArgs)
    parsed.offset.should eq(-5)
    parsed.scales.should eq([-0.5, -0.25])
  end

  it "accepts a negative number as an option value" do
    parse_punch!(["--at", "-3"]).at.should eq("-3")
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

  it "accepts an `extend self` converter" do
    ExtendSelfHaver.parse(["--doubled", "21"]).as(ExtendSelfHaver).doubled.should eq(42)
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

  it "carries the command schema on MissingValue" do
    error = parse_punch_error!(["--at"]).as(Kebab::Error::MissingValue)
    error.schema.options.map(&.long).should contain("at")
    error.schema.path.should eq(["punch"])
    error.to_s.should contain("Usage: punch")
    error.to_s.should contain("Options:")
  end

  it "exposes a Schema::Option on RepeatedOption" do
    error = parse_punch_error!(["--at", "8:45", "--at", "9:30"]).as(Kebab::Error::RepeatedOption)
    error.option.long.should eq("at")
  end

  it "carries the command schema on RepeatedOption" do
    error = parse_punch_error!(["--at", "8:45", "--at", "9:30"]).as(Kebab::Error::RepeatedOption)
    error.schema.options.map(&.long).should contain("at")
    error.schema.path.should eq(["punch"])
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
    error.should be_a(Kebab::Error::InvalidValue::Exact(Int32, Punch))
  end

  it "carries the command schema on InvalidValue" do
    error = parse_punch_error!(["--weeks", "potato"]).as(Kebab::Error::InvalidValue)
    error.schema.path.should eq(["punch"])
    error.schema.options.map(&.long).should contain("weeks")
  end

  it "carries the command schema on UnknownOption" do
    error = parse_punch_error!(["--nope"]).as(Kebab::Error::UnknownOption)
    error.schema.path.should eq(["punch"])
    error.schema.options.map(&.long).should contain("at")
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

enum SpecMultiWord
  RawText
  PrettyJson
end

private struct EnumHaver
  include Kebab::Parseable

  @[Kebab::Option]
  getter format : SpecOutputFormat = SpecOutputFormat::Text
end

private struct MultiWordEnumHaver
  include Kebab::Parseable

  @[Kebab::Option(converter: Kebab::Convert::Enum(SpecMultiWord))]
  getter format : SpecMultiWord = SpecMultiWord::PrettyJson
end

enum SpecCustomEnum
  Json
  Text
end

module AliasedEnumConverter
  def self.convert(input : String) : SpecCustomEnum | Kebab::Convert::Failure
    return SpecCustomEnum::Json if input == "j"
    Kebab::Convert::Enum(SpecCustomEnum).convert(input)
  end
end

private struct CustomEnumHaver
  include Kebab::Parseable

  @[Kebab::Option(converter: AliasedEnumConverter)]
  getter format : SpecCustomEnum = SpecCustomEnum::Text
end

private struct NegativeText
  include Kebab::Parseable

  @[Kebab::Argument]
  getter text : String
end

private struct DigitShort
  include Kebab::Parseable

  @[Kebab::Option(short: '1')]
  getter? one : Bool = false

  @[Kebab::Argument]
  getter offset : Int32 = 0
end

private struct NegativeArgs
  include Kebab::Parseable

  @[Kebab::Argument]
  getter offset : Int32

  @[Kebab::Argument]
  getter scales : Array(Float64) = [] of Float64
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
  def self.convert(input : String) : Int32 | Kebab::Convert::Failure
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

module CommaSplit
  def self.convert(input : String) : Array(String) | Kebab::Convert::Failure
    input.split(',')
  end
end

private struct CommaTags
  include Kebab::Parseable

  @[Kebab::Option(converter: CommaSplit)]
  getter tag : Array(String) = [] of String

  @[Kebab::Argument(converter: CommaSplit)]
  getter extras : Array(String) = [] of String
end

private struct SetTail
  include Kebab::Parseable

  @[Kebab::Argument]
  getter target : String

  @[Kebab::Argument(converter: StrictTagSet)]
  getter tags : Set(String) = Set(String).new
end

private struct MultiValue
  include Kebab::Parseable

  @[Kebab::Option(value_names: {"min", "max"})]
  getter range : Tuple(Int32, Int32) = {0, 0}

  @[Kebab::Option(short: 'p', arity: 2)]
  getter pair : Array(String) = [] of String

  @[Kebab::Option]
  getter points : Array(Tuple(String, Int32)) = [] of Tuple(String, Int32)

  @[Kebab::Option]
  getter at : Tuple(Int32, Int32)?
end

private struct Greedy
  include Kebab::Parseable

  @[Kebab::Option(arity: 2.., value_names: {"file"})]
  getter files : Array(String) = [] of String
end

private struct MoveArgs
  include Kebab::Parseable

  @[Kebab::Argument]
  getter from : Tuple(Int32, Int32)

  @[Kebab::Argument]
  getter waypoints : Array(Tuple(Int32, Int32)) = [] of Tuple(Int32, Int32)
end

describe "multi-value options and arguments" do
  it "parses a tuple option per position" do
    MultiValue.parse(["--range", "1", "10"]).as(MultiValue).range.should eq({1, 10})
  end

  it "reports the failing position when a tuple value doesn't convert" do
    error = MultiValue.parse(["--range", "1", "x"]).as(Kebab::Error::InvalidValue)
    error.value.should eq("x")
  end

  it "keeps a nilable tuple option nil when absent" do
    MultiValue.parse([] of String).as(MultiValue).at.should be_nil
    MultiValue.parse(["--at", "3", "4"]).as(MultiValue).at.should eq({3, 4})
  end

  it "errors when an occurrence is short of values" do
    error = MultiValue.parse(["--range", "1"]).as(Kebab::Error::MissingValue)
    error.message.should eq(%(option "--range" expects 2 values, got 1.))
  end

  it "errors when an occurrence is cut short by a following option" do
    error = MultiValue.parse(["--range", "1", "--pair", "a", "b"]).as(Kebab::Error::MissingValue)
    error.message.should eq(%(option "--range" expects 2 values, got 1.))
  end

  it "errors when a tuple option is repeated" do
    MultiValue.parse(["--range", "1", "2", "--range", "3", "4"]).as(Kebab::Error::RepeatedOption)
  end

  it "rejects inline values on multi-value options" do
    error = MultiValue.parse(["--range=1,10"]).as(Kebab::Error::InvalidValue)
    error.reason.should eq("takes multiple values as separate tokens, not inline")
  end

  it "repeats a tuple-grouped option into pairs" do
    parsed = MultiValue.parse(["--points", "x", "1", "--points", "y", "2"]).as(MultiValue)
    parsed.points.should eq([{"x", 1}, {"y", 2}])
  end

  it "flattens fixed-arity occurrences into the array" do
    MultiValue.parse(["-p", "a", "b", "-p", "c", "d"]).as(MultiValue).pair.should eq(["a", "b", "c", "d"])
  end

  it "rejects an attached value on a multi-value short" do
    error = MultiValue.parse(["-pa"]).as(Kebab::Error::InvalidValue)
    error.reason.should eq("takes multiple values as separate tokens, not inline")
  end

  it "consumes greedily up to the arity minimum with a range" do
    Greedy.parse(["--files", "a", "b", "c"]).as(Greedy).files.should eq(["a", "b", "c"])
    error = Greedy.parse(["--files", "a"]).as(Kebab::Error::MissingValue)
    error.message.should eq(%(option "--files" expects at least 2 values, got 1.))
  end

  it "renders value names and variable tails in help" do
    range_help = MultiValue.parse(["--help"]).as(Kebab::Help).text
    range_help.should contain("--range <min> <max>")
    Greedy.parse(["--help"]).as(Kebab::Help).text.should contain("--files <file>...")
  end

  it "binds tuple arguments and grouped variadic tails" do
    parsed = MoveArgs.parse(["1", "2", "3", "4", "5", "6"]).as(MoveArgs)
    parsed.from.should eq({1, 2})
    parsed.waypoints.should eq([{3, 4}, {5, 6}])
  end

  it "errors on a token that dangles off a grouped tail" do
    error = MoveArgs.parse(["1", "2", "3"]).as(Kebab::Error::UnexpectedArgument)
    error.value.should eq("3")
  end

  it "errors when a tuple argument is partially supplied" do
    MoveArgs.parse(["1"]).should be_a(Kebab::Error::MissingArgument)
  end

  it "advertises tuple argument slots in the usage line" do
    MoveArgs.schema.usage.to_s.should contain("<from> <from> <waypoints> <waypoints>...")
  end
end

describe "whole-collection converters" do
  it "flattens several elements per occurrence into the array" do
    CommaTags.parse(["--tag", "a,b", "--tag", "c"]).as(CommaTags).tag.should eq(["a", "b", "c"])
  end

  it "splits inline values the same way" do
    CommaTags.parse(["--tag=a,b"]).as(CommaTags).tag.should eq(["a", "b"])
  end

  it "splits each variadic positional" do
    CommaTags.parse(["x,y", "z"]).as(CommaTags).extras.should eq(["x", "y", "z"])
  end
end

describe "collect arguments" do
  it "folds the remaining positionals into the field type" do
    parsed = SetTail.parse(["build", "a", "b"]).as(SetTail)
    parsed.target.should eq("build")
    parsed.tags.should eq(Set{"a", "b"})
  end

  it "returns InvalidCollection naming the argument when collect rejects" do
    error = SetTail.parse(["build", "a", "a"]).as(Kebab::Error::InvalidCollection)
    error.values.should eq(["a", "a"])
    error.message.should eq(%("a", "a" aren't valid tags for "<tags>" (duplicate tags)))
  end

  it "uses the default when no positionals remain" do
    SetTail.parse(["build"]).as(SetTail).tags.should be_empty
  end

  it "renders the collect tail as variadic in usage" do
    SetTail.schema.usage.to_s.should contain("<target> <tags>...")
  end
end

describe "repeatable options" do
  it "accumulates values in the order they were given" do
    Repeater.parse(["--tag", "a", "--tag", "b", "--tag", "c"]).as(Repeater).tag.should eq(["a", "b", "c"])
  end

  it "accepts a single occurrence" do
    Repeater.parse(["--tag", "a"]).as(Repeater).tag.should eq(["a"])
  end

  it "converts each occurrence via the element type" do
    Repeater.parse(["-n", "1", "-n", "2"]).as(Repeater).num.should eq([1, 2])
  end

  it "collects attached short values across occurrences" do
    Repeater.parse(["-n1", "-n2"]).as(Repeater).num.should eq([1, 2])
  end

  it "accepts inline values" do
    Repeater.parse(["--tag=a", "--tag=b"]).as(Repeater).tag.should eq(["a", "b"])
  end

  it "applies a converter to each occurrence" do
    Repeater.parse(["--doubled", "2", "--doubled", "3"]).as(Repeater).doubled.should eq([4, 6])
  end

  it "reports the failing occurrence when an element doesn't convert" do
    error = Repeater.parse(["-n", "1", "-n", "potato"]).as(Kebab::Error::InvalidValue)
    error.value.should eq("potato")
  end

  it "uses the default when never given" do
    Repeater.parse([] of String).as(Repeater).num.should eq([] of Int32)
  end

  it "is nil when nilable and never given" do
    Repeater.parse([] of String).as(Repeater).maybe.should be_nil
    Repeater.parse(["--maybe", "x"]).as(Repeater).maybe.should eq(["x"])
  end

  it "errors when required and never given" do
    RequiredRepeat.parse([] of String).should be_a(Kebab::Error::MissingOption)
  end

  it "collects into the field type via the converter's collect" do
    SetHaver.parse(["--tags", "a", "--tags", "b"]).as(SetHaver).tags.should eq(Set{"a", "b"})
  end

  it "phrases a single-value collect failure in the singular" do
    error = PairHaver.parse(["--pair", "a"]).as(Kebab::Error::InvalidCollection)
    error.message.should eq(%("a" isn't a valid value for "--pair"))
  end

  it "falls back to a friendly noun when the converter gives no name" do
    error = PairHaver.parse(["--pair", "a", "--pair", "b", "--pair", "c"]).as(Kebab::Error::InvalidCollection)
    error.message.should eq(%("a", "b", "c" aren't valid values for "--pair"))
  end

  it "returns InvalidCollection when collect rejects the values" do
    error = SetHaver.parse(["--tags", "a", "--tags", "b", "--tags", "a"]).as(Kebab::Error::InvalidCollection)
    error.values.should eq(["a", "b", "a"])
    error.source.as(Kebab::Schema::Option).long.should eq("tags")
    error.reason.should eq("duplicate tags")
    error.message.should eq(%("a", "b", "a" aren't valid tags for "--tags" (duplicate tags)))
  end

  it "narrows InvalidCollection by target type and command" do
    error = SetHaver.parse(["--tags", "a", "--tags", "a"])
    error.should be_a(Kebab::Error::InvalidCollection::Of(Set(String)))
    error.should be_a(Kebab::Error::InvalidCollection::For(SetHaver))
  end

  it "collects through a generic converter" do
    SetHaver.parse(["--ids", "1", "--ids", "2", "--ids", "1"]).as(SetHaver).ids.should eq(Set{1, 2})
  end

  it "folds into a scalar when collect returns one" do
    SetHaver.parse(["--total", "1", "--total", "2", "--total", "3"]).as(SetHaver).total.should eq(6)
  end
end

describe "enum conversion" do
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
    error.reason.should eq("one of: json, text or yaml")
    error.value.should eq("xml")
    error.target_type_name.should eq("SpecOutputFormat")
    error.target_name.should eq("spec output format")
    case source = error.source
    in Kebab::Schema::Option   then source.long.should eq("format")
    in Kebab::Schema::Argument then fail "expected option source"
    end
    error.should be_a(Kebab::Error::InvalidValue::Of(SpecOutputFormat))
  end

  it "parses multi-word members by their underscored name" do
    MultiWordEnumHaver.parse(["--format", "pretty_json"]).as(MultiWordEnumHaver).format.should eq(SpecMultiWord::PrettyJson)
  end

  it "lists multi-word members underscored and sorted when unrecognised" do
    error = MultiWordEnumHaver.parse(["--format", "xml"]).as(Kebab::Error::InvalidValue)
    error.reason.should eq("one of: pretty_json or raw_text")
  end

  it "gives the same result whether the converter is named explicitly or inferred" do
    MultiWordEnumHaver.parse(["--format", "raw_text"]).as(MultiWordEnumHaver).format.should eq(SpecMultiWord::RawText)
  end

  it "customises enum conversion through an explicit converter" do
    CustomEnumHaver.parse(["--format", "j"]).as(CustomEnumHaver).format.should eq(SpecCustomEnum::Json)
    CustomEnumHaver.parse(["--format", "text"]).as(CustomEnumHaver).format.should eq(SpecCustomEnum::Text)
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

private struct DriftGuard
  include Kebab::Parseable

  @[Kebab::Option]
  getter output_dir : String?

  @[Kebab::Argument]
  getter input_file : String?
end

# The schema, parse, and check macros each derive field names independently.
describe "schema and parser agree on derived names" do
  it "advertises the dashed names the parser accepts" do
    schema = DriftGuard.schema
    schema.options.map(&.long).should contain("output-dir")
    schema.arguments.map(&.name).should contain("input-file")

    parsed = DriftGuard.parse(["--output-dir", "build", "main.cr"]).as(DriftGuard)
    parsed.output_dir.should eq("build")
    parsed.input_file.should eq("main.cr")
  end

  it "advertises the same arity the parser enforces" do
    range = MultiValue.schema.options.find! { |option| option.long == "range" }
    range.min_values.should eq(2)
    range.max_values.should eq(2)
    range.value_names.should eq(["min", "max"])

    files = Greedy.schema.options.find! { |option| option.long == "files" }
    files.min_values.should eq(2)
    files.max_values.should be_nil
  end
end
