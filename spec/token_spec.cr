require "./spec_helper"

describe Kebab::Token do
  it "classifies long options" do
    Kebab::Token.classify("--at").should eq(Kebab::Token::Long.new("at"))
  end

  it "classifies long options with inline values" do
    Kebab::Token.classify("--at=8:45").should eq(Kebab::Token::Long.new("at", "8:45"))
  end

  it "classifies long options with empty inline values" do
    Kebab::Token.classify("--at=").should eq(Kebab::Token::Long.new("at", ""))
  end

  it "classifies kebab-cased long options" do
    Kebab::Token.classify("--skip-validations").should eq(Kebab::Token::Long.new("skip-validations"))
  end

  it "classifies short options" do
    Kebab::Token.classify("-a").should eq(Kebab::Token::Shorts.new("a"))
  end

  it "classifies short option clusters" do
    Kebab::Token.classify("-abc").should eq(Kebab::Token::Shorts.new("abc"))
  end

  it "classifies short options with inline values" do
    Kebab::Token.classify("-a=8:45").should eq(Kebab::Token::Shorts.new("a", "8:45"))
  end

  it "classifies positionals" do
    Kebab::Token.classify("start").should eq(Kebab::Token::Positional.new("start"))
  end

  it "classifies a lone dash as a positional" do
    Kebab::Token.classify("-").should eq(Kebab::Token::Positional.new("-"))
  end

  it "classifies an empty string as a positional" do
    Kebab::Token.classify("").should eq(Kebab::Token::Positional.new(""))
  end

  it "classifies the separator" do
    Kebab::Token.classify("--").should eq(Kebab::Token::Separator.new)
  end

  it "preserves equals signs after the first in inline values" do
    Kebab::Token.classify("--query=a=b").should eq(Kebab::Token::Long.new("query", "a=b"))
  end
end
