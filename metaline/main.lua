require 'expand'
require 'batch'
require 'texture'

print('_VERSION', _VERSION)

-- TODO:
-- 1. Need to be able to offset and scale the rendering.
-- 2. Refactor to make it usuable as a library.
-- WISH:
-- 1. Correct for the valence of the endpoints of the lines.

local w = love.graphics.getWidth()
local h = love.graphics.getHeight()

local point1s, point2s

function testdata()
	-- This is test data from another program I'm writing.
	point1s = {
		{ 100, 100 }, { 100, 100 }, { 100, 100 }, { 100, 150 }, { 100, 150 }, { 100, 150 }, { 100, 150 }, { 100, 200 }, { 100, 200 },
		{ 100, 200 }, { 100, 200 }, { 100, 250 }, { 100, 250 }, { 100, 250 }, { 100, 250 }, { 100, 300 }, { 100, 300 }, { 150, 100 },
		{ 150, 100 }, { 150, 100 }, { 150, 150 }, { 150, 150 }, { 150, 150 }, { 150, 150 }, { 150, 200 }, { 150, 200 }, { 150, 200 },
		{ 150, 200 }, { 150, 250 }, { 150, 250 }, { 150, 250 }, { 150, 250 }, { 150, 300 }, { 150, 300 }, { 200, 100 }, { 200, 100 },
		{ 200, 100 }, { 200, 150 }, { 200, 150 }, { 200, 150 }, { 200, 150 }, { 200, 200 }, { 200, 200 }, { 200, 200 }, { 200, 200 },
		{ 200, 250 }, { 200, 250 }, { 200, 250 }, { 200, 250 }, { 200, 300 }, { 200, 300 }, { 250, 100 }, { 250, 100 }, { 250, 100 },
		{ 250, 150 }, { 250, 150 }, { 250, 150 }, { 250, 150 }, { 250, 200 }, { 250, 200 }, { 250, 200 }, { 250, 200 }, { 250, 250 },
		{ 250, 250 }, { 250, 250 }, { 250, 250 }, { 250, 300 }, { 250, 300 }, { 253, 549 }, { 253, 549 }, { 299, 499 }, { 299, 499 },
		{ 299, 499 }, { 300, 100 }, { 300, 150 }, { 300, 150 }, { 300, 200 }, { 300, 250 }, { 300, 250 }, { 300, 300 }, { 337, 562 },
		{ 337, 562 }, { 348, 428 }, { 348, 428 }, { 385, 508 }, { 385, 508 }, { 385, 508 }, { 402, 437 }, { 402, 437 }, { 402, 565 },
		{ 444, 540 }, { 444, 540 }, { 452, 396 }, { 452, 396 }, { 452, 396 }, { 456, 446 }, { 510, 549 }, { 525, 425 }, { 544, 264 },
		{ 544, 264 }, { 572, 193 }, { 572, 193 }, { 572, 193 }, { 620, 110 }, { 631, 261 }, { 631, 261 }, { 664, 186 },
	}
	point2s = {
	    { 100, 150 }, { 150, 100 }, { 150, 150 }, { 100, 200 }, { 150, 100 }, { 150, 150 }, { 150, 200 }, { 100, 250 }, { 150, 150 },
	    { 150, 200 }, { 150, 250 }, { 100, 300 }, { 150, 200 }, { 150, 250 }, { 150, 300 }, { 150, 250 }, { 150, 300 }, { 150, 150 },
	    { 200, 100 }, { 200, 150 }, { 150, 200 }, { 200, 100 }, { 200, 150 }, { 200, 200 }, { 150, 250 }, { 200, 150 }, { 200, 200 },
	    { 200, 250 }, { 150, 300 }, { 200, 200 }, { 200, 250 }, { 200, 300 }, { 200, 250 }, { 200, 300 }, { 200, 150 }, { 250, 100 },
	    { 250, 150 }, { 200, 200 }, { 250, 100 }, { 250, 150 }, { 250, 200 }, { 200, 250 }, { 250, 150 }, { 250, 200 }, { 250, 250 },
	    { 200, 300 }, { 250, 200 }, { 250, 250 }, { 250, 300 }, { 250, 250 }, { 250, 300 }, { 250, 150 }, { 300, 100 }, { 300, 150 },
	    { 250, 200 }, { 300, 100 }, { 300, 150 }, { 300, 200 }, { 250, 250 }, { 300, 150 }, { 300, 200 }, { 300, 250 }, { 250, 300 },
	    { 300, 200 }, { 300, 250 }, { 300, 300 }, { 300, 250 }, { 300, 300 }, { 299, 499 }, { 337, 562 }, { 337, 562 }, { 348, 428 },
	    { 385, 508 }, { 300, 150 }, { 300, 200 }, { 572, 193 }, { 300, 250 }, { 300, 300 }, { 544, 264 }, { 348, 428 }, { 385, 508 },
	    { 402, 565 }, { 385, 508 }, { 402, 437 }, { 402, 437 }, { 402, 565 }, { 444, 540 }, { 452, 396 }, { 456, 446 }, { 444, 540 },
	    { 456, 446 }, { 510, 549 }, { 456, 446 }, { 525, 425 }, { 544, 264 }, { 525, 425 }, { 525, 425 }, { 544, 264 }, { 572, 193 },
	    { 631, 261 }, { 620, 110 }, { 631, 261 }, { 664, 186 }, { 664, 186 }, { 664, 186 }, { 718, 253 }, { 718, 253 },
	}
