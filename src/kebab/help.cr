module Kebab
  record Help, text : String do
    def to_s(io : IO) : Nil
      io << text
    end
  end
end
