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

case result = Greet.parse # args default to ARGV
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

When a command owns its logic, give it a `def run` and dispatch with `Type.run`,
which parses, runs on success, and writes help and errors for you.

## Examples

Runnable walkthroughs in [`examples/`](examples/):

- [`examples/parsing/`](examples/parsing/): kebab as a pure parser, no `def run`.
- [`examples/command/`](examples/command/): single-command pattern with `Type.run`.
- [`examples/subcommands/`](examples/subcommands/): multi-level command tree.
- [`examples/errors/`](examples/errors/): typed error dispatch in parsing mode.
- [`examples/suggestions/`](examples/suggestions/): in-command error handlers with "did you mean" hints.
- [`examples/completions/`](examples/completions/): generating fish, bash, and zsh completions.
- [`examples/global/`](examples/global/): options usable anywhere in a command's subtree with `global: true`.
- [`examples/collections/`](examples/collections/): repeated options, value groups, converters, and variadic arity.
- [`examples/testing/`](examples/testing/): testing commands with parse, injected dependencies, and captured IO.

## API docs

Generate them with `crystal docs` from the repo root.