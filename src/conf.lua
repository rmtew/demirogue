function love.conf( t )
	t.title = 'Demirogue'
	t.author = 'naughty'
	t.identity = 'demirogue' -- save game directory name
	t.version = '0.8.0'
	t.console = true
	t.screen.width = 800
    t.screen.height = 600 

    -- t.screen.width = 400
    -- t.screen.height = 300
    -- The voronoi cells look a lot better with AA on.
	t.screen.fsaa = 8
end