require "../../../log"

module Nya::Render::Backends::GL
  # GLSL shader compiler
  class GLSLCompiler
    @@shader_cache = Hash(String, UInt32).new
    @@program_cache = Hash(String, UInt32).new
    @@preprocessor_cache = Hash(String, String).new
    REQUIRE_REGEX = %r(^\s*//\s*@require (?<name>.+))

    # Flushes preprocessor, compiler and linker cache
    def self.flush_cache!
      Nya.log.warn "Flushing shader and shader program cache"
      [@@shader_cache,
       @@program_cache,
       @@preprocessor_cache].each &.clear
    end

    # Preprocesses shader
    # In fact, that only replaces `@require file` with the contents of the `file`
    def self.preprocess(text : String)
      while text =~ REQUIRE_REGEX
        text = text.split("\n").map do |line|
          if md = line.match REQUIRE_REGEX
            Storage::Reader.read_to_end(md["name"])
          else
            line
          end
        end.join("\n")
      end
      text
    end

    # :nodoc:
    protected def self.type_from_s(str)
      case str.downcase
      when /^frag/
        ShaderType::Fragment
      when /^tess.*c/
        ShaderType::TessControl
      when /^tess.*e/
        ShaderType::TessEvaluation
      when /^geom/
        ShaderType::Geometry
      when /^vert/
        ShaderType::Vertex
      else
        Nya.log.warn "Unknown shader type #{str}, assuming vertex shader", "Shader"
        ShaderType::Vertex
      end
    end

    # Detects shader type using `//@type shader_type` directive and file extension
    # `frag*` - fragment shader
    # `tess*c*` - tesselation control shader
    # `tess*e*` - tesselation evaluation shader
    # `geom*` - geometry shader
    # Shader with other type is considered vertex shader
    def self.detect_type(text, filename : String? = nil)
      md = text.match(/\/\/@type (?<type>.*)/)
      if md
        type_from_s md["type"]
      elsif filename
        type_from_s File.extname(filename.not_nil!).lchop('.')
      else
        Nya.log.warn "Cannot detect shader type, assuming vertex shader", "Shader"
        ShaderType::Vertex
      end
    end

    # Compiles shader
    # If `stype` is not set, it is detected automatically using `detect_type`
    def self.compile(filename : String, stype : ShaderType? = nil)
      ckey = "#{filename}$#{stype}"
      if @@shader_cache.has_key? ckey
        Nya.log.debug "Found cached shader for #{filename}"
        return @@shader_cache[ckey]
      end
      Nya.log.info "Compiling shader #{filename}", "Shader"
      text = Storage::Reader.read_to_end(filename)
      if @@preprocessor_cache.has_key? filename
        text = @@preprocessor_cache[filename]
      else
        text = preprocess text
      end
      @@preprocessor_cache[filename] = text
      stype ||= detect_type text
      Nya.log.debug "Type is #{stype}", "Shader"

      shid = LibGL.create_shader stype.to_i
      Nya.log.debug "Allocated ID : 0x#{shid.to_s(16)} (#{shid})", "Shader"

      utext = text.to_unsafe

      LibGL.shader_source shid, 1, pointerof(utext), nil
      LibGL.compile_shader shid

      LibGL.get_shaderiv shid, LibGL::COMPILE_STATUS, out comp_ok
      LibGL.get_shaderiv shid, LibGL::INFO_LOG_LENGTH, out log_l
      bytes = Bytes.new(log_l)
      LibGL.get_shader_info_log shid, log_l, out len, bytes


      if log_l > 0
        String.new(bytes).split("\n").each do |ln|
          Nya.log.error ln, "GL"
        end
      end

      raise "Cannot compile shader. See log for more details" if comp_ok == 0
      Nya.log.debug "Compiled shader successfully", "Shader"
      @@shader_cache[ckey] = shid
      shid
    end

    # Links a shader program
    def self.link(shaders : Array(UInt32))
      ckey = shaders.join(";")
      if @@program_cache.has_key? ckey
        Nya.log.debug "Found cached shader for #{ckey}"
        return @@program_cache[ckey]
      end
      Nya.log.debug "Linking shader program", "Shader"
      pid = LibGL.create_program
      Nya.log.debug "Allocated ID : 0x#{pid.to_s(16)} (#{pid})", "Shader"
      shaders.each { |s| LibGL.attach_shader pid, s }

      LibGL.bind_attrib_location pid, 0, "nya_Position"
      LibGL.bind_attrib_location pid, 1, "nya_Normal"
      LibGL.bind_attrib_location pid, 2, "nya_TexCoord"

      link_program! pid

      @@program_cache[ckey] = pid
      pid
    end

    # :nodoc:
    def self.link_program!(pid, silent = false)
      LibGL.link_program pid

      LibGL.get_programiv pid, LibGL::LINK_STATUS, out link_ok
      LibGL.get_programiv pid, LibGL::INFO_LOG_LENGTH, out log_l
      log = Bytes.new(log_l)
      LibGL.get_program_info_log pid, log_l, out len, log
      String.new(log).split("\n").each do |ln|
        if link_ok == 0
          Nya.log.error ln, "GL"
        elsif log_l > 0 && !silent
          Nya.log.warn ln, "GL"
        end
      end

      raise "Cannot link shader program. See log for more details" if link_ok == 0
      Nya.log.debug "Linked successfully", "Shader" unless silent
    end

    # :nodoc:
    def self.parse_vars(filename : String)
      text = if @@preprocessor_cache.has_key? filename
        @@preprocessor_cache[filename]
      else
        Nya.log.warn "Preprocessing shader #{filename} as it has been not preprocessed yet", "Shader"
        @@preprocessor_cache[filename] = preprocess Storage::Reader.read_to_end(filename)
      end
      text.split("\n").compact_map do |line|
        md = line.match(/^[^\/]*(?<kind>attribute|uniform)\s*(?<type>[a-z0-9A-Z]+)\s*(?<name>.+);/)
        if md.nil?
          nil
        else
          {
            kind: md["kind"].not_nil!,
            type: md["type"].not_nil!,
            name: md["name"].not_nil!,
          }
        end
      end
    end
  end
end
