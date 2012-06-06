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
function texture.bandedCLUT( bands, w, h )
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
			-- result:setPixel(x, y, bias * r, bias * g, bias * b, a)

			local grey = (r * 0.3086) + (g * 0.6094) + (b * 0.0820)

			r = r * bias + grey * (1 - bias)
			g = g * bias + grey * (1 - bias)
			b = b * bias + grey * (1 - bias)

			result:setPixel(x, y, r, g, b, a)
		end
	end

	return love.graphics.newImage(result)
end

-- TODO: We need different 'mounds' for different roles:
-- 1. As base heightmap data.
-- 2. As lights
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
			local vl = 255 * (1 - _clamp(d / cx, 0, 1))
			result:setPixel(x, y, v, vl, v, 255)
		end
	end

	return love.graphics.newImage(result)
end

