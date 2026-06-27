-----------------------------------------------------------------------------------------
-- Kara Effector 3.6.004 - Seijitsu Extensions File
-- Contiene Wrappers de ILL (Shapery), Mesh Engines y funciones personalizadas para
-- el fork de Sijitsu.
-----------------------------------------------------------------------------------------

-- Inicialización local de ILL (Shapery)
local status, ILL = pcall(require, "ILL.ILL")
local SHP = status and ILL.Path or nil

-- Fix Aegisub 3.2.2: Flag para advertir sobre la falta de ILL solo durante la ejecución
local warning_shp_printed = false

local function check_shp_available()
    if not SHP then
        if not warning_shp_printed then
            aegisub.debug.out(0, "[Error] ILL.ILL Shapery no encontrado. Los efectos vectoriales no funcionarán.\n")
            warning_shp_printed = true
        end
        return false
    end
    return true
end

-- Variables Globales y Cachés de Seijitsu
_G.Effector_Shape_Cache = _G.Effector_Shape_Cache or {}
calculate = calculate or {}

---------------------------------------------------------------------
-- CAPA PRIVADA
---------------------------------------------------------------------
local function _clean(shape)
    if type(shape) ~= "string" or shape == "" then return "" end
    local cleaned = shape:gsub("nan", "0"):gsub("inf", "0")
    return cleaned:gsub("(%-?%d+%.%d%d)%d+", "%1")
end

local function _run_shp(shape_str, action_fn, context_name)
    -- Fix: Validación segura retrasada
    if not check_shp_available() then return shape_str end
    
    if type(shape_str) ~= "string" then 
        aegisub.debug.out(1, string.format("[Aviso %s] Se esperaba un vector, pero se recibió: %s\n", context_name, type(shape_str)))
        return ""
    end
    
    if shape_str == "" or shape_str:match("nan") or shape_str:match("inf") then 
        return shape_str 
    end

    local ok, result_or_err = pcall(function()
        local p = SHP(shape_str)
        action_fn(p)
        return _clean(p:export())
    end)
    
    if not ok then
        aegisub.debug.out(0, string.format("[Error en %s] %s\n", context_name, tostring(result_or_err)))
        return shape_str
    end

    return result_or_err
end

---------------------------------------------------------------------
-- FUNCIONES GLOBALES y Wrappers de ILL
---------------------------------------------------------------------
function FX_ShpOffset(str, dist)
    local d = tonumber(dist) or 0.0 
    return _run_shp(str, function(p) 
        p:offset(d, "round", "polygon")
        p:simplify(0.5) 
    end, "FX_ShpOffset")
end

function FX_ShpRound(str, rad)
    if not check_shp_available() then return str end -- Fix
    if type(str) ~= "string" or str == "" then return str end
    if str:match("nan") or str:match("inf") then return str end

    local ok, result_or_err = pcall(function()
        local p = SHP.RoundingPath(str, rad, false, "Rounded", "Absolute")
        return _clean(p:export())
    end)
    
    if not ok then
        aegisub.debug.out(0, string.format("[Error en FX_ShpRound] %s\n", tostring(result_or_err)))
        return str
    end
    return result_or_err
end

function FX_ShpSimplify(str, tol)
    return _run_shp(str, function(p) p:simplify(tol or 1) end, "FX_ShpSimplify")
end

function FX_ShpTransform(str, sx, sy, rot, tx, ty)
    return _run_shp(str, function(p) 
        if sx or sy then p:scale(sx or 1, sy or 1) end
        if rot and rot ~= 0 then p:rotate(rot) end
        if tx or ty then p:move(tx or 0, ty or 0) end
    end, "FX_ShpTransform")
end

function FX_ShpBoolean(str_A, str_B, op)
    if not check_shp_available() then return str_A end -- Fix
    if type(str_A) ~= "string" or type(str_B) ~= "string" then return str_A end
    if str_A == "" or str_B == "" then return str_A end

    local ok, result_or_err = pcall(function()
        local pA = SHP(str_A)
        local pB = SHP(str_B)
        
        if op == "union" or op == "unite" then 
            pA:unite(pB)
        elseif op == "difference" then 
            pA:difference(pB)
        elseif op == "xor" or op == "exclude" then 
            pA:exclude(pB)
        else 
            pA:intersect(pB)
        end
        
        pA:simplify(0.5)
        return _clean(pA:export())
    end)
    
    if not ok then
        aegisub.debug.out(0, string.format("[Error en FX_ShpBoolean] Op: %s - %s\n", tostring(op), tostring(result_or_err)))
        return str_A
    end
    
    return result_or_err
end

function FX_ShpToCenter(str)
    return _run_shp(str, function(p) p:toCenter() end, "FX_ShpToCenter")
end

function FX_ShpToOrigin(str)
    return _run_shp(str, function(p) p:toOrigin() end, "FX_ShpToOrigin")
end

-- ---------------------------------------------------------------------
-- CAPA DE EXTRACCIÓN
-- ---------------------------------------------------------------------

function FX_ShpBox(str)
    local empty_box = {x=0, y=0, w=0, h=0, cx=0, cy=0}
    if not check_shp_available() then return empty_box end -- Fix
    if type(str) ~= "string" or str == "" then return empty_box end
    
    local ok, box_or_err = pcall(function()
        local p = SHP(str)
        local box = p:boundingBox()
        
        -- Tabla real de ILL: l (left), t (top), r (right), b (bottom), width, height
        return {
            x = box.l,                  -- Borde Izquierdo
            y = box.t,                  -- Borde Superior
            w = box.width,              -- Anchura
            h = box.height,             -- Altura
            cx = box.l + (box.width / 2),  -- Centro Matemático X
            cy = box.t + (box.height / 2)  -- Centro Matemático Y
        }
    end)
    
    if not ok then
        aegisub.debug.out(0, string.format("[Error en FX_ShpBox] %s\n", tostring(box_or_err)))
        return empty_box
    end
    
    return box_or_err
end

---------------------------------------------------------------------
-- FUNCIONES DE LIBRERÍA EXISTENTES
---------------------------------------------------------------------

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
    local progression_const = progression_const or 0
    local fade_dur = fade_dur or 0
    local avg_char_width = avg_char_width or 15
    local max_added_time = max_added_time or 2000

    local line = line_context.line
    local l = line_context.l
    local linefx = line_context.linefx
    local idx_line = line_context.idx_line
    local count_line_dialogue = line_context.count_line_dialogue
    local ini_line = line_context.ini_line

    local current_char_count = unicode.len((line.text_stripped:gsub(" ", "")))
    local P2_current = progression_const * (current_char_count > 1 and current_char_count - 1 or 0)
    
    if line.i >= line.n then
        return P2_current + 250
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

function calculate.synchronized_extratime_2(line_context, progression_const, fade_dur, avg_char_width, max_added_time, delay, max_gap_threshold, extra)
    local progression_const = progression_const or 0
    local fade_dur = fade_dur or 0
    local avg_char_width = avg_char_width or 15
    local max_added_time = max_added_time or 2000
    local max_gap_threshold = max_gap_threshold or 3000
    local delay = delay or 250
    local extra = extra or 250

    local line = line_context.line
    local l = line_context.l
    local linefx = line_context.linefx
    local idx_line = line_context.idx_line
    local count_line_dialogue = line_context.count_line_dialogue
    local ini_line = line_context.ini_line
    local current_char_count = unicode.len((line.text_stripped:gsub(" ", "")))
    local P2_current = progression_const * (current_char_count > 1 and current_char_count - 1 or 0) + extra
    
    if line.i >= line.n then
        return P2_current
    end

    local next_line_index_in_selection = line.i + 1
    local next_line_index_in_file = idx_line[next_line_index_in_selection]
    local next_line_index_in_linefx = next_line_index_in_file + count_line_dialogue - ini_line
    local next_line = linefx[next_line_index_in_linefx]
    if not next_line then return P2_current end
    
    local gap_between_lines = next_line.start_time - l.end_time
    
    if gap_between_lines < delay then
        return 0
    end
    
    if gap_between_lines > max_gap_threshold then
        return P2_current
    end
    
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
    
function text.clean_cache()
    _G.Effector_Shape_Cache = {}
    if collectgarbage then collectgarbage() end
end

function text.contorno_to_pixels( Text, Shape, Pixel, Seed, Bord, Filter, Scale )
local text_2bord = Text or val_text
    
local size_pixel = (type(Pixel) == "number" and Pixel > 0) and Pixel or 1
local size_pixel_sq = size_pixel * size_pixel
local seed_space = Seed or 1
local text_scale = Scale or 1
    
local points = recall.txtpnt_exterior_multisyl
   
if j == 1 then
    if ke and ke.infofx then
        ke.infofx.l = {}
        ke.infofx.l.style = L 
        ke.infofx.l.text_raw = l.text
        ke.infofx.fx = fx
    end
        
    local success_raw, raw_code = pcall(function() 
        return ke.text.to_shape( text_2bord, text_scale, true ) 
    end)

    if not success_raw or not raw_code or raw_code:gsub("%s", "") == "" then
        points = remember( "txtpnt_exterior_multisyl", {} )
    else
        local shapes_list = {}

        for part in raw_code:gmatch("m[^m]+") do
            local min_x, max_x = 99999, -99999
            local min_y, max_y = 99999, -99999

            for x, y in part:gmatch("([%-%d%.]+)%s+([%-%d%.]+)") do
                local nx, ny = tonumber(x), tonumber(y)
                if nx and ny then
                    if nx < min_x then min_x = nx end
                    if nx > max_x then max_x = nx end
                    if ny < min_y then min_y = ny end
                    if ny > max_y then max_y = ny end
                end
            end
              
            if min_x ~= 99999 then
                table.insert(shapes_list, {
                    code = part,
                    area = (max_x - min_x) * (max_y - min_y),
                    x1 = min_x, x2 = max_x,
                    y1 = min_y, y2 = max_y
                })
            end
        end

        local outer_shapes = {}
          
        for i, s1 in ipairs(shapes_list) do
            local is_hole = false
            for k, s2 in ipairs(shapes_list) do
                if i ~= k and s1.area < s2.area then
                    if s1.x1 >= s2.x1 and s1.x2 <= s2.x2 and
                        s1.y1 >= s2.y1 and s1.y2 <= s2.y2 then
                        is_hole = true
                        break
                    end
                end
            end
            if not is_hole then
                table.insert(outer_shapes, s1.code)
            end
        end

        local all_clean_points = {}

        local delta_x = fx.pos_x - (val_width / 2)
        local delta_y = fx.pos_y - (val_height / 2)
        local resolution = math.max(1, size_pixel * 0.4)
            
        for _, shape_code in ipairs(outer_shapes) do

            local my_shape = ke.shape.new(shape_code)
            my_shape = my_shape:displace(delta_x, delta_y)
                
            local success_red, res_red = pcall(function() return my_shape:redraw(resolution, "syl") end)
                
            if success_red and res_red then
                local raw_points = res_red:points()
                local current_points = {}
                local last_p = nil

                for i = 1, #raw_points do
                    local p = raw_points[i]
                    if p and p.x == p.x then
                        local guardar = true
                        if last_p then
                            local dx = p.x - last_p.x
                            local dy = p.y - last_p.y
                            if (dx*dx + dy*dy) < (size_pixel_sq * 0.25) then
                                guardar = false
                            end
                        end
                        if guardar then
                            table.insert(current_points, p)
                            last_p = p
                        end
                    end
                end

                if #current_points > 5 then
                    local p_start = current_points[1]
                    for k = #current_points, math.max(2, #current_points - 8), -1 do
                        local p_end = current_points[k]
                        local dx = p_end.x - p_start.x
                        local dy = p_end.y - p_start.y
                        if (dx*dx + dy*dy) < (size_pixel_sq * 5) then 
                            table.remove(current_points, k)
                        end
                    end
                end

                for _, p in ipairs(current_points) do
                    table.insert(all_clean_points, p)
                end
            end
        end
            
        points = remember( "txtpnt_exterior_multisyl", all_clean_points )
    end
