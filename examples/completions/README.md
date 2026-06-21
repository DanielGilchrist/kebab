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

The shell is a typed argument: `getter shell : Kebab::Completion::Shell`, parsed with `Kebab::Convert::Enum`. An unknown shell fails at parse time with `one of: fish, bash, zsh`, so there is no string matching to write. The parsed command is handled in the `case`:

```crystal
in Completions then puts sub.shell.generate(Todo.schema)
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

## Adding a shell kebab doesn't ship

A generator is any type with `generate(command : Kebab::Schema::Command, binary : String? = nil) : String`. Write one, then dispatch to it from your own shell enum alongside the built-ins:

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
    in Fish then Kebab::Completion::Shell::Fish.generate(command, binary)
    in Nu   then Nushell.generate(command, binary)
    end
  end
end
```

Then use `AppShell` as the argument type instead of `Kebab::Completion::Shell`.
