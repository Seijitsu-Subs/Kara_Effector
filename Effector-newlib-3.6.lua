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

	--> https://x.com/SeijitsuSubs
	--> [Discord] @trotacalles
	
	-- Effector-newlib-3.6.lua -------------------------------------------------------------------------------------
	Effector_NewLib_authors  = "Itachi Akatsuki"
	Effector_NewLib_testers  = "NatsuoKE & Vict8r"
	Effector_NewLib_version  = "1.0"
	Effector_NewLib_modified = "September 19th 2025 by Seijitsu_Subs"
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

  Retorna:
    - Un string con el tag \clip o \iclip generado.
]]

function tag.create_clip_grid(current_index, cols, rows, box, mode, is_inverse)
	-- Validar y establecer valores por defecto
	local i = current_index or 1
	local c = cols or 1
	local r = rows or 1
	local m = mode or 79
	local inv = is_inverse or false
	local b = box or { x = 0, y = 0, w = xres, h = yres }

	-- Calcular tamaño de cada celda
	local cell_w = b.w / c
	local cell_h = b.h / r

	-- Calcular fila y columna
	local col_idx, row_idx = 0, 0
	
	-- Basado en la lógica de effector.do_fx para los diferentes modos de barrido
	if m == 13 or m == 17 or m == 31 or m == 39 or m == 71 or m == 79 or m == 93 or m == 97 then
		if m == 17 or m == 39 or m == 71 or m == 93 then -- Barrido Vertical Primero
			col_idx = math.floor((i - 1) / r)
			row_idx = (i - 1) % r
		else -- Barrido Horizontal Primero
			col_idx = (i - 1) % c
			row_idx = math.floor((i - 1) / c)
		end
		-- Revertir dirección para modos específicos
		if m == 31 or m == 39 or m == 93 or m == 97 then
			col_idx = c - 1 - col_idx
		end
		if m == 13 or m == 17 or m == 31 or m == 39 then
			row_idx = r - 1 - row_idx
		end
	else
		-- Por defecto para modos no estándar (como 5, 7, etc.), usar el modo 79
		col_idx = (i - 1) % c
		row_idx = math.floor((i - 1) / c)
	end

	-- Calcular coordenadas
	local cx1 = b.x + col_idx * cell_w
	local cy1 = b.y + row_idx * cell_h
	local cx2 = cx1 + cell_w
	local cy2 = cy1 + cell_h
	
	-- Construir y devolver el tag
	local tag_type = inv and "iclip" or "clip"
	
	-- Se redondean los valores para asegurar que el formato sea correcto
	return string.format("\\%s(%s,%s,%s,%s)", tag_type, math.round(cx1,2), math.round(cy1,2), math.round(cx2,2), math.round(cy2,2))
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

	-- Casos base: si no hay colores o solo hay uno, no se puede interpolar.
	if #colors < 1 then return "&H000000&" end -- Retorna negro si no se proveen colores
	if #colors == 1 then return color.ass(colors[1]) end -- Retorna el único color provisto

	-- Asegura que pct esté en el rango [0, 1]
	local pct = math.clamp( pct or 0, 0, 1 )

	-- Calcula en qué segmento del gradiente se encuentra el pct.
	-- Por ejemplo, con 4 colores, hay 3 segmentos. Un pct de 0.6 se encuentra en el segundo segmento (entre el color 2 y 3).
	local position = pct * (#colors - 1)
	
	-- Determina los dos colores que rodean la posición.
	local index_start = math.floor(position) + 1
	local index_end = math.min(index_start + 1, #colors) -- math.min para evitar irse fuera de los límites si pct es 1.0

	-- Calcula el porcentaje local *dentro* de ese segmento específico.
	-- Por ejemplo, si estamos en el 50% del camino entre el color 2 y 3, local_pct será 0.5.
	local local_pct = position - math.floor(position)
	if local_pct == 0 and pct == 1.0 then
		-- Caso especial para cuando pct es exactamente 1, para asegurar que se use el último color.
		return color.ass(colors[#colors])
	end

	local color1 = color.ass( colors[index_start] )
	local color2 = color.ass( colors[index_end] )

	-- Usa la función de interpolación existente para el segmento final.
	return color.interpolate(local_pct, color1, color2)
end

-- Asegura que Calculate existe.
Calculate = Calculate or {}

function calculate.extratime(ctx, progression_per_char, fade_duration, start_delay, end_delay, desired_gap, max_added_time)
    -- Asignación de valores por defecto si no se proporcionan.
    local start_delay = start_delay or 250
    local end_delay = end_delay or 250
    local desired_gap = desired_gap or 50
    local max_added_time = max_added_time or 800
    
    -- Comprobar si es la última línea de la SELECCIÓN.
    if ctx.line.i >= ctx.line.n then
        return 0
    end

    -- Obtener las propiedades de la siguiente línea en la SELECCIÓN.
    local next_line_index_in_file = ctx.idx_line[ctx.l_counter + 1]
    local next_line_index_in_linefx = next_line_index_in_file + ctx.count_line_dialogue - ctx.ini_line
    local next_line = ctx.linefx[next_line_index_in_linefx]
    
    -- Calcular el fin real de la animación actual.
    local actual_animation_end_time = ctx.l.end_time + end_delay + fade_duration
    
    -- Calcular el inicio real de la animación siguiente.
    local next_animation_start_time = next_line.start_time - start_delay
    
    -- Calcular el "Gap" actual.
    local current_gap = next_animation_start_time - actual_animation_end_time
    
    -- Calcular el tiempo extra necesario.
    local extra_time_needed = current_gap - desired_gap
    
    -- Aplicar restricciones.
    local final_extra_time = math.min(max_added_time, math.max(0, extra_time_needed))
    
    return final_extra_time
end

-- Ejemplo de uso:
-- Casilla end_time:
-- l.end_time + delay2 + Calculate.ExtraTime(line_context, progression_const, fade_dur)
-- Casilla variable:
-- progression_const = 35;
-- fade_dur = 150;
-- delay2 = 250;
-- ctx es extraído de Effector-3.6.lua