end
    
    maxloop( #points )
    
    -- SALIDA
    if points and #points > 0 then
        if not points[j] then return "" end 
        
        local final_x = points[j].x
        local final_y = points[j].y
        
        if Shape then
            if type( Shape ) == "function" then
                bord_shape = Shape( )
            elseif type( Shape ) == "table" then
                bord_shape = Shape[ math.i( j, #Shape )[ "1-->A" ] ]
            else
                bord_shape = Shape
            end
        else
            bord_shape = shape.pixel
        end

        if Filter then
            local temp_pts = { points[j] } 
            local filtered_pos = Filter( temp_pts ) 
            if filtered_pos then 
                return format( "{%s\\p1%s}%s", filtered_pos, extra_tags or "", bord_shape )
            end
            final_x = points[j].x
            final_y = points[j].y
        end

        local bordpixel_pos = effector.new_pos( final_x, final_y )
        fx.pos_x, fx.pos_y = final_x, final_y
        
        if R( seed_space ) == 1 then
            if posgroup and posgroup() then
                return format( "{%s\\p1%s}%s", bordpixel_pos, extra_tags or "", bord_shape )
            end
            return format( "{%s\\p1%s}%s", bordpixel_pos, extra_tags or "", bord_shape )
        end
    end
    return ""
end

--=====================================================================================================--
-- FUNCIÓN MEJORADA: text.bord_to_pixels_v2 
-- Conserva la geometría del texto usando un pre-redibujado interno
-- antes de extraer y espaciar los puntos. Usa motor: newkara_library.
-- Suele secuestrar maxloop si usas más de un replay, por lo que recomiendo
-- llamarla con (J == 1 and text.bord_to_pixels_5(...) or "") para evitarlo.
--=====================================================================================================--

function text.bord_to_pixels_v2(Text, Shape, Pixel, RedrawDist, Seed, Bord, Filter, Scale)
    local text_2bord = Text or val_text
    local bord_shape
    
    local size_pixel = (type(Pixel) == "number" and Pixel > 0) and Pixel or 1
    
    local redraw_dist = (type(RedrawDist) == "number" and RedrawDist > 0) and RedrawDist or 1
    
    local seed_space = Seed or 1
    local text_scale = Scale or 1
    
    local points = recall.txtpnt_final_v5

    if j == 1 then
        local is_shape = false
        local clean_txt = text_2bord:gsub("%b{}", ""):gsub("^%s+", "")
        
        if clean_txt:match("^m%s+%-?%d") then
            is_shape = true
        end

        local shape_template
        if is_shape then
            shape_template = text_scale ~= 1 and shape.ratio(text_2bord, text_scale) or text_2bord
        else
            local fn = l.fontname or "Arial"
            local fs = l.fontsize or 20
            local b  = tostring(l.bold or false)
            local i_tag = tostring(l.italic or false)
            local sp = l.spacing or 0
            local scx = l.scale_x or 100

            local cache_key_template = string.format("shp_tpl_v5_%s_sc%.2f_fn%s_fs%.1f_b%s_i%s_sp%.1f_sx%.1f", 
                text_2bord, text_scale, fn, fs, b, i_tag, sp, scx)
            
            shape_template = recall[cache_key_template]
            
            if not shape_template then
                local success, raw_shape_code = pcall(function()
                    if ke and ke.infofx then
                        ke.infofx.l = { style = L, text_raw = l.text }
                        ke.infofx.fx = fx
                    end
                    return ke.text.to_shape(text_2bord, text_scale, true)
                end)
                
                if not success or not raw_shape_code or raw_shape_code:gsub("%s", "") == "" then
                    shape_template = remember(cache_key_template, "m 0 0")
                else
                    shape_template = remember(cache_key_template, raw_shape_code)
                end
            end
        end

        local delta_x = fx.pos_x - (val_width / 2)
        local delta_y = fx.pos_y - (val_height / 2)

        local success_shape, my_shape = pcall(function() 
            local temp_shape = ke.shape.new(shape_template)
            return temp_shape:displace(delta_x, delta_y)
        end)

        if success_shape and my_shape then
            local success_red, res_red = pcall(function() return my_shape:redraw(redraw_dist, "syl") end)
            
            if success_red and res_red then
                local raw_points = res_red:points()
                local clean_points = {}
                local last_p = nil
                local size_pixel_sq = size_pixel * size_pixel
                
                for i = 1, #raw_points do
                    local p = raw_points[i]
                    if p and p.x == p.x and p.y == p.y then 
                        local guardar = true

                        if last_p then
                            local dx = p.x - last_p.x
                            local dy = p.y - last_p.y
                            if (dx*dx + dy*dy) < size_pixel_sq then
                                guardar = false
                            end
                        end
                        
                        if guardar then
                            table.insert(clean_points, p)
                            last_p = p
                        end
                    end
                end

                if #clean_points > 1 then
                    local first, last = clean_points[1], clean_points[#clean_points]
                    local dx, dy = first.x - last.x, first.y - last.y
                    if (dx*dx + dy*dy) < (size_pixel_sq * 0.25) then
                        table.remove(clean_points, #clean_points)
                    end
                end
                
                points = remember("txtpnt_final_v5", clean_points)
            else
                points = remember("txtpnt_final_v5", {})
            end
        else
            points = remember("txtpnt_final_v5", {})
        end
        
        maxloop(#points)
    end

    -- Output
    if points and #points > 0 then
        if not points[j] then return "" end
        
        if Shape then
            if type(Shape) == "function" then bord_shape = Shape()
            elseif type(Shape) == "table" then bord_shape = Shape[math.i(j, #Shape)["1-->A"]]
            else bord_shape = Shape end
        else
            bord_shape = shape.pixel
        end
        
        local final_x = points[j].x
        local final_y = points[j].y

        if Filter then
             local temp_pts = { points[j] } 
             local filtered_pos = Filter( temp_pts ) 
             if filtered_pos then 
                 return string.format("{%s\\p1%s}%s", filtered_pos, extra_tags or "", bord_shape)
             end
             final_x = points[j].x
             final_y = points[j].y
        end

        local bordpixel_pos = effector.new_pos(final_x, final_y)
        fx.pos_x, fx.pos_y = final_x, final_y
        
        if R(seed_space) == 1 then
            if posgroup and posgroup() then
                return string.format("{%s\\p1%s}%s", bordpixel_pos, extra_tags or "", bord_shape)
            end
            return string.format("{%s\\p1%s}%s", bordpixel_pos, extra_tags or "", bord_shape)
        end
    end
    
    return ""
end

function text.bord_to_pixels_5(Text, Shape, Pixel, RedrawDist, Seed, Bord, Filter, Scale)
    local text_2bord = Text or val_text
    local bord_shape
    
    local size_pixel = (type(Pixel) == "number" and Pixel > 0) and Pixel or 1
    
    local redraw_dist = (type(RedrawDist) == "number" and RedrawDist > 0) and RedrawDist or 1
    
    local seed_space = Seed or 1
    local text_scale = Scale or 1
    
    local points = recall.txtpnt_final_v5

    if j == 1 then
        local is_shape = false
        local clean_txt = text_2bord:gsub("%b{}", ""):gsub("^%s+", "")
        
        if clean_txt:match("^m%s+%-?%d") then
            is_shape = true
        end

        local shape_template
        if is_shape then
            shape_template = text_scale ~= 1 and shape.ratio(text_2bord, text_scale) or text_2bord
        else
            local fn = l.fontname or "Arial"
            local fs = l.fontsize or 20
            local b  = tostring(l.bold or false)
            local i_tag = tostring(l.italic or false)
            local sp = l.spacing or 0
            local scx = l.scale_x or 100

            local cache_key_template = string.format("shp_tpl_v5_%s_sc%.2f_fn%s_fs%.1f_b%s_i%s_sp%.1f_sx%.1f", 
                text_2bord, text_scale, fn, fs, b, i_tag, sp, scx)
            
            shape_template = recall[cache_key_template]
            
            if not shape_template then
                local success, raw_shape_code = pcall(function()
                    if ke and ke.infofx then
                        ke.infofx.l = { style = L, text_raw = l.text }
                        ke.infofx.fx = fx
                    end
                    return ke.text.to_shape(text_2bord, text_scale, true)
                end)
                
                if not success or not raw_shape_code or raw_shape_code:gsub("%s", "") == "" then
                    shape_template = remember(cache_key_template, "m 0 0")
                else
                    shape_template = remember(cache_key_template, raw_shape_code)
                end
            end
        end

        local delta_x = fx.pos_x - (val_width / 2)
        local delta_y = fx.pos_y - (val_height / 2)

        local success_shape, my_shape = pcall(function() 
            local temp_shape = ke.shape.new(shape_template)
            return temp_shape:displace(delta_x, delta_y)
        end)

        if success_shape and my_shape then
            local success_red, res_red = pcall(function() return my_shape:redraw(redraw_dist, "syl") end)
            
            if success_red and res_red then
                local raw_points = res_red:points()
                local clean_points = {}
                local last_p = nil
                local size_pixel_sq = size_pixel * size_pixel
                
                for i = 1, #raw_points do
                    local p = raw_points[i]
                    if p and p.x == p.x and p.y == p.y then 
                        local guardar = true

                        if last_p then
                            local dx = p.x - last_p.x
                            local dy = p.y - last_p.y
                            if (dx*dx + dy*dy) < size_pixel_sq then
                                guardar = false
                            end
                        end
                        
                        if guardar then
                            table.insert(clean_points, p)
                            last_p = p
                        end
                    end
                end

                if #clean_points > 1 then
                    local first, last = clean_points[1], clean_points[#clean_points]
                    local dx, dy = first.x - last.x, first.y - last.y
                    if (dx*dx + dy*dy) < (size_pixel_sq * 0.25) then
                        table.remove(clean_points, #clean_points)
                    end
                end
                
                points = remember("txtpnt_final_v5", clean_points)
            else
                points = remember("txtpnt_final_v5", {})
            end
        else
            points = remember("txtpnt_final_v5", {})
        end
        
        maxloop(#points)
    end

    -- Output
    if points and #points > 0 then
        if not points[j] then return "" end
        
        if Shape then
            if type(Shape) == "function" then bord_shape = Shape()
            elseif type(Shape) == "table" then bord_shape = Shape[math.i(j, #Shape)["1-->A"]]
            else bord_shape = Shape end
        else
            bord_shape = shape.pixel
        end
        
        local final_x = points[j].x
        local final_y = points[j].y

        if Filter then
             local temp_pts = { points[j] } 
             local filtered_pos = Filter( temp_pts ) 
             if filtered_pos then 
                 return string.format("{%s\\p1%s}%s", filtered_pos, extra_tags or "", bord_shape)
             end
             final_x = points[j].x
             final_y = points[j].y
        end

        local bordpixel_pos = effector.new_pos(final_x, final_y)
        fx.pos_x, fx.pos_y = final_x, final_y
        
        if R(seed_space) == 1 then
            if posgroup and posgroup() then
                return string.format("{%s\\p1%s}%s", bordpixel_pos, extra_tags or "", bord_shape)
            end
            return string.format("{%s\\p1%s}%s", bordpixel_pos, extra_tags or "", bord_shape)
        end
    end
    
    return ""
end

--[[ shape.unite
  Une dos o más shapes en una sola forma compuesta, eliminando los contornos internos.
  Utiliza la operación de unión booleana de la librería Clipper a través de newkara_library.
  - Emula: Pathfinder > Unite en Adobe Illustrator o la funcionalidad equivalente en Shapery.

  @param ... (strings/tablas de strings) Una secuencia de shapes en formato ASSDraw.
             Puede ser `shape.unite(shp1, shp2, shp3)` o `shape.unite({shp1, shp2, shp3})`.
  @return (string) Una única shape en formato ASSDraw que representa la unión de todas las shapes de entrada.
                  Retorna una string vacía si no se proporcionan shapes válidas.
--]]
function shape.unite(...)
    local shapes_to_process = {...}
    if #shapes_to_process == 1 and type(shapes_to_process[1]) == "table" then
        shapes_to_process = shapes_to_process[1]
    end

    if #shapes_to_process == 0 then return "" end
    if #shapes_to_process == 1 then return shapes_to_process[1] or "" end

    local accumulated_shape_code
    local first_valid_index = 0
    for i = 1, #shapes_to_process do
        if type(shapes_to_process[i]) == "string" and shapes_to_process[i]:gsub("%s", "") ~= "" then
            accumulated_shape_code = shapes_to_process[i]
            first_valid_index = i
            break
        else
            aegisub.debug.out(string.format("shape.unite: Ignorando shape inválida o vacía en el índice %d.\n", i))
        end
    end

    if not accumulated_shape_code then return "" end

    for i = first_valid_index + 1, #shapes_to_process do
        local next_shape_code = shapes_to_process[i]
        if type(next_shape_code) == "string" and next_shape_code:gsub("%s", "") ~= "" then
            local success, result_shape_obj = pcall(ke.shape.clipper.boolean, accumulated_shape_code, next_shape_code, "union")
            
            if success and result_shape_obj and result_shape_obj.code then
                accumulated_shape_code = result_shape_obj.code
            else
                aegisub.debug.out(string.format("shape.unite: Error en la operación de unión con la shape en el índice %d. Puede que la geometría sea inválida.\n", i))
            end
        else
            aegisub.debug.out(string.format("shape.unite: Ignorando shape inválida o vacía en el índice %d.\n", i))
        end
    end

    return accumulated_shape_code
end


--[[ shape.difference
  Sustrae una o más shapes (B, C, ...) de una shape base (A).
  Utiliza la operación de diferencia booleana de la librería Clipper.
  - Emula: Pathfinder > Minus Front / Difference en Adobe Illustrator o Shapery.

  @param ... (strings/tablas de strings) La primera shape es la base de la que se sustraerá.
             Las shapes subsecuentes son las que se restarán.
             Puede ser `shape.difference(base, cortador1, cortador2)` o `shape.difference({base, cortador1, ...})`.
  @return (string) Una única shape en formato ASSDraw que representa el resultado de la sustracción.
                  Retorna una string vacía si la operación resulta en una forma vacía.
--]]
function shape.difference(...)
    local shapes_to_process = {...}
    if #shapes_to_process == 1 and type(shapes_to_process[1]) == "table" then
        shapes_to_process = shapes_to_process[1]
    end

    if #shapes_to_process < 2 then
        return shapes_to_process[1] or ""
    end

    local accumulated_shape_code
    local first_valid_index = 0
    for i = 1, #shapes_to_process do
        if type(shapes_to_process[i]) == "string" and shapes_to_process[i]:gsub("%s", "") ~= "" then
            accumulated_shape_code = shapes_to_process[i]
            first_valid_index = i
            break
        else
            aegisub.debug.out(string.format("shape.difference: Ignorando shape base inválida en el índice %d.\n", i))
        end
    end

    if not accumulated_shape_code then return "" end

    for i = first_valid_index + 1, #shapes_to_process do
        local cutter_shape_code = shapes_to_process[i]
        if type(cutter_shape_code) == "string" and cutter_shape_code:gsub("%s", "") ~= "" then
            local success, result_shape_obj = pcall(ke.shape.clipper.boolean, accumulated_shape_code, cutter_shape_code, "difference")
            
            if success and result_shape_obj and result_shape_obj.code then
                accumulated_shape_code = result_shape_obj.code
            else
                aegisub.debug.out(string.format("shape.difference: Error en la operación de diferencia con la shape en el índice %d.\n", i))
            end
        else
            aegisub.debug.out(string.format("shape.difference: Ignorando shape de corte inválida en el índice %d.\n", i))
        end
    end

    return accumulated_shape_code
end

--[[ shape.intersect
  Calcula la intersección de dos o más shapes, devolviendo solo el área común.
  Utiliza la operación de intersección booleana de la librería Clipper.
  - Emula: Pathfinder > Intersect en Adobe Illustrator o Shapery.

  @param ... (strings/tablas de strings) Una secuencia de shapes en formato ASSDraw a intersectar.
  @return (string) Una única shape en formato ASSDraw que representa el área de solapamiento.
--]]
function shape.intersect(...)
    local shapes_to_process = {...}
    if #shapes_to_process == 1 and type(shapes_to_process[1]) == "table" then
        shapes_to_process = shapes_to_process[1]
    end

    if #shapes_to_process < 2 then
        return shapes_to_process[1] or ""
    end

    local accumulated_shape_code
    local first_valid_index = 0
    for i = 1, #shapes_to_process do
        if type(shapes_to_process[i]) == "string" and shapes_to_process[i]:gsub("%s", "") ~= "" then
            accumulated_shape_code = shapes_to_process[i]
            first_valid_index = i
            break
        else
            aegisub.debug.out(string.format("shape.intersect: Ignorando shape base inválida en el índice %d.\n", i))
        end
    end

    if not accumulated_shape_code then return "" end

    for i = first_valid_index + 1, #shapes_to_process do
        local next_shape_code = shapes_to_process[i]
        if type(next_shape_code) == "string" and next_shape_code:gsub("%s", "") ~= "" then
            local success, result_shape_obj = pcall(ke.shape.clipper.boolean, accumulated_shape_code, next_shape_code, "intersection")
            
            if success and result_shape_obj and result_shape_obj.code then
                accumulated_shape_code = result_shape_obj.code
            else
                return "" 
            end
        else
            aegisub.debug.out(string.format("shape.intersect: Ignorando shape inválida en el índice %d.\n", i))
        end
    end
    
    return accumulated_shape_code
end

--[[ shape.exclude
  Calcula la diferencia simétrica (XOR) de dos o más shapes. Mantiene todas las áreas
  excepto aquellas donde las formas se superponen.
  Utiliza la operación XOR booleana de la librería Clipper.
  - Emula: Pathfinder > Exclude en Adobe Illustrator o Shapery.

  @param ... (strings/tablas de strings) Una secuencia de shapes en formato ASSDraw a procesar.
  @return (string) Una única shape en formato ASSDraw que representa el área no común.
--]]
function shape.exclude(...)
    local shapes_to_process = {...}
    if #shapes_to_process == 1 and type(shapes_to_process[1]) == "table" then
        shapes_to_process = shapes_to_process[1]
    end

    -- Casos base
    if #shapes_to_process < 2 then
        return shapes_to_process[1] or ""
    end

    local accumulated_shape_code
    local first_valid_index = 0
    for i = 1, #shapes_to_process do
        if type(shapes_to_process[i]) == "string" and shapes_to_process[i]:gsub("%s", "") ~= "" then
            accumulated_shape_code = shapes_to_process[i]
            first_valid_index = i
            break
        else
            aegisub.debug.out(string.format("shape.exclude: Ignorando shape base inválida en el índice %d.\n", i))
        end
    end

    if not accumulated_shape_code then return "" end

    for i = first_valid_index + 1, #shapes_to_process do
        local next_shape_code = shapes_to_process[i]
        if type(next_shape_code) == "string" and next_shape_code:gsub("%s", "") ~= "" then
            local success, result_shape_obj = pcall(ke.shape.clipper.boolean, accumulated_shape_code, next_shape_code, "xor")
            
            if success and result_shape_obj and result_shape_obj.code then
                accumulated_shape_code = result_shape_obj.code
            else
                 aegisub.debug.out(string.format("shape.exclude: Error en la operación XOR con la shape en el índice %d.\n", i))
            end
        else
            aegisub.debug.out(string.format("shape.exclude: Ignorando shape inválida en el índice %d.\n", i))
        end
    end
    
    return accumulated_shape_code
end

--------------------------------------------------------------------------------
	-- TEXT.TO_SHAPE_2:
	--------------------------------------------------------------------------------
	function text.to_shape_2( Text, Scale, Tags, Offset )
		local Text = Text or val_text
		while Text:sub( -1, -1 ) == " " do Text = Text:sub( 1, -2 ) end
		
		local text_scale = Scale or 1
		local shape_scale = math.round( math.log( text_scale, 2 ) + 1 )
		
		local base_fn = l.fontname or "Arial"
		local base_fs = l.fontsize or 20
		local base_b  = l.bold or false
		local base_i  = l.italic or false
		local base_u  = l.underline or false
		local base_s  = l.strikeout or false
		local base_scx = l.scale_x or 100
		local base_scy = l.scale_y or 100
		local base_sp  = l.spacing or 0

		local tagx = Text:match( "%b{}" )
		
		local fn = (tagx and tagx:match("\\fn([^\\}]+)")) or base_fn
		
		local fs_match = tagx and tagx:match("\\fs(%d+[%.%d]*)")
		local fs = (fs_match and tonumber(fs_match)) or base_fs
		if not fs or fs <= 0 then fs = 20 end
		
		local b_tag = tagx and tagx:match("\\b([01])")
		local b = b_tag and (b_tag == "1") or base_b
		
		local i_tag = tagx and tagx:match("\\i([01])")
		local i = i_tag and (i_tag == "1") or base_i
		
		local u_tag = tagx and tagx:match("\\u([01])")
		local u = u_tag and (u_tag == "1") or base_u
		
		local s_tag = tagx and tagx:match("\\s([01])")
		local s = s_tag and (s_tag == "1") or base_s

		local scx_match = tagx and tagx:match("\\fscx(%d+[%.%d]*)")
		local scx = (scx_match and tonumber(scx_match)) or base_scx
		
		local scy_match = tagx and tagx:match("\\fscy(%d+[%.%d]*)")
		local scy = (scy_match and tonumber(scy_match)) or base_scy
		
		local sp_match = tagx and tagx:match("\\fsp(%-?%d+[%.%d]*)")
		local sp = (sp_match and tonumber(sp_match)) or base_sp

		local cache_key = string.format("TXT:%s|S:%.3f|FN:%s|FS:%.2f|B:%s|I:%s|U:%s|S:%s|X:%.1f|Y:%.1f|SP:%.2f", 
			Text:gsub("%b{}", ""),
			text_scale, 
			fn, fs, 
			tostring(b), tostring(i), tostring(u), tostring(s), 
			scx, scy, sp
		)

		local text_shape = _G.Effector_Shape_Cache[cache_key]

		if not text_shape then
			local text_confi = {
				[1] = fn,
				[2] = b,
				[3] = i,
				[4] = u,
				[5] = s,
				[6] = fs,
				[7] = text_scale * scx / 100,
				[8] = text_scale * scy / 100,
				[9] = sp
			}
			
			local success, raw_shape = pcall(function() 
				local text_font = Yutils.decode.create_font( unpack( text_confi ) )

				return shape.ASSDraw3( text_font.text_to_shape( Text ) )
			end)
			
			if success and raw_shape then
				text_shape = raw_shape
				_G.Effector_Shape_Cache[cache_key] = text_shape
			else
				_G.Effector_Shape_Cache[cache_key] = ""
				return ""
			end
		end

		if text_shape ~= "" then
			local text_off_x = 0
			local text_off_y = 0
			
			if not Offset then
				local w_s = shape.width( text_shape )
				local h_s = shape.height( text_shape )
				
				local w_t = text_scale * aegisub.width( text.remove_tags( Text ) )
				local h_t = text_scale * aegisub.height( text.remove_tags( Text ) )
				
				text_off_x = 0.5 * (w_s - w_t)
				text_off_y = 0.5 * (h_s - h_t)
			end
			
			local final_shape = shape.displace( text_shape, text_off_x, text_off_y )
			
			if Tags then
				return format( "{\\p%d%s}%s", shape_scale, extra_tags or "", final_shape )
			end
			return final_shape
		end
		
		return ""
	end
	
	--------------------------------------------------------------------------------
	-- TEXT.TO_CLIP: Wrapper
	--------------------------------------------------------------------------------
	
	function text.to_clip_2( Text, relative_pos, iclip, Scale )
		local Text = Text or val_text
		local text_scale = Scale or 1
		

		local angle = 0
		if Text:match( "%b{}" ) then
			local tagsx = Text:match( "%b{}" )
			local frz = tagsx:match( "\\fr[z]*(%-?%d[%.%d]*)" )
			if frz then angle = tonumber(frz) end
		end
		

		local clip_shape = text.to_shape_2( Text, text_scale, nil, true )
		
		if clip_shape ~= "" then
			-- Rotar
			if angle ~= 0 then
				clip_shape = shape.rotate( clip_shape, angle, "center" )
			end
		
			-- Desplazar
			local final_clip
			if relative_pos then

				final_clip = shape.displace( clip_shape, val_left, val_top )
			else

				final_clip = shape.displace( clip_shape, fx.move_l1, fx.move_t1 )
			end
			
			local text_mode = iclip and "i" or ""
			return format( "\\%sclip(%s)%s", text_mode, final_clip, extra_tags or "" )
		end
		
		return ""
	end

--=============================================================================--
-- COLOR.SET_2
--=============================================================================--
function color.set_2(Times, Colors, Tag, d_manual)
    local Tag = Tag or "\\1c"
    local output = ""

    local inicio_real = l_start - (d_manual or 0)
    
    if type(Colors) ~= "table" then Colors = {Colors} end
    
    for i = 1, #Times do
        local entry = Times[i]
        local t_glob, t_dur, t_acc = 0, 0, 1
        
        if type(entry) == "table" then
            t_glob, t_dur, t_acc = entry[1], entry[2] or 0, entry[3] or 1
        else
            t_glob = entry
        end

        if type(t_glob) == "string" then t_glob = HMS_to_ms(t_glob) end

        local t1 = t_glob - inicio_real
        local t2 = t1 + t_dur
        
        output = output .. string.format("\\t(%.1f,%.1f,%s,%s%s)", t1, t2, t_acc, Tag, Colors[(i-1)%#Colors+1])
    end
    return output
end

-- ============================================================================
-- FUNCIÓN: shape.custom_clip 
-- Permite usar cualquier shape como máscara de corte (diferencia, intersección, etc)
-- ============================================================================
function shape.custom_clip(subject_shp, mask_shp, operation)
    local op = operation or "difference"
    
    -- Validar inputs
    local subject_code = type(subject_shp) == "table" and subject_shp.code or subject_shp
    local mask_code = type(mask_shp) == "table" and mask_shp.code or mask_shp
    
    if type(subject_code) ~= "string" or subject_code:gsub("%s", "") == "" then return "" end
    if type(mask_code) ~= "string" or mask_code:gsub("%s", "") == "" then 
        return op == "difference" and subject_code or "" 
    end
    
    local success, result = pcall(function()
        return ke.shape.clipper.boolean(subject_code, mask_code, op, "evenodd")
    end)
    
    if not success then
        aegisub.debug.out(string.format("shape.custom_clip Error (%s): %s\n", op, tostring(result)))
        return subject_code
    end
    
    local result_code = type(result) == "table" and result.code or result
    
    if type(result_code) ~= "string" or result_code:gsub("%s", "") == "" then
        return "" 
    end
    
    return result_code
end

	-- Pensé que mejor armar un wrapper que seguir repitiendo lo mismo.
	-- Wrapper de alto rendimiento para convertir texto a vector (ASSDraw)
	-- Utiliza newkara_library (ILL) con caché dinámico absoluto y centrado automático.
	
	function text.to_shape_ill( Text, Scale )
    if type( Text ) == "function" then Text = Text( ) end
    if type( Scale ) == "function" then Scale = Scale( ) end
    
    local input_str = Text or val_text
    if type(input_str) ~= "string" or input_str == "" then return "m 0 0" end

    local text_scale = tonumber( Scale ) or 1
    
    local fn = L.fontname or "Arial"
    local fs = L.fontsize or 20
    local b  = tostring(L.bold or false)
    local i_tag = tostring(L.italic or false)
    local sp = L.spacing or 0
    local scx = L.scale_x or 100

    -- Caché
    local cache_key = string.format("shp_ill_v1_%s_sc%.2f_fn%s_fs%.1f_b%s_i%s_sp%.1f_sx%.1f", 
        input_str, text_scale, fn, fs, b, i_tag, sp, scx)

    local final_shape = recall[cache_key]

    if not final_shape then
        local raw_shape_code = ""
        local is_shape = false

        local clean_txt = input_str:gsub("%b{}", ""):gsub("^%s+", "")
        
        -- Verifica tipo
        if clean_txt:match("^m%s+%-?%d") then
            is_shape = true
            raw_shape_code = text_scale ~= 1 and shape.ratio(input_str, text_scale) or shape.ASSDraw3(input_str)
        else
            local success, txt_shape_code = pcall(function()
                if ke and ke.infofx then
                    ke.infofx.l = { style = L, text_raw = l.text }
                    ke.infofx.fx = fx
                end
                return ke.text.to_shape(input_str, text_scale, true)
            end)
            if success and type(txt_shape_code) == "string" and txt_shape_code:gsub("%s", "") ~= "" then
                raw_shape_code = txt_shape_code
            else
                raw_shape_code = "m 0 0"
            end
        end

        -- Aplica desplazamiento unificado
        local delta_x, delta_y

        if input_str == val_text or is_shape then
            delta_x = -(val_width * text_scale) / 2
            delta_y = -(val_height * text_scale) / 2
        else
            local clean_text = text.remove_tags(input_str)
            local tw, th = aegisub.text_extents(L, clean_text)
            delta_x = -(tw * text_scale) / 2
            delta_y = -(th * text_scale) / 2
        end

        local ok_disp, my_shape = pcall(function() 
            return ke.shape.new(raw_shape_code):displace(delta_x, delta_y)
        end)
        
        if ok_disp and my_shape then
            final_shape = remember(cache_key, my_shape.code)
        else
            final_shape = remember(cache_key, raw_shape_code)
        end
    end

    return final_shape
end

-- ============================================================================
-- FUNCIÓN: shape.borders y shape.filled_borders
-- Toma un shape o texto y crea shapes de su borde tantas veces como sea
-- solicitado, con la separación solicitada y el overlap solicitado.
-- Además, acepta tablas para espeficicar el intervalo de loop a utilizar
-- y la separación capa a capa.
-- ============================================================================


	function shape.borders( Shape_or_Text, Loops, Separation, Overlap, Scale )
		if type( Shape_or_Text ) == "function" then Shape_or_Text = Shape_or_Text( ) end
		if type( Loops ) == "function" then Loops = Loops( ) end
		if type( Separation ) == "function" then Separation = Separation( ) end
		if type( Overlap ) == "function" then Overlap = Overlap( ) end
		if type( Scale ) == "function" then Scale = Scale( ) end

		-- Wrapper
		local base_shape = text.to_shape_ill( Shape_or_Text, Scale )
		if not base_shape or base_shape == "" or base_shape == "m 0 0" then return "" end

		local start_loop, end_loop = 1, 1
		if type( Loops ) == "number" then
			end_loop = math.max( 1, math.floor( Loops ) )
		elseif type( Loops ) == "table" then
			start_loop = math.floor( Loops[ 1 ] or 1 )
			end_loop = math.floor( Loops[ 2 ] or start_loop )
		end

		if end_loop < 1 then return "" end

		local overlap_val = tonumber( Overlap ) or 0

		effector.print_error( Loops, "numbertable", "shape.borders", 2 )
		effector.print_error( Separation, "numbertable", "shape.borders", 3 )

		-- CACHÉ
		local rings_cache_key = "rings_" .. tostring( base_shape ) .. "_" .. start_loop .. "_" .. end_loop .. "_" .. (type( Separation ) == "table" and table.concat( Separation, "-" ) or tostring( Separation )) .. "_" .. tostring( overlap_val )
		
		local Rings = recall[rings_cache_key]
		
		if not Rings then
			Rings = { }
			local prev_dist = 0
			local cumulative_dist = 0

			-- Siempre calcula desde 1 para que las distancias de la tabla encajen
			for i = 1, end_loop do
				local dist = 5
				if type( Separation ) == "number" then
					dist = Separation
				elseif type( Separation ) == "table" then
					dist = Separation[ i ] or 5
				end
				
				cumulative_dist = prev_dist + math.abs( dist )
				
				-- Solo calculam booleanos si el borde entra en el rango visible
				if i >= start_loop then
					local outer_dist = cumulative_dist + overlap_val
					local inner_dist = prev_dist - overlap_val
					
					local outer_shape = outer_dist == 0 and base_shape or FX_ShpOffset( base_shape, outer_dist )
					local inner_shape = inner_dist == 0 and base_shape or FX_ShpOffset( base_shape, inner_dist )
					
					Rings[ i ] = FX_ShpBoolean( outer_shape, inner_shape, "difference" )
				end

				prev_dist = cumulative_dist
			end
			
			remember( rings_cache_key, Rings )
		end

		-- anillo del loop correspondiente
		if j >= start_loop and j <= end_loop then
			return Rings[ j ] or ""
		end

		return ""
	end

	-- Lo mismo, pero conservando el centro.
	-- Genera la forma base rellena en el loop 1, y bordes concéntricos en los loops sucesivos.

	function shape.filled_borders( Shape_or_Text, Loops, Separation, Overlap, Scale )
	
		if type( Shape_or_Text ) == "function" then Shape_or_Text = Shape_or_Text( ) end
		if type( Loops ) == "function" then Loops = Loops( ) end
		if type( Separation ) == "function" then Separation = Separation( ) end
		if type( Overlap ) == "function" then Overlap = Overlap( ) end
		if type( Scale ) == "function" then Scale = Scale( ) end

		-- Wrapper
		local base_shape = text.to_shape_ill( Shape_or_Text, Scale )
		if not base_shape or base_shape == "" or base_shape == "m 0 0" then return "" end

		local start_loop, end_loop = 1, 1
		if type( Loops ) == "number" then
			end_loop = math.max( 1, math.floor( Loops ) )
		elseif type( Loops ) == "table" then
			start_loop = math.floor( Loops[ 1 ] or 1 )
			end_loop = math.floor( Loops[ 2 ] or start_loop )
		end

		if end_loop < 1 then return "" end

		local overlap_val = tonumber( Overlap ) or 0

		effector.print_error( Loops, "numbertable", "shape.filled_borders", 2 )
		effector.print_error( Separation, "numbertable", "shape.filled_borders", 3 )

		-- CACHÉ
		local f_rings_cache_key = "f_rings_" .. tostring( base_shape ) .. "_" .. start_loop .. "_" .. end_loop .. "_" .. (type( Separation ) == "table" and table.concat( Separation, "-" ) or tostring( Separation )) .. "_" .. tostring( overlap_val )
		
		local Rings = recall[f_rings_cache_key]
		
		if not Rings then
			Rings = { }
			local prev_dist = 0
			local cumulative_dist = 0

			for i = 1, end_loop do
				if i == 1 then
					-- [ LOOP 1 ]: Es la forma original rellena
					if i >= start_loop then
						Rings[ i ] = overlap_val == 0 and base_shape or FX_ShpOffset( base_shape, overlap_val )
					end
				else
					-- [ LOOPS 2+ ]: Son los bordes (Loop 2 = Borde 1)
					local b_idx = i - 1
					local dist = 5
					if type( Separation ) == "number" then
						dist = Separation
					elseif type( Separation ) == "table" then
						dist = Separation[ b_idx ] or 5
					end
					
					cumulative_dist = prev_dist + math.abs( dist )
					
					if i >= start_loop then
						local outer_dist = cumulative_dist + overlap_val
						local inner_dist = prev_dist - overlap_val
						
						local outer_shape = outer_dist == 0 and base_shape or FX_ShpOffset( base_shape, outer_dist )
						local inner_shape = inner_dist == 0 and base_shape or FX_ShpOffset( base_shape, inner_dist )
						
						Rings[ i ] = FX_ShpBoolean( outer_shape, inner_shape, "difference" )
					end

					prev_dist = cumulative_dist
				end
			end
			
			remember( f_rings_cache_key, Rings )
		end

		-- anillo o relleno del loop correspondiente
		if j >= start_loop and j <= end_loop then
			return Rings[ j ] or ""
		end

		return ""
	end


--[[================================================================================================
	@function: (/> o <)/ shape.slice \(> w <\) Evolución de SLICE_RECT_CLIPPER ~~ Descansa en paz ~~
	@desc: Corta Shapes o Textos en rebanadas. Usa newkara_library para convertir el texto a vector, 
	       y los wrappers de newlib 3.6 (ILL) para la rotación y el recorte booleano.
	@args:
		1. Shape/Text : Texto crudo (Ej: syl.text) o ASSDraw.
		2. Slices     : (Num/Tab) Total de cortes (ej. 5) o intervalo de loops (ej. {3, 7}).
		3. Angle      : (Num) Ángulo de las cuchillas en grados (0=Vertical, 45=Diagonal).
		4. Overlap    : (Num/Tab) Sangrado (ej. 0.5) o {Sangrado, Separación} (ej. {0.5, 10} o {0.5, {10, -5}}).
		5. Accel      : (Num/Str) Progresión de los cortes (ej. 2 o "sin(%s*pi)"). 1 = equidistantes.
		6. Scale      : (Num/Tab) Escala base (ej. 1) o {Escala, Offset_Previo} (ej. {1, 3}).
		7. Mode       : "clip" Permite utilizar el modo clip para quitar marcadores fantasma.
		@ej: shape.slice( syl.text, {1, 5}, 45, {0.5, 15}, 1, {1, 4}, "clip" )
	==================================================================================================]]--
	function shape.slice( Shape_or_Text, Slices, Angle, Overlap, Accel, Scale, Mode )		
		local DEBUG_BLADE = false 
		
		if type( Shape_or_Text ) == "function" then Shape_or_Text = Shape_or_Text() end
		if type( Slices ) == "function" then Slices = Slices() end
		if type( Angle ) == "function" then Angle = Angle() end
		if type( Overlap ) == "function" then Overlap = Overlap() end
		if type( Accel ) == "function" then Accel = Accel() end
		if type( Scale ) == "function" then Scale = Scale() end
		if type( Mode ) == "function" then Mode = Mode() end
		
		-- Modo Clip
		local is_clip = (Mode == "clip" or Mode == true)

		-- Manejo de escala y offset pre-corte
		local text_scale = 1
		local pre_offset = 0
		if type( Scale ) == "table" then
			text_scale = tonumber( Scale[1] ) or 1
			pre_offset = tonumber( Scale[2] ) or 0
		elseif Scale ~= nil then
			text_scale = tonumber( Scale ) or 1
		end

		-- Manejo del modo avanzado (intervalo de loops)
		local start_loop, end_loop = 1, 1
		if type( Slices ) == "number" then
			end_loop = math.max( 1, math.floor( Slices ) )
		elseif type( Slices ) == "table" then
			start_loop = math.floor( Slices[ 1 ] or 1 )
			end_loop = math.max( start_loop, math.floor( Slices[ 2 ] or start_loop ) )
		end
		
		local n = end_loop - start_loop + 1
		if n < 1 then return "" end
		
		-- Valida que el loop (de j) esté dentro del intervalo solicitado
		if j < start_loop or j > end_loop then return "" end

		-- Obtiene la shape base
		local base_shape = text.to_shape_ill( Shape_or_Text, text_scale )
		if not base_shape or base_shape == "" or base_shape == "m 0 0" then 
			return is_clip and "m 0 0 l 1 0 l 1 1" or "" 
		end
		
		-- Aplica offset pre-corte
		if pre_offset ~= 0 then
			base_shape = FX_ShpOffset( base_shape, pre_offset )
			if not base_shape or base_shape == "" then 
				return is_clip and "m 0 0 l 1 0 l 1 1" or "" 
			end
        end

		local ang = tonumber( Angle ) or 0

		-- Manejo de Overlap y Separación
		local ov = 0
		local sep_val = 0
		local sep_x, sep_y = 0, 0
		local use_directional_sep = true

		if type( Overlap ) == "number" then
			ov = Overlap
		elseif type( Overlap ) == "table" then
			ov = tonumber( Overlap[1] ) or 0
			local sep_data = Overlap[2]
			if type( sep_data ) == "number" then
				sep_val = sep_data
			elseif type( sep_data ) == "table" then
				sep_x = tonumber( sep_data[1] ) or 0
				sep_y = tonumber( sep_data[2] ) or sep_x
				use_directional_sep = false
			end
		end

		-- Caché (la separación NO se incluye para poder animarla dinámicamente)
		local cache_key = string.format("slice_v12_%s_%d_%d_%.1f_%.2f_%s_%.2f_%s_%s", 
			base_shape, start_loop, end_loop, ang, ov, tostring(Accel), pre_offset, tostring(DEBUG_BLADE), tostring(is_clip))
			
		local Sliced_Pieces = recall[cache_key]
		
		if not Sliced_Pieces then
			Sliced_Pieces = {}
			local box = FX_ShpBox( base_shape )
			
			-- Los clips no necesitan marcadores
			local ghost_marker = is_clip and "" or string.format("m %.2f %.2f m %.2f %.2f ", box.x, box.y, box.x + box.w, box.y + box.h)
			
			if n == 1 and not DEBUG_BLADE then
				Sliced_Pieces[1] = ghost_marker .. base_shape
				remember( cache_key, Sliced_Pieces )
			else
				-- Mates de rotación
				local rad_a = math.rad(-ang)
				local cos_a = math.cos(rad_a)
				local sin_a = math.sin(rad_a)
				local cx, cy = box.cx, box.cy
				
				-- Proyección exacta de la caja
				local D = box.w * math.abs(cos_a) + box.h * math.abs(sin_a) + 0.1
				local H_ext = D + math.max(box.w, box.h) * 2 
				
				local function rot_point(lx, ly)
					local rx = lx * cos_a - ly * sin_a
					local ry = lx * sin_a + ly * cos_a
					return cx + rx, cy + ry
				end
				
				-- Aceleración
				local function get_pct(p)
					if type(Accel) == "string" then
						local alg = Accel
						if type(tonumber(alg)) == "number" then alg = "%s ^ " .. alg end
						
						local ok, res = pcall(math.format, alg, p)
						if ok and type(tonumber(res)) == "number" then
							return tonumber(res)
						end
						return p
					else
						local a = tonumber(Accel) or 1
						return p ^ a
					end
				end
				
				for i = 1, n do
					local pct_start = get_pct((i - 1) / n)
					local pct_end = get_pct(i / n)
					
					local l_left = -D/2 + (D * pct_start) - ov
					local l_right = -D/2 + (D * pct_end) + ov
					local l_top = -H_ext/2 - ov
					local l_bottom = H_ext/2 + ov
					
					local x1, y1 = rot_point(l_left, l_top)    
					local x2, y2 = rot_point(l_left, l_bottom) 
					local x3, y3 = rot_point(l_right, l_bottom)
					local x4, y4 = rot_point(l_right, l_top)   
					
					-- Dibujado de la cuchilla
					local mask_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
						x1, y1, x4, y4, x3, y3, x2, y2, x1, y1)
					
					if DEBUG_BLADE then
						Sliced_Pieces[i] = ghost_marker .. mask_code
					else
						local piece = FX_ShpBoolean( base_shape, mask_code, "intersection" )
						
						if piece and piece ~= "" and piece ~= "m 0 0" and not piece:match("nan") then
							Sliced_Pieces[i] = ghost_marker .. piece
						else
							-- Retorno
							Sliced_Pieces[i] = is_clip and "m 0 0 l 1 0 l 1 1" or ""
						end
					end
				end
				
				remember( cache_key, Sliced_Pieces )
			end
		end
		
		local current_slice_index = j - start_loop + 1
		local piece = Sliced_Pieces[current_slice_index] or (is_clip and "m 0 0 l 1 0 l 1 1" or "")
		
		-- Aplicar desplazamiento de expansión/separación dinámicamente
		if piece ~= "" and piece ~= "m 0 0 l 1 0 l 1 1" and (sep_val ~= 0 or sep_x ~= 0 or sep_y ~= 0) then
			local dist_multiplier = (current_slice_index - (n + 1) / 2)
			local dx, dy = 0, 0

			if use_directional_sep then
				local rad_a = math.rad(-ang)
				dx = dist_multiplier * sep_val * math.cos(rad_a)
				dy = dist_multiplier * sep_val * math.sin(rad_a)
			else
				dx = dist_multiplier * sep_x
				dy = dist_multiplier * sep_y
			end
			
			piece = shape.displace(piece, dx, dy)
		end

		return piece
	end


	--[[================================================================================================
	@function: (/> o <)/ shape.slice_grid \(> w <\) 
	@desc: Corta Shapes o Textos en una cuadrícula (grid) y permite separarlas de su centro.
	@args:
		1. Shape/Text : Texto crudo (Ej: syl.text) o ASSDraw.
		2. Slices     : (Num/Tab) Total de cortes. Si pasas 10, hará 5x5. Si pasas {cols, rows}.
		3. Overlap    : (Num) Sangrado de las cuchillas para evitar fisuras/huecos (ej. 0.5).
		4. Separation : (Num/Tab) (Opcional) Distancia para separar las piezas del centro.
		5. Scale      : (Num/Tab) Escala base (ej. 1) o {Escala, Offset_Previo} (ej. {1, 3}).
	@ej: shape.slice_grid( syl.text, {3, 3}, 0.5, 15, 1 ) -- Cuadrícula 3x3 separada 15px
	==================================================================================================]]--
	function shape.slice_grid( Shape_or_Text, Slices, Overlap, Separation, Scale )		
		if type( Shape_or_Text ) == "function" then Shape_or_Text = Shape_or_Text() end
		if type( Slices ) == "function" then Slices = Slices() end
		if type( Overlap ) == "function" then Overlap = Overlap() end
		if type( Separation ) == "function" then Separation = Separation() end
		if type( Scale ) == "function" then Scale = Scale() end
		
		-- Manejo de escala y offset pre-corte
		local text_scale = 1
		local pre_offset = 0
		if type( Scale ) == "table" then
			text_scale = tonumber( Scale[1] ) or 1
			pre_offset = tonumber( Scale[2] ) or 0
		elseif Scale ~= nil then
			text_scale = tonumber( Scale ) or 1
		end

		-- Determinación de columnas y filas
		local cols, rows = 1, 1
		if type( Slices ) == "number" then
			cols = math.max( 1, math.floor( Slices / 2 ) )
			rows = cols
		elseif type( Slices ) == "table" then
			cols = math.max( 1, math.floor( Slices[ 1 ] or 1 ) )
			rows = math.max( 1, math.floor( Slices[ 2 ] or cols ) )
		end
		
		local total_parts = cols * rows
		if total_parts < 1 then return "" end
		
		-- Valida que el loop actual (j) no sobrepase la cantidad de trozos
		if j < 1 or j > total_parts then return "" end

		-- Manejo de Separación
		local sep_x, sep_y = 0, 0
		if type( Separation ) == "number" then
			sep_x = Separation
			sep_y = Separation
		elseif type( Separation ) == "table" then
			sep_x = tonumber( Separation[1] ) or 0
			sep_y = tonumber( Separation[2] ) or sep_x
		end

		-- Obtiene la shape base
		local base_shape = text.to_shape_ill( Shape_or_Text, text_scale )
		if not base_shape or base_shape == "" or base_shape == "m 0 0" then return "" end
		
		-- Aplica offset pre-corte
		if pre_offset ~= 0 then
			base_shape = FX_ShpOffset( base_shape, pre_offset )
			if not base_shape or base_shape == "" then return "" end
		end

		local ov = tonumber( Overlap ) or 0

		-- Caché (la separación no se guarda en caché para poder animarla o alterarla rápido)
		local cache_key = string.format("slice_grid_v2_%s_%d_%d_%.2f_%.2f", 
			base_shape, cols, rows, ov, pre_offset)
			
		local Sliced_Pieces = recall[cache_key]
		
		if not Sliced_Pieces then
			Sliced_Pieces = {}
			local box = FX_ShpBox( base_shape )
			local ghost_marker = string.format("m %.2f %.2f m %.2f %.2f ", box.x, box.y, box.x + box.w, box.y + box.h)
			
			if total_parts == 1 then
				Sliced_Pieces[1] = ghost_marker .. base_shape
				remember( cache_key, Sliced_Pieces )
			else
				-- Mates de la grilla
				local cw = box.w / cols
				local ch = box.h / rows
				
				for r = 1, rows do
					for c = 1, cols do
						local idx = (r - 1) * cols + c
						
						-- Posiciones del recuadro (con sangrado)
						local x1 = box.x + (c - 1) * cw - ov
						local y1 = box.y + (r - 1) * ch - ov
						local x2 = box.x + c * cw + ov
						local y2 = box.y + r * ch + ov
						
						-- Dibujado horario {puto clipper}
						local mask_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
							x1, y1, x2, y1, x2, y2, x1, y2, x1, y1)
						
						local piece = FX_ShpBoolean( base_shape, mask_code, "intersection" )
						
						if piece and piece ~= "" and piece ~= "m 0 0" and not piece:match("nan") then
							Sliced_Pieces[idx] = ghost_marker .. piece
						else
							Sliced_Pieces[idx] = ""
						end
					end
				end
				remember( cache_key, Sliced_Pieces )
			end
		end
		
		local piece = Sliced_Pieces[j]
		if not piece or piece == "" then return "" end

		-- Aplicar desplazamiento de expansión/separación dinámicamente
		if sep_x ~= 0 or sep_y ~= 0 then
			-- Encontrar en qué columna y fila está la pieza `j`
			local c_actual = ((j - 1) % cols) + 1
			local r_actual = math.floor((j - 1) / cols) + 1
			
			-- Desplazar respecto al centro de la cuadrícula
			local dx = (c_actual - (cols + 1) / 2) * sep_x
			local dy = (r_actual - (rows + 1) / 2) * sep_y
			
			piece = shape.displace(piece, dx, dy)
		end

		return piece
	end

	function text.fake_zoom( Center, Separation, Scale_X, t1, t2, Accel )
		-- Genera un falso zoom separando caracteres o sílabas usando la sombra (xshad)
		if type( Center ) == "function" then Center = Center( ) end
		if type( Separation ) == "function" then Separation = Separation( ) end
		if type( Scale_X ) == "function" then Scale_X = Scale_X( ) end
		if type( t1 ) == "function" then t1 = t1( ) end
		if type( t2 ) == "function" then t2 = t2( ) end
		if type( Accel ) == "function" then Accel = Accel( ) end

		-- Establece el centro de expansión
		local cx = val_center
		if type( Center ) == "string" then
			local c_lower = Center:lower( )
			if c_lower == "line" then
				cx = line.center
			elseif c_lower == "word" then
				cx = word.center
			elseif c_lower == "syl" then
				cx = syl.center
			elseif c_lower == "char" then
				cx = char.center
			else
				cx = tonumber( Center ) or val_center
			end
		elseif type( Center ) == "number" then
			cx = Center
		end

		local sep = tonumber( Separation ) or 0
		local scx = tonumber( Scale_X ) or 100
		
		-- Distancia desde el objeto actual al centro de expansión
		local dist_x = val_center - cx
		local off_xshad = math.round( dist_x * sep, 3 )
		
		-- Genera los tags estáticos
		local tags = format( "\\fscx%s\\xshad%s", scx, off_xshad )
		
		-- Envuelve en \t si se proveen tiempos
		if t1 and t2 then
			if retime_mode then
				t1, t2 = retimettag( retime_mode, t1, t2 )
			end
			local acc = (Accel and Accel ~= 1) and (tostring( Accel ) .. ",") or ""
			tags = format( "\\t(%s,%s,%s%s)", math.round( t1 ), math.round( t2 ), acc, tags )
		end
		
		return tags
	end

-- ============================================================================
-- MESH ENGINE: SISTEMA MODULAR DE GENERACIÓN DE MALLAS PARA KARA EFFECTOR
-- Arquitectura refactorizada: Utilidades, Motores Independientes y Administrador
-- ============================================================================

shape.mesh_engines = {}
shape.mesh_utils = {}

-- ============================================================================
-- [1] UTILIDADES MATEMÁTICAS COMPARTIDAS
-- ============================================================================

-- Función Hash Determinística
function shape.mesh_utils.hash_rand(c, r, offset)
    local s = math.abs(math.floor(c) * 73856093 + math.floor(r) * 19349663 + (offset or 12345))
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
end

-- Generador de círculos
function shape.mesh_utils.make_circle(cx, cy, r)
    if r <= 0 then return "" end
    local segments = math.max(16, math.min(64, math.ceil(r)))
    local pts = {}
    for i = 0, segments - 1 do
        local a = math.rad((i / segments) * 360)
        table.insert(pts, string.format("%.3f %.3f", cx + r * math.cos(a), cy + r * math.sin(a)))
    end
    local code = "m " .. pts[1]
    for i = 2, segments do code = code .. " l " .. pts[i] end
    return code .. " l " .. pts[1]
end

-- ============================================================================
-- [2] MOTORES DE MALLA (MESH ENGINES)
-- Reciben: (box, config, px, py) -> Retornan: Tabla de máscaras {code, cx, cy}
-- ============================================================================

-- MOTOR: HEXAGONAL (Panal de abeja)
shape.mesh_engines["hex"] = function(box, cfg, px, py)
    local masks = {}
    local R = cfg.R
    local H = 1.73205081 * R
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start, c_end = math.floor(screen_x1 / (1.5 * R)) - 1, math.ceil(screen_x2 / (1.5 * R)) + 1
    local r_start, r_end = math.floor(screen_y1 / H) - 1, math.ceil(screen_y2 / H) + 1
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            local screen_cx = c * 1.5 * R
            local screen_cy = r * H
            if math.abs(c % 2) == 1 then screen_cy = screen_cy + H / 2 end
            
            local cx, cy = screen_cx - px, screen_cy - py
            local hex_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx + R, cy, cx + R * 0.5, cy + R * 0.866025, cx - R * 0.5, cy + R * 0.866025,
                cx - R, cy, cx - R * 0.5, cy - R * 0.866025, cx + R * 0.5, cy - R * 0.866025, cx + R, cy)
            table.insert(masks, {code = hex_code, cx = cx, cy = cy})
        end
    end
    return masks
end

-- MOTOR: TRIANGULAR (Malla Isométrica)
shape.mesh_engines["tri"] = function(box, cfg, px, py)
    local masks = {}
    local L = cfg.R * 2 
    local H = L * 0.86602540378 
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start, c_end = math.floor(screen_x1 / L) - 1, math.ceil(screen_x2 / L) + 1
    local r_start, r_end = math.floor(screen_y1 / H) - 1, math.ceil(screen_y2 / H) + 1
    
    for r = r_start, r_end do
        local y1, y2 = r * H, (r + 1) * H
        for c = c_start, c_end do
            local base_x = c * L
            local up_cx, down_cx
            if math.abs(r % 2) == 0 then up_cx, down_cx = base_x, base_x + L/2 else down_cx, up_cx = base_x, base_x + L/2 end
            
            local u_cx, u_cy = up_cx - px, y1 - py
            local tri_up_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                u_cx, u_cy, u_cx - L/2, u_cy + H, u_cx + L/2, u_cy + H, u_cx, u_cy)
            table.insert(masks, {code = tri_up_code, cx = u_cx, cy = u_cy + (2*H/3)})
            
            local d_cx, d_cy = down_cx - px, y2 - py
            local tri_down_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                d_cx - L/2, d_cy - H, d_cx + L/2, d_cy - H, d_cx, d_cy, d_cx - L/2, d_cy - H)
            table.insert(masks, {code = tri_down_code, cx = d_cx, cy = d_cy - (2*H/3)})
        end
    end
    return masks
end

-- MOTOR: DIAMANTE (Rombos)
shape.mesh_engines["dia"] = function(box, cfg, px, py)
    local masks = {}
    local R = cfg.R
    local H_step, W_step = R, R * 2
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start, c_end = math.floor(screen_x1 / W_step) - 1, math.ceil(screen_x2 / W_step) + 1
    local r_start, r_end = math.floor(screen_y1 / H_step) - 1, math.ceil(screen_y2 / H_step) + 1
    
    for r = r_start, r_end do
        for c = c_start, c_end do
            local screen_cx = c * W_step
            local screen_cy = r * H_step
            if math.abs(r % 2) == 1 then screen_cx = screen_cx + R end
            
            local cx, cy = screen_cx - px, screen_cy - py
            local dia_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx, cy - R, cx + R, cy, cx, cy + R, cx - R, cy, cx, cy - R)
            table.insert(masks, {code = dia_code, cx = cx, cy = cy})
        end
    end
    return masks
end

-- MOTOR: ANILLOS (Rings)
shape.mesh_engines["ring"] = function(box, cfg, px, py)
    local masks = {}
    local ring_w = math.max(2, cfg.R)
    local max_polar_R = math.sqrt((box.w/2)^2 + (box.h/2)^2) + 2
    local num_rings = math.ceil(max_polar_R / ring_w)
    
    for i = 0, num_rings - 1 do
        local r_in = i * ring_w
        local r_out = (i + 1) * ring_w
        local mask_code = r_in == 0 and shape.mesh_utils.make_circle(box.cx, box.cy, r_out) 
                        or FX_ShpBoolean(shape.mesh_utils.make_circle(box.cx, box.cy, r_out), shape.mesh_utils.make_circle(box.cx, box.cy, r_in), "difference")
        table.insert(masks, {code = mask_code, cx = box.cx, cy = box.cy})
    end
    return masks
end

-- MOTOR: RADIAL (Rayos/Rebanadas)
shape.mesh_engines["ray"] = function(box, cfg, px, py)
    local masks = {}
    local ang_step = math.max(1, math.min(360, cfg.R))
    local num_rays = math.ceil(360 / ang_step)
    local max_polar_R = math.sqrt((box.w/2)^2 + (box.h/2)^2) + 2
    
    for i = 0, num_rays - 1 do
        local a1 = i * ang_step
        local a2 = math.min((i + 1) * ang_step, 360)
        local pts = { string.format("%.3f %.3f", box.cx, box.cy) }
        local arc_steps = math.max(1, math.ceil((a2 - a1) / 10))
        for j = 0, arc_steps do
            local a = math.rad(a1 + (a2 - a1) * (j / arc_steps))
            table.insert(pts, string.format("%.3f %.3f", box.cx + max_polar_R * math.cos(a), box.cy + max_polar_R * math.sin(a)))
        end
        local mask_code = "m " .. table.concat(pts, " l ") .. string.format(" l %.3f %.3f", box.cx, box.cy)
        local mid_a = math.rad((a1 + a2) / 2)
        local v_dist = (2/3) * max_polar_R
        table.insert(masks, {code = mask_code, cx = box.cx + math.cos(mid_a) * v_dist, cy = box.cy + math.sin(mid_a) * v_dist})
    end
    return masks
end

-- MOTOR: QUADTREE (Glitch Asimétrico)
shape.mesh_engines["quad"] = function(box, cfg, px, py)
    local masks = {}
    local min_size = math.max(4, cfg.R)
    local prob = tonumber(cfg[2]) or 0.45 -- FIX
    local base_size = min_size * 8
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / base_size) - 1
    local c_end   = math.ceil(screen_x2 / base_size) + 1
    local r_start = math.floor(screen_y1 / base_size) - 1
    local r_end   = math.ceil(screen_y2 / base_size) + 1
    
    local function subdivide(gx, gy, size)
        if gx + size < screen_x1 or gx > screen_x2 or gy + size < screen_y1 or gy > screen_y2 then return end
        
        -- FIX: variable local prob
        if size <= min_size * 1.1 or shape.mesh_utils.hash_rand(gx, gy) <= prob then
            local cx, cy = gx - px, gy - py
            local quad_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx, cy, cx + size, cy, cx + size, cy + size, cx, cy + size, cx, cy)
            table.insert(masks, {code = quad_code, cx = cx + size/2, cy = cy + size/2})
        else
            local half = size / 2
            subdivide(gx, gy, half)
            subdivide(gx + half, gy, half)
            subdivide(gx, gy + half, half)
            subdivide(gx + half, gy + half, half)
        end
    end
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            subdivide(c * base_size, r * base_size, base_size)
        end
    end
    return masks
end

-- MOTOR: BÉZIER ONDAS / JIGSAW (Rompecabezas)
shape.mesh_engines["bez"] = function(box, cfg, px, py)
    local masks = {}
    local W = math.max(10, cfg.R * 2)
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start, c_end = math.floor(screen_x1 / W) - 1, math.ceil(screen_x2 / W) + 1
    local r_start, r_end = math.floor(screen_y1 / W) - 1, math.ceil(screen_y2 / W) + 1
    
    local function get_bezier_edge(etype, c, r, x1, y1, x2, y2)
        local rand1 = shape.mesh_utils.hash_rand(c, r, etype == "H" and 1 or 2)
        local rand2 = shape.mesh_utils.hash_rand(c, r, etype == "H" and 3 or 4)
        local amp1, amp2 = (rand1 - 0.5) * 1.5 * W, (rand2 - 0.5) * 1.5 * W
        
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx*dx + dy*dy)
        local nx, ny = -dy / len, dx / len
        
        local cp1x, cp1y = x1 + dx * 0.33 + nx * amp1, y1 + dy * 0.33 + ny * amp1
        local cp2x, cp2y = x1 + dx * 0.66 + nx * amp2, y1 + dy * 0.66 + ny * amp2
        
        return {
            fwd = string.format("b %.3f %.3f %.3f %.3f %.3f %.3f", cp1x, cp1y, cp2x, cp2y, x2, y2),
            bwd = string.format("b %.3f %.3f %.3f %.3f %.3f %.3f", cp2x, cp2y, cp1x, cp1y, x1, y1)
        }
    end
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            local tl_x, tl_y = c * W - px, r * W - py
            local tr_x, tr_y = (c + 1) * W - px, r * W - py
            local br_x, br_y = (c + 1) * W - px, (r + 1) * W - py
            local bl_x, bl_y = c * W - px, (r + 1) * W - py
            
            local top_edge = get_bezier_edge("H", c, r, tl_x, tl_y, tr_x, tr_y).fwd
            local right_edge = get_bezier_edge("V", c + 1, r, tr_x, tr_y, br_x, br_y).fwd
            local bottom_edge = get_bezier_edge("H", c, r + 1, bl_x, bl_y, br_x, br_y).bwd
            local left_edge = get_bezier_edge("V", c, r, tl_x, tl_y, bl_x, bl_y).bwd
            
            local cell_code = string.format("m %.3f %.3f %s %s %s %s", tl_x, tl_y, top_edge, right_edge, bottom_edge, left_edge)
            table.insert(masks, {code = cell_code, cx = (tl_x + br_x) / 2, cy = (tl_y + br_y) / 2})
        end
    end
    return masks
end

-- MOTOR: VORONOI (Cristales Orgánicos)
shape.mesh_engines["vor"] = function(box, cfg, px, py)
    local masks = {}
    local cell_size = math.max(8, cfg.R) 
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start, c_end = math.floor(screen_x1 / cell_size) - 1, math.ceil(screen_x2 / cell_size) + 1
    local r_start, r_end = math.floor(screen_y1 / cell_size) - 1, math.ceil(screen_y2 / cell_size) + 1
    
    local pts = {}
    for c = c_start - 2, c_end + 2 do
        for r = r_start - 2, r_end + 2 do
            local rx = shape.mesh_utils.hash_rand(c, r, 777)
            local ry = shape.mesh_utils.hash_rand(r, c, 888)
            local p_x = c * cell_size + rx * cell_size
            local p_y = r * cell_size + ry * cell_size
            table.insert(pts, {x = p_x - px, y = p_y - py, c = c, r = r})
        end
    end
    
    for _, p1 in ipairs(pts) do
        if p1.c >= c_start and p1.c <= c_end and p1.r >= r_start and p1.r <= r_end then
            local P = cell_size * 2.5 
            local cell_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f",
                p1.x - P, p1.y - P, p1.x + P, p1.y - P, p1.x + P, p1.y + P, p1.x - P, p1.y + P, p1.x - P, p1.y - P)
            
            for _, p2 in ipairs(pts) do
                if p1 ~= p2 then
                    local dc, dr = math.abs(p1.c - p2.c), math.abs(p1.r - p2.r)
                    if dc <= 2 and dr <= 2 then
                        local mx, my = (p1.x + p2.x)/2, (p1.y + p2.y)/2
                        local nx, ny = p1.x - p2.x, p1.y - p2.y
                        local len = math.sqrt(nx*nx + ny*ny)
                        if len > 0.001 then
                            nx, ny = nx/len, ny/len
                            local tx, ty = -ny, nx
                            local L = P * 4
                            local hp_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f",
                                mx + tx*L, my + ty*L, mx - tx*L, my - ty*L, mx - tx*L + nx*L, my - ty*L + ny*L, 
                                mx + tx*L + nx*L, my + ty*L + ny*L, mx + tx*L, my + ty*L)
                            
                            local ok, res = pcall(FX_ShpBoolean, cell_code, hp_code, "intersection")
                            if ok and type(res) == "string" and res ~= "" then cell_code = res end
                        end
                    end
                end
            end
            table.insert(masks, {code = cell_code, cx = p1.x, cy = p1.y})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: RANDOM ASHLAR / MONDRIAN (Rectángulos Aleatorios)
-- ==============================================================
shape.mesh_engines["ashlar"] = function(box, cfg, px, py)
    local masks = {}
    
    -- Configuración: cfg = { Ancho_Minimo, Ancho_Maximo, Altura_Fila }
    local min_w = math.max(2, tonumber(cfg[1]) or 10)
    local max_w = math.max(min_w + 1, tonumber(cfg[2]) or (min_w * 4))
    local row_h = math.max(2, tonumber(cfg[3]) or min_w)
    
    -- Algoritmo Voronoi 1D para asegurar anclaje global determinístico
    local S = (max_w + min_w) / 2
    local J = (max_w - min_w) / 2
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / S) - 1
    local c_end   = math.ceil(screen_x2 / S) + 1
    local r_start = math.floor(screen_y1 / row_h) - 1
    local r_end   = math.ceil(screen_y2 / row_h) + 1
    
    for r = r_start, r_end do
        local screen_y = r * row_h
        
        for c = c_start, c_end do
            -- Punto de corte izquierdo
            local hash_l = shape.mesh_utils.hash_rand(c, r, 111)
            local screen_x_left = c * S + hash_l * J
            
            -- Punto de corte derecho
            local hash_r = shape.mesh_utils.hash_rand(c + 1, r, 111)
            local screen_x_right = (c + 1) * S + hash_r * J
            
            -- Si el ladrillo cae dentro de la caja visible, lo dibuja
            if screen_x_right >= screen_x1 and screen_x_left <= screen_x2 then
                local cx1 = screen_x_left - px
                local cx2 = screen_x_right - px
                local cy1 = screen_y - py
                local cy2 = screen_y + row_h - py
                
                local rect_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                    cx1, cy1, cx2, cy1, cx2, cy2, cx1, cy2, cx1, cy1)
                    
                table.insert(masks, {code = rect_code, cx = (cx1 + cx2)/2, cy = (cy1 + cy2)/2})
            end
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: BRICK (Ladrillos Clásicos / Running Bond)
-- ==============================================================
shape.mesh_engines["brick"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Ancho, Alto, Ratio_Desfase }
    local W = math.max(2, tonumber(cfg[1]) or 30)
    local H = math.max(2, tonumber(cfg[2]) or 15)
    local offset_ratio = tonumber(cfg[3]) or 0.5 -- 0.5 significa que se desfasa a la mitad
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local r_start = math.floor(screen_y1 / H) - 1
    local r_end   = math.ceil(screen_y2 / H) + 1
    
    for r = r_start, r_end do
        -- Desfasamos las filas impares
        local row_offset = (math.abs(r) % 2) * W * offset_ratio
        
        local c_start = math.floor((screen_x1 - row_offset) / W) - 1
        local c_end   = math.ceil((screen_x2 - row_offset) / W) + 1
        
        for c = c_start, c_end do
            local screen_x = c * W + row_offset
            local screen_y = r * H
            
            local cx, cy = screen_x - px, screen_y - py
            local brick_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx, cy, cx + W, cy, cx + W, cy + H, cx, cy + H, cx, cy)
                
            table.insert(masks, {code = brick_code, cx = cx + W/2, cy = cy + H/2})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: MONDRIAN (Rectángulos Asimétricos Verdaderos)
-- ==============================================================
shape.mesh_engines["mondrian"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Tamaño_Minimo, Probabilidad } (Similar a Quadtree)
    local min_size = math.max(4, tonumber(cfg[1]) or 12)
    local prob = tonumber(cfg[2]) or 0.45
    local base_size = min_size * 8
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / base_size) - 1
    local c_end   = math.ceil(screen_x2 / base_size) + 1
    local r_start = math.floor(screen_y1 / base_size) - 1
    local r_end   = math.ceil(screen_y2 / base_size) + 1
    
    -- Subdivisión aleatoria en ratios irregulares (ej. 30% / 70% en vez de 50/50)
    local function subdivide(gx, gy, gw, gh)
        if gx + gw < screen_x1 or gx > screen_x2 or gy + gh < screen_y1 or gy > screen_y2 then return end
        
        local stop = false
        if math.max(gw, gh) <= min_size * 1.5 then stop = true end
        if math.max(gw, gh) <= min_size * 4 and shape.mesh_utils.hash_rand(gx, gy, 99) <= prob then stop = true end
        
        if stop then
            local cx, cy = gx - px, gy - py
            local rect_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx, cy, cx + gw, cy, cx + gw, cy + gh, cx, cy + gh, cx, cy)
            table.insert(masks, {code = rect_code, cx = cx + gw/2, cy = cy + gh/2})
        else
            -- Decide si cortar vertical u horizontalmente
            local split_x = false
            if gw > gh * 1.5 then split_x = true -- Si es muy ancho, forzar corte X
            elseif gh > gw * 1.5 then split_x = false -- Si es muy alto, forzar corte Y
            else split_x = shape.mesh_utils.hash_rand(gx, gy, 123) > 0.5 end
            
            -- Ratio de corte aleatorio entre 30% y 70%
            local ratio = 0.3 + 0.4 * shape.mesh_utils.hash_rand(gx, gy, 456)
            
            if split_x then
                local w1 = gw * ratio
                local w2 = gw - w1
                subdivide(gx, gy, w1, gh)
                subdivide(gx + w1, gy, w2, gh)
            else
                local h1 = gh * ratio
                local h2 = gh - h1
                subdivide(gx, gy, gw, h1)
                subdivide(gx, gy + h1, gw, h2)
            end
        end
    end
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            subdivide(c * base_size, r * base_size, base_size, base_size)
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: HERRINGBONE (Punto de Espiga / Zig-Zag)
-- ==============================================================
shape.mesh_engines["herringbone"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Longitud_Ladrillo, Grosor_Ladrillo }
    local L = math.max(2, tonumber(cfg[1]) or 30)
    local W = math.max(1, tonumber(cfg[2]) or 10)
    
    -- Vectores de traslación puros para Herringbone: T1 = (L, -L) y T2 = (W, W)
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    -- Margen de seguridad para cubrir completamente la pantalla
    local pad = math.max(L, W) * 2
    screen_x1, screen_x2 = screen_x1 - pad, screen_x2 + pad
    screen_y1, screen_y2 = screen_y1 - pad, screen_y2 + pad
    
    -- Proyectamos el Bounding Box al espacio matricial
    local function get_cr(x, y)
        local c = (x - y) / (2 * L)
        local r = (x + y) / (2 * W)
        return c, r
    end
    
    local c1, r1 = get_cr(screen_x1, screen_y1)
    local c2, r2 = get_cr(screen_x2, screen_y1)
    local c3, r3 = get_cr(screen_x1, screen_y2)
    local c4, r4 = get_cr(screen_x2, screen_y2)
    
    local c_start = math.floor(math.min(c1, c2, c3, c4))
    local c_end   = math.ceil(math.max(c1, c2, c3, c4))
    local r_start = math.floor(math.min(r1, r2, r3, r4))
    local r_end   = math.ceil(math.max(r1, r2, r3, r4))
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            -- Posición base del bloque ("L")
            local base_cx = c * L + r * W
            local base_cy = -c * L + r * W
            
            -- Ladrillo Horizontal
            local hx, hy = base_cx - px, base_cy - py
            local h_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                hx, hy, hx + L, hy, hx + L, hy + W, hx, hy + W, hx, hy)
            table.insert(masks, {code = h_code, cx = hx + L/2, cy = hy + W/2})
            
            -- Ladrillo Vertical (Enganchado exactamente a la derecha y abajo)
            local vx, vy = base_cx + L - px, base_cy + W - L - py
            local v_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                vx, vy, vx + W, vy, vx + W, vy + L, vx, vy + L, vx, vy)
            table.insert(masks, {code = v_code, cx = vx + W/2, cy = vy + L/2})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: DELAUNAY / LOW-POLY (Triangulación Orgánica / Vidrio)
