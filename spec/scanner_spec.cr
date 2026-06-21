require "./spec_helper"

describe Kebab::Internal::Scanner do
  it "scans long options" do
    Kebab::Internal::Scanner.scan("--at").should eq(Kebab::Internal::Tokens::Long.new("at"))
  end

  it "scans long options with inline values" do
    Kebab::Internal::Scanner.scan("--at=8:45").should eq(Kebab::Internal::Tokens::Long.new("at", "8:45"))
  end

  it "scans long options with empty inline values" do
    Kebab::Internal::Scanner.scan("--at=").should eq(Kebab::Internal::Tokens::Long.new("at", ""))
  end

  it "scans kebab-cased long options" do
    Kebab::Internal::Scanner.scan("--skip-validations").should eq(Kebab::Internal::Tokens::Long.new("skip-validations"))
  end

  it "scans short options" do
    Kebab::Internal::Scanner.scan("-a").should eq(Kebab::Internal::Tokens::Shorts.new("a"))
  end

  it "scans short option clusters" do
    Kebab::Internal::Scanner.scan("-abc").should eq(Kebab::Internal::Tokens::Shorts.new("abc"))
  end

  it "scans short options with inline values" do
    Kebab::Internal::Scanner.scan("-a=8:45").should eq(Kebab::Internal::Tokens::Shorts.new("a", "8:45"))
  end

  it "scans positionals" do
    Kebab::Internal::Scanner.scan("start").should eq(Kebab::Internal::Tokens::Positional.new("start"))
  end

  it "scans a lone dash as a positional" do
    Kebab::Internal::Scanner.scan("-").should eq(Kebab::Internal::Tokens::Positional.new("-"))
  end

  it "scans an empty string as a positional" do
    Kebab::Internal::Scanner.scan("").should eq(Kebab::Internal::Tokens::Positional.new(""))
  end

  it "scans the separator" do
    Kebab::Internal::Scanner.scan("--").should eq(Kebab::Internal::Tokens::Separator.new)
  end

  it "preserves equals signs after the first in inline values" do
    Kebab::Internal::Scanner.scan("--query=a=b").should eq(Kebab::Internal::Tokens::Long.new("query", "a=b"))
  end
end
