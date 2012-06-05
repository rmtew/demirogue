require 'misc'
require 'expand'

assert(love.graphics.isSupported('pixeleffect'), 'metalines requires pixeleffects')

-- This pixel effect draws the distance field onto a background canvas.
local metalineEffectSrc = [[
	// first point of the metaline segment
	extern vec2 origins[$(NUMLINES)];
	// the direction of the metaline
	extern vec2 norms[$(NUMLINES)];
	extern float lengths[$(NUMLINES)];
	// the 'light' value for the ends of each line.
	extern vec2 intensities[$(NUMLINES)];
	// the maximum distance away from the metaline that we can set.
	extern float width;

	vec2 metaline(vec2 pc, vec2 lorigin, vec2 lnorm, float llength, vec2 lintensity)
	{
		vec2 disp = pc - lorigin;
		float lambda = dot(disp, lnorm);
		lambda = clamp(lambda, 0, llength);

		vec2 proj = lorigin + (lnorm * lambda);
		vec2 dispnear = pc - proj;
		float d = length(dispnear);    // distance from the line
		float invd = width - d;        // inverse distance
		float within = step(0, invd);  // 1.0 if within width, 0.0 otherwise
		float invdc = within * invd;   // inverse distance clamped >= 0
		float invdcn = invdc / width;  // inverse distance clamped and normalised to [0..1]

		float lambdan = lambda / llength;

		float p1int = (1 - lambdan) * lintensity.x;
		float p2int = lambdan * lintensity.y;

		float intensity = invdcn * (p1int + p2int);
		// float intensity = (((1 - lambdan) * lintensity.x) + (lambdan * lintensity.y));
		//float intensity = lintensity.x;
		// float intensity = lintensity.x;


		// n^3 seems to look the best
		return vec2(invdcn * invdcn * invdcn, intensity);
	}

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
	{
		/*
		float p = 0.0;
		float i = 0.0;
		
		#(for i = 0, NUMLINES-1 do)
            vec2 pi$(i) = metaline(pc, origins[$(i)], norms[$(i)], lengths[$(i)], intensities[$(i)]);
            p += pi$(i).x;
            i = max(i, pi$(i).y);
        #(end)

		return vec4(p, i, 0, 1);
        */
        vec2 p = vec2(0.0, 0.0);
		
		#(for i = 0, NUMLINES-1 do)
            p += metaline(pc, origins[$(i)], norms[$(i)], lengths[$(i)], intensities[$(i)]);
        #(end)

		return vec4(p.x, p.y, 0, 1);
	}
]]

local minMetalinesPerBatch, maxMetalinesPerBatch = 1, 16
local metalineEffects = {}

for i = minMetalinesPerBatch, maxMetalinesPerBatch do
	local expanded = expand(metalineEffectSrc, { NUMLINES = i})
	metalineEffects[i] = love.graphics.newPixelEffect(expanded)
end

local clutEffectSrc = [[
	extern Image clut;

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
	{
		vec2 pi = Texel(tex, tc).xy;

		return Texel(clut, vec2(pi.y, pi.x));
	}
]]

local clutEffect = love.graphics.newPixelEffect(clutEffectSrc)

-- local norms = {}
-- local lengths = {}

-- local function _prepareMetalineEffect( effect, h, width, point1s, point2s, intensities )
-- 	-- PixelEffects flip the y-axis so we need to adjust for that.
-- 	local yFlippedPoint1s = {}

-- 	for index, point1 in ipairs(point1s) do
-- 		local point2 = point2s[index]

-- 		local x1, y1 = point1[1], h - point1[2]
-- 		local x2, y2 = point2[1], h - point2[2]

-- 		local dx = x2 - x1
-- 		local dy = y2 - y1

-- 		local length = math.sqrt((dx * dx) + (dy * dy))
		
-- 		lengths[index] = { length }
-- 		norms[index] = { dx / length, dy / length }

-- 		yFlippedPoint1s[index] = { x1, y1 }

