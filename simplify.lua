----------------------------------------------------------------------
-- Simplify Path for Ipe

--[[

SUMMARY

 This ipelet adds an option to simplify paths: it reduces the number
 of vertices while retaining the shape of the path. It also gives the
 option to convert a path to a spline, to round the corners of a
 polyline, and to undo the rounding again.

 The simplification is based on the Ramer-Douglas-Peucker algorithm.

FILE/AUTHOR HISTORY

 version  0. Initial Release. Philipp Kindermann 2016
 version  1. Added spline support. Philipp Kindermann 2016
 version  2. Make rounded corners. Philipp Kindermann 2022
 version  3. Support for closed paths, unround corners, re-rounding
             with a new radius, radius clamping. Philipp Kindermann 2026

LICENSE

 This file can be distributed and modified under the terms of the GNU General
 Public License as published by the Free Software Foundation; either version
 3, or (at your option) any later version.

 This file is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 details.

--]]

----------------------------------------------------------------------

label = "Simplify Path"

about = [[
  Simplify Path: Reduce the number of points on a (possibly hand-drawn)
  path without changing the drawing by much. Also converts paths to
  splines and rounds (or unrounds) the corners of polylines.
]]

V = ipe.Vector

radius = 4

local EPS = 1e-9      -- numerical zero
local SAME = 1e-4     -- points closer than this are considered identical

----------------------------------------------------------------------
-- small geometry helpers

local function dist(p, q)
  local dx, dy = q.x - p.x, q.y - p.y
  return math.sqrt(dx * dx + dy * dy)
end

local function same(p, q)
  return dist(p, q) < SAME
end

-- squared distance between point p and segment ab
local function sqSegDist(p, a, b)
  local x, y = a.x, a.y
  local dx, dy = b.x - x, b.y - y
  if dx ~= 0 or dy ~= 0 then
    local t = ((p.x - x) * dx + (p.y - y) * dy) / (dx * dx + dy * dy)
    if t > 1 then
      x, y = b.x, b.y
    elseif t > 0 then
      x, y = x + dx * t, y + dy * t
    end
  end
  dx, dy = p.x - x, p.y - y
  return dx * dx + dy * dy
end

-- point at distance d from p in direction of q
local function towards(p, q, d)
  local l = dist(p, q)
  return V(p.x + (q.x - p.x) * d / l, p.y + (q.y - p.y) * d / l)
end

-- unit tangent at p2 (bisecting the directions p1->p2 and p2->p3)
local function tang(p1, p2, p3)
  local d1, d2 = dist(p1, p2), dist(p2, p3)
  local tx = (p2.x - p1.x) / d1 + (p3.x - p2.x) / d2
  local ty = (p2.y - p1.y) / d1 + (p3.y - p2.y) / d2
  local l = math.sqrt(tx * tx + ty * ty)
  if l < EPS then -- path reverses at p2
    return (p3.x - p2.x) / d2, (p3.y - p2.y) / d2
  end
  return tx / l, ty / l
end

-- first control point between p2 and p3
local function cp1(p1, p2, p3)
  local tx, ty = tang(p1, p2, p3)
  local s = dist(p2, p3) / 3
  return V(p2.x + tx * s, p2.y + ty * s)
end

-- second control point between p2 and p3
local function cp2(p2, p3, p4)
  local tx, ty = tang(p2, p3, p4)
  local s = dist(p2, p3) / 3
  return V(p3.x - tx * s, p3.y - ty * s)
end

----------------------------------------------------------------------
-- reading and writing subpaths

local function mkseg(type, ...)
  local s = { ... }
  s.type = type
  return s
end

local function clearPath(path)
  for i = #path, 1, -1 do path[i] = nil end
end

-- A rounded corner as created by this ipelet: a quadratic spline
-- {a, c, b} where c is the original vertex and |ac| = |cb|.
local function isCorner(seg)
  if #seg ~= 3 or (seg.type ~= "spline" and seg.type ~= "quad") then
    return false
  end
  local d1, d2 = dist(seg[1], seg[2]), dist(seg[2], seg[3])
  return d1 > EPS and math.abs(d1 - d2) <= 0.01 + 0.001 * d1
end

