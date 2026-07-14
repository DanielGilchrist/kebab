require "colorize"

require "./schema/argument"
require "./schema/command"
require "./schema/option"
require "./schema/usage"

module Kebab
  # :nodoc:
  module Renderer
    extend self

    def usage(io : IO, usage : Schema::Usage::Any) : Nil
      io << "Usage:".colorize.bold.underline << ' '
      usage.to_s(io)
    end

    def section(io : IO, header : String, items : Array) : Nil
      return if items.empty?

      rows = items.map { |item| row(item) }
      width = rows.max_of(&.first.size) + 2

      io << header.colorize.bold.underline
      rows.each do |row|
        left, description = row
        io << "\n  " << left.colorize.bold
        io << " " * (width - left.size) << description unless description.empty?
      end
    end

    def row(command : Schema::Command) : Tuple(String, String)
      {command.name, command.summary}
    end

    def row(option : Schema::Option) : Tuple(String, String)
      short = option.short
      left = short ? "-#{short}, --#{option.long}" : "    --#{option.long}"
      option.value_names.each { |name| left = "#{left} <#{name}>" }
      left = "#{left}..." if option.variable?
      {left, option.description}
    end

    def row(argument : Schema::Argument) : Tuple(String, String)
      left = Array.new(argument.value_count, "<#{argument.name}>").join(' ')
      left = "#{left}..." if argument.variadic?
      {left, argument.description}
    end
  end
end
