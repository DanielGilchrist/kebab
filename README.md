# Kebab

A type-safe CLI parser for Crystal.

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

```crystal
require "kebab"

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
- [`examples/errors/`](examples/errors/) — typed error dispatch and in-command handlers.

## API docs

Generate them with `crystal docs` from the repo root.
