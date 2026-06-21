# Shell completion

`Type.completion_fish("binary-name")` returns a fish completion script built from the command tree. This example exposes it through a `completions` subcommand.

## Run it

```sh
crystal run main.cr -- completions fish

# the normal CLI still works
crystal run main.cr -- add "buy milk" -p 2
crystal run main.cr -- list --all
```

## How it works

Completion is generated from the same `Type.schema` tree that drives help, so subcommands, options, descriptions, and value-vs-flag status all come through automatically.

`main.cr` handles `completions fish` before normal parsing and prints the script. Kebab hands you the string and you decide how to expose it. A hidden subcommand (shown here), a flag, or a separate binary all work.

The output is standard fish `complete` directives:

- subcommands are offered before one is chosen (`__fish_use_subcommand`)
- each subcommand's options are scoped to it (`__fish_seen_subcommand_from`)
- value options are marked `-r`, boolean flags are not

## Installing it

Save the script where fish looks for completions:

```sh
todo completions fish > ~/.config/fish/completions/todo.fish
```

## Other shells

Only fish is generated for now. The generators are pure functions over the `Kebab::Schema::Command` tree (see `Kebab::Completion`), so a new shell is a new function over the same IR, and you can write your own against `Type.schema`.
