require "./bindings/pangocairo"
require "./bindings/gl"
require "crystaledge"

module Nya
  class Pango
    property texture_id : UInt32
    property size : CrystalEdge::Vector2

    def initialize(@texture_id, @size)
    end

    def self.get_text_size(layout : LibPangoCairo::PangoLayout*)
      LibPangoCairo.layout_get_size(layout, out w, out h)
      return (CrystalEdge::Vector2.new(w.to_f64, h.to_f64)) / (LibPangoCairo::SCALE.to_f64)
    end

    def self.render_text(text : String, font : String, channels = 4u8)
      # Create a context
      temp_surface = LibPangoCairo.create_surf(LibPangoCairo::CairoFormat::ARGB32, 0, 0)
      context = LibPangoCairo.create(temp_surface)
      LibPangoCairo.destroy_surface(temp_surface)

      layout = LibPangoCairo.create_layout(context)

      LibPangoCairo.layout_set_text(layout, text, -1)

      desc = LibPangoCairo.font_desc_from_string(font)
      LibPangoCairo.layout_set_font_desc(layout, desc)
      LibPangoCairo.free_font_desc(desc)

      tsize = get_text_size(layout)
      buffer = Array(UInt32).build((tsize.x*tsize.y*channels).to_i) { 0 }

      rendering_context = LibPangoCairo.create(LibPangoCairo.create_surf_for_data(
        buffer,
        LibPangoCairo::CairoFormat::ARGB32,
        tsize.x,
        tsize.y,
        channels*tsize.x
      ))

      LibPangoCairo.set_source_rgba(rendering_context, 1, 1, 1, 1)

      LibPangoCairo.show_layout(rendering_context, layout)

      texture_id = 0u32
      LibGL.gen_textures 1, pointerof(texture_id)
      LibGL.bind_texture(LibGL::TEXTURE_2D, texture_id)

      LibGL.tex_parameteri(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::LINEAR)
      LibGL.tex_parameteri(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::LINEAR)

      LibGL.tex_image2d(
        LibGL::TEXTURE_2D,
        0,
        LibGL::RGBA,
        tsize.x,
        tsize.y,
        0,
        LibGL::BGRA,
        LibGL::UNSIGNED_BYTE,
        buffer
      )

      LibPangoCairo.destroy(context)
      LibPangoCairo.destroy(rendering_context)

      new(texture_id, tsize)
    end
  end
end
