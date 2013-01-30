--[[

voronoi.lua

Based on Raymon Hill's excellent Javascript implementation.

Author: Raymond Hill (rhill@raymondhill.net)
Contributor: Jesse Morgan (morgajel@gmail.com)
File: rhill-voronoi-core.js
Version: 0.98
Date: January 21, 2013
Description: This is my personal Javascript implementation of
Steven Fortune's algorithm to compute Voronoi diagrams.

Copyright (C) 2010,2011 Raymond Hill
https://github.com/gorhill/Javascript-Voronoi

Licensed under The MIT License
http://en.wikipedia.org/wiki/MIT_License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*****

Portions of this software use, depend, or was inspired by the work of:

  "Fortune's algorithm" by Steven J. Fortune: For his clever
  algorithm to compute Voronoi diagrams.
  http://ect.bell-labs.com/who/sjf/

  "The Liang-Barsky line clipping algorithm in a nutshell!" by Daniel White,
  to efficiently clip a line within a rectangle.
  http://www.skytopia.com/project/articles/compsci/clipping.html

  "rbtree" by Franck Bui-Huu
  https://github.com/fbuihuu/libtree/blob/master/rb.c
  I ported to Javascript the C code of a Red-Black tree implementation by
  Franck Bui-Huu, and further altered the code for Javascript efficiency
  and to very specifically fit the purpose of holding the beachline (the key
  is a variable range rather than an unmutable data point), and unused
  code paths have been removed. Each node in the tree is actually a beach
  section on the beachline. Using a tree structure for the beachline remove
  the need to lookup the beach section in the array at removal time, as
  now a circle event can safely hold a reference to its associated
  beach section (thus findDeletionPoint() is no longer needed). This
  finally take care of nagging finite arithmetic precision issues arising
  at lookup time, such that epsilon could be brought down to 1e-9 (from 1e-4).
  rhill 2011-05-27: added a 'previous' and 'next' members which keeps track
  of previous and next nodes, and remove the need for Beachsection.getPrevious()
  and Beachsection.getNext().

*****

History:

0.98 (25 Jan 2013):
  Added Cell.getBbox() and Cell.pointIntersection() for convenience when using
  an external treemap.

0.97 (21 Jan 2013):
  Merged contribution by Jesse Morgan (https://github.com/morgajel):
  Cell.getNeighbourIds()
  https://github.com/gorhill/Javascript-Voronoi/commit/4c50f691a301cd6a286359fefba1fab30c8e3b89

0.96 (26 May 2011):
  Returned diagram.cells is now an array, whereas the index of a cell
  matches the index of its associated site in the array of sites passed
  to Voronoi.compute(). This allowed some gain in performance. The
  'voronoiId' member is still used internally by the Voronoi object.
  The Voronoi.Cells object is no longer necessary and has been removed.

0.95 (19 May 2011):
  No longer using Javascript array to keep track of the beach sections of
  the beachline, now using Red-Black tree.

  The move to a binary tree was unavoidable, as I ran into finite precision
  arithmetic problems when I started to use sites with fractional values.
  The problem arose when the code had to find the arc associated with a
  triggered Fortune circle event: the collapsing arc was not always properly
  found due to finite precision arithmetic-related errors. Using a tree structure
  eliminate the need to look-up a beachsection in the array structure
  (findDeletionPoint()), and allowed to bring back epsilon down to 1e-9.

0.91(21 September 2010):
  Lower epsilon from 1e-5 to 1e-4, to fix problem reported at
  http://www.raymondhill.net/blog/?p=9#comment-1414

0.90 (21 September 2010):
  First version.

*****

Usage:

  var sites = [{x:300,y:300}, {x:100,y:100}, {x:200,y:500}, {x:250,y:450}, {x:600,y:150}];
  // xl, xr means x left, x right
  // yt, yb means y top, y bottom
  var bbox = {xl:0, xr:800, yt:0, yb:600};
  var voronoi = new Voronoi();
  // pass an object which exhibits xl, xr, yt, yb properties. The bounding
  // box will be used to connect unbound edges, and to close open cells
  result = voronoi.compute(sites, bbox);
  // render, further analyze, etc.

Return value:
  An object with the following properties:

  result.edges = an array of unordered, unique Voronoi.Edge objects making up the Voronoi diagram.
  result.cells = an array of Voronoi.Cell object making up the Voronoi diagram. A Cell object
    might have an empty array of halfedges, meaning no Voronoi cell could be computed for a
    particular cell.
  result.execTime = the time it took to compute the Voronoi diagram, in milliseconds.

Voronoi.Edge object:
  lSite: the Voronoi site object at the left of this Voronoi.Edge object.
  rSite: the Voronoi site object at the right of this Voronoi.Edge object (can be null).
  va: an object with an 'x' and a 'y' property defining the start point
    (relative to the Voronoi site on the left) of this Voronoi.Edge object.
  vb: an object with an 'x' and a 'y' property defining the end point
    (relative to Voronoi site on the left) of this Voronoi.Edge object.

  For edges which are used to close open cells (using the supplied bounding box), the
  rSite property will be null.

Voronoi.Cell object:
  site: the Voronoi site object associated with the Voronoi cell.
  halfedges: an array of Voronoi.Halfedge objects, ordered counterclockwise, defining the
    polygon for this Voronoi cell.

Voronoi.Halfedge object:
  site: the Voronoi site object owning this Voronoi.Halfedge object.
  edge: a reference to the unique Voronoi.Edge object underlying this Voronoi.Halfedge object.
  getStartpoint(): a method returning an object with an 'x' and a 'y' property for
    the start point of this halfedge. Keep in mind halfedges are always countercockwise.
  getEndpoint(): a method returning an object with an 'x' and a 'y' property for
    the end point of this halfedge. Keep in mind halfedges are always countercockwise.

TODO: Identify opportunities for performance improvement.
TODO: Let the user close the Voronoi cells, do not do it automatically. Not only let
      him close the cells, but also allow him to close more than once using a different
      bounding box for the same Voronoi diagram.
--]]

-- global Math

Voronoi = {
	RBTree = {},
	Cell = {},
	Halfedge = {},
}

function Voronoi:new()
	local result = {
		edges = nil,
		cells = nil,
		beachsectionJunkyard = {},
		circleEventJunkyard = {},
		beachline = nil,
		circleEvents = nil,
		firstCircleEvent = nil,
	}

	setmetatable(result, self)
	self.__index = self

	return result
end

function Voronoi:reset() {
	if not self.beachline then
		self.beachline = RBTree:new()
	end
	-- Move leftover beachsections to the beachsection junkyard.
	if self.beachline.root then
		local beachsection = self.beachline:getFirst(self.beachline.root)
		while beachsection do
			self.beachsectionJunkyard:push(beachsection); -- mark for reuse
			beachsection = beachsection.rbNext;
		end
	end
	self.beachline.root = nil
	
	if not self.circleEvents then
		self.circleEvents = RBTree:new()
	end

	self.circleEvents.root, self.firstCircleEvent = nil, nil
	self.edges = {}
	self.cells = {}
end


local sqrt = math.sqrt
local abs = math.abs
local EPSILON = 1e-9
local function equalWithEpsilon( a, b )
	return abs(a-b) < EPSILON
end
local function greaterThanWithEpsilon( a, b )
	return a-b > EPSILON
end
local function greaterThanOrEqualWithEpsilon( a, b )
	return b-a < EPSILON
end
local function lessThanWithEpsilon( a, b )
	return b-a > EPSILON
end
local function lessThanOrEqualWithEpsilon( a, b )
	return a-b < EPSILON
end


-- ---------------------------------------------------------------------------
-- Red-Black tree code (based on C version of "rbtree" by Franck Bui-Huu
-- https://github.com/fbuihuu/libtree/blob/master/rb.c

function Voronoi.RBTree:new()
	local result = {
		root = nil
	}

	setmetatable(self, result)
	self.__index = self

	return result
end

function Voronoi.RBTree:rbInsertSuccessor( node, successor )
	local parent

	if node then
		-- >>> rhill 2011-05-27: Performance: cache previous/next nodes
		successor.rbPrevious = node
		successor.rbNext = node.rbNext
		if node.rbNext then
			node.rbNext.rbPrevious = successor
		end
		node.rbNext = successor
		-- <<<
		if node.rbRight then
			-- in-place expansion of node.rbRight.getFirst();
			node = node.rbRight
			while node.rbLeft do
				node = node.rbLeft
			end
			node.rbLeft = successor
		else
			node.rbRight = successor
		end
		parent = node
	-- rhill 2011-06-07: if node is null, successor must be inserted
	-- to the left-most part of the tree
	elseif this.root then
		node = self:getFirst(self.root)
		-- >>> Performance: cache previous/next nodes
		successor.rbPrevious = nil
		successor.rbNext = node
		node.rbPrevious = successor
		-- <<<
		node.rbLeft = successor
		parent = node
	else
		-- >>> Performance: cache previous/next nodes
		successor.rbPrevious = successor.rbNext = nil
		-- <<<
		this.root = successor
		parent = nil
	end
	successor.rbLeft, successor.rbRight = nil, nil
	successor.rbParent = parent
	successor.rbRed = true
	-- Fixup the modified tree by recoloring nodes and performing
	-- rotations (2 at most) hence the red-black tree properties are
	-- preserved.
	local grandpa, uncle
	node = successor
	while parent and parent.rbRed do
		grandpa = parent.rbParent
		if parent == grandpa.rbLeft then
			uncle = grandpa.rbRight
			if uncle and uncle.rbRed then
				parent.rbRed, uncle.rbRed = false, false
				grandpa.rbRed = true
				node = grandpa
			else
				if node == parent.rbRight then
					self:rbRotateLeft(parent)
					node = parent
					parent = node.rbParent
				end
				parent.rbRed = false
				grandpa.rbRed = true
				self:rbRotateRight(grandpa)
			end
		else
			uncle = grandpa.rbLeft
			if uncle and uncle.rbRed then
				parent.rbRed, uncle.rbRed = false, false
				grandpa.rbRed = true
				node = grandpa
			else
				if node == parent.rbLeft then
					self:rbRotateRight(parent)
					node = parent
					parent = node.rbParent
				end
				parent.rbRed = false
				grandpa.rbRed = true
				self:rbRotateLeft(grandpa)
			end
		end
		parent = node.rbParent
	end
	
	self.root.rbRed = false
end


function Voronoi.RBTree:rbRemoveNode( node )
	-- >>> rhill 2011-05-27: Performance: cache previous/next nodes
	if node.rbNext then
		node.rbNext.rbPrevious = node.rbPrevious
	end
	if node.rbPrevious then
		node.rbPrevious.rbNext = node.rbNext
	end
	node.rbNext, node.rbPrevious = nil, nil
	-- <<<
	local parent = node.rbParent
	local left = node.rbLeft
	local right = node.rbRight
	local nextn -- [DCS] next -> nextn because next() is a built-in function.
	if not left then
		nextn = right
	else if not right then
		nextn = left
	else
		nextn = self:getFirst(right)
	end
	if parent then
		if parent.rbLeft == node then
			parent.rbLeft = nextn
		else
			parent.rbRight = nextn
		end
	else
		this.root = nextn
	end
	-- enforce red-black rules
	local isRed
	if left and right then
		isRed = nextn.rbRed
		nextn.rbRed = node.rbRed
		nextn.rbLeft = left
		left.rbParent = nextn
		if nextn ~= right then
			parent = nextn.rbParent
			nextn.rbParent = node.rbParent
			node = nextn.rbRight
			parent.rbLeft = node
			nextn.rbRight = right
			right.rbParent = nextn
		else
			nextn.rbParent = parent
			parent = nextn
			node = nextn.rbRight
		end
	else
		isRed = node.rbRed
		node = nextn
	end
	-- 'node' is now the sole successor's child and 'parent' its
	-- new parent (since the successor can have been moved)
	if node then
		node.rbParent = parent
	end
	-- the 'easy' cases
	if isRed then
		return
	end
	if node and node.rbRed then
		node.rbRed = false
		return
	end
	-- the other cases
	local sibling
	repeat
		if node == self.root then
			break
		end
		if node == parent.rbLeft then
			sibling = parent.rbRight
			if sibling.rbRed then
				sibling.rbRed = false
				parent.rbRed = true
				self:rbRotateLeft(parent)
				sibling = parent.rbRight
			end
			if (sibling.rbLeft and sibling.rbLeft.rbRed) or (sibling.rbRight and sibling.rbRight.rbRed) then
				if not sibling.rbRight or not sibling.rbRight.rbRed then
					sibling.rbLeft.rbRed = false
					sibling.rbRed = true
					selfrbRotateRight(sibling)
					sibling = parent.rbRight
				end
				sibling.rbRed = parent.rbRed
				parent.rbRed, sibling.rbRight.rbRed = false, false
				self:rbRotateLeft(parent)
				node = self.root
				break
			end
		else
			sibling = parent.rbLeft
			if sibling.rbRed then
				sibling.rbRed = false
				parent.rbRed = true
				self:rbRotateRight(parent)
				sibling = parent.rbLeft
			end
			if (sibling.rbLeft and sibling.rbLeft.rbRed) or (sibling.rbRight and sibling.rbRight.rbRed) then
				if not sibling.rbLeft or not sibling.rbLeft.rbRed then
					sibling.rbRight.rbRed = false
					sibling.rbRed = true
					self:rbRotateLeft(sibling)
					sibling = parent.rbLeft
				end
				sibling.rbRed = parent.rbRed
				parent.rbRed, sibling.rbLeft.rbRed = false, false
				self:rbRotateRight(parent)
				node = this.root
				break
			end
		end
		sibling.rbRed = true
		node = parent
		parent = parent.rbParent
	until not node.rbRed
	
	if node then
		node.rbRed = false
	end
end

function Voronoi.RBTree:rbRotateLeft( node )
	local p = node
	local q = node.rbRight -- can't be nil
	local parent = p.rbParent
	if parent then
		if parent.rbLeft == p then
			parent.rbLeft = q
		else
			parent.rbRight = q
		end
	else
		self.root = q
	end
	q.rbParent = parent
	p.rbParent = q
	p.rbRight = q.rbLeft
	if p.rbRight then
		p.rbRight.rbParent = p
	end
	q.rbLeft = p
end

function Voronoi.RBTree:rbRotateRight( node )
	local p = node
	local q = node.rbLeft -- can't be nil
	local parent = p.rbParent
	if parent then
		if parent.rbLeft == p then
			parent.rbLeft = q
		else
			parent.rbRight = q
		end
	else
		self.root = q
	end
	q.rbParent = parent
	p.rbParent = q
	p.rbLeft = q.rbRight
	if p.rbLeft then
		p.rbLeft.rbParent = p
	then
	q.rbRight = p
end

function Voronoi.RBTree:getFirst( node )
	while node.rbLeft do
		node = node.rbLeft
	end
	return node
end

function Voronoi.RBTree:getLast( node )
	while node.rbRight do
		node = node.rbRight
	end
	return node
end

-- [DCS] Voronoi.Diagram is just a POD so I've removed it.

-- ---------------------------------------------------------------------------
-- Cell methods

function Voronoi.Cell:new( site )
	local result = {
		site = site,
		halfedges = {},
	}

	setmetatable(result, self)
	self.__index = self

	return result
end

function Voronoi.Cell:prepare()
	local halfedges = self.halfedges
	local numHalfedges = #halfedges
	-- get rid of unused halfedges
	-- rhill 2011-05-27: Keep it simple, no point here in trying
	-- to be fancy: dangling edges are a typically a minority.
	for index = numHalfedges, 1, -1 do
		local edge = halfedges[index].edge
		if not edge.vb or not edge.va then
			table.remove(halfedges, index)
		end
	end
	-- rhill 2011-05-26: I tried to use a binary search at insertion
	-- time to keep the array sorted on-the-fly (in Cell.addHalfedge()).
	-- There was no real benefits in doing so, performance on
	-- Firefox 3.6 was improved marginally, while performance on
	-- Opera 11 was penalized marginally.
	table.sort(halfedges, function( a, b ) return b.angle < a.angle end)
	return #halfedges.length
end


-- Return a list of the neighbor Ids
function Voronoi.Cell:getNeighborIds()
	local neighbors = {}
	local halfedges = self.halfedges
	for index = 1, #halfedges do
		local edge = halfedges[index].edge
		if edge.lSite ~= nil and edge.lSite.voronoiId ~= self.site.voronoiId then
			neighbors[#neighbors+1] = edge.lSite.voronoiId
		elseif edge.rSite ~= nil and edge.rSite.voronoiId ~= self.site.voronoiId then
			neighbors[#neighbors+1] = edge.rSite.voronoiId
		end
	end

	return neighbors
end


-- Compute bounding box
--
function Voronoi.Cell:getBbox()
	local halfedges = self.halfedges
	local xmin = math.huge,
	local ymin = math.huge,
	local xmax = -math.huge,
	local ymax = -math.huge;
	for index = 1, #halfedges do
		local v = halfedges[index]:getStartpoint()
		local vx = v.x
		local vy = v.y
		if vx < xmin then xmin = vx end
		if vy < ymin then ymin = vy end
		if vx > xmax then xmax = vx end
		if vy > ymax then ymax = vy end
		-- we dont need to take into account end point,
		-- since each end point matches a start point
	end
	return {
		x = xmin,
		y = ymin,
		width = xmax-xmin,
		height = ymax-ymin,
	}
end

-- Return whether a point is inside, on, or outside the cell:
--   -1: point is outside the perimeter of the cell
--    0: point is on the perimeter of the cell
--    1: point is inside the perimeter of the cell
--
function Voronoi.Cell:pointIntersection( x, y )
	-- Check if point in polygon. Since all polygons of a Voronoi
	-- diagram are convex, then:
	-- http://paulbourke.net/geometry/polygonmesh/
	-- Solution 3 (2D):
	--   "If the polygon is convex then one can consider the polygon
	--   "as a 'path' from the first vertex. A point is on the interior
	--   "of this polygons if it is always on the same side of all the
	--   "line segments making up the path. ...
	--   "(y - y0) (x1 - x0) - (x - x0) (y1 - y0)
	--   "if it is less than 0 then P is to the right of the line segment,
	--   "if greater than 0 it is to the left, if equal to 0 then it lies
	--   "on the line segment"
	local halfedges = self.halfedges
	for index = 1, #halfedges do
		local halfedge = halfedges[index]
		local p0 = halfedge:getStartpoint()
		local p1 = halfedge:getEndpoint()
		local r = (y-p0.y)*(p1.x-p0.x)-(x-p0.x)*(p1.y-p0.y)
		if r == 0 then
			return 0
		end
		if r > 0 then
			return -1
		end
	end
	return 1
end

-- ---------------------------------------------------------------------------
-- Edge methods
--

-- [DCS] Both Vertex and Edge are PoD but I've kept them to make porting the
--       rest of the code more straightforward.

local function Vertex( x, y )
	return {
		x = x,
		y = y,
	}
end

local function Edge( lSite, rSite )
	return {
		lSite = lSite,
		rSite = rSite,
		va = nil,
		vb = nil,
	}
end


function Voronoi.Halfedge:new( edge, lSite, rSite )
	local result = {
		site = lSite,
		edge = edge,
		angle = nil,
	}

	-- 'angle' is a value to be used for properly sorting the
	-- halfsegments counterclockwise. By convention, we will
	-- use the angle of the line defined by the 'site to the left'
	-- to the 'site to the right'.
	-- However, border edges have no 'site to the right': thus we
	-- use the angle of line perpendicular to the halfsegment (the
	-- edge should have both end points defined in such case.)
	if rSite then
		result.angle = math.atan2(rSite.y-lSite.y, rSite.x-lSite.x)
	else
		local va = edge.va
		local vb = edge.vb
		-- rhill 2011-05-31: used to call getStartpoint()/getEndpoint(),
		-- but for performance purpose, these are expanded in place here.
		if edge.lSite == lSite then
			result.angle = math.atan2(vb.x-va.x, va.y-vb.y)
		else
			result.angle = math.atan2(va.x-vb.x, vb.y-va.y)
		end
	end

	setmetatable(result, self)
	self.__index = self
end

function Voronoi.Halfedge:getStartpoint()
	return self.edge.lSite == self.site and self.edge.va or this.edge.vb
end

function Voronoi.Halfedge:getEndpoint()
	return self.edge.lSite == self.site and self.edge.vb or this.edge.va
end

-- this create and add an edge to internal collection, and also create
-- two halfedges which are added to each site's counterclockwise array
-- of halfedges.
function Voronoi:createEdge( lSite, rSite, va, vb )
	local edge = Edge(lSite, rSite)
	local edges = self.edges
	edges[#edges+1] = edge
	if va then
		self:setEdgeStartpoint(edge, lSite, rSite, va)
	end
	if vb then
		self:setEdgeEndpoint(edge, lSite, rSite, vb)
	end

	local cells = self.cells
	local lhalfedges = cells[lSite.voronoiId].halfedges
	local rhalfedges = cells[rSite.voronoiId].halfedges

	lhalfedges[#lhalfedges+1] = Halfedge:new(edge, lSite, rSite)
	rhalfedges[#rhalfedges+1] = Halfedge:new(edge, rSite, lSite)

	return edge
end

function Voronoi:createBorderEdge( lSite, va, vb )
	local edge = Edge(lSite, null)
	edge.va = va
	edge.vb = vb
	local edges = self.edges
	edges[#edges+1] = edge
	return edge
end
-- DONE

-- TODO

Voronoi.prototype.setEdgeStartpoint = function(edge, lSite, rSite, vertex) {
	if (!edge.va && !edge.vb) {
		edge.va = vertex;
		edge.lSite = lSite;
		edge.rSite = rSite;
		}
	else if (edge.lSite === rSite) {
		edge.vb = vertex;
		}
	else {
		edge.va = vertex;
		}
	};

Voronoi.prototype.setEdgeEndpoint = function(edge, lSite, rSite, vertex) {
	this.setEdgeStartpoint(edge, rSite, lSite, vertex);
	};

// ---------------------------------------------------------------------------
// Beachline methods

// rhill 2011-06-07: For some reasons, performance suffers significantly
// when instanciating a literal object instead of an empty ctor
Voronoi.prototype.Beachsection = function() {
	};

// rhill 2011-06-02: A lot of Beachsection instanciations
// occur during the computation of the Voronoi diagram,
// somewhere between the number of sites and twice the
// number of sites, while the number of Beachsections on the
// beachline at any given time is comparatively low. For this
// reason, we reuse already created Beachsections, in order
// to avoid new memory allocation. This resulted in a measurable
// performance gain.
Voronoi.prototype.createBeachsection = function(site) {
	var beachsection = this.beachsectionJunkyard.pop();
	if (!beachsection) {
		beachsection = new this.Beachsection();
		}
	beachsection.site = site;
	return beachsection;
	};

// calculate the left break point of a particular beach section,
// given a particular sweep line
Voronoi.prototype.leftBreakPoint = function(arc, directrix) {
	// http://en.wikipedia.org/wiki/Parabola
	// http://en.wikipedia.org/wiki/Quadratic_equation
	// h1 = x1,
	// k1 = (y1+directrix)/2,
	// h2 = x2,
	// k2 = (y2+directrix)/2,
	// p1 = k1-directrix,
	// a1 = 1/(4*p1),
	// b1 = -h1/(2*p1),
	// c1 = h1*h1/(4*p1)+k1,
	// p2 = k2-directrix,
	// a2 = 1/(4*p2),
	// b2 = -h2/(2*p2),
	// c2 = h2*h2/(4*p2)+k2,
	// x = (-(b2-b1) + Math.sqrt((b2-b1)*(b2-b1) - 4*(a2-a1)*(c2-c1))) / (2*(a2-a1))
	// When x1 become the x-origin:
	// h1 = 0,
	// k1 = (y1+directrix)/2,
	// h2 = x2-x1,
	// k2 = (y2+directrix)/2,
	// p1 = k1-directrix,
	// a1 = 1/(4*p1),
	// b1 = 0,
	// c1 = k1,
	// p2 = k2-directrix,
	// a2 = 1/(4*p2),
	// b2 = -h2/(2*p2),
	// c2 = h2*h2/(4*p2)+k2,
	// x = (-b2 + Math.sqrt(b2*b2 - 4*(a2-a1)*(c2-k1))) / (2*(a2-a1)) + x1

	// change code below at your own risk: care has been taken to
	// reduce errors due to computers' finite arithmetic precision.
	// Maybe can still be improved, will see if any more of this
	// kind of errors pop up again.
	var site = arc.site,
		rfocx = site.x,
		rfocy = site.y,
		pby2 = rfocy-directrix;
	// parabola in degenerate case where focus is on directrix
	if (!pby2) {
		return rfocx;
		}
	var lArc = arc.rbPrevious;
	if (!lArc) {
		return -Infinity;
		}
	site = lArc.site;
	var lfocx = site.x,
		lfocy = site.y,
		plby2 = lfocy-directrix;
	// parabola in degenerate case where focus is on directrix
	if (!plby2) {
		return lfocx;
		}
	var	hl = lfocx-rfocx,
		aby2 = 1/pby2-1/plby2,
		b = hl/plby2;
	if (aby2) {
		return (-b+this.sqrt(b*b-2*aby2*(hl*hl/(-2*plby2)-lfocy+plby2/2+rfocy-pby2/2)))/aby2+rfocx;
		}
	// both parabolas have same distance to directrix, thus break point is midway
	return (rfocx+lfocx)/2;
	};

// calculate the right break point of a particular beach section,
// given a particular directrix
Voronoi.prototype.rightBreakPoint = function(arc, directrix) {
	var rArc = arc.rbNext;
	if (rArc) {
		return this.leftBreakPoint(rArc, directrix);
		}
	var site = arc.site;
	return site.y === directrix ? site.x : Infinity;
	};

Voronoi.prototype.detachBeachsection = function(beachsection) {
	this.detachCircleEvent(beachsection); // detach potentially attached circle event
	this.beachline.rbRemoveNode(beachsection); // remove from RB-tree
	this.beachsectionJunkyard.push(beachsection); // mark for reuse
	};

Voronoi.prototype.removeBeachsection = function(beachsection) {
	var circle = beachsection.circleEvent,
		x = circle.x,
		y = circle.ycenter,
		vertex = new this.Vertex(x, y),
		previous = beachsection.rbPrevious,
		next = beachsection.rbNext,
		disappearingTransitions = [beachsection],
		abs_fn = Math.abs;

	// remove collapsed beachsection from beachline
	this.detachBeachsection(beachsection);

	// there could be more than one empty arc at the deletion point, this
	// happens when more than two edges are linked by the same vertex,
	// so we will collect all those edges by looking up both sides of
	// the deletion point.
	// by the way, there is *always* a predecessor/successor to any collapsed
	// beach section, it's just impossible to have a collapsing first/last
	// beach sections on the beachline, since they obviously are unconstrained
	// on their left/right side.

	// look left
	var lArc = previous;
	while (lArc.circleEvent && abs_fn(x-lArc.circleEvent.x)<1e-9 && abs_fn(y-lArc.circleEvent.ycenter)<1e-9) {
		previous = lArc.rbPrevious;
		disappearingTransitions.unshift(lArc);
		this.detachBeachsection(lArc); // mark for reuse
		lArc = previous;
		}
	// even though it is not disappearing, I will also add the beach section
	// immediately to the left of the left-most collapsed beach section, for
	// convenience, since we need to refer to it later as this beach section
	// is the 'left' site of an edge for which a start point is set.
	disappearingTransitions.unshift(lArc);
	this.detachCircleEvent(lArc);

	// look right
	var rArc = next;
	while (rArc.circleEvent && abs_fn(x-rArc.circleEvent.x)<1e-9 && abs_fn(y-rArc.circleEvent.ycenter)<1e-9) {
		next = rArc.rbNext;
		disappearingTransitions.push(rArc);
		this.detachBeachsection(rArc); // mark for reuse
		rArc = next;
		}
	// we also have to add the beach section immediately to the right of the
	// right-most collapsed beach section, since there is also a disappearing
	// transition representing an edge's start point on its left.
	disappearingTransitions.push(rArc);
	this.detachCircleEvent(rArc);

	// walk through all the disappearing transitions between beach sections and
	// set the start point of their (implied) edge.
	var nArcs = disappearingTransitions.length,
		iArc;
	for (iArc=1; iArc<nArcs; iArc++) {
		rArc = disappearingTransitions[iArc];
		lArc = disappearingTransitions[iArc-1];
		this.setEdgeStartpoint(rArc.edge, lArc.site, rArc.site, vertex);
		}

	// create a new edge as we have now a new transition between
	// two beach sections which were previously not adjacent.
	// since this edge appears as a new vertex is defined, the vertex
	// actually define an end point of the edge (relative to the site
	// on the left)
	lArc = disappearingTransitions[0];
	rArc = disappearingTransitions[nArcs-1];
	rArc.edge = this.createEdge(lArc.site, rArc.site, undefined, vertex);

	// create circle events if any for beach sections left in the beachline
	// adjacent to collapsed sections
	this.attachCircleEvent(lArc);
	this.attachCircleEvent(rArc);
	};

Voronoi.prototype.addBeachsection = function(site) {
	var x = site.x,
		directrix = site.y;

	// find the left and right beach sections which will surround the newly
	// created beach section.
	// rhill 2011-06-01: This loop is one of the most often executed,
	// hence we expand in-place the comparison-against-epsilon calls.
	var lArc, rArc,
		dxl, dxr,
		node = this.beachline.root;

	while (node) {
		dxl = this.leftBreakPoint(node,directrix)-x;
		// x lessThanWithEpsilon xl => falls somewhere before the left edge of the beachsection
		if (dxl > 1e-9) {
			// this case should never happen
			// if (!node.rbLeft) {
			//	rArc = node.rbLeft;
			//	break;
			//	}
			node = node.rbLeft;
			}
		else {
			dxr = x-this.rightBreakPoint(node,directrix);
			// x greaterThanWithEpsilon xr => falls somewhere after the right edge of the beachsection
			if (dxr > 1e-9) {
				if (!node.rbRight) {
					lArc = node;
					break;
					}
				node = node.rbRight;
				}
			else {
				// x equalWithEpsilon xl => falls exactly on the left edge of the beachsection
				if (dxl > -1e-9) {
					lArc = node.rbPrevious;
					rArc = node;
					}
				// x equalWithEpsilon xr => falls exactly on the right edge of the beachsection
				else if (dxr > -1e-9) {
					lArc = node;
					rArc = node.rbNext;
					}
				// falls exactly somewhere in the middle of the beachsection
				else {
					lArc = rArc = node;
					}
				break;
				}
			}
		}
	// at this point, keep in mind that lArc and/or rArc could be
	// undefined or null.

	// create a new beach section object for the site and add it to RB-tree
	var newArc = this.createBeachsection(site);
	this.beachline.rbInsertSuccessor(lArc, newArc);

	// cases:
	//

	// [null,null]
	// least likely case: new beach section is the first beach section on the
	// beachline.
	// This case means:
	//   no new transition appears
	//   no collapsing beach section
	//   new beachsection become root of the RB-tree
	if (!lArc && !rArc) {
		return;
		}

	// [lArc,rArc] where lArc == rArc
	// most likely case: new beach section split an existing beach
	// section.
	// This case means:
	//   one new transition appears
	//   the left and right beach section might be collapsing as a result
	//   two new nodes added to the RB-tree
	if (lArc === rArc) {
		// invalidate circle event of split beach section
		this.detachCircleEvent(lArc);

		// split the beach section into two separate beach sections
		rArc = this.createBeachsection(lArc.site);
		this.beachline.rbInsertSuccessor(newArc, rArc);

		// since we have a new transition between two beach sections,
		// a new edge is born
		newArc.edge = rArc.edge = this.createEdge(lArc.site, newArc.site);

		// check whether the left and right beach sections are collapsing
		// and if so create circle events, to be notified when the point of
		// collapse is reached.
		this.attachCircleEvent(lArc);
		this.attachCircleEvent(rArc);
		return;
		}

	// [lArc,null]
	// even less likely case: new beach section is the *last* beach section
	// on the beachline -- this can happen *only* if *all* the previous beach
	// sections currently on the beachline share the same y value as
	// the new beach section.
	// This case means:
	//   one new transition appears
	//   no collapsing beach section as a result
	//   new beach section become right-most node of the RB-tree
	if (lArc && !rArc) {
		newArc.edge = this.createEdge(lArc.site,newArc.site);
		return;
		}

	// [null,rArc]
	// impossible case: because sites are strictly processed from top to bottom,
	// and left to right, which guarantees that there will always be a beach section
	// on the left -- except of course when there are no beach section at all on
	// the beach line, which case was handled above.
	// rhill 2011-06-02: No point testing in non-debug version
	//if (!lArc && rArc) {
	//	throw "Voronoi.addBeachsection(): What is this I don't even";
	//	}

	// [lArc,rArc] where lArc != rArc
	// somewhat less likely case: new beach section falls *exactly* in between two
	// existing beach sections
	// This case means:
	//   one transition disappears
	//   two new transitions appear
	//   the left and right beach section might be collapsing as a result
	//   only one new node added to the RB-tree
	if (lArc !== rArc) {
		// invalidate circle events of left and right sites
		this.detachCircleEvent(lArc);
		this.detachCircleEvent(rArc);

		// an existing transition disappears, meaning a vertex is defined at
		// the disappearance point.
		// since the disappearance is caused by the new beachsection, the
		// vertex is at the center of the circumscribed circle of the left,
		// new and right beachsections.
		// http://mathforum.org/library/drmath/view/55002.html
		// Except that I bring the origin at A to simplify
		// calculation
		var lSite = lArc.site,
			ax = lSite.x,
			ay = lSite.y,
			bx=site.x-ax,
			by=site.y-ay,
			rSite = rArc.site,
			cx=rSite.x-ax,
			cy=rSite.y-ay,
			d=2*(bx*cy-by*cx),
			hb=bx*bx+by*by,
			hc=cx*cx+cy*cy,
			vertex = new this.Vertex((cy*hb-by*hc)/d+ax, (bx*hc-cx*hb)/d+ay);

		// one transition disappear
		this.setEdgeStartpoint(rArc.edge, lSite, rSite, vertex);

		// two new transitions appear at the new vertex location
		newArc.edge = this.createEdge(lSite, site, undefined, vertex);
		rArc.edge = this.createEdge(site, rSite, undefined, vertex);

		// check whether the left and right beach sections are collapsing
		// and if so create circle events, to handle the point of collapse.
		this.attachCircleEvent(lArc);
		this.attachCircleEvent(rArc);
		return;
		}
	};

// ---------------------------------------------------------------------------
// Circle event methods

// rhill 2011-06-07: For some reasons, performance suffers significantly
// when instanciating a literal object instead of an empty ctor
Voronoi.prototype.CircleEvent = function() {
	};

Voronoi.prototype.attachCircleEvent = function(arc) {
	var lArc = arc.rbPrevious,
		rArc = arc.rbNext;
	if (!lArc || !rArc) {return;} // does that ever happen?
	var lSite = lArc.site,
		cSite = arc.site,
		rSite = rArc.site;

	// If site of left beachsection is same as site of
	// right beachsection, there can't be convergence
	if (lSite===rSite) {return;}

	// Find the circumscribed circle for the three sites associated
	// with the beachsection triplet.
	// rhill 2011-05-26: It is more efficient to calculate in-place
	// rather than getting the resulting circumscribed circle from an
	// object returned by calling Voronoi.circumcircle()
	// http://mathforum.org/library/drmath/view/55002.html
	// Except that I bring the origin at cSite to simplify calculations.
	// The bottom-most part of the circumcircle is our Fortune 'circle
	// event', and its center is a vertex potentially part of the final
	// Voronoi diagram.
	var bx = cSite.x,
		by = cSite.y,
		ax = lSite.x-bx,
		ay = lSite.y-by,
		cx = rSite.x-bx,
		cy = rSite.y-by;

	// If points l->c->r are clockwise, then center beach section does not
	// collapse, hence it can't end up as a vertex (we reuse 'd' here, which
	// sign is reverse of the orientation, hence we reverse the test.
	// http://en.wikipedia.org/wiki/Curve_orientation#Orientation_of_a_simple_polygon
	// rhill 2011-05-21: Nasty finite precision error which caused circumcircle() to
	// return infinites: 1e-12 seems to fix the problem.
	var d = 2*(ax*cy-ay*cx);
	if (d >= -2e-12){return;}

	var	ha = ax*ax+ay*ay,
		hc = cx*cx+cy*cy,
		x = (cy*ha-ay*hc)/d,
		y = (ax*hc-cx*ha)/d,
		ycenter = y+by;

	// Important: ybottom should always be under or at sweep, so no need
	// to waste CPU cycles by checking

	// recycle circle event object if possible
	var circleEvent = this.circleEventJunkyard.pop();
	if (!circleEvent) {
		circleEvent = new this.CircleEvent();
		}
	circleEvent.arc = arc;
	circleEvent.site = cSite;
	circleEvent.x = x+bx;
	circleEvent.y = ycenter+this.sqrt(x*x+y*y); // y bottom
	circleEvent.ycenter = ycenter;
	arc.circleEvent = circleEvent;

	// find insertion point in RB-tree: circle events are ordered from
	// smallest to largest
	var predecessor = null,
		node = this.circleEvents.root;
	while (node) {
		if (circleEvent.y < node.y || (circleEvent.y === node.y && circleEvent.x <= node.x)) {
			if (node.rbLeft) {
				node = node.rbLeft;
				}
			else {
				predecessor = node.rbPrevious;
				break;
				}
			}
		else {
			if (node.rbRight) {
				node = node.rbRight;
				}
			else {
				predecessor = node;
				break;
				}
			}
		}
	this.circleEvents.rbInsertSuccessor(predecessor, circleEvent);
	if (!predecessor) {
		this.firstCircleEvent = circleEvent;
		}
	};

Voronoi.prototype.detachCircleEvent = function(arc) {
	var circle = arc.circleEvent;
	if (circle) {
		if (!circle.rbPrevious) {
			this.firstCircleEvent = circle.rbNext;
			}
		this.circleEvents.rbRemoveNode(circle); // remove from RB-tree
		this.circleEventJunkyard.push(circle);
		arc.circleEvent = null;
		}
	};

// ---------------------------------------------------------------------------
// Diagram completion methods

// connect dangling edges (not if a cursory test tells us
// it is not going to be visible.
// return value:
//   false: the dangling endpoint couldn't be connected
//   true: the dangling endpoint could be connected
Voronoi.prototype.connectEdge = function(edge, bbox) {
	// skip if end point already connected
	var vb = edge.vb;
	if (!!vb) {return true;}

	// make local copy for performance purpose
	var va = edge.va,
		xl = bbox.xl,
		xr = bbox.xr,
		yt = bbox.yt,
		yb = bbox.yb,
		lSite = edge.lSite,
		rSite = edge.rSite,
		lx = lSite.x,
		ly = lSite.y,
		rx = rSite.x,
		ry = rSite.y,
		fx = (lx+rx)/2,
		fy = (ly+ry)/2,
		fm, fb;

	// get the line equation of the bisector if line is not vertical
	if (ry !== ly) {
		fm = (lx-rx)/(ry-ly);
		fb = fy-fm*fx;
		}

	// remember, direction of line (relative to left site):
	// upward: left.x < right.x
	// downward: left.x > right.x
	// horizontal: left.x == right.x
	// upward: left.x < right.x
	// rightward: left.y < right.y
	// leftward: left.y > right.y
	// vertical: left.y == right.y

	// depending on the direction, find the best side of the
	// bounding box to use to determine a reasonable start point

	// special case: vertical line
	if (fm === undefined) {
		// doesn't intersect with viewport
		if (fx < xl || fx >= xr) {return false;}
		// downward
		if (lx > rx) {
			if (!va) {
				va = new this.Vertex(fx, yt);
				}
			else if (va.y >= yb) {
				return false;
				}
			vb = new this.Vertex(fx, yb);
			}
		// upward
		else {
			if (!va) {
				va = new this.Vertex(fx, yb);
				}
			else if (va.y < yt) {
				return false;
				}
			vb = new this.Vertex(fx, yt);
			}
		}
	// closer to vertical than horizontal, connect start point to the
	// top or bottom side of the bounding box
	else if (fm < -1 || fm > 1) {
		// downward
		if (lx > rx) {
			if (!va) {
				va = new this.Vertex((yt-fb)/fm, yt);
				}
			else if (va.y >= yb) {
				return false;
				}
			vb = new this.Vertex((yb-fb)/fm, yb);
			}
		// upward
		else {
			if (!va) {
				va = new this.Vertex((yb-fb)/fm, yb);
				}
			else if (va.y < yt) {
				return false;
				}
			vb = new this.Vertex((yt-fb)/fm, yt);
			}
		}
	// closer to horizontal than vertical, connect start point to the
	// left or right side of the bounding box
	else {
		// rightward
		if (ly < ry) {
			if (!va) {
				va = new this.Vertex(xl, fm*xl+fb);
				}
			else if (va.x >= xr) {
				return false;
				}
			vb = new this.Vertex(xr, fm*xr+fb);
			}
		// leftward
		else {
			if (!va) {
				va = new this.Vertex(xr, fm*xr+fb);
				}
			else if (va.x < xl) {
				return false;
				}
			vb = new this.Vertex(xl, fm*xl+fb);
			}
		}
	edge.va = va;
	edge.vb = vb;
	return true;
	};

// line-clipping code taken from:
//   Liang-Barsky function by Daniel White
//   http://www.skytopia.com/project/articles/compsci/clipping.html
// Thanks!
// A bit modified to minimize code paths
Voronoi.prototype.clipEdge = function(edge, bbox) {
	var ax = edge.va.x,
		ay = edge.va.y,
		bx = edge.vb.x,
		by = edge.vb.y,
		t0 = 0,
		t1 = 1,
		dx = bx-ax,
		dy = by-ay;
	// left
	var q = ax-bbox.xl;
	if (dx===0 && q<0) {return false;}
	var r = -q/dx;
	if (dx<0) {
		if (r<t0) {return false;}
		else if (r<t1) {t1=r;}
		}
	else if (dx>0) {
		if (r>t1) {return false;}
		else if (r>t0) {t0=r;}
		}
	// right
	q = bbox.xr-ax;
	if (dx===0 && q<0) {return false;}
	r = q/dx;
	if (dx<0) {
		if (r>t1) {return false;}
		else if (r>t0) {t0=r;}
		}
	else if (dx>0) {
		if (r<t0) {return false;}
		else if (r<t1) {t1=r;}
		}
	// top
	q = ay-bbox.yt;
	if (dy===0 && q<0) {return false;}
	r = -q/dy;
	if (dy<0) {
		if (r<t0) {return false;}
		else if (r<t1) {t1=r;}
		}
	else if (dy>0) {
		if (r>t1) {return false;}
		else if (r>t0) {t0=r;}
		}
	// bottom		
	q = bbox.yb-ay;
	if (dy===0 && q<0) {return false;}
	r = q/dy;
	if (dy<0) {
		if (r>t1) {return false;}
		else if (r>t0) {t0=r;}
		}
	else if (dy>0) {
		if (r<t0) {return false;}
		else if (r<t1) {t1=r;}
		}

	// if we reach this point, Voronoi edge is within bbox

	// if t0 > 0, va needs to change
	// rhill 2011-06-03: we need to create a new vertex rather
	// than modifying the existing one, since the existing
	// one is likely shared with at least another edge
	if (t0 > 0) {
		edge.va = new this.Vertex(ax+t0*dx, ay+t0*dy);
		}

	// if t1 < 1, vb needs to change
	// rhill 2011-06-03: we need to create a new vertex rather
	// than modifying the existing one, since the existing
	// one is likely shared with at least another edge
	if (t1 < 1) {
		edge.vb = new this.Vertex(ax+t1*dx, ay+t1*dy);
		}

	return true;
	};

// Connect/cut edges at bounding box
Voronoi.prototype.clipEdges = function(bbox) {
	// connect all dangling edges to bounding box
	// or get rid of them if it can't be done
	var edges = this.edges,
		iEdge = edges.length,
		edge,
		abs_fn = Math.abs;

	// iterate backward so we can splice safely
	while (iEdge--) {
		edge = edges[iEdge];
		// edge is removed if:
		//   it is wholly outside the bounding box
		//   it is actually a point rather than a line
		if (!this.connectEdge(edge, bbox) || !this.clipEdge(edge, bbox) || (abs_fn(edge.va.x-edge.vb.x)<1e-9 && abs_fn(edge.va.y-edge.vb.y)<1e-9)) {
			edge.va = edge.vb = null;
			edges.splice(iEdge,1);
			}
		}
	};

// Close the cells.
// The cells are bound by the supplied bounding box.
// Each cell refers to its associated site, and a list
// of halfedges ordered counterclockwise.
Voronoi.prototype.closeCells = function(bbox) {
	// prune, order halfedges, then add missing ones
	// required to close cells
	var xl = bbox.xl,
		xr = bbox.xr,
		yt = bbox.yt,
		yb = bbox.yb,
		cells = this.cells,
		iCell = cells.length,
		cell,
		iLeft, iRight,
		halfedges, nHalfedges,
		edge,
		startpoint, endpoint,
		va, vb,
		abs_fn = Math.abs;

	while (iCell--) {
		cell = cells[iCell];
		// trim non fully-defined halfedges and sort them counterclockwise
		if (!cell.prepare()) {
			continue;
			}
		// close open cells
		// step 1: find first 'unclosed' point, if any.
		// an 'unclosed' point will be the end point of a halfedge which
		// does not match the start point of the following halfedge
		halfedges = cell.halfedges;
		nHalfedges = halfedges.length;
		// special case: only one site, in which case, the viewport is the cell
		// ...
		// all other cases
		iLeft = 0;
		while (iLeft < nHalfedges) {
			iRight = (iLeft+1) % nHalfedges;
			endpoint = halfedges[iLeft].getEndpoint();
			startpoint = halfedges[iRight].getStartpoint();
			// if end point is not equal to start point, we need to add the missing
			// halfedge(s) to close the cell
			if (abs_fn(endpoint.x-startpoint.x)>=1e-9 || abs_fn(endpoint.y-startpoint.y)>=1e-9) {
				// if we reach this point, cell needs to be closed by walking
				// counterclockwise along the bounding box until it connects
				// to next halfedge in the list
				va = endpoint;
				// walk downward along left side
				if (this.equalWithEpsilon(endpoint.x,xl) && this.lessThanWithEpsilon(endpoint.y,yb)) {
					vb = new this.Vertex(xl, this.equalWithEpsilon(startpoint.x,xl) ? startpoint.y : yb);
					}
				// walk rightward along bottom side
				else if (this.equalWithEpsilon(endpoint.y,yb) && this.lessThanWithEpsilon(endpoint.x,xr)) {
					vb = new this.Vertex(this.equalWithEpsilon(startpoint.y,yb) ? startpoint.x : xr, yb);
					}
				// walk upward along right side
				else if (this.equalWithEpsilon(endpoint.x,xr) && this.greaterThanWithEpsilon(endpoint.y,yt)) {
					vb = new this.Vertex(xr, this.equalWithEpsilon(startpoint.x,xr) ? startpoint.y : yt);
					}
				// walk leftward along top side
				else if (this.equalWithEpsilon(endpoint.y,yt) && this.greaterThanWithEpsilon(endpoint.x,xl)) {
					vb = new this.Vertex(this.equalWithEpsilon(startpoint.y,yt) ? startpoint.x : xl, yt);
					}
				edge = this.createBorderEdge(cell.site, va, vb);
				halfedges.splice(iLeft+1, 0, new this.Halfedge(edge, cell.site, null));
				nHalfedges = halfedges.length;
				}
			iLeft++;
			}
		}
	};

// ---------------------------------------------------------------------------
// Top-level Fortune loop

// rhill 2011-05-19:
//   Voronoi sites are kept client-side now, to allow
//   user to freely modify content. At compute time,
//   *references* to sites are copied locally.
Voronoi.prototype.compute = function(sites, bbox) {
	// to measure execution time
	var startTime = new Date();

	// init internal state
	this.reset();

	// Initialize site event queue
	var siteEvents = sites.slice(0);
	siteEvents.sort(function(a,b){
		var r = b.y - a.y;
		if (r) {return r;}
		return b.x - a.x;
		});

	// process queue
	var site = siteEvents.pop(),
		siteid = 0,
		xsitex = Number.MIN_VALUE, // to avoid duplicate sites
		xsitey = Number.MIN_VALUE,
		cells = this.cells,
		circle;

	// main loop
	for (;;) {
		// we need to figure whether we handle a site or circle event
		// for this we find out if there is a site event and it is
		// 'earlier' than the circle event
		circle = this.firstCircleEvent;

		// add beach section
		if (site && (!circle || site.y < circle.y || (site.y === circle.y && site.x < circle.x))) {
			// only if site is not a duplicate
			if (site.x !== xsitex || site.y !== xsitey) {
				// first create cell for new site
				cells[siteid] = new this.Cell(site);
				site.voronoiId = siteid++;
				// then create a beachsection for that site
				this.addBeachsection(site);
				// remember last site coords to detect duplicate
				xsitey = site.y;
				xsitex = site.x;
				}
			site = siteEvents.pop();
			}

		// remove beach section
		else if (circle) {
			this.removeBeachsection(circle.arc);
			}

		// all done, quit
		else {
			break;
			}
		}

	// wrapping-up:
	//   connect dangling edges to bounding box
	//   cut edges as per bounding box
	//   discard edges completely outside bounding box
	//   discard edges which are point-like
	this.clipEdges(bbox);

	//   add missing edges in order to close opened cells
	this.closeCells(bbox);

	// to measure execution time
	var stopTime = new Date();

	// prepare return values
	var diagram = new this.Diagram();
	diagram.cells = this.cells;
	diagram.edges = this.edges;
	diagram.execTime = stopTime.getTime()-startTime.getTime();

	// clean up
	this.reset();

	return diagram;
	};
