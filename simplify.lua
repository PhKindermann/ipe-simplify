----------------------------------------------------------------------
-- Simplify Path for Ipe

--[[

SUMMARY

 This ipelet adds an option to simplify paths: it reduces the number
 of vertices while retaining the shape of the path. It also gives the
 option to convert a path to a spline.
 
 The code is based on the Ramer–Douglas–Peucker algorithm.

FILE/AUTHOR HISTORY

 version  0. Initial Release. Philipp Kindermann 2016
 version  1. Added spline support. Philipp Kindermann 2016
 version  2. Make rounded corners. Philipp Kindermann 2022

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
  path without changing the drawing by much.
]]

V = ipe.Vector

radius = 4


function simplify(model, num)
   local str = getString(model, "Enter tolerance in px")
   if not str or str:match("^%s*$)") then return end
   tolerance = tonumber(str)

   -- start to edit the edges
   local t = { label = "simplify path",
	       pno = model.pno,
	       vno = model.vno,
	       selection = model:selection(),
	       original = model:page():clone(),
	       matrix = matrix,
	       undo = _G.revertOriginal,}
   t.redo = function (t, doc)
      local p = doc[t.pno]
      for _, i in ipairs(t.selection) do
        p:setSelect(i, 2)
      end
      local p = doc[t.pno]
      for i, obj, sel, layer in p:objects() do
        if sel then
          local shape = obj:shape()
          for _, subPath in ipairs(shape) do
            if (subPath["type"] == "curve") then
              simplifyPath(subPath, tolerance, num)
            end
          end
          obj:setShape(shape)
        end
      end
    end
   model:register(t)
end

function convert(model, num)
   -- start to edit the edges
   local t = { label = "convert",
	       pno = model.pno,
	       vno = model.vno,
	       selection = model:selection(),
	       original = model:page():clone(),
	       matrix = matrix,
	       undo = _G.revertOriginal,}
   t.redo = function (t, doc)
      local p = doc[t.pno]
      for _, i in ipairs(t.selection) do
        p:setSelect(i, 2)
      end
      local p = doc[t.pno]
      for i, obj, sel, layer in p:objects() do
        if sel then
          local shape = obj:shape()
          for _, subPath in ipairs(shape) do
            if (subPath["type"] == "curve") then
              convertPath(subPath)
            end
          end
          obj:setShape(shape)
        end
      end
    end
   model:register(t)
end

function getString(model, st)
   if ipeui.getString ~= nil then
      return ipeui.getString(model.ui, st)
   else 
      return model:getString(st)
   end
end



