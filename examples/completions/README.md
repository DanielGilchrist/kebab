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

## Other shells

`Kebab::Completion::Shell` is a convenience for the shells kebab ships. You are not tied to it. `Todo.schema` is the public input a completion script is built from, so a shell kebab doesn't cover is just a script you build from that:

```crystal
script = generate_xonsh(Todo.schema)  # walk command.subcommands and command.options
```

Wire it up however suits you. If you want kebab's built-ins in the same command, `Kebab::Completion::Shell::Fish.generate(Todo.schema)` (and `Bash`/`Zsh`) are there to reuse.
