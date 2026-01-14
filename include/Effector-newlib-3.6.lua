	----------------------------------------------------------------------------------------------------------------
	--[[ ( c ) Copyright 2012 - 2019, Vict8r, Karalaura, NatsuoKE & Itachi Akatsuki				  				]]--
	----------------------------------------------------------------------------------------------------------------
	--[[ El archivo Effector-newlib-3.6.lua  ha sido creado con la intención de poder almacenar todas esas variables
	que usamos constantemente en nuestros efectos y ediciones de texto, también aquellas funciones que diseñamos por
	comodidad o necesidad de nuestras creaciones. Se debe tener muy presente que, todo lo que sea almacenado en este
	archivo afectará directamente al funcionamiento correcto del Kara Effector, por lo que, si algo de lo almacenado
	o modificado genera un error, éste deberá ser reparado o eliminado, para que todo funcione de forma correcta. Se
	debe contar con unos conocimientos mínimos de programación en lenguaje LUA para poder crear o diseñar la mayoría
	de las funciones extras, externas al Kara Effector, que son necesarias para la invención de efectos considerados
	de nivel avanzado, así que gran parte de la responsabilidad del correcto funcionamiento del KE dependerá de todo
	lo que acá sea añadido/modificado.
	En caso de tener alguna duda o inquietud, no olvides ponerte en contacto con nosotros, y de ser posible, daremos
	pronta solución a tus cuestionamientos. Ahora contamos con nuevos canales de comunicación por los cuales podemos
	estar en contacto más seguido y hasta en tiempo real. --]]
	
	--> Kara Effector 3.6 legacy
	--> Contáctanos:
	
	--> [WhatsApp] Kara Effector: +57 320 863 14 72
	--> [Discord]  Kara Effector: discord.gg/YFP2zeY
	-->	http://www.facebook.com/karaeffector
	--> http://www.karaeffector.blogspot.com
	
	-- Effector-newlib-3.6.lua -------------------------------------------------------------------------------------
	Effector_NewLib_authors  = "Itachi Akatsuki"
	Effector_NewLib_testers  = "NatsuoKE & Vict8r"
	Effector_NewLib_version  = "1.0"
	Effector_NewLib_modified = "January 12th 2019"
	----------------------------------------------------------------------------------------------------------------
  
	--[[ tag.create_clip_grid
  Función de clip personalizada para generar rejillas de clips de forma independiente.
  No depende de las variables globales j, fx.loop_v, o fx.loop_h.

  Parámetros:
    - current_index (número): El índice del clip a generar (empezando en 1).
    - cols (número): Número total de columnas en la rejilla.
    - rows (número): Número total de filas en la rejilla.
    - box (tabla): Tabla {x, y, w, h} que define el área total a recortar.
    - mode (número, opcional): Orden de barrido. 79 (defecto) = I-D, A-A. 71 = A-A, I-D.
    - is_inverse (booleano, opcional): true para \iclip, false (defecto) para \clip.
    - overlap (número o tabla, opcional): Píxeles de solapamiento. Puede ser un número para un overlap uniforme,
      o una tabla {overlap_x, overlap_y} para un control independiente. Por defecto es 0.

  Retorna:
    - Un string con el tag \clip o \iclip generado.
]]

function tag.create_clip_grid(current_index, cols, rows, box, mode, is_inverse, overlap)

	local i = current_index or 1
	local c = cols or 1
	local r = rows or 1
	local m = mode or 79
	local inv = is_inverse or false
	local b = box or { x = 0, y = 0, w = xres, h = yres }
	local overlap_x = 0
	local overlap_y = 0
	if type(overlap) == "number" then
		overlap_x = overlap
		overlap_y = overlap
	elseif type(overlap) == "table" then
		overlap_x = overlap[1] or 0
		overlap_y = overlap[2] or overlap_x
	end

    local cell_w = b.w / c
	local cell_h = b.h / r
    local col_idx, row_idx = 0, 0

	if m == 13 or m == 17 or m == 31 or m == 39 or m == 71 or m == 79 or m == 93 or m == 97 then
		if m == 17 or m == 39 or m == 71 or m == 93 then
			col_idx = math.floor((i - 1) / r)
			row_idx = (i - 1) % r
		else
			col_idx = (i - 1) % c
			row_idx = math.floor((i - 1) / c)
		end

		if m == 31 or m == 39 or m == 93 or m == 97 then
			col_idx = c - 1 - col_idx
		end
		if m == 13 or m == 17 or m == 31 or m == 39 then
			row_idx = r - 1 - row_idx
		end
	else

		col_idx = (i - 1) % c
		row_idx = math.floor((i - 1) / c)
	end

	local cx1 = b.x + col_idx * cell_w - overlap_x
	local cy1 = b.y + row_idx * cell_h - overlap_y
	local cx2 = b.x + (col_idx + 1) * cell_w + overlap_x
	local cy2 = b.y + (row_idx + 1) * cell_h + overlap_y

	local tag_type = inv and "iclip" or "clip"

	return string.format("\\%s(%d,%d,%d,%d)", tag_type, math.round(cx1,2), math.round(cy1,2), math.round(cx2,2), math.round(cy2,2))
