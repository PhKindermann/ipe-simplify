----------------------------------------------------------------------
-- Simplify Path for Ipe

--[[

SUMMARY

 This ipelet adds an option to simplify paths.
 
 The code is based on "Simplify.js" by Vladimir Agafonkin

FILE/AUTHOR HISTORY

 version  0. Initial Release. Philipp Kindermann 2016

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


function simplify(model)
   local str = getString(model, "Enter tolerance in px")
   if not str or str:match("^%s*$)") then return end
   tolerance = tonumber(str)

   -- start to edit the edges
   local t = { label = "shorten edges",
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
              simplifyPath(subPath, tolerance)
            end
          end
          obj:setShape(shape)
        end
      end
    end
   model:register(t)
end




function getString(model, string)
   if ipeui.getString ~= nil then
      return ipeui.getString(model.ui, "Enter tolerance in px")
   else 
      return model:getString("Enter tolerance in px")
   end
end


function getSquareDistance(p1, p2)
    -- Square distance between two points
    dx = p1.x - p2.x
    dy = p1.y - p2.y

    return dx * dx + dy * dy
end


function getSquareSegmentDistance(p, p1, p2)
    -- Square distance between point and a segment
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


function simplifyPath(path, tolerance)
  first = 1
  last = #path
  marked = {}
  first_stack = {}
  last_stack = {}
  new_points = {}
  marked[first] = 1
  marked[last+1] = 1
  while last do
    max_sqdist = 0
    for i = first + 1,last do 
      if (last > #path) then
        sqdist = getSquareSegmentDistance(path[i][1], path[first][1], path[#path][2])
      else
        sqdist = getSquareSegmentDistance(path[i][1], path[first][1], path[last][1])
      end
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
  
  -- only use first vertex, last vertex, and marked vertices
  table.insert(new_points,path[1][1])
  for i, seg in ipairs(path) do
    if marked[i] then
      table.insert(new_points,seg[1])
    end
  end
  table.insert(new_points,path[#path][2])
  
  -- clear the path
  while #path > 0 do
    table.remove(path)
  end
    
  -- reinsert the marked vertices
  for i=2,#new_points do
    seg = {new_points[i-1],new_points[i]}
    seg.type = "segment"
    table.insert(path,seg)
  end
end

methods = {
  { label = "Simplify", run=simplify},
}

