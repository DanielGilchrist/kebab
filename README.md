# Kebab

WIP. Public API is subject to change.

## Defining a command

```crystal
require "kebab"

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
end
```

## Usage modes

Kebab has three "modes" for different use-cases

### 1. Parse-only (pure parser strategy)

Treat kebab purely as an argument parser. You get back the typed struct (or a `Help` / `Errors` value) and do whatever you want with it.

```crystal
case result = Serve.parse(ARGV)
in Serve
  # result is the parsed struct — use it however you like
  puts "Serving #{result.dir} on http://#{result.bind}:#{result.port}"
in Kebab::Help
  puts result
in Kebab::Errors
  STDERR.puts(result)
  exit(1)
end
```

No `def run` needed on the struct. Good for small CLIs where the command is just data.

### 2. Manual dispatch (hybrid command pattern)

Each command owns its behaviour via `def run(...)`, but you decide when to call it and how to render help/errors. Good when you want the command structure to drive code organisation without giving up control of the IO/exit flow.

```crystal
record Context, stdout : IO, stderr : IO

@[Kebab::Command(summary: "Serve a directory over HTTP")]
struct Serve
  include Kebab::Parseable
  # ... fields as above ...

  def run(context : Context) : Nil
    context.stdout.puts("Serving #{dir} on http://#{bind}:#{port}")
  end
end

context = Context.new(stdout: STDOUT, stderr: STDERR)

case result = Serve.parse(ARGV)
in Serve         then result.run(context)
in Kebab::Help   then context.stdout.puts(result)
in Kebab::Errors then context.stderr.puts(result); exit(1)
end
```

### 3. Auto dispatch (full command pattern)

Let kebab handle everything. `Type.run` parses, then forwards any extra args and kwargs straight through to the `run` defined on the parsed instance. Returns `true` on success or help, `false` on error.

```crystal
struct Serve
  include Kebab::Parseable
  # ... fields ...

  def run : Nil
    puts "Serving #{dir} on http://#{bind}:#{port}"
  end
end

exit(1) unless Serve.run(ARGV)
```

The `stdout:` and `stderr:` keyword args control where kebab writes the help/error output. Override them for tests or to redirect the output:

```crystal
stdout = IO::Memory.new
stderr = IO::Memory.new
Serve.run(["--bogus"], stdout: stdout, stderr: stderr)
stderr.to_s.should contain("isn't a recognised option")
```

Pass anything your `run` needs as a positional or keyword arg. `Type.run` forwards those arguments to the parsed instance:

```crystal
Serve.run(ARGV, context)               # → run(context)
Serve.run(ARGV, context, logger)       # → run(context, logger)
Serve.run(ARGV, db: my_db)             # → run(db: my_db)
```

The only rule is **every `run` in a command tree must share the same signature**. Subcommands forward to their children automatically, so whatever you pass to the top-level `Type.run` has to be accepted all the way down.

## Typed error dispatch

`Kebab::Error::InvalidValueOf(T)` lets you handle conversion failures by target type:

```crystal
case result = Serve.parse(ARGV)
in Kebab::Error::InvalidValue
  case result
  when Kebab::Error::InvalidValueOf(Verbosity)
    context.stderr.puts("Pick one of: #{Verbosity.names.map(&.downcase).join(", ")}")
  else
    context.stderr.puts(result)
  end
in # ... other arms
end
```

## Output

Kebab itself never writes to `STDOUT` or `STDERR` directly. `Kebab::Help`, errors, and the schema types all implement `to_s(io)`. You pick the IO when you `puts(result)`. The auto-dispatch helper (`Type.run`) defaults to `STDOUT`/`STDERR` for convenience but accepts `stdout:`/`stderr:` kwargs to override.