-- ==============================================================
shape.mesh_engines["delaunay"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg.R = Tamaño aproximado de las esquirlas
    local cell_size = math.max(8, cfg.R)
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / cell_size) - 1
    local c_end   = math.ceil(screen_x2 / cell_size) + 1
    local r_start = math.floor(screen_y1 / cell_size) - 1
    local r_end   = math.ceil(screen_y2 / cell_size) + 1
    
    local function get_pt(c, r)
        local rx = shape.mesh_utils.hash_rand(c, r, 2024)
        local ry = shape.mesh_utils.hash_rand(r, c, 4202)
        return c * cell_size + rx * cell_size - px, r * cell_size + ry * cell_size - py
    end
    
    local function dist_sq(x1, y1, x2, y2)
        return (x2 - x1)^2 + (y2 - y1)^2
    end

    for c = c_start, c_end do
        for r = r_start, r_end do
            local tl_x, tl_y = get_pt(c, r)           -- Top-Left
            local tr_x, tr_y = get_pt(c + 1, r)       -- Top-Right
            local bl_x, bl_y = get_pt(c, r + 1)       -- Bottom-Left
            local br_x, br_y = get_pt(c + 1, r + 1)   -- Bottom-Right
            
            local d1 = dist_sq(tl_x, tl_y, br_x, br_y)
            local d2 = dist_sq(tr_x, tr_y, bl_x, bl_y)
            
            local tri1, tri2
            local cx1, cy1, cx2, cy2
            
            if d1 < d2 then
                tri1 = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                    tl_x, tl_y, tr_x, tr_y, br_x, br_y, tl_x, tl_y)
                cx1, cy1 = (tl_x + tr_x + br_x)/3, (tl_y + tr_y + br_y)/3
                
                tri2 = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                    tl_x, tl_y, br_x, br_y, bl_x, bl_y, tl_x, tl_y)
                cx2, cy2 = (tl_x + br_x + bl_x)/3, (tl_y + br_y + bl_y)/3
            else
                tri1 = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                    tl_x, tl_y, tr_x, tr_y, bl_x, bl_y, tl_x, tl_y)
                cx1, cy1 = (tl_x + tr_x + bl_x)/3, (tl_y + tr_y + bl_y)/3
                
                tri2 = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                    tr_x, tr_y, br_x, br_y, bl_x, bl_y, tr_x, tr_y)
                cx2, cy2 = (tr_x + br_x + bl_x)/3, (tr_y + br_y + bl_y)/3
            end
            
            table.insert(masks, {code = tri1, cx = cx1, cy = cy1})
            table.insert(masks, {code = tri2, cx = cx2, cy = cy2})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: SCALLOPS / SCALES (Escamas de Pez / Sirena)
