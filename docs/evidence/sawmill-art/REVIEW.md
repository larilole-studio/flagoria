# Hooded frame saw self-review

1. **Projection.** The stepped timber hood fills the north row. Its lit top and south eave meet the front posts, sash, log, and trestle in the south row. The roof occupies 14 rows and the front occupies 16. The atlas mockup uses flat ground.
2. **Light.** The roof courses, left post, end grain, and bench top catch the top-left light. The south fascia uses midtones, with darker timber on the right and under the eave.
3. **Outline.** The silhouette uses a one-pixel `#2a2238` outline. The two contact marks are one pixel high in `#3d3a5c`. The down-facing flagbearer is the original sheet crop and keeps its `#141b1b` outline.
4. **Palette.** All eight frames passed an exact RGB check against v1.1 and have binary alpha. The mill uses timber and steel, with wood-coloured chips.
5. **Grid and scale.** The idle alpha bounds measure **44 × 30 px**, spanning x=2–45 and y=2–31 on the **48 × 32 px** canvas. The eight frames share those bounds. All review enlargements use nearest-neighbour at 4×.
6. **Size.** The same-baseline lineup puts the mill at 30 px with the lumber mill and below the 31 px barracks. It is under two 16 px flagbearer sprites tall. Its open frame and 3×2 plot stay subordinate to the castle's 7×5 plot. The current castle walls are a 14 px ring and still need to grow.
7. **Footprint, collision, and overhang.** The footprint is **3×2** at 16 px per tile. Invisible collision tiles occupy the five `TWT / T.T` structure cells and leave the south-center doorstep empty. Overhang is 0 px, with no collision outside the plot.
8. **Y-sort reference.** The art's feet and contact row sit on the south edge of the plot. The intended sort line is that edge, 8 px below the installed sprite's south-middle tile-center anchor. The existing world draw order remains in effect and does not dynamically sort the mill against the hero.
9. **Phone readability.** At 4× in a 480×270 logical view the hood, pale toothed blade and horizontal log remain distinct. The raised and lowered sash positions differ by four native pixels, with a widening kerf, scattered chips and a separating board at the bottom of the stroke.
10. **Process.** Reviewed the native frames, 4× idle and work strip, and the same-baseline lineup. The atlas terrain mockup puts the mill beside the hero, castle and both pine sizes. The seven-frame working GIF loops at 130 ms per frame.

The live seed 4 captures show the idle pose and both ends of the working stroke
next to a pine. The camera at 1.0 shows the full castle and the hero with the
mill at the same integer scale. Pixel comparison confirmed that each opaque
sprite pixel covers a uniform 4 × 4 block in the idle and working captures.
