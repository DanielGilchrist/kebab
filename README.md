# Kebab

WIP. Public API is subject to change.

## Usage

```crystal
require "kebab"
require "http/server"

record Context, stdout : IO, stderr : IO

enum Verbosity
  Quiet
  Normal
  Verbose
end

@[Kebab::Command(summary: "Serve a directory over HTTP")]
struct Serve
  include Kebab::Parseable

  @[Kebab::Argument(description: "Directory to serve")]
  getter dir : String = "."

  @[Kebab::Option(short: 'p', description: "Port to listen on")]
  getter port : Int32 = 8000

  @[Kebab::Option(short: 'b', description: "Address to bind to")]
  getter bind : String = "127.0.0.1"

  @[Kebab::Option(short: 'v', description: "Output verbosity", converter: Kebab::Convert::Enum(Verbosity))]
  getter verbosity : Verbosity = Verbosity::Normal

  def run(context : Context) : Nil
    handlers = [] of HTTP::Handler
    handlers << HTTP::LogHandler.new(context.stdout) if verbosity.verbose?
    handlers << HTTP::StaticFileHandler.new(dir)

    server = HTTP::Server.new(handlers)
    server.bind_tcp(bind, port)

    context.stdout.puts("Serving #{dir} on http://#{bind}:#{port}") unless verbosity.quiet?
    server.listen
  end
end

context = Context.new(stdout: STDOUT, stderr: STDERR)

case result = Serve.parse(ARGV)
in Serve
  result.run(context)
in Kebab::Help
  context.stdout.puts(result)
in Kebab::Error::InvalidValue
  case result
  when Kebab::Error::InvalidValueOf(Verbosity)
    context.stderr.puts("Pick one of: #{Verbosity.names.map(&.downcase).join(", ")}")
  else
    context.stderr.puts(result)
  end
  exit(1)
in Kebab::Errors
  context.stderr.puts(result)
  exit(1)
end
```
