# Subcommands

A parent command dispatches to one of several child commands via `@[Kebab::Subcommand]`. The parent's subcommand field is a union of the children.

## Run it

```sh
crystal run main.cr -- add "buy milk"
crystal run main.cr -- list
crystal run main.cr -- list --all
crystal run main.cr -- --help
crystal run main.cr -- add --help
crystal run main.cr -- bogus
```

## How it works

The parent declares its children as a union:

```crystal
@[Kebab::Subcommand]
getter command : Add | List
```

The CLI name for each child is the underscored struct name (`add`, `list`) unless overridden with `@[Kebab::Command(name: "...")]`.

`Tasks.parse` returns `Tasks | Kebab::Help | Kebab::Errors`. On success you get the parent, never a child. The chosen child is data on the instance, in `result.command`, typed `Add | List`. So you match in two levels: first the parse result, then the subcommand.

```crystal
case result = Tasks.parse
in Tasks
  case sub = result.command
  in Add  then # ...
  in List then # ...
  end
in Kebab::Help   then # ...
in Kebab::Errors then # ...
end
```

## Exhaustiveness

`result.command` is a real Crystal union, so the inner `case ... in` is checked at compile time. Drop a child and the compiler names it:

```
Error: case is not exhaustive.

Missing types:
 - List
```

Handle some children with `when` and leave an `else`, and `else` sees whatever is left. After `when Add` here that leaves `List`. With more children it would be their union. This is plain Crystal flow typing over the union, nothing kebab-specific.

## Running children directly

Children carry data here, not behaviour. To make each child own its logic, give it a `def run` and dispatch with `Tasks.run(ARGV)`. See [`../command/`](../command/) for the run pattern.
