require "../renderer"
require "../schema/command"
require "../schema/usage/subcommand"
require "./base"

module Kebab
  module Error
    class UnknownCommand < Error::Base
      def initialize(@command : String, @commands : Array(Schema::Command), @usage : Schema::Usage::Subcommand)
        super("\"#{@command}\" isn't a known command.")
      end

      getter command : String
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
