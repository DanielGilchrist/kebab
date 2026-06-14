require "colorize"

require "./schema/argument"
require "./schema/command"
require "./schema/option"
require "./schema/usage"

module Kebab
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
      left = "#{left} <value>" if option.takes_value?
      {left, option.description}
    end

    def row(argument : Schema::Argument) : Tuple(String, String)
      left = argument.variadic? ? "<#{argument.name}>..." : "<#{argument.name}>"
      {left, argument.description}
    end
  end
end