end

testdata()


local function _clamp( x, min, max )
	if x < min then
		return min
	elseif x > max then
		return max
	end

	return x
end

local function printf( ... )
	print(string.format(...))
end

local function _peturb( x )
	local xmax = w
	local ymax = h

	for index, point1 in ipairs(point1s) do
		local point2 = point2s[index]

		local x1, y1 = point1[1], point1[2]
		local x2, y2 = point2[1], point2[2]

		local newx1 = _clamp(x1 + math.random(-x, x), 0, xmax)
		local newy1 = _clamp(y1 + math.random(-x, x), 0, ymax)
		local newx2 = _clamp(x2 + math.random(-x, x), 0, xmax)
		local newy2 = _clamp(y2 + math.random(-x, x), 0, ymax)

		point1[1], point1[2] = newx1, newy1
		point2[1], point2[2] = newx2, newy2
	end
end

local norms = {}
local lengths = {}

local function _metalines( effect, width, point1s, point2s )
	for index, point1 in ipairs(point1s) do
		local point2 = point2s[index]

		local x1, y1 = point1[1], point1[2]
		local x2, y2 = point2[1], point2[2]

		local dx = x2 - x1
		local dy = y2 - y1

		local length = math.sqrt((dx * dx) + (dy * dy))
		
		lengths[index] = { length }
		norms[index] = { dx / length, dy / length }

		-- printf('[%d, %d] -> [%d, %d] |%.2f| [%.2f, %.2f]', newx1, newy1, newx2, newy2, length, norms[index][1], norms[index][2])
	end

	effect:send('origins', unpack(point1s))
	effect:send('norms', unpack(norms))
	effect:send('lengths', unpack(lengths))
	effect:send('width', width)
end

local MIN_METALINES, MAX_METALINES = 4, 16

