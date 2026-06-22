# Testing

Commands are plain structs, so tests just call `parse`/`run` and assert. No process spawning.

## Run it

```sh
crystal spec cli_spec.cr
```

## How it works

### Parsing returns a value to assert on

`parse` hands back the typed struct or a typed error:

```crystal
Greet.parse(["kebab", "--loud"]).as(Greet).loud?.should be_true
Greet.parse([] of String).should be_a(Kebab::Error::MissingArgument)
```

### Inject dependencies through run

`run` takes whatever you pass after the args. Here it's a `Context` holding an output `IO`, so a test passes a fake and asserts on what was written:

```crystal
output = IO::Memory.new
Greet.run(["kebab", "--loud"], Context.new(output))
output.to_s.chomp.should eq("HELLO, KEBAB!")
```

### Capture help and errors

`run` writes help to `stdout:` and errors to `stderr:`. Pass `IO::Memory` to capture them:

```crystal
output = IO::Memory.new
Greet.run(["--help"], Context.new(IO::Memory.new), stdout: output)
output.to_s.should contain("Usage:")
```
