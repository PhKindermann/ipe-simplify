With the simplify ipelet, you can simplify a path in the sense that 
points that only a small number of points (based on the input 
tolerance) are kept while retaining the shape. The following example 
illustrates a hand-drawn path and two simplifications of it.

![Simplify examples](simplify.png) 

The ipelet utilizes the [Ramer–Douglas–Peucker algorithm](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)

# Download & Installation #

Download [simplify.lua](simplify.lua) and copy it to ~/.ipe/ipelets/
(or to some other directory for ipelets).

# Usage #

Run "Ipelets->Simplify Path->Simplify" to simplify the currently selected path.  

# Changes #

**12. April 2016**
first version of the simplify ipelet online