function love.load()
	assert(love.graphics.isSupported('pixeleffect'), 'Pixel effects are not supported on your hardware. Sorry about that.')

	local metalinesrc = [[
		// first point of the metaline segment
		extern vec2 origins[$(NUMLINES)];
		// the direction of the metaline
		extern vec2 norms[$(NUMLINES)];
		extern float lengths[$(NUMLINES)];
		// the maximum distance away from the metaline that we can set.
		extern float width;

		float metaline(vec2 pc, vec2 lorigin, vec2 lnorm, float llength)
		{
			vec2 disp = pc - lorigin;
			float lambda = dot(disp, lnorm);
			lambda = clamp(lambda, 0, llength);

			vec2 proj = lorigin + (lnorm * lambda);
			vec2 dispnear = pc - proj;
			float d = length(dispnear);           // distance from the line
			float invd = width - d;               // inverse distance
			float invdc = step(0, invd) * invd;   // inverse distance clamped >= 0
			float invdcn = invdc / width;         // inverse distance clamped and normalised to [0..1]

			// n^3 seems to look the best
			return invdcn * invdcn * invdcn;
		}

		vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
		{
			float p = 0.0;
			
			#(for i = 0, NUMLINES-1 do)
                p += metaline(pc, origins[$(i)], norms[$(i)], lengths[$(i)]);
            #(end)

			return vec4(p, p, p, 1);
		}
	]]

	metalinefx = {}

	for i = MIN_METALINES, MAX_METALINES do
		local expanded = expand(metalinesrc, { NUMLINES = i})
		metalinefx[i] = love.graphics.newPixelEffect(expanded)
	end

	local colourisesrc = [[
		extern Image clut;

		vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
		{
			float p = Texel(tex, tc).x;

			return Texel(clut, vec2(0, p));
		}
	]]

	colourisefx = love.graphics.newPixelEffect(colourisesrc)

	canvas = love.graphics.newCanvas()

	local clutgens = {
		unionjack = 
			function ()
				local red = { 0.8 * 255, 0, 0, 255 }
				local white = { 255, 255, 255, 255 }
				local blue = { 0, 0.2 * 255, 0.6 * 255, 255 }

				local blur = 5
				local b1 = 10
				local b2 = 25

				local bands = {
					[1] = blue,
					[b1 - blur] = blue,
					[b1 + blur] = white,
					[b2 - blur] = white,
					[b2 + blur] = red,
					[100] = red,
				}

				return texture.clut(bands, 256, 256)
			end,
		pastelscrub =
			function ()
				-- No official colour names.
				local lilac = { 132, 83, 255, 255 }
				local verdant = { 22, 178, 39, 255 }
				local drygrass = { 57, 255, 79, 255 }
				local clay = { 204, 114, 25, 255 }
				local sandysoil = { 178, 104, 31, 255 }

				local blur = 5
				local b1 = 10
				local b2 = 25
				local b3 = 45
				local b4 = 65

				local bands = {
					[1] = lilac,
					[b1-blur] = lilac,
					[b1+blur] = verdant,
					[b2-blur] = verdant,
					[b2+blur] = drygrass,
					[b3-blur] = drygrass,
					[b3+blur] = clay,
					[b4-blur] = clay,
					[b4+blur] = sandysoil,
					[100] = sandysoil,
				}

				return texture.clut(bands, 256, 256)
			end,
		rubarb =
			function ()
				-- No official colour names.
				local colour1 = { 255, 72, 73, 255 }
				local colour2 = { 178, 16, 35, 255 }
				local colour3 = { 255, 47, 71, 255 }
				local colour4 = { 0, 178, 35, 255 }
				local colour5 = { 47, 255, 92, 255 }

				local blur = 5
				local b1 = 10
				local b2 = 25
				local b3 = 45
				local b4 = 65

				local bands = {
					[1] = colour1,
					[b1-blur] = colour1,
					[b1+blur] = colour2,
					[b2-blur] = colour2,
					[b2+blur] = colour3,
					[b3-blur] = colour3,
					[b3+blur] = colour4,
					[b4-blur] = colour4,
					[b4+blur] = colour5,
					[100] = colour5,
				}

				return texture.clut(bands, 256, 256)
			end,
		strobe =
			function ()
				-- No official colour names.
				local white = { 255, 255, 255, 255 }
				local black = { 0, 0, 0, 255 }

				local bands = {}

				for i = 10, 90, 10 do
					bands[i-1] = black
					bands[i+1] = white
				end

				bands[1] = black
				bands[100] = white

				return texture.clut(bands, 256, 256)
			end,
		sine =
			function ()
				local bands = {}

				for i = 0, 99 do
					local theta = i * (99 / (math.pi * 2))
					local r = 255 * (0.5 * (math.sin(theta)+1))
					local g = 255 * (0.5 * (math.cos(theta)+1))
					local b = 255 * (0.5 * (-math.sin(theta)+1))
					local a = 255

					print(i+1, r, g, b, a)
					
					bands[i+1] = { r, g, b, a }
				end

				return texture.clut(bands, 256, 256)
			end,
		border =
			function ()
				local white = { 255, 255, 255, 255 }
				local black = { 0, 0, 0, 255 }
				
				local bands = {
					[1] = black,
					[2] = white,
					[3] = white,
					[4] = black,
					[97] = black,
					[98] = white,
					[99] = white,
					[100] = black,
				}

				return texture.clut(bands, 256, 256)
			end,
	}

	cluts = {}

	for name, gen in pairs(clutgens) do
		cluts[name] = gen()
	end
end

local updated = false
local width = 0
local heighfield = false
local timer = true
local boundingboxes = false
local batcher = 'simple'
local clutkey = 'unionjack'
local numlines = MIN_METALINES