-- Returns the vertex list of a curve subpath and whether it is closed.
-- With detectCorners, rounded corners are replaced by their original
-- corner point (this is what "unrounding" means).
-- For closed paths the first vertex is not repeated at the end.
local function getVertices(path, detectCorners)
  local segs = {}
  for _, seg in ipairs(path) do
    segs[#segs + 1] = { pts = seg, corner = detectCorners and isCorner(seg) }
  end
  if #segs == 0 then return {}, false end

  local closed = path.closed and true or false
  local first = segs[1].pts[1]
  local lastSeg = segs[#segs].pts
  local last = lastSeg[#lastSeg]
  if closed and not same(first, last) then
    -- make Ipe's implicit closing segment explicit
    segs[#segs + 1] = { pts = { last, first }, corner = false }
  end

  local m = #segs
  local verts = {}
  local function push(p)
    if #verts == 0 or not same(verts[#verts], p) then
      verts[#verts + 1] = p
    end
  end

  for i = 1, m do
    local s = segs[i].pts
    local prevCorner
    if i > 1 then prevCorner = segs[i - 1].corner
    elseif closed then prevCorner = segs[m].corner
    else prevCorner = false end
    -- a junction next to a rounded corner is only a stopper, not a vertex
    if not prevCorner and not segs[i].corner then push(s[1]) end
    -- inner control points (for a rounded corner: the corner itself)
    for j = 2, #s - 1 do push(s[j]) end
  end
  if not closed and not segs[m].corner then
    local s = segs[m].pts
    push(s[#s])
  end
  if closed then
    while #verts > 1 and same(verts[1], verts[#verts]) do
      table.remove(verts)
    end
  end
  return verts, closed
end

local function buildPolyline(path, q, closed)
  clearPath(path)
  for i = 2, #q do
    path[#path + 1] = mkseg("segment", q[i - 1], q[i])
  end
  path.closed = closed
end

local function buildSpline(path, q, closed)
  local n = #q
  if n < 3 then buildPolyline(path, q, closed) return end
  clearPath(path)
  if closed then
    for i = 1, n do
      local q0, q1 = q[(i - 2) % n + 1], q[i]
      local q2, q3 = q[i % n + 1], q[(i + 1) % n + 1]
      path[#path + 1] = mkseg("spline", q1, cp1(q0, q1, q2), cp2(q1, q2, q3), q2)
    end
  else
    path[#path + 1] = mkseg("spline", q[1], cp2(q[1], q[2], q[3]), q[2])
    for i = 2, n - 2 do
      path[#path + 1] = mkseg("spline", q[i], cp1(q[i - 1], q[i], q[i + 1]),
                              cp2(q[i], q[i + 1], q[i + 2]), q[i + 1])
    end
    path[#path + 1] = mkseg("spline", q[n - 1], cp1(q[n - 2], q[n - 1], q[n]), q[n])
  end
  path.closed = closed
end

local function buildRounded(path, q, closed)
  local n = #q
  if n < 3 then buildPolyline(path, q, closed) return end

  local function isCornerIndex(i)
    return closed or (i > 1 and i < n)
  end
  -- how much of edge (i, j) a corner at i may use: half the edge if the
  -- other end is rounded too, otherwise the whole edge
  local function limit(i, j)
    local l = dist(q[i], q[j])
    if isCornerIndex(j) then return l / 2 else return l end
  end
  -- stoppers a (before) and b (after) of corner i
  local function stoppers(i)
    local h, j = (i - 2) % n + 1, i % n + 1
    local r = math.min(radius, limit(i, h), limit(i, j))
    return towards(q[i], q[h], r), towards(q[i], q[j], r)
  end

  clearPath(path)
  local function line(p1, p2)
    if dist(p1, p2) > EPS then path[#path + 1] = mkseg("segment", p1, p2) end
  end

  if closed then
    local cur
    for i = 1, n do
      local a, b = stoppers(i)
      if cur then line(cur, a) end
      path[#path + 1] = mkseg("spline", a, q[i], b)
      cur = b
    end
    -- the last straight piece back to the start is Ipe's closing segment
  else
    local cur = q[1]
    for i = 2, n - 1 do
      local a, b = stoppers(i)
      line(cur, a)
      path[#path + 1] = mkseg("spline", a, q[i], b)
      cur = b
    end
    line(cur, q[n])
  end
  path.closed = closed
end

----------------------------------------------------------------------
-- Ramer-Douglas-Peucker

local function rdp(pts, first, last, sqtol, keep)
  local stack = { { first, last } }
  while #stack > 0 do
    local top = table.remove(stack)
    local f, l = top[1], top[2]
    local maxd, idx = 0, nil
    for i = f + 1, l - 1 do
      local d = sqSegDist(pts[i], pts[f], pts[l])
      if d > maxd then maxd, idx = d, i end
    end
    if idx and maxd > sqtol then
      keep[idx] = true
      stack[#stack + 1] = { f, idx }
      stack[#stack + 1] = { idx, l }
    end
  end
end

local function simplifyVertices(pts, closed, tol)
  local n = #pts
  if n < 3 then return pts end
  local keep, sqtol = {}, tol * tol

  if closed then
    -- split the cycle at the vertex farthest from the first one
    local k, maxd = 2, -1
    for i = 2, n do
      local d = dist(pts[1], pts[i])
      if d > maxd then k, maxd = i, d end
    end
    local ext = {}
    for i = 1, n do ext[i] = pts[i] end
    ext[n + 1] = pts[1]
    keep[1], keep[k] = true, true
    rdp(ext, 1, k, sqtol, keep)
    rdp(ext, k, n + 1, sqtol, keep)
    -- a closed path needs at least three vertices
    local count = 0
    for i = 1, n do if keep[i] then count = count + 1 end end
    if count < 3 then
      local best, bestd = nil, -1
      for i = 1, n do
        if not keep[i] then
          local d = sqSegDist(pts[i], pts[1], pts[k])
          if d > bestd then best, bestd = i, d end
        end
      end
      if best then keep[best] = true end
    end
  else
    keep[1], keep[n] = true, true
    rdp(pts, 1, n, sqtol, keep)
  end

  local res = {}
  for i = 1, n do
    if keep[i] then res[#res + 1] = pts[i] end
  end
  return res
end

----------------------------------------------------------------------
-- Ipe glue

function getString(model, st)
  if ipeui.getString ~= nil then
    return ipeui.getString(model.ui, st)
  else
    return model:getString(st)
  end
end

local function askNumber(model, prompt)
  local str = getString(model, prompt)
  if not str or str:match("^%s*$") then return nil end
  return tonumber(str)
end

-- apply fn to every curve subpath of every selected path object
local function applyToSelection(model, label, fn)
  if not model:page():hasSelection() then
    model:warning("Nothing selected")
    return
  end
  local t = { label = label,
              pno = model.pno,
              vno = model.vno,
              selection = model:selection(),
              original = model:page():clone(),
              undo = _G.revertOriginal, }
  t.redo = function (t, doc)
    local p = doc[t.pno]
    for _, i in ipairs(t.selection) do
      p:setSelect(i, 2)
    end
    for i, obj, sel, layer in p:objects() do
      if sel and obj:type() == "path" then
        local shape = obj:shape()
        for _, subPath in ipairs(shape) do
          if subPath.type == "curve" then fn(subPath) end
        end
        obj:setShape(shape)
      end
    end
  end
  model:register(t)
end

----------------------------------------------------------------------
-- commands

local function simplify(model, num)
  local tolerance = askNumber(model, "Enter tolerance in px")
  if not tolerance then return end
  applyToSelection(model, "simplify path", function (path)
    local verts, closed = getVertices(path, false)
    if #verts < 2 then return end
    verts = simplifyVertices(verts, closed, tolerance)
    if num == 2 then
      buildSpline(path, verts, closed)
    else
      buildPolyline(path, verts, closed)
    end
  end)
end

local function convert(model, num)
  applyToSelection(model, "convert to spline", function (path)
    local verts, closed = getVertices(path, false)
    if #verts < 2 then return end
    buildSpline(path, verts, closed)
  end)
end

local function setRadius(model, num)
  local r = askNumber(model, "Enter radius in px (current: " .. radius .. ")")
  if r and r > 0 then radius = r end
end

local function round(model, num)
  -- already rounded corners are unrounded first, so running this again
  -- after changing the radius updates the rounding
  applyToSelection(model, "round corners", function (path)
    local verts, closed = getVertices(path, true)
    if #verts < 2 then return end
    buildRounded(path, verts, closed)
  end)
end

local function unround(model, num)
  applyToSelection(model, "unround corners", function (path)
    local verts, closed = getVertices(path, true)
    if #verts < 2 then return end
    buildPolyline(path, verts, closed)
  end)
end

methods = {
  { label = "Simplify", run = simplify },
  { label = "Simplify to Spline", run = simplify },
  { label = "Convert to Spline", run = convert },
  { label = "Set radius for round corners (default: 4px)", run = setRadius },
  { label = "Round Corners", run = round },
  { label = "Unround Corners", run = unround },
}

----------------------------------------------------------------------
