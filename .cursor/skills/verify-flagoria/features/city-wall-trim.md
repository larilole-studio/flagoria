# City wall team trim

Drive: drives/city_wall_trim.gd
Source: Scripts/mechanics/conquest/cities.gd

A player's stone city ring shows two shades of team trim. The bands follow
the wall cap and upper front on runs, corners, posts, and gates. Capture
recolors the trim along with the flag.

Host to see the blue starting castle. The seeded display drive captures
that ring, changes the fixture to a red owner through the structure sync
API, and captures the same ring again. In both frames the trim reaches the
corners and gate without coloring the ground or gate leaves.
