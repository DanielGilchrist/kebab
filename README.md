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

# Greet.parse : Greet | Kebab::Help | Kebab::Errors  (args default to ARGV)
case result = Greet.parse
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

## Field types and conversion

A field's type sets how its value parses:

- `String` and the number types (`Int32`, `Float64`, and the other int/float widths) are built in.
- `Bool` is a flag, never a value.
- Enums parse automatically. Matching is case-insensitive and treats `-` and `_` the same. An unknown value errors with the valid names.
- `Array(T)` makes an option repeatable: `--tag a --tag b` collects both, each parsed as `T`. As the last positional argument it collects the remaining positionals instead.
- `Tuple(A, B)` takes a fixed group of values in one occurrence (`--range 1 10`), each position parsed as its own type. `Array(Tuple(A, B))` repeats the group, and as arguments both consume that many positionals.

`arity:` sets how many values one occurrence takes. `arity: 2` on an `Array(T)`
option consumes two per occurrence, flattened into the array. A range
(`arity: 1..`) consumes until the next option, allowed only where nothing can
be swallowed: commands with no positional arguments or subcommand, and never
`global:`. `value_names:` names the placeholders in help, so
`value_names: {"min", "max"}` renders `--range <min> <max>`.

Other types need a `converter:`, a type or module with `self.convert(input : String) : T | Kebab::Convert::Failure`:

```crystal
struct Duration
  getter minutes : Int32

  def initialize(@minutes : Int32)
  end

  def self.convert(input : String) : Duration | Kebab::Convert::Failure
    minutes = input.to_i?
    return Kebab::Convert.failure("expected a number of minutes") unless minutes
    new(minutes)
  end
end

@[Kebab::Option(converter: Duration)]
getter pause : Duration?
```

Passing a scalar option twice is an error. To repeat into something other than an
array, give the converter a `collect`: each occurrence goes through `convert`,
then the results go through `collect` once to build the field.

```crystal
module Tags
  def self.convert(input : String) : String | Kebab::Convert::Failure
    input
  end

  def self.collect(values : Array(String)) : Set(String) | Kebab::Convert::Failure
    set = values.to_set
    return Kebab::Convert.failure("duplicate tags") if set.size != values.size
    set
  end
end

@[Kebab::Option(converter: Tags)]
getter tags : Set(String) = Set(String).new
```

On an `Array(T)` field the converter may instead return `Array(T)`, yielding
several elements from one value, so a comma-splitting converter turns
`--tag a,b --tag c` into all three. A converter with `collect` also works on
the last positional argument, folding the remaining positionals.

A `collect` failure is a `Kebab::Error::InvalidCollection` carrying every raw
value. An unsupported type with no `converter:` is a compile error.

## Examples

Runnable walkthroughs in [`examples/`](examples/):

- [`examples/parsing/`](examples/parsing/): kebab as a pure parser, no `def run`.
- [`examples/command/`](examples/command/): single-command pattern with `Type.run`.
- [`examples/subcommands/`](examples/subcommands/): multi-level command tree.
- [`examples/errors/`](examples/errors/): typed error dispatch in parsing mode.
- [`examples/suggestions/`](examples/suggestions/): in-command error handlers with "did you mean" hints.
- [`examples/completions/`](examples/completions/): generating fish, bash, and zsh completions.
- [`examples/global/`](examples/global/): options usable anywhere in a command's subtree with `global: true`.
- [`examples/collections/`](examples/collections/): repeated options, value groups, and variadic arity.
- [`examples/testing/`](examples/testing/): testing commands with parse, injected dependencies, and captured IO.

## Global options

By default an option is only recognised before its command's subcommand
(`app --verbose start`, not `app start --verbose`). Mark it `global: true` to
accept it anywhere in that command's portion of the line, including after
subcommands:

```crystal
struct App
  include Kebab::Parseable

  @[Kebab::Option(global: true)]
  getter? no_colour : Bool = false

  @[Kebab::Subcommand]
  getter command : Start | Finish
end

# all set no_colour? on the App instance:
App.parse(["--no-colour", "start"])
App.parse(["start", "--no-colour"])
```

The value lives on the declaring command's instance, so in command mode read it
there and thread it into the subcommand's `run` like any other dependency. A
global is also listed in its subcommands' help and completion, since it's usable
there too.

Collection stops at `--`. A global is recognised throughout its declaring
command's subtree, so a descendant can't reuse its name or short letter. That's
a compile error, not a silent shadow. See [`examples/global/`](examples/global/).

## Shell completion

`Kebab::Completion::Shell` generates completion scripts for fish, bash, and
zsh. Expose it as a subcommand with a typed shell argument:

```crystal
@[Kebab::Command(summary: "Print a shell completion script")]
struct Completions
  include Kebab::Parseable

  @[Kebab::Argument]
  getter shell : Kebab::Completion::Shell

  def run : Nil
    puts shell.generate(Todo.schema)
  end
end
```

An unknown shell is a parse error listing the valid ones. Source the script at
shell startup so it tracks the current binary:

```sh
todo completions fish | source          # fish
eval "$(todo completions bash)"         # bash, in ~/.bashrc
source <(todo completions zsh)          # zsh, in ~/.zshrc after compinit
```

A completion script is built from `Type.schema`, so for any other shell you
generate the script yourself. See
[`examples/completions/`](examples/completions/).

## Command structure

`Type.schema` returns the command and its subcommands as a
`Kebab::Schema::Command` (options, arguments, subcommands, usage). It drives
help and completion, is carried on every parse error as `error.schema`, and you
can walk it for your own tooling.

## Colour

Help and error output is colourised through Crystal's `Colorize`, which
disables itself when the output is not a TTY. To force it off (for example in a host program that handles its own colour), set `Colorize.enabled = false` before calling `parse` or `run`.

## API docs

Generate them with `crystal docs` from the repo root.
