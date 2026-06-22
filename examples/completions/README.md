# Shell completion

`Kebab::Completion::Shell` generates completion scripts for fish, bash, and zsh. This example exposes them through a `completions <shell>` subcommand.

## Run it

```sh
crystal run main.cr -- completions fish
crystal run main.cr -- completions bash
crystal run main.cr -- completions zsh

# unknown shell is a parse error listing the valid ones
crystal run main.cr -- completions ksh

# the normal CLI works as usual
crystal run main.cr -- add "buy milk" -p 2
crystal run main.cr -- list --all
```

## How it works

The shell is a typed argument: `getter shell : Kebab::Completion::Shell`, parsed with `Kebab::Convert::Enum`. An unknown shell fails at parse time with `one of: fish, bash, zsh`, so there is no string matching to write.

`Todo.parse` returns the parsed command, and the `completions` subcommand is handled like any other:

```crystal
case result = Todo.parse
in Todo
  case sub = result.command
  in Add         then # ...
  in List        then # ...
  in Completions then puts sub.shell.generate(Todo.schema)
  end
in Kebab::Help   then puts result
in Kebab::Errors then STDERR.puts(result)
end
```

`Todo.schema` is the same command structure that drives help, so subcommands, options, and descriptions all come through.

## Installing it

Source it at shell startup so it tracks the current binary (re-run on each launch, never stale):

```sh
# fish
todo completions fish | source

# bash (~/.bashrc)
eval "$(todo completions bash)"

# zsh (~/.zshrc, after compinit)
source <(todo completions zsh)
```

## Other shells

`Kebab::Completion::Shell` is a convenience for the shells kebab ships, not a requirement. A completion script is built from `Todo.schema`, so a shell kebab doesn't cover is just a script you generate from it, wired up however suits you.

If you want the same typed-argument pattern for an extra shell, define your own enum and dispatch to the built-ins plus your own generator:

```crystal
module Nushell
  def self.generate(command : Kebab::Schema::Command, binary : String? = nil) : String
    # walk command.subcommands and command.options
  end
end

enum AppShell
  Fish
  Nu

  def generate(command : Kebab::Schema::Command, binary : String? = nil) : String
    case self
    in Fish then Kebab::Completion::Fish.generate(command, binary)  # reuse a built-in
    in Nu   then Nushell.generate(command, binary)                          # your own
    end
  end
end
```

Then parse it with the same converter, using your enum in place of `Kebab::Completion::Shell`:

```crystal
@[Kebab::Argument(converter: Kebab::Convert::Enum(AppShell))]
getter shell : AppShell
```