function simplifyPath(path, tolerance, num)
  
  -- get all control points
  points = {}
  for i,seg in ipairs(path) do
    for j = 1,#seg - 1 do
      table.insert(points,seg[j])
    end
  end
  table.insert(points,path[#path][#path[#path]])
  
  -- initialize
  first = 1
  last = #points
  marked = {}
  first_stack = {}
  last_stack = {}
  new_points = {}
  marked[first] = 1
  marked[last] = 1
  
  -- mark points to keep
  while last do
    max_sqdist = 0
    for i = first + 1,last do 
      sqdist = getSquareSegmentDistance(points[i], points[first], points[last])
      if sqdist > max_sqdist then
        index = i
        max_sqdist = sqdist
      end
    end
    
    if max_sqdist > tolerance * tolerance then
      marked[index] = 1
      table.insert(first_stack,first)
      table.insert(last_stack,index)
      table.insert(first_stack,index)
      table.insert(last_stack,last)
    end

    if #first_stack == 0 then
      first = nil
    else
      first = table.remove(first_stack)
    end

    if #last_stack == 0 then
      last = nil
    else
      last = table.remove(last_stack)
    end
  end
  
  -- only use marked vertices
  for i, point in ipairs(points) do
    if marked[i] then
      table.insert(new_points,point)
    end
  end
  
  -- clear the path
  while #path > 0 do
    table.remove(path)
  end
    
  -- reinsert the marked vertices
  if num == 2 then --spline
    if #new_points > 2 then
      cp = cp2(new_points[1],new_points[2],new_points[3])
      seg = {new_points[1],cp,new_points[2]}
      seg.type = "spline"
      table.insert(path,seg)
    else
      seg = {new_points[1],new_points[2]}
      seg.type = "segment"
      table.insert(path,seg)      
    end
    for i=2,#new_points-2 do
      q1 = new_points[i-1]
      q2 = new_points[i]
      q3 = new_points[i+1]
      q4 = new_points[i+2]
      cpa = cp1(q1,q2,q3)
      cpb = cp2(q2,q3,q4)
      seg = {q2,cpa,cpb,q3}
      seg.type = "spline"
      table.insert(path,seg)
    end
    if #new_points > 2 then
      cp = cp1(new_points[#new_points-2],new_points[#new_points-1],new_points[#new_points])
      seg = {new_points[#new_points-1],cp,new_points[#new_points]}
      seg.type = "spline"
      table.insert(path,seg)
    end
  else --path
    for i=2,#new_points do
      seg = {new_points[i-1],new_points[i]}
      seg.type = "segment"
      table.insert(path,seg)
    end
  end  
end


-- convert a path to a Bezier curve
function convertPath(path)
  -- get all control points
  points = {}
  for i,seg in ipairs(path) do
    for j = 1,#seg - 1 do
      table.insert(points,seg[j])
    end
  end
  table.insert(points,path[#path][#path[#path]])
  
    -- clear the path
  while #path > 0 do
    table.remove(path)
  end
  
  -- create Bezier curves
  if #points > 2 then
    cp = cp2(points[1],points[2],points[3])
    seg = {points[1],cp,points[2]}
    seg.type = "spline"
    table.insert(path,seg)
  else
    seg = {points[1],points[2]}
    seg.type = "segment"
    table.insert(path,seg)      
  end
  for i=2,#points-2 do
    q1 = points[i-1]
    q2 = points[i]
    q3 = points[i+1]
    q4 = points[i+2]
    cpa = cp1(q1,q2,q3)
    cpb = cp2(q2,q3,q4)
    seg = {q2,cpa,cpb,q3}
    seg.type = "spline"
    table.insert(path,seg)
  end
  if #points > 2 then
    cp = cp1(points[#points-2],points[#points-1],points[#points])
    seg = {points[#points-1],cp,points[#points]}
    seg.type = "spline"
    table.insert(path,seg)
  end

end


function round(model, num)
   -- start to edit the edges
   local t = { label = "round",
	       pno = model.pno,
	       vno = model.vno,
	       selection = model:selection(),
	       original = model:page():clone(),
	       matrix = matrix,
	       undo = _G.revertOriginal,}
   t.redo = function (t, doc)
      local p = doc[t.pno]
      for _, i in ipairs(t.selection) do
        p:setSelect(i, 2)
      end
      local p = doc[t.pno]
      for i, obj, sel, layer in p:objects() do
        if sel then
          local shape = obj:shape()
          for _, subPath in ipairs(shape) do
            if (subPath["type"] == "curve") then
              roundPath(subPath)
            end
          end
          obj:setShape(shape)
        end
      end
    end
   model:register(t)
end


function setRadius(model, num)
   local str = getString(model, "Enter radius in px")
   if not str or str:match("^%s*$)") then radius = 4 else radius = tonumber(str) end
   if radius == nil then radius = 4 end
end


-- round the corners
function roundPath(path)
  -- get all control points
  points = {}
  for i,seg in ipairs(path) do
    for j = 1,#seg - 1 do
      table.insert(points,seg[j])
    end
  end
  table.insert(points,path[#path][#path[#path]])
  
    -- clear the path
  while #path > 0 do
    table.remove(path)
  end
  
  -- create Bezier curves
  if #points > 2 then
    seg = {points[1],rd2(points[1],points[2])}
    seg.type = "segment"
    table.insert(path,seg)
    seg = {rd2(points[1],points[2]),points[2],rd1(points[2],points[3])}
    seg.type = "spline"
    table.insert(path,seg)
  else
    seg = {points[1],points[2]}
    seg.type = "segment"
    table.insert(path,seg)      
  end
  for i=2,#points-2 do
    seg = {rd1(points[i],points[i+1]),rd2(points[i],points[i+1])}
    seg.type = "segment"
    table.insert(path,seg)
    seg = {rd2(points[i],points[i+1]),points[i+1],rd1(points[i+1],points[i+2])}
    seg.type = "spline"
    table.insert(path,seg)
  end
  if #points > 2 then
    seg = {rd1(points[#points-1],points[#points]),points[#points]}
	--seg = {points[#points-2],points[#points-1]}
    seg.type = "segment"
    table.insert(path,seg)
  end

end



-- Square distance between point and a segment
function getSquareSegmentDistance(p, p1, p2)
    x = p1.x
    y = p1.y

    dx = p2.x - x
    dy = p2.y - y

    if dx ~= 0 or dy ~= 0 then
        t = ((p.x - x) * dx + (p.y - y) * dy) / (dx * dx + dy * dy)

        if t > 1 then
            x = p2.x
            y = p2.y
        elseif t > 0 then
            x = x + dx * t
            y = y + dy * t
        end
    end

    dx = p.x - x
    dy = p.y - y

    return dx * dx + dy * dy
end

-- rounding: first stopper between p1 and p2
function rd1(p1,p2)
  local vec = {p2.x - p1.x, p2.y - p1.y}
  local veclen = radius / len(vec)
  return V(p1.x + vec[1] * veclen, p1.y + vec[2] * veclen)
end

-- rounding: second stopper between p1 and p2
function rd2(p1,p2)
  local vec = {p2.x - p1.x, p2.y - p1.y}
  local veclen = radius / len(vec)
  return V(p2.x - vec[1] * veclen, p2.y - vec[2] * veclen)
end

-- first control point between p2 and p3
function cp1(p1,p2,p3)
  local tangent = tang(p1,p2,p3)
  local normtan = {tangent[1]/len(tangent), tangent[2]/len(tangent)}
  local vec = {p3.x - p2.x, p3.y - p2.y}
  local veclen = len(vec) / 3
  return V(p2.x + normtan[1] * veclen, p2.y + normtan[2] * veclen)
end

-- second control point between p2 and p3
function cp2(p2,p3,p4)
  local tangent = tang(p2,p3,p4)
  local normtan = {tangent[1]/len(tangent), tangent[2]/len(tangent)}
  local vec = {p3.x - p2.x, p3.y - p2.y}
  local veclen = len(vec) / 3
  return V(p3.x - normtan[1] * veclen, p3.y - normtan[2] * veclen)
end

-- vector for control points around p2
function tang(p1,p2,p3)
  local vec1 = {p2.x - p1.x, p2.y - p1.y}
  local vec2 = {p3.x - p2.x, p3.y - p2.y}
  local normvec1 = {vec1[1]/len(vec1), vec1[2]/len(vec1)}
  local normvec2 = {vec2[1]/len(vec2), vec2[2]/len(vec2)}
  local tangent = {normvec2[1] + normvec1[1], normvec2[2] + normvec1[2]}
  return tangent  
end

-- length of a vector
function len(vec)
  sqlen = vec[1] * vec[1] + vec[2] * vec[2]
  return math.sqrt(sqlen)  
end


methods = {
  { label = "Simplify", run=simplify},
  { label = "Simplify to Spline", run=simplify},
  { label = "Convert to Spline", run=convert},
  { label = "Set radius for round corners (default: 4px)", run=setRadius},
  { label = "Round Corners", run=round}
}