-- ==============================================================
shape.mesh_engines["scallop"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Radio, Angulo }
    local R = math.max(2, tonumber(cfg[1]) or 12)
    local Angle = tonumber(cfg[2]) or 0
    
    local k = R * 0.55228475
    local H_step = R
    local W_step = R * 2
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start, c_end, r_start, r_end
    
    if Angle == 0 then
        c_start = math.floor(screen_x1 / W_step) - 1
        c_end   = math.ceil(screen_x2 / W_step) + 1
        r_start = math.floor(screen_y1 / H_step) - 1
        r_end   = math.ceil(screen_y2 / H_step) + 1
    else
        local function inv_rot(x, y)
            local a = math.angle(0, 0, x, y)
            local d = math.distance(0, 0, x, y)
            return math.polar(a - Angle, d, "x"), math.polar(a - Angle, d, "y")
        end
        local ix1, iy1 = inv_rot(screen_x1, screen_y1)
        local ix2, iy2 = inv_rot(screen_x2, screen_y1)
        local ix3, iy3 = inv_rot(screen_x1, screen_y2)
        local ix4, iy4 = inv_rot(screen_x2, screen_y2)

        local min_sx = math.min(ix1, ix2, ix3, ix4)
        local max_sx = math.max(ix1, ix2, ix3, ix4)
        local min_sy = math.min(iy1, iy2, iy3, iy4)
        local max_sy = math.max(iy1, iy2, iy3, iy4)

        c_start = math.floor(min_sx / W_step) - 1
        c_end   = math.ceil(max_sx / W_step) + 1
        r_start = math.floor(min_sy / H_step) - 1
        r_end   = math.ceil(max_sy / H_step) + 1
    end
    
    for r = r_start, r_end do
        for c = c_start, c_end do
            local screen_cx = c * W_step
            local screen_cy = r * H_step
            if math.abs(r % 2) == 1 then screen_cx = screen_cx + R end
            
            local cx = screen_cx - px
            local cy = screen_cy - py
            
            local scallop_code = string.format(
                "m %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f",
                cx - R, cy,
                cx - R, cy - k, cx - k, cy - R, cx, cy - R,
                cx + k, cy - R, cx + R, cy - k, cx + R, cy,
                cx + R - k, cy, cx, cy + R - k, cx, cy + R,
                cx, cy + R - k, cx - R + k, cy, cx - R, cy
            )
            
            if Angle ~= 0 then
                scallop_code = shape.rotate(scallop_code, Angle, -px, -py)
                local c_ang = math.angle(-px, -py, cx, cy)
                local c_rad = math.distance(-px, -py, cx, cy)
                cx = -px + math.polar(c_ang + Angle, c_rad, "x")
                cy = -py + math.polar(c_ang + Angle, c_rad, "y")
            end
            
            if cx >= box.x - R*2 and cx <= box.x + box.w + R*2 and cy >= box.y - R*2 and cy <= box.y + box.h + R*2 then
                table.insert(masks, {code = scallop_code, cx = cx, cy = cy})
            end
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: SPIDERWEB / RADIAL SHATTER (Telaraña / Vidrio Roto Radial)
-- ==============================================================
shape.mesh_engines["web"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Num_Anillos, Num_Rayos, Nivel_Caos, CentroX, CentroY }
    local num_rings = math.max(1, math.floor(tonumber(cfg[1]) or 5))
    local num_rays  = math.max(3, math.floor(tonumber(cfg[2]) or 12))
    local chaos     = math.max(0, math.min(1, tonumber(cfg[3]) or 0.2))
    
    local cx = tonumber(cfg[4]) or box.cx
    local cy = tonumber(cfg[5]) or box.cy
    
    local max_dist = 0
    local corners = {
        {box.x, box.y}, {box.x + box.w, box.y},
        {box.x, box.y + box.h}, {box.x + box.w, box.y + box.h}
    }
    for _, pt in ipairs(corners) do
        local d = math.sqrt((pt[1]-cx)^2 + (pt[2]-cy)^2)
        if d > max_dist then max_dist = d end
    end
    max_dist = max_dist + 5 -- Relleno de seguridad
    
    local step_R = max_dist / num_rings
    local step_A = 360 / num_rays
    
   local function get_vertex(ring, ray)
        if ring == 0 then return cx, cy end -- El epicentro es fijo
        
        local safe_ray = ray % num_rays -- Conecta el último rayo con el primero
        
        local a = safe_ray * step_A
        local r = ring * step_R
        
        local a_jit = (shape.mesh_utils.hash_rand(ring, safe_ray, 11) - 0.5) * step_A * chaos
        local r_jit = (shape.mesh_utils.hash_rand(ring, safe_ray, 22) - 0.5) * step_R * chaos
        
        local final_a = math.rad(a + a_jit)
        local final_r = r + r_jit
        
        return cx + final_r * math.cos(final_a), cy + final_r * math.sin(final_a)
    end
    
    for ring = 1, num_rings do
        for ray = 0, num_rays - 1 do
            local x1, y1 = get_vertex(ring - 1, ray)
            local x2, y2 = get_vertex(ring, ray)
            local x3, y3 = get_vertex(ring, ray + 1)
            local x4, y4 = get_vertex(ring - 1, ray + 1)
            
            local cell_code
            local cent_x, cent_y
            
            if ring == 1 then
                cell_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f",
                    x1, y1, x2, y2, x3, y3, x1, y1)
                cent_x, cent_y = (x1+x2+x3)/3, (y1+y2+y3)/3
            else
                cell_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f",
                    x1, y1, x2, y2, x3, y3, x4, y4, x1, y1)
                cent_x, cent_y = (x1+x2+x3+x4)/4, (y1+y2+y3+y4)/4
            end
            
            local min_x = math.min(x1, x2, x3, x4)
            local max_x = math.max(x1, x2, x3, x4)
            local min_y = math.min(y1, y2, y3, y4)
            local max_y = math.max(y1, y2, y3, y4)
            
            if max_x >= box.x and min_x <= box.x + box.w and max_y >= box.y and min_y <= box.y + box.h then
                table.insert(masks, {code = cell_code, cx = cent_x, cy = cent_y})
            end
        end
    end
    
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: RHOMBILLE / CUBOS ISOMÉTRICOS (Q*bert)
-- ==============================================================
shape.mesh_engines["rhombille"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Radio_Hexágono }
    local R = math.max(2, tonumber(cfg[1]) or 20)
    
    local W = 1.73205081 * R   -- Ancho (math.sqrt(3) * R)
    local H_step = 1.5 * R     -- Distancia vertical entre filas
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / W) - 1
    local c_end   = math.ceil(screen_x2 / W) + 1
    local r_start = math.floor(screen_y1 / H_step) - 1
    local r_end   = math.ceil(screen_y2 / H_step) + 1
    
    for r = r_start, r_end do
        local screen_cy = r * H_step
        for c = c_start, c_end do
            local screen_cx = c * W
            
            if math.abs(r % 2) == 1 then
                screen_cx = screen_cx + W / 2
            end
            
            local cx = screen_cx - px
            local cy = screen_cy - py
            
            -- Puntos del hexágono
            local p_c  = {cx, cy}                  -- Centro
            local p_t  = {cx, cy - R}              -- Arriba
            local p_tr = {cx + W/2, cy - R/2}      -- Arriba Derecha
            local p_br = {cx + W/2, cy + R/2}      -- Abajo Derecha
            local p_b  = {cx, cy + R}              -- Abajo
            local p_bl = {cx - W/2, cy + R/2}      -- Abajo Izquierda
            local p_tl = {cx - W/2, cy - R/2}      -- Arriba Izquierda
            
            local r1_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f",
                p_c[1], p_c[2], p_tl[1], p_tl[2], p_t[1], p_t[2], p_tr[1], p_tr[2], p_c[1], p_c[2])
            table.insert(masks, {code = r1_code, cx = cx, cy = cy - R/2})
            
            local r2_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f",
                p_c[1], p_c[2], p_tr[1], p_tr[2], p_br[1], p_br[2], p_b[1], p_b[2], p_c[1], p_c[2])
            table.insert(masks, {code = r2_code, cx = cx + W/4, cy = cy + R/4})
            
            local r3_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f",
                p_c[1], p_c[2], p_b[1], p_b[2], p_bl[1], p_bl[2], p_tl[1], p_tl[2], p_c[1], p_c[2])
            table.insert(masks, {code = r3_code, cx = cx - W/4, cy = cy + R/4})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: TRUNCATED SQUARE / MOSAICO MORISCO (Octágonos y Cuadrados)
