With the Simplify Ipelet, you can simplify a path in the sense that 
points that only a small number of points (based on the input 
tolerance) are kept while retaining the shape. The ipelet utilizes the 
[Ramer–Douglas–Peucker algorithm](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm).
The user can choose whether he wants to simplify to a polygonal chain or
to a spline (a chain of cubic Bezier curves). The ipelet also gives an 
option to convert a polygonal chain into a spline.

The following example illustrates a hand-drawn path and two polygonal 
simplifications of it.

![Simplify examples](simplify.png) 

The second example shows a hand-drawn path, a polygonal simplification
with tolerance 5px, and a spline simplification with tolerance 10px.

![Simplify examples](simplifyspline.png) 

# Download & Installation #

Download [simplify.lua](simplify.lua) and copy it to ~/.ipe/ipelets/
(or to some other directory for ipelets).

# Usage #

Run "Ipelets->Simplify Path->Simplify" to simplify the currently selected path.  

Run "Ipelets->Simplify Path->Simplify to Spline" to create a spline instead of a path. 

Run "Ipelets->Simplify Path->Convert to Spline" to convert a path to a spline.

Run "Ipelets->Simplify Path->Round Corners" to round the corners on a polyline.

# Changes #

**12. April 2016**
first version of the Simplify Ipelet online

**13. April 2016**
added options to simplify and convert to a spline

**17. March 2022**
Added an option to round the corners of a polyline