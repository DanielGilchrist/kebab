require "./spec_helper"

@[Kebab::Command(name: "start", summary: "Clock in")]
struct HelpSpecStart
  include Kebab::Parseable

  @[Kebab::Option(short: 'a', description: "Clock in at a past time")]
  getter at : String?

  @[Kebab::Option(short: 's', description: "Skip clock in validations")]
  getter? skip_validations : Bool = false
end

@[Kebab::Command(name: "finish", summary: "Clock out")]
struct HelpSpecFinish
  include Kebab::Parseable

  getter at : String?
end

@[Kebab::Command(name: "clockin", summary: "Clock in/out")]
struct HelpSpecClock
  include Kebab::Parseable

  @[Kebab::Option(description: "Noisy output")]
  getter? verbose : Bool = false

  @[Kebab::Subcommand]
  getter command : HelpSpecStart | HelpSpecFinish
end

@[Kebab::Command(name: "trim", summary: "Trim a file")]
struct HelpSpecTrim
  include Kebab::Parseable

  @[Kebab::Argument(description: "File to trim")]
  getter path : String

  @[Kebab::Argument(name: "limit", description: "Max lines to keep")]
  getter limit : Int32 = 10
end

private def help_for(result) : String
  case result
  when Kebab::Help
    result.text
  else
    fail "expected Kebab::Help, got #{result.class}: #{result.inspect}"
  end
end

describe "Kebab::Parseable help" do
  it "renders options, commands, and the summary for --help" do
    help_for(HelpSpecClock.parse(["--help"])).should eq(<<-HELP
      Clock in/out

      Usage: clockin [options] <command>

      Commands:
        finish  Clock out
        start   Clock in
        help    Show this help

      Options:
            --verbose  Noisy output
        -h, --help     Show this help

      HELP
    )
  end

  it "renders short options and value placeholders for -h" do
    help_for(HelpSpecStart.parse(["-h"])).should eq(<<-HELP
      Clock in

      Usage: start [options]

      Options:
        -a, --at <value>        Clock in at a past time
        -s, --skip-validations  Skip clock in validations
        -h, --help              Show this help

      HELP
    )
  end

  it "renders positional arguments in usage and sections" do
    help_for(HelpSpecTrim.parse(["--help"])).should eq(<<-HELP
      Trim a file

      Usage: trim [options] <path> <limit>

      Arguments:
        <path>   File to trim
        <limit>  Max lines to keep

      Options:
        -h, --help  Show this help

      HELP
    )
  end

  it "shows the subcommand's help for `command sub --help` with the full path" do
    result = HelpSpecClock.parse(["start", "--help"])
    help_for(result).should contain("Usage: clockin start [options]")
  end

  it "takes priority over unknown option errors at the point reached" do
    HelpSpecClock.parse(["--help", "--nope"]).should be_a(Kebab::Help)
  end
end