-- ==============================================================
shape.mesh_engines["octagon"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Radio_Base }
    local R = math.max(2, tonumber(cfg[1]) or 20)
    
    -- Matemáticas del teselado Arquimediano
    local x_cut = R * (2 - math.sqrt(2)) -- El corte de las esquinas para hacer un octágono regular
    local d = R - x_cut                  -- Mitad del lado recto del octágono
    local step = R * 2                   -- Distancia entre centros
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / step) - 1
    local c_end   = math.ceil(screen_x2 / step) + 1
    local r_start = math.floor(screen_y1 / step) - 1
    local r_end   = math.ceil(screen_y2 / step) + 1
    
    for r = r_start, r_end do
        for c = c_start, c_end do
            local screen_cx = c * step
            local screen_cy = r * step
            
            local cx = screen_cx - px
            local cy = screen_cy - py
            
            local oct_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx - d, cy - R, 
                cx + d, cy - R,
                cx + R, cy - d, 
                cx + R, cy + d,
                cx + d, cy + R, 
                cx - d, cy + R,
                cx - R, cy + d, 
                cx - R, cy - d
            )
            table.insert(masks, {code = oct_code, cx = cx, cy = cy})
            
            local sq_cx = cx + R
            local sq_cy = cy + R
            local sq_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                sq_cx, sq_cy - x_cut,
                sq_cx + x_cut, sq_cy,
                sq_cx, sq_cy + x_cut,
                sq_cx - x_cut, sq_cy
            )
            table.insert(masks, {code = sq_code, cx = sq_cx, cy = sq_cy})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: KAGOME LATTICE (Trihexagonal / Estrella de David)