local handlers = {
	p = {
		func =
			function ()
				_peturb(20)
			end,
		desc = 'peturb the lines',
	},
	r = {
		func = 
			function ()
				for index = 1, #point1s do
					local point1 = point1s[index]
					local point2 = { 0, 0 }
					point2s[index] = point2

					point1[1], point1[2] = math.random(0, w), math.random(0, h)
					point2[1], point2[2] = math.random(0, w), math.random(0, h)
				end
			end,
		desc = 'randomly assign the lines',
	},
	s = {
		func = 
			function ()
				timer = not timer
			end,
		desc = 'start/stop the animation',
	},
	h =  {
		func = 
			function ()
				heightfield = not heightfield
			end,
		desc = 'toggle heightfield rendering'
	},
	b =  {
		func = 
			function ()
				boundingboxes = not boundingboxes
			end,
		desc = 'toggle bounding box rendering'
	},
	i =  {
		func = 
			function ()
				batcher = next(batch, batcher) or next(batch)
			end,
		desc = 'cycle simple/BIH/minarea batching'
	},
	c =  {
		func = 
			function ()
				clutkey = next(cluts, clutkey) or next(cluts)
			end,
		desc = 'cycle simple/BIH/minarea batching'
	},
	t =  {
		func = 
			function ()
				testdata()
			end,
		desc = 'restore testdata'
	},
	up = { func = function () end, desc = 'alter metaline width'},
	down = { func = function () end, desc = 'alter metaline width'},
	left = { func =
		function ()
			numlines = math.max(MIN_METALINES, numlines - 1)
		end,
		desc = 'decrease numlines'
	},
	right = { func =
		function ()
			numlines = math.min(MAX_METALINES, numlines + 1)
		end,
		desc = 'increase numlines'
	},
	escape =  {
		func = 
			function ()
				love.event.push('quit')
			end,
		desc = 'quit'
	},
}

function shadowedtextf( x, y, ... )
	local text = string.format(...)

	love.graphics.setBlendMode('alpha')

	love.graphics.setColor(0, 0, 0, 255)

	love.graphics.print(text, x-1, y-1)
	love.graphics.print(text, x-1, y+1)
	love.graphics.print(text, x+1, y-1)
	love.graphics.print(text, x+1, y+1)

	love.graphics.setColor(255, 255, 255, 255)

	love.graphics.print(text, x, y)
end


function love.draw()
	if not updated then
		return
	end
	
	canvas:clear()
	love.graphics.setCanvas(canvas)

	local effect = metalinefx[numlines]

	love.graphics.setPixelEffect(effect)

	love.graphics.setBlendMode('additive')

	local batched = batch[batcher](w, h, point1s, point2s, numlines, width)

	for _, batch in pairs(batched.batches) do
		_metalines(effect, width, batch.point1s, batch.point2s)

		local aabb = batch.aabb

		love.graphics.rectangle('fill', aabb[1], aabb[2], aabb[3], aabb[4])
	end

	love.graphics.setCanvas()
	
	if not heightfield then
		colourisefx:send('clut', cluts[clutkey])
		love.graphics.setPixelEffect(colourisefx)
	else
		love.graphics.setPixelEffect()
	end

	love.graphics.draw(canvas, 0,0)

	love.graphics.setPixelEffect()

	for index, point1 in ipairs(point1s) do
		local point2 = point2s[index]
		love.graphics.line(point1[1], h - point1[2], point2[1], h - point2[2])
	end

	if boundingboxes then
		for _, batch in pairs(batched.batches) do
			local aabb = batch.aabb
			love.graphics.rectangle('line', aabb[1], aabb[2], aabb[3], aabb[4])
		end
	end 

	-- love.graphics.draw(clut, 100, 100)
	
	local overdraw = 100 * (batched.pixels / (w * h))
	local batchtxt = batcher

	shadowedtextf(10, 10, 'fps:%.2f #metalines:%d width:%.2f pixels:%d overdraw:%.2f%% oobs:%d batch:%s #batches:%d',
		love.timer.getFPS(),
		numlines,
		width,
		batched.pixels,
		overdraw,
		batched.oobs,
		batchtxt,
		#batched.batches)

	local yoffset = 25
	for key, data in pairs(handlers) do
		shadowedtextf(10, yoffset, '%s : %s', key, data.desc)
		yoffset = yoffset + 15
	end

	shadowedtextf(10, yoffset + 15, 'colourscheme: %s', clutkey)
end

t = 0
function love.update(dt)
	if timer then
		t = t + love.timer.getDelta();
	end

	if love.keyboard.isDown('up') then
		t = t + (math.pi / 180)
	elseif love.keyboard.isDown('down') then
		t = t - (math.pi / 180)
	end

	width = 5 + (100 * (0.5 * (math.sin(t) + 1)))

	updated = true
end

function love.keypressed( key )
	local data = handlers[key]

	if data then
		data.func()
	end
end
