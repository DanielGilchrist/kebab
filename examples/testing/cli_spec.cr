require "spec"
require "./cli"

describe Greet do
  it "parses arguments and options into a typed struct" do
    greet = Greet.parse(["kebab", "--loud"]).as(Greet)
    greet.name.should eq("kebab")
    greet.loud?.should be_true
  end

  it "returns parse failures as typed values, not exceptions" do
    Greet.parse([] of String).should be_a(Kebab::Error::MissingArgument)
  end

  it "runs with an injected dependency so output is capturable" do
    output = IO::Memory.new
    Greet.run(["kebab", "--loud"], Context.new(output))
    output.to_s.chomp.should eq("HELLO, KEBAB!")
  end

  it "writes help to the stdout passed to run" do
    output = IO::Memory.new
    Greet.run(["--help"], Context.new(IO::Memory.new), stdout: output)
    output.to_s.should contain("Usage:")
  end
end
