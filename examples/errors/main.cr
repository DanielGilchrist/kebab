require "../../src/kebab"

enum OutputFormat
  Json
  Yaml
  Text
end

@[Kebab::Command(summary: "Run a query")]
struct Query
  include Kebab::Parseable

  @[Kebab::Argument(description: "Query text")]
  getter text : String

  @[Kebab::Option(short: 'f', description: "Output format", converter: Kebab::Convert::Enum(OutputFormat))]
  getter format : OutputFormat = OutputFormat::Text

  @[Kebab::Option(short: 'l', description: "Result limit (1-1000)")]
  getter limit : Int32 = 10
end

case result = Query.parse(ARGV)
in Query
  puts "Running '#{result.text}' (format=#{result.format}, limit=#{result.limit})"
in Kebab::Help
  puts result
in Kebab::Errors
  case result
  when Kebab::Error::InvalidValue::Of(OutputFormat)
    STDERR.puts "format must be one of: #{OutputFormat.names.map(&.downcase).join(", ")}"
  when Kebab::Error::InvalidValue::Of(Int32)
    STDERR.puts "--limit must be a whole number between 1 and 1000"
  else
    STDERR.puts result
  end
  exit(1)
end
