require "../renderer"
require "../schema/command"
require "../schema/usage/subcommand"
require "./base"

module Kebab
  module Error
    class MissingCommand < Error::Base
      def initialize(@commands : Array(Schema::Command), @usage : Schema::Usage::Subcommand)
        super("a command is required.")
      end

      getter commands : Array(Schema::Command)
      getter usage : Schema::Usage::Subcommand

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @usage)
        io << "\n\n"
        Renderer.section(io, "Commands:", @commands)
      end
    end
  end
end