-- 		-- printf('[%d, %d] -> [%d, %d] |%.2f| [%.2f, %.2f]', newx1, newy1, newx2, newy2, length, norms[index][1], norms[index][2])
-- 	end

-- 	effect:send('origins', unpack(yFlippedPoint1s))
-- 	effect:send('norms', unpack(norms))
-- 	effect:send('lengths', unpack(lengths))
-- 	effect:send('intensities', unpack(intensities))
-- 	effect:send('width', width)
-- end

local yFlippedPoint1 = { 0, 0 }
local norm = { 0, 0 }

local function _prepareMetalineEffect( effect, h, width, point1, point2, intensity )
	local x1, y1 = point1[1], h - point1[2]
	local x2, y2 = point2[1], h - point2[2]

	local dx = x2 - x1
	local dy = y2 - y1

	local length = math.sqrt((dx * dx) + (dy * dy))
		
	norm[1], norm[2] = dx / length, dy / length

	yFlippedPoint1[1], yFlippedPoint1[2] = x1, y1

	effect:send('origins', yFlippedPoint1)
	effect:send('norms', norm)
	effect:send('lengths', length)
	effect:send('intensities', intensity)
	effect:send('width', width)
end

metalines = {}

local heightfield = false
local lines = false

function metalines.draw( canvas, xform, w, h, point1s, point2s, intensities, width, clut )
	assert(#point1s == #point2s)
	assert(width > 0)

	-- Viewport values.
	local vpx = -xform.translate[1]
	local vpy = -xform.translate[2]
	local vpsx = 1/xform.scale[1]
	local vpsy = 1/xform.scale[2]
	local vpw = w * 1/xform.scale[1]
	local vph = h * 1/xform.scale[2]

	-- print(vpx, vpy, vpw, vph)

	canvas:clear()
	
	love.graphics.setCanvas(canvas)

	local metalineEffect = metalineEffects[1]

	love.graphics.setPixelEffect(metalineEffect)
	local oldBlendMode = love.graphics.getBlendMode()
	love.graphics.setBlendMode('additive')
	love.graphics.setColor(255, 255, 255)

	local xformed1 = { 0, 0 }
	local xformed2 = { 0, 0 }

	local count = 0

	for i = 1, #point1s do
		local point1, point2 = point1s[i], point2s[i]

		local x = math.min(point1[1], point2[1])
		local y = math.min(point1[2], point2[2])
		local lw = math.max(point1[1], point2[1]) - x
		local lh = math.max(point1[2], point2[2]) - y

		x = x - width
		y = y - width
		lw = lw + (2 * width)
		lh = lh + (2 * width)

		local xoverlap = (vpx < x + lw) and (x < vpx + vpw)
		local yoverlap = (vpy < y + lh) and (y < vpy + vph)

		if xoverlap and yoverlap then
			xformed1[1] = (point1[1] + xform.translate[1]) * xform.scale[1]
			xformed1[2] = (point1[2] + xform.translate[2]) * xform.scale[2]
			
			xformed2[1] = (point2[1] + xform.translate[1]) * xform.scale[1]
			xformed2[2] = (point2[2] + xform.translate[2]) * xform.scale[2]
		
			_prepareMetalineEffect(metalineEffect, h, width * xform.scale[1], xformed1, xformed2, intensities[i])

			love.graphics.rectangle('fill', x, y, lw, lh)

			count = count + 1
		end
	end

	love.graphics.setCanvas()
	
	if not heightfield then
		clutEffect:send('clut', clut)
		love.graphics.setPixelEffect(clutEffect)
	else
		love.graphics.setPixelEffect()
	end

	love.graphics.draw(canvas, vpx, vpy, 0, vpsx, vpsy)

	love.graphics.setPixelEffect()

	if lines then
		for index, point1 in ipairs(point1s) do
			local point2 = point2s[index]
			love.graphics.line(point1[1], point1[2], point2[1], point2[2])
		end
	end

	love.graphics.setBlendMode(oldBlendMode)

	return count
end
