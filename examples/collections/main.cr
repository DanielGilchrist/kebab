require "../../src/kebab"

# One value can carry several columns: "time,cost" becomes two elements.
module Columns
  def self.convert(input : String) : Array(String) | Kebab::Convert::Failure
    input.split(',')
  end
end

# Rejects duplicates across occurrences instead of silently deduping.
module UniqueTags
  def self.convert(input : String) : String | Kebab::Convert::Failure
    input
  end

  def self.collect(values : Array(String)) : Set(String) | Kebab::Convert::Failure
    set = values.to_set
    return Kebab::Convert.failure("duplicate tags", name: "tags") if set.size != values.size
    set
  end
end

@[Kebab::Command(summary: "Build a report from data points")]
struct Report
  include Kebab::Parseable

  @[Kebab::Option(short: 'c', converter: Columns, description: "Column to include")]
  getter column : Array(String) = [] of String

  @[Kebab::Option(converter: UniqueTags, description: "Tags, duplicates rejected")]
  getter tag : Set(String) = Set(String).new

  @[Kebab::Option(value_names: {"min", "max"}, description: "Y-axis range")]
  getter range : Tuple(Int32, Int32) = {0, 100}

  @[Kebab::Argument(description: "X/Y data points")]
  getter points : Array(Tuple(Float64, Float64)) = [] of Tuple(Float64, Float64)

  def run : Nil
    puts "columns: #{column.join(", ")}"
    puts "tags:    #{tag.join(", ")}"
    puts "range:   #{range[0]}..#{range[1]}"
    points.each { |(x, y)| puts "point:   #{x} @ #{y}" }
  end
end

@[Kebab::Command(summary: "Gather files to bundle")]
struct Gather
  include Kebab::Parseable

  @[Kebab::Option(arity: 1.., value_names: {"file"}, description: "Files to include")]
  getter files : Array(String) = [] of String

  def run : Nil
    puts "files: #{files.join(", ")}"
  end
end

@[Kebab::Command(name: "demo", summary: "Repeated and multi-value options")]
struct Demo
  include Kebab::Parseable

  @[Kebab::Subcommand]
  getter command : Report | Gather
end

exit(1) unless Demo.run(ARGV)
