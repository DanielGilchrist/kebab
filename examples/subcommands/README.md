# Subcommands

A parent command dispatches to one of several child commands via `@[Kebab::Subcommand]`. The parent type is a union of the children.

## Run it

```sh
crystal run main.cr -- add "buy milk"
crystal run main.cr -- list
crystal run main.cr -- list --all
crystal run main.cr -- --help
crystal run main.cr -- add --help
crystal run main.cr -- bogus
```

## What to look at

The parent's subcommand field is a union type of commands:

```crystal
@[Kebab::Subcommand]
getter command : Add | List
```

Kebab generates the dispatch from the union. The CLI command name for each child is the underscored struct name (`add`, `list`) unless overridden with `@[Kebab::Command(name: "...")]`.

When you call `Tasks.run(ARGV)` kebab walks the tree: parses the parent, picks the child by name, parses its args, calls the child's `run`. Help and errors at every level show the full command path (`tasks add`, `tasks list`, etc).

## Signature consistency

Subcommand parents auto-forward args to their chosen child. So `Tasks.run(ARGV, context)` flows through to `Add.run(context)` or `List.run(context)`. All children under the same parent must accept the same signature.