-- ==============================================================
shape.mesh_engines["kagome"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Radio_Hexágono }
    local R = math.max(2, tonumber(cfg[1]) or 15)
    
    local H_step = R * 1.73205081 -- Altura matemática: R * math.sqrt(3)
    local H_half = H_step / 2
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local r_start = math.floor(screen_y1 / H_step) - 1
    local r_end   = math.ceil(screen_y2 / H_step) + 1
    
    for r = r_start, r_end do
        local c_start = math.floor((screen_x1 - r * R) / (2 * R)) - 1
        local c_end   = math.ceil((screen_x2 - r * R) / (2 * R)) + 1
        
        for c = c_start, c_end do
            local screen_cx = c * 2 * R + r * R
            local screen_cy = r * H_step
            
            local cx = screen_cx - px
            local cy = screen_cy - py
            
            local hex_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx + R, cy,
                cx + R/2, cy + H_half,
                cx - R/2, cy + H_half,
                cx - R, cy,
                cx - R/2, cy - H_half,
                cx + R/2, cy - H_half,
                cx + R, cy
            )
            table.insert(masks, {code = hex_code, cx = cx, cy = cy})
            
            local td_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx + R, cy,
                cx + 1.5*R, cy + H_half,
                cx + 0.5*R, cy + H_half,
                cx + R, cy
            )
            table.insert(masks, {code = td_code, cx = cx + R, cy = cy + H_step/3})
            
            local tu_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx + R, cy,
                cx + 0.5*R, cy - H_half,
                cx + 1.5*R, cy - H_half,
                cx + R, cy
            )
            table.insert(masks, {code = tu_code, cx = cx + R, cy = cy - H_step/3})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: JIGSAW / PUZZLE (Rompecabezas Clásico)
