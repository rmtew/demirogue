require 'Level'
require 'Actor'

render = {}

function render.level( scale,  )


-- scale
-- track or actor-to-centre-on
-- maxdepth of LoS
--   I should just pass in the LoS dmap
-- player actor
-- level
-- sprite batches
-- - can assume the height, backlight and forelight
-- - others are terrain specific
-- canvas
-- effects
-- - height
-- - cover
-- - fov
--   - textured
--   - untextured
-- drawFlags
-- - drawEdges
-- - drawVertices
-- - drawMetalines (remove metalines I'm not going to use them anymore)
-- - drawMounds
-- - drawHeightfield
-- - drawCover
-- - drawBetweeness
-- - drawOryx
-- linewidth
-- warp (only needed for debug text which could be handled somewhere else)