end

--------------------------------------------------

function color.gradient( pct, ... )
	-- Interpola un color a lo largo de un gradiente definido por múltiples puntos de color.
	-- pct: El porcentaje (0 a 1) a lo largo del gradiente completo.
	-- ...: La lista de colores que definen el gradiente (ej: color1, color2, color3, ...)
	
	local colors = { ... }
	if type( ... ) == "table" then
		colors = ...
	end

	if #colors < 1 then return "&H000000&" end
	if #colors == 1 then return color.ass(colors[1]) end

	local pct = math.clamp( pct or 0, 0, 1 )
	local position = pct * (#colors - 1)
	local index_start = math.floor(position) + 1
	local index_end = math.min(index_start + 1, #colors)
	local local_pct = position - math.floor(position)
	if local_pct == 0 and pct == 1.0 then
		return color.ass(colors[#colors])
	end

	local color1 = color.ass( colors[index_start] )
	local color2 = color.ass( colors[index_end] )

	return color.interpolate(local_pct, color1, color2)
	end

--------------------------------------------------

-- Asegura que Calculate existe.
calculate = calculate or {}

function calculate.avg_char_width(char_widths_table, text_string)
    local non_space_widths = {}
    local text_chars = {}
    for c in unicode.chars(text_string) do
        table.insert(text_chars, c)
    end

    if #char_widths_table ~= #text_chars then return 15 end

    for i=1, #char_widths_table do
        if text_chars[i] ~= " " then
            table.insert(non_space_widths, char_widths_table[i])
        end
    end

    if #non_space_widths == 0 then
        return 15
    end
    
    return table.op(non_space_widths, "average")
end

function calculate.synchronized_extratime(line_context, progression_const, fade_dur, avg_char_width, max_added_time)
    progression_const = progression_const or 0
    fade_dur = fade_dur or 0
    avg_char_width = avg_char_width or 15
    max_added_time = max_added_time or 2000
    local line = line_context.line
    local l = line_context.l
    local linefx = line_context.linefx
    local idx_line = line_context.idx_line
    local count_line_dialogue = line_context.count_line_dialogue
    local ini_line = line_context.ini_line
    local current_char_count = unicode.len((line.text_stripped:gsub(" ", "")))
    local P2_current = progression_const * (current_char_count > 1 and current_char_count - 1 or 0)
    
    if line.i >= line.n then
        return P2_current
    end

    local next_line_index_in_selection = line.i + 1
    local next_line_index_in_file = idx_line[next_line_index_in_selection]
    local next_line_index_in_linefx = next_line_index_in_file + count_line_dialogue - ini_line
    local next_line = linefx[next_line_index_in_linefx]
    if not next_line then return P2_current end
    local next_line_char_count = unicode.len((next_line.text_stripped:gsub(" ", "")))
    local P2_next = progression_const * (next_line_char_count > 1 and next_line_char_count - 1 or 0)
    local transition_duration = (P2_current + P2_next) / 2
    local spatial_jump = next_line.left - line.right
    local spatial_compensation_time = (spatial_jump > 0) and ((spatial_jump / avg_char_width) * progression_const) or 0
    local ideal_end_time = next_line.start_time + transition_duration + spatial_compensation_time - fade_dur
    local extra_time_needed = ideal_end_time - l.end_time
    local final_extra_time = math.min(max_added_time, math.max(0, extra_time_needed))
    
    return final_extra_time
end

-- Ejemplo de uso:
-- Casilla end_time:
-- l.end_time + delay2 + calculate.extratime(line_context, progression_const, fade_dur)
-- Casilla variable:
-- progression_const = 35;
-- fade_dur = 150;
-- delay2 = 250;
-- line_context = {
--    line = line,
--    l = l,
--    idx_line = idx_line,
--    l_counter = l_counter,
--    count_line_dialogue = count_line_dialogue,
--    ini_line = ini_line,
--    linefx = linefx
--};