-- ==============================================================
shape.mesh_engines["jigsaw"] = function(box, cfg, px, py)
    local masks = {}
    -- W es el tamaño de la celda cuadrada del rompecabezas
    local W = math.max(10, cfg.R * 2)
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / W) - 1
    local c_end   = math.ceil(screen_x2 / W) + 1
    local r_start = math.floor(screen_y1 / W) - 1
    local r_end   = math.ceil(screen_y2 / W) + 1
    
    local function get_jigsaw_edge(etype, c, r, x1, y1, x2, y2)
        local rand1 = shape.mesh_utils.hash_rand(c, r, etype == "H" and 1 or 2)
        local rand2 = shape.mesh_utils.hash_rand(c, r, etype == "H" and 3 or 4)
        
        local dir = (rand1 > 0.5) and 1 or -1
        local offset = (rand2 - 0.5) * 0.2
        
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx*dx + dy*dy)
        local nx, ny = -dy / len * dir, dx / len * dir
        local ux, uy = dx / len, dy / len
        
        local p_neck_L = 0.38 + offset
        local p_neck_R = 0.62 + offset
        
        local function pt(u, n)
            return {x1 + ux * (u * len) + nx * (n * len), y1 + uy * (u * len) + ny * (n * len)}
        end
        
        local pt_neck_L = pt(p_neck_L, 0)
        local b1_c1, b1_c2, b1_end = pt(p_neck_L + 0.05, 0.0), pt(p_neck_L + 0.05, 0.1), pt(p_neck_L, 0.15)
        local b2_c1, b2_c2, b2_end = pt(p_neck_L - 0.10, 0.3), pt(p_neck_R + 0.10, 0.3), pt(p_neck_R, 0.15)
        local b3_c1, b3_c2, b3_end = pt(p_neck_R - 0.05, 0.1), pt(p_neck_R - 0.05, 0.0), pt(p_neck_R, 0.0)
        
        -- Trazado en sentido horario
        local fwd = string.format("l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f l %.3f %.3f",
            pt_neck_L[1], pt_neck_L[2],
            b1_c1[1], b1_c1[2], b1_c2[1], b1_c2[2], b1_end[1], b1_end[2],
            b2_c1[1], b2_c1[2], b2_c2[1], b2_c2[2], b2_end[1], b2_end[2],
            b3_c1[1], b3_c1[2], b3_c2[1], b3_c2[2], b3_end[1], b3_end[2],
            x2, y2)
            
        -- Trazado en sentido antihorario
        local bwd = string.format("l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f l %.3f %.3f",
            b3_end[1], b3_end[2],
            b3_c2[1], b3_c2[2], b3_c1[1], b3_c1[2], b2_end[1], b2_end[2],
            b2_c2[1], b2_c2[2], b2_c1[1], b2_c1[2], b1_end[1], b1_end[2],
            b1_c2[1], b1_c2[2], b1_c1[1], b1_c1[2], pt_neck_L[1], pt_neck_L[2],
            x1, y1)
            
        return {fwd = fwd, bwd = bwd}
    end
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            local tl_x, tl_y = c * W - px, r * W - py
            local tr_x, tr_y = (c + 1) * W - px, r * W - py
            local br_x, br_y = (c + 1) * W - px, (r + 1) * W - py
            local bl_x, bl_y = c * W - px, (r + 1) * W - py
            
            local top_edge    = get_jigsaw_edge("H", c, r, tl_x, tl_y, tr_x, tr_y).fwd
            local right_edge  = get_jigsaw_edge("V", c + 1, r, tr_x, tr_y, br_x, br_y).fwd
            local bottom_edge = get_jigsaw_edge("H", c, r + 1, bl_x, bl_y, br_x, br_y).bwd
            local left_edge   = get_jigsaw_edge("V", c, r, tl_x, tl_y, bl_x, bl_y).bwd
            
            local cell_code = string.format("m %.3f %.3f %s %s %s %s", tl_x, tl_y, top_edge, right_edge, bottom_edge, left_edge)
            local cx, cy = (tl_x + br_x) / 2, (tl_y + br_y) / 2
            
            table.insert(masks, {code = cell_code, cx = cx, cy = cy})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: TRUCHET TILES (Laberintos / Tuberías Curvas)
