function love.conf( t )
	t.title = 'Demirogue'
	t.author = 'naughty'
	-- t.url = nil
	t.identity = 'demirogue' -- save game directory name
	t.version = '0.9.0'      -- love version
	
	t.console = true
	-- t.release = false

	t.screen.width = 800
    t.screen.height = 600 
    -- t.screen.fullscreen = false
    -- t.screen.vsync = true
    -- The voronoi cells look a lot better with AA on.
	t.screen.fsaa = 0 -- 8
    
    -- t.modules.joystick = true
    -- t.modules.audio = true
    -- t.modules.keyboard = true
    -- t.modules.event = true
    -- t.modules.image = true
    -- t.modules.graphics = true
    -- t.modules.timer = true
    -- t.modules.mouse = true
    -- t.modules.sound = true
    -- t.modules.physics = true
end