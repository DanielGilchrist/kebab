require "./spec_helper"

describe Kebab::Scanner do
  it "scans long options" do
    Kebab::Scanner.scan("--at").should eq(Kebab::Tokens::Long.new("at"))
  end

  it "scans long options with inline values" do
    Kebab::Scanner.scan("--at=8:45").should eq(Kebab::Tokens::Long.new("at", "8:45"))
  end

  it "scans long options with empty inline values" do
    Kebab::Scanner.scan("--at=").should eq(Kebab::Tokens::Long.new("at", ""))
  end

  it "scans kebab-cased long options" do
    Kebab::Scanner.scan("--skip-validations").should eq(Kebab::Tokens::Long.new("skip-validations"))
  end

  it "scans short options" do
    Kebab::Scanner.scan("-a").should eq(Kebab::Tokens::Shorts.new("a"))
  end

  it "scans short option clusters" do
    Kebab::Scanner.scan("-abc").should eq(Kebab::Tokens::Shorts.new("abc"))
  end

  it "scans short options with inline values" do
    Kebab::Scanner.scan("-a=8:45").should eq(Kebab::Tokens::Shorts.new("a", "8:45"))
  end

  it "scans positionals" do
    Kebab::Scanner.scan("start").should eq(Kebab::Tokens::Positional.new("start"))
  end

  it "scans a lone dash as a positional" do
    Kebab::Scanner.scan("-").should eq(Kebab::Tokens::Positional.new("-"))
  end

  it "scans an empty string as a positional" do
    Kebab::Scanner.scan("").should eq(Kebab::Tokens::Positional.new(""))
  end

  it "scans the separator" do
    Kebab::Scanner.scan("--").should eq(Kebab::Tokens::Separator.new)
  end

  it "preserves equals signs after the first in inline values" do
    Kebab::Scanner.scan("--query=a=b").should eq(Kebab::Tokens::Long.new("query", "a=b"))
  end
end
