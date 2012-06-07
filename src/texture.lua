texture = {}

local function _clamp( x, xmin, xmax )
	if x < xmin then
		return xmin
	elseif x > xmax then
		return xmax
	end

	return x
end

local function _smootherstep( x, xmin, xmax )
	local t =  _clamp((x - xmin)/(xmax - xmin), 0, 1);
   
    return t*t*t*(t*(t*6 - 15) + 10)
end

-- bands = {
--     [percentage] = { r, g, b, a } -- r,g,b,a : [0..255]
-- }*
function texture.bandedCLUT( bands, w, h, option )
	assert(bands[1] and bands[100])

	local result = love.image.newImageData(w, h)

	for y = 0, h-1 do
		local probe = 1 + y * (99 / (h - 1))

		local lowerpc = 0
		local upperpc = 100

		for percent, color in pairs(bands) do
			if percent <= probe and percent > lowerpc then
				lowerpc = percent
			end

			if percent >= probe and percent < upperpc then
				upperpc = percent
			end
		end

		local r, g, b, a

		if lowerpc == upperpc then
			local color = bands[lowerpc]	
			r, g, b, a = color[1], color[2], color[3], color[4]
		else
			local lower = bands[lowerpc]
			local upper = bands[upperpc]

			local bias = _smootherstep(probe, lowerpc, upperpc)
			
			r = (1 - bias) * lower[1] + bias * upper[1]
			g = (1 - bias) * lower[2] + bias * upper[2]
			b = (1 - bias) * lower[3] + bias * upper[3]
			a = (1 - bias) * lower[4] + bias * upper[4]
		end

		for x = 0, w-1 do
			local bias = x / (w-1)

			if option ~= 'grey' then
				result:setPixel(x, y, bias * r, bias * g, bias * b, a)
			else
				local grey = (r * 0.3086) + (g * 0.6094) + (b * 0.0820)

				local nr = (r * bias) + (grey * (1 - bias))
				local ng = (g * bias) + (grey * (1 - bias))
				local nb = (b * bias) + (grey * (1 - bias))

				result:setPixel(x, y, bias * nr, bias * ng, bias * nb, a)
				-- result:setPixel(x, y, bias * r, bias * g, bias * b, a)
			end
		end
	end

	result:encode('clut.png')

	return love.graphics.newImage(result)
end

function texture.mound( w, h )
	local result = love.image.newImageData(w, h)

	local cx = w * 0.5
	local cy = h * 0.5
	local edge = cx * 0.99

	for y = 0, h-1 do
		for x = 0, w-1 do
			local dx, dy = cx - x, cy - y
			local d = math.sqrt((dx * dx) + (dy * dy))
			local v = (1 - _smootherstep(d, 0, cx))^2 * 255
			-- local vl = 255 * (1 - _clamp(d / cx, 0, 1))
			result:setPixel(x, y, v, 0, 0, 255)
		end
	end

	return love.graphics.newImage(result)
end

function texture.circle( w, h, r, g, b, a )
	local result = love.image.newImageData(w, h)

	local cx = w * 0.5
	local cy = h * 0.5
	local radius = math.min(cx, cy) * 0.99

	result:mapPixel(
		function ( x, y )
			local dx, dy = cx - x, cy - y
			local d = math.sqrt((dx * dx) + (dy * dy))

			if d > radius then
				return 0, 0, 0, 0
			else
				return r, g, b, a
			end
		end)

	return love.graphics.newImage(result)
end

function texture.featheredCircle( w, h, r, g, b, a, feather )
	feather = feather or 1
	assert(0 <= feather and feather <= 1)

	local result = love.image.newImageData(w, h)

	local cx = w * 0.5
	local cy = h * 0.5
	local outerRadius = math.min(cx, cy) * 0.99
	local innerRadius = outerRadius * feather

	result:mapPixel(
		function ( x, y )
			local dx, dy = cx - x, cy - y
			local d = math.sqrt((dx * dx) + (dy * dy))

			if d > outerRadius then
				return 0, 0, 0, 0
			elseif d > innerRadius then
				local f = 1 - ((d - innerRadius) / (outerRadius - innerRadius))
				-- f = f * f

				return f*r, f*g, f*b, f*a
			else
				return r, g, b, a
			end
		end)

	return love.graphics.newImage(result)
end

function texture.smootherCircle( w, h, r, g, b, a, feather )
	feather = feather or 1
	assert(0 <= feather and feather <= 1)

	local result = love.image.newImageData(w, h)

	local cx = w * 0.5
	local cy = h * 0.5
	local outerRadius = math.min(cx, cy) * 0.99
	local innerRadius = outerRadius * feather

	result:mapPixel(
		function ( x, y )
			local dx, dy = cx - x, cy - y
			local d = math.sqrt((dx * dx) + (dy * dy))

			if d > outerRadius then
				return 0, 0, 0, 0
			elseif d > innerRadius then
				local f = 1 - _smootherstep(d, innerRadius, outerRadius)

				return f*r, f*g, f*b, f*a
			else
				return r, g, b, a
			end
		end)

	return love.graphics.newImage(result)
end