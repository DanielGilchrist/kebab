require "../../src/kebab"

enum OutputFormat
  Json
  Yaml
  Text
end

@[Kebab::Command(summary: "Run a query")]
struct Query
  include Kebab::Parseable

  def self.on_parse_error(error : Kebab::Errors, stderr : IO) : Bool
    case error
    when Kebab::Error::InvalidValue::Of(OutputFormat)
      stderr.puts "format must be one of: #{OutputFormat.names.map(&.downcase).join(", ")}"
      true
    when Kebab::Error::InvalidValue::Of(Int32)
      stderr.puts "--limit must be a whole number between 1 and 1000"
      true
    else
      false
    end
  end

  @[Kebab::Argument(description: "Query text")]
  getter text : String

  @[Kebab::Option(short: 'f', description: "Output format", converter: Kebab::Convert::Enum(OutputFormat))]
  getter format : OutputFormat = OutputFormat::Text

  @[Kebab::Option(short: 'l', description: "Result limit (1-1000)")]
  getter limit : Int32 = 10

  def run : Nil
    puts "Running '#{text}' (format=#{format}, limit=#{limit})"
  end
end

exit(1) unless Query.run(ARGV)
