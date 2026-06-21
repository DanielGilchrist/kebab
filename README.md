# Kebab

WIP. Public API is subject to change.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  kebab:
    github: DanielGilchrist/kebab
```

Then run `shards install`.

## Quick example

Annotate a struct, then parse `ARGV` into it:

```crystal
require "kebab"

@[Kebab::Command(summary: "Greet someone")]
struct Greet
  include Kebab::Parseable

  @[Kebab::Argument(description: "Name to greet")]
  getter name : String

  @[Kebab::Option(short: 'l', description: "Make it loud")]
  getter? loud : Bool = false
end

# Greet.parse(ARGV) : Greet | Kebab::Help | Kebab::Errors
case result = Greet.parse(ARGV)
in Greet
  message = "Hello, #{result.name}!"
  message = message.upcase if result.loud?
  puts message
in Kebab::Help
  puts result        # the user passed --help
in Kebab::Errors
  STDERR.puts result # parsing failed
  exit(1)
end
```

`parse` never raises. It returns one of exactly three things: the parsed
struct, a `Kebab::Help` when `--help` was asked for, or a `Kebab::Errors` when
the input was invalid. Crystal's `case ... in` makes you handle all three.

## Commands that carry behaviour

When a command should own its logic, give it a `def run` and dispatch with
`Type.run`. It parses, calls `run` on success, prints help to `stdout` and
errors to `stderr`, and returns a `Bool`:

```crystal
@[Kebab::Command(summary: "Greet someone")]
struct Greet
  include Kebab::Parseable

  @[Kebab::Argument(description: "Name to greet")]
  getter name : String

  @[Kebab::Option(short: 'l', description: "Make it loud")]
  getter? loud : Bool = false

  def run : Nil
    message = "Hello, #{name}!"
    message = message.upcase if loud?
    puts message
  end
end

exit(1) unless Greet.run(ARGV)
```

## Examples

Runnable walkthroughs in [`examples/`](examples/):

- [`examples/parsing/`](examples/parsing/) — kebab as a pure parser, no `def run`.
- [`examples/command/`](examples/command/) — single-command pattern with `Type.run`.
- [`examples/subcommands/`](examples/subcommands/) — multi-level command tree.
- [`examples/errors/`](examples/errors/) — typed error dispatch in parsing mode.
- [`examples/suggestions/`](examples/suggestions/) — in-command error handlers with "did you mean" hints.
- [`examples/completions/`](examples/completions/) — generating a fish completion script.

## Shell completion

`Type.completion_fish("binary-name")` returns a fish completion script derived
from the command tree, covering subcommands, options, and their descriptions:

```crystal
puts Todo.completion_fish("todo")
```

How you expose it is up to you (a hidden subcommand, a flag, a separate
binary). Save the output where fish looks for completions:

```sh
todo completions fish > ~/.config/fish/completions/todo.fish
```

## Inspecting the command tree

Both completion and help are generated from one representation,
`Type.schema`, which returns the whole tree as an immutable
`Kebab::Schema::Command` (options, arguments, subcommands, usage). It is the
same value carried on every parse error as `error.schema`, and you can walk it
yourself to drive your own tooling.

## Colour

Help and error output is colourised through Crystal's `Colorize`, which
disables itself when the output is not a TTY. To force it off (for example in a host program that handles its own colour), set `Colorize.enabled = false` before calling `parse` or `run`.

## API docs

Generate them with `crystal docs` from the repo root.
