require "./spec_helper"

# The code is piped to the compiler over stdin with this file's path as the
# filename, so `require "../src/kebab"` inside it resolves relative to spec/.
# Exclude these subprocess cases from the fast loop with `crystal spec --tag '~compile'`.
private def assert_compile_time_error(message : String, code : String, *, file = __FILE__, line = __LINE__) : Nil
  stderr = IO::Memory.new
  status = Process.run(
    ENV["CRYSTAL"]? || "crystal",
    ["run", "--no-codegen", "--no-color", "--stdin-filename", file],
    input: IO::Memory.new(code),
    error: stderr,
  )
  fail "expected a compile error, but the program compiled", file: file, line: line if status.success?
  stderr.to_s.should contain(message), file: file, line: line
end

describe "compile-time rejections", tags: "compile" do
  it "rejects an option whose type kebab can't convert" do
    assert_compile_time_error "has type `Time`, which kebab can't convert", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        getter at : Time?
      end
      C.parse([] of String)
      CR
  end

  it "rejects an argument whose type kebab can't convert" do
    assert_compile_time_error "has type `Time`, which kebab can't convert", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter at : Time
      end
      C.parse([] of String)
      CR
  end

  it "rejects a converter with no convert method" do
    assert_compile_time_error "needs `self.convert(input : String)", <<-CR
      require "../src/kebab"
      module NoConv
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: NoConv)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a converter whose convert takes the wrong number of arguments" do
    assert_compile_time_error "must take a single argument", <<-CR
      require "../src/kebab"
      module Conv
        def self.convert(a : String, b : Int32) : String | Kebab::Convert::Failure
          a
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Conv)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a converter whose convert takes a non-String argument" do
    assert_compile_time_error "must take `String`, not `Int32`", <<-CR
      require "../src/kebab"
      module Conv
        def self.convert(input : Int32) : String | Kebab::Convert::Failure
          "x"
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Conv)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a scalar option converter with the wrong return, naming both fixes" do
    assert_compile_time_error "Either return `String | Kebab::Convert::Failure` (one occurrence, parsed whole), or add `self.collect(values : Array(Int32)) : String | Kebab::Convert::Failure`", <<-CR
      require "../src/kebab"
      module Conv
        def self.convert(input : String) : Int32 | Kebab::Convert::Failure
          5
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Conv)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a converter on a Bool flag" do
    assert_compile_time_error "is a Bool flag and never converts a value", <<-CR
      require "../src/kebab"
      module Conv
        def self.convert(input : String) : Bool | Kebab::Convert::Failure
          true
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Conv)]
        getter? loud : Bool = false
      end
      C.parse([] of String)
      CR
  end

  it "rejects an argument converter whose convert returns the wrong type" do
    assert_compile_time_error "must return `String | Kebab::Convert::Failure`, not", <<-CR
      require "../src/kebab"
      module Conv
        def self.convert(input : String) : Int32 | Kebab::Convert::Failure
          5
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Argument(converter: Conv)]
        getter x : String
      end
      C.parse([] of String)
      CR
  end

  it "rejects an Array(Bool) option" do
    assert_compile_time_error "A flag can't take a value, so it can't be one of several", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        getter flags : Array(Bool) = [] of Bool
      end
      C.parse([] of String)
      CR
  end

  it "rejects an array option converter with mismatched element types" do
    assert_compile_time_error "must return `String | Kebab::Convert::Failure` (one element per value) or `Array(String) | Kebab::Convert::Failure` (several)", <<-CR
      require "../src/kebab"
      module Wrong
        def self.convert(input : String) : Array(Int32) | Kebab::Convert::Failure
          [input.size]
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Wrong)]
        getter tags : Array(String) = [] of String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a collection field without a converter, naming the repeatable paths" do
    assert_compile_time_error "Use `Array(T)` for a repeatable option", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        getter tags : Set(String) = Set(String).new
      end
      C.parse([] of String)
      CR
  end

  it "rejects a collect argument that isn't last" do
    assert_compile_time_error "consumes the remaining positionals, so it must be the last one", <<-CR
      require "../src/kebab"
      module Tags
        def self.convert(input : String) : String | Kebab::Convert::Failure
          input
        end
        def self.collect(values : Array(String)) : Set(String) | Kebab::Convert::Failure
          values.to_set
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Argument(converter: Tags)]
        getter tags : Set(String) = Set(String).new
        @[Kebab::Argument]
        getter target : String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a collect that takes the wrong number of arguments" do
    assert_compile_time_error "`collect` must take a single argument", <<-CR
      require "../src/kebab"
      module Tags
        def self.convert(input : String) : String | Kebab::Convert::Failure
          input
        end
        def self.collect(values : Array(String), strict : Bool) : Set(String) | Kebab::Convert::Failure
          values.to_set
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Tags)]
        getter tags : Set(String) = Set(String).new
      end
      C.parse([] of String)
      CR
  end

  it "rejects a collect whose argument doesn't match convert's output" do
    assert_compile_time_error "`collect` must take the values `convert` produces", <<-CR
      require "../src/kebab"
      module Tags
        def self.convert(input : String) : String | Kebab::Convert::Failure
          input
        end
        def self.collect(values : Array(Int32)) : Set(String) | Kebab::Convert::Failure
          Set(String).new
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Tags)]
        getter tags : Set(String) = Set(String).new
      end
      C.parse([] of String)
      CR
  end

  it "rejects a collect whose return doesn't match the field type" do
    assert_compile_time_error "`collect` must return `Set(String) | Kebab::Convert::Failure`, not", <<-CR
      require "../src/kebab"
      module Tags
        def self.convert(input : String) : String | Kebab::Convert::Failure
          input
        end
        def self.collect(values : Array(String)) : Array(String) | Kebab::Convert::Failure
          values
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Tags)]
        getter tags : Set(String) = Set(String).new
      end
      C.parse([] of String)
      CR
  end

  it "rejects a direct Convert.convert of an unsupported type" do
    assert_compile_time_error "no built-in conversion for", <<-CR
      require "../src/kebab"
      Kebab::Convert.convert(Time, "x")
      CR
  end

  it "rejects Convert::Enum of a non-enum type" do
    assert_compile_time_error "requires an enum type", <<-CR
      require "../src/kebab"
      Kebab::Convert::Enum(String).convert("x")
      CR
  end

  it "rejects a duplicate long option" do
    assert_compile_time_error "Duplicate long option", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(long: "foo")]
        getter a : String?
        @[Kebab::Option(long: "foo")]
        getter b : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a duplicate short option" do
    assert_compile_time_error "Duplicate short option", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(short: 'x')]
        getter a : String?
        @[Kebab::Option(short: 'x')]
        getter b : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a duplicate argument name" do
    assert_compile_time_error "Duplicate argument", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument(name: "f")]
        getter a : String
        @[Kebab::Argument(name: "f")]
        getter b : String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a Bool positional argument" do
    assert_compile_time_error "Bool fields can't be positional", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter? flag : Bool
      end
      C.parse([] of String)
      CR
  end

  it "rejects an Array(Bool) positional argument" do
    assert_compile_time_error "Bool fields can't be positional", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter flags : Array(Bool)
      end
      C.parse([] of String)
      CR
  end

  it "rejects a nilable flag" do
    assert_compile_time_error "Use `Bool = false`", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        getter? flag : Bool | Nil
      end
      C.parse([] of String)
      CR
  end

  it "rejects a nilable variadic argument" do
    assert_compile_time_error "can't be nilable", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter files : Array(String)?
      end
      C.parse([] of String)
      CR
  end

  it "rejects two variadic arguments" do
    assert_compile_time_error "arguments that consume the remaining positionals (variadic `Array(T)` or a converter with `collect`). Only one is allowed", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter a : Array(String)
        @[Kebab::Argument]
        getter b : Array(String)
      end
      C.parse([] of String)
      CR
  end

  it "rejects a variadic argument that isn't last" do
    assert_compile_time_error "consumes the remaining positionals, so it must be the last one", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter a : Array(String)
        @[Kebab::Argument]
        getter b : String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a required positional after an optional one" do
    assert_compile_time_error "comes after an optional argument", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter a : String?
        @[Kebab::Argument]
        getter b : String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a multi-type union field" do
    assert_compile_time_error "must be a single type", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter x : String | Int32
      end
      C.parse([] of String)
      CR
  end

  it "rejects a field with two kebab annotations" do
    assert_compile_time_error "more than one kebab annotation", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        @[Kebab::Argument]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects an unknown option key" do
    assert_compile_time_error "has unknown key", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(bogus: 1)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a non-Char short" do
    assert_compile_time_error "must be a Char", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(short: "x")]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a non-String long" do
    assert_compile_time_error "must be a String", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(long: 5)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a non-Bool global" do
    assert_compile_time_error "must be true or false", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(global: 1)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a non-type converter" do
    assert_compile_time_error "must be a type name", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: 5)]
        getter x : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects an annotated method with no typed ivar" do
    assert_compile_time_error "needs an explicit type", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        def foo : String?
          nil
        end
      end
      C.parse([] of String)
      CR
  end

  it "rejects two subcommand fields" do
    assert_compile_time_error "@[Kebab::Subcommand] fields. Only one is allowed", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Subcommand]
        getter a : Leaf
        @[Kebab::Subcommand]
        getter b : Leaf
      end
      C.parse([] of String)
      CR
  end

  it "rejects positionals alongside a subcommand" do
    assert_compile_time_error "one or the other", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter a : String
        @[Kebab::Subcommand]
        getter cmd : Leaf
      end
      C.parse([] of String)
      CR
  end

  it "rejects a non-Parseable subcommand union member" do
    assert_compile_time_error "isn't a command", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Subcommand]
        getter cmd : Leaf | Int32
      end
      C.parse([] of String)
      CR
  end

  it "rejects two subcommand union members that resolve to the same name" do
    assert_compile_time_error "Duplicate subcommand", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "list")]
      struct Renamed
        include Kebab::Parseable
      end
      struct List
        include Kebab::Parseable
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Subcommand]
        getter cmd : Renamed | List
      end
      C.parse([] of String)
      CR
  end

  it "rejects a nilable subcommand field" do
    assert_compile_time_error "can't be nilable. Use `required:", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Subcommand]
        getter cmd : Leaf?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a subcommand field with a default value" do
    assert_compile_time_error "Defaults aren't used here", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Subcommand(required: false)]
        getter cmd : Leaf | Nil = nil
      end
      C.parse([] of String)
      CR
  end

  it "rejects a descendant redeclaring an ancestor's global long option" do
    assert_compile_time_error "redeclared by", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
        @[Kebab::Option]
        getter? verbose : Bool = false
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(global: true)]
        getter? verbose : Bool = false
        @[Kebab::Subcommand]
        getter cmd : Leaf
      end
      C.parse([] of String)
      CR
  end

  it "rejects arity on a Tuple option" do
    assert_compile_time_error "already fixes the arity at 2", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 2)]
        getter range : Tuple(Int32, Int32) = {0, 0}
      end
      C.parse([] of String)
      CR
  end

  it "rejects arity on a single-value option" do
    assert_compile_time_error "takes one value. Use `Tuple(...)` for a fixed group", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 2)]
        getter name : String?
      end
      C.parse([] of String)
      CR
  end

  it "rejects arity on a flag" do
    assert_compile_time_error "a Bool flag takes no values", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 2)]
        getter? loud : Bool = false
      end
      C.parse([] of String)
      CR
  end

  it "rejects a zero arity" do
    assert_compile_time_error "must take at least one value, got `0`", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 0)]
        getter tags : Array(String) = [] of String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a beginless arity range" do
    assert_compile_time_error "allows zero. Start the range at 1", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: ..3)]
        getter tags : Array(String) = [] of String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a float arity" do
    assert_compile_time_error "must be an Int like `2` or an inclusive Range", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 2.5)]
        getter tags : Array(String) = [] of String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a zero-starting arity range" do
    assert_compile_time_error "allows zero. Start the range at 1", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 0..)]
        getter tags : Array(String) = [] of String
      end
      C.parse([] of String)
      CR
  end

  it "rejects an exclusive arity range" do
    assert_compile_time_error "must be an inclusive Range", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 1...3)]
        getter tags : Array(String) = [] of String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a variable arity alongside positional arguments" do
    assert_compile_time_error "A greedy option would swallow them", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 1..)]
        getter files : Array(String) = [] of String
        @[Kebab::Argument]
        getter target : String
      end
      C.parse([] of String)
      CR
  end

  it "rejects a variable arity alongside a subcommand" do
    assert_compile_time_error "would swallow the subcommand name", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 1..)]
        getter files : Array(String) = [] of String
        @[Kebab::Subcommand]
        getter cmd : Leaf
      end
      C.parse([] of String)
      CR
  end

  it "rejects a variable-arity global" do
    assert_compile_time_error "A greedy global would swallow subcommands", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(arity: 1.., global: true)]
        getter files : Array(String) = [] of String
      end
      C.parse([] of String)
      CR
  end

  it "rejects value_names that don't match the value count" do
    assert_compile_time_error "names 3 values, but --range takes 2", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option(value_names: {"a", "b", "c"})]
        getter range : Tuple(Int32, Int32) = {0, 0}
      end
      C.parse([] of String)
      CR
  end

  it "rejects a one-value tuple" do
    assert_compile_time_error "A one-value tuple is a plain value. Use `Int32` directly", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        getter solo : Tuple(Int32) = {0}
      end
      C.parse([] of String)
      CR
  end

  it "rejects nested tuples" do
    assert_compile_time_error "Value types must be simple", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        getter deep : Tuple(Int32, Tuple(Int32, Int32))?
      end
      C.parse([] of String)
      CR
  end

  it "rejects nested arrays" do
    assert_compile_time_error "Value types must be simple", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Option]
        getter deep : Array(Array(Int32)) = [] of Array(Int32)
      end
      C.parse([] of String)
      CR
  end

  it "rejects a nested array argument" do
    assert_compile_time_error "Value types must be simple", <<-CR
      require "../src/kebab"
      struct C
        include Kebab::Parseable
        @[Kebab::Argument]
        getter deep : Array(Array(Int32)) = [] of Array(Int32)
      end
      C.parse([] of String)
      CR
  end

  it "rejects a converter on a heterogeneous tuple" do
    assert_compile_time_error "mixes types. Drop the `converter:`", <<-CR
      require "../src/kebab"
      module Conv
        def self.convert(input : String) : String | Kebab::Convert::Failure
          input
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Conv)]
        getter pair : Tuple(String, Int32)?
      end
      C.parse([] of String)
      CR
  end

  it "rejects collect on a tuple-grouped option" do
    assert_compile_time_error "`collect` folds one value per occurrence", <<-CR
      require "../src/kebab"
      module Conv
        def self.convert(input : String) : Int32 | Kebab::Convert::Failure
          Kebab::Convert.convert(Int32, input)
        end
        def self.collect(values : Array(Int32)) : Tuple(Int32, Int32) | Kebab::Convert::Failure
          {values[0], values[1]}
        end
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(converter: Conv)]
        getter pair : Tuple(Int32, Int32)?
      end
      C.parse([] of String)
      CR
  end

  it "rejects a descendant redeclaring an ancestor's global short option" do
    assert_compile_time_error "redeclared by", <<-CR
      require "../src/kebab"
      @[Kebab::Command(name: "leaf")]
      struct Leaf
        include Kebab::Parseable
        @[Kebab::Option(short: 'v')]
        getter value : String?
      end
      struct C
        include Kebab::Parseable
        @[Kebab::Option(global: true, short: 'v')]
        getter volume : String?
        @[Kebab::Subcommand]
        getter cmd : Leaf
      end
      C.parse([] of String)
      CR
  end
end
