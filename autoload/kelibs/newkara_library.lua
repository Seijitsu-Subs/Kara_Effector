	--CONFIGURATIONS
	local FP_PRECISION = 3		--floating point precision by numbers behind point (for shape points)
	local FONT_PRECISION = 64	--font scale for better precision output from native font system
	local SCALE_PATHS = 1000	--multiplication factor for the polygons in the clipper library
	local ROUND_NUM = 3			--number of decimal places used to round a numerical value
	local ROUND_MATRIX = 6		--number of decimal places used to round a numerical value in matrix
	local EPSILON = 1e-6		--if math.abs(value) < 0.000001 then the value is 0
	local RANDOM				--auxiliary variable for the ke.table.get(array, "random") function
	
	local templates = require("kelibs/newkara_fxlist")
	local ke
	
	ke = {
		math = {
			
			round = function(object, decimal)
				if type(object) == "table" then
					return ke.table.filter(object, function(k, v) return ke.math.round(v, decimal) end)
				end --recurse
				local dec = type(decimal) == "function" and decimal() or decimal or 0
				dec = type(dec) == "number" and math.floor(math.abs(dec)) or 0
				return tonumber(object)
					and math.floor(tonumber(object) * (10 ^ dec) + 0.5) / (10 ^ dec)
					or object
			end, --ke.math.round({1.6, 3.2, "0.9", x = "&HFF&"})
			
			rand = function(num1, num2, step, sign, ratio)
				--generates a random number from a specified values range
				local num1 = type(num1) == "function" and num1() or num1
				local num2 = type(num2) == "function" and num2() or num2
				local step = type(step) == "function" and step() or step or 1
				if type(num1) == "table" then
					local keys = {}
					for k, v in pairs(num1) do
						keys[#keys + 1] = k
					end
					return num1[keys[ke.math.rand(#keys)]]
				end --random in table
				local function fxrand(num1, num2)
					local offset = tonumber(tostring(os.time()):sub(-3, -1))
					if num2 == nil and num1 == nil then
						return ke.math.round(math.random(), 5)
					end
					if num2 == nil then
						if num1 == 0 then
							return 0
						end
						num1, num2 = 1, num1
					end
					local r1 = ke.math.round(math.min(num1, num2))
					local r2 = ke.math.round(math.max(num1, num2))
					return r1 + (math.random(r1, r2) + offset - 1) % (r2 - r1 + 1)
				end --random between two valors
				if num1 == nil then return fxrand() end
				if num2 == nil then return fxrand(num1) end
				local n1, n2 = math.min(num1, num2), math.max(num1, num2)
				step = step <= 0 and 1 or step
				if ratio then
					local xres = aegisub.video_size()
					local ratio = (xres or 1280) / 1280
					n1, n2, step = n1 * ratio, n2 * ratio, step * ratio
				end
				local result = n1 + fxrand(0, (n2 - n1) / step) * step
				result = result > n2 and n2 or result
				return sign and result * (-1) ^ ke.math.rand(2) or result
			end,
			
			count = function(init, step)
				--generates an independent counter to each assigned variable
				local s = step or 1
				local i = init and init - s or 0
				return function(mode, A, B, C)
					i = i + s
					local xt = function(v) return math.ceil(i / v) end --xt(A)
					if mode then
						local A, B, C = A or 1, B or 1, C or 1
						local D, E, f = A - B + 1, B - A + 1, math.floor
						local algorithms = {
							["+,-"] = (-1) ^ (xt(A) + 1),														-->(+,-) A-veces cada uno
							["A,B"] = A + ((B - A) / 2) * (1 + (-1) ^ xt(C)),									-->(A,B) C-veces cada uno
							["mxA"] = A * xt(B),																-->(mxA) B-veces los múltiplos de A
							["A>B"] = (A <= B) and (xt(C) - 1) % E + A or -1 * ((xt(C) - 1) % D - A),			-->(A-->B) C-veces cada uno
							["ABB"] = A * f(1 / i) + B * (1 - f(1 / i)),										-->(A,BB) primero A y el resto B
							["ABA"] = ((A > B)																	-->(A-->B-->A)
								and B + D - ((D - 1 - (D - 1) * xt(D - 1) + i) * (-1) ^ (xt(D - 1) + 1) + (D + 1) * (1 + (-1) ^ xt(D - 1)) / 2)
								or  A + (E - 1 - (E - 1) * xt(E - 1) + i) * (-1) ^ (xt(E - 1) + 1) + (E + 1) * (1 + (-1) ^ xt(E - 1)) / 2 - 1),
							["ABC"] = A * f((C * xt(C) - i + 1) / C) + B * (1 - f((C * xt(C) - i + 1) / C)),	-->(A<->BB) primer A y (C-1)veces B
							["ACB"] = A * (1 - f((C - C * xt(C) + i) / C)) + B * f((C - C * xt(C) + i) / C),	-->(AA<->B) (C-1)veces A y un B
							["N,n"] = f((i - 1) / A) + 1,														-->(N,n) los Naturales A-veces cada uno
						}
						return tostring(algorithms[mode]) == "-0" and 0 or algorithms[mode]
					end
					return i
				end
			end,
			
			angle = function(x1, y1, x2, y2, x3, y3)
				--angle between one (and origin), two or three points (ASSDraw3 coordinates)
				local points = ke.math.getnumbers(x1, y1, x2, y2, x3, y3)
				local x1, y1, x2, y2, x3, y3 = table.unpack(points)
				if x2 == nil then
					x2, y2, x1, y1 = x1, y1, 0, 0
				end --for cartesian coordinates: ang = 360 - ang
				local a1 = math.deg(math.atan2(y1 - y2, x2 - x1))
				local a2 = (x3 and y3) and math.deg(math.atan2(y2 - y3, x3 - x2)) or nil
				a1, a2 = a1 < 0 and a1 + 360 or a1, a2 and (a2 < 0 and a2 + 360 or a2) or nil
				local ang = a2 and 180 - a1 + a2 or a1
				return ke.math.round(ang < 0 and ang + 360 or (ang > 360 and ang - 360 or ang), ROUND_NUM)
			end, --ke.math.angle(4, 5)
			
			polar = function(angle, radius, Return)
				--coordinates of the point located at the assigned angle and radius, with respect to the origin
				local angle = type(angle) == "function" and angle() or angle
				local radius = type(radius) == "function" and radius() or radius
				local Px = ke.math.round(radius * math.cos(math.rad(angle)), ROUND_NUM)
				local Py = ke.math.round(-radius * math.sin(math.rad(angle)), ROUND_NUM)
				return (Return ~= "y" and Px or Py), not Return and Py or nil
			end, --ke.math.polar(45, 10)
			
			distance = function(x1, y1, x2, y2)
				--distance between two points or a point and the origin (0, 0)
				local points = ke.math.getnumbers(x1, y1, x2, y2)
				if #points > 4 then
					local polylength = 0
					for i = 3, #points, 2 do
						polylength = polylength + ke.math.distance(points[i], points[i + 1], points[i - 2], points[i - 1])
					end
					return polylength
				end --recurse
				local x1, y1, x2, y2 = table.unpack(points)
				return not x1 and 0 or ke.math.round(((x1 - (x2 or 0)) ^ 2 + (y1 - (y2 or 0)) ^ 2) ^ 0.5, ROUND_NUM)
			end, --ke.math.distance(0, 0, 3, 4)
			
			intersect = function(x1, y1, x2, y2, x3, y3, x4, y4)
				--intercept point between lines defined at four points
				local points = ke.math.getnumbers(x1, y1, x2, y2, x3, y3, x4, y4)
				local x1, y1, x2, y2, x3, y3, x4, y4 = table.unpack(points)
				if (x1 == x3 and y1 == y3) or (x1 == x4 and y1 == y4) then
					return x1, y1, 0
				elseif (x2 == x3 and y2 == y3) or (x2 == x4 and y2 == y4) then
					return x2, y2, 1
				end
				local t = ((x3 - x1) * (y3 - y4) - (x3 - x4) * (y3 - y1)) / ((x2 - x1) * (y3 - y4) - (x3 - x4) * (y2 - y1))
				if (x2 - x1) * (y3 - y4) - (x3 - x4) * (y2 - y1) == 0 then
					return "parallels"
				end
				local x, y = ke.math.round(x1 + t * (x2 - x1), ROUND_NUM), ke.math.round(y1 + t * (y2 - y1), ROUND_NUM)
				return x, y, t
			end, --{ke.math.intersect("2 7 11 3 ", "4 3 6 8 ")}
			
			factk = function(n)
				--factorial of number n
				local n_factk, n = 1, type(n) == "function" and n() or n
				for i = 2, math.abs(ke.math.round(n)) do
					n_factk = n_factk * i
				end
				return n_factk
			end,
			
			i = function(counter, A, B, C)
				--generates a numerical sequence based on predetermined algorithms
				local i = type(counter) == "function" and counter() or counter
				local A = type(A) == "function" and A() or A or 1
				local B = type(B) == "function" and B() or B or 1
				local C = type(C) == "function" and C() or C or 1
				local D, E, f = A - B + 1, B - A + 1, math.floor
				local xt = function(v) return math.ceil(i / v) end
				local algorithms = {
					["+,-"] = (-1) ^ (xt(A) + 1),														-->(+,-) A-veces cada uno
					["A,B"] = A + ((B - A) / 2) * (1 + (-1) ^ xt(C)),									-->(A,B) C-veces cada uno
					["mxA"] = A * xt(B),																-->(mxA) B-veces los múltiplos de A
					["A>B"] = (A <= B) and (xt(C) - 1) % E + A or -1 * ((xt(C) - 1) % D - A),			-->(A-->B) C-veces cada uno
					["ABB"] = A * f(1 / i) + B * (1 - f(1 / i)),										-->(A,BB) primero A y el resto B
					["ABA"] = ((A > B)																	-->(A-->B-->A)
						and B + D - ((D - 1 - (D - 1) * xt(D - 1) + i) * (-1) ^ (xt(D - 1) + 1) + (D + 1) * (1 + (-1) ^ xt(D - 1)) / 2)
						or  A + (E - 1 - (E - 1) * xt(E - 1) + i) * (-1) ^ (xt(E - 1) + 1) + (E + 1) * (1 + (-1) ^ xt(E - 1)) / 2 - 1),
					["ABC"] = A * f((C * xt(C) - i + 1) / C) + B * (1 - f((C * xt(C) - i + 1) / C)),	-->(A<->BB) primer A y (C-1)veces B
					["ACB"] = A * (1 - f((C - C * xt(C) + i) / C)) + B * f((C - C * xt(C) + i) / C),	-->(AA<->B) (C-1)veces A y un B
					["N,n"] = f((i - 1) / A) + 1,														-->(N,n) los Naturales A-veces cada uno
				}
				for k, v in pairs(algorithms) do
					algorithms[k] = tostring(v) == "-0" and 0 or v
				end
				return algorithms
			end,
			
			circle = function(shp)
				--coordinates of the center and radius of a circle from three points in a clip/shape
				local shp = ke.shape.new(shp).code
				if type(shp) == "table" then
					local recursion_tbl = {}
					for k, v in pairs(shp) do
						recursion_tbl[k] = {ke.math.circle(v)}
					end
					return recursion_tbl
				end --recurse
				local coor = ke.string.array(shp, "number")
				local P1 = {x = coor[1], y = coor[2], z = -(coor[1] ^ 2 + coor[2] ^ 2)}
				local P2 = {x = coor[3], y = coor[4], z = -(coor[3] ^ 2 + coor[4] ^ 2)}
				local P3 = {x = coor[5], y = coor[6], z = -(coor[5] ^ 2 + coor[6] ^ 2)}
				local Det_i = (P1.x * P2.y + P2.x * P3.y + P3.x * P1.y) - (P1.y * P2.x + P2.y * P3.x + P3.y * P1.x)
				local Det_D = (P1.z * P2.y + P2.z * P3.y + P3.z * P1.y) - (P1.y * P2.z + P2.y * P3.z + P3.y * P1.z)
				local Det_E = (P1.x * P2.z + P2.x * P3.z + P3.x * P1.z) - (P1.z * P2.x + P2.z * P3.x + P3.z * P1.x)
				local Det_F = (P1.x * P2.y * P3.z + P2.x * P3.y * P1.z + P3.x * P1.y * P2.z) - (P1.z * P2.y * P3.x + P2.z * P3.y * P1.x + P3.z * P1.y * P2.x)
				local Cd, Ce, Cf = Det_D / Det_i, Det_E / Det_i, Det_F / Det_i
				local Cx, Cy = ke.math.round(-Cd / 2, ROUND_NUM), ke.math.round(-Ce / 2, ROUND_NUM)
				local radius = ke.math.round(((Cd / 2) ^ 2 + (Ce / 2) ^ 2 - Cf) ^ 0.5, ROUND_NUM)
				return Cx, Cy, radius
			end,
			
			rotate = function(p, angle, axis)
				--rotation a point p(x, y, z) in space, about the selected axis
				local p = type(p) == "function" and p() or p
				if ke.table.type(p) == "table" then
					return ke.table.recursive(p, ke.math.rotate, angle, axis)
				end --recurse
				local rot_p, axis = {}, axis or "z"
				if type(p) == "string" and p:match("%-?%d[%.%d]*%s+%-?%d[%.%d]*") then
					local filter_rotation = function(x, y)
						local rot = ke.math.rotate({x, y}, angle, axis)
						return ("%s %s"):format(rot.x, rot.y)
					end
					rot_p = p:gsub("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)", filter_rotation)
					return rot_p
				end
				local angle = math.rad(type(angle) == "function" and angle() or angle or 0)
				local x, y, z = tonumber(p.x or p[1]) or 0, tonumber(p.y or p[2]) or 0, tonumber(p.z or p[3]) or 0
				rot_p.x = axis == "x" and x or axis == "y" and math.cos(angle) * x + math.sin(angle) * z or math.cos(angle) * x - math.sin(angle) * y
				rot_p.y = axis == "x" and math.cos(angle) * y - math.sin(angle) * z or axis == "y" and y or math.sin(angle) * x + math.cos(angle) * y
				rot_p.z = axis == "x" and math.sin(angle) * y + math.cos(angle) * z or axis == "y" and math.cos(angle) * z - math.sin(angle) * x or z
				return rot_p
			end, --ke.math.rotate(ke.shape.rectangle, 20, "z")
			
			to16 = function(num)
				--converts a number from decimal base to hexadecimal base
				local num = type(num) == "function" and num() or num
				if type(num) == "table" then
					return ke.table.recursive(num, ke.math.to16)
				end --recurse		
				return ("%X"):format(ke.math.round(num))
			end, --math.to16({255, 40, x = 12})
			
			clamp = function(num, menor, mayor, cycle)
				--restricts a number between a minimum and a maximum value
				local num = type(num) == "function" and num() or num or 0.5
				if type(num) == "table" then
					return ke.table.recursive(num, ke.math.clamp, menor, mayor, cycle)
				end --recurse
				local menor = type(menor) == "function" and menor() or menor or 0
				local mayor = type(mayor) == "function" and mayor() or mayor or 1
				local c_min, c_max, ci = math.min(menor, mayor), math.max(menor, mayor)
				if cycle then --is cyclically restricted
					num = ke.math.round(num * 10000)
					c_min = ke.math.round(c_min * 10000)
					c_max = ke.math.round(c_max * 10000)
					ci = ke.math.count(num - c_min)
					return ke.math.round(ci("ABA", c_min, c_max) / 10000, 3)
				end --math.clamp(-0.2 + 1.5m)
				return num < c_min and c_min or (num > c_max and c_max or num)
			end, --ke.math.clamp(3, 5, 10)
			
			quadratic = function(c1, c2, c3)
				local d = c2 * c2 - 4 * c1 * c3
				if d > EPSILON then
					local sd = math.sqrt(d)
					return {(-c2 - sd) / (2 * c1), (-c2 + sd) / (2 * c1)}
				elseif math.abs(d) <= EPSILON then
					return {(-c2)/(2 * c1)}
				end
				return {}
			end,
			
			cubic = function(c1, c2, c3, c4)
				local function cbrt(x) return x >= 0 and x ^ (1 / 3) or -((-x) ^ (1 / 3)) end
				local a = 1 / c1
				local b, c, d = c2 * a, c3 * a, c4 * a
				local offset = b / 3
				local p = c - b * b / 3
				local q = (2 * b * b * b) / 27 - (b * c) / 3 + d
				local D = (q * q) / 4 + (p * p * p) / 27
				local roots = ke.table.new()--{}
				if D > EPSILON then
					local sD = math.sqrt(D)
					local u, v = cbrt(-q / 2 + sD), cbrt(-q / 2 - sD)
					local z = u + v
					roots:insert(z - offset)
				elseif math.abs(D) <= EPSILON then
					local u = cbrt(-q / 2)
					local z1, z2 = 2 * u, -u
					roots:insert(z1 - offset)
					roots:insert(z2 - offset)
				else
					local phi = math.acos(math.max(-1, math.min(1, (-q / 2) / math.sqrt(-(p * p * p) / 27))))
					local r = 2 * math.sqrt(-p / 3)
					local z1 = r * math.cos(phi / 3)
					local z2 = r * math.cos((2 * math.pi + phi) / 3)
					local z3 = r * math.cos((4 * math.pi + phi) / 3)
					roots:insert(z1 - offset)
					roots:insert(z2 - offset)
					roots:insert(z3 - offset)
				end
				return roots("org")
			end,
			
			equality = function(n1, n2, tolerance)
				--defines a maximum tolerance for two numbers to be considered equal
				return math.abs(n1 - n2) < 0.1 ^ ((tolerance or 5) - 1)
			end,
			
			getpair = function(val, defx, defy)
				local nums = ke.math.getnumbers(val)
				local vx, vy = nums[1] or defx or 0, nums[2] or defy or 0
				return {vx, vy}
			end,
			
			normalize = function(t, accel, shape)
				local a = accel or 1
				if type(t) == "table" then
					a = t.accel or accel or 1
					s = t.shape or shape
					t = t.t
				end
				t = ke.math.clamp(type(a) == "function" and a(t) or t ^ a)
				if s and s:match("m%s+%-?%d[%.%-%d mlb]*") then
					--interpolation by "y" value from shape
					local normshp = ke.recall.normshp or ke.recall.remember("normshp", ke.shape.new(s))
					local height, p = normshp.height, normshp:getpoint(t)
					t = height == 0 and 0 or math.abs(p.y) / height
				end --ke.math.normalize(0.25, nil, ke.shape.circle)
				return t --[0, 1]
			end, --ke.math.normalize(0.75, function(t) retrun math.sin(t * 2 * math.pi) end)
			
			ipol = function(values, t, accel, shape, size)
				if size then
					return ke.table.new(size, function(i) return ke.math.ipol(values, (i - 1) / (size - 1), accel, shape) end)
				end
				local values = type(values) == "number" and {0, values} or values
				local t = ke.math.normalize(t, accel, shape)
				if t == 0 then
					return values[1]
				end --ke.math.ipol({0, 30, 20}, 0.25, 0.8, ke.shape.circle)
				local n = #values
				local seg = math.ceil(t * (n - 1))
				local ini, fin = values[seg], values[seg + 1]
				local u = t * (n - 1) - (seg - 1)
				return ke.math.round(ini + u * (fin - ini), ROUND_NUM)
			end, --ke.math.ipol({0, 30, 20}, 0.7)
			
			format = function(str, ...)
				-- assigns values to a format string
				local str = type(str) == "function" and str() or str
				local values = type(... or true) == "table" and ... or {...}
				values = #values == 0 and {1} or values
				if type(str) == "table" then
					return ke.table.recursive(str, ke.math.format, ...)
				end --recurse
				local icount = ke.string.count(str, "%%[aAcdeEfgGioqsuxX]^*") -- string.format modes
				local str = str:format(unpack(ke.table.get(values, "newlen", icount)))
				return ke.string.toval(str)
			end, --ke.math.format("5 + 7")
			
			getnumbers = function(...)
				local array, result = {...}, ke.table.new()
				array = (#array == 1 and type(array[1]) == "table") and array[1] or array
				array = ke.table.get(array, "tonumber")
				for _, v in ipairs(array) do
					if type(tonumber(v)) == "number" then
						result:insert(tonumber(v))
					end
				end
				return result
			end, --ke.math.getnumbers({{x = 1, y = 2}, "7 8 ", 3, 4, x = 10, y = 11})
			
			gauss = function(matrix)
				local n = #matrix
				local A = ke4.table.copy(matrix)
				for k = 1, n do
					local max_val = math.abs(A[k][k])
					local pivot_row = k
					for i = k + 1, n do
						if math.abs(A[i][k]) > max_val then
							max_val = math.abs(A[i][k])
							pivot_row = i
						end
					end
					if max_val < EPSILON then
						return nil, "singular system"
					end
					if pivot_row ~= k then
						local temp_row = A[k]
						A[k] = A[pivot_row]
						A[pivot_row] = temp_row
					end
					local pivot = A[k][k]
					for j = k, n + 1 do
						A[k][j] = A[k][j] / pivot
					end
					for i = k + 1, n do
						local factor = A[i][k]
						for j = k, n + 1 do
							A[i][j] = A[i][j] - factor * A[k][j]
						end
					end
				end
				local solutions = {}
				for i = n, 1, -1 do
					local sum = 0
					for j = i + 1, n do
						sum = sum + A[i][j] * solutions[j]
					end
					solutions[i] = A[i][n + 1] - sum
				end
				return ke.math.round(solutions, ROUND_MATRIX)
			end,
			
			matrix = { --subclass
				
				__name = "matrix",
				__metatable = "matrix",
				__index = function(self, key)
					local __cache = rawget(self, key)
					if __cache ~= nil then
						return __cache
					end
					if key == "n" then
						return #self
					elseif key == "det" then
						return self:determinant()
					end
					return ke.math.matrix[key]
				end,
				
				__mul = function(self, other)
					local result = {}
					local n = self.n
					if type(self[1]) == "number" and getmetatable(other) == "matrix" then
						n = other.n --row matrix * matrix
						for j = 1, n do
							local sum = 0
							for k = 1, n do
								sum = sum + (self[k] or 0) * other[k][j]
							end
							result[j] = sum
						end
						return ke.math.matrix.new(result, true)
					end
					if type(other) == "number" then --matrix * scalar
						for i = 1, n do
							result[i] = {}
							for j = 1, n do
								result[i][j] = self[i][j] * other
							end
						end
						return ke.math.matrix.new(result)
					end
					if ke.table.type(other) == "point" then --matrix * point
						local vals, result = ke.math.getnumbers(other), {}
						for i = 1, n do
							result[i] = 0
							for j = 1, n do
								result[i] = result[i] + self[i][j] * (vals[j] or 0)
							end
						end --ke.math.matrix.__mul(ke.math.matrix.new({1,0,0,0,1,0,0,0,1}), ke.shape.point.new("l 10 20 "))
						local newp = ke.shape.point.new(result[1], result[2], other.t)
						newp.z, newp.w = result[3], result[4]
						return newp --point
					end
					for i = 1, n do --matrix * matrix
						result[i] = {}
						for j = 1, n do
							local sum = 0
							for k = 1, n do
								sum = sum + self[i][k] * other[k][j]
							end
							result[i][j] = sum
						end
					end
					return ke.math.matrix.new(result)
				end, --ke.math.matrix.new({2, 3, 1, 4, 1, -3, 2, 4, 1}) * 2
				
				__add = function(self, other)
					local result = {}
					local isrow = type(self[1]) == "number"
					for i = 1, self.n do
						result[i] = {}
						for j = 1, self.n do
							result[i][j] = self[i][j] + (type(other) == "number" and other or other[i][j])
						end
					end
					return ke.math.matrix.new(result, isrow)
				end,
				
				__sub = function(self, other)
					local result = {}
					local isrow = type(self[1]) == "number"
					for i = 1, self.n do
						result[i] = {}
						for j = 1, self.n do
							result[i][j] = self[i][j] - (type(other) == "number" and other or other[i][j])
						end
					end
					return ke.math.matrix.new(result, isrow)
				end,
				
				__unm = function(self)
					local result = {}
					local isrow = type(self[1]) == "number"
					for i = 1, self.n do
						result[i] = {}
						for j = 1, self.n do
							result[i][j] = -self[i][j]
						end
					end
					return ke.math.matrix.new(result)
				end,
				
				__eq = function(self, other)
					if self.n ~= other.n then
						return false
					end
					for i = 1, self.n do
						for j = 1, self.n do
							if not math.abs(self[i][j] - other[i][j]) < EPSILON then
								return false
							end
						end
					end
					return true
				end,
				
				__tostring = function(self)
					local s = "matrix" .. self.n .. "x" .. self.n .. "(\n"
					for i = 1, self.n do
						s = s .. "\t{"
						for j = 1, self.n do
							s = s .. string.format("%s", self[i][j])
							if j < self.n then s = s .. ", " end
						end
						s = s .. "}"
						if i < self.n then s = s .. ",\n" end
					end
					s = s .. "\n)"
					return s
				end,
				
				__type = function(self)
					return "matrix"
				end,
				
				new = function(data, isrow)
					local array = ke.table.type(data) == "matrix" and ke.math.matrix.toarray(data) or ke.math.getnumbers(data)
					local len = array.n
					if isrow then
						array = ke.math.round(array, ROUND_MATRIX)
						setmetatable(array, ke.math.matrix)
						return array
					end
					local n = math.sqrt(math.ceil(math.sqrt(len)) ^ 2)
					for i = 1, n * n do
						array[i] = ke.math.round(array[i] or 0, ROUND_MATRIX)
					end
					local m = array("inpack", n)
					setmetatable(m, ke.math.matrix)
					return m
				end, --ke.math.matrix.new({1,2,3,4})
				
				toarray = function(self)
					local result = ke.table.new()
					local n = self.n
					for i = 1, n do
						for j = 1, n do
							result:insert(self[i][j])
						end
					end
					return result
				end, --ke.math.matrix.toarray(ke.math.matrix.new({1,2,3,4}))
				
				identity = function(n)
					local n = math.ceil(n)
					local data = {}
					for i = 1, n do
						data[i] = {}
						for j = 1, n do
							data[i][j] = (i == j) and 1 or 0
						end
					end
					return ke.math.matrix.new(data)
				end,  --ke.math.matrix.identity(4)

				determinant = function(self)
					local n = self.n
					if n == 1 then
						return self[1][1]
					end
					local det, sign = 0, 1
					for j = 1, n do
						local element = self[1][j]
						local sub_m_data = {}
						local sub_row_idx = 1
						for row = 2, n do
							sub_m_data[sub_row_idx] = {}
							local sub_col_idx = 1
							for col = 1, n do
								if col ~= j then
									sub_m_data[sub_row_idx][sub_col_idx] = self[row][col]
									sub_col_idx = sub_col_idx + 1
								end
							end
							sub_row_idx = sub_row_idx + 1
						end
						local sub_matrix = ke.math.matrix.new(sub_m_data)
						det = det + sign * element * ke.math.matrix.determinant(sub_matrix)
						sign = -sign
					end
					return det
				end, --ke.math.matrix.new({2, 3, 4, 1}).det
				
				inverse = function(self)
					local det = self.det
					if math.abs(det) < EPSILON then
						return nil
					end
					local n = self.n
					local inv_m_data = {}
					local cofactor_matrix_data = {}
					for i = 1, n do
						cofactor_matrix_data[i] = {}
						for j = 1, n do
							local sub_m_data = {}
							local sub_row_idx = 1
							for row = 1, n do
								if row ~= i then
									sub_m_data[sub_row_idx] = {}
									local sub_col_idx = 1
									for col = 1, n do
										if col ~= j then
											sub_m_data[sub_row_idx][sub_col_idx] = self[row][col]
											sub_col_idx = sub_col_idx + 1
										end
									end
									sub_row_idx = sub_row_idx + 1
								end
							end
							local cofactor = 1
							if n > 1 then
								local sub_matrix = ke.math.matrix.new(sub_m_data)
								cofactor = ke.math.matrix.determinant(sub_matrix)
							end
							cofactor = (i + j) % 2 == 1 and -cofactor or cofactor
							cofactor_matrix_data[i][j] = cofactor
						end
					end
					for i = 1, n do
						inv_m_data[i] = {}
						for j = 1, n do
							inv_m_data[i][j] = cofactor_matrix_data[j][i] / det
						end
					end
					local inv_matrix = ke.math.matrix.new(inv_m_data)
					return inv_matrix --ke.math.matrix.new({2, 3, 1, 4, 1, -3, 2, 4, 1}):inverse()
				end, --ke.math.matrix.new({2, 3, 4, 1}):inverse()
				
				rotate = function(self, angles)
					local axis = {x = angles.x or 0, y = angles.y or 0, z = angles.z or 0}
					local sx, sy, sz = math.sin(math.rad(axis.x)), math.sin(math.rad(axis.y)), math.sin(math.rad(axis.z))
					local cx, cy, cz = math.cos(math.rad(axis.x)), math.cos(math.rad(axis.y)), math.cos(math.rad(axis.z))
					local matrix_rot = {
						[1] = cy * cz,	[2] = -cx * sz + sx * sy * cz,	[3] = sx * sz + cx * sy * cz,
						[4] = cy * sz,	[5] = cx * cz + sx * sy * sz,	[6] = -sx * cz + cx * sy * sz,
						[7] = -sy,		[8] = sx * cy,					[9] = cx * cy
					}
					return self * ke.math.matrix.new(matrix_rot)
				end, --ke.math.matrix.new({4, 0}, true):rotate()
				
			},
			
		},
		
		table = {
			__name = "ketable",
			
			["__index"] = function(self, key)
				local __cache = rawget(self, key)
				if __cache ~= nil then
					return __cache
				end
				return key == "n" and #self or ke.table[key]
			end,
			
			["new"] = function(array, support)
				local newself, e = {}
				if type(array) == "table" then
					newself = ke.table.copy(array)
					if type(support) == "function" then
						for k, v in pairs(newself) do
							v = support(k, v, newself)
							newself[k] = v
						end
					elseif support then
						newself = {}
						local key, val
						for i, v in ipairs(array) do
							key = type(v) == "string" and v or nil
							if key then
								val = type(support) == "table" and support[i] or nil
								val = type(support) ~= "table" and support or val
								newself[key] = val
							end
						end --ke.table.new({"w", "h"}, true)
					else
						for k, v in pairs(newself) do
							v = type(v) == "table" and ke.table.new(v) or v
							newself[k] = v
						end
					end
				elseif type(array) == "function" then
					--iterable function
					for A, B, C, D, E, F, G, H, M, N in array do
						local values = {A, B, C, D, E, F, G, H, M, N}
						if type(support) == "function" then
							for i, v in ipairs(values) do
								values[i] = support(i, v)
							end
						end
						local settab = type(support) == "number" and values[support] or (#values > 1 and values or values[1])
						table.insert(newself, settab) --ke.table.new(unicode.chars("demo"), 1)
					end --ke.table.new(shp:gmatch(("%d+") ("%d+")))
				elseif type(array) == "number" then
					local size = math.ceil(math.abs(array))
					for i = 1, size do
						e = not support and i or (type(support) ~= "function" and support or support(i))
						newself[#newself + 1] = type(e) == "table" and ke.table.copy(e) or e or nil
					end
				else
					newself = {array}
				end
				setmetatable(newself, ke.table)
				return newself
			end,
			
			["__call"] = function(self, mode, support)
				return mode and self:get(mode, support) or self:view()
			end,
			
			["__copy"] = function(array)
				local lookup = {}
				local function table_copy(array)
					if type(array) ~= "table" then
						return array
					elseif lookup[array] then
						return lookup[array]
					end
					local newself = {}
					lookup[array] = newself
					for k, v in pairs(array) do
						newself[table_copy(k)] = table_copy(v)
					end
					return setmetatable(newself, getmetatable(array))
				end
				return table_copy(array)
			end,
			
			["__sub"] = function(self, remove)
				--remove from the array the elements with the indicated indices
				return self:get("delete", remove)
			end,
			
			["__add"] = function(self, insert)
				--inserts at the end of the array, the element or the "insert" array
				return self:get("insert", insert)
			end,
			
			["__eq"] = function(self, other)
				--returns "false" or "true" when comparing two arrays
				if type(self) ~= type(other) then
					return false
				elseif type(self) ~= "table" and type(other) ~= "table" then
					return self == other
				end
				for k, v in pairs(self) do
					if (not other[k] or not ke.table.__eq(v, other[k]))
						or (other[k] and getmetatable(v) and getmetatable(v).__eq and v ~= other[k]) then
						return false
					end
				end
				return true
			end,
			
			view = function(array, name)
				--retorna en modo string el contenido completo de un array
				local array = type(array) == "function" and array() or array
				local cart, autoref
				local isemptytable = function(array)
					return next(array) == nil
				end
				local basicserialize = function(o)
					local so = tostring(o)
					if type(o) == "function" then
						local info = debug.getinfo(o, "S")
						if info.what == "C" then
							return ("%q"):format(so .. ", C function")
						end 
						return ("%q, defined in (lines: %s - %s), ubication %s"):format(
							so, info.linedefined, info.lastlinedefined, info.source
						)
					elseif type(o) == "number" or type(o) == "boolean" then
						return so
					end
					return ("%q"):format(so)
				end
				local function addtocart(value, name, indent, saved, field)
					indent, saved, field = indent or "", saved or {}, field or name
					cart = cart .. indent .. field
					if type(value) ~= "table" then
						cart = cart .. " = " .. basicserialize(value) .. ",\n"
					else
						if saved[value] then
							cart = cart .. " = {}, -- " .. saved[value] .. " (self reference)\n"
							autoref = autoref ..  name .. " = " .. saved[value] .. ",\n"
						else
							saved[value] = name
							if isemptytable(value) then
								cart = cart .. " = {},\n"
							else
								cart = cart .. " = {\n"
								for k, v in pairs(value) do
									k = basicserialize(k)
									local fname = ("%s[%s]"):format(name, k)
									field = ("[%s]"):format(k)
									addtocart(v, fname, indent .. "	", saved, field)
								end
								cart = ("%s%s},\n"):format(cart, indent)
							end
						end
					end
				end
				name = name or (type(array) == "table" and array.__name or "table_unnamed")
				name = (type(array) == "table" and array.__type) and array:__type() or name
				array = (type(array) == "table" and array.__view) and array:__view() or array
				if type(array) ~= "table" then
					return ("%s = %s"):format(name, basicserialize(array))
				end
				cart, autoref = "", ""
				addtocart(array, name, indent)
				return cart:sub(1, -3) .. "\n" .. autoref
			end,
			
			copy = function(self)
				return ke.table.__copy(self)
			end,
			
			recursive = function(self, f, ...)
				for k, v in pairs(self) do
					if type(v) ~= "table" then
						self[k] = f(v, ...)
					else
						ke.table.recursive(v, f, ...)
					end
				end --{"0:00:34.952", "0:00:44.920", "0:00:48.882"}
				return self
				--[[aplicar una función a los elementos de un array
				por2 = function(v) if type(v) == "number" then v = v * 2 end return v end
				tbl = {2, 3, "hola mundo!", {7, 8, x = 1}}
				tbl = ke.table.recursive(tbl, por2)
				print --> {4, 6, "hola mundo!", {14, 16, x = 2}}
				--]]
				
				--[[función parámetros extras
				por3 = function(v, add, exp)
					local exp = exp or 1
					local add = add or 0
					return type(v) == "number" and (v * 3 + add) ^ exp or v
				end
				tbl = {2, 3, "hola mundo!", {7, 8, x = 1}}
				tbl = ke.table.recursive(tbl, por3, 5, 2)
				--]]
				
				--[[extraer elementos
				alis = {}
				ins = function(v) table.insert(alis, v) end
				tbl = {2, 3, "hola mundo!", {7, 8, x = 1}, 0, {6, 7}}
				tbl = ke.table.recursive(tbl, ins)
				--]]
			end,
			
			insert = function(self, e, index, _unpack_)
				local newindex = index or #self + 1
				if type(newindex) == "function" then
					local idxs = {}
					for k, v in ipairs(self) do
						if newindex(k, v, self) then
							table.insert(idxs, k)
						end
					end
					for i = #idxs, 1, -1 do
						table.insert(self, idxs[i] + 1, e)
					end
					if #idxs == 0 then
						table.insert(self, e)
					end --tbl = {1, 2, -6, -7, 8}
					--ke.table.insert(tbl, 0, function(k, v, self) return k < #self and v * self[k + 1] < 0 end)
				else
					newindex = (type(newindex) == "number" and newindex < 0) and newindex % #self + 2 or newindex
					if type(newindex) ~= "number" or (type(newindex) == "number" and newindex > #self + 1) then
						newindex = #self + 1
					end
					local idx = ke.math.count()
					if type(e) == "table" and _unpack_ then
						for k, v in pairs(e) do
							local nk = type(k) == "number" and newindex + idx() - 1 or k
							if type(nk) == "number" then
								table.insert(self, nk, v)
							else
								self[nk] = v
							end
						end
					else
						if type(newindex) == "number" then
							table.insert(self, newindex, e)
						else
							self[newindex] = e
						end
					end
				end
			end,
			
			type = function(self)
				--indicates the elements type in an array
				local self, tpx = type(self) ~= "table" and {self} or self, {}
				if pcall(function() return self:__type() end) then
					return self:__type()
				end
				for _, v in pairs(self) do
					if pcall(function() return v:__type() end) then
						tpx[#tpx + 1] = v:__type()
					elseif type(v) == "string" then
						tpx[#tpx + 1] = v:match("m%s+%-?%d[%.%-%d mlb]*") and "shape"
						or (v:match("%-?%d[%.%d]*,[]*%-?%d[%.%d]*,[]*%-?%d[%.%d]*,[]*%-?%d[%.%d]*") and "clip")
						or (v:match("%x%x%x%x%x%x") and "color")
						or (v:match("%x%x") and "alpha")
						or (v:match("\\\\") and "tag") or "string"
					else
						tpx[#tpx + 1] = type(v)
					end
					if #tpx > 1 then
						tpx[#tpx] = (tpx[#tpx] == "number" and tpx[#tpx - 1] == "alpha") and "alpha" or tpx[#tpx]
						tpx[#tpx - 1] = (tpx[#tpx] == "alpha" and tpx[#tpx - 1] == "number") and "alpha" or tpx[#tpx - 1]
						if tpx[#tpx] ~= tpx[#tpx - 1] then
							return "mixed"
						end
					end --ke.table.type({25, "&HFF&", 80})
				end
				return #tpx > 0 and tpx[1] or "empty"
			end,
			
			compare = function(self, other)
				--returns "false" or "true" when comparing two arrays
				if type(self) ~= type(other) then
					return false
				elseif type(self) ~= "table" and type(other) ~= "table" then
					return self == other
				end
				local mt = getmetatable(self)
				if mt and mt.__eq then
					return self == other
				end
				for k, v in pairs(self) do
					if not other[k] or not ke.table.compare(v, other[k]) then
						return false
					end
				end
				return true
			end,
			
			concat = function(self, ...)
				--special concatenations between arrays
				local self = type(self) == "function" and self() or self
				local concats, Helpers = {...}
				if #concats == 0 then
					local aux = self[1]
					table.remove(self, 1)
					concats, self = ke.table.copy(self), ke.table.copy(aux)
				end
				Helpers = {
					[1] = function()
						local tbls = ke.table.get(concats, "outpack")
						local con1 = ke.table.new(#self * #tbls,
							function(i)
								return self[#self - #self * math.ceil(i / #self) + i] .. tbls[math.ceil(i / #self)]
							end
						)
						return con1
					end, --ke.table.concat({"\\1a"}, {"&HFF&", "&HAB&", "&H00&"})(1) = {"\\1a&HFF&", "\\1a&HAB&", "\\1a&H00&"}
					[2] = function()
						local tbls, con2 = ke.table.get(concats, "outpack"), ke.table.new(#self, "")
						for i = 1, #self do
							for k = 1, #tbls do
								con2[i] = con2[i] .. self[i] .. tbls[k]
							end
						end
						return con2
					end, --ke.table.concat({"\\foo", "\\bar"}, {0, 255})(2) = {"\\foo0\\foo255", "\\bar0\\bar255"}
					[3] = function()
						local tbls, con3 = ke.table.copy(concats), ke.table.copy(self)
						for i = 1, #tbls do
							tbls[i] = type(tbls[i]) ~= "table" and {tbls[i]} or tbls[i]
						end
						for i = 1, #self do
							for k = 1, #tbls do
								con3[i] = con3[i] .. tbls[k][(i - 1) % #tbls[k] + 1]
							end
						end
						return con3
					end, --ke.table.concat({"A", "B", "C"}, "1", {"x", "y"})(3) = {"A1x", "B1y", "C1x"}
					[4] = function()
						local tbls, con4 = ke.table.copy(concats), ke.table.copy(self)
						for i = 1, #tbls do
							tbls[i] = type(tbls[i]) ~= "table" and {tbls[i]} or tbls[i]
						end
						for i = 1, #self do
							for k = 1, #tbls do
								con4[i] = con4[i] .. (tbls[k][i] or "")
							end
						end
						return con4
					end, --ke.table.concat({"a", "b", "c", "d"}, {1, 2, 3})(4) = {"a1", "b2", "c3", "d"}
					[5] = function()
						local tbls = ke.table.copy(concats)
						for i = 1, #tbls do
							tbls[i] = type(tbls[i]) ~= "table" and {tbls[i]} or tbls[i]
						end
						local con5 = ke.table.new(#self * #tbls[1],
							function(i)
								return self[math.ceil(i / #tbls[1])] .. tbls[1][#tbls[1] - #tbls[1] * math.ceil(i / #tbls[1]) + i]
							end
						)
						for k = 2, #tbls do
							con5 = ke.table.new(#con5 * #tbls[k],
								function(i)
									return con5[math.ceil(i / #tbls[k])] .. tbls[k][#tbls[k] - #tbls[k] * math.ceil(i / #tbls[k]) + i]
								end
							)
						end
						return con5
					end, --ke.table.concat({"a", "b", "c"}, {1, 2}, "x")(5) = {"a1x", "a2x", "b1x", "b2x", "c1x", "c2x"}
				}
				return function(n) return Helpers[n]() end
			end,
			
			inside = function(self, e, capture)
				--returns "false" or "true" if an element, capture or element type, is inside an array
				if type(e) == "table" then
					for _, v in pairs(self) do
						if ke.table.compare(v, e) then
							return true
						end
					end --if "e"(array) is inside an array
				elseif type(e) == "string" then
					for _, v in pairs(self) do
						if ke.table.type(v) == e
							or ((capture and type(v) == "string") and v:match(capture) == e:match(capture))
							or (type(v) == "string" and (e == v or (e:match("%%") and v:match(e)))) then
							return true
						end --element type, equals string or capture in the strings element
					end --ke.table.inside({ 1, 2, "a4a" }, "%d[%.%d]*")
				end
				for _, v in pairs(self) do -- equals element
					if v == e then
						return true
					end
				end --ke.table.inside({1, 2, "a", "b", 3}, "string")
				return false
			end,
			
			index = function(self, e, capture)
				--returns the position or index of an element or element type in an array
				if type(e) == "table" then
					for k, v in pairs(self) do
						if ke.table.compare(v, e) then
							return k
						end
					end --if "e"(array) is inside an array
				elseif type(e) == "string" then
					for k, v in pairs(self) do
						if ke.table.type(v) == e
							or ((capture and type(v) == "string") and v:match(capture) == e:match(capture))
							or (type(v) == "string" and (e == v or (e:match("%%") and v:match(e)))) then
							return k
						end --element type, equals string or capture in the strings element
					end --ke.table.index({1, 2, "a4a"}, "%d[%.%d]*")
				end
				for k, v in pairs(self) do -- equals element
					if v == e then
						return k
					end
				end --ke.table.index({1, 2, "a", "b", 3}, "string")
				return false
			end,
			
			filter = function(self, support)
				--filter the elements of the array by means of a function or element types
				local f = support or "number"
				local newself, newv, newk = {}
				for k, v in pairs(self) do
					newv = type(f) == "string" and (type(v) == f and v or nil) or (type(f) == "function" and f(k, v, self) or nil)
					newk = type(k) == "number" and #newself + 1 or k
					newself[newk] = newv
				end
				return newself --impar = function(k, v) return v % 2 == 1 and v or nil end
			end, --ke.table.filter({1, 2, 3, "4", x = 5, 6, y = 9}, impar)
			
			get = function(self, mode, support)
				--perform multiple operations with the array elements
				local self = type(self) == "function" and self() or self
				local mode, operation = mode or "suma"
				self = ke.table.new(self)
				operation = {
					["add"] = function(self, support)
						--sum the elements with a number or with the elements of an array
						local newtable, aux = ke.table.new(), support
						if type(aux) == "table" then
							for i = 1, #self do --ke.table.get({3, 3, 3, 3}, "add", {{1, 2}})
								newtable[i] = self[i] + (ke.table.type(aux) == "table" and aux[1][(i - 1) % #aux[1] + 1] or (aux[i] or 0))
							end --ke.table.get({3, 3, 3, 3}, "add", {1, 1})
						else
							local aux = type(aux) == "number" and aux or 0
							for i = 1, #self do
								newtable[i] = type(self[i]) == "table" and operation.add(self[i], aux) or self[i] + aux
							end
						end
						return newtable
					end, --ke.table.get({1, 2, {3, 4, 5}}, "add", 10)
					
					["average"] = function(self)
						--arithmetic average of the numbers in the array
						local _average, tbl_ave = 0, operation.toval(self)
						for i = 1, #self do
							_average = _average + tbl_ave[i]
						end
						return #self > 0 and _average / #self or 0
					end, --ke.table.get({10, 8, 9, 6}, "average")
					
					["combine"] = function(self, support)
						--combinations of n size of an array
						local newtable, n, newrow = ke.table.new(), ke.math.round(math.abs(type(support) == "number" and support or 2))
						local aux = ke.table.new(n)
						while true do
							newrow = ke.table.new(n, function(i) return self[aux[i]] end)
							newtable:insert(newrow)
							local i = n
							while aux[i] == #self - n + i do
								i = i - 1
							end
							if i < 1 then break end
							aux[i] = aux[i] + 1
							for k = i, n do
								aux[k] = aux[i] + k - i
							end
						end
						return newtable
					end, --ke.table.get({"a", "b", "c", "d"}, "combine", 2)
					
					["count"] = function(self, support)
						--number of times an element is inside, capture or an element type, in the array
						local n, e = 0, support
						local types = {"function", "table", "string", "color", "alpha", "shape", "clip", "number", "boolean", "point", "segment", "polygon"}
						if type(e) == "table" then
							for k, v in pairs(self) do
								n = ke.table.compare(v, e) and n + 1 or n
							end --si la tabla "e" está dentro de la tabla
						elseif type(e) == "string" then
							if ke.table.inside(types, e) then
								for k, v in pairs(self) do
									n = type(v) == "table" and n + operation.count(v, e) or n
									n = ke.table.type(v) == e and n + 1 or n
								end --tipo de elemento
							else
								for k, v in pairs(self) do
									n = type(v) == "table" and n + operation.count(v, e) or n
									if type(v) == "string" then --captura en los elementos strings
										n = v:match(e) and n + 1 or n
									elseif v == e then
										n = n + 1
									end --strings iguales
								end
							end
						else
							for k, v in pairs(self) do
								n = type(v) == "table" and n + operation.count(v, e) or n
								n = v == e and n + 1 or n
							end --elementos iguales
						end
						return n
					end, --ke.table.get({1, 2, "a", {"bar", 3, 7}, x = 0}, "count", "number")
					
					["delete"] = function(self, support)
						--remove the indicated elements from the array
						local newtable, Index, self2 = {}, {}, ke.table.copy(self)
						local retire_e = type(support) == "table" and support or {support}
						local types = {"function", "string", "color", "alpha", "shape", "clip", "number", "boolean", "point", "segment", "polygon"}
						for k, v in pairs(self2) do
							Index[#Index + 1] = type(k) == "number" and k or nil
							newtable[k] = type(v) == "table" and operation.delete(v, retire_e) or v
							for key, val in pairs(retire_e) do
								if type(val) == "table" and ke.table.type(val) == "number" then
									newtable[k] = not (type(k) == "number" and k >= val[1] and k <= (val[2] or val[1])) and v or nil
								elseif type(val) == "table" then --según su índice (pairs)
									for _, indx in pairs(val) do
										if k == indx then
											newtable[k] = nil
											break
										end --ke.table.get({"n", "b", {0, 9, "b", "c"}, 2, 7}, "delete", {{1, 3}})
									end --ke.table.get({1, x = 2, {"n", x = "m 0 0 l 80 80 ", 3}, "&HFF&", "&H0000FF&"}, "delete", {"a", {"x"}})
								else --ke.table.get({1, 2, "m 0 0 l 80 80 "}, "delete", "shape")
									if type(val) == "string" and ke.table.inside(types, val) then --según el tipo de elemento
										newtable[k] = ke.table.type(v) ~= val and newtable[k] or nil
									elseif v == val then --elimima los elementos en retire_e
										newtable[k] = nil
									end --ke.table.get({"m", 0, "b", {0, 9, "b", "c"}, 2, 7}, "delete", {"b", "a"})
								end
							end --ke.table.get({[9] = 9, [3] = 3, [4] = 4, [5] = 5, [6] = 6, x = {0, 0}}, "delete", {{4}})
						end --ke.table.get({"n", "b", {0, 9, "b", "c"}, 2, 7}, "delete", "b")
						Index = operation.org(Index)
						for i = 2, #Index do
							if Index[i] - Index[i - 1] ~= 1 then
								return newtable
							end
						end
						return operation.idx(newtable)
					end, --ke.table.get({"n", "b", "c"}, "delete", "b")
					
					["disorder"] = function(self)
						--randomly shuffles the content of an indexed array
						local newtable, newt = ke.table.new(), ke.table.copy(self)
						while #newt > 0 do
							idx = ke.math.rand(1, #newt)
							newtable:insert(newt[idx])
							newt = operation.delete(newt, {{idx}})
						end
						return newtable --ke.table.get(10, "disorder")
					end, --ke.table.get({"A", "B", "C", "D", "E"}, "disorder")
					
					["idx"] = function(self, support)
						--organize by index the elements of the table and omit the nils
						local self = support and operation.toval(self) or self
						local newtable, index_num, index_key, key = ke.table.new(), {}, {}
						for k, v in pairs(self) do
							index_num[#index_num + 1] = type(k) == "number" and k or nil
							index_key[#index_key + 1] = type(k) ~= "number" and k or nil
						end
						index_num = operation.org(index_num)
						for i = 1, #index_num do
							key = index_num[i]
							newtable[#newtable + 1] = self[key]
						end
						for i = 1, #index_key do
							key = index_key[i]
							newtable[key] = self[key]
						end --ke.table.get({[5] = "E", [2] = "B", x = 0, y = {[6] = "F", [3] = "C", [1] = "A"}}, "idx")
						for k, v in pairs(newtable) do
							newtable[k] = type(v) == "table" and operation.idx(v) or v
						end
						return newtable
					end, --ke.table.get({1, [9] = 2, 3, 4, x = 0}, "idx")
					
					["inpack"] = function(self, support)
						--pack the array elements, into groups
						local parts = support or 2
						parts = type(support) == "table" and math.ceil(#self / support[1]) or parts
						local newtable = ke.table.new(math.ceil(#self / parts), {})
						for i = 1, math.ceil(#self / parts) do
							for k = 1, parts do
								newtable[i][k] = self[(i - 1) * parts + k]
							end
						end
						return newtable
					end, --ke.table.get(10, "inpack", 3)
					
					["insert"] = function(self, support)
						--insert "support" at the end of the array
						local newtable = ke.table.new(self)
						local support = type(support) == "table" and support or {support}
						for k, v in pairs(support) do
							k = type(k) == "number" and #newtable + 1 or k
							newtable[k] = v
						end --ke.table.get({1, 2, 3}, "insert", {"a", x = 8, 7})
						return newtable
					end,
					
					["inverse"] = function(self)
						--invert the position of the array elements
						local newtable, ini = ke.table.new(), self[0] and 0 or 1
						for k, v in pairs(self) do
							newtable[k] = type(k) == "number" and self[#self - k + ini] or v
						end
						return newtable
					end, --ke.table.get({1, 2, 3, 4, 5}, "inverse")
					
					["max"] = function(self)
						--maximum array value
						local newtable = operation.org(self)
						return newtable[#newtable] and newtable[#newtable] or 0
					end, --ke.table.get({1, 3, 5, 7}, "max")
					
					["move"] = function(self, support)
						--shifts the indices of the array an integer number of positions
						local newtable = ke.table.new()
						local support = type(support) == "number" and math.ceil(math.abs(support)) or support or 0
						if type(support) == "number" then
							for k, v in pairs(self) do
								k = type(k) == "number" and k + support or k
								newtable[k] = v
							end --ke.table.get({1, 2, 3, 4, 5}, "move", 2)
						elseif type(support) == "table" and type(support[1]) == "number" then
							support = math.ceil(math.abs(support[1]))
							local n = #self
							for k, v in pairs(self) do
								newtable[k] = type(k) == "number" and self[1 + (support + k - 2) % n] or v
							end --ke.table.get({1, 2, 3, 4, 5, x = 0}, "move", {3})
						end
						return newtable
					end,
					
					["min"] = function(self)
						--minimum array value
						local newtable = operation.org(self)
						return newtable[1] and newtable[1] or 0
					end, --ke.table.get({1, 3, 5, 7}, "min")
					
					["newlen"] = function(self, support)
						--modify the array size using its own elements
						local newtable, n = ke.table.new(), support or #self
						if type(n) == "table" then
							local tbl1, tbl2 = ke.table.new(#self, math.floor(n[1] / #self)), ke.table.new(n[1] % #self, 1)
							local new_t = operation.add(tbl1, tbl2)
							for i = 1, #self do
								for k = 1, new_t[i] do
									newtable:insert(self[i])
								end
							end --ke.table.get({"a", "b", "c"}, "newlen", {5})
						elseif type(n) == "number" then
							newtable = ke.table.new(n, function(i) return self[(i - 1) % #self + 1] end)
						elseif type(tonumber(n)) == "number" then
							for i = 1, tonumber(n) do
								for k = 1, #self do
									newtable:insert(type(self[k]) == "function" and self[k]() or self[k])
								end
							end --ke.table.get({"a", "b", "c"}, "newlen", "2")
						end --ke.table.get({"a", "b", "c"}, "newlen", 5)
						return newtable
					end,
					
					["org"] = function(self)
						--returns the array with the numbers arranged in ascending order
						local newtable = operation.toval(self)
						table.sort(newtable, function(a, b)
							a = type(a) == "table" and a[1] or a
							b = type(b) == "table" and b[1] or b
							return a < b end
						)
						return newtable
					end, --ke.table.get({4, 1, 3, {2, "x"}}, "org")
					
					["order"] = function(self)
						--arranges the elements of a string array in alphabetical order
						local newtable = ke.table.new(self)
						table.sort(newtable,
							function(a, b)
								local _, _, col1, num1 = tostring(a):find("^(.-)%s*(%d+)$")
								local _, _, col2, num2 = tostring(b):find("^(.-)%s*(%d+)$")
								if col1 and col2 and col1 == col2 then
									return tonumber(num1) < tonumber(num2)
								end
								return a < b
							end
						)
						return newtable
					end, --ke.table.get({"dog", "cat", "hen", "cow", "pig"}, "order")
					
					["outpack"] = function(self)
						--"unpacks" all the array contents into a single indexed array
						local function tbl_ipairs(self)
							local index, keys = {}, {}
							for k, v in pairs(self) do
								v = type(v) == "table" and tbl_ipairs(v) or v
								if type(k) ~= "number" then
									keys[#keys + 1], index[k], self[k] = k, v
								end
							end
							keys = operation.order(keys)
							for i = 1, #keys do
								self[#self + 1] = index[keys[i]] 
							end
							return self
						end
						local function tbl_unpack(tbl, self)
							for k, v in pairs(self) do
								tbl = type(v) == "table" and tbl_unpack(tbl, v) or tbl
								tbl[#tbl + 1] = type(v) ~= "table" and v or nil
							end
							return tbl
						end
						return tbl_unpack(ke.table.new(), tbl_ipairs(self))
					end, --ke.table.get({{x = 1, y = 2}, "7 8 ", 3, 4, x = 10, y = 11}, "outpack")
					
					["permute"] = function(self)
						--returns an array with the combinations of the elements
						local newtable = ke.table.new()
						local function output(per)
							local inside = {}
							for _, v in ipairs(per) do
								inside[#inside + 1] = v
							end
							newtable:insert(inside)
						end
						local function permutation(per, n)
							if n == 0 then
								output(per)
							else
								for i = 1, n do
									per[n], per[i] = per[i], per[n]
									permutation(per, n - 1)
									per[n], per[i] = per[i], per[n]
								end
							end
						end
						local n = #self
						permutation(self, n)
						return newtable
					end, --ke.table.get({1, 2, 3}, "permute")
					
					["pos"] = function(self, support)
						--returns an array with the positions of the element "e", of type, capture or equality
						local newtable, e = ke.table.new(), support
						local types = {"function", "table", "string", "color", "alpha", "shape", "clip", "number", "boolean", "point", "segment", "polygon"}
						if type(e) == "table" then
							for k, v in pairs(self) do
								newtable[#newtable + 1] = ke.table.compare(v, e) and k or nil
							end --si la tabla "e" está dentro de la tabla
						elseif type(e) == "string" then
							if ke.table.inside(types, e) then
								for k, v in pairs(self) do
									newtable[#newtable + 1] = type(v) == "table" and operation.pos(v, e) or (ke.table.type(v) == e and k or nil)
								end --tipo de elemento
							else
								for k, v in pairs(self) do
									newtable[#newtable + 1] = type(v) == "table" and operation.pos(v, e) or nil
									if type(v) == "string" then --captura en los elementos strings
										newtable[#newtable + 1] = v:match(e) and k or nil
									elseif v == e then
										newtable[#newtable + 1] = k
									end --strings iguales
								end --ke.table.get({1, 2, "box", {"b", 3, x = 0}}, "pos", "b")
							end
						else
							for k, v in pairs(self) do
								newtable[#newtable + 1] = type(v) == "table" and operation.pos(v, e) or (v == e and k or nil)
							end --elementos iguales
						end --ke.table.get({1, 2, "a", {"b", 3, x = 0}}, "pos", "number")
						return newtable
					end,
					
					["random"] = function(self)
						--returns a random element, never the same consecutive
						if #self <= 1 then
							return self[1]
						end
						local rand_e = self[ke.math.rand(#self)]
						while rand_e == RANDOM do
							rand_e = self[ke.math.rand(#self)]
						end
						RANDOM = rand_e
						return rand_e --ke.table.get(5, "random")
					end,
					
					["round"] = function(self, support)
						--returns the array with all the numbers rounded according to the third argument
						local newtable = ke.table.new(self)
						return ke.math.round(newtable, support)
					end,
					
					["string"] = function(self, support)
						--returns an array with the n-size parts of each string
						local n = type(support) == "function" and support() or support or 1
						local newtable = ke.table.new(self)
						for i, str in pairs(newtable) do
							if type(str) == "table" then
								newtable[i] = operation.string(str, n)
							elseif type(str) == "string" then
								local aux, chars, size = {}, {}, unicode.len(str)
								for c in unicode.chars(str) do
									table.insert(chars, c)
								end
								for j = 1, size, n do
									aux[#aux + 1] = ""
									for k = 1, n do
										aux[#aux] = aux[#aux] .. (chars[j + k - 1] or "")
									end
								end --ke.table.get({y = "line text", "pi", "demo", 453}, "string", 3)
								newtable[i] = n >= size and {str} or aux
							else
								newtable[i] = str
							end
						end
						return newtable
					end, --ke.table.get({"line text", "demo", "de"}, "string", 3)
					
					["suma"] = function(self, support)
						--sum of elements from 1 to support or #self
						local sum, newtable = 0, operation.toval(self)
						local support = (support and support > #self) and #self or support or #self
						for i = 1, support do
							sum = sum + newtable[i]
						end
						return sum
					end, --ke.table.get({1, 2, "3", 4, 5}, "suma", 3)
					
					["tonumber"] = function(self)
						--convert elements to numbers, if possible
						--local self = type(self) ~= "table" and {self} or self
						local index = {}
						for k, v in pairs(self) do
							v = type(v) == "function" and v() or v
							self[k] = type(v) == "string" and ke.string.array(v, "number") or v
							v = type(v) == "table" and operation.tonumber(v) or v
							k = type(k) == "number" and #index + 1 or k
							index[k] = v
						end
						local function tbl_ipairs(self)
							local index, keys = {}, {}
							for k, v in pairs(self) do
								v = type(v) == "table" and tbl_ipairs(v) or v
								if type(k) ~= "number" then
									keys[#keys + 1], index[k], self[k] = k, v
								end
							end
							keys = operation.order(keys)
							for i = 1, #keys do
								self[#self + 1] = index[keys[i]] 
							end
							return self
						end
						local function tbl_unpack(tbl, self)
							for k, v in pairs(self) do
								tbl = type(v) == "table" and tbl_unpack(tbl, v) or tbl
								tbl[#tbl + 1] = type(v) ~= "table" and v or nil
							end
							return tbl
						end
						local newtable = tbl_unpack(ke.table.new(), tbl_ipairs(self))
						return newtable
					end, --ke.table.get({{x = 1, y = 2}, "7 8 ", 3, 4, x = 10, y = 11}, "tonumber")
					
					["topoint"] = function(self)
						--get the points of an array or a shape
						local values = operation.tonumber(self)
						local points = ke.table.new()
						for i = 1, #values, 2 do
							points:insert(ke.shape.point.new(values[i], values[i + 1]))
						end
						return points
					end, --ke.table.get(ke.shape.rectangle, "topoint")
					
					["tosegment"] = function(self)
						--get the line segments of an array or a shape
						local values = operation.tonumber(self)
						local segments = ke.table.new()
						for i = 1, #values - 3, 2 do
							segments:insert(ke.shape.segment.new({values[i], values[i + 1], values[i + 2], values[i + 3]}))
						end
						return segments
					end, --ke.table.get(ke.shape.rectangle, "tosegment")
					
					["toval"] = function(self)
						--assigns the actual value that each element represents
						local newtable, table_val = ke.table.new(), ke.table.copy(self)
						for k, v in pairs(table_val) do
							newtable[k] = (type(v) == "string" and v ~= "l") and ke.string.toval(v) or v
							newtable[k] = type(v) == "table" and operation.toval(v) or newtable[k]
						end --ke.table.get({"2", 4, {"5", "&HFF&"}, x = "7"}, "toval")
						return newtable
					end,
					
					["unique"] = function(self, support)
						--remove repeating elements from an indexed array
						local newtable, _copy = ke.table.new(), ke.table.copy(self)
						if support then
							newtable[1] = self[1]
							for i = 2, #self do
								newtable[#newtable + 1] = self[i] ~= newtable[#newtable] and self[i] or nil
							end --remove only consecutive occurrences of each element
						else --ke.table.get({1, 2, 2, 2, 5, 2, 2, 7, 7, 8}, "unique", true)
							while #_copy > 0 do
								newtable[#newtable + 1] = _copy[1]
								_copy = operation.delete(_copy, _copy[1])
							end
						end
						return newtable
					end, --ke.table.get({1, 2, 2, 2, 5, 6, 7, 7, 8}, "unique")
				}
				local self_op = operation[mode] and operation[mode](self, support) or self
				return self_op
			end,
			
			gsub = function(self, capture, filter)
				--generates replacements in the string elements of an array
				local capture = type(capture) == "function" and capture() or capture or "KEfx"
				capture = type(capture) == "string" and {capture} or capture
				local filter = filter or ""
				local newtable, _copy = ke.table.new(), ke.table.copy(self)
				for k, v in pairs(_copy) do
					for i = 1, #capture do
						v = type(v) == "string" and v:gsub(capture[i], filter) or v
					end
					newtable[k] = type(v) == "table" and ke.table.gsub(v, capture, filter) or v
				end --ke.table.gsub({"line demo", x = "string word fx"}, "o", "O")
				return newtable
			end,
			
			match = function(self, capture)
				--generates an array with the matches it finds, of equality, of type or of capture
				local capture = type(capture) == "function" and capture() or capture or "KEfx"
				capture = type(capture) ~= "table" and {capture} or capture
				local newtable, _copy = ke.table.new(), ke.table.copy(self)
				local types = {"function", "table", "string", "color", "alpha", "shape", "clip", "number", "boolean", "point", "segment"}
				for i = 1, #capture do
					for k, v in pairs(_copy) do
						newtable[k] = ((ke.table.inside(types, capture[i]) and ke.table.type({v}) == capture[i])
						or (capture[i] == v) or (type(v) == "string" and type(capture[i]) == "string" and v:match(capture[i]))
						or ke.table.compare(v, capture[i])) and v or newtable[k]
						--si el elemento de la tabla es del mismo tipo que el indicado		--si la captura es el valor de un elemento en la tabla
						--si la tabla (capture[i]) es uno de los elementos de la tabla		--si el elemento es un string con la captura indicada
					end --ke.table.match({"a", "b", x = "c", [5] = 1, 2, {3}}, {"string", 1})
				end --ke.table.match({"a", "b", x = "c", [5] = 1, 2, 3}, "c")
				return newtable
			end,
			
			twin = function(self, ...)
				--create an array with the possible one-to-one matches, with the elements of the arrays entered
				local tables = ... and {...} or ke.table.copy(self)
				if ... then
					tables = #tables == 1 and ... or tables
					tables = ke.table.type(tables) ~= "table" and {tables} or tables
					table.insert(tables, 1, self)
				end
				local size_tbl = ke.table.new(#tables, function(i) return #tables[i] end)
				local min_size = ke.table.get(size_tbl, "min")
				local newtable = ke.table.new(min_size, {})
				for i = 1, min_size do
					for k = 1, #tables do
						newtable[i][k] = tables[k][i]
					end
				end
				return newtable
			end, --ke.table.twin({{1, 2, 3, 4}, {"A", "B", "C", "D"}, {7, 8, 9, 0, -1}})
			
		},
		
		string = {
			
			__name = "string",
			
			["__index"] = function(self, name)
				local newstring = ke.table.copy(string)
				table.insert(newstring, ke.string)
				return ke.string[name]
			end,
			
			["new"] = function(str)
				local str = type(str) == "function" and str() or str or ""
				if type(str) == "table" then
					return ke.table.recursive(str, ke.string.new)
				end
				local mt = getmetatable("").__index
				setmetatable(mt, ke.string)
				return str
			end,
			
			fxline = function(re, ...)
				local valors = {...}
				return re:format(table.unpack(ke.math.round(valors, ROUND_NUM)))
			end,
			
			toval = function(self, vars)
				local self = type(self) == "function" and self() or self or ""
				if type(self) == "table" then
					return ke.table.recursive(self, ke.string.toval, vars)
				end --recurse
				local xres, yres = ke.infofx.xres, ke.infofx.yres
				local ratio, frame_dur = ke.infofx.ratio, ke.infofx.frame_dur
				local env = {
					["ke"] 		= ke,			["fx"]			 = ke.infofx.fx,
					["xres"] 	= xres,			["yres"]		 = yres,
					["ratio"] 	= ratio,		["frame_dur"]	 = frame_dur,
					["math"]	= _G["math"],	["getmetatable"] = _G["getmetatable"],
					["string"]	= _G["string"],	["setmetatable"] = _G["setmetatable"],
					["table"]	= _G["table"],	["tonumber"]	 = _G["tonumber"],
					["type"]	= _G["type"],	["tostring"]	 = _G["tostring"],
					["pairs"]	= _G["pairs"],	["include"]		 = _G["include"],
					["ipairs"]	= _G["ipairs"],	["unicode"]		 = _G["unicode"],
				}
				if vars then --array
					for k, v in pairs(vars) do
						env[k] = v
					end --ke.string.toval({"0:00:02.018", "200"})
				end --ke.string.toval("{3, 7, {x = 0, y = {5, 8}}}")
				local self = self:gsub("%d+:%d+:%d+%.%d+", function(HMS) return ke.time.HMS_to_ms(HMS) end)
				local chunk, err = load(("return %s"):format(self), "= ke.string.toval", "t", env)
				--self = self:gsub("\"(&H%x+&)\"", "%1")
				if not chunk then
					return self
				end --ke.string.toval("tonumber('3.5') + math.random(8)")
				local success, result = pcall(chunk)
				return (success and result) and result or self
			end, --ke.string.toval("5 + 7")
			
			loadstr = function(str, vars)
				local env = {ke = ke, _G = _G}
				if vars then --array
					for k, v in pairs(vars) do
						env[k] = v
					end
				end
				--
				local result = {}
				for statement in str:gmatch("([^;]+)") do
					table.insert(result, statement:match("^%s*(.-)%s*$"))
				end
				local sent = ""--{}
				if #result > 0 then
					for i, stmt in ipairs(result) do
						local v = stmt:match("(%S+)[%s]*=[%s]*.+")
						sent = sent .. v .. " = " .. v .. "; "
					end
					sent = "{" .. sent .. "}"
				end
				--
				local option3 = ("return function() %s return %s end"):format(str, sent)
				local chunk, err = load(option3, "= string_toval_chunk", "t", env)
				if not chunk then
					return str
				end
				local success, result = pcall(chunk)
				return (success and result) and result or str
			end,
			
			i = function(self)
				--converts the string "i" to a consecutive numeric value
				local self = type(self) == "function" and self() or self or ""
				if type(self) == "table" then
					return ke.table.recursive(self, ke.string.i)
				end --recurse
				local count_i = 0
				self = self:gsub("\\%w+%b()",
					function(capture)
						local new_cap = capture
						local capture = capture:gsub("([%+ %-%*%/%^%(%[%{%d%%]^*)i([%+ %-%*%/%^%)%]%}%%%\\]^*)",
							function(capture_ini, capture_fin)
								local cap_ini, cap_i, cap_fin = capture_ini, count_i, capture_fin
								return capture_ini:match("%d") and cap_ini .. " * " .. cap_i .. cap_fin or cap_ini .. cap_i .. cap_fin
							end
						)
						count_i = new_cap ~= capture and count_i + 1 or count_i
						return capture
					end
				)
				return ke.string.new(self)
			end, --ke.string.i("\\fr(-5i)\\frx(10 - i)")
			
			count = function(self, captures)
				-- number of times a snapshot or snapshot family appears in a string
				local self = type(self) == "function" and self() or self or ""
				if type(self) == "table" then
					return ke.table.recursive(self, ke.string.count, captures)
				end --recurse
				local captures = type(captures) == "function" and captures() or captures or "KEfx"
				captures = type(captures) ~= "table" and {captures} or captures
				local n = 0 --ke.string.count({"&HF58628&", "&HFF00FF&"}, "%x")
				for _, cap in ipairs(captures) do
					cap = cap == "number" and "%-?%d[%.%d]*"
					or (cap == "point" and "%-?%d[%.%d]*%s+%-?%d[%.%d]*")
					or (cap == "color" and "[%&%#Hh]^*%x%x%x%x%x%x[%&]*")
					or (cap == "alpha" and "%&[Hh]^*%x%x%&")
					or (cap == "shape" and "m%s+%-?%d[%.%-%d mlb]*") or cap
					for c in self:gmatch(cap) do
						n = n + 1
					end
				end
				return n
			end, --ke.string.count("&HF58628&", "%x")
			
			array = function(self, captures)
				--returns an array with specific values of a string
				local self = type(self) == "function" and self() or self or ""
				if type(self) == "table" then
					return ke.table.recursive(self, ke.string.array, captures)
				end --recurse
				local captures = type(captures) == "function" and captures() or captures or "KEfx"
				captures = type(captures) ~= "table" and {captures} or captures
				local result = ke.table.new()
				for _, cap in ipairs(captures) do
					cap = cap == "number" and "%-?%d[%.%d]*"
					or (cap == "color" and "[%&%#Hh]^*%x%x%x%x%x%x[%&]*")
					or (cap == "alpha" and "%&[Hh]^*%x%x%&")
					or (cap == "shape" and "m%s+%-?%d[%.%-%d mlb]*") or cap
					if cap == "chars" then
						result:insert(ke.table.new(unicode.chars(self), 1), nil, true)
					else --syl.text:array("chars")
						for A, B, C, D, E, F, G in self:gmatch(cap) do
							result:insert(ke.string.new(B and {A, B, C, D, E, F, G} or A))
						end --ke.string.array(ke.shape.circle, "(%-?%d[%.%d]*) (%-?%d[%.%d]*)")
					end
				end --ke.string.array("\\an5\\pos(600,320)\\blur4\\t(\\bord0)", "\\[%d]*%a+%b()", "\\[%d]*%a+%-?[%d&#]^*[%.%dH&%x]*")
				return result
			end,
			
			capture = function(self, captures, options)
				local list, caps
				local captures = type(captures) == "function" and captures() or captures or "KEfx"
				captures = type(captures) ~= "table" and {captures} or captures
				if captures.protect then
					list = type(captures.protect) ~= "table" and {captures.protect} or captures.protect
					self, caps = ke.string.protect(self, list)
				end
				options = options or {}
				local overlap = options.overlap ~= false	-- true por defecto
				local advance = options.advance or 1		-- mínimo avance entre capturas
				local pos, size = 1, unicode.len(self)
				local result, res = ke.table.new(), ke.table.new()
				for _, pattern in ipairs(captures) do
					while pos <= size do
						local ini, fin = self:find(pattern, pos)
						if ini then
							local cap = self:sub(ini, fin)
							if #result == 0 or not result[#result]:match(cap) then
								table.insert(result, ("<<%s>>"):format(ini) .. cap)
							end
							pos = overlap and ini + advance or fin + 1
						else
							break
						end --str = "\\frz-32\\blur-2\\1a&HFF&\\bordR(2,6)\\org(80,90)\\iclip(m 0 0 l 0 100 l 100 100 )\\t(0,80,\\1c&HFF00FF&)\\p1"
					end --ke.string.capture(str, {"\\[%d]*%a+%-?[%d&]^*[%.%dH%x&]*", "\\[%d]*[^t%W]%a+%b()", protect = "\\t%b()", include = true})
					pos = 1
				end
				--ke.string.capture(str, {"\\[%d]*%a+%-?[%d&]^*[%.%dH%x&]*", protect = "\\t%b()"})
				--str = "\\1a&HA4&\\frz-32\\blur-2\\1a&HFF&\\t(0,80,\\1c&HFF00FF&)"
				if list and captures.include then
					local k = ke.math.count()
					self = self:gsub("<x>", function(cap) return caps[k()] end)
					pos = 1
					for _, pattern in ipairs(list) do
						while pos <= size do
							local ini, fin = self:find(pattern, pos)
							if ini then
								local cap = self:sub(ini, fin)
								if #result == 0 or not result[#result]:match(cap) then
									table.insert(result, ("<<%s>>"):format(ini) .. cap)
								end
								pos = overlap and ini + advance or fin + 1
							else
								break
							end
						end
						pos = 1
					end
				end
				for k, v in ipairs(result) do
					local idx = tonumber(v:match("<<(%d+)>>"))
					res[idx] = v:gsub("<<%d+>>", "")
				end
				return res("idx")
				--str = "m 0 0 l 0 100 l 100 100 l 100 0 l 0 0 "
				--ke.string.capture(str, "%d+ %d+ l %d+ %d+ ")
			end,
			
			protect = function(self, captures)
				--"protect" part of the string to apply replacement functions
				local self = type(self) == "function" and self() or self or ""
				if type(self) == "table" then
					return ke.table.recursive(self, ke.string.protect, captures)
				end --recurse
				local captures = type(captures) == "function" and captures() or captures or "KEfx"
				captures = type(captures) == "string" and {captures} or captures
				local list = ke.table.new()
				local operation = function(str)
					local str = str
					:gsub("%%","%%%%"):gsub("%*", "%%*"):gsub("%+", "%%+"):gsub("%-", "%%-")
					:gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%[", "%%["):gsub("%]", "%%]")
					return str
				end
				for _, cap in ipairs(captures) do
					self = self:gsub(cap,
						function(c)
							local key = self:find(operation(c))
							local Len = unicode.len(operation(c))
							list[key] = c
							return "€" .. string.rep("Æ", Len - 1)
						end
					)
				end
				self = self:gsub("€[Æ]*", "<x>")
				--	self, caps = ke.string.protect(self, captures)	--> protege las capturas en el string y genera la tabla de dichas capturas
				--	self = self:gsub(-todo-)						--> aplica los remplazos en el string protegido
				--	local k = ke.math.count()						--> contador para regresar las capturas salvadas al string protegido
				--	self = self:gsub("<x>", function(cap) return caps[k()] end)
				return ke.string.new(self), list("idx") --{ke.string.protect("foo(8)bar(0)demo6 foo(demo)", "%w+%b()")}
			end,
			
			change = function(self, captures, NoChange, Nocapture, filter)
				--remove or change a specific capture of a string
				local self = type(self) == "function" and self() or self or ""
				local No_cap = {}
				if type(self) == "table" then
					return ke.table.recursive(self, ke.string.change, captures, NoChange, Nocapture, filter)
				end --recurse
				local filter = filter or ""
				local captures = type(captures) == "function" and captures() or captures or "KEfx"
				captures = type(captures) ~= "table" and {captures} or captures
				local NoChange = type(NoChange) == "number" and {NoChange} or NoChange or {0}
				if Nocapture then --capturas protegidas
					self, No_cap = ke.string.protect(self, Nocapture)
				end
				local NoChange2 = ke.table.copy(NoChange)
				for _, cap in ipairs(captures) do
					local Count = ke.math.count()
					local _, Ni = self:gsub(cap, "")
					for k, v in ipairs(NoChange) do
						NoChange[k] = v < 0 and Ni + v + 1 or v
					end
					self = self:gsub(cap,
						function(c)
							if ke.table.inside(NoChange, Count()) then
								return c
							end
							return type(filter) == "function" and filter(c) or filter
						end
					)
					NoChange = ke.table.copy(NoChange2)
				end
				if Nocapture then --devuelve las capturas protegidas
					local k = ke.math.count()
					self = self:gsub("<x>", function(cap) return No_cap[k()] end)
				end --ke.string.change("foo(1)bar(2)foo(3)bar(4)\\t(\\demo1234)demo", "%w+%b()", nil, {"foo%b()", "bar%b()"})
				return ke.string.new(self)
			end, --ke.string.change("\\1c&H0000FF&\\t(\\1c&HFF00AA&)\\1c&H00FFFF&ru", "\\1c&H%x+&", 1, "\\t%b()")
			
			parts = function(self, parts)
				--returns an array with the n-size parts of a string
				local self, parts = self or "", parts or 3
				if type(self) == "table" then
					return ke.table.recursive(self, ke.string.parts, parts)
				end --recurse
				parts = type(parts) == "number" and math.ceil(math.abs(parts)) or parts
				if type(parts) == "table" then
					parts[1] = parts[1] <= 0 and 1 or parts[1]
					parts[2] = parts[2] <= 0 and 2 or parts[2]
				end
				parts = parts == 0 and 2 or parts
				local chars_tbl, parts_tbl, Part_i, i = ke.string.array(self, "chars"), {}, 0, 1
				while #chars_tbl > 0 do
					Part_i = type(parts) == "table" and ke.math.rand(parts[1], parts[2]) or parts
					parts_tbl[i] = ""
					for k = 1, Part_i do
						parts_tbl[i] = parts_tbl[i] .. (chars_tbl[1] or "")
						table.remove(chars_tbl, 1)
					end
					parts_tbl[i] = ke.string.new(parts_tbl[i])
					i = i + 1
				end --ke.string.parts("por ejemplo", 2) --> {"po", "r ", "ej", "em", "pl", "o"}
				return parts_tbl
			end,
			
			width = function(self, style)
				local self = self:gsub("%b{}", "")
				return aegisub.text_extents(style or ke.infofx.l.style, self)
			end, --ke.string.width(" ")
			
		},
		
		shape = {
			__name = "shape",
			
			-- internal predesigned shapes --
			circle		= "m 50 0 b 22 0 0 22 0 50 b 0 78 22 100 50 100 b 78 100 100 78 100 50 b 100 22 78 0 50 0 ",
			triangle	= "m 50 0 l 0 86 l 100 86 l 50 0 ",
			rectangle	= "m 0 0 l 0 100 l 100 100 l 100 0 l 0 0 ",
			pixel		= "m 0 0 l 0 1 1 1 1 0 ",
			heart		= "m 50 25 b 32 0 0 16 0 40 b 0 68 24 71 50 106 b 75 71 100 68 100 40 b 100 16 68 0 50 25 ",
			shine1t		= "m 0 0 l 47 50 l 0 100 l 50 53 l 100 100 l 53 50 l 100 0 l 50 47 m 42 50 b 42 61 58 61 58 50 b 58 39 42 39 42 50 ",
			shine2t		= "m 0 0 l 45 50 l 0 100 l 50 55 l 100 100 l 55 50 l 100 0 l 50 45 m 40 50 b 40 64 60 64 60 50 b 60 36 40 36 40 50 ",
			trebol		= "m 1 99 l 4 106 b 21 99 44 83 53 56 b 51 73 40 88 56 98 b 72 106 80 90 77 82 b 85 86 100 82 100 69 b 100 58 87 52 64 54 b 52 55 51 50 68 48 b 85 46 94 40 95 29 b 96 18 80 10 70 19 b 70 0 40 0 40 21 b 40 33 47 37 50 43 b 54 50 52 54 47 47 b 39 38 31 26 19 27 b 0 29 0 49 13 53 b 0 58 3 80 19 79 b 39 78 40 62 51 55 b 42 79 23 92 1 99 ",
			feather		= "m 0 0 b 0 20 10 28 27 34 b 10 33 47 49 54 55 b 62 62 72 77 78 75 l 80 78 l 90 79 b 94 86 96 94 97 100 l 100 100 b 99 93 96 84 93 78 b 100 56 88 41 73 30 l 73 39 l 69 28 b 62 24 55 23 49 19 l 48 24 l 45 19 b 31 10 13 12 0 0 m 91 74 l 88 75 b 79 49 57 40 46 35 b 22 25 8 15 2 5 b 11 17 22 23 48 34 b 64 41 82 51 91 74 ",
			bubble		= "m 50 100 b 78 100 100 78 100 50 b 100 22 78 0 50 0 b 22 0 0 22 0 50 b 0 78 22 100 50 100 m 50 1 b 79 1 99 21 99 50 b 99 76 80 93 68 96 b 62 98 66 94 50 94 b 34 94 38 98 32 96 b 20 93 1 78 1 50 b 1 22 22 1 50 1 m 88 22 b 79 11 75 14 85 24 b 92 38 94 33 88 22 m 12 15 b 12 19 18 19 18 15 b 18 11 12 11 12 15 m 14 16 l 15 30 l 16 16 l 30 15 l 16 14 l 15 0 l 14 14 l 0 15 m 50 94 b 63 94 61 100 52 100 b 42 100 38 94 50 94 ",
			star		= "m 38 36 l 0 36 l 31 59 l 20 95 l 50 72 l 81 94 l 69 59 l 100 36 l 62 36 l 50 0 l 38 36 ",
			sakura		= "m 50 40 l 35 0 b 10 10 0 32 0 61 b 0 88 15 117 50 130 b 85 117 100 88 100 61 b 100 32 90 10 65 0 l 50 40 ",
			test		= "m 0 0 l 0 100 l 100 100 l 100 0 l 0 0 m 20 20 l 80 20 l 80 80 l 20 80 l 20 20 m 40 40 l 40 60 l 60 60 l 60 40 l 40 40 ",
			
			-- subclass and sublibraries --
			["point"] = {	--subclass
				
				__name = "point",
				
				["__index"] = function(self, key)
					return ke.shape.point[key]
				end,
				
				["new"] = function(x, y, t)
					local px, py, pt = x, y, t
					if type(x) == "string" and x:match("([blm]^*)%s+(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)") then
						pt, px, py = x:match("([blm]^*)%s+(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)")
					end
					if type(x) == "table" then
						px = x.x or x[1] or 0
						py = x.y or x[2] or 0
						pt = x.t or x[3] or nil
					end
					local p = {
						x = ke.math.round(px or 0, ROUND_NUM),
						y = ke.math.round(py or 0, ROUND_NUM),
						t = pt
					}
					setmetatable(p, ke.shape.point)
					return p
				end, --ke.shape.point.new("m 12 -8.3")
				
				["__copy"] = function(self)
					return ke.shape.point.new(self.x, self.y, self.t)
				end,
				
				["__type"] = function(self)
					return "point"
				end,
				
				["__unm"] = function(self)
					return ke.shape.point.new(-self.x, -self.y, self.t)
				end,
				
				["__add"] = function(self, other)
					local addx, addy = table.unpack(ke.math.getpair(other, 0, 0))
					return ke.shape.point.new(self.x + addx, self.y + addy, self.t)
				end,
				
				["__sub"] = function(self, other)
					local subx, suby = table.unpack(ke.math.getpair(other, 0, 0))
					return ke.shape.point.new(self.x - subx, self.y - suby, self.t)
				end,
				
				["__div"] = function(self, other)
					local other = type(other) == "number" and {other, other} or other
					local divx, divy = table.unpack(ke.math.getpair(other, 1, 1))
					return ke.shape.point.new(self.x / divx, self.y / divy, self.t)
				end,
				
				["__mul"] = function(self, other)
					if ke.table.type(other) == "matrix" then
						return ke.math.matrix.__mul(other, self)
					end
					return type(self) == "number" and ke.shape.point.new(self * other.x, self * other.y, other.t)
						or (type(other) == "number" and ke.shape.point.new(other * self.x, other * self.y, self.t)
						or self.x * other.x + self.y * other.y)
				end,
				
				["__lt"] = function(self, other)
					return self.x < other.x or (self.x == other.x and self.y < other.y)
				end,
				
				["__le"] = function(self, other)
					return self.x <= other.x and self.y <= other.y
				end,
				
				["__str"] = function(self)
					return ("%s %s "):format(self.x, self.y)
				end,
				
				["__eq"] = function(self, other)
					return math.abs(self.x - other.x) <= EPSILON and math.abs(self.y - other.y) <= EPSILON
				end,
				
				["__tostring"] = function(self)
					return ("(%s, %s)"):format(self.x, self.y)
				end,
				
				["len"] = function(self)
					return math.sqrt(self * self)
				end,
				
				["distance"] = function(self, other, ...)
					return ke.math.distance(self, other, ...)
				end,
				
				["unpack"] = function(self, ...)
					local others = {...}
					local coors = ke.table.new()
					coors:insert({self.x, self.y}, nil, true)
					for _, p in ipairs(others) do
						coors:insert({p.x, p.y}, nil, true)
					end
					return table.unpack(coors)
				end,
				
				["middle"] = function(self, other)
					return (self + other) / 2
				end,
				
				["ortho"] = function(self)
					return ke.shape.point.new(-self.y, self.x)
				end,
				
				["cross"] = function(self, other)
					return self.x * other.y - self.y * other.x
				end,
				
				["clockwise"] = function(self, other, third)
					return (other - self):cross(third - self) >= 0
				end,
				
				["collinear"] = function(self, other, third)
					return math.abs((other - self):cross(third - self)) < EPSILON
				end,
				
				["angle"] = function(self, other, third)
					if not other then
						return ke.math.angle(self)
					end
					local a1, a2 = ke.math.angle(self, other), ke.math.angle(other, third)
					local ang = third and 180 - a1 + a2 or a1
					return ang < 0 and ang + 360 or (ang > 360 and ang - 360 or ang)
				end,
				
				["bisector"] = function(self, other, third)
					local a1, a2 = ke.math.angle(self, other), ke.math.angle(other, third)
					local ang = 180 - a1 + a2
					ang = ang < 0 and ang + 360 or (ang > 360 and ang - 360 or ang)
					ang = a1 + 180 + ang / 2
					return ang < 0 and ang + 360 or (ang > 360 and ang - 360 or ang)
				end, --ke.shape.point.bisector({x = 0, y = 0}, {x = 0, y = 10}, {x = 10, y = 10})
				
				["in3angle"] = function(self, p1, p2, p3)
					local v1, v2 = p2 - p1, p3 - p1
					local qp, dv = self - p1, v1:cross(v2)
					local l, m = qp:cross(v2) / dv, v1:cross(qp) / dv
					if l <= 0 or m <= 0 then
						return false
					end
					return l + m < 1
				end,
				
				["intersect"] = function(self, p1, p2, p3)
					local p0 = self
					local det = (p0.x - p1.x) * (p2.y - p3.y) - (p0.y - p1.y) * (p2.x - p3.x)
					if det == 0 then return nil end
					local t = ((p0.x - p2.x) * (p2.y - p3.y) - (p0.y - p2.y) * (p2.x - p3.x)) / det
					local u = -((p0.x - p1.x) * (p0.y - p2.y) - (p0.y - p1.y) * (p0.x - p2.x)) / det
					if t >= -EPSILON and t <= 1 + EPSILON and u >= -EPSILON and u <= 1 + EPSILON then
						return ke.shape.point.new({p0.x + t * (p1.x - p0.x), p0.y + t * (p1.y - p0.y)})
					end
					return nil
				end,
				
				["perpendicular"] = function(self, other, t, distance)
					local other = self == other and self:polar(self:angle() - 90, 32) or other
					local t = t or 0.5
					local d = distance or 0
					local ax, ay, bx, by = self.x, self.y, other.x, other.y
					local vx, vy = bx - ax, by - ay
					local len = self:distance(other)
					d = type(d) == "table" and d[1] * len or d
					local px, py = ax + t * vx, ay + t * vy
					local nx, ny = -vy / len, vx / len
					return ke.shape.point.new({x = px + d * nx, y = py + d * ny, t = self.t})
				end, --ke.shape.point.perpendicular(ke.shape.point.new(4, 3), ke.shape.point.new(0, 0), 0.4, 5)
				
				["polar"] = function(self, angle, radius, ptype)
					--polar displacement of a point
					local x, y = ke.math.polar(angle, radius)
					return ke.shape.point.new(self.x + x, self.y + y, ptype or self.t)
				end,
				
				["topolar"] = function(self, other)
					local other = other or ke.shape.point.new(0, 0)
					return self:angle(other), self:distance(other)
				end,
				
				["ratio"] = function(self, rxy)
					local rx, ry = table.unpack(ke.math.getpair(rxy, 1, 1))
					return ke.shape.point.new(self.x * rx, self.y * ry, self.t)
				end,
				
				["rotate"] = function(self, angle, o, axis)
					local self = type(self) == "function" and self() or self
					local o = type(o) == "function" and o() or o or ke.shape.point.new(0, 0)
					local a = type(angle) == "function" and angle() or angle or 0
					a = type(a) == "table" and 360 - o:angle(self) + a[1] or a
					a = -math.rad(a)
					local axis = axis or "z"
					local Px, Py, Pz = (self.x or 0) - o.x, (self.y or 0) - o.y, (self.z or 0) - (o.z or 0)
					local newrot = axis == "x" and ke.shape.point.new(Px + o.x, math.cos(a) * Py - math.sin(a) * Pz + o.y)
						or (axis == "y" and ke.shape.point.new(math.cos(a) * Px + math.sin(a) * Pz + o.x, Py + o.y))
						or ke.shape.point.new(math.cos(a) * Px - math.sin(a) * Py + o.x, math.sin(a) * Px + math.cos(a) * Py + o.y)
					newrot.t = self.t
					return newrot
				end, --ke.shape.point.new(10, 0):rotate(45)
				
				["distline"] = function(self, line)
					--distance and angle from a point to a line
					local angle = line:angle() + 90
					local p2 = self:polar(angle, 1)
					local x, y = ke.math.intersect(self, p2, line)
					return ke.math.distance(self, x, y), ke.math.angle(self, x, y), ke.shape.point.new(x, y)
				end, --ke.shape.point.distline(ke.shape.point.new(50, 50), ke.shape.segment.new({0, 50, 50, 0}))
				
				["rand"] = function(self, other, configs)
					--configs = {dx = val or table, dy = val, step = val or 1}
					local dx = type(configs) == "table" and configs.dx or configs or 86
					local dy = type(configs) == "table" and configs.dy or dx
					local st = type(configs) == "table" and configs.step or 1
					local t = ke.math.rand(0, 2 * math.pi, 0.01)
					if other then
						local dista, angle, center = self:distance(other), self:angle(other), self:middle(other)
						local a = type(configs) == "table" and configs.dx or 0.25 * dista
						local b = type(configs) == "table" and configs.dy or 0.50 * dista
						a = a + 0.5 * dista
						return ke.shape.point.new(center.x + a * math.cos(t), center.y + b * math.sin(t)):rotate(angle, center)
					end --p1:rand(p2, {dx = 0, dy = 0})
					if type(dx) == "table" and ke.table.type(dx) == "number" then
						local r = ke.math.rand(dx[1], dx[2])
						return self + ke.shape.point.new(r * math.cos(t), r * math.sin(t))
					end --p1:rand(nil, {dx = {20, 36}})
					return self + ke.shape.point.new(ke.math.rand(0, dx, st, true), ke.math.rand(0, dy, st, true))
				end, --ke.shape.point.new(2,43):rand(nil, 5)
				
				["ipol"] = function(self, others, parameter)
					local others = type(others) == "function" and others() or others or self
					local points = ke.table.new({self})
					if type(others) == "table" and others.__name == "point" then
						points:insert(others)
					elseif ke.table.type(others) == "point" then
						points:insert(others, nil, true)
					end
					if type(parameter) == "table" and parameter.others then
						points:insert(parameter.others, 2, true)
					end
					if type(parameter) == "table" and parameter.filter then
						points:insert(parameter.filter(self, other), 2, true)
					end
					local total = points.n
					local t = type(parameter) == "table" and parameter.t or parameter or nil
					local n = type(parameter) == "table" and parameter.n or nil
					local a = type(parameter) == "table" and parameter.accel or 1
					local s = type(parameter) == "table" and parameter.shape or nil
					local bernstein = function(i, n, t)
						return (ke.math.factk(n) / (ke.math.factk(i) * ke.math.factk(n - i))) * (t ^ i) * ((1 - t) ^ (n - i))
					end
					local special = {
						["curve+"]  = {self:perpendicular(points[total], 0.33, {0.35}), self:perpendicular(points[total], 0.67, {0.35})},
						["curve-"]  = {self:perpendicular(points[total], 0.33, {-0.35}), self:perpendicular(points[total], 0.67, {-0.35})},
						["curve+-"] = {self:perpendicular(points[total], 0.33, {0.35}), self:perpendicular(points[total], 0.67, {-0.35})},
						["curve-+"] = {self:perpendicular(points[total], 0.33, {-0.35}), self:perpendicular(points[total], 0.67, {0.35})},
					}
					if type(parameter) == "table" and type(parameter.curve) == "string" and special[parameter.curve] then
						points:insert(special[parameter.curve], 2, true)
					end
					local get_t = function(t, shp, accel)
						local accel = accel or 1
						local t = type(accel) == "function" and accel(t) or t ^ accel
						if shp and shp:match("m%s+%-?%d[%.%-%d mlb]*") then
							--interpolation by "y" value from shape
							local shape = ke.recall.shape or ke.recall.remember("shape", ke.shape.new(shp))
							local height, p = shape.height, shape:getpoint(t)
							t = height == 0 and 0 or math.abs(p.y) / height
						end
						return t
					end
					local bn = points.n
					if not n then
						t = get_t(t, s, a)
						local x, y = 0, 0
						for i, p in ipairs(points) do
							x = x + p.x * bernstein(i - 1, bn - 1, t)
							y = y + p.y * bernstein(i - 1, bn - 1, t)
						end
						return ke.shape.point.new(x, y, self.t)
					end
					if n < 2 then
						return self
					end
					local result = ke.table.new()
					for k = 1, n do
						local u = get_t((k - 1) / (n - 1), s, a)
						local x, y = 0, 0
						for i, p in ipairs(points) do
							x = x + p.x * bernstein(i - 1, bn - 1, u)
							y = y + p.y * bernstein(i - 1, bn - 1, u)
						end
						result:insert(ke.shape.point.new(x, y, self.t))
					end
					return result
				end, --p1:ipol(p2, 0.5)
				
				["reflect"] = function (self, p1, p2)
					local new = self:__copy()
					if not p2 or p1 == p2 then
						new = p1 * 2 - self
						return new
					end
					local v, w = p2 - p1, new - p1
					local norma2 = v.x ^ 2 + v.y ^ 2
					local t = (w.x * v.x + w.y * v.y) / norma2
					local aux = (v * t + p1) * 2 - new
					new.x, new.y = aux.x, aux.y
					return new
				end,
				
				-- points group functions --
				["random"] = function(n, xrange, yrange)
					--generate random points between a specified values range
					local cn = type(n) == "function" and n() or n or 10
					local rx = type(xrange) == "function" and xrange() or xrange or 256
					local ry = type(yrange) == "function" and yrange() or yrange or 256
					return ke.table.new(cn,
						function(i)
							local prx = type(rx) == "table" and ke.math.rand(rx[1], rx[2], rx[3] or 1, rx[4]) or rx
							local pry = type(ry) == "table" and ke.math.rand(ry[1], ry[2], ry[3] or 1, ry[4]) or ry
							return ke.shape.point.new(
								type(rx) == "table" and prx or ke.math.rand(0, rx, 1, true),
								type(ry) == "table" and pry or ke.math.rand(0, ry, 1, true)
							)
						end
					)
				end, --ke.shape.point.random(10, 50, 50)
				
				["group"] = function(points, filter, ...)
					local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
					local xsum, ysum, cx, cy, lengths, total = 0, 0, {}, {}, {}, 0
					for i, p in ipairs(points) do
						minx, maxx = math.min(minx, p.x), math.max(maxx, p.x)
						miny, maxy = math.min(miny, p.y), math.max(maxy, p.y)
						table.insert(cx, p.x)
						table.insert(cy, p.y)
						xsum = xsum + p.x
						ysum = ysum + p.y
						if i > 1 then
							lengths[i - 1] = p:distance(points[i - 1])
							total = total + lengths[i - 1]
						end
					end
					local get = {
						rank = {x = maxx - minx, y = maxy - miny}, --width and height
						bounding = {minx, miny, maxx, maxy},
						n = #points,
						centroid = ke.shape.point.new(xsum / #points, ysum / #points),
						convex = ke.shape.point.toconvex(points),
						coors = {x = cx, y = cy},
						lengths = lengths
					}
					get.lengths.total = total
					if type(filter) == "string" then
						return get[filter] or points
					end
					for i, p in ipairs(points) do
						points[i] = filter(p, get, ...)
					end
					return points
				end, --ke.shape.point.group(puntos, function(p, get, add) p.x = p.x + add[1] p.y = p.y + add[2] return p end, {5000, 1000})
				
				["sort"] = function(points, mode)
					local centroid = ke.shape.point.group(points, "centroid")
					local n = #points
					local idxpoints = {}
					for i = 1, n do
						idxpoints[i] = {p = points[i], i = i}
					end
					local index = 1
					local function getindex(vertex, sortfunc)
						local best_item = vertex[1]
						local idx = 1
						for i = 2, #vertex do
							local current_item = vertex[i]
							if sortfunc(current_item, best_item) then
								best_item = current_item
								idx = i
							end
						end
						return idx
					end
					if type(mode) == "string" then
						local sorts = {
							["minx"] = function(a, b) return a.p.x < b.p.x end,
							["maxx"] = function(a, b) return a.p.x > b.p.x end,
							["miny"] = function(a, b) return a.p.y < b.p.y end,
							["maxy"] = function(a, b) return a.p.y > b.p.y end,
							["lefttop"] = function(a, b) --assdraw3 coors
								if a.p.y < b.p.y then return true end
								if a.p.y == b.p.y and a.p.x < b.p.x then return true end
								return false
							end,
							["righttop"] = function(a, b)
								if a.p.y < b.p.y then return true end
								if a.p.y == b.p.y and a.p.x > b.p.x then return true end
								return false
							end,
							["leftbottom"] = function(a, b)
								if a.p.y > b.p.y then return true end
								if a.p.y == b.p.y and a.p.x < b.p.x then return true end
								return false
							end,
							["rightbottom"] = function(a, b)
								if a.p.y > b.p.y then return true end
								if a.p.y == b.p.y and a.p.x > b.p.x then return true end
								return false
							end,
							["other"] = function(a, b) return true end
						}
						local sortfunc = sorts[mode] or sorts.other
						index = idxpoints[getindex(idxpoints, sortfunc)].i
					elseif type(mode) == "number" then --angle [0°, 360°)
						table.sort(idxpoints, function(a, b) return centroid:angle(a.p) < centroid:angle(b.p) end)
						local angle = mode
						local low, high, best = 1, n, -1
						local min_diff = math.huge
						while low <= high do
							local mid = math.floor((low + high) / 2)
							local current_item = idxpoints[mid]
							local current_angle = centroid:angle(current_item.p)
							local diff = math.abs(current_angle - angle)
							diff = math.min(diff, 360 - diff)
							if diff < min_diff then
								min_diff = diff
								best = mid
							end
							if current_angle < angle then
								low = mid + 1
							else
								high = mid - 1
							end
						end
						if best ~= -1 then
							local best_item = idxpoints[best]
							local best_angle = centroid:angle(best_item.p)
							local check_index = best
							while check_index > 1 do
								local prev_item = idxpoints[check_index - 1]
								local prev_angle = centroid:angle(prev_item.p)
								local prev_diff = math.abs(prev_angle - angle)
								prev_diff = math.min(prev_diff, 360 - prev_diff)
								if prev_diff < EPSILON then
									best = check_index - 1
								else
									break
								end
								check_index = check_index - 1
							end
						end
						index = best ~= -1 and idxpoints[best].i or 1
					elseif type(mode) == "function" then
						--[[ example:
						--más cerca al origen
						local compare_to_origin = function(item_a, item_b)
							local dist_a = math.sqrt(item_a.p.x^2 + item_a.p.y^2)
							local dist_b = math.sqrt(item_b.p.x^2 + item_b.p.y^2)
							return dist_a < dist_b
						end
						--]]
						index = idxpoints[getindex(idxpoints, mode)].i
					end
					local result = {}
					for i = 1, n do
						local current_original_index = (index + i - 2) % n + 1
						result[i] = points[current_original_index]
					end
					return result
				end,
				
				["toconvex"] = function(points)
					if #points < 3 then
						return points
					end
					local function cross3(o, a, b)
						return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
					end
					local pts = ke.table.copy(points)
					table.sort(pts, function(a, b) return math.abs(a.x - b.x) < EPSILON and a.y < b.y or a.x < b.x end)
					local uniques = {pts[1]}
					for i = 2, #pts do
						local last = uniques[#uniques]
						if pts[i] ~= last then
							table.insert(uniques, pts[i])
						end
					end
					pts = uniques
					if #pts < 3 then
						return pts
					end
					local inf, sup, envelope = {}, {}, {}
					for i = 1, #pts do
						while #inf >= 2 and cross3(inf[#inf - 1], inf[#inf], pts[i]) <= 0 do
							table.remove(inf)
						end
						table.insert(inf, pts[i])
					end
					for i = #pts, 1, -1 do
						while #sup >= 2 and cross3(sup[#sup - 1], sup[#sup], pts[i]) <= 0 do
							table.remove(sup)
						end
						table.insert(sup, pts[i])
					end
					table.remove(inf)
					table.remove(sup)
					for i = 1, #inf do
						table.insert(envelope, inf[i])
					end
					for i = 1, #sup do
						table.insert(envelope, sup[i])
					end
					return envelope
				end, --ke.shape.point.toconvex(ke.shape.point.random(25, 50, 50))
				
				["toshape"] = function(points)
					local shp = ("m %s %s l "):format(points[1].x, points[1].y)
					for i = 2, #points do
						shp = shp .. ("%s %s "):format(points[i].x, points[i].y)
					end
					return shp
				end, --ke.shape.point.toshape(ke.shape.point.toconvex(ke.shape.point.random(25, 50, 50)))
				
				["triangulate"] = function(points)
					local delaunay
					delaunay = {
						__index = function(self, key)
							return delaunay[key]
						end,
						
						new = function(points)
							return setmetatable({points = points or {}, triangles = {}}, delaunay)
						end,
						
						triangle = {
							__index = function(self, key)
								return delaunay.triangle[key]
							end,
							
							new = function(p1, p2, p3)
								local tri = setmetatable({p1 = p1, p2 = p2, p3 = p3}, delaunay.triangle)
								local ax, ay = tri.p1.x, tri.p1.y
								local bx, by = tri.p2.x, tri.p2.y
								local cx, cy = tri.p3.x, tri.p3.y
								local d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
								if math.abs(d) < EPSILON then
									return nil
								end
								local ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
								local uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
								tri.circumcenter = ke.shape.point.new(ux, uy)
								tri.circumradius = tri.circumcenter:distance(tri.p1)
								return tri
							end,
							
							inside = function(self, p)
								if self.circumradius == math.huge then
									return false
								end
								return self.circumcenter:distance(p) < (self.circumradius - EPSILON)
							end,
							
							getedges = function(self)
								return {{self.p1, self.p2}, {self.p2, self.p3}, {self.p3, self.p1}}
							end
						},
						
						supertriangle = function(self)
							local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
							for i, p in ipairs(self.points) do
								minx, maxx = math.min(minx, p.x), math.max(maxx, p.x)
								miny, maxy = math.min(miny, p.y), math.max(maxy, p.y)
							end
							local dx, dy = maxx - minx, maxy - miny
							local deltamax = math.max(dx, dy) * 2
							local midx, midy = (minx + maxx) / 2, (miny + maxy) / 2
							return delaunay.triangle.new(
								ke.shape.point.new(midx - deltamax, midy - deltamax),
								ke.shape.point.new(midx + deltamax, midy - deltamax),
								ke.shape.point.new(midx, midy + deltamax)
							)
						end,
						
						edgeshared = function(self, edge, bads)
							local count = 0
							for _, tri in ipairs(bads) do
								local edges = tri:getedges()
								for _, triedge in ipairs(edges) do
									if (edge[1] == triedge[1] and edge[2] == triedge[2])
										or (edge[1] == triedge[2] and edge[2] == triedge[1]) then
										count = count + 1
									end
								end
							end
							return count > 1
						end,
						
						triangulate = function(self)
							local bigtriangle = self:supertriangle()
							local triangulation = {bigtriangle}
							-- Bowyer-Watson
							for _, p in ipairs(self.points) do
								local bads = {}
								for _, tri in ipairs(triangulation) do
									if tri:inside(p) then
										table.insert(bads, tri)
									end
								end
								local polygon = {}
								for _, bad in ipairs(bads) do
									local edges = bad:getedges()
									for _, edge in ipairs(edges) do
										if not self:edgeshared(edge, bads) then
											table.insert(polygon, edge)
										end
									end
								end
								local new = {}
								for _, tri in ipairs(triangulation) do
									local isbad = false
									for _, bad in ipairs(bads) do
										if tri == bad then
											isbad = true
											break
										end
									end
									if not isbad then
										table.insert(new, tri)
									end
								end
								triangulation = new
								for _, edge in ipairs(polygon) do
									local newtriangle = delaunay.triangle.new(edge[1], edge[2], p)
									table.insert(triangulation, newtriangle)
								end
							end
							local result = {}
							local supervertices = {bigtriangle.p1, bigtriangle.p2, bigtriangle.p3}
							for _, tri in ipairs(triangulation) do
								local shares = false
								local trianglevertices = {tri.p1, tri.p2, tri.p3}
								for _, supervertex in ipairs(supervertices) do
									for _, vertex in ipairs(trianglevertices) do
										if vertex == supervertex then
											shares = true
											break
										end
									end
									if shares then break end
								end
								if not shares then
									table.insert(result, tri)
								end
							end
							self.triangles = result
							return result
						end
					}
					local triangles = delaunay.new(points):triangulate()
					return triangles
				end,
				
			},
			
			["segment"] = {	--subclass
				
				__name = "segment",
				
				["__index"] = function(self, key)
					return ke.shape.segment[key]
				end,
				
				["new"] = function(seg)
					local seg, new = ke.table.get(seg, "tonumber"), {}
					new.t = #seg == 2 and "m" or (#seg == 4 and "l" or "b")
					local i = new.t == "m" and 1 or 0
					for k = 1, #seg, 2 do
						new[i] = ke.shape.point.new(seg[k], seg[k + 1])
						i = i + 1
					end
					setmetatable(new, ke.shape.segment)
					return new
				end, --ke.shape.segment.new("0 0 b 1 1 2 2 3 3 ")
				
				["__concat"] = function(self, shp)
					--concat segment with shape
					table.insert(shp.part, 1, {self})
					return ke.shape.new(shp.part)
				end, --segment .. shape
				
				["__copy"] = function(self)
					return ke.table.copy(self)
				end,
				
				["__type"] = function(self)
					return "segment"
				end,
				
				["__str"] = function(self)
					local x0, y0, x1, y1, x2, y2, x3, y3 = self:unpack()
					local str = {
						[1] = ("m %s %s "):format(x0, y0),
						[2] = ("%s %s l %s %s "):format(x0, y0, x1, y1),
						[3] = ("%s %s b %s %s %s %s %s %s "):format(x0, y0, x1, y1, x2, y2, x3, y3)
					}
					return x2 and str[3] or (x1 and str[2] or str[1])
				end,
				
				["__tostring"] = function(self)
					local x0, y0, x1, y1, x2, y2, x3, y3 = self:unpack()
					local str = {
						[1] = ("m %s %s "):format(x0, y0),
						[2] = ("%s %s l %s %s "):format(x0, y0, x1, y1),
						[3] = ("%s %s b %s %s %s %s %s %s "):format(x0, y0, x1, y1, x2, y2, x3, y3)
					}
					return x2 and str[3] or (x1 and str[2] or str[1])
				end,
				
				["__inv"] = function(self)
					return ke.shape.segment.new(ke.table.get(self, "inverse"))
				end, --ke.shape.segment.new("0 0 l 100 0 "):__inv()
				
				["length"] = function(self)
					--segment length
					return self.t == "m" and 0 or ke.shape.beziers.length(self)
				end,
				
				["bezier"] = function(self, t)
					return self.t == "m" and self[1] or ke.shape.beziers.config(self, t)
				end,
				
				["to_bezier"] = function(self)
					--converted a line to bezier
					if self.t == "l" then --line
						local x0, y0, x3, y3 = self:unpack()
						self = {t = "b", --bezier
							[0] = {x = x0, y = y0},
							[1] = {x = x0 + 0.33 * (x3 - x0), y = y0 + 0.33 * (y3 - y0)},
							[2] = {x = x0 + 0.67 * (x3 - x0), y = y0 + 0.67 * (y3 - y0)},
							[3] = {x = x3, y = y3}
						}
						self = ke.shape.segment.new(self)
					end
					return self
				end, --ke.shape.segment.new("0 0 l 0 100 "):to_bezier()
				
				["unpack"] = function(self)
					return table.unpack(ke.table.get(self, "tonumber"))
				end,
				
				["inside"] = function(self, p)
					--check point are inside in segment
					if self.t == "l" then
						local x0, y0, x1, y1 = self:unpack()
						if (p.x - x0) * (y1 - y0) == (p.y - y0) * (x1 - x0) then
							local t = (x0 == x1) and (p.y - y0) / (y1 - y0) or (p.x - x0) / (x1 - x0)
							return (t >= 0 and t <= 1) and t or false
						end
					elseif self.t == "b" then
						local Cx, Cy = ke.shape.beziers.coefficient(self)
						Cx[4], Cy[4] = Cx[4] - p.x, Cy[4] - p.y
						local root_x, root_y, t = ke.math.cubic(Cx), ke.math.cubic(Cy), {}
						for i = 1, #root_x do
							if ke.table.inside(root_y, ke.math.round(root_x[i], 3)) and (root_x[i] >= 0 and root_x[i] <= 1) then
								t[#t + 1] = root_x[i]
							end
						end
						if #t > 0 then
							return table.unpack(t)
						end
					end
					return false
				end,
				
				["cut"] = function(self, t)
					if type(t) == "table" then
						local parts, n = {}, t[1]
						if n == 1 then return self end
						local cur = self
						for i = 1, n - 1 do
							local t = 1 / (n - i + 1)
							local L, R = ke.shape.segment.cut(cur, t)
							parts[i] = L cur = R
						end
						table.insert(parts, cur)
						local newself = parts[1]
						for i = 2, #parts do
							for k = 1, 3 do
								table.insert(newself, parts[i][k])
							end
						end
						return newself
					end
					if self.t == "m" then
						return self
					end
					local x0, y0, x2, y2 = self:unpack()
					local x1, y1 = x0 + t * (x2 - x0), y0 + t * (y2 - y0)
					local s1, s2 = {x0, y0, x1, y1}, {x1, y1, x2, y2}
					local x, y = x1, y1
					if self.t == "b" then
						local Sx0, Sy0, Sx1, Sy1, Sx2, Sy2, Sx3, Sy3 = self:unpack()
						local bx0, by0 = Sx0 * (1 - t) + Sx1 * t, Sy0 * (1 - t) + Sy1 * t
						local bx1, by1 = Sx1 * (1 - t) + Sx2 * t, Sy1 * (1 - t) + Sy2 * t
						local bx2, by2 = Sx2 * (1 - t) + Sx3 * t, Sy2 * (1 - t) + Sy3 * t
						local bx3, by3 = bx0 * (1 - t) + bx1 * t, by0 * (1 - t) + by1 * t
						local bx4, by4 = bx1 * (1 - t) + bx2 * t, by1 * (1 - t) + by2 * t
						local bx5, by5 = bx3 * (1 - t) + bx4 * t, by3 * (1 - t) + by4 * t
						s1, s2 = {Sx0, Sy0, bx0, by0, bx3, by3, bx5, by5}, {bx5, by5, bx4, by4, bx2, by2, Sx3, Sy3}
						x, y = bx5, by5
					end
					return ke.shape.segment.new(s1), ke.shape.segment.new(s2), ke.shape.point.new(x, y)
				end,
				
				["intersect"] = function(self, other, without_vertices)
					--intersection (if any) between two segments
					local s1, s2 = ke.shape.segment.new(self), ke.shape.segment.new(other)
					local x, y, t = ke.math.intersect(s1, s2)
					local a, b, s = ke.math.intersect(s2, s1)
					if s1.t == "l" and s2.t == "l" then --segment and segment
						if without_vertices then
							if (t and (t <= 0 or t >= 1)) or (s and (s <= 0 or s >= 1))
								or math.abs(s1:angle() - s2:angle()) == 180 or s1:angle() == s2:angle() then
								return false
							end --ke.shape.segment.intersect("0 0 l 12 15 ", "5 0 l -4 5 ")
						else
							if (t and (t < 0 or t > 1)) or (s and (s < 0 or s > 1))
								or math.abs(s1:angle() - s2:angle()) == 180 or s1:angle() == s2:angle() then
								return false
							end
						end
						return ke.shape.point.new(x, y), t, s
					elseif s1.t == "l" or s2.t == "l" then --segment and bezier
						local seg = s1.t == "l" and s1 or s2
						local bez = s1.t == "l" and s2 or s1
						local segs = bez:split(1)
						local parts = ke.table.new(#segs, function(i) return ke.shape.segment.new({segs[i - 1], segs[i]}) end)
						local result = {}
						for _, s in ipairs(parts) do
							local p, t, u = seg:intersect(s)
							if p then
								table.insert(result, {p, t = t, u = u})
							end
							if #result == 3 then break end
						end --ke.shape.segment.intersect("m -5 25 l 57 3 ", "m 15 2 b 12 47 32 -7 45 13 ")
						return #result > 0 and result or false
					end
					return false
				end,
				
				["angle"] = function(self, other)
					--angle segment line or angle between two segments line
					return self.t == "m" and 0 or (other and self[0]:angle(self[1], other[1]) or ke.math.angle(self))
				end,
				
				["bisector"] = function(self, other)
					--mid angle between two segments line
					local ang = self:angle() - 180 + 0.5 * self:angle(other)
					return ang < 0 and ang + 360 or (ang > 360 and ang - 360 or ang)
				end,
				
				["parameter"] = function(self, t)
					if self.t == "m" then
						return self
					end
					local t =  type(t) == "table" and ke.shape.beziers.length2t(self, t[1]) or tonumber(t)
					local point, angle = self:bezier(t), ke.shape.beziers.angle(self, t)
					return point, angle, t
				end, --!_G.ke.table.view({_G.ke.shape.new(_G.ke.shape.circle).part[1][2]:parameter({50})})!
				
				["split"] = function(self, split)
					local split = type(split) == "function" and split() or split or 2
					local segms = type(split) == "table" and split[1] or nil
					local seg = self:__copy()
					if self.t == "m" then
						return self
					elseif self.t == "l" then
						local angle, length = self[0]:angle(self[1]), self[0]:distance(self[1])
						local parts = segms and length / segms or length / ke.math.round(length / split)
						for k = 1, ke.math.round(length / parts) do
							seg[k] = self[0]:polar(angle, parts * k)
						end
					else
						seg.t = "l"
						local l, k, t = self:length(), 1, 0
						split = segms and l / segms or split
						while true do
							t = ke.shape.beziers.length2t(self, k * split)
							if not t or t > 1 then
								--seg[k + 1] = self:bezier(1)
								table.insert(seg, self:bezier(1))
								break
							end
							seg[k] = self:bezier(t)
							k = k + 1
						end
					end
					return seg
				end,
				
				["intax"] = function(self, other)
					--check if two segments are "overlapping"
					local s1, s2 = ke.shape.segment.new(self), ke.shape.segment.new(other)
					local a1, a2 = s1:angle(), s2:angle()
					if (s1[0] == s2[0] and math.abs(a1 - a2) == 180) or (s1[0] == s2[1] and a1 == a2)
						or (s1[1] == s2[1] and math.abs(a1 - a2) == 180) or (s1[1] == s2[0] and a1 == a2) then
						return false
					end
					if not ke.shape.segment.intersect(s1, s2) then
						local a1, a2 = ke.shape.segment.angle(s1), ke.shape.segment.angle(s2)
						local x0, y0, x1, y1 = table.unpack(ke.table.get(s1, "tonumber"))
						local x2, y2, x3, y3 = table.unpack(ke.table.get(s2, "tonumber"))
						if     (x0 > x2 and x0 > x3) and (x1 > x2 and x1 > x3) or (x0 < x2 and x0 < x3) and (x1 < x2 and x1 < x3)
							or (y0 > y2 and y0 > y3) and (y1 > y2 and y1 > y3) or (y0 < y2 and y0 < y3) and (y1 < y2 and y1 < y3) then
							return false
						end
						return (a1 == a2 or math.abs(a1 - a2) == 180) and true or false
					end
					return false
				end,
				
				["rotate"] = function(self, Angle, o)
					local org = o == 0 and self[0] or (o == 1 and self[1] or o or self[0])
					for k, v in pairs(self) do
						self[k] = type(k) == "number" and ke.shape.point.rotate(v, Angle, org) or v
					end
					return ke.shape.segment.new(self)
				end, --ke.shape.segment.new("0 5 l 100 5 "):rotate(45)
				
				["extend"] = function(self, ext_i, ext_f)
					local self = self:__copy()
					local ext_i, ext_f, a = ext_i or 0, ext_f or 0, self:angle()
					self[0], self[1] = self[0]:polar(a + 180, ext_i), self[1]:polar(a, ext_f)
					return self
				end,
				
				["move"] = function(self, dxy)
					local dx, dy = table.unpack(ke.math.getpair(dxy, 0, 0))
					local k = self.t == "m" and 1 or 0
					for i = k, #self do
						self[i] = self[i] + {dx, dy}
					end
					return ke.shape.segment.new(self)
				end, --ke.shape.segment.new("0 0 b 2 2 4 4 6 6 "):move({-3,0})
				
				["ratio"] = function(self, rxy)
					local rx, ry = table.unpack(ke.math.getpair(rxy, 1, 1))
					local k = self.t == "m" and 1 or 0
					for i = k, #self do
						self[i].x = self[i].x * rx
						self[i].y = self[i].y * ry
					end
					return ke.shape.segment.new(self)
				end, --ke.shape.segment.new("0 0 b 2 2 4 4 6 6 "):ratio({2,1})
				
			},
			
			["polygon"] = {	--subclass
				
				__name = "polygon",
				
				["__index"] = function(self, key)
					return ke.shape.polygon[key]
				end,
				
				["new"] = function(path)
					--create the new polygon and insert in "polygon class"
					local path = (type(path) == "table" and path.points) and path or ke.shape.polygon.p2code(path)
					local self, poly = ke.shape.new(path):to_line(), {}
					local vertices, area = self:points(), 0
					poly.n = self.n
					for i = 1, #vertices do
						vertices[i].t = nil
						area = area + vertices[i]:cross(vertices[i % #vertices + 1])
					end
					poly.minx, poly.miny		= self.minx, self.miny
					poly.maxx, poly.maxy		= self.maxx, self.maxy
					poly.width, poly.height		= self.width, self.height
					poly.convex, poly.closed	= ke.shape.polygon.isconvex(vertices), vertices[1] == vertices[#vertices]
					poly.vertices, poly.code	= vertices, self.code
					poly.clockwise, poly.area	= area >= 0, area / 2
					poly.centroid, poly.radius	= ke.shape.point.new(self.center, self.middle), self.radius
					setmetatable(poly, ke.shape.polygon)
					return poly
				end, --ke.shape.polygon.new("m 0 0 l 0 20 l 40 20 l 40 10 l 20 10 l 20 0 l 0 0 ")
				
				["__copy"] = function(self)
					return ke.table.copy(self)
				end,
				
				["__type"] = function(self)
					return "polygon"
				end,
				
				["__tostring"] = function(self)
					return self.code
				end,
				
				["__seg"] = function(self)
					--get the polygon segments
					return ke.table.get(self:__closed().vertices, "tosegment")
				end,
				
				["__inv"] = function(self)
					--reverses the direction of the polygon tracing
					return ke.shape.polygon.new(ke.table.get(self.vertices, "inverse"))
				end,
				
				["__gsub"] = function(self, filter)
					--applies a filter function to the polygon points
					local v, ki = self.vertices, ke.math.count()
					local x0, y0, x1, y1, O, Or = self.minx, self.miny, self.maxx, self.maxy, self.centroid, self.radius
					local maxdist = function(angle)
						local bounding = {{x0, y0, x0, y1}, {x0, y1, x1, y1}, {x1, y1, x1, y0}, {x1, y0, x0, y0}}
						local ray, p = ke.shape.segment.new({O, O:polar(angle, 2 * Or)})
						for i = 1, 4 do
							p = ray:intersect(bounding[i])
							if p then
								break
							end
						end
						return ke.math.distance(p, O)
					end
					for i = 1, #v do
						local x, y = v[i].x, v[i].y
						Cx, Cy = O.x, O.y					--coordenadas del centro
						Dc = ke.math.distance(Cx, Cy, x, y)	--distancia del punto al centro
						Ac = ke.math.angle(Cx, Cy, x, y)	--ángulo del centro al punto
						Dm = maxdist(Ac)					--distancia desde el centro al bounding
						Pk, Pn = ki(), self.n				--contador de puntos y cantidad total
						Mx = (y - y0) / self.height			--módulo de varianza respecto a "x", Mx = [0, 1]
						My = (x - x0) / self.width			--módulo de varianza respecto a "y", My = [0, 1]
						Mp = (Pk - 1) / (Pn - 1)			--módulo de varianza respecto a los puntos, Mp = [0, 1]
						v[i].x, v[i].y = filter(x, y)		--aplicación del filtro al punto
					end
					return ke.shape.polygon.new(v)
				end,
				
				["__closed"] = function(self)
					local vertices = self.vertices
					vertices[#vertices + 1] = not self.closed and vertices[1]:__copy() or nil
					return ke.shape.polygon.new(vertices)
				end,
				
				["__unclosed"] = function(self)
					local vertices = self.vertices
					vertices[#vertices] = not self.closed and vertices[#vertices] or nil
					return ke.shape.polygon.new(vertices)
				end,
				
				["__clockwise"] = function(self)
					local vertices = self.vertices
					vertices = not self.clockwise and ke.table.get(vertices, "inverse") or vertices
					return ke.shape.polygon.new(vertices)
				end,
				
				["angles"] = function(self)
					--get angles of the polygon vertices
					local v = self:__unclosed().vertices
					local angs = ke.table.new(#v, function(i) return v[(i - 2) % #v + 1]:angle(v[i], v[i % #v + 1]) end)
					return angs
				end, --ke.shape.polygon.new(ke.shape.rectangle):angles()
				
				["rotate"] = function(self, angle, o, axis)
					--polygon 3d rotation
					local self = self.vertices and self or ke.shape.polygon.new(self)
					for i = 1, #self.vertices do
						self.vertices[i] = ke.shape.point.rotate(self.vertices[i], angle, o, axis)
					end
					return ke.shape.polygon.new(self.vertices)
				end, --ke.shape.polygon.rotate(ke.shape.rectangle, 20).code
				
				["collision"] = function(self, other)
					--check the collision between two polygons
					local seg1, seg2 = self:__seg(), other:__seg()
					for i = 1, #seg1 do
						for k = 1, #seg2 do
							if seg1[i]:intersect(seg2[k], true) then
								return true
							end
						end
					end
					return false
				end,
				
				["tolefttop"] = function(self)
					local points = (type(self) == "table" and self.vertices) and self.vertices
					or (type(self) == "string" and ke.table.get(self, "topoint") or self)
					local idx, closed = 1, points[1] == points[#points] and 1 or 0
					for i = 2, #points - closed do
						idx = (points[i].x <= points[idx].x and points[i].y < points[idx].y) and i or idx
					end
					points[#points] = closed == 0 and points[#points] or nil
					points = ke.table.get(points, "move", {1 - idx})
					points[#points + 1] = closed == 1 and points[1] or nil
					return ke.shape.polygon.new(points)
				end,
				
				["uncollinear"] = function(self)
					local points = self.vertices and self.vertices or self
					local v, P = {points[1]}, {points[1]}
					for i = 2, #points do
						P[#P + 1] = points[i] ~= points[i - 1] and points[i] or nil
					end
					for k = 2, #P do
						if not P[k - 1]:collinear(P[k], P[k % #P + 1]) then
							v[#v + 1] = P[k]
						end
					end
					if v[#v]:collinear(v[1], v[2]) then
						table.remove(v, 1)
					end
					v[#v + 1] = P[1] == P[#P] and v[1] or nil
					return ke.shape.polygon.new(v)
				end,
				
				["p2code"] = function(points)
					local code, points = "", ke.table.get(type(points) == "table" and points.vertices or points, "topoint")
					for i = 1, #points do
						code = code .. ("l %s %s "):format(points[i].x, points[i].y)
					end
					code = code:gsub("l", "m", 1)
					return code
				end,
				
				["selfcut"] = function(self)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local segs = self:__seg()
					for i = 1, #segs do
						for k = i + 2, #segs - 1 do
							if segs[i]:intersect(segs[k]) then
								return true
							end
						end
					end
					return false
				end, --ke.shape.polygon.selfcut("m 0 40 l 20 40 l 30 30 l 10 10 l 20 0 l 30 10 l 10 30 l 10 20 l 0 20 ")
				
				["divide"] = function(self)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local segs, paths, polys, forms = self:__seg(), {}, {}, {}
					local v, length, nl, p = {[0] = segs[1][0]}, 0, 0
					for i = 1, #segs do
						for k = i + 2, #segs + i - 2 do
							p = segs[i]:intersect(segs[(k - 1) % #segs + 1])
							if p then
								nl = length + p:distance(segs[i][0])
								v[nl] = p
								v[nl].i = tostring(p)
							end
						end
						length = length + segs[i]:length()
						v[length] = segs[i][1]
					end
					v = ke.table.get(v, "idx")
					for i = 1, #v do
						if v[i].i then
							paths[i] = {v[i]}
							for k = i + 1, #v + i do
								paths[i][#paths[i] + 1] = not v[(k - 1) % #v + 1].i and v[(k - 1) % #v + 1] or nil
								if v[(k - 1) % #v + 1].i then
									paths[i][#paths[i] + 1] = v[(k - 1) % #v + 1]
									break
								end
							end
						end
					end
					for _, v in pairs(paths) do
						polys[#polys + 1] = v[1].i == v[#v].i and ke.shape.polygon.new(v):uncollinear() or nil
						forms[#forms + 1] = v[1].i ~= v[#v].i and v or nil
					end
					local reforms, newidx = {[1] = forms[1]}
					table.remove(forms, 1)
					while #forms > 0 do
						newidx = #forms
						for i = 1, #reforms do
							if forms[1][1].i == reforms[i][#reforms[i]].i then
								reforms[i] = ke.table.get(reforms[i], "insert", forms[1])
								table.remove(forms, 1)
								break
							end
						end
						if newidx == #forms then
							reforms[#reforms + 1] = {forms[1]}
							table.remove(forms, 1)
						end
					end
					for i = 1, #reforms do
						polys[#polys + 1] = ke.shape.polygon.new(reforms[i]):uncollinear()
					end
					polys[#polys + 1] = #polys == 0 and self or nil
					return polys
				end, --ke.shape.polygon.divide("m 0 25 l 30 25 l 30 0 l 45 0 l 45 16 l 3 16 l 3 5 l 18 5 l 18 37 l 0 37 ")
				
				["isconvex"] = function(self)
					local P = self.vertices and self.vertices or self
					if #P < 4 then
						return true
					end
					local idx, state = P[1] == P[#P] and 1 or 0, P[1]:angle(P[2], P[3]) <= 180
					for i = 2, #P - 2 - idx do
						if (P[i]:angle(P[i + 1], P[i + 2]) <= 180) == not state then
							return false
						end
					end
					return true
				end,
				
				["triangulate"] = function(self)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					if #self.vertices == 3 then return {self} end
					local triangles, concave, adj = {}, {}, {}
					local vertices = self.vertices
					for i, p in ipairs(vertices) do
						local l = (i == 1) and vertices[#vertices] or vertices[i - 1]
						local r = (i == #vertices) and vertices[1] or vertices[i + 1]
						adj[p] = {p = p, l = l, r = r}
						if not l:clockwise(p, r) then
							concave[p] = p
						end
					end
					local function isEar(p1, p2, p3)
						if not p1:clockwise(p2, p3) then
							return false
						end
						for q, v in pairs(concave) do
							if v:in3angle(p1, p2, p3) then
								return false
							end
						end
						return true
					end
					local nPoints, skipped, p = #vertices, 0, adj[vertices[2]]
					while nPoints > 3 do
						if not concave[p.p] and isEar(p.l, p.p, p.r) then
							triangles[#triangles + 1] = ke.shape.polygon.new({p.l, p.p, p.r})
							if concave[p.l] and adj[p.l].l:clockwise(p.l, p.r) then
								concave[p.l] = nil
							end
							if concave[p.r] and p.l:clockwise(p.r, adj[p.r].r) then
								concave[p.r] = nil
							end
							adj[p.l].r, adj[p.r].l, adj[p.p] = p.r, p.l
							nPoints = nPoints - 1
							skipped, p = 0, adj[p.l]
						else
							p = adj[p.r]
							skipped = skipped + 1
							assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
						end
					end
					triangles[#triangles + 1] = ke.shape.polygon.new({p.l, p.p, p.r})
					return triangles
				end,
				
				["merged"] = function(self, other)
					local getsharededge = function(self, other)
						local p, q, vertices = self.vertices, other.vertices, {}
						for i, v in ipairs(q) do
							vertices[tostring(v)] = i
						end
						for i, v in ipairs(p) do
							local w = (i == #p) and p[1] or p[i + 1]
							if vertices[tostring(v)] and vertices[tostring(w)] then
								return i, vertices[tostring(v)]
							end
						end
					end
					local p, q = getsharededge(self, other)
					if not (p and q) then
						return nil
					end
					local ret = ke.table.new(p, function(i) return self.vertices[i] end)
					for i = 2, #other.vertices - 1 do
						local k = i + q - 1
						k = k > #other.vertices and k - #other.vertices or k
						ret:insert(other.vertices[k])
					end
					for i = p + 1, #self.vertices do
						ret:insert(self.vertices[i])
					end
					return ke.shape.polygon.new(ret)
				end, --ke.shape.polygon.merged(ke.shape.polygon.new ("m 0 0 l 10 0 l 10 10 l 0 10 "), ke.shape.polygon.new ("m 10 0 l 20 0 l 20 10 l 10 10 ")).code
				
				["domerged"] = function(self, other)
					local pnt1, pnt2 = self.vertices, other.vertices
					local ret, i, state = {}, 1
					while pnt1[i] do
						for k = 1, #pnt2 do
							if pnt1[i] == pnt2[k] then
								while pnt2[k] do
									ret[#ret + 1] = pnt2[(k - 1) % #pnt2 + 1]
									for j = #pnt1, i + 1, -1 do
										if pnt1[j] == pnt2[k] then
											state, i = true, j
											break
										end
									end
									if state then
										break
									end
									k = k % #pnt2 + 1
								end
								ret[#ret] = nil
								break
							end
						end
						ret[#ret + 1], i = pnt1[i], i + 1
					end
					return ke.shape.polygon.new(ret):uncollinear()
				end,
				
				["splitconvex"] = function(self)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					if #self.vertices <= 3 or self.convex then
						return {self}
					end
					local convex, i = self:triangulate(), 1
					repeat
						local p, k = convex[i], i + 1
						while k <= #convex do
							local _, fusion = pcall(function() return p:merged(convex[k]) end)
							if fusion and fusion.convex then
								convex[i] = fusion
								p = convex[i]
								table.remove(convex, k)
							end
							k = not(fusion and fusion.convex) and k + 1 or k
						end
						i = i + 1
					until i >= #convex
					return convex
				end, --ke.shape.polygon.new("m 0 0 l 20 0 l 20 20 l 40 20 l 40 40 l 0 40 l 0 0 "):splitconvex()
				
				["inside"] = function(self, p)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local segs, v, into = self:__seg(), self.vertices, false
					if getmetatable(p) == ke.shape.polygon then --polygon
						local psegs = p:__seg()
						for i = 1, #psegs do
							if not self:inside(psegs[i]) then
								return false
							end
						end
						for i = 1, #v do
							for k = i + 1, #v + i - 1 do
								if not self:inside(v[i]:middle(v[(k - 1) % #v + 1])) then
									return false
								end
							end
						end
						return true
					end
					if getmetatable(p) == ke.shape.segment then --segment
						if not self:inside(p[0]) or not self:inside(p[1]) then
							return false
						end
						local seg_ang, ang = p:angle()
						for i = 1, #segs do
							if segs[i]:inside(p[0]) or segs[i]:inside(p[1]) then
								ang = segs[i]:angle()
								if ang == seg_ang or math.abs(ang - seg_ang) == 180 then
									if not (segs[i]:inside(p[0]) and segs[i]:inside(p[1])) then
										return false
									end
								end
							end
						end
						return true
					end
					for i = 1, #segs do --point
						if segs[i]:inside(p) then return true end
					end
					local check = function(a, b)
						local st1 = ((a.y > p.y and b.y < p.y) or (a.y < p.y and b.y > p.y)) and (p.x - a.x < (p.y - a.y) * (b.x - a.x) / (b.y - a.y))
						local st2 = ((a.y == p.y and a.x > p.x and b.y < p.y)) or (b.y == p.y and b.x > p.x and a.y < p.y)
						return st1 or st2
					end
					for i = 1, #v do
						into = check(v[i], v[i % #v + 1]) and not into or into
					end
					return into
				end, --ke.shape.polygon.inside(ke.shape.polygon.new(ke.shape.rectangle), ke.shape.point.new(10, 20))
				
				["cutray"] = function(self, segment)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local p, v = segment[0], segment[1]
					local n = v:ortho()
					local vertices = self.vertices
					for i = 1, #vertices do
						local q1, q2 = vertices[i], vertices[(i % #vertices) + 1]
						local w = q2 - q1
						local det = v:cross(w)
						if det ~= 0 then
							local r = q2 - p
							local l, m = r:cross(w), v:cross(r)
							if l >= 0 and m >= 0 and m <= det then
								return true, l
							end
						else
							local dist = (q1 - p) * n
							if dist == 0 then
								local l, m = v * (q1 - p), v * (q2 - p)
								if l >= 0 and l >= m then
									return true, l
								end
								if m >= 0 then
									return true, m
								end
							end
						end
					end
					return false
				end,
				
				["filtergroup"] = function(group, filter)
					for i = 1, #group do
						group[i] = filter(group[i])
					end
					return group
				end,
				
				["cutseg"] = function(self, ray)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local ray = ke.shape.segment.new(ray or "0 5 l 100 5 ")
					local angle, org = ray:angle(), self.centroid
					ray = ray:rotate(-angle, org)
					local v_upper, v_lower, seg_H = {}, {}, ray:extend(100000, 100000)
					self, ray = self:rotate(-angle, org), seg_H[0].y
					local assign_seg = function(seg)
						v_upper[#v_upper + 1] = (seg[0].y <  ray and seg[1].y <  ray) and seg[1] or nil
						v_lower[#v_lower + 1] = (seg[0].y >= ray and seg[1].y >= ray) and seg[1] or nil
						if seg:intersect(seg_H) then
							local P = seg:intersect(seg_H)
							v_upper[#v_upper + 1] = P
							v_lower[#v_lower + 1] = seg[0].y <  ray and P or nil
							v_upper[#v_upper + 1] = seg[0].y >= ray and seg[1] or nil
							v_lower[#v_lower + 1] = seg[0].y <  ray and seg[1] or P
						end
					end
					local segs = self:__seg()
					v_upper[1] = segs[1][0].y <  ray and segs[1][0] or nil
					v_lower[1] = segs[1][0].y >= ray and segs[1][0] or nil
					for i = 1, #segs do
						assign_seg(segs[i])
					end
					return {
						ke.shape.polygon.filtergroup(
							ke.shape.polygon.new(v_upper):divide(), function(poly) return poly:rotate(angle, org) end
						),
						ke.shape.polygon.filtergroup(
							ke.shape.polygon.new(v_lower):divide(), function(poly) return poly:rotate(angle, org) end
						)
					}
				end, --ke.shape.polygon.new(shape.rectangle):cutseg("0 20 l 100 20 ")
				
				["toconvex"] = function(self)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local ok2c, no2c = {}, {}
					local split = function(poly)
						local segs, state = poly:__copy():__closed():__seg(), false
						local v1, v2, a, idx1, idx2, p = {[1] = segs[1][0]}, {}, poly:angles()
						local selfxcut = function(hh, p1, p2)
							for jj = hh + 1, #segs + hh do
								if segs[(jj - 1) % #segs + 1]:intersect({p1, p2}, true) then
									return true
								end
							end
							return false
						end
						for i = 1, #segs do
							for k = 1, #segs - 3 do
								local j = ((k - 1) % (#segs - 3) + i + 1) % #segs + 1
								p = segs[i]:extend(100000, 100000):intersect(segs[j], true)
								if p and not selfxcut(j, segs[i][1], p)
									and ((a[i] < 180 and a[i % #a + 1] > 180) or (a[i] > 180 and a[i % #a + 1] < 180)) then
									idx1, idx2 = i, j
									v2[#v2 + 1] = segs[i][1]
									if j < i then state, v1, v2, idx1, idx2 = true, {}, {p}, j, i end
									v1[#v1 + 1] = p
									break
								end
							end
							if idx1 then
								break
							end
							v1[#v1 + 1] = segs[i][1]
						end
						if idx1 then
							local ii, kk = state and 0 or 1, state and idx1 - 1 or 0
							for i = idx2, #segs + kk do v1[#v1 + 1] = segs[(i - 1) % #segs + 1][1] end
							for i = idx1 + ii, idx2 - 1 do v2[#v2 + 1] = segs[i][1] end
							v1[#v1 + 1], v2[#v2 + 1] = state and p or nil, p
							local pg1 = ke.shape.polygon.new(v1):__closed():uncollinear()
							local pg2 = ke.shape.polygon.new(v2):__closed():uncollinear()
							ok2c[#ok2c + 1], no2c[#no2c + 1] = pg1.convex and pg1 or nil, not pg1.convex and pg1 or nil
							ok2c[#ok2c + 1], no2c[#no2c + 1] = pg2.convex and pg2 or nil, not pg2.convex and pg2 or nil
						end
					end
					if self.convex then return {self} end
					split(self:uncollinear():__clockwise())
					while #no2c > 0 do
						local newpoly = no2c[1]
						table.remove(no2c, 1)
						split(newpoly)
					end
					return ke.table.new(#ok2c, function(i) return ok2c[i].area ~= 0 and ok2c[i] or nil end)
				end, --ke.shape.polygon.toconvex("m 0 10 l 0 -10 l 17 -10 l 17 16 l 28 16 l 28 -4 l 50 -4 l 50 32 l 42 32 l 42 1 l 35 1 l 35 32 l 0 32 l 0 10 ")
				
				["topolygon"] = function(path)
					local self = type(path) == "function" and path() or path
					self = type(self) == "string" and ke.shape.new(self) or self
					local shapes = self:divide()
					return ke.table.new(#shapes, function(i) return ke.shape.polygon.new(shapes[i]) end)
				end, --ke.shape.polygon.topolygon("m 0 0 l 0 30 l 30 30 l 30 0 l 0 0 m 10 10 l 20 10 l 20 20 l 10 20 l 10 10 ")
				
				["pointcut"] = function(self, other)
					--inserts the cut points (if any) in the vertex array of each polygon
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local other = other.vertices and other or ke.shape.polygon.new(other)
					local segs1, segs2, helpers, state = self:__seg(), other:__seg(), {}, false
					helpers = {
						["inedge"] = function(segs, p)
							for i = 1, #segs do
								if segs[i]:inside(p) then
									p.i = tostring(p)
									return p
								end
							end
							return false
						end,
						["getcut"] = function(segs_i, segs_f)
							local v, idx, length, p, q = {[0] = segs_i[1][0]}, 0, 0
							for i = 1, #segs_i do
								q = helpers.inedge(segs_f, segs_i[i][1])
								if not q then
									for k = 1, #segs_f do
										p = segs_i[i]:intersect(segs_f[k], true)
										if p then
											p.i, idx = tostring(p), length + p:distance(segs_i[i][0])
											v[idx], state = p, true
										end
									end
								end
								length = length + ke.math.distance(segs_i[i])
								v[length], state = q and q or segs_i[i][1], q and true or state
							end
							return ke.table.get(v, "idx")
						end
					}
					local v1, v2 = helpers.getcut(segs1, segs2), helpers.getcut(segs2, segs1)
					if state then
						local j, k = 1, 1
						for i = 1, #v1 do
							if v1[i].i then
								j = i
								break
							end
						end
						for i = 1, #v2 do
							if v2[i].i then
								k = i
								break
							end
						end
						v1, v2 = ke.table.get(v1, "move", {1 - j}), ke.table.get(v2, "move", {1 - k})
						v1[#v1 + 1], v2[#v2 + 1] = ke.table.copy(v1[1]), ke.table.copy(v2[1])
					end
					return v1, v2, state
				end,
				
				["clipper"] = function(self, other, Mode)
					--Mode: "union", "intersection", "xor", "subtraction"
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local other = other.vertices and other or ke.shape.polygon.new(other)
					self, other = self:__clockwise(), other:__clockwise()
					local Mode = Mode or "intersection"
					local v1, v2, state = self:pointcut(other)
					if not state then
						if Mode == "subtraction" then
							return self:inside(other) and {self, other:__inv()} or {self}
						end
						return (Mode == "union" or Mode == "xor") and {self, other} or {}
					end
					local polys, paths = {}, {}
					if Mode == "xor" or Mode == "subtraction" then
						v2 = ke.table.get(v2, "inverse")
						for i = 1, #v2 do
							if v2[i].i then
								polys[i] = {v2[i]}
								for k = i + 1, i + #v2 do
									polys[i][#polys[i] + 1] = not v2[(k - 1) % #v2 + 1].i and v2[(k - 1) % #v2 + 1] or nil
									if v2[(k - 1) % #v2 + 1].i then
										polys[i][#polys[i] + 1] = v2[(k - 1) % #v2 + 1]
										break
									end
								end
								for k = 1, #v1 do
									if v1[k].i and v1[k].i == polys[i][#polys[i]].i then
										for j = k + 1, k + #v1 do
											polys[i][#polys[i] + 1] = not v1[(j - 1) % #v1 + 1].i and v1[(j - 1) % #v1 + 1] or nil
											if v1[(j - 1) % #v1 + 1].i then
												break
											end
										end
									end
								end
							end
						end
						for k, v in pairs(polys) do
							v = ke.shape.polygon.new(v)
							if v.area ~= 0 then
								v = v:uncollinear():__closed()
								if Mode == "xor" then
									paths[#paths + 1] = v
								else --"subtraction"
									paths[#paths + 1] = (self:inside(v) and not other:inside(v)) and v or nil
								end
							end
						end
					else
						local polyway = function()
							local idx1, idx2, paths1, paths2 = {}, {}, {}, {}
							for i = 1, #v1 do idx1[#idx1 + 1] = v1[i].i and i or nil end
							for i = 1, #v2 do idx2[#idx2 + 1] = v2[i].i and i or nil end
							for i = 1, #idx1 - 1 do
								paths1[i] = {poly = 1}
								for k = idx1[i], idx1[i + 1] do paths1[i][#paths1[i] + 1] = v1[k] end
							end
							for i = 1, #idx2 - 1 do
								paths2[i] = {poly = 2}
								for k = idx2[i], idx2[i + 1] do paths2[i][#paths2[i] + 1] = v2[k] end
							end
							return paths1, paths2
						end
						local getpaths = function()
							local paths1, paths2 = polyway()
							local xpoly = {[1] = paths1[1]}
							table.remove(paths1, 1)
							local interunion = function()
								local state = false
								for i = 1, #paths2 do
									for k = 1, #xpoly do
										if paths2[i][1].i == xpoly[k][#xpoly[k]].i
											and xpoly[k][1].i ~= xpoly[k][#xpoly[k]].i then
											xpoly[k], state = ke.table.get(xpoly[k], "insert", paths2[i]), true
											table.remove(paths2, i)
											break
										end
									end
									if state then
										break
									end
								end
								if not state then
									xpoly[#xpoly + 1] = paths2[1]
									table.remove(paths2, 1)
								end
								state = false
								for i = 1, #paths1 do
									for k = 1, #xpoly do
										if paths1[i][1].i == xpoly[k][#xpoly[k]].i
											and xpoly[k][1].i ~= xpoly[k][#xpoly[k]].i then
											xpoly[k], state = ke.table.get(xpoly[k], "insert", paths1[i]), true
											table.remove(paths1, i)
											break
										end
									end
									if state then break end
								end
								if not state or xpoly[#xpoly][1].i == xpoly[#xpoly][#xpoly[#xpoly]].i then
									xpoly[#xpoly + 1] = paths1[1]
									table.remove(paths1, 1)
								end
							end
							while #paths1 > 0 or #paths2 > 0 do
								interunion()
							end
							return xpoly
						end
						polys = getpaths()
						for k, v in pairs(polys) do
							v = ke.shape.polygon.new(v)
							if v.area ~= 0 then
								v = v:uncollinear():__closed()
								if Mode == "union" then
									paths[#paths + 1] = (not self:inside(v) and not other:inside(v)) and v or nil
								else --"intersection"
									paths[#paths + 1] = (self:inside(v) and other:inside(v)) and v or nil
								end
							end
						end
					end
					return paths
				end, --ke.shape.polygon.clipper("m 0 10 l 0 -10 l 17 -10 l 17 16 l 28 16 l 28 -4 l 50 -4 l 50 32 l 42 32 l 42 1 l 35 1 l 35 32 l 0 32 l 0 10 ", "m 10 10 l 31 10 l 31 37 l 10 37 l 10 10 ")
				
				["offset"] = function(self, bord)
					local self = self.vertices and self or ke.shape.polygon.new(self)
					local bord = type(bord) == "function" and bord() or bord or 4
					bord = math.abs(type(bord) == "number" and bord or 4) / 2
					local v, A_ext, A_int, n, rat = self.vertices, ke.table.new(), ke.table.new(), 0, 0.115
					for i = 2, #v do
						if v[i] == v[1] then
							n = n + 1
						else
							break
						end
					end
					v = n > 0 and ke.table.get(v, "delete", {{1, n - 1}}) or v
					v[0] = self.closed and v[#v - 1] or v[1]:polar(v[2]:angle(v[1]), 1)
					v[#v + 1] = self.closed and v[2] or v[#v]:polar(v[#v - 1]:angle(v[#v]), 1)
					for i = 1, #v - 1 do
						local p0, p1, p2 = v[i - 1], v[i], v[i + 1]
						local angB, angI = p0:bisector(p1, p2), p0:angle(p1, p2)
						local radius = math.abs(bord / math.sin(math.rad(angB - p1:angle(p0) - (angI <= 300 and 0 or rat) * angI)))
						A_ext[#A_ext + 1] = angI <= 300 and p1:polar(angB,  radius) or p1:polar(angB - rat * angI,  radius)
						A_int[#A_int + 1] = angI <= 300 and p1:polar(angB, -radius) or p1:polar(angB - rat * angI, -radius)
						A_ext[#A_ext + 1] = (angI > 300 and i ~= #v) and p1:polar(angB + rat * angI,  radius) or nil
						A_int[#A_int + 1] = (angI > 300 and i ~= #v) and p1:polar(angB + rat * angI, -radius) or nil
					end
					return ke.shape.polygon.new(A_ext("insert", A_int("inverse"))):__closed()
				end, --ke.shape.polygon.offset(shape.star, 8).code
				
				["convexscan"] = function(self)
					--get the convex polygon that can be generated
					local points, state = self.vertices or self, true
					local P = {points[1]}
					for i = 2, #points do
						P[#P + 1] = points[i] ~= points[i - 1] and points[i] or nil
					end
					local h, k, closed = 1, 1, P[1] == P[#P] and 1 or 0
					for i = 1, #P - closed do
						k = P[i].x <= P[k].x and i or k
					end
					local vertices = {[1] = P[k]}
					vertices[1].i = "first"
					table.remove(P, k)
					local angles = ke.table.new(#P, function(i) return (ke.shape.point.angle(vertices[1], P[i]) + 269) % 360 + 1 end)
					for i = 1, #angles do
						h = angles[h] > angles[i] and h or i
					end
					vertices[2] = P[h]
					table.remove(P, h)
					P[#P + 1] = vertices[1]
					local scan = function()
						local k, angles = 1, {}
						for i = 1, #P do
							angles[i] = ke.shape.point.angle(vertices[#vertices - 1], vertices[#vertices], P[i])
							angles[i] = angles[i] == 360 and 0 or angles[i]
						end
						for i = 1, #angles do
							k = angles[k] > angles[i] and k or i
						end
						if P[k].i == "first" then
							P, state = {}, false
						else
							vertices[#vertices + 1] = P[k]
							table.remove(P, k)
						end
					end
					while #P > 1 do
						scan()
					end
					vertices[#vertices + 1] = state and P[1] or nil
					return ke.shape.polygon.new(vertices):__closed():uncollinear()
				end, --ke.shape.polygon.convexscan(ke.shape.point.random(12, 20, 20)).code
				
			},
			
			["beziers"] = {	--sublibrary
				
				["config"] = function(points, t)
					--generates the curve bezier points
					local t = type(t) == "function" and t() or t
					local coor = ke.table.get(points, "tonumber")
					local bernstein = function(i, n, t) --terms of the parametric polynomial bezier
						return (ke.math.factk(n) / (ke.math.factk(i) * ke.math.factk(n - i))) * (t ^ i) * ((1 - t) ^ (n - i))
					end
					local x, y, n = 0, 0, #coor / 2
					for i = 1, n do
						x = x + coor[2 * i - 1] * bernstein(i - 1, n - 1, t)
						y = y + coor[2 * i - 0] * bernstein(i - 1, n - 1, t)
					end
					return ke.shape.point.new(x, y)
				end,
				
				["length"] = function(bezier, t, n)
					local t, n = t or 1, n or 24--8
					local coor = ke.table.get(bezier, "tonumber")
					if #coor == 4 then --line
						return ke.math.distance(coor) * t
					end
					local Dt, SFt1, SFt2 = {}, 0, 0
					for i = 1, 2 * n + 1 do
						Dt[i] = (i - 1) * t / (2 * n)
					end
					local BZxy = ke.shape.beziers.difference(bezier)
					local dpos = ke.shape.beziers.differential(BZxy, Dt[1])
					local Ft1 = (dpos[2][1] ^ 2 + dpos[2][2] ^ 2) ^ 0.5
					dpos = ke.shape.beziers.differential(BZxy, Dt[2 * n + 1])
					local Ft2 = (dpos[2][1] ^ 2 + dpos[2][2] ^ 2) ^ 0.5
					for i = 1, n do
						dpos = ke.shape.beziers.differential(BZxy, Dt[2 * i])
						SFt1 = SFt1 + (dpos[2][1] ^ 2 + dpos[2][2] ^ 2) ^ 0.5
					end
					for i = 1, n - 1 do
						dpos = ke.shape.beziers.differential(BZxy, Dt[2 * i + 1])
						SFt2 = SFt2 + (dpos[2][1] ^ 2 + dpos[2][2] ^ 2) ^ 0.5
					end
					return (t / (6 * n)) * ((Ft1 + Ft2) + (4 * SFt1) + (2 * SFt2))
				end,
				
				["angle"] = function(points, t)
					--angle of a point P on a bezier curve, according to the parameter t
					local t = type(t) == "function" and t() or t or 1
					local Px, Py = {}, {}
					local coor = ke.table.get(points, "tonumber")
					if #coor == 4 then return ke.math.angle(coor) end
					for i = 1, #coor / 2 do
						Px[i], Py[i] = coor[2 * i - 1], coor[2 * i]
					end
					local Pdx = -3 * (Px[1] - Px[2]) * (1 - t) ^ 2 - 6 * (Px[2] - Px[3]) * t * (1 - t) - 3 * (Px[3] - Px[4]) * t ^ 2
					local Pdy = -3 * (Py[1] - Py[2]) * (1 - t) ^ 2 - 6 * (Py[2] - Py[3]) * t * (1 - t) - 3 * (Py[3] - Py[4]) * t ^ 2
					return ke.math.round(math.deg(math.atan2(-Pdy, Pdx)), 3)
				end,
				
				["difference"] = function(bezier)
					if #bezier == 1 then --is segment
						local p0, p3 = bezier[0], bezier[1]
						local p1, p2 = p0:ipol(p3, 0.33), p0:ipol(p3, 0.67)
						bezier = {[0] = p0, [1] = p1, [2] = p2, [3] = p3}
					end
					local DVec, BZxy = {}, {}
					--1st step difference
					DVec[1] = {bezier[1].x - bezier[0].x, bezier[1].y - bezier[0].y}
					DVec[2] = {bezier[2].x - bezier[1].x, bezier[2].y - bezier[1].y}
					DVec[3] = {bezier[3].x - bezier[2].x, bezier[3].y - bezier[2].y}
					--2nd step difference
					DVec[4] = {DVec[2][1] - DVec[1][1], DVec[2][2] - DVec[1][2]}
					DVec[5] = {DVec[3][1] - DVec[2][1], DVec[3][2] - DVec[2][2]}
					--3rd step difference
					DVec[6] = {DVec[5][1] - DVec[4][1], DVec[5][2] - DVec[4][2]}
					BZxy[1] = {bezier[0].x, bezier[0].y}
					BZxy[2] = {DVec[1][1], DVec[1][2]}
					BZxy[3] = {DVec[4][1], DVec[4][2]}
					BZxy[4] = {DVec[6][1], DVec[6][2]}
					return BZxy
				end,
				
				["differential"] = function(BZxy, t)
					local dPos = {}
					dPos[1] = {
						[1] = BZxy[4][1] * t ^ 3 + 3 * BZxy[3][1] * t ^ 2 + 3 * BZxy[2][1] * t + BZxy[1][1],
						[2] = BZxy[4][2] * t ^ 3 + 3 * BZxy[3][2] * t ^ 2 + 3 * BZxy[2][2] * t + BZxy[1][2]
					}
					dPos[2] = {
						[1] = 3 * (BZxy[4][1] * t ^ 2 + 2 * BZxy[3][1] * t + BZxy[2][1]),
						[2] = 3 * (BZxy[4][2] * t ^ 2 + 2 * BZxy[3][2] * t + BZxy[2][2])
					}
					dPos[3] = {
						[1] = 6 * (BZxy[4][1] * t + BZxy[3][1]),
						[2] = 6 * (BZxy[4][2] * t + BZxy[3][2])
					}
					return dPos
				end,
				
				["tangential2p"] = function(bezier, t)
					local tanvec = {}
					local BZxy = ke.shape.beziers.difference(bezier)
					local dpos = ke.shape.beziers.differential(BZxy, t) 
					tanvec[1] = dpos[2][1] / ke.math.distance(dpos[2])
					tanvec[2] = dpos[2][2] / ke.math.distance(dpos[2])
					return tanvec
				end,
				
				["length2t"] = function(bezier, length)
					local coor = ke.table.get(bezier, "tonumber")
					if #coor == 4 then --line
						return length / ke.math.distance(coor)
					end
					local ll, n = {[1] = 0}, 12--8
					local ni, tb, t = 1 / n, 0, 0
					for i = 2, n + 1 do
						tb = tb + ni
						ll[i] = ke.shape.beziers.length(bezier, tb, n * 2)
					end
					if (length - ll[n + 1]) > 0.1 then
						return false
					end
					for i = 1, n do
						if length >= ll[i] and length <= ll[i + 1] then
							t = (i - 1) / n + (length - ll[i]) / (ll[i + 1] - ll[i]) * (1 / n)
							break
						end
					end
					return t
				end,
				
				["length2seg"] = function(shp, length)
					local offset, segs, seg, target_length = {[0] = 0}, shp:__seg()
					for i, s in ipairs(segs) do
						offset[i] = offset[i - 1] + s:length()
					end
					local length = math.abs(offset[#offset] - length) < 1 and offset[#offset] or length
					for i = 1, #offset - 1 do
						if length >= offset[i] and length <= offset[i + 1] then
							seg, target_length = segs[i + 1], length - offset[i]
							return seg, target_length
						end
					end
					return false
				end, --{ke.shape.beziers.length2seg(ke.shape.new(ke.shape.rectangle), 40)}
				
				["normal2p"] = function(bezier, t)
					local normal = ke.shape.beziers.tangential2p(bezier, t)
					normal[1], normal[2] = normal[2], -normal[1]
					return normal
				end,
				
				["coefficient"] = function(bezier) --cubic bezier
					local x0, y0, x1, y1, x2, y2, x3, y3 = bezier:unpack()
					local Cx = {[1] = -x0 + 3 * x1 - 3 * x2 + x3, [2] = 3 * x0 - 6 * x1 + 3 * x2, [3] = -3 * x0 + 3 * x1, [4] = x0}
					local Cy = {[1] = -y0 + 3 * y1 - 3 * y2 + y3, [2] = 3 * y0 - 6 * y1 + 3 * y2, [3] = -3 * y0 + 3 * y1, [4] = y0}
					return Cx, Cy
				end, --ke.shape.beziers.coefficient(ke.shape.new(shape.circle).part[1][2])
				
			},
			
			["clipper"] = { --sublibrary
				
				topaths = function(paths)
					--get points from shape
					local paths = type(paths) == "string" and ke.shape.new(paths) or paths
					paths = paths:redraw(2, "bezier")
					local points = {}
					for i, s in ipairs(paths) do
						points[i]= {}
						local k = 1
						for x, y in s.code:gmatch("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)") do
							points[i][k] = {x = tonumber(x) * SCALE_PATHS, y = tonumber(y) * SCALE_PATHS}
							k = k + 1
						end
					end
					return points
				end,
				
				toshape = function(paths)
					--converts the paths struct to shape
					local codes = {}
					for i, path in ipairs(paths) do
						local asscode = ""
						for _, p in ipairs(path) do
							asscode = asscode .. ("l %s %s "):format(p.x / SCALE_PATHS, p.y / SCALE_PATHS)
						end
						codes[i] = asscode:gsub("l", "m", 1)
					end
					local code = table.concat(codes)
					return ke.shape.new(code):__closed()
				end,
				
				boolean = function(subject, clip, operation, filltype)
					local CPP = include("kelibs\\clipper.lua")
					local subject = ke.shape.clipper.topaths(subject)
					local clip = ke.shape.clipper.topaths(clip)
					local cpp = CPP.Clipper()
					cpp:AddPaths(subject, CPP.ClipperLib.PolyType.ptSubject, true)
					cpp:AddPaths(clip, CPP.ClipperLib.PolyType.ptClip, true)
					local ClipType = {
						["intersection"] = 0;
						["union"] = 1;
						["difference"] = 2;
						["xor"] = 3;
					}
					local FillType = {
						["evenodd"] = 0;
						["nonzero"] = 1;
						["positive"] = 2;
						["negative"] = 3;
					}
					local operation = (operation and ClipType[operation]) and ClipType[operation] or "union"
					local filltype = (filltype and FillType[filltype]) and FillType[filltype] or "evenodd"
					cpp:Execute(	--ejecutar operación (unión, intersección, diferencia o xor)
						operation,	-- Tipo de operación
						filltype,	-- Tipo de relleno para subject
						filltype	-- Tipo de relleno para clip
					)--PolyFillType: "pftEvenOdd" = 0, "pftNonZero" = 1, "pftPositive" = 2, "pftNegative" = 3
					local solution = cpp.FinalSolution
					return ke.shape.clipper.toshape(solution)
				end, --ke.shape.clipper.boolean("m 0 0 l 0 50 l 30 50 l 30 0 l 0 0 m 10 10 l 20 10 l 20 40 l 10 40 l 10 10 ", "m -5 20 l -5 30 l 40 30 l 40 20 l -5 20 ", "difference").code
				
			},
			-------------------------------
			
			__type = function(self)
				return ke.shape.__name
			end,
			
			__view = function(self)
				return self.__raw
			end,
			
			new = function(asscode)
				local data = {}
				local code = (type(asscode) == "table" and asscode.code) and asscode.code or asscode
				code = type(code) == "table" and ke.shape.tocode(code) or code
				code = ke.shape.assdraw(code:gsub("c%s?", "")):gsub("nil", "m")
				data.code = code
				local self, proxy = {}
				proxy = { --shp = ke.shape.new(ke.shape.rectangle)
					__get = function(name)
						local _minx, _maxx, _miny, _maxy = math.huge, -math.huge, math.huge, -math.huge
						for x, y in data.code:gmatch("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)") do
							_minx, _miny = math.min(_minx, x), math.min(_miny, y)
							_maxx, _maxy = math.max(_maxx, x), math.max(_maxy, y)
						end
						local values = {}
						values.minx = _minx
						values.miny = _miny
						values.maxx = _maxx
						values.maxy = _maxy
						values.width  = _maxx - _minx																--shape width
						values.height = _maxy - _miny																--shape height
						values.center = _minx + values.width / 2													--center shape ("x")
						values.middle = _miny + values.height / 2													--middle shape ("y")
						values.radius = ke.math.distance(values.width, values.height) / 2							--shape radius
						values.centroid = ke.shape.point.new(_minx + values.width / 2, _miny + values.height / 2)	--shape point center
						--values.seg = name == "seg" and self:__seg() or nil										--shape segments
						values.pnt = name == "pnt" and self:points() or nil											--shape points
						--values.len = name == "len" and self:length() or nil										--shape length (perimeter)
						--values.isclosed = self:__isclosed()														--true or false
						values.n = name == "n" and ke.string.count(data.code, "point") or nil						--total points
						return values[name]
					end,
					
					__index = function(_, key)
						if key == "__raw" then
							return data
						end
						local specials = ke.table.new(
							{
								"n", "minx", "miny", "maxx", "maxy", "width", "height", "center", "middle",
								"radius", "centroid", "seg", "pnt", "len", "isclosed"
							}, true
						)
						if specials[key] then
							return proxy.__get(key)
						end
						return data[key] or ke.shape[key]
					end,
					
					__newindex = function(_, key, value)
						if key == "code" then
							data.code = value
						end
						rawset(data, key, value)
					end,
					
					__ipairs = function(self)
						local shapes = ke.table.new(self.__raw.code:gmatch("m[^m]*"))
						local i = 0
						return function()
							i = i + 1
							if shapes[i] then
								return i, ke.shape.new(shapes[i])
							end
						end
					end,
					
					__add = function(self, xy)
						local dx = type(xy) == "table" and xy[1] or xy or 0
						local dy = type(xy) == "table" and xy[2] or 0
						if type(xy) == "table" and xy.code then
							return self:__concat(xy)
						end --concat the shapes
						return self:__gsub(function(x, y) return x + dx, y + dy end) --move the shape
					end, --ke.shape.new(ke.shape.rectangle) + 7
					
					__sub = function(self, xy)
						local dx = type(xy) == "table" and xy[1] or xy or 0
						local dy = type(xy) == "table" and xy[2] or 0
						return self:__gsub(function(x, y) return x - dx, y - dy end)
					end,
					
					__mul = function(self, xy)
						local rx = type(xy) == "table" and xy[1] or xy or 1
						local ry = type(xy) == "table" and xy[2] or 1
						return self:__gsub(function(x, y) return x * rx, y * ry end)
					end,
					
					__div = function(self, xy)
						local rx = type(xy) == "table" and xy[1] or xy or 1
						local ry = type(xy) == "table" and xy[2] or 1
						return self:__gsub(function(x, y) return x / (rx ~= 0 and rx or 1), y / (ry ~= 0 and ry or 1) end)
					end,
					
					__concat = function(self, other)
						local other = type(other) == "function" and other() or other
						local toconcat = other
						if type(other) == "table" and ke.table.type(other) == "shape" then
							toconcat = other.code
						end
						self.code = ke.shape.new(self.code .. toconcat).code
						return self
					end, --ke.shape.new(ke.shape.circle) .. ke.shape.pixel
					
					__tostring = function(self)
						return self.code
					end, --tostring(ke.shape.new(ke.shape.circle))
					
				}
				setmetatable(self, proxy)
				return self
			end,
			
			clone = function(self)
				return ke.table.copy(self)
			end,--shp = ke.shape.new(ke.shape.rectangle):clone()
			
			["__gsub"] = function(self, filter, aux, count)
				if type(filter) == "string" then
					self.code = self.code:gsub(filter, aux, count)
					return self.code
				end
				local i = ke.math.count()
				--local i, Cx, Cy, Do, Dc, Ao, Ac, Pn, Pk, Mx, My, Mp = ke.math.count()
				self.code = self.code:gsub("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)",
					function(x, y, t)
						Cx = self.center					--coordenada "x" del centro
						Cy = self.middle					--coordenada "y" del centro
						Do = ke.math.distance(x, y)			--distancia del punto al origen
						Dc = ke.math.distance(Cx, Cy, x, y)	--distancia del punto al centro
						Ao = ke.math.angle(0, 0, x, y)		--ángulo del origen al punto
						Ac = ke.math.angle(Cx, Cy, x, y)	--ángulo del centro al punto
						Pn = self.n							--cantidad total de puntos
						Pk = i()							--contador de los puntos
						Mx = (y - self.miny) / self.height	--varianza respecto a "x", Mx = [0, 1]
						My = (x - self.minx) / self.width	--varianza respecto a "y", My = [0, 1]
						Mp = (Pk - 1) / (Pn - 1)			--varianza respecto a los puntos, Mp = [0, 1]
						x, y, t = filter(x, y, t)
						return ("%s %s"):format(ke.math.round(x, ROUND_NUM), ke.math.round(y, ROUND_NUM))
					end
				)
				return self
			end, --ke.shape.new(ke.shape.rectangle):__gsub(function(x, y) y = y - 7 return x, y end)
			
			["__del"] = function(self, delete, initial)
				--removes the point(s) indicated in a shape
				local points, delete = self:clone():points(), delete or 0
				local del1 = type(delete) == "table" and delete[1] or delete
				local del2 = type(delete) == "table" and delete[2] or del1
				del1 = del1 < 0 and #points + del1 + 1 or del1
				del2 = del2 < 0 and #points + del2 + 1 or del2
				points = ke.table.get(points, "delete", {{del1, del2}})
				points[1].t = initial and "m" or points[1].t
				self.code = ke.shape.new(points).code
				return self
			end, --ke.shape.new(ke.shape.rectangle):__del({4, 5}).code
			
			["__rep"] = function(self, n)
				local n = type(n) == "function" and n() or n
				n = type(n) ~= "number" and 1 or math.ceil(math.abs(n) > 0 and math.abs(n) or 1)
				local newcode = self.code:rep(n)
				self.code = newcode
				return self
			end, --ke.shape.new(ke.shape.rectangle):__rep(3).code
			
			["__inv"] = function(self)
				local shapes = ke.table.new()
				for i, s in ipairs(self) do
					local segs = ke.shape.tract(s.code)("inverse")
					for k, seg in ipairs(segs) do
						local aux = ke.table.new(seg:gmatch("%-?%d[%.%d]*%s+%-?%d[%.%d]*"))("inverse")
						local letter = seg:match("[mbl]")
						aux:insert(letter, 2)
						segs[k] = table.concat(aux, " ")
						segs[k] = k > 1 and segs[k]:match("[mlb][^mlb]*") or segs[k]
					end
					shapes[i] = "m " .. table.concat(segs, " "):sub(1, -2)
				end
				local newcode = table.concat(shapes("inverse"), " ")
				self.code = newcode
				return self
			end, --ke.shape.new(ke.shape.circle):__inv()
			
			["__red"] = function(self, round)
				--remove collinear points shape
				local P = self:points()
				local function get_reduce(P1, P2, P3)
					return ke.math.equality(P1:angle(P2), P1:angle(P3), 2)
				end
				local newpoints = {P[1]}
				for i = 2, #P - 1 do
					newpoints[#newpoints + 1] = not (P[i].t == "l" and P[i + 1].t == "l" and get_reduce(P[i - 1], P[i], P[i + 1]))
					and P[i] or nil
				end
				newpoints[#newpoints + 1] = P[#P]
				self.code = ke.shape.new(newpoints).code
				return self
			end,
			
			["__seg"] = function(self)
				local segments, tracts = {}, self:tract()
				for i = 1, #tracts do
					segments[i] = ke.shape.segment.new(tracts[i])
				end
				return segments
			end, --ke.shape.new(ke.shape.circle):__seg()
			
			["__call"] = function(self, tract, section)
				return type(tract) == "function" and self:filter(tract) or self:redraw(tract, section)
			end,
			
			["__area"] = function(self)
				--if the area is negative, the shape is drawn unclockwise
				--if area == 0, then either the points are collinear or the edges intersect
				local area = 0
				for _, s in ipairs(self) do
					local sum1, sum2, pnt, n = 0, 0, s:points(), s.n
					for i = 1, n do
						sum1 = sum1 + (pnt[i].x * pnt[i % n + 1].y)
						sum2 = sum2 + (pnt[i].y * pnt[i % n + 1].x)
					end
					area = area + (sum1 - sum2) / 2
				end
				return ke.math.round(area, ROUND_NUM)
			end, --ke.shape.new(ke.shape.rectangle):__area()
			
			["__isclosed"] = function(self)
				for i, s in ipairs(self) do
					local points = s:points()
					if points[1] ~= points[#points] then
						return false
					end
				end
				return true
			end,
			
			["__closed"] = function(self)
				local newcode, addfirst = "", ""
				for i, s in ipairs(self) do
					local first = s.code:match("m (%-?%d[%.%d]* %-?%d[%.%d]* )")
					local last = s.code:match("(%-?%d[%.%d]* %-?%d[%.%d]* )$")
					addfirst = first ~= last and first or ""
					newcode = newcode .. s.code .. addfirst
				end
				self.code = newcode
				return self
			end, --ke.shape.new("m 0 0 l 0 20 l 20 20 l 20 0 m 30 20 l 30 0 l 50 0 l 50 20 "):__closed().code
			
			["__unclosed"] = function(self)
				local newcode = ""
				for i, s in ipairs(self) do
					local first = s.code:match("m (%-?%d[%.%d]* %-?%d[%.%d]* )")
					local last = s.code:match("(%-?%d[%.%d]* %-?%d[%.%d]* )$")
					if first == last then
						s.code = s.code:gsub("%-?%d[%.%d]* %-?%d[%.%d]* $", ""):gsub("[lm] $", "")
					end
					newcode = newcode .. s.code
				end
				self.code = newcode
				return self
			end, --ke.shape.new(ke.shape.rectangle):__unclosed()
			
			["isclockwise"] = function(self)
				return self:__area() > 0
			end,
			
			["clockwise"] = function(self)
				local newcode = self:__area() <= 0 and self:__inv().code or self.code
				self.code = newcode
				return self
			end, --ke.shape.new("m 0 0 l 0 20 l 20 20 l 20 0 "):clockwise()
			
			["unclockwise"] = function(self)
				local self = self:__copy()
				return self:__area() > 0 and self:__inv() or self
			end, --ke.shape.new("m 0 0 l 0 20 l 20 20 l 20 0 "):unclockwise()
			
			assdraw = function(asscode)
				if type(asscode) == "table" and asscode.code then
					return asscode.code
				end
				local code = asscode:match("m%s+%-?%d[%.%-%d blm]*") or asscode
				if asscode:match("%-?%d[%. %d]*,%s*%-?%d[%. %d]*,%s*%-?%d[%. %d]*,%s*%-?%d[%. %d]*") then
					local x1, y1, x2, y2 = asscode:match( "(%-?%d[%. %d]*),%s*(%-?%d[%. %d]*),%s*(%-?%d[%. %d]*),%s*(%-?%d[%. %d]*)")
					code = ("m %s %s l %s %s l %s %s l %s %s "):format(x1, y1, x1, y2, x2, y2, x2, y1)
				end
				code = code:gsub("([mbl]^*)(%s+%-?%d[%.%- %d]*)",
					function(bl, numbers)
						local k, i = ke.math.count(), bl == "b" and 6 or 2
						return bl .. numbers:gsub("%-?%d[%.%d]*",
							function(num)
								local num = ke.math.round(num, ROUND_NUM)
								return k() % i == 0 and num .. " " .. bl or num
							end
						):gsub(" +", " "):sub(1, -3)
					end
				)
				return code
			end,
			
			points = function(self, coors)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local pnt = ke.table.new()
				for t, nums in self.code:gmatch("([mbl]^*)(%s+%-?%d[%. %-%d]*)") do
					for x, y in nums:gmatch("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)") do
						pnt:insert(ke.shape.point.new(x, y, t))
					end
				end
				return not coors and pnt or ke.shape.point.group(pnt, "coors")
			end,
			
			tocode = function(points)
				if type(points) == "table" and (points.coorsx or points.coorsy) then --coors to points
					local coorsx = points.coorsx or 0
					local coorsy = points.coorsy or 0
					points = ke.table.new()
					if type(coorsx) == "table" then
						for i, x in ipairs(coorsx) do
							local y = type(coorsy) == "table" and coorsy[i] or coorsy
							points:insert(ke.shape.point.new(x, y, "l"))
						end
					elseif type(coorsy) == "table" then
						for i, y in ipairs(coorsy) do
							local x = type(coorsx) == "table" and coorsx[i] or coorsx
							points:insert(ke.shape.point.new(x, y, "l"))
						end
					end
					points[1].t = "m"
				end --ke.shape.new({coorsx = {4, -5, 1, 0, 2}})
				if ke.table.type(points[1]) == "segment" then --segments to points
					local aux = {}
					for _, s in ipairs(points) do
						for _, p in ipairs(s) do
							p.t = s.t
							table.insert(aux, p)
						end
					end
					points = aux
				end
				local code = ("%s %s %s "):format(points[1].t, points[1].x, points[1].y)
				for i = 2, #points do
					local letter = points[i].t == points[i - 1].t and "" or points[i].t
					code = code .. ("%s %s %s "):format(letter, points[i].x, points[i].y)
				end
				code = code:gsub("%s+", " ")
				return code
			end,
			
			tract = function(self)
				local code = (type(self) == "table" and self.code) and self.code or self
				local tracts, i = ke.table.new(), ke.math.count()
				for seg in code:gmatch("[mlb][^mlb]*") do
					local k = i()
					if k > 1 and not seg:match("m") then
						seg = tracts[k - 1]:match("%-?%d[%.%d]*%s+%-?%d[%.%d]*%s?$") .. seg
					end
					tracts:insert(seg)
				end
				return tracts
			end, --ke.shape.new(ke.shape.circle):tract()
			
			bounding = function(self)
				--min and max values in thne bounding box
				return self.minx, self.miny, self.maxx, self.maxy
			end,
			
			box = function(self)
				--bounding points: lt, lb, rb, rt
				local x0, y0, x1, y1 = self:bounding()
				local p0, p1 = ke.shape.point.new(x0, y0), ke.shape.point.new(x0, y1)
				local p2, p3 = ke.shape.point.new(x1, y1), ke.shape.point.new(x1, y0)
				return p0, p1, p2, p3
			end,
			
			round = function(self, n)
				self.code = self.code:gsub("%-?%d[%.%d]*", function(num) return ke.math.round(num, n or 0) end)
				return self
			end,
			
			redraw = function(self, tract, section)
				--divides the segments of the shape into segments of specified length
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local segs = self:__seg()
				local tract = tract or 2
				local section = section or "all"
				for i = 1, #segs do
					if section ~= "bezier" then	--"line" or all
						segs[i] = segs[i].t ~= "l" and segs[i] or segs[i]:split(tract)
					end
					if section ~= "line" then	--"bezier" or all
						segs[i] = segs[i].t ~= "b" and segs[i] or segs[i]:split(tract)
					end
				end
				self.code = ke.shape.new(segs).code
				return self
			end, --ke.shape.new("m 10 0 b 0 0 0 10 10 10 l 30 10 b 40 10 40 0 30 0 l 10 0 "):redraw(4, "line"):round().code
			
			length = function(self)
				--total shape perimeter
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local length, segs = 0, self:__seg()
				for _, seg in ipairs(segs) do
					length = length + seg:length()
				end
				return ke.math.round(length, ROUND_NUM)
			end, --ke.shape.length(ke.shape.circle)
			
			displace = function(self, dx, dy, mode)
				--two-dimensional displacement of the shape
				--> ke.shape.displace(self, dx, dy)
				--> ke.shape.displace(self, "origin"), ke.shape.displace(self, "incenter")
				--> ke.shape.displace(self, Px, Py, "center")	--> move respect to center shape
				--> ke.shape.displace(self, Px, Py, "first")	--> move respect to first point shape
				--> ke.shape.displace(self, Px, Py, "last")		--> move respect to last point shape
				--> ke.shape.displace(self, P1, P2, "point")	--> move respect to one point of shape
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local dx = type(dx) == "function" and dx() or dx or 0
				local dy = type(dy) == "function" and dy() or dy or 0
				local P1, P2 = dx, dy
				dy = (type(dx) == "table"  and dx.x) and dx.y or dy
				dx = (type(dx) == "table"  and dx.x) and dx.x or dx						--respecto a las coordenadas de un punto
				dy = (type(dx) == "table") and ke.math.polar(dx[1], dx[2], "y") or dy	--movimiento polar, indicando ángulo y radio
				dx = (type(dx) == "table") and ke.math.polar(dx[1], dx[2], "x") or dx
				if type(dx) == "string" or type(dy) == "string" or mode then
					dx, dy, mode = P1 == "origin"   and 0 or dx, P1 == "origin"   and 0 or dy, P1 == "origin"   and "origin" or mode
					dx, dy, mode = P1 == "incenter" and 0 or dx, P1 == "incenter" and 0 or dy, P1 == "incenter" and "center" or mode
					local P = self:points()
					dx = mode == "origin" and dx - self.minx							-->ke.shape.displace(self, "origin")
					or (mode == "center" and dx - self.minx - 0.5 * self.width)			-->ke.shape.displace(self, 0, 0, "center")
					or (mode == "first" and dx - P[1].x)								--coordenadas del primer punto
					or (mode == "last" and dx - P[#P].x) or dx							--coordenadas del último punto
					dy = mode == "origin" and dy - self.miny
					or (mode == "center" and dy - self.miny - 0.5 * self.height)
					or (mode == "first" and dy - P[1].y)
					or (mode == "last" and dy - P[#P].y) or dy
					if mode == "point" then
						local x1, y1, x2, y2 = 0, 0, 0, 0
						x1 = (type(P1) == "table" and P1.x and P1.y) and P1.x or (type(P1) == "table" and P1[1] or x1)
						y1 = (type(P1) == "table" and P1.x and P1.y) and P1.y or (type(P1) == "table" and P1[2] or y1)
						x2 = (type(P2) == "table" and P2.x and P2.y) and P2.x or (type(P2) == "table" and P2[1] or x2)
						y2 = (type(P2) == "table" and P2.x and P2.y) and P2.y or (type(P2) == "table" and P2[2] or y2)
						x1 = (type(P1) == "number") and (P[P1].x or 0) or x1
						y1 = (type(P1) == "number") and (P[P1].y or 0) or y1
						x2 = (type(P2) == "number") and (P[P2].x or 0) or x2
						y2 = (type(P2) == "number") and (P[P2].y or 0) or y2
						dx, dy = x2 - x1, y2 - y1
					end --ke.shape.displace(ke.shape.circle, 1, {20, 20}, "point").code
				end
				return self + {dx, dy}
			end, --ke.shape.displace(ke.shape.circle, 20, 10).code
			
			ratio = function(self, xratio, yratio, mode)
				--modifies the size of the shape with respect to a proportion (Ratio)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local xratio = type(xratio) == "function" and xratio() or xratio
				local yratio = type(yratio) == "function" and yratio() or yratio
				local mode = type(mode) == "function" and mode() or mode
				local x0, y0, x1, y1 = self:bounding()
				local wx, hy = self.width, self.height
				local P, rx = self:points(), xratio or 1
				if type(xratio) == "table" then
					rx = (xratio[1] or wx) / wx
					if #xratio == 2 then --rx depends on the distance between two points or a point and the origin
						xratio[1] = not xratio[1] and {P[1], P[#P]} or xratio[1]
						rx = xratio[2] / ke.math.distance(xratio[1])
						rx = ke.math.distance(xratio[1]) == 0 and xratio[2] / wx or rx
					end
				end
				local ry = yratio or rx
				if yratio and type(yratio) == "table" then
					ry = yratio[1] / hy
					rx = xratio == nil and ry or rx
				end
				newself = self:__gsub(function(x, y) return x * rx, y * ry end)
				local get_modes = {--move the shape to the notable positions of the original shape
					[01] = function(s) return s:displace("origin"):displace(x0, y1 - newself.height) end,
					[02] = function(s) return s:displace("origin"):displace(x0 + 0.5 * wx - 0.5 * newself.width, y1 - newself.height) end,
					[03] = function(s) return s:displace("origin"):displace(x1 - newself.width, y1 - newself.height) end,
					[04] = function(s) return s:displace("origin"):displace(x0, y0 + 0.5 * hy - 0.5 * newself.height) end,
					[05] = function(s) return s:displace("origin"):displace(x0 + 0.5 * wx - 0.5 * newself.width, y0 + 0.5 * hy - 0.5 * newself.height) end,
					[06] = function(s) return s:displace("origin"):displace(x1 - newself.width, y0 + 0.5 * hy - 0.5 * newself.height) end,
					[07] = function(s) return s:displace("origin"):displace(x0, y0) end,
					[08] = function(s) return s:displace("origin"):displace(x0 + 0.5 * wx - 0.5 * newself.width, y0) end,
					[09] = function(s) return s:displace("origin"):displace(x1 - newself.width, y0) end,
					[10] = function(s) return s:displace(0, 0, "first"):displace(P[1].x, P[1].y, "first") end,
					[11] = function(s) return s:displace(P[#P].x, P[#P].y, "last") end,
					[12] = function(s) return s:displace("incenter") end--(0,0)
				}
				return mode and get_modes[mode](newself) or newself
			end, --ke.shape.ratio(ke.shape.rectangle, 0.4, nil, 5).code
			
			size = function(self, xsize, ysize, mode)
				--modifies the size of the shape with respect to certain values
				--if xsize is an array, xsize[1] will be added to the width  of the shape
				--if ysize is an array, ysize[1] will be added to the height of the shape
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local xsize = type(xsize) == "function" and xsize() or xsize or self.width
				local ysize = type(ysize) == "function" and ysize() or ysize or xsize
				local mode = type(mode) == "function" and mode() or mode
				local xrat = type(xsize) == "table" and self.width  + xsize[1] or xsize
				local yrat = type(ysize) == "table" and self.height + ysize[1] or ysize
				xrat = yrat == 0 and {xrat} or (xrat ~= 0 and (self.width  > 0 and xrat / self.width  or 1)) or nil
				yrat = xrat == 0 and {yrat} or (yrat ~= 0 and (self.height > 0 and yrat / self.height or 1)) or nil
				--x = 0: "x" is proportionally modified depending on how "y" is modified
				--y = 0: "y" is proportionally modified depending on how "x" is modified
				return self:ratio(xrat, yrat, mode) --ke.shape.size(ke.shape.rectangle, 120, 0).code
			end, --ke.shape.size(ke.shape.rectangle, 120, 45).code
			
			glue = function(self, other, mode, split)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local split = type(split) == "function" and split() or split or 2
				local mode = mode or 1
				self = self:redraw(split) --shape
				local other  = ke.shape.new(other:match("m%s+%-?%d[%.%-%d lb]*")):redraw(3)
				local ratio  = ke.math.round(self.width / other:length(), ROUND_NUM)
				local filter = type(mode) == "function" and mode or nil
				filter = other:length() < self.width and function(x, y) return x, y end		--default
				or (mode == 1 and function(x, y) return (1 - ratio) / 2 + ratio * x, y end)	--centrado
				or (mode == 2 and function(x, y) return ratio * x, y end)					--de inicio a fin
				or (mode == 3 and function(x, y) return 1 - ratio + ratio * x, y end)		--de fin a inicio
				or (mode == 4 and function(x, y) return x, y end) or filter					--justificado a lo largo
				local segments, length, n, l, last = {}, 0, 0
				other = other:__gsub(
					function(x, y)
						if last then
							l = {last[1], last[2], x - last[1], y - last[2], ke.math.distance(x - last[1], y - last[2])}
							if l[5] > 0 then
								n = n + 1
								segments[n] = l
								length = length + l[5]
							end
						end
						last = {x, y}
						return x, y
					end
				)
				if n > 0 then
					local curve = 0
					for _, l in ipairs(segments) do
						l[6] = curve / length
						curve = curve + l[5]
						l[7] = curve / length
					end
					local x0, y0, x1, y1 = self:bounding()
					if x0 and x1 > x0 then
						local ortho = function(x1, y1, z1, x2, y2, z2)
							return y1 * z2 - z1 * y2, z1 * x2 - x1 * z2, x1 * y2 - y1 * x2
						end
						local stretch = function(x, y, length)
							local  curve = (x * x + y * y) ^ 0.5
							return curve == 0 and 0 or x * length / curve, curve == 0 and 0 or y * length / curve
						end
						local pos, ox, oy, px, py, dx, dy
						return self:__gsub(
							function(x, y)
								px, py = (x - x0) / self.width, y - y1
								dx, dy = filter(px, py)
								px, py = math.max(0, math.min(dx, 1)), dy
								for i = 1, n do
									l = segments[i]
									if px >= l[6] and px <= l[7] then
										pos = (px - l[6]) / (l[7] - l[6])
										ox, oy = ortho(l[3], l[4], 0, 0, 0, -1)
										ox, oy = stretch(ox, oy, py)
										return l[1] + pos * l[3] + ox, l[2] + pos * l[4] + oy
									end
								end
							end
						)
					end
				end
			end, --ke.shape.glue(ke.shape.size(ke.shape.rectangle, 240, 20), ke.shape.circle).code
			
			rotate = function(self, angle, org)
				--rotate the shape about the "z" axis with a predetermined point of origin
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local org = type(org) == "function" and org() or org or {x = 0, y = 0}
				local points = self:points()
				local angle = angle or 0
				local cx, cy, ang = 0, 0, angle
				org = org == "center" and ke.shape.point.new(self.center, self.middle) or org
				if type(org) == "number" then
					local P = points[math.ceil(org)] or {x = 0, y = 0}
					org = {x = P.x, y = P.y}
				end --ke.shape.rotate(ke.shape.rectangle, -45, 2):round().code
				cx, cy = org.x, org.y
				if type(angle) == "table" then
					--ang depende del ángulo entre dos puntos o un punto y el origen
					angle[1] = not angle[1] and {points[1], points[#points]} or angle[1]
					ang = (angle[2] or 0) - ke.math.angle(angle[1])
				end --ke.shape.rotate(ke.shape.rectangle, -45, "center").code
				local filter_rotate = function(x, y)
					local new_ang = ke.math.angle(cx, cy, x, y)
					local new_rad = ke.math.distance(cx, cy, x, y)
					local angle = type(ang) == "function" and ang(x, y) or ang
					x = cx + ke.math.polar(new_ang + angle, new_rad, "x")
					y = cy + ke.math.polar(new_ang + angle, new_rad, "y")
					return x, y --ke.shape.rotate(ke.shape.redraw(ke.shape.rectangle, 5), function(x, y) return x * y end).code
				end --ke.shape.rotate(ke.shape.redraw(ke.shape.rectangle, 5), function(x, y) return tag.ipol(Mp, 0, 60) end)
				return self:__gsub(filter_rotate) --ke.shape.rotate(ke.shape.rectangle, -45).code
			end,
			
			reflect = function(self, axis, relative)
				--makes a reflection of the shape with respect to any of the 2 axes, or to the line y = x
				--It can also be reflect about the lines x = relative or y = relative
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local axis = type(axis) == "function" and axis() or axis
				local relative = type(relative) == "function" and relative() or relative or 0
				relative, axis = not axis and self.maxx or relative, axis or "y"
				local filter_reflect = function(x, y)
					x = axis == "x" and x or ((axis == "y" or axis == nil) and relative - x) or -relative - x
					y = axis == "x" and relative - y or ((axis == "y" or axis == nil) and y) or -relative - y
					return x, y
				end
				return self:__gsub(filter_reflect)
			end, --ke.shape.reflect("m 0 0 l 0 50 l 30 50 l 30 30 ", "y").code
			
			oblique = function(self, pixels, t)
				--shape modifies respect to its bounding box
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local cx, cy = 0.4 * self.width, 0.4 * self.height
				local pxs, t = pixels or cx, t or 1
				local fxbox = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
				fxbox = type(pxs) == "number" and {{pxs, 0}, {0, 0}, {0, 0}, {pxs, 0}} or fxbox
				if type(pxs) == "table" and (pxs.x or pxs.y) then
					local cx, cy = pxs.x or {0, 0, 0, 0}, pxs.y or {0, 0, 0, 0}
					fxbox = {{cx[1] or 0, cy[1] or 0}, {cx[2] or 0, cy[2] or 0}, {cx[3] or 0, cy[3] or 0}, {cx[4] or 0, cy[4] or 0}}
				elseif type(pxs) == "string" and pxs == "random" then
					fxbox = ke.table.new(4, function(i) return {ke.math.rand(-cx, cx), ke.math.rand(-cy, cy)} end)
				end
				local P0, P1, P2, P3 = self:box()
				P0, P1, P2, P3 = P0 + fxbox[1], P1 + fxbox[2], P2 + fxbox[3], P3 + fxbox[4]
				local oblique_filter = function(x, y)
					local top, bottom = P0:ipol(P3, My), P1:ipol(P2, My)
					local newp = top:ipol(bottom, Mx)
					x, y = x + (newp.x - x) * t, y + (newp.y - y) * t
					return x, y
				end
				return self:__gsub(oblique_filter)
			end, --ke.shape.oblique("m 12 8 l 12 25 l 0 25 l 0 34 l 49 34 l 49 17 l 37 17 l 37 0 l 30 0 l 30 20 l 22 20 l 22 8 l 12 8 ", 20).code
			
			roundout = function(self, radius, mode)
				--rounds the shape corners
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local get_t = function(p0, p1, p2, radius)
					local d1, d2 = p0:distance(p1), p1:distance(p2)
					local dmin = math.min(d1, d2) == 0 and math.max(d1, d2) or math.min(d1, d2)
					local radius = radius > 0.4 * dmin and 0.4 * dmin or radius
					return radius / d1, radius / d2
				end
				local radius, negative = radius or 10, false
				if radius < 0 then
					radius, negative = -1 * radius, true
				end
				local mode = mode or "round" --or "bevel"
				local result = ke.table.new()
				for _, s in ipairs(self) do
					local points = s:points()
					local closed = s:__isclosed()
					if closed then
						local t0, t1 = get_t(points[#points - 1], points[1], points[2], radius)
						result:insert(points[1]:ipol(points[2], t1))
					else
						result:insert(points[1])
					end
					local n = #points
					for i, p in ipairs(points) do
						if p.t == "l" then
							if i > 1 and i <= n - (closed and 0 or 1) then
								local pnext = i == n and points[2] or points[i + 1]
								local t0, t1 = get_t(points[i - 1], p, pnext, radius)
								if mode == "bevel" then
									local p1, p2 = p:ipol(points[i - 1], t0), p:ipol(pnext, t1)
									result:insert({p1, p2}, nil, true)
								else --mode = "round"
									local p1, p2 = p:ipol(points[i - 1], t0), p:ipol(points[i - 1], 0.42 * t0)
									local p3, p4 = p:ipol(pnext, 0.42 * t1), p:ipol(pnext, t1)
									if negative then
										p2 = p2:reflect(p1, p4)
										p3 = p3:reflect(p1, p4)
									end
									p2.t, p3.t, p4.t = "b", "b", "b"
									result:insert({p1, p2, p3, p4}, nil, true)
								end
							end
						elseif p.t ~= "m" then
							result:insert(p)
						end
					end
					if not closed then
						result:insert(points[#points])
					end
				end
				self.code = ke.shape.new(result).code
				return self
			end, --ke.shape.roundout(ke.shape.rectangle, 20).code
			
			filter = function(self, split, ...)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				self = (split and split > 0) and self:redraw(split) or self
				local filters = (... and type(...) == "table") and ... or {...}
				filters[1] = #filters == 0 and function(x, y) return x, y end or filters[1]
				for i = 1, #filters do
					if type(filters[i]) == "table" or type(filters[i]) == "string" then
						local shp = type(filters[i]) == "table" and filters[i][1] or filters[i]
						local mode  = type(filters[i]) == "table" and filters[i][2] or nil
						self = self:glue(shp, mode)
					else
						self = self:__gsub(filters[i])
					end
				end --ke.shape.filter(ke.shape.rectangle, 4, function(x, y) x = x + 8 * math.sin(Mx * 4 * math.pi) return x, y end).code
				return self:__red()
			end, --ke.shape.filter(ke.shape.rectangle, 4, function(x, y) x = x + ke.math.rand(5) y = y + ke.math.rand(5) return x, y end).code
			
			filtergroup = function(self, filter)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				if type(self) == "table" and not self.code then
					return ke.table.recursive(self, ke.shape.filtergroup, self)
				end
				local code = ""
				local n = ke.string.count(self.code, "m")
				for i, s in ipairs(self) do
					code = code .. filter(i, n, s, self).code
				end
				self.code = code
				return self
				--ke.shape.new("m 50 0 l 50 20 l 70 20 l 70 0 "):__rep(12):filtergroup(function(i, n, s, self) return s:rotate(30 * i, {x = 0, y = self.middle}) end)
			end,
			
			multi1 = function(size, px)
				--returns concentric square shapes
				local size = type(size) == "function" and size() or size or 100
				local px = px or 4
				local shpw, pxi, px1, i = 0, 0, 0, 1
				px = type(px) == "number" and {px} or px
				px1 = type(px) == "table" and px[1] or (type(px) == "function" and px() or px1)
				shpw = px1
				local shp = ("m 0 0 l 0 %s l %s %s l %s 0 l 0 0 "):format(px1, px1, px1, px1)
				while 2 * shpw < size do
					pxi = type(px) == "table" and px[i % #px + 1] or (type(px) == "function" and px(i) or pxi)
					shpw = shpw + (type(pxi) == "table" and pxi[1] or pxi)
					if type(pxi) == "number" then
						shp = shp .. ("m %s %s l %s %s l %s %s l %s %s l %s %s l %s %s l %s %s l %s %s l %s %s l %s %s "):format(
							-shpw + px1, -shpw + px1, -shpw + px1, shpw, shpw, shpw, shpw, -shpw + px1, -shpw + px1,
							-shpw + px1, -shpw + px1 + pxi, -shpw + px1 + pxi, shpw - pxi, -shpw + px1 + pxi, shpw - pxi,
							shpw - pxi, -shpw + px1 + pxi, shpw - pxi, -shpw + px1 + pxi, -shpw + px1 + pxi
						)
					end
					i = i + 1
				end
				return ke.shape.new(shp):displace("origin")
			end, --ke.shape.multi1(100, {10, {4}}).code
			
			multi2 = function(width, height, pixel)
				--create diagonal shapes inside a rectangle with given measurements
				local width = type(width) == "function" and width() or width or 70
				local height = type(height) == "function" and height() or height or 50
				local pixel = type(pixel) == "function" and pixel() or pixel or 6
				pixel = type(pixel) == "number" and {pixel} or pixel
				local dimension = height > width and {x = height, y = width} or {x = width, y = height}
				local i, pxi = 1, 0
				local shp = ("m 0 0 l 0 %s l %s 0 l 0 0 l 0 0 "):format(pixel[1], pixel[1])
				local dy = pixel[1]
				while dy < dimension.y do
					pxi = type(pixel) == "table" and pixel[i % #pixel + 1] or 0
					dy = dy + ((type(pxi) == "table") and pxi[1] or pxi)
					if type(pxi) == "number" then
						shp = shp .. ("m 0 %s l 0 %s l %s 0 l %s 0 l 0 %s "):format(dy - pxi, dy, dy, dy - pxi, dy - pxi)
					end
					i = i + 1
				end
				local dx, shp_y = dy, dy
				while dx < dimension.x do
					pxi = type(pixel) == "table" and pixel[i % #pixel + 1] or 0
					dx = dx + ((type(pxi) == "table") and pxi[1] or pxi)
					if type(pxi) == "number" then
						shp = shp .. ("m %s %s l %s %s l %s 0 l %s 0 l %s %s "):format(
							dx - shp_y - pxi, shp_y, dx - shp_y, shp_y, dx, dx - pxi, dx - shp_y - pxi, shp_y
						)
					end
					i = i + 1
				end
				local shp_x = 0
				while shp_x < shp_y do
					pxi = type(pixel) == "table" and pixel[i % #pixel + 1] or 0
					shp_x = shp_x + ((type(pxi) == "table") and pxi[1] or pxi)
					if type(pxi) == "number" and shp_x <= shp_y then
						shp = shp .. ("m %s %s l %s %s l %s %s l %s %s l %s %s "):format(
							dx - shp_y + shp_x - pxi, shp_y, dx - shp_y + shp_x, shp_y, dx,
							shp_x, dx, shp_x - pxi, dx - shp_y + shp_x - pxi, shp_y
						)
					end
					i = i + 1
				end
				shp = ke.shape.new(shp)
				shp = height > width and shp:rotate(-90):reflect() or shp
				return shp
			end, --"{\\p1}" .. ke.shape.multi2(36, 94, {10, {2}, 5, {3}}).code
			
			multi3 = function(self, size, bord)
				--if it is not put "self", it returns concentric circles, or concentric shapes of the one that has been entered
				local size = type(size) == "function" and size() or size or 100
				local bord = type(bord) == "function" and bord() or bord or 4
				local self = type(self) == "function" and self() or self or ke.shape.circle
				self = type(self) == "string" and ke.shape.new(self) or self
				bord = type(bord) == "number" and {bord} or bord
				local i, shp1, shp2, scon = 1
				local smax, bi = bord[1], 0
				size = (size == "default" or size == nil) and 100 or size
				local shp = self:size(bord[1]):displace("incenter")
				while smax <= size do
					bi = type(bord) == "table" and bord[i % #bord + 1] or bi
					smax = smax + 2 * ((type(bi) == "table") and bi[1] or bi)
					if type(bi) == "number" then
						shp1 = ke.shape.size(self.code, smax):displace("incenter")
						shp2 = ke.shape.size(self.code, smax - 2 * bi):__inv():displace("incenter")
						scon = shp1.code .. shp2.code:gsub("m", "l", 1)
						shp = shp .. scon
					end
					i = i + 1
				end
				return shp:displace("origin")
			end, --"{\\p1}" .. ke.shape.multi3(ke.shape.rectangle, 100, {8, {5}}).code
			
			multi4 = function(size, loop1, loop2, n)
				--returns a regular polygon of loop1 sides, with an array of loop2. n is the number of arrangements taken into account
				local size = type(size) == "function" and size() or size or 64
				local loop1 = ke.math.round(math.abs(type(loop1) == "function" and loop1() or loop1 or 6))
				local loop2 = ke.math.round(math.abs(type(loop2) == "function" and loop2() or loop2 or 1))
				local n = ke.math.round(math.abs(type(n) == "function" and n() or n or 25))
				local sizer = 2 * math.ceil(size / 2)
				local pn = sizer / 2
				loop1 = loop1 < 3 and 3 or loop1
				loop2 = loop2 <= 0 and 1 or loop2
				local px = ke.math.round(0.5 * sizer / loop2)
				local function multi40(size40, loop40, px40)
					local size40 = 2 * math.ceil(size40 / 2)
					px40 = px40 >= size40 / 2 and size40 / 2 or px40
					local angle = 360 / loop40
					local shapes = {}
					for i = 1, ke.math.round(360 / angle) do
						shapes[#shapes + 1] = ("m %s %s l %s %s l %s %s l %s %s "):format(
							ke.math.polar(angle * (i - 0), size40 / 2 - px40, "x"), ke.math.polar(angle * (i - 0), size40 / 2 - px40, "y"),
							ke.math.polar(angle * (i - 0), size40 / 2, "x"), ke.math.polar(angle * (i - 0), size40 / 2, "y"),
							ke.math.polar(angle * (i - 1), size40 / 2, "x"), ke.math.polar(angle * (i - 1), size40 / 2, "y"),
							ke.math.polar(angle * (i - 1), size40 / 2 - px40, "x"), ke.math.polar(angle * (i - 1), size40 / 2 - px40, "y")
						)
					end
					return table.concat(shapes)
				end
				local shp, i = "", 0
				while pn > 0 and i < n do
					shp = shp .. multi40(pn * 2, loop1, px)
					pn = pn - px
					i = i + 1
				end
				shp = ke.shape.new(shp):displace("origin")
				return loop1 % 2 == 1 and shp:rotate(((-1) ^ ((loop1 - 1) / 2)) * 90 / loop1):displace("origin") or shp
			end, --ke.shape.multi4(100, 6, 4, 3).code
			
			multi5 = function(self, width, height, dxy)
				--returns a rectangular array of the entered shapes
				local shapes = self or ke.shape.new(ke.shape.rectangle):size(8)
				shapes = type(shapes) == "function" and shapes() or shapes
				shapes = type(shapes) == "string" and ke.shape.new(shapes) or shapes
				local aux = not shapes.code and ke.table.new(#shapes, function(i) return ke.shape.new(shapes[i]) end) or nil
				shapes = aux or {shapes}
				local width = type(width) == "function" and width() or width or 60
				local height = type(height) == "function" and height() or height or 50
				local dxy = type(dxy) == "function" and dxy() or dxy or {0, 0}
				local shp, shpt = {}, ke.table.new(#shapes, {})
				local widths  = ke.table.new(#shapes, function(i) return shapes[i].width end)
				local heights = ke.table.new(#shapes, function(i) return shapes[i].height end)
				local wmax, hmax = widths("max"), heights("max")
				for i = 1, #shapes do
					for k = 1, #shapes do
						shpt[i][k] = shapes[(k - i) % #shapes + 1]:displace("incenter"):displace((k - 1) * wmax, (i - #shapes) * hmax).code
					end
					shpt[i] = table.concat(shpt[i])
				end --ke.shape.multi5({"m 0 0 l 0 10 l 10 10 l 10 0 ", "m 0 10 l 10 10 l 5 0 "}).code
				shp = ke.shape.new(table.concat(shpt)):displace("origin")
				local dis_xy = type(dxy) == "number" and {dxy, 0} or dxy
				local length_H = math.ceil(width / (shp.width + dis_xy[1]))
				local length_V = math.ceil(height / (shp.height + dis_xy[2]))
				return shp:array({length_H, length_V}, "array", dis_xy)
			end, --ke.shape.multi5()
			
			multi6 = function(size, bord, length)
				--returns the perimeter of a rectangle made up of individual rectangles
				local size = type(size) == "function" and size() or size or 104
				local bord = type(bord) == "function" and bord() or bord or 4
				local length = type(length) == "function" and length() or length or 20
				local xsize = type(size) == "table" and size[1] or size
				local ysize = type(size) == "table" and size[2] or size
				local spacex = type(bord) == "table" and bord[2] or 0
				bord = type(bord) == "table" and bord[1] or bord
				local xloop = math.ceil((xsize - bord) / (length + spacex))
				local yloop = math.ceil((ysize - bord) / (length + spacex))
				xsize, ysize = xloop * (length + spacex) + bord - spacex, yloop * (length + spacex) + bord - spacex
				local rectangle = ke.shape.new("m 0 100 l 100 100 l 100 0 l 0 0 "):size(length, bord)
				local shp_H = rectangle:array(xloop, "array", spacex)
				local shp_V = yloop == xloop and shp_H or rectangle:array(yloop, "array", spacex)
				local parts = {
					[1] = shp_H.code,
					[2] = shp_V:rotate(-90):displace(4, {xsize + spacex, 0}, "point").code,
					[3] = shp_H:rotate(180):displace(4, {xsize + spacex, ysize + spacex}, "point").code,
					[4] = shp_V:rotate( 90):displace(4, {0, ysize + spacex}, "point").code
				} --ke.shape.multi6({120, 30}, {4, 5}, 8)
				return ke.shape.new(table.concat(parts))
			end, --ke.shape.multi6()
			
			multi7 = function(part, radius)
				--returns a circle or the perimeter of a circle made up of individual segments
				local part = type(part) == "function" and part() or part or 12
				local radius = type(radius) == "function" and radius() or radius or 50
				part = ke.math.round(math.abs(part))
				part = part < 2 and 2 or part
				local angle = 360 / part
				local ang_b = angle * 0.295927
				local ratio, shp = 1 / math.cos(math.rad(ang_b)), ""
				if type(radius) == "number" then
					for i = 1, part do
						local x0, y0 = ke.math.polar(angle * (i - 1), radius)
						local x1, y1 = ke.math.polar(angle * (i - 1) + ang_b, radius * ratio)
						local x2, y2 = ke.math.polar(angle * i - ang_b, radius * ratio)
						local x3, y3 = ke.math.polar(angle * i, radius)
						shp = shp .. ("m 0 0 l %s %s b %s %s %s %s %s %s l 0 0 "):format(x0, y0, x1, y1, x2, y2, x3, y3)
					end --ke.shape.multi7(12, 100)
				else --type(radius) == "table"
					for i = 1, #radius - 1 do
						for k = 1, part do
							local x0, y0 = ke.math.polar(angle * (k - 1), radius[i + 1])
							local x1, y1 = ke.math.polar(angle * (k - 1) + ang_b, radius[i + 1] * ratio)
							local x2, y2 = ke.math.polar(angle * k - ang_b, radius[i + 1] * ratio)
							local x3, y3 = ke.math.polar(angle * k, radius[i + 1])
							local x4, y4 = ke.math.polar(angle * k, radius[i])
							local x5, y5 = ke.math.polar(angle * k - ang_b, radius[i] * ratio)
							local x6, y6 = ke.math.polar(angle * (k - 1) + ang_b, radius[i] * ratio)
							local x7, y7 = ke.math.polar(angle * (k - 1), radius[i])
							local x8, y8 = ke.math.polar(angle * (k - 1), radius[i + 1])
							shp = shp .. ("m %s %s b %s %s %s %s %s %s l %s %s b %s %s %s %s %s %s l %s %s "):format(
								x0, y0, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6, x7, y7, x8, y8
							)
						end
					end
				end --ke.shape.multi7(12, {20, 40, 60})
				return ke.shape.new(shp):displace("origin")
			end,
			
			multi8 = function(self, size1, size2, loop)
				--returns concentric shapes from an initial size to a final size
				local shp = self or ke.shape.rectangle
				shp = type(shp) == "function" and shp() or shp
				shp = type(shp) == "string" and ke.shape.new(shp) or shp
				shp = shp:displace("origin")
				local size1 = type(size1) == "function" and size1() or size1 or shp.width
				local size2 = type(size2) == "function" and size2() or size2 or shp.width * 0.5
				local loop = math.abs(math.ceil(type(loop) == "function" and loop() or loop or 8))
				loop = loop < 2 and 2 or loop
				local maxsize = math.max(math.abs(math.ceil(size1)), math.abs(math.ceil(size2)))
				local minsize = math.min(math.abs(math.ceil(size1)), math.abs(math.ceil(size2)))
				local shp1 = shp:size(maxsize, 0)
				local result, c = {}, shp1.centroid
				for i = 1, loop do
					result[i] = shp1:size(maxsize - (maxsize - minsize) * (i - 1) / (loop - 1), 0):displace(c, nil, "center").code
				end
				return ke.shape.new(table.concat(result))
			end, --ke.shape.multi8(ke.shape.rectangle, 100, 10, 10)
			
			to_line = function(self, tract)
				--converts the "bezier" sections of the shape, into "line"
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local tract = type(tract) == "function" and tract() or tract or 5
				return self:redraw(tract, "bezier")
			end, --ke.shape.to_line(ke.shape.circle).code
			
			to_bezier = function(self)
				--converts the "line" sections of the shape, into "bezier"
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local segs = self:__seg()
				for i = 1, #segs do
					segs[i] = segs[i].t == "l" and segs[i]:to_bezier() or segs[i]
				end
				self.code = ke.shape.new(segs).code
				return self
			end, --ke.shape.to_bezier(ke.shape.rectangle).code
			
			insert = function(self, other)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local other = type(other) == "function" and other() or other
				other = type(other) == "string" and ke.shape.new(other) or other
				local shapes1 = ke.table.new(self.code:gmatch("m[^m]*")) --shapes individuales
				local shapes2 = ke.table.new(other.code:gmatch("m[^m]*"))
				local isolen = function(array1, array2)
					local n1, n2 = #array1, #array2
					local array1 = n1 < n2 and array1("newlen", {n2}) or array1
					local array2 = n1 > n2 and array2("newlen", {n1}) or array2
					return array1, array2
				end --iguala el tamaño de dos tablas
				shapes1, shapes2 = isolen(shapes1, shapes2)
				for i = 1, #shapes1 do
					shapes1[i] = ke.table.new(shapes1[i]:gmatch("[mlb][^mlb]*")) --segmentos de cada shape
					shapes2[i] = ke.table.new(shapes2[i]:gmatch("[mlb][^mlb]*"))
					local m1, m2 = shapes1[i][1], shapes2[i][1]
					table.remove(shapes1[i], 1)
					table.remove(shapes2[i], 1)
					shapes1[i], shapes2[i] = isolen(shapes1[i], shapes2[i])
					table.insert(shapes1[i], 1, m1)
					table.insert(shapes2[i], 1, m2)
					for k = 1, #shapes1[i] do
						local t1, t2 = shapes1[i][k]:match("[mbl]"), shapes2[i][k]:match("[mbl]")
						if k > 1 and t1 ~= t2 then
							if t1 == "l" then
								local p0 = ke.shape.point.new(shapes1[i][k - 1]:match("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)%s?$"))
								local p3 = ke.shape.point.new(shapes1[i][k]:match("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)%s?$"))
								local p1, p2 = p0:ipol(p3, 0.33), p0:ipol(p3, 0.66)
								shapes1[i][k] = ("b %.f %.f %.f %.f %s %s "):format(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y)
							else
								local p0 = ke.shape.point.new(shapes2[i][k - 1]:match("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)%s?$"))
								local p3 = ke.shape.point.new(shapes2[i][k]:match("(%-?%d[%.%d]*)%s+(%-?%d[%.%d]*)%s?$"))
								local p1, p2 = p0:ipol(p3, 0.33), p0:ipol(p3, 0.66)
								shapes2[i][k] = ("b %.f %.f %.f %.f %s %s "):format(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y)
							end
						end
					end
					shapes1[i], shapes2[i] = table.concat(shapes1[i]), table.concat(shapes2[i])
				end
				self.code = ke.shape.new(table.concat(shapes1)).code
				other.code = ke.shape.new(table.concat(shapes2)).code
				return self, other
			end, --ke.shape.insert(ke.shape.rectangle, ke.shape.circle)
			
			ipol = function(self, other, parameter)
				local self, other = ke.shape.insert(self, other)
				local pnt, opnt = self:points(), other:points()
				local a = type(parameter) == "table" and parameter.accel or 1
				local n = type(parameter) == "table" and parameter.n or nil
				local t = type(parameter) == "table" and parameter.t or parameter or 0.5
				local configs = {
					["t"] = t,
					["accel"] = a,
					["curve"] = type(parameter) == "table" and parameter.accel or nil,
					["shape"] = type(parameter) == "table" and parameter.shape or nil,
					["others"] = type(parameter) == "table" and parameter.others or nil,
				}
				if not n then
					local result = ke.table.new(pnt.n, function(i) return pnt[i]:ipol(opnt[i], configs) end)
					return ke.shape.new(result)
				end
				if n < 2 then
					return self
				end --ke.shape.ipol(ke.shape.rectangle, ke.shape.circle, {n = 5})
				local result = ke.table.new(n, {})
				for i = 1, n do
					for k, p in ipairs(pnt) do
						configs.t = (i - 1) / (n - 1)
						table.insert(result[i], p:ipol(opnt[k], configs))
					end
					result[i] = ke.shape.new(result[i]).code
				end --ke.shape.ipol(ke.shape.rectangle, ke.shape.circle, {n = 5, accel = function(t) return math.sin(math.pi * t) end})
				return result
			end, --ke.shape.ipol(ke.shape.rectangle, ke.shape.circle, 0.8).code
			
			cut = function(self, t)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				if t < 0 then
					local s, p = ke.shape.cut(self:__inv(), -t)
					return s:__inv(), p
				end
				t = ke.math.clamp(t or 0.5)
				if t == 1 then return self, nil end
				local slength, alength, k = {}, {0}, 1
				local segs = self:__seg()
				for i, s in ipairs(segs) do
					slength[i] = s:length()
					alength[i + 1] = alength[i] + slength[i]
				end
				local tlenght, newsegs = t * self:length(), {}
				for i = 1, #segs do
					newsegs[i] = segs[i]
					if tlenght <= alength[i + 1] then
						k = i
						break
					end
				end
				local newt = slength[k] > 0 and (tlenght - alength[k]) / slength[k] or 0
				newsegs[k] = segs[k]:cut(newt)
				self.code = ke.shape.new(newsegs).code
				return self, segs[k]:parameter(newt)
			end, --ke.shape.cut(ke.shape.rectangle, 0.625)
			
			parameter = function(self, t, n)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				if n and type(n) == "number" then
					n = math.ceil(math.abs(n))
					local div, posangles = self:__isclosed() and n or n - 1, {}
					return ke.table.new(n, function(i) return {self:parameter((i - 1) / div)} end)
				end
				local t = type(t) == "table" and t[1] or t * self:length()
				local seg, length = ke.shape.beziers.length2seg(self, t)
				local nwt = ke.shape.beziers.length2t(seg, length)
				local vec = ke.shape.beziers.normal2p(seg, nwt)
				local pos = ke.shape.beziers.config(seg, nwt)
				local ang = ke.math.round(math.deg(math.atan2(-vec[2], vec[1])), 3)
				return pos, ang
			end, --{ke.shape.parameter(ke.shape.new(ke.shape.circle), 0.125)}
			
			getpoint = function(self, t)
				return ke.shape.parameter(self, t)
			end,
			
			getparameter = function(self, p)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				self = self:__closed()
				local perimeter = self:length()
				self = self:__unclosed()
				local accum = 0
				for _, s in ipairs(self) do
					local points = s:points()
					local n, seg = #points, {}
					for i = 1, n do
						local p1 = points[i]
						local p2 = (i == n) and points[1] or points[i + 1]
						seg[i] = p1:distance(p2)
					end
					for i = 1, n do
						local p1 = points[i]
						local p2 = (i == n) and points[1] or points[i + 1]
						if p == p1 then
							return accum / perimeter
						end
						local dist1, dist2 = p1:distance(p), seg[i]
						if math.abs(dist1 + p:distance(p2) - dist2) < EPSILON then
							return (accum + dist1) / perimeter
						end
						accum = accum + seg[i]
					end
				end
				return nil
			end, --ke.shape.getparameter("m 0 0 l 0 30 l 30 30 l 30 0 l 0 0 m 10 10 l 20 10 l 20 20 l 10 20 l 10 10 ", ke.shape.point.new(10, 20))
			
			line = function(self, bord, mode)
				local bord = bord and 0.5 * math.abs(bord) or 4
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local mode = mode or "miter" --"miter", "round" or "bevel"
				self = self:__red()
				local result, rat = "", 0.115
				for i, s in ipairs(self) do
					local pnt = s:points()
					local polyline = s:__isclosed()
					local exterior, interior = ke.table.new(), ke.table.new()
					local first = pnt[1] == pnt[#pnt] and pnt[#pnt - 1] or pnt[1]:polar(pnt[2]:angle(pnt[1]), 1)
					local last  = pnt[1] == pnt[#pnt] and pnt[2] or pnt[#pnt]:polar(pnt[#pnt - 1]:angle(pnt[#pnt]), 1)
					for k = 1, #pnt do
						p0 = k == 1 and first or pnt[k - 1]
						p1 = pnt[k]
						p2 = k == #pnt and last or pnt[k + 1]
						ang1, ang2 = p0:bisector(p1, p2), p0:angle(p1, p2) --bisector and exterior angle
						radius = math.abs(bord / math.sin(math.rad(ang1 - p1:angle(p0) - (ang2 <= 300 and 0 or rat) * ang2)))
						exterior:insert(ang2 <= 300 and p1:polar(ang1,  radius) or p1:polar(ang1 - rat * ang2,  radius))
						interior:insert(ang2 <= 300 and p1:polar(ang1, -radius) or p1:polar(ang1 - rat * ang2, -radius))
						if ang2 > 300 and k ~= #pnt then
							exterior:insert(p1:polar(ang1 + rat * ang2,  radius))
							interior:insert(p1:polar(ang1 + rat * ang2, -radius))
						end
					end
					exterior = ke.shape.new(exterior)
					interior = ke.shape.new(interior):__inv()
					local ratio = mode == "round" and 2.4 or 1.8
					if s:isclockwise() and mode ~= "miter" then
						interior = interior:roundout(ratio * bord, mode)
					elseif not s:isclockwise() and mode ~= "miter" then
						exterior = exterior:roundout(ratio * bord, mode)
					end
					interior = polyline and interior.code:gsub("m", "l") or interior.code
					result = result .. exterior.code .. interior
				end
				self.code = ke.shape.new(result).code
				return self
			end, --ke.shape.line("m 0 0 l 0 56 l 44 56 l 44 0 l 0 0 m 15 18 l 87 18 l 87 37 l 15 37 l 15 18 ", 4, "round").code
			
			offset = function(self, bord, mode)
				return ke.shape.line(self, bord, mode)
			end,
			
			pixels = function(self)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local upscale = 8
				local downscale = 1 / upscale
				self = self:ratio(upscale)
				local x1, y1, x2, y2 = self.minx, self.miny, self.maxx, self.maxy
				local shift_x, shift_y = -(x1 - x1 % upscale), -(y1 - y1 % upscale)
				self = self:displace(shift_x, shift_y)
				local function render(shp, width, height, image)
					local line, n, last, move = {}, 0
					shp = shp:clone():redraw(upscale, "bezier")
					local y1, y2 = shp.miny, shp.maxy
					shp = shp:__gsub(
						function(x, y, t)
							x, y = ke.math.round(x), ke.math.round(y)
							if t == "m" then
								if move and move[2] ~= last[2] and not (last[2] < 0 and move[2] < 0)
									and not (last[2] > height and move[2] > height) then
									n = n + 1
									line[n] = {last[1], last[2], move[1] - last[1], move[2] - last[2]}
								end
								move = {x, y}
							elseif last and last[2] ~= y and not (last[2] < 0 and y < 0)
								and not (last[2] > height and y > height) then
								n = n + 1
								line[n] = {last[1], last[2], x - last[1], y - last[2]}
							end
							last = {x, y}
						end
					)
					if move and move[2] ~= last[2] and not (last[2] < 0 and move[2] < 0)
						and not (last[2] > height and move[2] > height) then
						n = n + 1
						line[n] = {last[1], last[2], move[1] - last[1], move[2] - last[2]}
					end
					local function hline(x, y, vx, vy, y2)
						if vy ~= 0 then
							local s = (y2 - y) / vy
							if s >= 0 and s <= 1 then
								return x + s * vx, y2
							end
						end
					end
					local function trim (x, min, max)
						return x < min and min or x > max and max or x
					end
					for y = math.max(math.floor(y1), 0), math.min(math.ceil(y2), height) - 1 do
						local row_stops, row_stops_n = {}, 0
						for i = 1, n do
							local line = line[i]
							local cx = hline(line[1], line[2], line[3], line[4], y + 0.5)
							if cx then
								row_stops_n = row_stops_n + 1
								row_stops[row_stops_n] = {trim(cx, 0, width), line[4] > 0 and 1 or -1}
							end
						end
						if row_stops_n > 1 then
							table.sort(row_stops, function(a, b) return a[1] < b[1] end)
							local status, row_index = 0, 1 + y * width
							for i = 1, row_stops_n - 1 do
								status = status + row_stops[i][2]
								if status ~= 0 then
									for x = math.ceil(row_stops[i][1] - 0.5), math.floor(row_stops[i + 1][1] + 0.5) - 1 do
										image[row_index + x] = true
									end
								end
							end
						end
					end
				end
				local img_width  = math.ceil((x2 + shift_x) * downscale) * upscale
				local img_height = math.ceil((y2 + shift_y) * downscale) * upscale
				local img_data = {}
				for i = 1, img_width * img_height do
					img_data[i] = false
				end
				render(self, img_width, img_height, img_data)
				local pixels, pixels_n, opacity = {}, 0
				for y = 0, img_height - upscale, upscale do
					for x = 0, img_width - upscale, upscale do
						opacity = 0
						for yy = 0, upscale - 1 do
							for xx = 0, upscale - 1 do
								if img_data[1 + (y + yy) * img_width + (x + xx)] then
									opacity = opacity + 255
								end
							end
						end
						if opacity > 0 then
							pixels_n = pixels_n + 1
							pixels[pixels_n] = {
								["a"] = ke.alpha.ass(255 - opacity * downscale ^ 2),	--alpha
								["x"] = (x - shift_x) * downscale + 1,					--x coor
								["y"] = (y - shift_y) * downscale + 1					--y coor
							}
						end
					end
				end
				return pixels
			end, --ke.shape.pixels("m 0 0 l 0 5 l 5 5 l 5 0 ")
			
			tensor = function(self, inbox, t)
				--shape modifies respect to its bounding box
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local P0, P1, P2, P3 = self:box()
				local t = t or 1
				local inbox = inbox or ke.shape.new(ke.shape.rectangle):size(self.width, self.height)
				--fx box configuration
				local other = ke.shape.new(inbox)
				local xbox = other:to_bezier():__seg()
				table.remove(xbox, 1)
				xbox[3], xbox[4] = xbox[3]:__inv(), xbox[4]:__inv()
				--points in segment box
				local sup0, sup1, sup2, sup3 = xbox[4][0], xbox[4][1], xbox[4][2], xbox[4][3] --top
				local inf0, inf1, inf2, inf3 = xbox[2][0], xbox[2][1], xbox[2][2], xbox[2][3] --bottom
				local izq0, izq1, izq2, izq3 = xbox[1][0], xbox[1][1], xbox[1][2], xbox[1][3] --left
				local der0, der1, der2, der3 = xbox[3][0], xbox[3][1], xbox[3][2], xbox[3][3] --right
				local sw, sh, ow, oh = self.width, self.height, other.width, other.height
				local tensor_filter = function(x, y)
					local u, v = My, Mx
					local Pt, Pb = sup0:ipol({sup1, sup2, sup3}, u), inf0:ipol({inf1, inf2, inf3}, u)
					local Pl, Pr = izq0:ipol({izq1, izq2, izq3}, v), der0:ipol({der1, der2, der3}, v)
					local vert, hori = Pt:ipol(Pb, v) * (sw / ow), Pl:ipol(Pr, u) * (sh / oh)
					--local offset = P0 * (1 - u) * (1 - v) + P3 * u * (1 - v) + P2 * u * v + P1 * v * (1 - u)
					--local newp = Pt * (1 - v) + Pb * v + Pl * (1 - u) + Pr * u --- offset
					--x, y = newp.x, newp.y
					x, y = x + (hori.x - x) * t, y + (vert.y - y) * t
					return x, y
				end
				return self:__gsub(tensor_filter)
				--ke.shape.new(ke.shape.rectangle):redraw(4):tensor("m 0 0 b 5 14 -11 32 0 40 b 10 34 28 34 40 40 b 47 28 47 13 40 0 b 27 -22 13 17 0 0 ").code
			end,
			
			distort = function(self, other, t, source, target)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local other = type(other) == "function" and other() or other
				local oself = self:clone()
				self = self:redraw(4) --4?
				other = type(other) == "string" and ke.shape.new(other) or other
				local source, target = source or "convex", target or "boundary"
				local funct = {
					["convex"] = ke.shape.inconvex,
					["boundary"] = ke.shape.inboundary
				}
				other = other:__red()
				local t = t or 1
				local points = self:points()
				local centroid = self.centroid
				for i, p in ipairs(points) do
					local angle, dis = centroid:topolar(p)
					local _, radius1 = funct[source](oself, angle)
					local _, radius2 = funct[target](other, angle)
					if not radius2 then
						_, radius2 = funct[target](other, -angle)
					end
					points[i] = centroid:polar(angle, dis + (dis * radius2 / radius1 - dis) * t)
					points[i].t = p.t
				end
				self.code = ke.shape.new(points):__red().code
				return self
			end, --ke.shape.distort(ke.shape.rectangle, ke.shape.heart, 0.75).code
			
			flexor = function(self, anycurve, t, axis)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				self = axis == "y" and self:rotate(-90) or self
				local h = self.height
				local anycurve = ke.shape.new(anycurve):cut(t or 1)
				local flexor_filter = function(x, y)
					local p, a = anycurve:parameter(My)
					local newp = p:polar(a, h / 2 - y)
					x, y = newp.x, newp.y
					return x, y
				end
				local split = ke.math.round(self:length() / (0.42 * (h + anycurve:length())), ROUND_NUM)
				self = self:redraw(split):__gsub(flexor_filter)
				return self
			end, --ke.shape.new("m 0 0 l 0 10 l 80 10 l 80 0 l 10 0 l 10 4 l 4 4 l 4 0 l 0 0 "):flexor("m 0 24 b 17 -2 62 36 71 -3 b 76 -34 133 3 78 24 ").code
			
			inflated = function(self, t, split, ratio, mode)
				local split = split or 4
				local ratio = ratio or 1
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				self = self:ratio(ratio):redraw(split)
				local mode = mode or "circle" -- or "ellipse"
				local result = {}
				for _, s in ipairs(self) do
					local points = s:points()
					local center = s.centroid
					local w, h = s.width, s.height
					local diameter = math.sqrt((w * w + h * h) / 2)
					local r1 = (mode == "circle" and diameter or w) * math.sqrt(2) / 2
					local r2 = (mode == "circle" and diameter or h) * math.sqrt(2) / 2
					for _, p in ipairs(points) do
						local dx = p.x - center.x
						local dy = p.y - center.y
						local distance = math.sqrt(dx * dx + dy * dy)
						local newp = {x = p.x, y = p.y, t = p.t}
						if distance > EPSILON then
							local _cos = math.cos(math.atan2(dy, dx))
							local _sin = math.sin(math.atan2(dy, dx))
							local radius = (r1 * r2) / math.sqrt(r2 * r2 * _cos * _cos + r1 * r1 * _sin * _sin)
							local ux, uy = dx / distance, dy / distance
							local newdist = distance * (1 - t) + radius * t
							newp = {x = center.x + ux * newdist, y = center.y + uy * newdist, t = p.t}
						end
						table.insert(result, ke.shape.point.new(newp))
					end
				end
				self.code = ke.shape.new(result).code
				return self
			end, --ke.shape.inflated(ke.shape.rectangle, 0.7).code
			
			trajectory = function(mode, loop, caliber1, caliber2)	
				local curves = {	
					["bezier"] = function(loop, distance_nim, distance_max)
						--generates a random shape with a stroke in beziers in a fluid way
						local loop = math.ceil(type(loop) == "function" and loop() or loop or 8)
						local dmin = type(distance_nim) == "function" and distance_nim() or distance_nim or 10
						local dmax = type(distance_max) == "function" and distance_max() or distance_max or 20
						local points, xpoints, shp = ke.shape.point.random(2 * loop + 1, dmin, dmax), {}, "m 0 0 b "
						for i = 1, #points do
							shp = shp .. points[i]:__str()
							if i < #points - 2 and i % 2 == 0 then
								shp = shp .. ke.shape.segment.new({points[i], points[i + 1]}):parameter(ke.math.rand(0.3, 0.7, 0.01)):__str()
							end
						end
						return ke.shape.new(shp)
					end, --ke.shape.trajectory("bezier")
					
					["path"] = function(loop, length_total, height_curve) --Curve in Line Trajectory
						--generates a random shape with a stroke in beziers in a fluid way, in a straight path
						local lengthT = type(length_total) == "function" and length_total() or length_total or 640
						local lengthC = lengthT / (type(loop) == "function" and loop() or loop or 4)
						local ratio_y = type(height_curve) == "function" and height_curve() or height_curve or 30
						local n, points, sign, x, y = ke.math.round(lengthT / lengthC), {}, (-1) ^ ke.math.rand(2)
						local xray, shp = ke.shape.segment.new({-lengthC, 0, n * lengthC + lengthC, 0}), "m 0 0 b "
						local cix, ciy = ke.math.count(2), ke.math.count()
						for i = 1, 2 * n do
							x = lengthC * (cix("N,n", 2) - 1) + ke.math.rand(0.35 * lengthC, 0.65 * lengthC) * sign ^ i
							y = ratio_y * sign * (-1) ^ ciy("N,n", 2) + ke.math.rand(1, 0.125 * ratio_y, 1, true)
							points[#points + 1] = ke.shape.point.new(x, y)
						end
						points[#points + 1] = ke.shape.point.new(n * lengthC + ke.math.rand(1, 0.125 * lengthC, 1, true), 0)
						for i = 1, #points do
							shp = shp .. points[i]:__str()
							if i < #points - 2 and i % 2 == 0 then
								shp = shp .. xray:intersect({points[i], points[i + 1]}):__str()
							end
						end
						return ke.shape.new(shp)
					end, --ke.shape.trajectory("path")
					
					["line"] = function(loop, radius) --Segment Line Trajectory
						--generate a random shape with straight strokes
						local loop = type(loop) == "function" and loop() or loop or 8
						local radius = type(radius) == "function" and radius() or radius or 60
						local loops, angles = math.ceil(loop), {[0] = ke.math.rand(36) * 10}
						for i = 1, loops do
							angles[i] = ke.math.rand(angles[i - 1] + 110, angles[i - 1] + 250)
						end
						local shp, Rand = "m 0 0 "
						for i = 1, loops do
							Rand = ke.math.rand(0.7 * radius, radius)
							shp = shp .. ("l %s %s "):format(ke.math.polar(angles[i], Rand))
						end
						return ke.shape.new(shp)
					end, --ke.shape.trajectory("line")
				}
				local mode = mode or "bezier"
				return curves[mode] and curves[mode](loop, caliber1, caliber2) or curves["bezier"](loop, caliber1, caliber2)
			end,
			
			to_clip = function(self, x, y, iclip)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				if type(self) == "table" and not self.code then
					return ke.table.recursive(self, ke.shape.to_clip, x, y, iclip)
				end
				local fx = ke.infofx.fx
				local x, y = x or fx.x, y or fx.y
				local shp = self:displace(x, y, "center").code
				return ("\\%sclip(%s)"):format(iclip and "i" or  "", shp)
			end, --ke.shape.to_clip(ke.shape.circle)
			
			divide = function(self)
				--array of shapes that make up a shape
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				if type(self) == "table" and not self.code then
					return ke.table.recursive(self, ke.shape.divide)
				end
				local x1, y1, x2, y2 = self:bounding()
				local mark = ("m %s %s m %s %s "):format(x1, y1, x2, y2)
				--local mark = ("m %s %s l %s %s m %s %s l %s %s "):format(x1, y1, x2, y1, x1, y2, x2, y2)
				local shapes = {}
				for i, s in ipairs(self) do
					shapes[i] = mark .. s.code
				end --ke.shape.divide({"m 50 53 l 23 66 m 50 53 l 54 84 ", "m 0 5 l 2 6 m 5 3 l 5 8 "})
				return shapes
			end, --ke.shape.divide("m 50 53 l 23 66 l 20 96 l 46 84 m 50 53 l 54 84 l 81 97 l 78 66 ")
			
			fusion = function(shapes, tags)
				--merge the entered shapes so that they occupy a single fx line
				local shapes = shapes or {ke.shape.rectangle, ke.shape.circle}
				shapes = type(shapes) == "function" and shapes() or shapes
				shapes = type(shapes) == "string" and ke.shape.new(shapes) or shapes
				local tags = type(tags) == "function" and tags() or tags
				local aux = not shapes.code and ke.table.new(#shapes, function(i) return ke.shape.new(shapes[i]) end) or nil
				local result = ""
				if aux then
					shapes = ""
					for i = 1, #aux do
						shapes = shapes .. aux[i].code
					end
					shapes = ke.shape.new(shapes)
				end
				local w, h = shapes.width, shapes.height
				shapes = shapes:displace("origin"):divide()
				local n = #shapes
				tags = tags or ke.table.new(n, function() return ("\\1c%s"):format(ke.color.random(nil, 82)) end)
				for i = n, 1, -1 do
					shapes[i] = ke.shape.displace(shapes[i], 0.5 * w + (n - i) * w, 0.5 * h, "center")
					shapes[i] = shapes[i]:displace(-0.5 * n * w + 0.5 * w)
				end
				for i = 1, n do
					shapes[i] = "{" .. tags[(i - 1) % #tags + 1] .. "}" .. shapes[i].code
					result = result .. shapes[i]
				end
				return result
			end,
			
			graph = {
				polygon = function(n, radius, angle, bord)
					local n = type(n) == "function" and n() or n or 6
					n = math.abs(math.ceil(n < 3 and 3 or n))
					local radius, angle = radius or 50, angle
					local do_polygon = function(n, radius, angle, bord)
						if not n or n == math.huge then
							local poly = ke.shape.new(ke.shape.circle):size(2 * radius):rotate(-90, "center"):displace("incenter")
							poly = angle and poly:cut(angle / 360) or poly
							poly = (bord and type(bord) == "number") and poly:line(bord) or poly
							return poly.code
						end --ke.shape.graph.polygon(nil, {40, 50}, 300, 5)
						local anglex, thetax = 360 / n, 90 * (n - 2) / n
						local poly = ""
						for i = 1, n + 1 do
							poly = poly .. ("l %s %s "):format(ke.math.polar(anglex * (i - 1), radius))
						end
						poly = poly:gsub("l", "m", 1)
						if n % 2 == 1 then --n impar
							local anglix = 90 - anglex * math.floor(90 / anglex)
							local fakex = radius * math.sin(math.rad(thetax)) / math.sin(math.rad(180 - thetax - anglix))
							poly = ("m %s 0 "):format(fakex)
							for i = 1, n do
								poly = poly .. ("l %s %s "):format(ke.math.polar(anglix + anglex * (i - 1), radius))
							end
							poly = poly .. ("l %s 0 "):format(fakex)
						end
						poly = ke.shape.new(poly)
						poly = angle and poly:cut(angle / 360) or poly
						poly = (bord and type(bord) == "number") and poly:line(bord) or poly
						return poly.code
					end --ke.shape.graph.polygon(8, {40, 50}, 300, 5)
					radius = type(radius) ~= "table" and {radius} or radius
					angle = (angle and type(angle) ~= "table") and {angle} or angle
					local polygon = ""
					for i = 1, #radius do
						polygon = polygon .. do_polygon(n, radius[i], angle and angle[(i - 1) % #angle + 1], bord)
					end
					return polygon
				end,
				
				banner = function(width, height, mode, bord)
					local width = type(width) == "function" and width() or width or 200
					local height = type(height) == "function" and height() or height or 50
					local mode = type(mode) == "function" and mode() or mode or "[]"
					local bord = type(bord) == "function" and bord() or bord
					local heads = {
						[1] = {--banner start
							["["] = "m 0 0 l 0 100 ",									["]"] = "m 0 0 l 0 100 ",
							["<"] = "m 28.86 0 l 0 50 l 28.86 100 ",					[">"] = "m 0 0 l 28.86 50 l 0 100 ",
							["/"] = "m 28.86 0 l 0 100 ",								["\\"] = "m 0 0 l 28.86 100 ",
							["{"] = "m 27 0 l 15 12 15 35 0 50 15 65 15 88 27 100 ",	["}"] = "m 0 0 l 12 12 12 35 27 50 12 65 12 88 0 100 ",
							["="] = "m 0 0 l 0 32 32 32 32 68 0 68 0 100 ",				["#"] = "m 0 0 l 0 20 20 20 20 40 0 40 0 60 20 60 20 80 0 80 0 100 ",
							["("] = "m 50 0 b 22 0 0 22 0 50 b 0 78 22 100 50 100 ",
							[")"] = "m 0 0 b 17.591 9.974 28.88 28.447 28.88 50 b 28.88 71.553 17.591 90.026 0 100 ",
						},
						[2] = {--banner end
							["]"] = "m 0 100 l 0 0 ",									["["] = "m 0 100 l 0 0 ",
							["<"] = "m 0 100 l -28.86 50 l 0 0 ",						[">"] = "m -28.86 100 l 0 50 l -28.86 0 ",
							["/"] = "m -28.86 100 l 0 0 ",								["\\"] = "m 0 100 l -28.86 0 ",
							["}"] = "m 0 100 l 12 88 12 65 27 50 12 35 12 12 0 0 ",		["{"] = "m 0 100 l -12 88 -12 65 -27 50 -12 35 -12 12 0 0 ",
							["="] = "m 0 100 l 0 68 -32 68 -32 32 0 32 0 0 ",			["#"] = "m 0 100 l 0 80 -20 80 -20 60 0 60 0 40 -20 40 -20 20 0 20 0 0 ",
							[")"] = "m -50 100 b -22 100 0 78 0 50 b 0 22 -22 0 -50 0 ",
							["("] = "m 0 100 b -17.591 90.026 -28.88 71.553 -28.88 50 b -28.88 28.447 -17.591 9.974 0 0 ",
						} --ke.shape.graph.banner(600, 100, "#{", 4).code
					} --ke.shape.graph.banner(300, 40, "<]").code
					mode = (type(mode) ~= "string" and type(mode) ~= "table") and "[]" or mode
					local mode_i = type(mode) == "string" and mode:sub(1, 1) or mode[1] or "["
					local mode_f = type(mode) == "string" and mode:sub(2, 2) or mode[2] or "]"
					local ini = ke.shape.new(heads[1][mode_i] or mode_i or "m 0 0 l 0 100 ")
					local fin = ke.shape.new(heads[2][mode_f] or mode_f or "m 0 100 l 0 0 ")
					ini = ini:ratio(nil, {height})
					fin = fin:ratio(nil, {height}):displace(width, 0)
					local banner = ini.code .. fin.code:gsub("m", "l")
					banner = ke.shape.new(banner):to_line():__closed()
					return (bord and type(bord) == "number") and banner:line(bord):displace("origin") or banner:displace("origin")
				end, --ke.shape.graph.banner(300, 40, "<>", 4).code
				
				gear = function(radius, n, dent, double, bord)
					local radius = type(radius) == "function" and radius() or radius or 180
					local n = type(n) == "function" and n() or n or 8
					local graph_gear = function(radius, n, dent)
						local ratio, angle = 0.38, 360 / n
						local arc1, arc2 = ratio * angle, 0.5 * (1 + ratio) * angle
						local length = 2 * math.pi * radius * angle / 360
						local dent = type(dent) == "function" and dent() or dent or "m 0 0 l 100 0 "
						dent = ke.shape.new(dent):rotate({nil, 0}):displace("incenter")
						local height = dent.height
						local parts = {
							[1] = ke.shape.new("m 50 0 b 50 -28 28 -50 0 -50 "):size(radius):cut(arc1 / 90),
							[2] = dent:ratio({0.45 * length}):rotate(90 + arc2):displace({arc2, radius + 0.45 * length - height / 5})
						}
						dent = ke.shape.new(parts[1].code .. parts[2].code:gsub("m", "l"))
						local gear_shp = ""
						for i = 1, n do
							gear_shp = gear_shp .. dent:rotate(angle * (i - 1)).code
						end --ke.shape.graph.gear(100, 8, "m 0 0 l 30 0 l 30 -22 l 70 -22 l 70 0 l 100 0 "):round().code
						local result = ke.shape.new(gear_shp):rotate(-arc2).code:gsub("m", "l"):gsub("l", "m", 1)
						return ke.shape.new(result):__closed()
					end
					local cir_1 = ke.shape.new("m 0 -50 b -28 -50 -50 -28 -50 0 b -50 28 -28 50 0 50 b 28 50 50 28 50 0 b 50 -28 28 -50 0 -50 ")
					local cir_2 = cir_1:__inv()
					local circle_add1 = cir_2:size(1.8 * radius) .. cir_1:size(1.5 * radius)
					local circle_add2 = cir_2:size(0.5 * radius)
					local shp_gear = graph_gear(radius, n, dent)
					if double then
						shp_gear = shp_gear .. graph_gear(0.7 * radius, n, dent):__inv()
						circle_add1 = cir_1:size(1.1 * radius) .. cir_2:size(0.9 * radius)
						circle_add2 = cir_1:size(0.5 * radius)
					end
					local gear = shp_gear .. circle_add1 .. circle_add2
					gear = (bord and type(bord) == "number") and gear:line(bord) or gear
					return gear:displace("origin")
				end --ke.shape.graph.gear(80, 8, "m -45 -16 l -20 0 l 20 0 l 45 -16 ", true).code
			},
			
			array = function(self, loop, mode, dxy)
				--generates multiple arrays of one or more shapes entered
				local self = type(self) == "function" and self() or self
				local shapes = type(self) == "string" and (self == "random" and self or ke.shape.new(self)) or self
				local Aux = (self ~= "random" and not shapes.code) and ke.table.new(#shapes, function(i) return ke.shape.new(shapes[i]) end) or nil
				shapes = Aux or {shapes}
				local loop = type(loop) == "function" and loop() or loop or 6
				local mode = type(mode) == "function" and mode() or mode or 0
				local dxy = type(dxy) == "function" and dxy() or dxy or 0
				local disxy, loop1, loop2 = dxy, loop, #shapes
				if type(loop) == "table" then
					loop1, loop2 = loop[1], loop[2] or loop1
				end --ke.shape.array("m 0 0 l 0 10 l 10 10 l 10 0 ", 8, "radial", 20)
				local angle_array = (type(mode) ~= "number" and type(mode) ~= "table") and 0 or mode
				local angle_shape = type(mode) == "table" and mode[2] or 0
				angle_array = type(mode) == "table" and mode[1] or angle_array
				local distance_x = type(disxy) == "string" and 0 or disxy
				local radius_ini = type(disxy) == "string" and 0 or disxy
				local distance_y, radius_fin = distance_x, radius_ini
				local arco, angle_ini, distance_r = 360, 0, 0
				if type(disxy) == "table" then
					distance_x, distance_y = disxy[1], disxy[2] or distance_x
					radius_ini, radius_fin = disxy[1], disxy[2] or radius_ini
					arco, angle_ini = disxy[3] or 360, disxy[4] or 0
					distance_r = disxy[5] or 0
				end
				local shape_radial, shape_radial_fx, shape_lineal_fx = {}, {}, {}
				local shape_left, idx, shape_rectangular_maxwidths
				local shape_array, shape_rectangular, shape_lineal = {}, {}, {}
				local shape_rectangular_widths = {}
				local widths, shp_lefts = {[0] = 0}, {[0] = 0}
				local heights, shp_tops = {[0] = 0}, {[0] = 0}
				if shapes[1] == "random" then
					local Rc = function(A, B) return ke.math.rand(A, B, 0.01) end
					local Rs = function(A, B) return ke.math.rand(A, B, 0.01, true) end
					local R1A, R1B, R1C, R2A, R2B, R2C, R6A = Rc(10, 30), Rc(10, 30), Rc(10, 30), Rs(30),  Rs(30), Rs(30), Rc(0, 20)
					local R3A, R3B, R4A, R4B, R5A, R5B, R5C = Rc(25, 45), Rc(25, 45), Rc(20, 40), Rc(20, 40), Rs(40), Rs(40), Rs(40)
					local shp0 = {
						[1] = ("m 0 0 l %s %s l %s %s l %s %s l %s %s l 50 0 "):format(R1A, R2A, R3A, R5A, R6A, R2B, R4A, R5B),
						[2] = ("m 0 0 b %s %s %s %s %s %s l %s %s b %s %s %s %s 50 0 "):format(R1A, R2A, R3A, R5A, R6A, R2B, R4A, R5B, R1B, R2C, R4B, R5C),
						[3] = ("m 0 0 b %s %s %s %s %s %s b %s %s %s %s %s %s l 50 0 "):format(R1A, R2A, R3A, R5A, R6A, R2B, R4A, R5B, R1B, R2C, R4B, R5C),
						[4] = ("m 0 0 l %s %s l %s %s b %s %s %s %s %s %s l 50 0 "):format(R1A, R2A, R3A, R5A, R6A, R2B, R3B, R5B, R4A, R5C),
						[5] = ("m 0 0 l %s %s b %s %s %s %s %s %s l %s %s l 50 0 "):format(R1A, R2A, R3A, R5A, R6A, R2B, R3B, R5B, R4A, R5C),
						[6] = ("m 0 0 b %s %s %s %s %s %s l %s %s b %s %s %s %s %s %s l 50 0 "):format(R1A, R2A, R3A, R5A, R6A, R2B, R4A, R5B, R1B, R2C, R4B, R5C, R1C, Rs(30)),
						[7] = ("m 0 0 b %s %s %s %s %s %s l %s %s b %s %s %s %s 50 0"):format(R1A, R2A, R3A, R5A, R6A, R2B, R4A, R5B, R1B, R2C, R4B, R5C, R1C, Rs(30)),
						[8] = ("m 0 0 l %s 0 b %s %s %s %s %s %s l %s %s b %s %s %s %s 50 0"):format(R4A, R3A, R5A, R6A, R2A, R4B, R5B, R1B, R2B, Rc(20, 40), R5C, R1C, R2C)
					}
					local shp1 = ke.shape.new(ke.math.rand(shp0))
					local shp2 = shp1:__inv():reflect("x").code:gsub("m 50 0 ", "")
					local shp3 = ke.shape.ratio(shp1.code .. shp2, {ke.math.rand(36, 50, 0.01)})
					shapes = {shp3}
					loop1, loop2 = 2 * ke.math.rand(3, 4), 1
					radius_ini = 50 - shp3.width
					radius_fin = radius_ini
					mode = "radial2"
				end --ke.shape.array("random").code
				if type(mode) == "string" and mode:match("shape") then --"shape", "shape1", "shape2"
					local confi, shp_array = ke.shape.parameter(disxy, nil, loop1 * loop2), {}
					for i = 1, #confi do
						if mode == "shape2" and i % 2 == 0 then
							shapes[(i - 1) % #shapes + 1] = shapes[(i - 1) % #shapes + 1]:__inv()
						end
						shp_array[i] = shapes[(i - 1) % #shapes + 1]:displace("incenter"):rotate(confi[i][2]):displace(confi[i][1]).code
					end --ke.shape.array(ke.shape.size(ke.shape.rectangle, 10, 30), 24, "shape2", ke.shape.circle)
					return ke.shape.new(table.concat(shp_array)):displace("origin")
				elseif mode == "radial3" then
					local radio_array, arcox
					for i = 1, #shapes do
						shape_array[i], widths[i] = {}, shapes[i].width + distance_r
						shp_lefts[i] = shp_lefts[i - 1] + widths[i - 1]
						for k = 1, loop2 do
							shape_array[i][k] = shapes[i]:displace("origin"):displace((k - 1) * widths[i], -0.5 * shapes[i].height).code
						end
						shape_array[i] = ke.shape.new(table.concat(shape_array[i]))
					end
					for i = 1, loop1 do
						idx = (i - 1) % #shapes + 1
						radio_array = loop1 ~= 1 and radius_ini + (radius_fin - radius_ini) * (i - 1) / (loop1 - 1) or radius_ini
						arcox = (loop1 > 1 and arco % 360 ~= 0) and (i - 1) * arco / (loop1 - 1) or (i - 1) * arco / loop1
						shape_radial_fx[i] = shape_array[idx]:displace(radio_array):rotate(angle_ini + arcox).code
					end --ke.shape.array(ke.shape.size(ke.shape.rectangle, 15, 45), 8, "radial3", 25)
					return ke.shape.new(table.concat(shape_radial_fx)):displace("origin")
				elseif mode == "radial" or mode == "radial1" or mode == "radial2" then
					local radio_array, arcox
					for i = 1, loop2 do
						idx = (i - 1) % #shapes + 1
						shape_array[i] = shapes[idx]:displace("origin"):displace(0, -0.5 * shapes[idx].height)
						widths[i] = shapes[idx].width + distance_r
						shp_lefts[i] = shp_lefts[i - 1] + widths[i - 1]
						shape_radial[i] = shape_array[i]:displace(shp_lefts[i]).code
					end --ke.shape.array({"m 0 0 l 0 10 l 10 10 l 10 0 ", "m 0 10 l 10 10 l 5 0 "}, 8, "radial2", 20).code
					shape_radial = ke.shape.new(table.concat(shape_radial))
					local shape_reverse = shape_radial:clone()
					for i = 1, loop1 do
						radio_array = loop1 ~= 1 and radius_ini + (radius_fin - radius_ini) * (i - 1) / (loop1 - 1) or radius_ini
						arcox = (loop1 > 1 and arco % 360 ~= 0) and (i - 1) * arco / (loop1 - 1) or (i - 1) * arco / loop1
						shape_reverse = (i % 2 == 0 and mode == "radial2") and shape_reverse:__inv() or shape_reverse
						shape_radial_fx[i] = shape_reverse:displace(radio_array):rotate(angle_ini + arcox).code
					end --ke.shape.array(ke.shape.size(ke.shape.rectangle, 15, 45), 8, "radial2", 25)
					return ke.shape.new(table.concat(shape_radial_fx)):displace("origin")
				elseif mode == "array" then
					for i = 1, loop2 do
						idx = (i - 1) % #shapes + 1
						shapes[idx] = shapes[idx]:displace("origin")
						heights[i] = shapes[idx].height + distance_y
						shp_tops[i] = shp_tops[i - 1] + heights[i - 1]
						shape_rectangular[i] = {}
						for k = 1, loop1 do
							shape_rectangular[i][k] = shapes[idx]:displace((k - 1) * shapes[idx].width + distance_x * (k - 1)).code
						end
						shape_rectangular[i] = ke.shape.new(table.concat(shape_rectangular[i])):displace(0, shp_tops[i])
						shape_rectangular_widths[i] = shape_rectangular[i].width
					end
					shape_rectangular_maxwidths = math.max(table.unpack(shape_rectangular_widths))
					for i = 1, loop2 do
						shape_rectangular[i] = shape_rectangular[i]:displace((shape_rectangular_maxwidths - shape_rectangular[i].width) / 2).code
					end --ke.shape.array(ke.shape.size(ke.shape.rectangle, 15, 15), {4, 5}, "array", 5)
					return ke.shape.new(table.concat(shape_rectangular))
				end
				for i = 1, loop1 do
					idx = (i - 1) % #shapes + 1
					shape_lineal[i] = shapes[idx]:rotate(angle_shape - angle_array):displace("origin")
					shape_lineal[i] = shape_lineal[i]:displace(0, -0.5 * shape_lineal[i].height)
					widths[i] = shape_lineal[i].width + distance_x
					shp_lefts[i] = shp_lefts[i - 1] + widths[i - 1]
					shape_lineal_fx[i] = shape_lineal[i]:displace(shp_lefts[i]).code
				end --ke.shape.array(ke.shape.size(ke.shape.rectangle, 25, 25), 5, nil, 10)
				return ke.shape.new(table.concat(shape_lineal_fx)):rotate(angle_array):displace("origin")
			end,
			
			inbounding = function(self, angle)
				--point in bounding
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local box = {self:box()}
				local angle = angle or 0
				local centroid = self.centroid
				local p = centroid:polar(angle, self.radius + 10)
				for i = 1, 4 do
					local newp = centroid:intersect(p, box[i], box[i % 4 + 1])
					if newp then
						return newp, newp:distance(centroid)
					end
				end
			end, --ke.shape.inbounding(ke.shape.rectangle, 15)
			
			inboundary = function(self, angle)
				--point in principal boundary shape
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local angle = angle or 0
				for _, s in ipairs(self) do
					local centroid = s.centroid
					local p = centroid:polar(angle, s.radius + 10)
					local points = s:points()
					local n = #points
					for i = 1, n do
						local newp = centroid:intersect(p, points[i], points[i % n + 1])
						if newp then
							return newp, newp:distance(centroid)
						end
					end
					break
				end
				return nil
			end, --ke.shape.inboundary(ke.shape.rectangle, 15)
			
			inconvex = function(self, angle)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local points = self:points()
				local convexscan = ke.shape.point.toconvex(points)
				local angle = angle or 0
				local centroid = self.centroid
				local p = centroid:polar(angle, self.radius + 10)
				local n = #convexscan
				for i = 1, n do
					local newp = centroid:intersect(p, convexscan[i], convexscan[i % n + 1])
					if newp then
						return newp, newp:distance(centroid)
					end
				end
			end, --ke.shape.inconvex(ke.shape.rectangle, 15)
			
			matrix = function(self, m)
				--applies a transformation through one matrix
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				m = ke.math.matrix.new(m)
				local shapes = {}
				for i, s in ipairs(self) do
					local points = s:points()
					shapes[i] = ke.shape.new(points:filter(function(i, p) return p * m end)).code
				end
				self.code = table.concat(shapes)
				return self
			end, --ke.shape.matrix(ke.shape.rectangle, {1, 0, 0, 0, math.sin(45), 0, 0, 0, math.cos(45)})
			
			bars = function(self, tags, vertical)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				self = self:redraw(4, "bezier")
				local x0, y0, x1, y1 = self:bounding()
				local tags = tags or function(i, n) return ("\\1c%s"):format(ke.color.HSV_to_RGB(30 + 90 * i / n)) end
				local exteriors, holes = {}, {} --ass format
				for _, s in ipairs(self) do
					table.insert(s:isclockwise() and holes or exteriors, s:points())
				end
				local v, helpers = vertical
				helpers = {
					inside = function(p, poly)
						local result = false
						local j = #poly
						for i = 1, #poly do
							local pi, pj = poly[i], poly[j]
							if ((pi.y > p.y) ~= (pj.y > p.y)) and
								(p.x < (pj.x - pi.x) * (p.y - pi.y) / ((pj.y - pi.y) + EPSILON) + pi.x) then
								result = not result
							end
							j = i
						end
						return result
					end,
					
					getbars = function(pixels)
						local fsort = v and function(p, q) return p.x == q.x and p.y < q.y or p.x < q.x end --"vertical"
							or function(p, q) return p.y == q.y and p.x < q.x or p.y < q.y end --"horizontal"
						table.sort(pixels, fsort)
						local bars, current, ini, fin = {}, nil, nil, nil
						for i, p in ipairs(pixels) do
							local fixed, axis = v and p.x or p.y, v and p.y or p.x
							if fixed ~= current or (fin and axis ~= fin + 1) then
								if ini then
									table.insert(bars, {x = v and current or ini, y = v and ini or current, l = fin - ini + 1})
								end
								current, ini = fixed, axis
							end
							fin = axis
						end
						if ini and fin then
							table.insert(bars, {x = v and current or ini, y = v and ini or current, l = fin - ini + 1})
						end
						return bars
					end,
					
					bargroup = function(pixels)
						local bars = helpers.getbars(pixels)
						local groups = {}, {}
						for _, b in ipairs(bars) do
							local key = v and b.x or b.y
							if not groups[key] then
								groups[key] = {b}
							else
								table.insert(groups[key], b)
							end				
						end
						return ke.table.get(groups, "idx")
					end,
					
					bars2shape = function(pixels)
						local bars = helpers.bargroup(pixels)
						local n = #bars
						bars[0] = {{x = x0 - 1, y = y0 - 1}}
						local shapes, shp = {}, "%s %s %s %s %s %s %s %s "
						for i, bar in ipairs(bars) do
							shapes[i] = ("m %s %s l "):format(x0, y0)
							local nx, ny, add
							if v then
								for k, b in ipairs(bar) do
									ny = not ny and b.y or ny
									nx = b.x - bars[i - 1][1].x - 1
									shapes[i] = shapes[i] .. shp:format(nx, b.y, nx + 1, b.y, nx + 1, b.y + b.l, nx, b.y + b.l)
								end
							else
								for k, b in ipairs(bar) do
									nx = not nx and b.x or nx
									ny = b.y - bars[i - 1][1].y - 1
									shapes[i] = shapes[i] .. shp:format(b.x, ny, b.x, ny + 1, b.x + b.l, ny + 1, b.x + b.l, ny)
								end
							end
							add = v and ("%s %s %s %s "):format(nx, y1, nx, ny) or ("%s %s %s %s "):format(x1, ny, nx, ny)
							shapes[i] = ("{%s\\p1}"):format(type(tags) == "function" and tags(i, n) or tags) .. shapes[i] .. add
							shapes[i] = shapes[i]:gsub("(%d+ %d+) l (%d+ %d+)", function(p, q) return p == q and p .. " l" or p .. " l " .. q end)
							shapes[i] = shapes[i] .. (not v and "{\\p0}\\N" or "")
						end
						return table.concat(shapes)
					end
				}
				local pixels = {}
				for y = math.floor(y0), math.ceil(y1) do
					for x = math.floor(x0), math.ceil(x1) do
						local total = 0
						local p = ke.shape.point.new(x + 0.5, y + 0.5)
						local isinside, ec, hc = false, 0, 0
						for _, ext in ipairs(exteriors) do
							if helpers.inside(p, ext) then
								isinside = true
								ec = ec + 1
							end
						end
						if isinside then
							for _, h in ipairs(holes) do
								if helpers.inside(p, h) then
									hc = hc + 1
								end
							end
						end
						isinside = isinside and ((hc > 0 and (ec + hc) % 2 == 1) and true or (hc == 0 and true or false)) or false
						if isinside then
							total = total + 1
						end
						if total > 0 then
							table.insert(pixels, {x = x, y = y})
						end
					end
				end
				return helpers.bars2shape(pixels)
			end,
			
			splitmove = function(self)
				local self = type(self) == "function" and self() or self
				self = type(self) == "string" and ke.shape.new(self) or self
				local segs = self:__seg()
				local result = ke.table.new()
				for _, s in ipairs(segs) do
					if s.t == "m" then
						result:insert(s)
					elseif s.t == "l" then
						local x0, y0, x1, y1 = s[0].x, s[0].y, s[1].x, s[1].y
						if y0 * y1 < 0 then
							local p = ke.shape.point.new(x0 + (-y0 / (y1 - y0)) * (x1 - x0), 0)
							result:insert(ke.shape.segment.new({s[0], p}))
							result:insert(ke.shape.segment.new({p, s[1]}))
						else
							result:insert(s)
						end
					elseif s.t == "b" then
						local y0, y1, y2, y3 = s[0].y, s[1].y, s[2].y, s[3].y
						local a, b = -y0 + 3 * y1 - 3 * y2 + y3, 3 * y0 - 6 * y1 + 3 * y2
						local c, d = -3 * y0 + 3 * y1, y0
						local roots = ke.math.cubic(a, b, c, d):filter(function(k, v) return (v >= 0 and v <= 1) and v or nil end)
						local curve, ini, c1, c2, u = s, 0
						for _, t in ipairs(roots) do
							u = (t - ini) / (1 - ini)
							c1, c2 = curve:cut(u)
							ini = t
							result:insert(c1)
							curve = c2
						end
						result:insert(c2 or s)
					end
				end
				self.code = ke.shape.new(result).code
				return self
			end,
			
		},
		
		color = {
			
			ass = function(R, G, B)
				--xy-vsfilter format color
				local R = type(R) == "function" and R() or R or 255
				if type(R) == "table" and ke.table.type(R) ~= "number" then
					return ke.table.recursive(R, ke.color.ass, G, B)
				end --recurse
				local G = type(G) == "function" and G() or G or 255
				local B = type(B) == "function" and B() or B or 255
				if type(R) == "table" then
					R, G, B = R[1], R[2], R[3]
				end
				local color
				if type(R) == "string" and R:match("%x%x%x%x%x%x") then
					color = R:gsub("%#(%x%x)(%x%x)(%x%x)", "&H%3%2%1&")				--HTML to ass
					:gsub("%x%x(%x%x%x%x%x%x)", "&H%1&")							--color fromstyle
					color = "&H" .. R:match("[%&Hh]*(%x%x%x%x%x%x)[%&]*") .. "&"	--from error
				elseif type(tonumber(R)) == "number" then
					local iR = ke.math.count(tonumber(R) + 1)
					local iG = ke.math.count(tonumber(G) + 1)
					local iB = ke.math.count(tonumber(B) + 1)
					R = ke.math.to16(iR("ABA", 0, 255))
					G = ke.math.to16(iG("ABA", 0, 255))
					B = ke.math.to16(iB("ABA", 0, 255))
					R = R:len() == 1 and "0" .. R or R
					G = G:len() == 1 and "0" .. G or G
					B = B:len() == 1 and "0" .. B or B
					color = "&H" .. B .. G .. R .. "&"
				end
				return color --ke.color.ass("#AA00FF")
			end,
			
			to_RGB = function(color)
				--retorna una tabla con los valores RGB del color ingresado
				local color = ke.color.ass(type(color) == "function" and color() or color or "&HFFFFFF&")
				local B, G, R = color:match("(%x%x)(%x%x)(%x%x)")
				return {tonumber(R, 16), tonumber(G, 16), tonumber(B, 16)}
			end, --ke.color.to_RGB("&HAAF0B7&")
			
			to_HSV = function(color)
				--retorna una tabla con los valores HSV del color ingresado
				local color = ke.color.ass(type(color) == "function" and color() or color or "&HFFFFFF&")
				local R, G, B = table.unpack(ke.color.to_RGB(color))
				R, G, B = R / 255 + 0.000001, G / 255, B / 255
				local cmax, cmin = math.max(R, G, B), math.min(R, G, B)
				local dval = cmax - cmin
				local H = cmax == R and ke.math.round(60 * (((G - B) / dval) % 6), 3)
				or (cmax == G and ke.math.round(60 * (((B - R) / dval) + 2), 3))
				or ke.math.round(60 * (((R - G) / dval) + 4), 3)
				local S, V = ke.math.round(dval / cmax, 3), ke.math.round(cmax, 3)
				return {H, S, V}
			end, --ke.color.to_HSV("&HAAF0B7&")
			
			HSV_to_RGB = function(H, S, V)
				--HSV to ass color format
				local H = type(H) == "function" and H() or H or 0
				local S = type(S) == "function" and S() or S or 1
				local V = type(V) == "function" and V() or V or 1
				if type(H) == "table" then
					V, S, H = H[3], H[2], H[1]
				end
				H = ((H - 1) % 360 + 1) / 360 * 6
				S = ((1000 * S) % 1001) / 1000
				V = ((1000 * V) % 1001) / 1000
				if S == 0 or V == 0 then
					return S == 0 and "&HFFFFFF&" or "&H000000&"
				end
				local C = V * S
				local M = V - C
				local X = C * (1 - math.abs((H % 2) - 1))
				local R = H < 1 and C or H < 2 and X or H < 3 and 0 or H < 4 and 0 or H < 5 and X or C
				local G = H < 1 and X or H < 2 and C or H < 3 and C or H < 4 and X or H < 5 and 0 or 0
				local B = H < 1 and 0 or H < 2 and 0 or H < 3 and X or H < 4 and C or H < 5 and C or X
				return ke.color.ass(255 * (R + M), 255 * (G + M), 255 * (B + M))
			end, --ke.color.HSV_to_RGB(128, 1, 1)
			
			random = function(H, S, V)
				local H = type(H) == "function" and H() or H or ke.math.rand(360)
				local S = type(S) == "function" and S() or S or 100
				local V = type(V) == "function" and V() or V or 100
				local iS, iV = ke.math.count(S + 1), ke.math.count(V + 1)
				H = type(H) == "table" and ke.math.rand((H[1] - 1) % 360 + 1, (H[2] - 1) % 360 + 1)
				or (type(H) == "number" and (H - 1) % 360 + 1) or ke.math.rand(360)
				S = type(S) == "table" and ke.math.rand(S[2] % 101, S[1] % 101) / 100
				or (type(S) == "number" and iS("ABA", 0, 100) / 100) or 100
				V = type(V) == "table" and ke.math.rand(V[2] % 101, V[1] % 101) / 100
				or (type(V) == "number" and iV("ABA", 0, 100) / 100) or 100
				return ke.color.HSV_to_RGB(H, S, V)
			end, --ke.color.random()
			
			interpolate = function(t, color1, color2)
				--interpolate_color
				local color1 = type(color1) == "function" and color1() or color1 or "&HFFFFFF&"
				local color2 = type(color2) == "function" and color2() or color2 or "&H0000FF&"
				if type(color1) == "table" then
					return ke.table.new(#color1, function(i) return ke.color.interpolate(t, color1[i], color2) end)
				elseif type(color2) == "table" then --ke.color.interpolate(0.6, {"&HFF00FF&", "&H00FF00&"}, "&HFFFFFF&")
					return ke.table.new(#color2, function(i) return ke.color.interpolate(t, color1, color2[i]) end)
				end --ke.color.interpolate(0.6, "&HFFFFFF&", {"&HFF00FF&", "&H00FF00&"})
				color1, color2 = ke.color.ass(color1), ke.color.ass(color2)
				local B1, G1, R1 = color1:match("(%x%x)(%x%x)(%x%x)")
				local B2, G2, R2 = color2:match("(%x%x)(%x%x)(%x%x)")
				R1, G1, B1 = tonumber(R1, 16), tonumber(G1, 16), tonumber(B1, 16)
				R2, G2, B2 = tonumber(R2, 16), tonumber(G2, 16), tonumber(B2, 16)
				local t = type(t) == "function" and t() or t or 0.5
				t = ke.math.normalize(t) --{t = 0.7, shape = ke.shape.circle, accel = 1.2}
				local R = ke.math.round(R1 + (R2 - R1) * t)
				local G = ke.math.round(G1 + (G2 - G1) * t)
				local B = ke.math.round(B1 + (B2 - B1) * t)
				return ke.color.ass(R, G, B)
			end, --ke.color.interpolate(0.5, "&HFFFFFF&", "&H0000FF&")
			
			set = function(times, colors, ...)
				local times = type(times) == "function" and times() or times
				local colors = ke.color.ass(type(colors) == "function" and colors() or colors)
				local concats = {...} --... = \\1c, \\3c or \\4c
				local fx = ke.infofx.fx
				concats = #concats == 0 and {"\\1c"} or concats
				times = ke.table.new(ke.time.HMS_to_ms(times))
				times:insert({fx.time_ini, fx.time_fin}, nil, true)
				times = times("org")
				local times2 = ke.table.copy(times)
				local ini, fin = ke.table.index(times, fx.time_ini), ke.table.index(times, fx.time_fin)
				colors[0] = #colors >= #times - 1 and colors[#times - 1] or "&HFFFFFF&"
				local t1, t2, offset, accel, idx = 0, 1, 1, 1, ini + 1
				for i = 0, #colors do
					colors[i] = type(colors[i]) == "function" and colors[i]() or colors[i]
					colors[i] = type(colors[i]) == "table" and colors[i][(fx.i - 1) % #colors[i] + 1] or colors[i]
					local tagcolor = ""
					for k = 1, #concats do
						tagcolor = tagcolor .. concats[k] .. colors[i]
					end
					colors[i] = tagcolor
				end
				local tags = colors[idx - 2]
				for i = 1, #times do
					times[i] = type(times[i]) == "table" and times[i][1] or times[i]
				end
				if ini + 1 ~= fin then
					while times[idx] < fx.time_fin do
						offset = type(times2[idx]) == "table" and times2[idx][2] or offset
						accel  = type(times2[idx]) == "table" and times2[idx][3] or 1
						t1 = ke.math.clamp(times[idx] - fx.time_ini - 20, 0, math.huge)
						t2 = t1 + offset
						tags = tags .. ("\\t(%s,%s,%s,%s)"):format(t1, t2, accel, colors[idx - 1])
						idx, offset = idx + 1, 1
					end --timex = {"0:00:59.101", "0:01:02.145", "0:01:04.147"}; colorx = {"&H00FFFF&", "&HB82913&", "&H0C0DF7&"}
				end
				return tags --ke.color.set(timex, colorx, "\\1c")
			end,
			
		},
		
		alpha = {
			
			ass = function(alpha, number)
				--le da el formato xy-vsfilter a los alphas
				local alpha = type(alpha) == "function" and alpha() or alpha or "00"
				if type(alpha) == "table" then
					return ke.table.recursive(alpha, ke.alpha.ass, number)
				end --recurse
				alpha = type(tonumber(alpha)) == "number" and ("%X"):format(math.ceil(alpha) % 256)
				or ((type(alpha) == "string" and alpha:match("[&H]*%x%x[&]*")) and alpha:match("[&H]*(%x%x)[&]*")) or alpha
				alpha = (type(alpha) == "string" and alpha:len() == 1) and "0" .. alpha or alpha
				assert(type(alpha) == "string" and alpha:match("(%x%x)"), "Error in alpha.ass: number or alpha expected, got " .. type(alpha))
				alpha = alpha:gsub("(%x+)", "&H%1&") --ke.alpha.ass({x = "(FF,00,AA,0F)", "#F0"})
				return number and tonumber(alpha:match("(%x%x)"), 16) or alpha
			end, --ke.alpha.ass({0, 45, 86, 255})
			
			random = function(alpha1, alpha2)
				local alpha1 = type(alpha1) == "function" and alpha1() or alpha1 or 0
				local alpha2 = type(alpha2) == "function" and alpha2() or alpha2 or 255
				alpha1, alpha2 = ke.alpha.ass(alpha1, true), ke.alpha.ass(alpha2, true)
				return ke.alpha.ass(ke.math.rand(alpha2, alpha1))
			end, --ke.alpha.random()
			
			interpolate = function(t, alpha1, alpha2)
				--interpolate_alpha
				local alpha1 = type(alpha1) == "function" and alpha1() or alpha1 or "&HFF&"
				local alpha2 = type(alpha2) == "function" and alpha2() or alpha2 or "&H00&"
				if type(alpha1) == "table" then
					return ke.table.new(#alpha1, function(i) return ke.alpha.interpolate(t, alpha1[i], alpha2) end)
				elseif type(alpha2) == "table" then
					return ke.table.new(#alpha2, function(i) return ke.alpha.interpolate(t, alpha1, alpha2[i]) end)
				end
				alpha1, alpha2 = ke.alpha.ass(alpha1, true), ke.alpha.ass(alpha2, true)
				local t = type(t) == "function" and t() or t or 0.5
				t = ke.math.normalize(t) --{t = 0.7, shape = ke.shape.circle, accel = 1.2}
				return ke.alpha.ass(alpha1 + t * (alpha2 - alpha1))
			end, --ke.alpha.interpolate(0.5, "&HFF&", 55)
			
		},
		
		text = {
			
			to_shape = function(text, scale, without)
				local text = text or ke.infofx.fx.text
				while text:sub(-1, -1) == " " do
					text = text:sub(1, -2)
				end
				local scale = scale or 1
				local style = ke.infofx.l.style
				if ke.infofx.l.text_raw:match("%b{}") then --extract tag settings from line text
					tagx = ke.infofx.l.text_raw:match("%b{}")
					style.fontname = tagx:match("\\fn(%S+[^\\]*)") and tagx:match("\\fn(%S+[^\\]*)") or style.fontname
					style.bold = tagx:match("\\b%d") and (tagx:match("\\b(%d)") == "1" and true or false) or style.bold
					style.italic = tagx:match("\\i%d") and (tagx:match("\\i(%d)") == "1" and true or false) or style.italic
					style.underline = tagx:match("\\u%d") and (tagx:match("\\u(%d)") == "1" and true or false) or style.underline
					style.strikeout = tagx:match("\\s%d") and (tagx:match("\\s(%d)") == "1" and true or false) or style.strikeout
					style.fontsize = tagx:match("\\fs(%d[%.%d]*)") and tonumber(tagx:match("\\fs(%d[%.%d]*)")) or style.fontsize
					style.scale_x = tagx:match("\\fscx(%d[%.%d]*)") and tonumber(tagx:match("\\fscx(%d[%.%d]*)")) or style.scale_x
					style.scale_y = tagx:match("\\fscy(%d[%.%d]*)") and tonumber(tagx:match("\\fscy(%d[%.%d]*)")) or style.scale_y
					style.spacing = tagx:match("\\fsp(%-?%d[%.%d]*)") and tonumber(tagx:match("\\fsp(%-?%d[%.%d]*)")) or style.spacing
				end --thank to Zeref Sama
				local configtxt = {
					[1] = style.fontname,				[2] = style.bold,
					[3] = style.italic,					[4] = style.underline,
					[5] = style.strikeout,				[6] = style.fontsize,
					[7] = style.scale_x * scale / 100,	[8] = style.scale_y * scale / 100,
					[9] = style.spacing
				}
				local text_font = ke.decode.create_font(table.unpack(configtxt))
				local text_shape = ke.shape.new(text_font.text_to_shape(text))
				if without then
					return text_shape.code
				end
				local width, height = aegisub.text_extents(style, text)
				local text_off_x = 0.5 * (text_shape.width - scale * width)
				local text_off_y = 0.5 * (text_shape.height - scale * height)
				return text_shape:displace(text_off_x, text_off_y).code
			end, --ke.text.to_shape(fx.text)
			
			bezier = function(shp, mode, offset)
				local l, fx = ke.infofx.l, ke.infofx.fx
				local shp = type(shp) == "function" and shp() or shp
				shp = (not shp and l.text_raw:match("\\i?clip%b()")) and l.text_raw:match("\\i?clip%b()") or shp
				shp = type(shp) == "string" and ke.shape.new(shp) or shp
				local offset, lineoffset, blength = offset or 0, 0, shp:length()
				lineoffset = mode == 2 and offset						--alinea el texto desde la izquierda
				or (mode == 3 and blength - l.width - offset)			--alinea el texto desde la derecha
				or (mode == 4 and (blength - l.width) * offset)			--justifica el texto en toda la longitud de la shape: offset = (ci - 1) / (cn - 1)
				or (mode == 5 and (blength - l.width) * (1 - offset))	--anima el texto de fin a inicio de la shape
				or (blength - l.width) / 2 + offset						--modo por default (centro de la shape)(mode == 1)
				--!maxloop(orgline.duration / frame_dur)!!retime("preline", frame_dur * (j - 1), frame_dur * j)!
				--{\an5!_G.ke.text.bezier(line, nil, $x, $y, 5, (j - 1) / (maxj - 1))!}
				local target = lineoffset + fx.center - l.left
				local pos, angle = shp:parameter({target})
				return target > blength and ("\\pos(%s,%s)"):format(fx.center, fx.middle)
				or ("\\pos(%s,%s)\\fr%s"):format(pos.x, pos.y, angle - 90)
			end, --ke.text.bezier("m 108 466 b 310 535 268 297 356 294 566 278 571 474 702 534 917 631 748 109 1140 106")
			
			romaji = {
				"kya",	"kyu",	"kyo",	"sha",	"shu",	"sho",	"cha",	"chu",	"cho",
				"nya",	"nyu",	"nyo",	"hya",	"hyu",	"hyo",	"mya",	"myu",	"myo",
				"rya",	"ryu",	"ryo",	"gya",	"gyu",	"gyo",	"bya",	"byu",	"byo",
				"pya",	"pyu",	"pyo",	"shi",	"chi",	"tsu",
				"ya",	"yu",	"yo",	"ka",	"ki",	"ku",	"ke",	"ko",	"sa",
				"su",	"se",	"so",	"ta",	"te",	"to",	"na",	"ni",	"nu",
				"ne",	"no",	"ha",	"hi",	"fu",	"he",	"ho",	"ma",	"mi",
				"mu",	"me",	"mo",	"ya",	"yu",	"yo",	"ra",	"ri",	"ru",
				"re",	"ro",	"wa",	"wi",	"we",	"wo",	"ga",	"gi",	"gu",
				"ge",	"go",	"za",	"ji",	"zu",	"ze",	"zo",	"ja",	"ju",
				"jo",	"da",	"di",	"du",	"de",	"do",	"ba",	"bi",	"bu",
				"be",	"bo",	"pa",	"pi",	"pu",	"pe",	"po",
				"a",	"i",	"u",	"e",	"o",	"n",	"b",	"c",	"d",
				"k",	"p",	"r",	"s",	"t",	"z"
			},
			
			hiragana = {
				"あ",	"い",	"う",	"え",	"お",	"ゃ",	"ゅ",	"ょ",
				"か",	"き",	"く",	"け",	"こ",	"きゃ",	"きゅ",	"きょ",
				"さ",	"し",	"す",	"せ",	"そ",	"しゃ",	"しゅ",	"しょ",
				"た",	"ち",	"つ",	"て",	"と",	"ちゃ",	"ちゅ",	"ちょ",
				"な",	"に",	"ぬ",	"ね",	"の",	"にゃ",	"にゅ",	"にょ",
				"は",	"ひ",	"ふ",	"へ",	"ほ",	"ひゃ",	"ひゅ",	"ひょ",
				"ま",	"み",	"む",	"め",	"も",	"みゃ",	"みゅ",	"みょ",
				"や",			"ゆ",			"よ",
				"ら",	"り",	"る",	"れ",	"ろ",	"りゃ",	"りゅ",	"りょ",
				"わ",	"ゐ",			"ゑ",	"を",
				"ん",
				"が",	"ぎ",	"ぐ",	"げ",	"ご",	"ぎゃ",	"ぎゅ",	"ぎょ",
				"ざ",	"じ",	"ず",	"ぜ",	"ぞ",	"じゃ",	"じゅ",	"じょ",
				"だ",	"ぢ",	"づ",	"で",	"ど",
				"ば",	"び",	"ぶ",	"べ",	"ぼ",	"びゃ",	"びゅ",	"びょ",
				"ぱ",	"ぴ",	"ぷ",	"ぺ",	"ぽ",	"ぴゃ",	"ぴゅ",	"ぴょ",
				"っ",	"っ",	"っ",	"っ",	"っ",	"っ",	"っ",	"っ",
				"っ"
			},
			
			katakana = {
				"ア",	"イ",	"ウ",	"エ",	"オ",	"ャ",	"ュ",	"ョ",
				"カ",	"キ",	"ク",	"ケ",	"コ",	"キャ",	"キュ",	"キョ",
				"サ",	"シ",	"ス",	"セ",	"ソ",	"シャ",	"シュ",	"ショ",
				"タ",	"チ",	"ッ",	"テ",	"ト",	"チャ",	"チュ",	"チョ",
				"ナ",	"ニ",	"ヌ",	"ネ",	"ノ",	"ニャ",	"ニュ",	"ニョ",
				"ハ",	"ヒ",	"フ",	"ヘ",	"ホ",	"ヒャ",	"ヒュ",	"ヒョ",
				"マ",	"ミ",	"ム",	"メ",	"モ",	"ミャ",	"ミュ",	"ミョ",
				"ヤ",			"ユ",			"ヨ",
				"ラ",	"リ",	"ル",	"レ",	"ロ",	"リャ",	"リュ",	"リョ",
				"ワ",	"ヰ",			"ヱ",	"ヲ",
				"ン",
				"ガ",	"ギ",	"グ",	"ゲ",	"ゴ",	"ギャ",	"ギュ",	"ギョ",
				"ザ",	"ジ",	"ズ",	"ゼ",	"ゾ",	"ジャ",	"ジュ",	"ジョ",
				"ダ",	"ヂ",	"ヅ",	"デ",	"ド",
				"バ",	"ビ",	"ブ",	"ベ",	"ボ",	"ビャ",	"ビュ",	"ビョ",
				"パ",	"ピ",	"プ",	"ペ",	"ポ",	"ピャ",	"ピュ",	"ピョ",
				"ッ",	"ッ",	"ッ",	"ッ",	"ッ",	"ッ",	"ッ",	"ッ",
				"ッ"
			},
			
			char_upper = {
				"A",	"B",	"C",	"D",	"E",	"F",	"G",	"H",	"I",
				"J",	"K",	"L",	"M",	"N",	"Ñ",	"O",	"P",	"Q",
				"R",	"S",	"T",	"U",	"V",	"W",	"X",	"Y",	"Z"
			}, --string.char(R(97, 122))
			
			char_lower = {
				"a",	"b",	"c",	"d",	"e",	"f",	"g",	"h",	"i",
				"j",	"k",	"l",	"m",	"n",	"ñ",	"o",	"p",	"q",
				"r",	"s",	"t",	"u",	"v",	"w",	"x",	"y",	"z"
			}, --string.char(R(65, 90))
			
			char_number = {
				"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
			}, --string.char(R(48, 57))
			
			char_special = {
				"°",	"¬",	"¡",	"!",	"¿",	"?",	"(",	")",	"[",
				"]",	"^",	"'",	"-",	"#",	"$",	"%",	"&",	";",
				":",	",",	".",	"<",	">",	"*",	"~",	"´",	"`",
				"¨",	"+",	"/",	"{",	"}",	"|",	"_",	"\\",	"\""
			},
			
			to_upper = function(text)
				--converts text to uppercase without affecting tags
				local text = text or "ke.text.to_upper"
				if type(text) == "table" then
					return ke.table.recursive(text, ke.text.to_upper)
				end --recurse
				local tag_text, k = ke.string.array(text, "%b{}"), ke.math.count()
				text = text:gsub("%b{}", "@")
				text = unicode.to_upper_case(text):gsub("@", function(cap) return tag_text[k()] end)
				return text
			end, --ke.text.to_upper(fx.text)
			
			to_lower = function(text)
				--converts text to lowercase without affecting tags
				local text = text or "ke.text.to_lower"
				if type(text) == "table" then
					return ke.table.recursive(text, ke.text.to_lower)
				end --recurse
				local tag_text, k = ke.string.array(text, "%b{}"), ke.math.count()
				text = text:gsub("%b{}", "@")
				text = unicode.to_lower_case(text):gsub("@", function(cap) return tag_text[k()] end)
				return text
			end, --ke.text.to_lower(fx.text)
			
			to_kara = function(text, kmode)
				local kmode, num = kmode or "k", 0
				kmode = not ke.table.inside({"k", "kf", "ko", "K"}, kmode) and "k" or kmode
				local words, times = ke.config.text2word(ke.text.to_lower(ke.config.remove_tags(text)))
				for i = 1, #words do
					for k = 1, #ke.text.romaji do
						words[i] = words[i]:gsub("[\128-\255]*" .. ke.text.romaji[k], "[%1]")
					end
					words[i], num = words[i]:gsub("%b[]", "%1")
					words[i] = words[i]:gsub("%b[]",
						function(capture)
							return format("{\\%s%d}%s", kmode, times[i] / (num * 10), capture:gsub("%[", ""):gsub("%]", ""))
						end
					)
				end
				return table.concat(words)
			end, --ke.text.to_kara(line.text)
			
			text2part = function(text, duration, parts)
				local style = ke.infofx.l.style
				local fx = ke.infofx.fx
				local function _width(str)
					local txt_width = aegisub.text_extents(style, str)
					return txt_width
				end
				local text, duration = text or fx.text, duration or fx.time_dur
				local durs, parts, left_spc = {}, parts or 2
				local parts_in_text = ke.string.parts(text, parts)
				local widths, lefts = {[0] = 0}, {[0] = fx.left}
				local char_dur = ke.math.round(duration / unicode.len(text), ROUND_NUM)
				for i = 1, #parts_in_text do
					left_spc = ""
					durs[i] = unicode.len(parts_in_text[i]) * char_dur
					while parts_in_text[i]:sub(1, 1) == " " or parts_in_text[i]:sub(1, 1) == "	" do
						left_spc = left_spc .. parts_in_text[i]:sub(1, 1)
						parts_in_text[i] = parts_in_text[i]:sub(2, -1)
					end
					widths[i] = _width(parts_in_text[i])
					lefts[i] = ke.math.round(lefts[i - 1] + widths[i - 1] + _width(left_spc), ROUND_NUM)
				end
				local rights, centers = {}, {}
				for i = 1, #parts_in_text do
					while parts_in_text[i]:sub(-1, -1) == " " or parts_in_text[i]:sub(-1, -1) == "	" do
						parts_in_text[i] = parts_in_text[i]:sub(1, -2)
					end
					widths[i]  = ke.math.round(_width(parts_in_text[i]), ROUND_NUM)
					rights[i]  = ke.math.round(lefts[i] + widths[i], ROUND_NUM)
					centers[i] = ke.math.round(lefts[i] + widths[i] / 2, ROUND_NUM)
				end --ke.text.text2part(nil, nil, 5)
				widths[0], lefts[0] = nil, nil
				return parts_in_text, durs, centers, widths, lefts, rights
			end, --local p_txt, p_dur, p_cen, p_wid, p_lef, p_rig
			
			syl2hiragana = function(text)
				local roma_idx = ke.table.index(ke.text.romaji,   text:lower():match("%w+"))
				local kata_idx = ke.table.index(ke.text.katakana, text:match("[\128-\255]+"))
				return roma_idx and text:lower():gsub(ke.text.romaji[roma_idx], ke.text.hiragana[roma_idx])
				or (kata_idx and text:gsub(ke.text.katakana[kata_idx], ke.text.hiragana[kata_idx])) or text
			end, --ke.text.syl2hiragana(syl.text)
			
			syl2katakana = function(text)
				local roma_idx = ke.table.index(ke.text.romaji,   text:lower():match("%w+"))
				local hira_idx = ke.table.index(ke.text.hiragana, text:match("[\128-\255]+"))
				return roma_idx and text:lower():gsub(ke.text.romaji[roma_idx], ke.text.hiragana[roma_idx])
				or (hira_idx and text:gsub(ke.text.katakana[hira_idx], ke.text.hiragana[hira_idx])) or text
			end, --ke.text.syl2katakana(syl.text)
			
			kana2romaji = function(text)
				local hira_idx = ke.table.index(ke.text.hiragana, text:match("[\128-\255]+"))
				local kata_idx = ke.table.index(ke.text.katakana, text:match("[\128-\255]+"))
				return hira_idx and text:lower():gsub(ke.text.romaji[hira_idx], ke.text.hiragana[hira_idx])
				or (kata_idx and text:gsub(ke.text.katakana[kata_idx], ke.text.hiragana[kata_idx])) or text
			end,
			
			char2byte = function(text)
				local bytes, c = {}
				for c in unicode.chars(text) do
					bytes[#bytes + 1] = c:byte()
				end
				return bytes
			end,
			
			byte2char = function(Bytes)
				return string.char(table.unpack(Bytes))
			end,
			
			tag = function(text, ...)
				local tags = type(...) == "table" and ... or {...}
				local texttag, text, xval = "", text or "no text"
				local chars = ke.string.array(text, "chars"), {}
				local ipols = ke.table.new(#chars, "")
				local str2tbl = function(str)
					local tag, val = str:match("(\\%w+)(%b{})")
					val = val:gsub("&H%x+&", "\"%1\"")
					val = ke.string.toval(val)
					return type(val) == "table" and {tag, val} or nil
				end
				for i = 1, #chars do
					for k = 1, #tags do
						xval = str2tbl(tags[k])
						ipols[i] = xval and ipols[i] .. xval[1] .. ke.tag.interpolate((i - 1) / (#chars - 1), xval[2]) or ""
					end
					texttag = texttag .. (chars[i] == " " and " " or ("{%s}%s"):format(ipols[i], chars[i]))
				end
				return texttag
			end, --ke.text.tag(fx.text, "\\fscy{100, 200, 50}", "\\1c{&H00FFFF&, &HFF00FF&, &HFFFF00&}")
			
			rand = function(text, num_tran, dur_tran, tags, extra, mode, all)
				local fx = ke.infofx.fx
				local frame_dur = ke.infofx.frame_dur
				local text = text or fx.text
				local dur_tran = math.abs(dur_tran or 2 * frame_dur)
				local num_tran = math.abs(ke.math.round(num_tran or 5))
				local delay_tr = dur_tran * num_tran
				local del_tran, table_ch = 0, {}
				dur_tran = dur_tran < frame_dur and frame_dur or dur_tran
				if delay_tr == 0 or delay_tr > fx.time_dur then
					delay_tr = fx.time_dur
					num_tran = math.ceil(fx.time_dur / dur_tran)
				end
				for i = 48, 57 do --dígitos
					table_ch[#table_ch + 1] = string.char(i)
				end
				for i = 65, 90 do --minúsculas y mayúsculas
					table_ch[#table_ch + 1] = string.char(i)
					table_ch[#table_ch + 1] = string.char(i + 32)
				end
				local tbl_rand, extra_tg = extra or table_ch, tags or ""
				local time_ini = ke.math.rand(0, fx.time_dur - delay_tr, 5 * frame_dur)
				time_ini = (mode == "intro" or mode == "line") and 0 or (mode == "outro" and fx.time_dur - delay_tr) or time_ini
				local tbl_char, tbl_rtrn = ke.string.array(text, "chars"), {}
				local time_line = fx.time_dur - delay_tr
				local l = ke.infofx.l
				local Ad = (l.outline == 0 and l.shadow == 0) and ("\\1a%s"):format(l.alpha1)
				or (l.shadow == 0 and ("\\1a%s\\3a%s"):format(l.alpha1, l.alpha3))
				or (l.outline == 0 and ("\\1a%s\\4a%s"):format(l.alpha1, l.alpha4))
				or format("\\1a%s\\3a%s\\4a%s", l.alpha1, l.alpha3, l.alpha4)
				local Ai = (l.outline == 0 and l.shadow == 0) and "\\1a&HFF&" or (l.shadow == 0 and "\\1a&HFF&\\3a&HFF&")
				or (l.outline == 0 and "\\1a&HFF&\\4a&HFF&") or "\\1a&HFF&\\3a&HFF&\\4a&HFF&"
				for i = 1, #tbl_char do
					if tbl_char[i] ~= " " then
						if ke.table.inside(ke.text.char_special, tbl_char[i]) then
							tbl_rtrn[i] = ("{\\fscx%s}%s"):format(l.scale_x, tbl_char[i])
						else
							if mode == "line" then
								tbl_rtrn[i] = ("{%s\\fscx%s%s\\t(%s,%s,\\fscx0%s)\\t(%s,%s,\\fscx%s%s)\\t(%s,%s,\\fscx0%s)}%s"):format(
									ke.tag.default(extra_tg),
									l.scale_x, Ad, time_ini, time_ini + del_tran, Ai, time_ini + delay_tr, time_ini + delay_tr + del_tran,
									l.scale_x, Ad, time_line, time_line + del_tran, Ai, tbl_char[i]
								)
								for k = 1, num_tran do
									tbl_rtrn[i] = tbl_rtrn[i] .. ("{\\fscx0%s\\t(%s,%s,\\fscx%s%s%s)\\t(%s,%s,\\fscx0%s%s)\\t(%s,%s,\\fscx%s%s)\\t(%s,%s,\\fscx0%s)}%s"):format(
										Ai, time_ini + (k - 1) * dur_tran, time_ini + del_tran + (k - 1) * dur_tran, l.scale_x, Ad, extra_tg,
										time_ini + (k - 0) * dur_tran, time_ini + del_tran + (k - 0) * dur_tran, Ai, ke.tag.default(extra_tg),
										time_line + (k - 1) * dur_tran, time_line + del_tran + (k - 1) * dur_tran, l.scale_x, Ad,
										time_line + (k - 0) * dur_tran, time_line + del_tran + (k - 0) * dur_tran, Ai, ke.math.rand(tbl_rand)
									)
								end
							else
								tbl_rtrn[i] = ("{%s\\fscx%s%s\\t(%s,%s,\\fscx0%s)\\t(%s,%s,\\fscx%s%s)}%s"):format(
									ke.tag.default(extra_tg),
									l.scale_x, Ad, time_ini, time_ini + del_tran, Ai, time_ini + delay_tr,
									time_ini + delay_tr + del_tran, l.scale_x, Ad, tbl_char[i]
								)
								for k = 1, num_tran do
									tbl_rtrn[i] = tbl_rtrn[i] .. ("{\\fscx0%s\\t(%s,%s,\\fscx%s%s%s)\\t(%s,%s,\\fscx0%s%s)}%s"):format(
										Ai, time_ini + (k - 1) * dur_tran, time_ini + del_tran + (k - 1) * dur_tran, l.scale_x, Ad, extra_tg,
										time_ini + k * dur_tran, time_ini + del_tran + k * dur_tran, Ai, ke.tag.default(extra_tg), ke.math.rand(tbl_rand)
									)
								end
							end
						end
					end
				end
				local Text_fx = ke.tag.dark(table.concat(tbl_rtrn))
				Text_fx = Text_fx:gsub("\\t(%b())",
					function(capture)
						if capture:sub(2, -2):sub(1, 4) == "0,0," then
							return capture:sub(2, -2):match("\\%S+[%S]*")
						end --captura todos los tags dentro de una \\t
					end
				) --si hay una \\t(0,0, solo retorna los tags que hay dentro
				if all or mode == "intro" or mode == "line" or mode == "outro" then
					return Text_fx --table.concat(tbl_rtrn)
				end --char.text:rand(5, 2f, "\\1cR()")
				return ke.tag.only(ke.math.rand(ke.math.rand(2, 4)) == 1, Text_fx, text)
			end, --ke.text.rand(fx.text, 5, 82)
			
			move = function(text, dx, dy, Ox, Oy, accel)
				local fx = ke.infofx.fx
				local text = text or fx.text
				local function count_space_end(str)
					local space, i = 0, 1
					while str:sub(-i, -i) == " " do
						space = space + 1
						i = i + 1
					end
					return space
				end
				fx.add_tags = fx.add_tags:gsub("\\\\", "\\")
				local Off_x = Ox or 0 --\\fsp
				local Off_y = Oy or 0 --\\fscy
				local Ini_x = aegisub.text_extents(ke.infofx.l.style, ".")
				local tagsi = ("{\\p0}\\N{\\r%s\\p1}%s"):format(fx.add_tags, text)
				local tagsa = "\\p0\\r\\alpha&HFF&"
				if ke.table.type({text}) ~= "shape" then
					Ini_x = aegisub.text_extents(ke.infofx.l.style, ".") + count_space_end(text) * aegisub.text_extents(ke.infofx.l.style, " ")
					tagsi = ("{\\p0}\\N{\\r%s\\q2}%s"):format(fx.add_tags, text)
					tagsa = "\\r\\alpha&HFF&"
				end --ke.table.type({ke.shape.circle})
				local tagsx, tagsy = dx or "", dy or ""
				fx.add_tags = "" -->no se está borrando en realidad
				Off_y = 2 * Off_y --los valores en "y" deben duplicarse
				tagsx = type(tagsx) == "number" and ("\\t(%s,%s,\\fsp%s)"):format(fx.t1, fx.t2, tagsx) or tagsx
				tagsy = type(tagsy) == "number" and ("\\t(%s,%s,\\fscy%s)"):format(fx.t1, fx.t2, tagsy) or tagsy
				local Mov_x = ("%s\\fsp%s"):format(tagsa, -Ini_x - 2 * Off_x)
				if type(tagsx) == "table" then
					local transfo_cap_x = ke.table.match(tagsx, "\\t%(")
					if #transfo_cap_x > 0 then
						tagsx = table.concat(tagsx)
					elseif ke.table.type(tagsx) == "number" then
						Mov_x = ("%s\\fsp%s"):format(tagsa, -Ini_x - 2 * tagsx[1])
						if #tagsx > 1 then
							local dur = fx.time_dur / (#tagsx - 1)
							for i = 2, #tagsx do
								Mov_x = Mov_x .. ("\\t(%s,%s,\\fsp%s)"):format((i - 2) * dur, (i - 1) * dur, -Ini_x - 2 * tagsx[i])
							end
						end
						tagsx = ""
					elseif ke.table.type(tagsx) == "table" then
						Mov_x = ("%s\\fsp%s"):format(tagsa, -Ini_x - 2 * tagsx[1][1])
						if #tagsx[1] > 1 then
							for i = 2, #tagsx[1] do
							--	Mov_x = Mov_x .. ("\\t(%s,%s,\\fsp%s)"):format(tagsx[2][i - 1], tagsx[2][i], -Ini_x - 2 * tagsx[1][i])
								Mov_x = Mov_x .. ("\\t(%s,%s,\\fsp%s)"):format(tagsx[2][i - 1], tagsx[2][i], -Ini_x - 2 * tagsx[1][i])
							end
						end
						tagsx = ""
					end
				else
					tagsx = tagsx:gsub("\\fsp(%-?%d[%.%d]*)", function(val) return "\\fsp" .. -Ini_x - 2 * tonumber(val) end)
					:gsub("\\fsp(R[%a]*%b())", function(val) return "\\fsp" .. -Ini_x - 2 * ke.string.toval(val) end)
					:gsub("\\fsp(%b())", function(val) return "\\fsp" .. -Ini_x - 2 * ke.string.toval(val) end)
				end
				local Mov_H = ("{%s%s}."):format(Mov_x, tagsx)
				------------------------------------------------------------------
				local Mov_y1 = ("\\r\\fscy%s"):format((Off_y >= 0) and Off_y or 0)
				tagsy = type(tagsy) == "table" and table.concat(tagsy) or tagsy
				tagsy = tagsy:gsub("\\fscy(R[%a]*%b())", function(val) return "\\fscy" .. ke.string.toval(val) end)
				:gsub("\\fscy(%b())", function(val) return "\\fscy" .. ke.string.toval(val) end)
				:gsub("\\fscy(%-?%d[%.%d]*)", function(val) return "\\fscy" .. 2 * tonumber(val) end)
				local valsy, t = {[0] = Off_y}
				for t in tagsy:gmatch("\\t%b()") do
					valsy[#valsy + 1] = tonumber(t:match("\\fscy(%-?%d[%.%d]*)"))
				end
				local k, transfo = 1, {p = {}, n = {}}
				local t1, t2, vy, dy
				for t in tagsy:gmatch("\\t%b()") do
					t1 = tonumber(t:match("\\t%((%d[%.%d]*),%d[%.%d]*,"))
					t2 = tonumber(t:match("\\t%(%d[%.%d]*,(%d[%.%d]*),"))
					vy = tonumber(t:match("\\fscy(%-?%d[%.%d]*)"))
					if vy < 0 then
						if vy * valsy[k - 1] >= 0 then
							transfo.n[#transfo.n + 1] = t:gsub("(\\fscy)%-(%d[%.%d]*)", "%1%2")
						else
							dy = valsy[k - 1] - vy
							transfo.p[#transfo.p + 1] = ("\\t(%s,%s,\\fscy0)"):format(t1, t1 - (t2 - t1) * vy / dy)
							transfo.n[#transfo.n + 1] = ("\\t(%s,%s,\\fscy%s)"):format(t1 - (t2 - t1) * vy / dy, t2, -vy)
						end
					else
						if vy * valsy[k - 1] >= 0 then
							transfo.p[#transfo.p + 1] = t
						else
							dy = vy - valsy[k - 1]
							transfo.n[#transfo.n + 1] = ("\\t(%s,%s,\\fscy0)"):format(t1, t1 + (t2 - t1) * vy / dy)
							transfo.p[#transfo.p + 1] = ("\\t(%s,%s,\\fscy%s)"):format(t1 + (t2 - t1) * vy / dy, t2, vy)
						end
					end
					k = k + 1
				end
				local Mov_V1 = ("{%s%s\\p1}m 0 0 m 0 100 "):format(Mov_y1, table.concat(transfo.p))
				local Mov_y2 = ("\\r\\fscy%s"):format((Off_y <= 0) and ((Off_y == 0) and 0 or -Off_y) or 0)
				local Mov_V2 = ("\\N{%s%s\\p1}m 0 0 m 0 100 "):format(Mov_y2, table.concat(transfo.n))
				return Mov_V1 .. tagsi .. Mov_H .. Mov_V2
			end, --ke.text.move(nil, ke.tag.oscill(fx.time_dur, 5f, "\\fspR(10)"), ke.tag.oscill(fx.time_dur, 5f, "\\fscyR(10)"))
			
		},
		
		tag = {
			
			tonumber = function(str)
				local ratio, frame_dur = ke.infofx.ratio, ke.infofx.frame_dur
				local str = type(str) == "function" and str() or str or ""
				str = str:gsub("(%-?%d[%.%d]*)([rf]^*)",
					function(capture, variable)
						local varx = variable == "f" and frame_dur or ratio
						return tonumber(capture) * varx
					end
				)
				return str
			end, --ke.tag.tonumber("\\alpha45\\foo5f\\bar2r\\3a255")
			
			default = function(str)
				local l = ke.infofx.l
				local result, str = "", str or ""
				local tags = {
					[01] = "\\1c",						[02] = "\\2c",						[03] = "\\3c",
					[04] = "\\4c",						[05] = "\\c&H",						[06] = "\\1a",
					[07] = "\\2a",						[08] = "\\3a",						[09] = "\\4a",
					[10] = "\\alpha",					[11] = "\\fsp",						[12] = "\\blur",
					[13] = "\\fe",						[14] = "\\be",						[15] = "\\xbord",	
					[16] = "\\ybord",					[17] = "\\bord",					[18] = "\\fn",
					[19] = "\\xshad",					[20] = "\\yshad",					[21] = "\\shad",
					[22] = "\\fs%d+[%.%d]*",			[23] = "\\fs%(",					[24] = "\\fsR",
					[25] = "\\fax%-?%d+[%.%d]*",		[26] = "\\fax%(",					[27] = "\\faxR",
					[28] = "\\fay%-?%d+[%.%d]*",		[29] = "\\fay%(",					[30] = "\\fayR",
					[31] = "\\frx[o]*%-?%d+[%.%d]*",	[32] = "\\frx[o]*%(",				[33] = "\\frx[o]*R",
					[34] = "\\fry[o]*%-?%d+[%.%d]*",	[35] = "\\fry[o]*%(",				[36] = "\\fry[o]*R",
					[37] = "\\fr[zo]*%-?%d+[%.%d]*",	[38] = "\\fr[zo]*%(",				[39] = "\\fr[zo]*R",
					[40] = "\\fscx[r]*%d+[%.%d]*",		[41] = "\\fscx[r]*%(",				[42] = "\\fscx[r]*R",
					[43] = "\\fscy[r]*%d+[%.%d]*",		[44] = "\\fscy[r]*%(",				[45] = "\\fscy[r]*R",
					[46] = "\\frxy[o]*%-?%d+[%.%d]*",	[47] = "\\frxy[o]*%(",				[48] = "\\frxy[o]*R",
					[49] = "\\frxz[o]*%-?%d+[%.%d]*",	[50] = "\\frxz[o]*%(",				[51] = "\\frxz[o]*R",
					[52] = "\\fryz[o]*%-?%d+[%.%d]*",	[53] = "\\fryz[o]*%(",				[54] = "\\fryz[o]*R",
					[55] = "\\faxy",					[56] = "\\frxyz",					[57] = "\\fscxy",
					[58] = "\\xyshad",					[59] = "\\xybord",
				}
				local vals = {
					[01] = "\\1c" .. l.color1,			[02] = "\\2c" .. l.color2,			[03] = "\\3c" .. l.color3,
					[04] = "\\4c" .. l.color4,			[05] = "\\c" .. l.color1,			[06] = "\\1a" .. l.alpha1,
					[07] = "\\2a" .. l.alpha2,			[08] = "\\3a" .. l.alpha3,			[09] = "\\4a" .. l.alpha4,
					[10] = "\\alpha&H00&",				[11] = "\\fsp" .. l.spacing,		[12] = "\\blur0",
					[13] = "\\fe0",						[14] = "\\be0",						[15] = "\\xbord" .. l.outline,
					[16] = "\\ybord" .. l.outline,		[17] = "\\bord" .. l.outline,		[18] = "\\fn" .. l.fontname,
					[19] = "\\xshad" .. l.shadow,		[20] = "\\yshad" .. l.shadow,		[21] = "\\shad" .. l.shadow,
					[22] = "\\fs" .. l.fontsize,		[23] = "\\fs" .. l.fontsize,		[24] = "\\fs" .. l.fontsize,
					[25] = "\\fax0",					[26] = "\\fax0",					[27] = "\\fax0",
					[28] = "\\fay0",					[29] = "\\fay0",					[30] = "\\fay0",
					[31] = "\\frx0",					[32] = "\\frx0",					[33] = "\\frx0",
					[34] = "\\fry0",					[35] = "\\fry0",					[36] = "\\fry0",
					[37] = "\\frz" .. l.angle,			[38] = "\\frz" .. l.angle,			[39] = "\\frz" .. l.angle,
					[40] = "\\fscx" .. l.scale_x,		[41] = "\\fscx" .. l.scale_x,		[42] = "\\fscx" .. l.scale_x,
					[43] = "\\fscy" .. l.scale_y,		[44] = "\\fscy" .. l.scale_y,		[45] = "\\fscy" .. l.scale_y,
					[46] = "\\frx0\\fry0",				[47] = "\\frx0\\fry0",				[48] = "\\frx0\\fry0",
					[49] = "\\frx0\\frz" .. l.angle,	[50] = "\\frx0\\frz" .. l.angle,	[51] = "\\frx0\\frz" .. l.angle,
					[52] = "\\fry0\\frz" .. l.angle,	[53] = "\\fry0\\frz" .. l.angle,	[54] = "\\fry0\\frz" .. l.angle,
					[55] = "\\fax0\\fay0",				[56] = "\\frx0\\fry0\\frz" .. l.angle,
					[57] = ("\\fscx%s\\fscy%s"):format(l.scale_x, l.scale_y),
					[58] = ("\\xshad%s\\yshad%s"):format(l.shadow, l.shadow),
					[59] = ("\\xbord%s\\ybord%s"):format(l.outline, l.outline),
				}
				local array = {}
				for i = 1, #tags do
					str = str:gsub(tags[i], function(tags) return "@" .. vals[i] .. "@" end)
				end
				str = str:gsub("%b@@", function(capture) array[#array + 1] = capture:sub(2, -2) end)
				result = #array > 0 and table.concat(array) or result
				local function delete_repeat_tag(str)
					local unrepeat = {
						[01] = "\\1c" .. l.color1,		[02] = "\\2c" .. l.color2,		[03] = "\\3c" .. l.color3,
						[04] = "\\4c" .. l.color4,		[05] = "\\c" .. l.color1,		[06] = "\\1a" .. l.alpha1,
						[07] = "\\2a" .. l.alpha2,		[08] = "\\3a" .. l.alpha3,		[09] = "\\4a" .. l.alpha4,
						[10] = "\\alpha&H00&",			[11] = "\\fsp" .. l.spacing,	[12] = "\\xbord" .. l.outline,
						[13] = "\\ybord" .. l.outline,	[14] = "\\bord" .. l.outline,	[15] = "\\fn" .. l.fontname,
						[16] = "\\xshad" .. l.shadow,	[17] = "\\yshad" .. l.shadow,	[18] = "\\shad" .. l.shadow,
						[19] = "\\fscx" .. l.scale_x,	[20] = "\\fscy" .. l.scale_y,	[21] = "\\fs" .. l.fontsize,
						[22] = "\\frx0",				[23] = "\\fry0",				[24] = "\\frz" .. l.angle,
						[25] = "\\blur0",				[26] = "\\fe0",					[27] = "\\be0",
						[28] = "\\frs0",				[29] = "\\fay0",				[30] = "\\fax0",
					}
					local nm = 0
					for i = 1, #unrepeat do
						str, nm = str:gsub(unrepeat[i], "%1")
						str = str:gsub(unrepeat[i], "", nm - 1)
					end
					return str
				end
				return delete_repeat_tag(result)
			end, --ke.tag.default("\\fscx250\\t(0,300,\\1a&HFF&)")
			
			dark = function(str)
				local str = str:gsub("(\\[%d]*%l+)R(%b())",
					function(tag, rand)
						local randfunct = "ke.math.rand"
						randfunct = tag:match("\\%d+c") and "ke.color.random"
						or (tag:match("\\%d+a") and "ke.alpha.random" or randfunct)
						return ("%s(%s%s)"):format(tag, randfunct, rand)
					end --\\tagR()
				)
				local tag_in = {
					[01] = "(\\fscxy)",				[02] = "(\\faxy)",				[03] = "(\\frxy)",
					[04] = "(\\frxz)",				[05] = "(\\fryz)",				[06] = "(\\frxyz)",
					[07] = "(\\xybord)",			[08] = "(\\xyshad)",			[09] = "(\\bs)",
					[10] = "(\\13a)",				[11] = "(\\14a)",				[12] = "(\\34a)",
					[13] = "(\\134a)",				[14] = "(\\13c)",				[15] = "(\\14c)",
					[16] = "(\\34c)",				[17] = "(\\134c)",
				}
				local tag_out = {
					[01] = "\\fscx%s\\fscy%s",		[02] = "\\fax%s\\fay%s",		[03] = "\\frx%s\\fry%s",
					[04] = "\\frx%s\\frz%s",		[05] = "\\fry%s\\frz%s",		[06] = "\\frx%s\\fry%s\\frz%s",
					[07] = "\\xbord%s\\ybord%s",	[08] = "\\xshad%s\\yshad%s",	[09] = "\\bord%s\\shad%s",
					[10] = "\\1a%s\\3a%s",			[11] = "\\1a%s\\4a%s",			[12] = "\\3a%s\\4a%s",
					[13] = "\\1a%s\\3a%s\\4a%s",	[14] = "\\1c%s\\3c%s",			[15] = "\\1c%s\\4c%s",
					[16] = "\\3c%s\\4c%s",			[17] = "\\1c%s\\3c%s\\4c%s",
				}
				local tag_values = {"(%b())", "([^\\}()]*)"}
				for i = 1, #tag_in do
					for k = 1, #tag_values do
						str = str:gsub(tag_in[i] .. tag_values[k],
							function(tag, val)
								return tag_out[i]:format(val, val, val)
							end
						)
					end
				end --tags dark
				str = str:gsub("(\\[%d]*%a+)(%b())", --tags function
					function(tag, val)
						local val = val:gsub("(\\[%d]*%a+)(%b())", --tags in \\t
							function(ttag, tval)
								local arrayval = ke.string.toval("{" .. tval:sub(2,-2) .. "}")
								if type(arrayval) == "table" then
									tval = "(" .. table.concat(arrayval, ",") .. ")"
									tval = (#arrayval == 1 and not ttag:match("clip")) and tval:sub(2, -2) or tval
								end
								return ttag .. tval
							end
						)
						val = "{" .. val:sub(2, -2):gsub("\\", "\\\\"):gsub("(\\.+)", "\"" .. "%1" .. "\"") .. "}"
						local arrayval = ke.string.toval("{" .. val:sub(2,-2) .. "}")
						if type(arrayval) == "table" then
							val = "(" .. table.concat(arrayval, ",") .. ")"
							val = (#arrayval == 1 and not tag:match("clip") and not tag:match("\\t")) and val:sub(2, -2) or val
						end
						return tag .. val:gsub("{", "("):gsub("}", ")")
					end
				)
				str = str:gsub("(%-?%d+%.%d+)", function(num) return ke.math.round(num, ROUND_NUM) end)
				str = str:gsub("(\\%d?a[lpha]*)(%d[%.%d]*)", function(tag, val) return tag .. ke.alpha.ass(val) end)
				return str--:gsub("\\", "\\\\")
			end, --ke.tag.dark("\\frxz-30\\13a64\\alpha200\\t(0, 100 - 8,\\blurR(1,3,0.02)\\34aR(34,67))")
			
			only = function(conditions, ...)
				--retorna los parámetros dados según las condiciones indicadas
				local conditions = type(conditions) == "function" and conditions() or conditions
				local exits = type(...) == "table" and ... or {...}
				if type(conditions) == "table" then
					for i = 1, #conditions do
						if conditions[i] then
							return exits[i]
						end
					end
					if #exits > #conditions then
						return exits[#conditions + 1]
					end
					return type(exits[#exits]) == "number" and 0 or ""
				end
				if conditions then
					return exits[1]
				end
				return exits[2] or (type(exits[1]) == "number" and 0 or "")
			end,
			
			clip = function(left, top, width, height)
				local loop = ke.infofx.loop
				local l, j = ke.infofx.l, ke.infofx.j
				local left, width = left or l.left, width or l.width
				local top, height = top or l.top, height or l.height
				local lw, lh = loop[1], loop[2] or 1
				local offset = l.outline + l.shadow
				local left_x, top_y = left - offset, top - offset
				local size_W, size_H = (width + 2 * offset) / lw, (height + 2 * offset) / lh
				local cx1 = ke.math.round(left_x + ((j - 1) % lw) * size_W, ROUND_NUM)
				local cx2 = ke.math.round(left_x + ((j - 1) % lw + 1) * size_W, ROUND_NUM)
				local cy1 = ke.math.round(top_y + (math.ceil(j / lw) - 1) * size_H, ROUND_NUM)
				local cy2 = ke.math.round(top_y + (math.ceil(j / lw)) * size_H, ROUND_NUM)
				return ("\\clip(%s,%s,%s,%s)"):format(cx1, cy1, cx2, cy2)
			end,
			
			move = function(points, times)
				local fx, l = ke.infofx.fx, ke.infofx.l
				local length = ke.math.distance(points)
				local times = times or fx.time_dur
				if type(points) == "string" then --smove
					local smove, shp = ke.shape.new(points), ke.recall.shp
					points = ke.recall.pnt
					if not shp or smove ~= shp then
						shp, smove = ke.recall.remember("shp", smove), smove:redraw(7.5, "bezier")
						points = smove:points()
						length = ke.math.distance(points)
					--	local add = {fx.center - (relative and points[1].x or 0), fx.middle - l.descent - (relative and points[1].y or 0)}
						local add = {fx.center - (relative and points[1].x or 0), fx.middle - (relative and points[1].y or 0)}
						points = ke.recall.remember("pnt", ke.shape.point.group(points, function(p, get, add) return p + add end, add))
					end --ke.tag.move(ke.shape.circle)
				elseif type(points) == "table" and points[1] == "random" then
					--{"randon", {rx, ry, dt}}
					local fx, l = ke.infofx.fx, ke.infofx.l
					times = type(times) == "number" and {{0, times}} or times
					table.remove(points, 1) --remove "random"
					local frame_dur = ke.infofx.frame_dur
					points[1] = points[1] or {}
					points[1][1] = points[1][1] or 10
					points[1][2] = points[1][2] or 10
					points[1][3] = points[1][3] or frame_dur
				--	local add = {fx.center, fx.middle - l.descent}
					local add = {fx.center, fx.middle}
					local xtimes = {}
					for i = 1, #points do
						local dur = times[i][2] - times[i][1]
						local n = math.ceil(dur / (points[i][3] or frame_dur)) - 1
						xtimes[i] = {[1] = {times[i][1], times[i][1] + 1}}
						dur = ke.math.round(dur / (n + 1), ROUND_NUM)
						for k = 2, n + 2 do
							xtimes[i][k] = {xtimes[i][k - 1][2], xtimes[i][k - 1][2] + dur}
						end
						local rand = ke.shape.point.random(n, points[i][1] or points[i - 1][1], points[i][2] or points[i - 1][2])
						table.insert(rand, 1, ke.shape.point.new({x = 0, y = 0}))
						table.insert(rand, ke.shape.point.new({x = 0, y = 0}))
						points[i] = ke.shape.point.group(rand, function(p, get, add) return p + add end, add)
					end
					local rpoints, rtimes = ke.table.new(), ke.table.new()
					for i = 1, #points do
						rpoints:insert(points[i], nil, true)
						rtimes:insert(xtimes[i], nil, true)
					end --ke.tag.move({"random", {6, 6}, {6, 6}}, {{0, 600}, {fx.time_dur - 600, fx.time_dur}})
					points, times = rpoints, rtimes
				else
					points = ke.table.get(points, "topoint")
				end
				if type(times) == "number" then
					local dur, n = times, #points
					length = length == 0 and 1 or length
					times = {[1] = {0, 1}}
					for i = 2, n do
						times[i] = {times[i - 1][2], ke.math.round(times[i - 1][2] + dur * points[i - 1]:distance(points[i]) / length, 2)}
					end
				end
				local x0, y0 = table.unpack(ke.shape.point.group(points, "bounding"))
				local add = {-fx.width / 2, 3 * fx.height / 2 - l.descent}
				points = ke.shape.point.group(points, function(p, get, add) return p + add end, add)
				x0, y0 = x0 >= 0 and 0 or x0, (y0 > 0 and y0 <= fx.height) and -y0 or (y0 >= 0 and 0 or y0)
				local tags = ("\\an7\\pos(%s,%s)\\q2"):format(x0, y0 - fx.height)
				for i, p in ipairs(points) do
					tags = tags .. ("\\t(%s,%s,\\fscx%s\\fscy%s)"):format(times[i][1], times[i][2], p.x, p.y)
				end
				tags = tags .. "\\p1}m 0 0 m 100 100 {\\p0\\r"
				return tags
			end, --ke.tag.move({{fx.center, fx.middle - 200}, {fx.center, fx.middle}})
			
			oscill = function(deration, durdelay, ...)
				--durdelay = durdelay, or: durdelay = {durdelay, accel}, or: durdelay = function
				--durdelay = {durdelay, accel, dilatation}, or: durdelay = {{durdelay, Dur_trans}, accel, dilatation}
				--durdelay = {{durdelay, Dur_trans}, accel, dilatation, offset_time}
				local time_ini, time_fin, time_tot = 0, deration
				local index_ii, dur_del1, dur_del2 = 1, durdelay
				local accel, dilat, offset_t, time_off, tags = 1, 0, 0, 0, {...}
				if type(deration) == "table" and type(deration[1]) == "table" then
					local multi_oscill = {}
					for i = 1, #deration do
						multi_oscill[i] = ke.tag.oscill(deration[i], durdelay, ...)
					end --recurse
					return table.concat(multi_oscill)
				end --ke.tag.oscill({{0, 500}, {fx.time_dur - 500, fx.time_dur}}, 100, "\\1cR()")
				------------------------------------------------------------------------
				local fx = ke.infofx.fx
				if type(deration) == "table" and type(deration[1]) ~= "table" then
					time_ini = deration[1] or 0			--tiempo de inicio
					time_fin = deration[2] or fx.time_dur	--tiempo final
					index_ii = deration[3] or 1			--índice en caso de table
				elseif type(deration) == "function" then
					time_ini = deration()[1] or 0		--tiempo de inicio
					time_fin = deration()[2] or fx.time_dur	--tiempo final
					index_ii = deration()[3] or 1		--índice en caso de table
				end --ke.tag.oscill(800, {{200, 5}}, "\\1cR()")
				time_tot = time_fin - time_ini
				--colores = table.ipol({shape.color1, shape.color3, shape.color1}, char.n, "\\1c")
				--colores[char.i], tag_oscill({0, fx.time_dur, char.i + 1}, 1f, colores)
				if type(durdelay) == "table" then
					dur_del1 = durdelay[1]
					if type(durdelay[1]) == "table" then
						dur_del1 = durdelay[1][1]
						dur_del2 = durdelay[1][2] and durdelay[1][2] or nil
					end
					accel = durdelay[2] and durdelay[2] or accel
					dilat = durdelay[3] and durdelay[3] / 2 or dilat
					offset_t = durdelay[4] and durdelay[4] or offset_t
				end
				------------------------------------------------------------------------
				if type(...) == "function" then
					tags = tags[1]()
					tags = type(tags) ~= "table" and {tags} or tags
				end --tag.oscill(fx.time_dur, 400, function() return "\\blurR(4)" end)
				tags = type(...) == "table" and ... or tags
				local time_i, time_f, tags_fx = 0, 1, ""
				local indicator, tag_osc = 1, ""
				dur_del1 = type(durdelay) == "number" and dur_del1 - dilat or (type(durdelay) == "function" and 0 or dur_del1)
				dur_del2 = not dur_del2 and dur_del1 or dur_del2
				local time_tot2, dur_func, dur_tag2 = time_tot, 0, 0
				------------------------------------------------------------------------
				local i, delay = 0
				while time_tot > 0 do
					time_i = ke.math.round(dur_del1 * i + time_ini + time_off, 2)
					time_f = ke.math.round((dur_del1 + dilat) * (i + 1) + time_ini + time_off, 2)
					time_f = (type(durdelay) == "table" and type(durdelay[1]) == "table") and time_i + dur_del2 or time_f
					if type(durdelay) == "function" then
						dur_func = durdelay(i)
						time_i = ke.math.round(dur_tag2 + time_ini + time_off, 2)
						time_f = ke.math.round(time_i + dur_func, 2)
					end --tag.oscill({0, 500}, 100, "\\1cR()")
					indicator = #tags - #tags * math.ceil((i + index_ii) / #tags) + i + index_ii
					tag_osc = tags[indicator]
					tag_osc = type(tags[indicator]) == "function" and tags[indicator](i) or tag_osc
					tags_fx = tags_fx .. ("\\t(%s,%s,%s,%s)"):format(time_i, time_f, accel, tag_osc)
					tags_fx = tags_fx:gsub("\\t%(%d[%.%d]*,%d[%.%d]*,[%d%.,]*%)", "")
					if type(durdelay) == "function" then
						dur_tag2, dur_del1 = dur_tag2 + dur_func, dur_func
					else
						dur_del1 = dur_del1 + dilat
					end --tag.oscill(fx.time_dur, 1000, "\\frx(90 * (-1) ^ i)")
					if (i + 1) % #tags == 0 then
						delay = type(offset_t) == "function" and offset_t(i) or offset_t
						time_off = time_off + delay
						--tag.oscill({R(800), fx.time_dur}, {{100, 0}, 1, 0, mydur}, "\\alpha255", "\\alpha0")
						--mydur = function() return R(500, 2000, 20) end
					end
					time_tot = ke.math.round(time_tot - dur_del1, 2)
					i = i + 1
				end
				-------------------------------------------------------------------------------
				tags_fx = tags_fx:gsub("(\\t%(%d[%.%d]*,%d[%.%d]*,)1,", "%1")
				tags_fx = ke.string.i(tags_fx)
				return ke.tag.dark(tags_fx)
			end,
			
			set = function(times, events)
				local fx = ke.infofx.fx
				local times = type(times) == "function" and times() or times
				times = ke.time.HMS_to_ms(times)
				local function tag_last(str)
					local tags = {--borra los tags repetidos y solo deja el último de cada uno de ellos
						[01] = "\\fscxy",	[02] = "\\faxy",	[03] = "\\frxyz",	[04] = "\\frxy",	[05] = "\\frxz",	[06] = "\\fryz",
						[07] = "\\bs",		[08] = "\\134a",	[09] = "\\13a",		[10] = "\\14a",		[11] = "\\34a",		[12] = "\\134c",
						[13] = "\\13c",		[14] = "\\14c",		[15] = "\\34c",		[16] = "\\1c",		[17] = "\\2c",		[18] = "\\3c",
						[19] = "\\4c",		[20] = "\\1a",		[21] = "\\2a",		[22] = "\\3a",		[23] = "\\4a",		[24] = "\\alpha",
						[25] = "\\fsp",		[26] = "\\blur",	[27] = "\\bord",	[28] = "\\xbord",	[29] = "\\ybord",	[30] = "\\xybord",
						[31] = "\\be",		[32] = "\\fe",		[33] = "\\shad",	[34] = "\\xshad",	[35] = "\\yshad",	[36] = "\\xyshad",
						[37] = "\\fn",		[38] = "\\fax",		[39] = "\\fay",		[40] = "\\frx",		[41] = "\\fry",		[42] = "\\frz?",
						[43] = "\\fscx",	[44] = "\\fscy",	[45] = "\\fs",		[46] = "\\b",		[47] = "\\i",		[48] = "\\u",
						[49] = "\\s",		[50] = "\\p",		[51] = "\\clip",	[52] = "\\iclip"
					}
					local v = {"%-?[%d&]^*[%.%dH%x&]*", "R%b()", "%b()"}
					for i = 1, #tags do
						str = ke.string.change(str, {tags[i] .. v[1], tags[i] .. v[2], tags[i] .. v[3]}, -1, "\\t%b()")
					end
					return str
				end
				local t2, accel, fxreturn = 1, 1, {}
				for i = 1, #times do
					local k = (i - 1) % #events + 1
					events[k] = type(events[k]) == "function" and events[k]() or events[k]
					local Transfos = ke.string.array(events[k], "\\t%b()")	--tabla de transfos
					if type(times[i]) == "table" then						--tiempos de las transfos
						t2 = times[i][2] - times[i][1]
						accel = times[i][3] or 1
					end
					fxreturn[i] = ("\\t(0,%s,%s,%s)"):format(t2, accel, events[k]:gsub("\\t%b()", "")) .. table.concat(Transfos)
					fxreturn[i] = fxreturn[i]:gsub("\\t%b()",
						function(tagst)
							local time1, time2
							tagst = tagst:gsub("(\\t)%(%s?(%d[%.%d]*),%s?(%d[%.%d]*)",
								function(tag, t1, t2)
									time1 = t1 + times[i] - fx.time_ini
									time2 = t2 + times[i] - fx.time_ini
									return ("%s(%s,%s"):format(tag, time1, time2)
								end
							)
							if time2 <= 0 then
								return tagst:match("%b()"):sub(2, -2):match("\\%w+[%S]*")
							end
							return time1 >= fx.time_fin and "" or tagst
						end
					)
				end
				return tag_last(table.concat(fxreturn))
			end,
			
			glitter = function(deration, extratags1, extratags2)
				local fx = ke.infofx.fx
				local i, t, t1, t2, t3, t4, tags = 0, 0, 0, 0, 0, 0, "\\shad0"
				local time1 = type(deration) == "function" and deration()[1]
				or (type(deration) == "table" and deration[1]) or 0
				local time2 = type(deration) == "function" and deration()[2]
				or (type(deration) == "table" and deration[2]) or deration or fx.time_dur
				local time_tot, eti, etf, size1, size2 = time2 - time1
				while time_tot > t do
					t1 = t + ke.math.rand(1, time_tot / 2, 0.01)
					t2 = t1 + 1
					t3 = t2 + 41
					t4 = t3 + 102
					size1, size2 = ke.math.rand(150, 250, 0.01), ke.math.rand(50, 150, 0.01)
					eti = type(extratags1) == "function" and extratags1(i) or extratags1 or ""
					etf = type(extratags2) == "function" and extratags2(i) or extratags2 or ""
					t4 = t4 > time_tot and time_tot or t4
					tags = tags .. ("\\t(%d,%d,%s\\fscx%d\\fscy%d)\\t(%d,%d,%s\\fscx%d\\fscy%d)"):format(
						time1 + t1, time1 + t2, eti, size1, size1, time1 + t3, time1 + t4, etf, size2, size2
					)
					i, t = i + 1, t4
				end
				return ke.string.i(tags) 
			end, --ke.tag.glitter()
			
			interpolate = function(t, ...)
				local values = type(...) == "table" and ... or {...}
				--tiempos en formato HMS -------------------------
				values = ke.table.gsub(values, "%d+:%d+:%d+%.%d+", function(HMS) return ke.time.HMS_to_ms(HMS) end)
				--interpola el valor de dos números --------------
				local function ipol_number(t, num1, num2)
					local num1 = num1 or 0
					local num2 = num2 or num1
					return ke.math.round(num1 + (num2 - num1) * t, ROUND_NUM)
				end
				--interpola el valor de dos shapes o dos clips ---
				local function ipol_shpclip(t, shp1, shp2)
					local shp1, shp2 = ke.shape.insert(shp1, shp2)
					local pnt1, pnt2 = shp1:points(), shp2:points()
					local k = 0
					local val_ipol = shp1.code:gsub("%-?%d[%.%d]*",
						function(val)
							k = k + 1
							return ke.math.round(pnt1[k] + (pnt2[k] - pnt1[k]) * t, ROUND_NUM)
						end
					)
					return val_ipol
				end
				--busca un string dentro de la tabla -------------
				local function string_in_tbl(array)
					for i, s in ipairs(array) do
						if type(s) == "string" then
							return true, s
						end
					end
					return false
				end
				--determina si los elementos son clips o shapes --
				local function type_table(array)
					local clip = "%(%s*%-?%d[%. %d]*,%s*%-?%d[%. %d]*,%s*%-?%d[%. %d]*,%s*%-?%d[%. %d]*%)"
					local tshp = "m%s+%-?%d[%.%-%d mlb]*"
					if type(array[1]) == "string" then
						if array[1]:match(clip) then
							for i, s in ipairs(array) do
								if type(s) ~= "string" or not s:match(clip) then
									return false
								end
							end
							return true
						elseif array[1]:match(clip) then
							for i, s in  ipairs(array) do
								if type(s) ~= "string" or not s:match(clip) then
									return false
								end
							end
							return true
						end
					end
					return false
				end
				--decide cuál de las 4 interpolaciones se usará --
				local shp_or_clip = type_table(values)
				local ipol_function = shp_or_clip and ipol_shpclip or ipol_number
				if string_in_tbl(values) then
					local trueval, str = string_in_tbl(values)
					ipol_function = str:match("[&Hh%#]^*%x%x%x%x%x%x[&]*") and ke.color.interpolate
					or (str:match("[&Hh%#]^*%x%x[&]*") and ke.alpha.interpolate) or ipol_function
				end
				--------------------------------------------------
				local t = t or 0.5
				t = ke.math.clamp(t)
				if t == 0 then
					return values[1]
				end
				local n = #values
				local seg = math.ceil(t * (n - 1))
				local ini, fin = values[seg], values[seg + 1]
				return ipol_function(t * (n - 1) - (seg - 1), ini, fin)
			end, --ke.tag.interpolate(0.44, "&H00&", "&HEE&", "&HFF&")
			
			move7 = function(text, moves, times)
				local fx, total = ke.infofx.fx
				local packs = {mx = {}, my = {}}
				local times = times or {0, fx.time_dur}
				local width_point = aegisub.text_extents(ke.infofx.l.style, ".")
				local width_space = aegisub.text_extents(ke.infofx.l.style, " ")
				local topairs = function(tbl)
					local result = {}
					for i = 1, #tbl - 1 do
						table.insert(result, {tbl[i], tbl[i + 1]})
					end
					return result
				end --ke.tag.move7(nil, ke.shape.rectangle)
				if ke.table.type(moves) == "shape" then
					--[[
					local coors = ke.shape.point.group(ke.shape.new(moves):redraw(6, "bezier"):points(), "coors")
					local mt = topairs(ke.math.ipol(times, nil, #coors[1]))
					packs.mx = {v = coors[1], t = mt}
					packs.my = {v = coors[2], t = mt}
					--]]
					local shp = ke.shape.new(moves):redraw(6, "bezier")
					local points, length, accum, accum_length = shp:points(), shp:length(), 0, 0
					local coors, mt = ke.shape.point.group(points, "coors"), ke.table.new()
					local total, accel = times[2] - times[1], 1.4
					for i = 2, #points do
						accum_length = accum_length + points[i]:distance(points[i - 1])
						local t = {
							times[1] + accum,
							times[1] + accum + total * (accum_length / length) ^ accel
						}
						mt:insert(t)
						accum = t[2]
					end
					packs.mx = {v = coors[1], t = mt}
					packs.my = {v = coors[2], t = mt}
					return packs
				elseif type(moves) == "table" then
					packs.mx, packs.my = moves.mx, moves.my
					if packs.mx then
						local tx = moves.mx.t
						if moves.mx.t and ke.table.type(moves.mx.t) == "number" then
							tx = topairs(ke.math.ipol(moves.mx.t, nil, #packs.mx.v))
						elseif not moves.mx.t then
							tx = topairs(ke.math.ipol(times, nil, #packs.mx.v))
						end
						packs.mx.t = tx
					end --ke.tag.move7(nil, {mx = {v = {0,200,-200,0}}})
					if packs.my then
						local ty = moves.my.t
						if moves.my.t and ke.table.type(moves.my.t) == "number" then
							ty = topairs(ke.math.ipol(moves.my.t, nil, #packs.my.v))
						elseif not moves.mx.t then
							ty = topairs(ke.math.ipol(times, nil, #packs.my.v))
						end
						packs.my.t = ty
					end --ke.tag.move7(nil, {mx = {v = {0,200,-200,0}, t = {600, 800}}})
					if moves.random then
						local points = ke.table.new()
						packs.mx = {v = ke.table.new(), t = ke.table.new()}
						packs.my = {v = ke.table.new(), t = ke.table.new()}
						for i, r in ipairs(moves.random) do
							total = r.t and r.t[2] - r.t[1] or fx.time_dur
							local n = math.ceil(total / (r.dur or 2 * ke.infofx.frame_dur))
							local rxy = ke.shape.point.random(n, r[1] or 24, r[2] or 24)
							rxy[#rxy] = ke.shape.point.new(0,0)
							packs.mx.v:insert(rxy, nil, true)
						end --ke.tag.move7(nil, {random = {{100, 200, t = {600, 800}}}})
					end
				end
				return packs
			end,
			--moves = shape
			--moves = {mx = {v = {coors}, t = {times}}, my = {v = {coors}, t = {times}}}
			--moves = {random = {rand1, rand2, ...}}
			--rand1 = {rx, ry, t = {t1, t2}, dur = 2f}
			
			array = function(str)
				local tags = ke.string.capture(str, {"\\[%d]*%a+%-?[%d&]^*[%.%dH%x&]*", "\\[%d]*[^t%W]%a+%b()", protect = "\\t%b()", include = true})
				local caps = {"\\t%(%s?(%d+[%.%d ]*,%s?%d+[%.%d ]*,%s?%d+[%.%d ]*),", "\\t%(%s?(%d+[%.%d ]*,%s?%d+[%.%d ]*),", "\\t%(%s?(%d+[%.%d ]*),"}
				local pack, k = ke.table.new(), ke.math.count()
				for i, v in ipairs(tags) do
					local cap1, cap2 = v:match("(\\[%d]*%l+)(R?%b())")
					if not cap2 then
						cap1, cap2 = v:match("(\\[%d]*%l+)(%-?[%d&]^*[%.%dH%x&]*)")
					end
					pack[i] = {tag = cap1, val = cap2}
					if pack[i].tag == "\\t" then
						pack[i].tag = pack[i].tag .. tostring(k())
						pack[i].val = ke.tag.array(pack[i].val)
						pack[i].times = v:match(caps[1]) or v:match(caps[2]) or v:match(caps[3])
					end
				end
				return pack
			end, --str = "\\frz-32\\blur-2\\1a&HFF&\\bordR(2,6)\\org(80,90)\\iclip(m 0 0 l 0 100 l 100 100 )\\t(0,80,\\1c&HFF00FF&\\bord1\\alpha&HFF&)\\p1"
			
		},
		
		time = {
			
			HMS_to_ms = function(HMS)
				--from HMS to ms format time
				if type(HMS) == "table" then
					return ke.table.recursive(HMS, ke.time.HMS_to_ms)
				end
				local HMS = type(HMS) == "function" and HMS() or HMS or 0
				if type(HMS) == "string" and HMS:match("%d+%:%d+%:%d+%.%d+") then
					local H, M, S, ms = HMS:match("(%d+)%:(%d+)%:(%d+)%.(%d+)")
					ms = ms:len( ) == 2 and 10 * ms or (ms:len( ) == 1 and 100 * ms or ms)
					return H * 3600000 + M * 60000 + S * 1000 + ms
				end
				return tonumber(HMS) and tonumber(HMS) or HMS
			end, --ke.time.HMS_to_ms({"0:00:34.952", "0:00:44.920", "0:00:48.882"})
			
			ms_to_HMS = function(ms)
				--convierte el tiempo de ms a formato HMS
				local ms = type(ms) == "function" and ms() or ms or 0
				if type(ms) == "table" then
					return ke.table.recursive(ms, ke.time.ms_to_HMS)
				end --recurse
				local tms, H, M, S = ke.math.round(ms), 0, 0, 0
				H = math.floor(tms / 3600000)
				tms = tms - H * 3600000
				M = math.floor(tms / 60000)
				tms = tms - M * 60000
				S = math.floor(tms / 1000)
				tms = tms - S * 1000 --ke.time.ms_to_HMS({540.945, 5645, 27432})
				M = M < 10 and "0" .. M or M
				S = S < 10 and "0" .. S or S
				tms = tostring(tms):len() == 1 and "00" .. tms or (tostring(tms):len() == 2 and "0" .. tms or tms)
				return ("%s:%s:%s.%s"):format(H, M, S, tms)
			end, --ke.time.ms_to_HMS((j - 1) * 41.7)
			
			time_to_frame = function(time)
				--retorna la cantidad de frames que hay en un tiempo determinado
				local frame_dur = ke.infofx.frame_dur
				local time = type(time) == "function" and time() or time or 0
				if type(time) == "table" then
					return ke.table.recursive(time, ke.time.time_to_frame)
				end --recurse
				local time = tostring(time)
				if time:match("%d+%:%d+%:%d+%.%d+") then
					time = type(ke.time.HMS_to_ms(time)) == "table" and ke.time.HMS_to_ms(time)[1] or ke.time.HMS_to_ms(time)
				end --ke.time.time_to_frame({3000, "0:00:25.673"})
				return math.ceil(time / frame_dur)
			end, --ke.time.time_to_frame(2000)
			
			frame_to_ms = function(frames)
				--convierte la cantidad de frames en un tiempo en formato ms
				local frame_dur = ke.infofx.frame_dur
				local frames = type(frames) == "function" and frames() or frames or 0
				if type(frames) == "table" then
					return ke.table.recursive(frames, ke.time.frame_to_ms)
				end --recurse
				return ke.math.round(frames * frame_dur, 2)
			end, --ke.time.frame_to_ms({2365, 128, 82351})
			
			frame_to_HMS = function(frames)
				--convierte la cantidad de frames en un tiempo en formato HMS
				local frames = type(frames) == "function" and frames() or frames or 0
				if type(frames) == "table" then
					return ke.table.recursive(frames, ke.time.frame_to_HMS)
				end --recurse
				return ke.time.ms_to_HMS(ke.time.frame_to_ms(frames))
			end, --ke.time.frame_to_HMS({35, 240, {4532, {24, 276}, 9574}})
			
			ipol = function(times, configs)
				local times = ke.time.HMS_to_ms(times)
				local configs = configs or {n = nil, accel = 1, points = nil, numbers = nil}
				local result, groups = ke.table.new(), ke.table.new()
				local couples = function(k, v, t) return (type(k) == "number" and k < #t) and {v, t[k + 1]} or nil end
				if type(times) == "number" then --times --> "number"
					groups:insert({0, times})
				elseif type(times) == "table" and times.segs then --times --> {segs = {{seg1}, {seg2}, ...}}
					for k, v in pairs(times.segs) do
						groups:insert(v)
					end
				elseif ke.table.type(times) == "table" then --times --> {{lap1}, {lap2}, {lap3}, ...}
					result:insert(times)
				elseif ke.table.type(times) == "number" then --times --> {ini, fin}
					groups:insert(ke.table.filter(times, couples), nil, true)
				end --times --> {t1, t2, t3, ...}
				if #result == 0 then
					local accel = type(configs) == "table" and configs.accel or 1
					if type(configs) == "table" and (configs.points or configs.numbers) then
						local values = {points = configs.points, numbers = configs.numbers}
						local function ipoltime(values, v, accel)
							local t0, dur = v[1], v[2] - v[1]
							local total, accum, aux, ts = 0, 0, {t0}, {}
							local vals = values.numbers or values.points
							local ispoints = values.points and 1 or 0
							if ispoints == 1 then
								vals, aux[0] = ke.shape.point.group(vals, "lengths"), t0
								total = vals.total
								for i = 1, #vals do
									accum = accum + vals[i]
									local u = accum / total
									aux[i] = t0 + dur * (type(accel) == "function" and accel(u) or u ^ accel)
									ts[i] = {aux[i - 1], aux[i]}
								end --ke.time.ipol({200, 500}, {points = ke.shape.new(ke.shape.rectangle):points()})
							else
								for i = 2, #vals do
									total = total + math.abs(vals[i] - vals[i - 1])
								end
								for i = 2, #vals do
									accum = accum + math.abs(vals[i] - vals[i - 1])
									local u = accum / total
									aux[i] = t0 + dur * (type(accel) == "function" and accel(u) or u ^ accel)
									ts[i - 1] = {aux[i - 1], aux[i]}
								end
							end --ke.time.ipol({segs = {{0, 100}, {400,500}}}, {points = ke.shape.new(ke.shape.rectangle):points()})
							return ts
						end --ke.time.ipol(1000, {numbers = {100,0,100,0}, accel = 1.2})
						for k, v in ipairs(groups) do
							result:insert(ipoltime(values, v, accel))
						end
						return result
					end
					local n = type(configs) == "number" and configs or nil
					n = type(configs) == "table" and configs.n or n
					if not n then
						result = groups
					else
						for k, v in ipairs(groups) do
							v = ke.math.ipol(v, nil, accel, nil, n + 1)
							result:insert(ke.table.filter(v, couples))
						end
					end
				end
				return result
			end,

		},
		
		config = {
			
			window = {
				[01] = {x = 3;	y = 0;	height = 1;	width = 2; class = "label";		label = " [:: Primary Setting ::]"},
				[02] = {x = 2;	y = 1;	height = 1; width = 1; class = "label";		label = "                          Apply to Style:"},
				[03] = {x = 3;	y = 1;	height = 1; width = 4; class = "dropdown";	name = "line_style"; hint = "Selected Lines or Lines Styles to which you Apply the Effect.";	items = {};	value = "Selected Lines"},
				[04] = {x = 2;	y = 2;	height = 1; width = 1; class = "label";		label = "                       Selection Effect:"},
				[05] = {x = 3;	y = 2;	height = 1; width = 4; class = "dropdown";	name = "effect_mode"; hint = "Select the Effect Mode: leadin, hilight, leadout, shape or translation fx";	items = {"leadin fx", "hilight fx", "leadout fx", "shape fx", "translation fx"};	value = "leadin fx"},
			},
			
			style = function(subtitles, selected_lines)
				local styles = {} --crea la tabla de los estilos para "Apply to Style:"
				for i = 1, #subtitles do
					if subtitles[i].class == "dialogue"
						and subtitles[i].effect ~= "Effector [fx]"
						and subtitles[i].effect ~= "fx"
						and not ke.table.inside(styles, subtitles[i].style) then
						styles[#styles + 1] = subtitles[i].style
					end
				end
				styles[#styles + 1] = #styles > 0 and  "All Lines" or nil
				styles[#styles + 1] = (selected_lines and #styles > 0) and "Selected Lines" or nil
				ke.config.window[3].items = styles --ingresa los estilos en la primera ventana
			end,
			
			apply = function(subtitles, selected_lines, sett, fx__)
				local index = {} --índice de las líneas fx
				if sett.line_style == "Selected Lines" then
					for _, v in ipairs(selected_lines) do --líneas seleccionadas
						if subtitles[v].class == "dialogue"
							and subtitles[v].effect ~= "Effector [fx]"
							and subtitles[v].effect ~= "fx" then
							index[#index + 1] = v 
						end
					end
				elseif sett.line_style == "All Lines" then
					for i = 1, #subtitles do --todas las líneas
						if subtitles[i].class == "dialogue"
							and subtitles[i].effect ~= "Effector [fx]"
							and subtitles[i].effect ~= "fx" then
							index[#index + 1] = i
						end
					end
				else
					for i = 1, #subtitles do --estilo seleccionado
						if sett.line_style == subtitles[i].style
							and subtitles[i].class == "dialogue"
							and subtitles[i].effect ~= "Effector [fx]"
							and subtitles[i].effect ~= "fx" then
							index[#index + 1] = i
						end
					end
				end

				local meta, styles = karaskel.collect_head(subtitles)
				local linefx = ke.config.preprosses_lines(subtitles, meta, styles, index)
				for k, v in ipairs(index) do
					local l = subtitles[v]
					karaskel.preproc_line(subtitles, meta, styles, l)
					ke.config.runfx(subtitles, meta, l, sett, fx__, linefx, linefx[k])
					l.comment = true
					subtitles[v] = l
				end
			end,
			
			macro = function(subtitles, selected_lines, active_line)
				ke.config.style(subtitles, #selected_lines > 0)
				local meta, styles = karaskel.collect_head(subtitles)
				local select_line_fx = selected_lines[1]
				local sett, box_res, fx__ = {}
				----------------
				::back_window1::
				----------------
				repeat
					box_res, sett = aegisub.dialog.display(ke.config.window,
						{"Apply Selection", "Cancel"}, {ok = "Apply Selection", cancel = "Cancel"}
					)
					if ke.config.window[07] and sett.effect_mode then
						ke.config.window[07].value = sett.effect_name
						sett.effect_name = ke.config.window[07].value
					end
					ke.config.window[03].value = sett.line_style --save
					ke.config.window[05].value = sett.effect_mode
					local fxlist = ke.config.get_namesfx(sett.effect_mode)
					if box_res == "Apply Selection" and sett.line_style ~= "" then
						ke.config.window[06] = {x = 0; y = 5; height = 1; width = 2; class = "label"; label = " Select [fx]: "}
						ke.config.window[07] = {x = 0; y = 6; height = 1; width = 6; class = "dropdown"; name = "effect_name";
							hint = "Select Karaoke Effect"; items = fxlist; value = sett.effect_name or fxlist[1]
						}
						repeat
							box_res, sett = aegisub.dialog.display(ke.config.window,
								{"Apply " .. sett.effect_mode, "Cancel", "Modify", "Back <"},
								{ok = "Apply " .. sett.effect_mode, cancel = "Cancel"}
							)
							ke.config.window[07].value = sett.effect_name --save
						until true
					end
					----------------
					::back_window2::
					----------------
					---------------------------------------
					ke.config.window[07].value = sett.effect_name
					if box_res == "Back <" then
						ke.config.window[06], ke.config.window[07] = nil, nil
						goto back_window1
					end
					---------------------------------------
					local name = sett.effect_name:gsub("%b[] ",""):gsub(" ", "_")
					local mode = sett.effect_mode:gsub(" ", "")
					local indx = ke.config.get_indexfx(fxlist, name)
					local windowfx = templates[mode][indx]
					fx__ = ke.config.loadprefx(windowfx)
					---------------------------------------
					if box_res == "Apply " .. sett.effect_mode then
						ke.config.apply(subtitles, selected_lines, sett, fx__)
					end

					if box_res == "Modify" and sett.line_style ~= "" then
						windowfx[01].label = sett.effect_mode:gsub("fx", "[fx]: ") .. sett.effect_name:gsub("%b[] ","")
						windowfx[39].value = sett.effect_mode		--folder fx
						--windowfx[00].label = string.format(" Style [fx]: %s", sett.line_style)		--style name
						
						repeat
							-----------------
							::style_manager::
							-----------------
							box_res, fx__ = aegisub.dialog.display(windowfx,
								{"Apply " .. sett.effect_mode, "Cancel", "Style Colors", "Back <"},
								{ok = "Apply " .. sett.effect_mode, cancel = "Cancel"}
							)
							fx__.fx_name = name
							fx__.fx_mode = mode
							-- save configurations
							windowfx[03].value	= fx__.fx_type		windowfx[05].text	= fx__.fx_start		windowfx[10].text	= fx__.fx_end
							windowfx[07].text	= fx__.fx_layer		windowfx[08].text	= fx__.fx_align		windowfx[12].text	= fx__.fx_loop
							windowfx[14].text	= fx__.fx_return	windowfx[16].text	= fx__.fx_posx		windowfx[18].text	= fx__.fx_posy
							windowfx[21].text	= fx__.fx_time		windowfx[29].value	= fx__.fx_color1	windowfx[30].value	= fx__.fx_color3
							windowfx[31].value	= fx__.fx_color4	windowfx[34].value	= fx__.fx_alpha1	windowfx[35].value	= fx__.fx_alpha3
							windowfx[36].value	= fx__.fx_alpha4	windowfx[42].text	= fx__.fx_variable	windowfx[43].text	= fx__.fx_addtags
							windowfx[44].value	= fx__.fx_reverse	windowfx[45].value	= fx__.fx_noblank	windowfx[46].value	= fx__.fx_vertical
							windowfx[19].value	= fx__.fx_modify	windowfx[23].value	= fx__.fx_keept		windowfx[32].text	= fx__.fx_namefx
							windowfx[39].value	= fx__.fx_folder
							
							if box_res == "Style Colors" then
								local style_fx_shp = sett.line_style
								if sett.line_style == "Selected Lines" or sett.line_style == "All Lines" then
									style_fx_shp = subtitles[select_line_fx].style
								end
								windowfx[29].value = styles[style_fx_shp].color1
								windowfx[30].value = styles[style_fx_shp].color3
								windowfx[31].value = styles[style_fx_shp].color4
								windowfx[34].value = tonumber(styles[style_fx_shp].color1:match("(%x%x)"), 16)
								windowfx[35].value = tonumber(styles[style_fx_shp].color3:match("(%x%x)"), 16)
								windowfx[36].value = tonumber(styles[style_fx_shp].color4:match("(%x%x)"), 16)
								goto style_manager
							end
							
							if box_res == "Back <" then --ventana 1
								box_res, sett = aegisub.dialog.display(ke.config.window,
									{"Apply " .. sett.effect_mode, "Cancel", "Modify", "Back <"},
									{ok = "Apply " .. sett.effect_mode, cancel = "Cancel"}
								)
								goto back_window2
							end
						until true
						
						if box_res == "Apply " .. sett.effect_mode then
							ke.config.apply(subtitles, selected_lines, sett, fx__)
						end
					end
				until true
			end,
			
			karaoke_true = function(array)
				for i = 1, #array do
					if not array[i]:match("\\[kK]^*[fo]*%d+") then
						return false
					end
				end
				return true
			end,
			
			remove_tags = function(text)
				local text = text:gsub("%b{}", "")
				return text
			end,
			
			remove_extra_space = function(text)
				while text:sub(1, 1) == " " or text:sub(1, 1) == "	" do
					text = text:sub(2, -1)
				end
				while text:sub(-1, -1) == " " or text:sub(-1, -1) == "	" do
					text = text:sub(1, -2)
				end
				return text
			end, --config.remove_extra_space("  	 demo text	 "}
			
			remove_space_in_tags = function(text)
				local text = text:gsub("%b{}",
					function(tags)
						local tags = tags:gsub("m%s+%-?%d[%.%-%d mlb]*",
							function(shp)
								local shp = shp:gsub(" ", "€")
								return shp
							end
						):gsub(" ", ""):gsub("€", " ")
						return tags
					end
				)
				return text
			end,
			
			adjust_line = function(text)
				local auxtext, score = text, 1
				while score == 1 do
					auxtext = auxtext:gsub("(%b{})(%b{})",
						function(tag1, tag2)
							local result = tag1 .. tag2
							if not (tag1:match("\\[kK]^*[fo]*%d+") and tag2:match("\\[kK]^*[fo]*%d+")) then
								result = result:gsub("}{", "")
							end
							return result
						end
					)
					score = auxtext ~= text and 1 or 0
					text = auxtext
				end
				return auxtext
			end,
			
			to_word = function(linetext, linedur)
				local text = linetext:gsub("\\N", " ")
				text = ke.config.remove_space_in_tags(text)
				text = ke.config.adjust_line(text)
				text = text:gsub("m%s+%-?%d[%.%-%d mlb]*",
					function(shp)
						local shp = shp:gsub(" ", "€")
						return shp
					end
				)
				local linedur = linedur or 10000--or fx.time_dur
				local words = {}
				for w in text:gmatch("[%b{}]*[%S]*[\33-\47\58-\64]*[%s]*") do
						words[#words + 1] = w ~= "" and w:gsub("€", " ") or nil
				end
				if #words > 0 then
					words[#words] = words[#words]:gsub(" ", ""):gsub("	", "")
				elseif #words == 0 then
					words[1] = ("{\\k%d}"):format(math.ceil(linedur / 10))
				end
				return words
			end, --ke.config.to_word(l.text)
			
			text2word = function(linetext, linedur, linestyle, lineleft, linetop)
				local linedur = linedur or 10000--fx.time_dur
				local words = ke.config.to_word(linetext, linedur)
				local words_dur, charn = {}
				local textspc, wordspc = ke.config.remove_tags(linetext):gsub(" ", "")
				if ke.config.karaoke_true(words) then
					for i = 1, #words do
						words_dur[i] = 0
						for kdur in words[i]:gmatch("\\[kK]^*[fo]*(%d+)") do
							words_dur[i] = words_dur[i] + kdur * 10
						end
					end
				else
					charn = unicode.len(textspc)
					for i = 1, #words do
						wordspc = ke.config.remove_tags(words[i]):gsub(" ", "")
						words_dur[i] = ke.math.round(unicode.len(wordspc) * linedur / charn, 3)
					end
				end
				if linestyle then
					local word, start, kw = {}, 0, 1
					for k, w in ipairs(words) do
						local text_stripped = ke.config.remove_tags(w)
						local text_first_spaces = text_stripped:match("(%s+).+") or ""
						local text_without_spaces = text_stripped:gsub("%s+", "")
						local width_first_spaces = aegisub.text_extents(linestyle, text_first_spaces)
						local width_without_spaces = aegisub.text_extents(linestyle, text_without_spaces)
						local width, height, descent, extlead = aegisub.text_extents(linestyle, text_stripped)
						if text_without_spaces:gsub("%s+", "") ~= "" then
							word[kw] = {
								i			= kw,
								ci			= kw,
								si			= kw,
								wi			= kw,
								start_time	= start,
								end_time	= start + words_dur[k],
								duration	= words_dur[k],
								dur			= words_dur[k],
								text		= text_without_spaces,
								text_raw	= w,
								-------------------------------------------------
								width	= width_without_spaces,					top		= linetop,
								left	= lineleft + width_first_spaces,		middle	= linetop + height / 2,
								center	= lineleft + width_without_spaces / 2,	bottom	= linetop + height,
								right	= lineleft + width_without_spaces,		descent	= descent,
								height	= height,								extlead	= extlead,
								-------------------------------------------------
							}
							kw = kw + 1
						end
						start = start + words_dur[k]
						lineleft = lineleft + width
					end
					return word
				end
				return words, words_dur
			end,
			
			text2syl = function(linetext, linedur, linestyle, lineleft, linetop)
				local linedur = linedur or 10000--fx.time_dur
				local words = ke.config.to_word(linetext, linedur)
				local syls, syls_dur, syl_wi, charn, syldur = {}, {}, {}
				local textspc, wordspc = ke.config.remove_tags(linetext):gsub(" ", "")
				if ke.config.karaoke_true(words) then
					for wi, w in pairs(words) do
						for syl in w:gmatch("%b{}[\32-\122\124\126-\255]*") do
							table.insert(syls, syl)
							syldur = 0
							for kdur in syl:gmatch("\\[kK]^*[fo]*(%d+)") do
								syldur = syldur + kdur * 10
							end
							table.insert(syls_dur, syldur)
							table.insert(syl_wi, wi)
						end
					end
				else
					syls, charn = words, unicode.len(textspc)
					for i = 1, #words do
						wordspc = ke.config.remove_tags(words[i]):gsub(" ", "")
						syls_dur[i] = ke.math.round(unicode.len(wordspc) * linedur / charn, 3)
						table.insert(syl_wi, i)
					end
				end
				if linestyle then
					local syl, start, ks = {}, 0, 1
					for k, s in ipairs(syls) do
						local text_stripped = ke.config.remove_tags(s)
						local text_first_spaces = text_stripped:match("(%s+).+") or ""
						local text_without_spaces = text_stripped:gsub("%s+", "")
						local width_first_spaces = aegisub.text_extents(linestyle, text_first_spaces)
						local width_without_spaces = aegisub.text_extents(linestyle, text_without_spaces)
						local width, height, descent, extlead = aegisub.text_extents(linestyle, text_stripped)
						if text_without_spaces:gsub("%s+", "") ~= "" then
							syl[ks] = {
								i			= ks,
								ci			= ks,
								si			= ks,
								wi			= syl_wi[k],
								start_time	= start,
								end_time	= start + syls_dur[k],
								duration	= syls_dur[k],
								dur			= syls_dur[k],
								text		= text_without_spaces,
								text_raw	= s,
								-------------------------------------------------
								width	= width_without_spaces,					top		= linetop,
								left	= lineleft + width_first_spaces,		middle	= linetop + height / 2,
								center	= lineleft + width_without_spaces / 2,	bottom	= linetop + height,
								right	= lineleft + width_without_spaces,		descent	= descent,
								height	= height,								extlead	= extlead,
								-------------------------------------------------
							}
							ks = ks + 1
						end
						start = start + syls_dur[k]
						lineleft = lineleft + width
					end
					return syl
				end
				return syls, syls_dur
			end,
			
			text2char = function(linetext, linedur, linestyle, lineleft, linetop)
				local linedur = linedur or 10000--fx.time_dur
				local words = ke.config.to_word(linetext, linedur)
				local sylstp, syldur, sylspc, charsyl
				local charn, charn_dur = {}, {}
				local char_wi, char_si = {}, {}
				if ke.config.karaoke_true(words) then
					local si = 1
					for wi, w in pairs(words) do
						for syl in w:gmatch("%b{}[\32-\122\124\126-\255]*") do
							syldur, sylstp = 0, ke.config.remove_tags(syl)
							for kdur in syl:gmatch("\\[kK]^*[fo]*(%d+)") do
								syldur = syldur + kdur * 10
							end
							if sylstp == "" then
								table.insert(charn, "")
								table.insert(charn_dur, syldur)
								table.insert(char_wi, wi)
								table.insert(char_si, si)
							else
								sylspc = sylstp:gsub(" ", "")
								charsyl = unicode.len(sylspc) == 0 and 1 or unicode.len(sylspc)
								for c in unicode.chars(sylstp) do
									table.insert(charn, c)
									table.insert(charn_dur, c == " " and 0 or ke.math.round(syldur / charsyl, 3))
									table.insert(char_wi, wi)
									table.insert(char_si, si)
								end
							end
							si = si + 1
						end
					end
				else
					local charline = unicode.len(ke.config.remove_tags(linetext:gsub(" ", "")))
					local swi = 1
					for c in unicode.chars(ke.config.remove_tags(linetext)) do
						table.insert(charn, c)
						table.insert(charn_dur, c == " " and 0 or ke.math.round(linedur / charline, 3))
						table.insert(char_wi, swi)
						table.insert(char_si, swi)
						swi = swi + (c == " " and 1 or 0)
					end
				end
				if linestyle then
					local chars, start, kc = {}, 0, 1
					for k, c in ipairs(charn) do
						local width, height, descent, extlead = aegisub.text_extents(linestyle, c)
						if c ~= " " and c ~= "" then
							chars[kc] = {
								i			= kc,
								ci			= kc,
								si			= char_si[k],
								wi			= char_wi[k],
								start_time	= start,
								end_time	= start + charn_dur[k],
								duration	= charn_dur[k],
								dur			= charn_dur[k],
								text		= c,
								text_raw	= c,
								-------------------------------------------------
								width	= width,				top		= linetop,
								left	= lineleft,				middle	= linetop + height / 2,
								center	= lineleft + width / 2,	bottom	= linetop + height,
								right	= lineleft + width,		descent	= descent,
								height	= height,				extlead	= extlead,
								-------------------------------------------------
							}
							kc = kc + 1
						end
						start = start + charn_dur[k]
						lineleft = lineleft + width
					end
					return chars
				end
				return charn, charn_dur
			end,
			
			preprosses_lines = function(subtitles, meta, styles, index)
				local xres = meta.res_x or 1280
				local yres = meta.res_y or 720
				local DefaultKE = {
					["raw"] = "Style: DefaultKE,Arial,25,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,2,2,20,20,20,1";
					["color1"] = "&H00FFFFFF&";		["color2"] = "&H000000FF&";		["color3"] = "&H00000000&";		["color4"] = "&H00000000&";
					["class"]		= "style";		["name"]		= "DefaultKE";	["fontname"]	= "Arial";		["section"]		= "[V4+ Styles]";
					["bold"]		= false;		["italic"]		= false;		["underline"]	= false;		["strikeout"]	= false;
					["scale_x"]		= 100;			["scale_y"] 	= 100;			["outline"]		= 2;			["shadow"]		= 2;
					["spacing"]		= 0;			["fontsize"]	= 25;			["angle"]		= 0;			["borderstyle"]	= 1;
					["alignment"]	= 2;			["align"]		= 2;			["margin_l"]	= 20;			["margin_r"]	= 20;
					["margin_v"]	= 20;			["margin_b"]	= 20;			["margin_t"]	= 20;			["encoding"]	= 1;
					["relative_to"]	= 2
				}
				local linefx = {}
				for i, v in ipairs(index) do
					local line = subtitles[v]
					line.text_stripped = ke.config.remove_tags(line.text)
					line.text = ke.config.remove_space_in_tags(line.text)
					line.text = line.text:gsub("(%b{})(%s+)([\32-\122\124\126-\255]*)", "%2%1%3")
					local style = styles[line.style] or DefaultKE
					local width, height, descent, extlead = aegisub.text_extents(style, line.text_stripped)
					local options_lft_line = {
						[1] = style.margin_l,
						[2] = (xres + style.margin_l - style.margin_r - width) / 2,
						[3] = xres - style.margin_r - width
					}
					local options_top_line = {
						[1] = yres - style.margin_b - height,
						[2] = (yres + style.margin_t - style.margin_b - height) / 2,
						[3] = style.margin_t
					}
					local left = options_lft_line[(style.align - 1) % 3 + 1]
					local ltop = options_top_line[math.ceil(style.align / 3)]
					local lnfx = {
						i	= i,
						ci	= i,
						si	= i,
						wi	= i,
						----------------------------------------------------------
						start_time	= line.start_time,
						end_time	= line.end_time,
						duration	= line.end_time - line.start_time,
						dur			= line.end_time - line.start_time,
						text_raw	= line.text,
						text		= line.text_stripped,
						----------------------------------------------------------
						width	= width,			top		= ltop,
						left	= left,				middle	= ltop + height / 2,
						center	= left + width / 2,	bottom	= ltop + height,
						right	= left + width,		descent	= descent,
						height	= height,			extlead	= extlead,
						----------------------------------------------------------
						style	= style,
						bold	= style.bold,		underline	= style.underline,
						italic	= style.italic,		strikeout	= style.strikeout,
						align	= style.align,		fontsize	= style.fontsize,
						shadow	= style.shadow,		fontname	= style.fontname,
						spacing	= style.spacing,	margin_b	= style.margin_b,
						scale_x	= style.scale_x,	margin_l	= style.margin_l,
						scale_y	= style.scale_y,	margin_r	= style.margin_r,
						angle	= style.angle,		margin_t	= style.margin_t,
						outline	= style.outline,	margin_v	= style.margin_t,
						----------------------------------------------------------
						color1 = "&H" .. style.color1:match("%x%x(%x%x%x%x%x%x)") .. "&",
						color2 = "&H" .. style.color2:match("%x%x(%x%x%x%x%x%x)") .. "&",
						color3 = "&H" .. style.color3:match("%x%x(%x%x%x%x%x%x)") .. "&",
						color4 = "&H" .. style.color4:match("%x%x(%x%x%x%x%x%x)") .. "&",
						alpha1 = "&H" .. style.color1:match("(%x%x)%x%x%x%x%x%x") .. "&",
						alpha2 = "&H" .. style.color2:match("(%x%x)%x%x%x%x%x%x") .. "&",
						alpha3 = "&H" .. style.color3:match("(%x%x)%x%x%x%x%x%x") .. "&",
						alpha4 = "&H" .. style.color4:match("(%x%x)%x%x%x%x%x%x") .. "&",
						----------------------------------------------------------
						pretime = i == 1 and 300 or line.start_time - linefx[i - 1].end_time,
						posttime = linefx[i + 1] and linefx[i + 1].start_time - line.end_time or 300,
					}
					table.insert(linefx, lnfx)
				end
				return linefx
			end,
			
			get_namesfx = function(mode)
				local mode = mode:gsub(" ", "")
				local names = {}
				for i, xfx in ipairs(templates[mode]) do
					names[i] = ("[%s] %s"):format(i, xfx[1].label:gsub("_", " "):gsub("%S+ %b[]: ", ""))
				end
				return names
			end,
			
			get_indexfx = function(list, name)
				local index = 1
				for i, xfx in ipairs(list)do
					xfx = xfx:gsub("%b[] ", ""):gsub(" ", "_")
					if name == xfx then
						index = i
						break
					end
				end
				return index
			end,
			
			savefx = function(array)
				local function str_op(array, quotation)
					for k, str in ipairs(array) do
						if type(str) == "string" then
							str = str:gsub("\\", "\\\\"):gsub("\"","\\%1"):gsub("\n", "\\n")--:gsub(" +", " ")
							str = quotation and "\"" .. str .. "\"" or str
						end
						array[k] = str
					end
					return table.unpack(array)
				end
				array.fx_folder = array.fx_folder:gsub(" ", "")
				array.fx_namefx = array.fx_namefx == "" and array.fx_folder .. tostring(os.time()):sub(-7, -1) or array.fx_namefx:gsub(" ", "_")
				local values = {--os.date("%X %x") --> 14:22:05 07/04/25
					array.fx_folder, array.fx_namefx, array.fx_type, array.fx_start, array.fx_end, array.fx_layer, array.fx_align,
					array.fx_loop, array.fx_return, array.fx_posx, array.fx_posy, array.fx_time, array.fx_color1, array.fx_color3,
					array.fx_color4, array.fx_alpha1, array.fx_alpha3, array.fx_alpha4, array.fx_variable, array.fx_addtags,
					array.fx_reverse, array.fx_noblank, array.fx_vertical
				}
				local newfx = ("{%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s}"):format(str_op(values, true))
				local newfx = ("	--[[%s %s]]	%s = utilsfx.loadfx(%s)"):format(array.fx_folder, os.date("%X %x"), array.fx_namefx, newfx)
				--------------------------------------------
				local ke_path = debug.getinfo(1, "S").source
				local folfer = ke_path:match("(.*/)") or ke_path:match("(.*\\)")
				local path = folfer .. "newkara_fxlist.lua"
				local fxlines = {}
				for l in io.lines(path) do
					table.insert(fxlines, l)
				end
				table.insert(fxlines, #fxlines - 1, newfx)
				fxfile = io.open(path, "w") --write
				for _, l in ipairs(fxlines) do
					fxfile:write(l .. "\n")
				end
				fxfile:close()
				aegisub.debug.out("The new effect has been saved successfully, you must reload the script Kara so you can see it in the list effects.")
			end, --ke.config.savefx(fx__)
			
			loadprefx = function(guifx)
				local prefx
				prefx = {
					fx_type		= guifx[03].value,	fx_start	= guifx[05].text,	fx_end		= guifx[10].text,
					fx_layer	= guifx[07].text,	fx_align	= guifx[08].text,	fx_loop		= guifx[12].text,
					fx_return	= guifx[14].text,	fx_posx		= guifx[16].text,	fx_posy		= guifx[18].text,
					fx_time		= guifx[21].text,	fx_color1	= guifx[29].value,	fx_color3	= guifx[30].value,
					fx_color4	= guifx[31].value,	fx_alpha1	= guifx[34].value,	fx_alpha3	= guifx[35].value,
					fx_alpha4	= guifx[36].value,	fx_variable	= guifx[42].text,	fx_addtags	= guifx[43].text,
					fx_reverse	= guifx[44].value,	fx_noblank	= guifx[45].value,	fx_vertical	= guifx[46].value,
					fx_modify	= guifx[19].value,	fx_keept	= guifx[23].value,	fx_namefx	= guifx[32].text,
					fx_folder	= guifx[39].value
				}
				return prefx
			end,
			
			valbox = function(fx__, meta, line, l, word, syl, char, fx, var, ke, j, maxj)
				local setting = {fx__, meta, line, l, word, syl, char, fx, var, ke, j, maxj}
				local tovalue = "return function(fx__, meta, line, l, word, syl, char, fx, var, ke, j, maxj) return %s end"
				local totable = "return function(fx__, meta, line, l, word, syl, char, fx, var, ke, j, maxj) return {%s} end"
				---------------------------------------
				local vals = {}
				--start and end times:
				fx__.fx_start = fx__.fx_start:gsub("(%d+%:%d+%:%d+%.%d+)", function(HMS) return tostring(ke.time.HMS_to_ms(HMS)) end)
				fx__.fx_end = fx__.fx_end:gsub( "(%d+%:%d+%:%d+%.%d+)", function(HMS) return tostring(ke.time.HMS_to_ms(HMS)) end)
				fx__.fx_start, fx__.fx_end = ke.tag.tonumber(fx__.fx_start), ke.tag.tonumber(fx__.fx_end)
				local start_t = loadstring(totable:format(fx__.fx_start))()
				local end_t = loadstring(totable:format(fx__.fx_end))()
				vals.start_time = start_t(table.unpack(setting))[1] or line.start_time
				vals.end_time = end_t(table.unpack(setting))[1] or line.end_time
				vals.dur = vals.end_time - vals.start_time
				---------------------------------------
				--align:
				fx__.fx_align = ke.tag.tonumber(fx__.fx_align)
				local align = loadstring(tovalue:format(fx__.fx_align))()
				vals.align = "\\an" .. (align(table.unpack(setting)) or 5)
				---------------------------------------
				--position, move and time move:
				fx__.fx_posx = ke.tag.tonumber(fx__.fx_posx)
				fx__.fx_posy = ke.tag.tonumber(fx__.fx_posy)
				fx__.fx_time = ke.tag.tonumber(fx__.fx_time)
				local pos_x = loadstring(totable:format(fx__.fx_posx))()
				local pos_y = loadstring(totable:format(fx__.fx_posy))()
				local times = loadstring(totable:format(fx__.fx_time))()
				times = times(table.unpack(setting))
				pos_x = pos_x(table.unpack(setting))
				pos_y = pos_y(table.unpack(setting))
				vals.t1, vals.t2 = times[1] or 0, times[1] or vals.dur
				vals.x, vals.y = pos_x[1] or fx.center, pos_y[1] or fx.middle
				local pos_knjx, pos_knjy = vals.x, vals.y
				local pos_rever_x = fx__.fx_reverse and l.right + l.left - 2 * fx.center or 0
				local xres = aegisub.video_size()
				if fx__.fx_vertical then
					pos_rever_x = 0
					local options_px = {
						[1] = l.margin_l + l.height / 2,
						[2] = l.margin_l + (xres - l.margin_l - l.margin_r) / 2,
						[3] = xres - l.margin_r - l.height / 2,
					}
					local options_py = {
						[1] = l.middle + l.height * (0.9 * (fx.i - fx.n)),
						[2] = l.middle + l.height * (0.9 * (fx.i - fx.n / 2 - 1) + 0.45),
						[3] = l.middle + l.height * (0.9 * (fx.i - 1)),
					}
					if fx__.fx_reverse then
						options_py = {
							[1] = l.middle - l.height * (0.9 * (fx.i - 1)),
							[2] = l.middle - l.height * (0.9 * (fx.i - fx.n / 2 - 1) + 0.45),
							[3] = l.middle - l.height * (0.9 * (fx.i - fx.n)),
						}
					end
					pos_knjx = options_px[(tonumber(vals.align:match("%d")) - 1) % 3 + 1]
					pos_knjy = options_py[math.ceil(tonumber(vals.align:match("%d")) / 3)]
				end
				vals.x, vals.y = pos_knjx + pos_rever_x, pos_knjy
				vals.x1, vals.y1 = vals.x, vals.y
				vals.x2, vals.y2 = pos_x[2] or nil, pos_y[2] or nil
				if vals.x2 or vals.y2 then
					vals.x2 = vals.x2 or vals.x1
					vals.y2 = vals.y2 or vals.y1
				end
				vals.pos = ("\\pos(%s,%s)"):format(vals.x, vals.y)
				vals.pos = vals.x2 and ("\\move(%s,%s,%s,%s,%s,%s)"):format(vals.x1, vals.y1, vals.x2, vals.y2, vals.t1, vals.t2) or vals.pos
				---------------------------------------
				--layer:
				fx__.fx_layer = ke.tag.tonumber(fx__.fx_layer)
				local layer = loadstring(tovalue:format(fx__.fx_layer))()
				vals.layer = layer(table.unpack(setting)) or line.layer
				---------------------------------------
				for k, v in pairs(vals) do
					if type(v) == "string" then
						vals[k] = ke.tag.dark(v)
					end
				end
				---------------------------------------
				ke.infofx.fx.time_dur = vals.dur
				ke.infofx.fx.time_ini, ke.infofx.fx.time_fin = vals.start_time, vals.end_time
				ke.infofx.fx.align = vals.align
				ke.infofx.fx.x, ke.infofx.fx.x1, ke.infofx.fx.x2 = vals.x, vals.x1, vals.x1
				ke.infofx.fx.y, ke.infofx.fx.y1, ke.infofx.fx.y2 = vals.y, vals.y1, vals.y1
				ke.infofx.fx.t1, ke.infofx.fx.t2 = vals.t1, vals.t2
				ke.infofx.fx.layer = vals.layer
				---------------------------------------
				--add tags:
				vals.add_tags = ""
				fx__.fx_addtags = ke.tag.tonumber(fx__.fx_addtags)
				local tags = loadstring(totable:format(fx__.fx_addtags))()
				tags = tags(table.unpack(setting))
				if type(tags) == "table" and #tags > 0 then
					for _, v in pairs(tags) do
						vals.add_tags = vals.add_tags .. v
					end
				end
				vals.add_tags = ke.tag.dark(vals.add_tags)
				vals.align = vals.add_tags:match("\\an%d") and "" or vals.align
				vals.pos = vals.add_tags:match("\\[mp]^*o[sv]^*e?") and "" or vals.pos
				ke.infofx.fx.add_tags = vals.add_tags
				---------------------------------------
				--return:
				fx__.fx_return = ke.tag.tonumber(fx__.fx_return)
				local returnfx = loadstring(totable:format(fx__.fx_return))()
				vals.returnfx = returnfx(table.unpack(setting))[1] or fx.text
				if type(vals.returnfx) == "number" then
					vals.returnfx = tostring(vals.returnfx)
				end
				if type(vals.returnfx) == "table" then
					vals.returnfx = ke.table.view(vals.returnfx)
				end
				if vals.returnfx:gsub("%b{}", ""):match("m%s+%-?%d[%.%-%d mlb]*")
					and (vals.returnfx:gsub("%b{}", ""):match("m%s+%-?%d[%.%-%d mlb]*") ~= "m 0 0 m 0 100 "
					and vals.returnfx:gsub("%b{}", ""):match("m%s+%-?%d[%.%-%d mlb]*") ~= "m 0 0 m 100 100 ") then
					local p_in_return = vals.returnfx:match("\\p%d")
					if p_in_return then
						vals.returnfx = vals.returnfx:gsub("\\p%d", "")
						vals.add_tags = vals.add_tags:gsub("\\p%d", "") .. p_in_return
					else
						vals.add_tags = vals.add_tags:match("\\p%d") and vals.add_tags or vals.add_tags .. "\\p1"
					end
					local tags = ke.tag.array(vals.add_tags)
					local stag = ke.table.new({"\\1a", "\\3a", "\\4a", "\\1c", "\\3c", "\\4c"})
					local shape_style = {
						["\\1c"] = ke.color.ass(fx__.fx_color1),	["\\3c"] = ke.color.ass(fx__.fx_color3),
						["\\4c"] = ke.color.ass(fx__.fx_color4),	["\\1a"] = ke.alpha.ass(fx__.fx_alpha1),
						["\\3a"] = ke.alpha.ass(fx__.fx_alpha3),	["\\4a"] = ke.alpha.ass(fx__.fx_alpha4)
					}
					for i, v in ipairs(tags) do
						if stag:inside(v.tag) then
							shape_style[v.tag] = nil
						end
					end
					local shptags = ""
					for k, v in pairs(shape_style) do
						shptags = shptags .. k .. v
					end
					vals.add_tags = shptags .. vals.add_tags
				end
				vals.returnfx = ke.tag.dark(vals.returnfx)
				vals.align = vals.returnfx:match("\\an%d") and "" or vals.align
				vals.pos = vals.returnfx:match("\\[mp]^*o[sv]^*e?") and "" or vals.pos
				ke.infofx.fx.returnfx = vals.returnfx
				---------------------------------------
				ke.table.insert(fx, vals, false, true)
			end,
			
		},
		
		recall = {
			
			remember = function(ref, value)
				ke.recall[ref] = value
				return value
			end,
			
			retime = function(mode, add_start, add_end)
				local add_start = ke.time.HMS_to_ms(add_start) or 0
				local add_end = ke.time.HMS_to_ms(add_end) or 0
				local times, l, fx = ke.infofx.times, ke.infofx.l, ke.infofx.fx
				if mode == "line" then				-- mode[01]
					l.start_time = times.line.start_time + add_start
					l.end_time = times.line.end_time + add_end
				elseif mode == "preline" then		-- mode[02]
					l.start_time = times.line.start_time + add_start
					l.end_time = times.line.start_time + add_end
				elseif mode == "postline" then		-- mode[03]
					l.start_time = times.line.end_time + add_start
					l.end_time = times.line.end_time + add_end
				elseif mode == "word" then			-- mode[04]
					l.start_time = times.line.start_time + times.word.start_time + add_start
					l.end_time = times.line.start_time + times.word.end_time + add_end
				elseif mode == "preword" then		-- mode[05]
					l.start_time = times.line.start_time + times.word.start_time + add_start
					l.end_time = times.line.start_time + times.word.start_time + add_end
				elseif mode == "postword" then		-- mode[06]
					l.start_time = times.line.start_time + times.word.end_time + add_start
					l.end_time = times.line.start_time + times.word.start_time + add_end
				elseif mode == "syl" then			-- mode[07]
					l.start_time = times.line.start_time + times.syl.start_time + add_start
					l.end_time = times.line.start_time + times.syl.end_time + add_end
				elseif mode == "presyl" then		-- mode[08]
					l.start_time = times.line.start_time + times.syl.start_time + add_start
					l.end_time = times.line.start_time + times.syl.start_time + add_end
				elseif mode == "postsyl" then		-- mode[09]
					l.start_time = times.line.start_time + times.syl.end_time + add_start
					l.end_time = times.line.start_time + times.syl.end_time + add_end
				elseif mode == "char" then			-- mode[10]
					l.start_time = times.line.start_time + times.char.start_time + add_start
					l.end_time = times.line.start_time + times.char.end_time + add_end
				elseif mode == "prechar" then		-- mode[11]
					l.start_time = times.line.start_time + times.char.start_time + add_start
					l.end_time = times.line.start_time + times.char.start_time + add_end
				elseif mode == "postchar" then		-- mode[12]
					l.start_time = times.line.start_time + times.char.end_time + add_start
					l.end_time = times.line.start_time + times.char.start_time + add_end
				elseif mode == "start2word"	then	-- mode[13]
					l.start_time = times.line.start_time + add_start
					l.end_time = times.line.start_time + times.word.start_time + add_end
				elseif mode == "word2end" then		-- mode[14]
					l.start_time = times.line.start_time + times.word.end_time + add_start
					l.end_time = times.line.end_time + add_end
				elseif mode == "start2syl" then		-- mode[15]
					l.start_time = times.line.start_time + add_start
					l.end_time = times.line.start_time + times.syl.start_time + add_end
				elseif mode == "syl2end" then		-- mode[16]
					l.start_time = times.line.start_time + times.syl.end_time + add_start
					l.end_time = times.line.end_time + add_end
				elseif mode == "start2char"	then	-- mode[17]
					l.start_time = times.line.start_time + add_start
					l.end_time = times.line.start_time + times.char.start_time + add_end
				elseif mode == "char2end" then		-- mode[18]
					l.start_time = times.line.start_time + times.char.end_time + add_start
					l.end_time = times.line.end_time + add_end
				elseif mode == "linepct" then		-- mode[19]
					l.start_time = times.line.start_time + add_start * times.line.duration / 100
					l.end_time = times.line.start_time + add_end * times.line.duration / 100
				elseif mode == "wordpct" then		-- mode[20]
					l.start_time = times.line.start_time + times.word.start_time + add_start * times.word.duration / 100
					l.end_time = times.line.start_time + times.word.start_time + add_end * times.word.duration / 100
				elseif mode == "sylpct" then		-- mode[21]
					l.start_time = times.line.start_time + times.syl.start_time + add_start * times.syl.duration / 100
					l.end_time = times.line.start_time + times.syl.start_time + add_end * times.syl.duration / 100
				elseif mode == "charpct" then		-- mode[22]
					l.start_time = times.line.start_time + times.char.start_time + add_start * times.char.duration / 100
					l.end_time = times.line.start_time + times.char.start_time + add_end * times.char.duration / 100
				elseif mode == "set" or mode == "abs" then	-- mode[29]
					l.start_time = add_start
					l.end_time = add_end
				elseif mode == "startsyl2char" then	-- mode[23]
					l.start_time = times.line.start_time + times.syl.start_time + add_start
					l.end_time = times.line.start_time + times.char.start_time + add_end
				elseif mode == "startword2syl" then	-- mode[24]
					l.start_time = times.line.start_time + times.word.start_time + add_start
					l.end_time = times.line.start_time + times.syl.start_time + add_end
				elseif mode == "startword2char" then-- mode[25]
					l.start_time = times.line.start_time + times.word.start_time + add_start
					l.end_time = times.line.start_time + times.char.start_time + add_end
				elseif mode == "syl2endword" then	-- mode[26]
					l.start_time = times.line.start_time + times.syl.end_time + add_start
					l.end_time = times.line.start_time + times.word.end_time + add_end
				elseif mode == "char2endsyl" then	-- mode[27]
					l.start_time = times.line.start_time + times.char.end_time + add_start
					l.end_time = times.line.start_time + times.syl.end_time + add_end
				elseif mode == "char2endword" then	-- mode[28]
					l.start_time = times.line.start_time + times.char.end_time + add_start
					l.end_time = times.line.start_time + times.word.end_time + add_end
				else								-- mode["default"]
					l.start_time = times.line.start_time
					l.end_time = times.line.end_time
				end --ke.recall.retime("preword", 0, 0)
				fx.time_ini = l.start_time
				fx.time_fin = l.end_time
				fx.time_dur = fx.time_fin - fx.time_ini
				return ""
			end,
			
			maxloop = function(newmaxloop)
				local fx = ke.infofx.fx
				fx.maxj = math.abs(math.ceil(newmaxloop or 1))
				return ""
			end, --ke.recall.maxloop(3)
			
		},
		
		decode = {
			
			config = include("kelibs\\newkara_ffi.lua"),
			
			utf8 = {
				
				chars = function(s)
					--Creates iterator through UTF8 characters
					if type(s) ~= "string" then
						error("string expected", 2)
					end
					local char_i, s_pos, s_len = 0, 1, #s
					local charrange = function(s, i)
						--UTF8 character range at string codepoint
						local byte = s:byte(i)
						return not byte and 0 or byte < 192 and 1 or byte < 224 and 2 or byte < 240 and 3 or byte < 248 and 4 or byte < 252 and 5 or 6
					end
					return function()
						if s_pos <= s_len then
							local cur_pos = s_pos
							s_pos = s_pos + charrange(s, s_pos)
							if s_pos - 1 <= s_len then
								char_i = char_i + 1
								return char_i, s:sub(cur_pos, s_pos - 1)
							end
						end
					end
				end,
				
				len = function(s)
					--Get UTF8 characters number in string
					if type(s) ~= "string" then
						error("string expected", 2)
					end
					local n = 0
					for _ in ke.decode.utf8.chars(s) do
						n = n + 1
					end
					return n
				end,
				
				utf8_to_utf16 = function(s)
					local wlen = ke.decode.config.ffi.C.MultiByteToWideChar(ke.decode.config.ffi.C.CP_UTF8X2, 0x0, s, -1, nil, 0)
					local ws = ke.decode.config.ffi.new("wchar_t[?]", wlen)
					ke.decode.config.ffi.C.MultiByteToWideChar(ke.decode.config.ffi.C.CP_UTF8X2, 0x0, s, -1, ws, wlen)
					return ws
				end,
				
				utf16_to_utf8 = function(ws)
					local slen = ke.decode.config.ffi.C.WideCharToMultiByte(ke.decode.config.ffi.C.CP_UTF8X2, 0x0, ws, -1, nil, 0, nil, nil)
					local s = ke.decode.config.ffi.new("char[?]", slen)
					ke.decode.config.ffi.C.WideCharToMultiByte(ke.decode.config.ffi.C.CP_UTF8X2, 0x0, ws, -1, s, slen, nil, nil)
					return ke.decode.config.ffi.string(s)
				end,
				
			},
			
			create_font = function(family, bold, italic, underline, strikeout, size, xscale, yscale, hspace)
				--Creates font
				if type(family) ~= "string" or type(bold) ~= "boolean" or type(italic) ~= "boolean" or type(underline) ~= "boolean" or type(strikeout) ~= "boolean" or type(size) ~= "number" or size <= 0 or
					(xscale ~= nil and type(xscale) ~= "number") or (yscale ~= nil and type(yscale) ~= "number") or (hspace ~= nil and type(hspace) ~= "number") then
					error("expected family, bold, italic, underline, strikeout, size and optional horizontal & vertical scale and intercharacter space", 2)
				end
				local xscale = not xscale and 1 or xscale
				local yscale = not yscale and 1 or yscale
				local hspace = not hspace and 0 or hspace
				local upscale = FONT_PRECISION
				local downscale = 1 / upscale
				if ke.decode.config.ffi.os == "Windows" then
					local resources_deleter
					local dc = ke.decode.config.ffi.gc(ke.decode.config.ffi.C.CreateCompatibleDC(nil), function() resources_deleter() end)
					ke.decode.config.ffi.C.SetMapMode(dc, ke.decode.config.ffi.C.MM_TEXT2X)
					ke.decode.config.ffi.C.SetBkMode(dc, ke.decode.config.ffi.C.TRANSPARENT2X)
					family = ke.decode.utf8.utf8_to_utf16(family)
					if ke.decode.config.ffi.C.wcslen(family) > 31 then
						error("family name to long", 2)
					end
					local font = ke.decode.config.ffi.C.CreateFontW(
						size * upscale,									--nHeight
						0,												--nWidth
						0,												--nEscapement
						0,												--nOrientation
						bold and ke.decode.config.ffi.C.FW_BOLD2X or ke.decode.config.ffi.C.FW_NORMAL2X,	--fnWeight
						italic and 1 or 0,								--fdwItalic
						underline and 1 or 0,							--fdwUnderline
						strikeout and 1 or 0,							--fdwStrikeOut
						ke.decode.config.ffi.C.DEFAULT_CHARSET2X,						--fdwCharSet
						ke.decode.config.ffi.C.OUT_TT_PRECIS2X,							--fdwOutputPrecision
						ke.decode.config.ffi.C.CLIP_DEFAULT_PRECIS2X,					--fdwClipPrecision
						ke.decode.config.ffi.C.ANTIALIASED_QUALITY2X,					--fdwQuality
						ke.decode.config.ffi.C.DEFAULT_PITCH2X + ke.decode.config.ffi.C.FF_DONTCARE2X,	--fdwPitchAndFamily
						family
					)
					local old_font = ke.decode.config.ffi.C.SelectObject(dc, font)
					resources_deleter = function()
						ke.decode.config.ffi.C.SelectObject(dc, old_font)
						ke.decode.config.ffi.C.DeleteObject(font)
						ke.decode.config.ffi.C.DeleteDC(dc)
					end
					return {
						metrics = function()
							local metrics = ke.decode.config.ffi.new("TEXTMETRICW[1]")
							ke.decode.config.ffi.C.GetTextMetricsW(dc, metrics)
							return {
								height = metrics[0].tmHeight * downscale * yscale,
								ascent = metrics[0].tmAscent * downscale * yscale,
								descent = metrics[0].tmDescent * downscale * yscale,
								internal_leading = metrics[0].tmInternalLeading * downscale * yscale,
								external_leading = metrics[0].tmExternalLeading * downscale * yscale
							}
						end,
						text_extents = function(text)
							if type(text) ~= "string" then
								error("text expected", 2)
							end
							text = ke.decode.utf8.utf8_to_utf16(text)
							local text_len = ke.decode.config.ffi.C.wcslen(text)
							local size = ke.decode.config.ffi.new("SIZE[1]")
							ke.decode.config.ffi.C.GetTextExtentPoint32W(dc, text, text_len, size)
							return {
								width = (size[0].cx * downscale + hspace * text_len) * xscale,
								height = size[0].cy * downscale * yscale
							}
						end,
						
						text_to_shape = function(text)
							--Converts text to ASS shape
							if type(text) ~= "string" then
								error("text expected", 2)
							end
							local shape, shape_n = {}, 0
							text = ke.decode.utf8.utf8_to_utf16(text)
							local text_len = ke.decode.config.ffi.C.wcslen(text)
							if text_len > 8192 then
								error("text too long", 2)
							end
							local char_widths
							if hspace ~= 0 then
								char_widths = ke.decode.config.ffi.new("INT[?]", text_len)
								local size, space = ke.decode.config.ffi.new("SIZE[1]"), hspace * upscale
								for i = 0, text_len - 1 do
									ke.decode.config.ffi.C.GetTextExtentPoint32W(dc, text + i, 1, size)
									char_widths[i] = size[0].cx + space
								end
							end
							ke.decode.config.ffi.C.BeginPath(dc)
							ke.decode.config.ffi.C.ExtTextOutW(dc, 0, 0, 0x0, nil, text, text_len, char_widths)
							ke.decode.config.ffi.C.EndPath(dc)
							local points_n = ke.decode.config.ffi.C.GetPath(dc, nil, nil, 0)
							if points_n > 0 then
								local points, types = ke.decode.config.ffi.new("POINT[?]", points_n), ke.decode.config.ffi.new("BYTE[?]", points_n)
								ke.decode.config.ffi.C.GetPath(dc, points, types, points_n)
								local i, last_type, cur_type, cur_point = 0
								while i < points_n do
									cur_type, cur_point = types[i], points[i]
									if cur_type == ke.decode.config.ffi.C.PT_MOVETO2X then
										if last_type ~= ke.decode.config.ffi.C.PT_MOVETO2X then
											shape_n = shape_n + 1
											shape[shape_n] = "m"
											last_type = cur_type
										end
										shape[shape_n + 1] = ke.math.round(cur_point.x * downscale * xscale, FP_PRECISION)
										shape[shape_n + 2] = ke.math.round(cur_point.y * downscale * yscale, FP_PRECISION)
										shape_n = shape_n + 2
										i = i + 1
									elseif cur_type == ke.decode.config.ffi.C.PT_LINETO2X or cur_type == (ke.decode.config.ffi.C.PT_LINETO2X + ke.decode.config.ffi.C.PT_CLOSEFIGURE2X) then
										if last_type ~= ke.decode.config.ffi.C.PT_LINETO2X then
											shape_n = shape_n + 1
											shape[shape_n] = "l"
											last_type = cur_type
										end
										shape[shape_n + 1] = ke.math.round(cur_point.x * downscale * xscale, FP_PRECISION)
										shape[shape_n + 2] = ke.math.round(cur_point.y * downscale * yscale, FP_PRECISION)
										shape_n = shape_n + 2
										i = i + 1
									elseif cur_type == ke.decode.config.ffi.C.PT_BEZIERTO2X or cur_type == (ke.decode.config.ffi.C.PT_BEZIERTO2X + ke.decode.config.ffi.C.PT_CLOSEFIGURE2X) then
										if last_type ~= ke.decode.config.ffi.C.PT_BEZIERTO2X then
											shape_n = shape_n + 1
											shape[shape_n] = "b"
											last_type = cur_type
										end
										shape[shape_n + 1] = ke.math.round(cur_point.x * downscale * xscale, FP_PRECISION)
										shape[shape_n + 2] = ke.math.round(cur_point.y * downscale * yscale, FP_PRECISION)
										shape[shape_n + 3] = ke.math.round(points[i + 1].x * downscale * xscale, FP_PRECISION)
										shape[shape_n + 4] = ke.math.round(points[i + 1].y * downscale * yscale, FP_PRECISION)
										shape[shape_n + 5] = ke.math.round(points[i + 2].x * downscale * xscale, FP_PRECISION)
										shape[shape_n + 6] = ke.math.round(points[i + 2].y * downscale * yscale, FP_PRECISION)
										shape_n = shape_n + 6
										i = i + 3
									else
										i = i + 1
									end
									if cur_type % 2 == 1 then
										shape_n = shape_n + 1
										shape[shape_n] = "c"
									end
								end
							end
							ke.decode.config.ffi.C.AbortPath(dc)
							return table.concat(shape, " ")
						end
					}
				else
					if not ke.decode.config.pangocairo then
						error("pangocairo library couldn't be loaded", 2)
					end
					local surface = ke.decode.config.pangocairo.cairo_image_surface_create(ke.decode.config.ffi.C.CAIRO_FORMAT_A8X, 1, 1)
					local context = ke.decode.config.pangocairo.cairo_create(surface)
					local layout
					layout = ke.decode.config.ffi.gc(ke.decode.config.pangocairo.pango_cairo_create_layout(context), function()
						ke.decode.config.pangocairo.g_object_unref(layout)
						ke.decode.config.pangocairo.cairo_destroy(context)
						ke.decode.config.pangocairo.cairo_surface_destroy(surface)
					end)
					local font_desc = ke.decode.config.ffi.gc(ke.decode.config.pangocairo.pango_font_description_new(), ke.decode.config.pangocairo.pango_font_description_free)
					ke.decode.config.pangocairo.pango_font_description_set_family(font_desc, family)
					ke.decode.config.pangocairo.pango_font_description_set_weight(font_desc, bold and ke.decode.config.ffi.C.PANGO_WEIGHT_BOLD2 or ke.decode.config.ffi.C.PANGO_WEIGHT_NORMAL2)
					ke.decode.config.pangocairo.pango_font_description_set_style(font_desc, italic and ke.decode.config.ffi.C.PANGO_STYLE_ITALIC or ke.decode.config.ffi.C.PANGO_STYLE_NORMAL)
					ke.decode.config.pangocairo.pango_font_description_set_absolute_size(font_desc, size * ke.decode.config.ffi.C.PANGO_SCALE2 * upscale)
					ke.decode.config.pangocairo.pango_layout_set_font_description(layout, font_desc)
					local attr = ke.decode.config.ffi.gc(ke.decode.config.pangocairo.pango_attr_list_new(), ke.decode.config.pangocairo.pango_attr_list_unref)
					ke.decode.config.pangocairo.pango_attr_list_insert(attr, ke.decode.config.pangocairo.pango_attr_underline_new(underline and ke.decode.config.ffi.C.PANGO_UNDERLINE_SINGLE or ke.decode.config.ffi.C.PANGO_UNDERLINE_NONE))
					ke.decode.config.pangocairo.pango_attr_list_insert(attr, ke.decode.config.pangocairo.pango_attr_strikethrough_new(strikeout))
					ke.decode.config.pangocairo.pango_attr_list_insert(attr, ke.decode.config.pangocairo.pango_attr_letter_spacing_new(hspace * ke.decode.config.ffi.C.PANGO_SCALE2 * upscale))
					ke.decode.config.pangocairo.pango_layout_set_attributes(layout, attr)
					local fonthack_scale = 1
					return {
						metrics = function()
							local metrics = ke.decode.config.ffi.gc(ke.decode.config.pangocairo.pango_context_get_metrics(ke.decode.config.pangocairo.pango_layout_get_context(layout), ke.decode.config.pangocairo.pango_layout_get_font_description(layout), nil), ke.decode.config.pangocairo.pango_font_metrics_unref)
							local ascent, descent = ke.decode.config.pangocairo.pango_font_metrics_get_ascent(metrics) / ke.decode.config.ffi.C.PANGO_SCALE2 * downscale,
													ke.decode.config.pangocairo.pango_font_metrics_get_descent(metrics) / ke.decode.config.ffi.C.PANGO_SCALE2 * downscale
							return {
								height = (ascent + descent) * yscale * fonthack_scale,
								ascent = ascent * yscale * fonthack_scale,
								descent = descent * yscale * fonthack_scale,
								internal_leading = 0,
								external_leading = ke.decode.config.pangocairo.pango_layout_get_spacing(layout) / ke.decode.config.ffi.C.PANGO_SCALE2 * downscale * yscale * fonthack_scale
							}
						end,
						text_extents = function(text)
							if type(text) ~= "string" then
								error("text expected", 2)
							end
							ke.decode.config.pangocairo.pango_layout_set_text(layout, text, -1)
							local rect = ke.decode.config.ffi.new("PangoRectangle[1]")
							ke.decode.config.pangocairo.pango_layout_get_pixel_extents(layout, nil, rect)
							return {
								width = rect[0].width * downscale * xscale * fonthack_scale,
								height = rect[0].height * downscale * yscale * fonthack_scale
							}
						end,
						
						text_to_shape = function(text)
							if type(text) ~= "string" then
								error("text expected", 2)
							end
							ke.decode.config.pangocairo.cairo_save(context)
							ke.decode.config.pangocairo.cairo_scale(context, downscale * xscale * fonthack_scale, downscale * yscale * fonthack_scale)
							ke.decode.config.pangocairo.pango_layout_set_text(layout, text, -1)
							ke.decode.config.pangocairo.pango_cairo_layout_path(context, layout)
							ke.decode.config.pangocairo.cairo_restore(context)
							local shape, shape_n = {}, 0
							local path = ke.decode.config.ffi.gc(ke.decode.config.pangocairo.cairo_copy_path(context), ke.decode.config.pangocairo.cairo_path_destroy)
							if(path[0].status == ke.decode.config.ffi.C.CAIRO_STATUS_SUCCESS2) then
								local i, cur_type, last_type = 0
								while(i < path[0].num_data) do
									cur_type = path[0].data[i].header.type
									if cur_type == ke.decode.config.ffi.C.CAIRO_PATH_MOVE_TO then
										if cur_type ~= last_type then
											shape_n = shape_n + 1
											shape[shape_n] = "m"
										end
										shape[shape_n + 1] = ke.math.round(path[0].data[i + 1].point.x, FP_PRECISION)
										shape[shape_n + 2] = ke.math.round(path[0].data[i + 1].point.y, FP_PRECISION)
										shape_n = shape_n + 2
									elseif cur_type == ke.decode.config.ffi.C.CAIRO_PATH_LINE_TO then
										if cur_type ~= last_type then
											shape_n = shape_n + 1
											shape[shape_n] = "l"
										end
										shape[shape_n + 1] = ke.math.round(path[0].data[i + 1].point.x, FP_PRECISION)
										shape[shape_n + 2] = ke.math.round(path[0].data[i + 1].point.y, FP_PRECISION)
										shape_n = shape_n + 2
									elseif cur_type == ke.decode.config.ffi.C.CAIRO_PATH_CURVE_TO then
										if cur_type ~= last_type then
											shape_n = shape_n + 1
											shape[shape_n] = "b"
										end
										shape[shape_n + 1] = ke.math.round(path[0].data[i + 1].point.x, FP_PRECISION)
										shape[shape_n + 2] = ke.math.round(path[0].data[i + 1].point.y, FP_PRECISION)
										shape[shape_n + 3] = ke.math.round(path[0].data[i + 2].point.x, FP_PRECISION)
										shape[shape_n + 4] = ke.math.round(path[0].data[i + 2].point.y, FP_PRECISION)
										shape[shape_n + 5] = ke.math.round(path[0].data[i + 3].point.x, FP_PRECISION)
										shape[shape_n + 6] = ke.math.round(path[0].data[i + 3].point.y, FP_PRECISION)
										shape_n = shape_n + 6
									elseif cur_type == ke.decode.config.ffi.C.CAIRO_PATH_CLOSE_PATH then
										if cur_type ~= last_type then
											shape_n = shape_n + 1
											shape[shape_n] = "c"
										end
									end
									last_type = cur_type
									i = i + path[0].data[i].header.length
								end
							end
							ke.decode.config.pangocairo.cairo_new_path(context)
							return table.concat(shape, " ")
						end
					}
				end
			end,
			
			list_fonts = function(with_filenames)
				--Lists available system fonts
				if with_filenames ~= nil and type(with_filenames) ~= "boolean" then
					error("optional boolean expected", 2)
				end
				local fonts = {n = 0}
				if ke.decode.config.ffi.os == "Windows" then
					local plogfont = ke.decode.config.ffi.new("LOGFONTW[1]")
					plogfont[0].lfCharSet = ke.decode.config.ffi.C.DEFAULT_CHARSET2X
					plogfont[0].lfFaceName[0] = 0	--Empty string
					plogfont[0].lfPitchAndFamily = ke.decode.config.ffi.C.DEFAULT_PITCH2X + ke.decode.config.ffi.C.FF_DONTCARE2X
					local fontname, style, font
					ke.decode.config.ffi.C.EnumFontFamiliesExW(ke.decode.config.ffi.gc(ke.decode.config.ffi.C.CreateCompatibleDC(nil), ke.decode.config.ffi.C.DeleteDC), plogfont, function(penumlogfont, _, fonttype, _)
						fontname, style = ke.decode.utf8.utf16_to_utf8(penumlogfont[0].elfLogFont.lfFaceName), utf16_to_utf8(penumlogfont[0].elfStyle)
						for i = 1, fonts.n do
							font = fonts[i]
							if font.name == fontname and font.style == style then
								goto win_font_found
							end
						end
						fonts.n = fonts.n + 1
						fonts[fonts.n] = {
							name = fontname,
							longname = ke.decode.utf8.utf16_to_utf8(penumlogfont[0].elfFullName),
							style = style,
							type = fonttype == ke.decode.config.ffi.C.FONTTYPE_RASTER2X and "Raster" or fonttype == ke.decode.config.ffi.C.FONTTYPE_DEVICE2X and "Device" or fonttype == ke.decode.config.ffi.C.FONTTYPE_TRUETYPE2X and "TrueType" or "Unknown",
						}
						::win_font_found::
						return 1
					end, 0, 0)
					if with_filenames then
						local function file_to_font(fontname, fontfile)
							for i = 1, fonts.n do
								font = fonts[i]
								if fontname == font.name:gsub("^@", "", 1) or fontname == ("%s %s"):format(font.name:gsub("^@", "", 1), font.style) or fontname == font.longname:gsub("^@", "", 1) then
									font.file = fontfile
								end
							end
						end
						local pregkey, fontfile = ke.decode.config.ffi.new("HKEY[1]")
						if ke.decode.config.advapix.RegOpenKeyExA(ke.decode.config.ffi.cast("HKEY", ke.decode.config.ffi.C.HKEY_LOCAL_MACHINE2X), "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts", 0, ke.decode.config.ffi.C.KEY_READ2X, pregkey) == ke.decode.config.ffi.C.ERROR_SUCCESS2X then
							local regkey = ke.decode.config.ffi.gc(pregkey[0], ke.decode.config.advapix.RegCloseKey)
							local value_index, value_name, pvalue_name_size, value_data, pvalue_data_size = 0, ke.decode.config.ffi.new("wchar_t[16383]"), ke.decode.config.ffi.new("DWORD[1]"), ke.decode.config.ffi.new("BYTE[65536]"), ke.decode.config.ffi.new("DWORD[1]")
							while true do
								pvalue_name_size[0], pvalue_data_size[0] = ke.decode.config.ffi.sizeof(value_name) / ke.decode.config.ffi.sizeof("wchar_t"), ke.decode.config.ffi.sizeof(value_data)
								if ke.decode.config.advapix.RegEnumValueW(regkey, value_index, value_name, pvalue_name_size, nil, nil, value_data, pvalue_data_size) ~= ke.decode.config.ffi.C.ERROR_SUCCESS2X then
									break
								else
									value_index = value_index + 1
								end
								fontname = ke.decode.utf8.utf16_to_utf8(value_name):gsub("(.*) %(.-%)$", "%1", 1)
								fontfile = ke.decode.utf8.utf16_to_utf8(ke.decode.config.ffi.cast("wchar_t*", value_data))
								file_to_font(fontname, fontfile)
								if fontname:find(" & ") then
									for fontname in fontname:gmatch("(.-) & ") do
										file_to_font(fontname, fontfile)
									end
									file_to_font(fontname:match(".* & (.-)$"), fontfile)
								end
							end
						end
					end
				else	--Unix
					if not ke.decode.config.fontconfig then
						error("fontconfig library couldn't be loaded", 2)
					end
					local fontset = ke.decode.config.ffi.gc(ke.decode.config.fontconfig.FcFontList(ke.decode.config.fontconfig.FcInitLoadConfigAndFonts(),
						ke.decode.config.ffi.gc(ke.decode.config.fontconfig.FcPatternCreate(), ke.decode.config.fontconfig.FcPatternDestroy),
						ke.decode.config.ffi.gc(ke.decode.config.fontconfig.FcObjectSetBuild("family", "fullname", "style", "outline", with_filenames and "file" or nil, nil), ke.decode.config.fontconfig.FcObjectSetDestroy)),
						ke.decode.config.fontconfig.FcFontSetDestroy)
					local font, family, fullname, style, outline, file
					local cstr, cbool = ke.decode.config.ffi.new("FcChar8*[1]"), ke.decode.config.ffi.new("FcBool[1]")
					for i = 0, fontset[0].nfont - 1 do
						font = fontset[0].fonts[i]
						family, fullname, style, outline, file = nil
						if ke.decode.config.fontconfig.FcPatternGetString(font, "family", 0, cstr) == ke.decode.config.ffi.C.FcResultMatch then
							family = ke.decode.config.ffi.string(cstr[0])
						end
						if ke.decode.config.fontconfig.FcPatternGetString(font, "fullname", 0, cstr) == ke.decode.config.ffi.C.FcResultMatch then
							fullname = ke.decode.config.ffi.string(cstr[0])
						end
						if ke.decode.config.fontconfig.FcPatternGetString(font, "style", 0, cstr) == ke.decode.config.ffi.C.FcResultMatch then
							style = ke.decode.config.ffi.string(cstr[0])
						end
						if ke.decode.config.fontconfig.FcPatternGetBool(font, "outline", 0, cbool) == ke.decode.config.ffi.C.FcResultMatch then
							outline = cbool[0]
						end
						if ke.decode.config.fontconfig.FcPatternGetString(font, "file", 0, cstr) == ke.decode.config.ffi.C.FcResultMatch then
							file = ke.decode.config.ffi.string(cstr[0])
						end
						if family and fullname and style and outline then
							fonts.n = fonts.n + 1
							fonts[fonts.n] = {
								name = family,
								longname = fullname,
								style = style,
								type = outline == 0 and "Raster" or "Outline",
								file = file
							}
						end
					end
				end
				table.sort(fonts, function(font1, font2)
					if font1.name == font2.name then
						return font1.style < font2.style
					else
						return font1.name < font2.name
					end
				end)
				return fonts
			end,
			
		},
		
		infofx = {
		},
		
		image = {
			
			to_pixels = function(png)
				local image = require("ILL.IMG")
				local png = png or "C:\\Users\\victo\\Escritorio\\effector2\\demo4.png"
				local img = image.LIBPNG(png):decode()
				local w, h = img.width, img.height
				local data = img:getData()
				local pixels = {}

				for x = 0, w - 1 do
					for y = 0, h - 1 do
						local i = y * w + x
						local v = data[i]
						local r, g, b, a = v.r, v.g, v.b, v.a
						pixels[string.format("%s,%s", x, y)] = {string.format("&H%02X%02X%02X&", b, g, r), ("&H%02X&"):format(255 - a)}
					end
				end
				return pixels
			end, --ke.image.to_pixels()
			
			
		},
	}
	
	return ke