-- ==============================================================
shape.mesh_engines["truchet"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Tamaño_Cuadrado }
    local W = math.max(10, tonumber(cfg[1]) or 20)
    
    local k = (W / 2) * 0.55228475
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / W) - 1
    local c_end   = math.ceil(screen_x2 / W) + 1
    local r_start = math.floor(screen_y1 / W) - 1
    local r_end   = math.ceil(screen_y2 / W) + 1
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            local cx = c * W - px
            local cy = r * W - py
            
            local config = shape.mesh_utils.hash_rand(c, r, 789) > 0.5 and 1 or 0
            
            if config == 0 then
                local m1 = string.format("m %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f l %.3f %.3f l %.3f %.3f",
                    cx, cy + W/2,
                    cx, cy + W/2 - k, cx + W/2 - k, cy, cx + W/2, cy,
                    cx, cy, cx, cy + W/2)
                table.insert(masks, {code = m1, cx = cx + W/4, cy = cy + W/4})
                
                local m2 = string.format("m %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f l %.3f %.3f l %.3f %.3f",
                    cx + W/2, cy + W,
                    cx + W/2 + k, cy + W, cx + W, cy + W/2 + k, cx + W, cy + W/2,
                    cx + W, cy + W, cx + W/2, cy + W)
                table.insert(masks, {code = m2, cx = cx + 3*W/4, cy = cy + 3*W/4})
                
                local m3 = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f l %.3f %.3f l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f",
                    cx + W/2, cy,
                    cx + W, cy, cx + W, cy + W/2,
                    cx + W, cy + W/2 + k, cx + W/2 + k, cy + W, cx + W/2, cy + W,
                    cx, cy + W, cx, cy + W/2,
                    cx, cy + W/2 - k, cx + W/2 - k, cy, cx + W/2, cy)
                table.insert(masks, {code = m3, cx = cx + W/2, cy = cy + W/2})
                
            else
                local m1 = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f",
                    cx + W/2, cy,
                    cx + W, cy, cx + W, cy + W/2,
                    cx + W, cy + W/2 - k, cx + W/2 + k, cy, cx + W/2, cy)
                table.insert(masks, {code = m1, cx = cx + 3*W/4, cy = cy + W/4})
                
                local m2 = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f",
                    cx, cy + W/2,
                    cx, cy + W, cx + W/2, cy + W,
                    cx + W/2 - k, cy + W, cx, cy + W/2 + k, cx, cy + W/2)
                table.insert(masks, {code = m2, cx = cx + W/4, cy = cy + 3*W/4})
                
                local m3 = string.format("m %.3f %.3f l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f l %.3f %.3f l %.3f %.3f b %.3f %.3f %.3f %.3f %.3f %.3f l %.3f %.3f",
                    cx, cy,
                    cx + W/2, cy,
                    cx + W/2 + k, cy, cx + W, cy + W/2 - k, cx + W, cy + W/2,
                    cx + W, cy + W, cx + W/2, cy + W,
                    cx + W/2 - k, cy + W, cx, cy + W/2 + k, cx, cy + W/2,
                    cx, cy)
                table.insert(masks, {code = m3, cx = cx + W/2, cy = cy + W/2})
            end
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: CIRCUIT BOARD / TECH (Placa de Circuitos Negativa)
-- ==============================================================
shape.mesh_engines["circuit"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Tamaño_Celda, Grosor_Pista, Probabilidad_Vía }
    local W = math.max(10, tonumber(cfg[1]) or 20)
    local T = math.max(2, tonumber(cfg[2]) or (W * 0.25))
    local prob_pad = math.max(0, math.min(1, tonumber(cfg[3]) or 0.2))
    local k = T / 2 
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / W) - 1
    local c_end   = math.ceil(screen_x2 / W) + 1
    local r_start = math.floor(screen_y1 / W) - 1
    local r_end   = math.ceil(screen_y2 / W) + 1
    
    for c = c_start, c_end do
        for r = r_start, r_end do
            local cx, cy = c * W - px, r * W - py
            
            local cell_sq = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                cx, cy, cx+W, cy, cx+W, cy+W, cx, cy+W)
                
            local hash = shape.mesh_utils.hash_rand(c, r, 101)
            local is_pad = shape.mesh_utils.hash_rand(c, r, 202) < prob_pad
            
            local trace_code = ""
            if hash < 0.15 then trace_code = ""
            elseif hash < 0.30 then -- Horizontal
                trace_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", cx, cy+W/2-k, cx+W, cy+W/2-k, cx+W, cy+W/2+k, cx, cy+W/2+k)
            elseif hash < 0.45 then -- Vertical
                trace_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", cx+W/2-k, cy, cx+W/2+k, cy, cx+W/2+k, cy+W, cx+W/2-k, cy+W)
            elseif hash < 0.60 then -- Esquina Top-Left
                trace_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", cx+W/2-k, cy, cx+W/2+k, cy, cx+W/2+k, cy+W/2+k, cx, cy+W/2+k, cx, cy+W/2-k, cx+W/2-k, cy+W/2-k)
            elseif hash < 0.75 then -- Esquina Top-Right
                trace_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", cx+W/2-k, cy, cx+W/2+k, cy, cx+W/2+k, cy+W/2-k, cx+W, cy+W/2-k, cx+W, cy+W/2+k, cx+W/2-k, cy+W/2+k)
            elseif hash < 0.90 then -- Esquina Bottom-Left
                trace_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", cx, cy+W/2-k, cx+W/2+k, cy+W/2-k, cx+W/2+k, cy+W, cx+W/2-k, cy+W, cx+W/2-k, cy+W/2+k, cx, cy+W/2+k)
            else -- Esquina Bottom-Right
                trace_code = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", cx+W/2-k, cy+W/2-k, cx+W, cy+W/2-k, cx+W, cy+W/2+k, cx+W/2+k, cy+W/2+k, cx+W/2+k, cy+W, cx+W/2-k, cy+W)
            end
            
            if is_pad and trace_code ~= "" then
                local pad_code = shape.mesh_utils.make_circle(cx+W/2, cy+W/2, T * 1.1)
                local ok, uni = pcall(FX_ShpBoolean, trace_code, pad_code, "union")
                trace_code = (ok and uni ~= "") and uni or (trace_code .. " " .. pad_code)
            end
            
            local final_cell = cell_sq
            if trace_code ~= "" then
                local ok, diff = pcall(FX_ShpBoolean, cell_sq, trace_code, "difference")
                if ok and diff ~= "" then final_cell = diff end
            end
            
            table.insert(masks, {code = final_cell, cx = cx + W/2, cy = cy + W/2})
        end
    end
    return masks
end

-- ==============================================================
-- MOTOR DE MALLA: PATTERNS (Patrones Universales Personalizados)
-- ==============================================================
shape.mesh_engines["pattern"] = function(box, cfg, px, py)
    local masks = {}
    -- Configuración: cfg = { Forma_String, Tamaño_Celda, Tamaño_Dibujo, Intercalar_Filas, Es_Positivo }
    local custom_shape = type(cfg[1]) == "string" and cfg[1] or shape.circle
    local S = math.max(4, tonumber(cfg[2]) or 20)
    local shp_size = tonumber(cfg[3]) or (S * 0.8)
    local stagger = cfg[4] == true      -- true = Desfasa las filas como ladrillos
    local is_pos = cfg[5] == true       -- false (default) = Espacio Negativo (huecos). true = Texto hecho de formitas.

    local scaled_pat = shape.displace(shape.size(custom_shape, shp_size), "incenter")
    
    local screen_x1, screen_x2 = box.x + px, box.x + box.w + px
    local screen_y1, screen_y2 = box.y + py, box.y + box.h + py
    
    local c_start = math.floor(screen_x1 / S) - 1
    local c_end   = math.ceil(screen_x2 / S) + 1
    local r_start = math.floor(screen_y1 / S) - 1
    local r_end   = math.ceil(screen_y2 / S) + 1
    
    for r = r_start, r_end do
        local offset_x = (stagger and math.abs(r % 2) == 1) and (S / 2) or 0
        
        for c = c_start, c_end do
            local cx = c * S + offset_x - px
            local cy = r * S - py
            
            local placed_shape = shape.displace(scaled_pat, cx + S/2, cy + S/2)
            local final_code = ""
            
            if not is_pos then
                -- MODO NEGATIVO: Cuadrado de la celda MENOS la forma (Perforación)
                local cell_sq = string.format("m %.3f %.3f l %.3f %.3f l %.3f %.3f l %.3f %.3f", 
                    cx, cy, cx+S, cy, cx+S, cy+S, cx, cy+S)
                local ok, diff = pcall(FX_ShpBoolean, cell_sq, placed_shape, "difference")
                final_code = (ok and diff ~= "") and diff or cell_sq
            else
                -- MODO POSITIVO: La máscara de corte ES la forma
                final_code = placed_shape
            end
            
            table.insert(masks, {code = final_code, cx = cx + S/2, cy = cy + S/2})
        end
    end
    return masks
end

-- ============================================================================
-- [3] FUNCIÓN PRINCIPAL ORQUESTADORA
-- ============================================================================

function shape.slice_mesh( Shape_or_Text, Mode, Size, Overlap, Separation, Scale )
    if type( Shape_or_Text ) == "function" then Shape_or_Text = Shape_or_Text() end
    if type( Mode ) == "function" then Mode = Mode() end
    if type( Size ) == "function" then Size = Size() end
    if type( Overlap ) == "function" then Overlap = Overlap() end
    if type( Separation ) == "function" then Separation = Separation() end
    if type( Scale ) == "function" then Scale = Scale() end
    
    -- Escala y offset pre-corte
    local text_scale, pre_offset = 1, 0
    if type( Scale ) == "table" then
        text_scale, pre_offset = tonumber( Scale[1] ) or 1, tonumber( Scale[2] ) or 0
    elseif Scale ~= nil then
        text_scale = tonumber( Scale ) or 1
    end

    local base_shape = text.to_shape_ill( Shape_or_Text, text_scale )
    if not base_shape or base_shape == "" or base_shape == "m 0 0" then return "" end
    if pre_offset ~= 0 then
        base_shape = FX_ShpOffset( base_shape, pre_offset )
        if not base_shape or base_shape == "" then return "" end
    end

    local mesh_mode = type(Mode) == "string" and Mode:lower() or "hex"
    if not shape.mesh_engines[mesh_mode] then mesh_mode = "hex" end -- Fallback seguro
    
    -- Configuración Dinámica (Passthrough seguro para la Caché)
    local cfg = type(Size) == "table" and Size or {Size}
    cfg.R = math.max(1, tonumber(cfg[1]) or 12)
    
    local cfg_str = ""
    if type(Size) == "table" then
        local str_tbl = {}
        for i = 1, #Size do 
            table.insert(str_tbl, tostring(Size[i])) 
        end
        cfg_str = table.concat(str_tbl, "_")
    else
        cfg_str = tostring(Size)
    end
    
    local ov = tonumber( Overlap ) or 0

    local cache_key = string.format("slice_mesh_v19_%s_%s_cfg%s_ov%.2f_po%.2f_px%.1f_py%.1f", 
        base_shape, mesh_mode, cfg_str, ov, pre_offset, fx.pos_x, fx.pos_y)
        
    local Sliced_Pieces = recall[cache_key]
    
    -- FASE DE CREACIÓN Y CACHÉ
    if not Sliced_Pieces then
        Sliced_Pieces = {}
        local box = FX_ShpBox( base_shape )
        local ghost_marker = string.format("m %.3f %.3f m %.3f %.3f ", box.x, box.y, box.x + box.w, box.y + box.h)
        
        -- Llama dinámicamente al motor correspondiente
        local masks = shape.mesh_engines[mesh_mode](box, cfg, fx.pos_x, fx.pos_y)
        
        local valid_piece_count = 0
        for _, mask in ipairs(masks) do
            local mask_code = mask.code
            if ov ~= 0 then mask_code = FX_ShpOffset(mask_code, ov) end
            
            local piece = FX_ShpBoolean( base_shape, mask_code, "intersection" )
            if piece and piece ~= "" and piece ~= "m 0 0" and not piece:match("nan") then
                valid_piece_count = valid_piece_count + 1
                Sliced_Pieces[valid_piece_count] = {
                    code = ghost_marker .. piece,
                    vx = mask.cx - box.cx, 
                    vy = mask.cy - box.cy 
                }
            end
        end
        remember( cache_key, Sliced_Pieces )
    end
    
    if j == 1 then maxloop(#Sliced_Pieces > 0 and #Sliced_Pieces or 1) end
    
    -- FASE DE EXTRACCIÓN
    local piece_data = Sliced_Pieces[j]
    if not piece_data then return "" end

    local final_piece_code = piece_data.code
    local sep_x, sep_y = 0, 0
    if type( Separation ) == "number" then
        sep_x, sep_y = Separation, Separation
    elseif type( Separation ) == "table" then
        sep_x, sep_y = tonumber( Separation[1] ) or 0, tonumber( Separation[2] ) or tonumber( Separation[1] ) or 0
    end

    if sep_x ~= 0 or sep_y ~= 0 then
        final_piece_code = shape.displace(final_piece_code, piece_data.vx * sep_x, piece_data.vy * sep_y)
    end

    return final_piece_code
end