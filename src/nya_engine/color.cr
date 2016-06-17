module Nya
  class Color
    @r : UInt8
    @g : UInt8
    @b : UInt8
    @a : UInt8
    property r,g,b,a
    def initialize(@r,@g,@b,@a)

    end

    def to_gl
      {
        @r.to_f / 255.0,
        @g.to_f / 255.0,
        @b.to_f / 255.0
      }
    end

    def to_gl_4
      {
        @r.to_f / 255.0,
        @g.to_f / 255.0,
        @b.to_f / 255.0,
        @a.to_f / 255.0
      }
    end

    def +(other : Color)
      alpha = other.a
      ia = 256-alpha
      Color.new(
        ((alpha*other.r + ia*self.r) >> 8).as(UInt8),
        ((alpha*other.g + ia*self.g) >> 8).as(UInt8),
        ((alpha*other.b + ia*self.b) >> 8).as(UInt8),
        255
      )
    end

    def self.red
      Color.new(255,0,0,255)
    end

    def self.green
      Color.new(0,255,0,255)
    end

    def self.blue
      Color.new(0,0,255,255)
    end

    def self.brown
      Color.new(255,255,0,255)
    end

    def self.black
      Color.new(0,0,0,255)
    end

  end
end