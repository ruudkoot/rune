# life provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/life.sml`. Project notice: LICENSE.

Classic SML/NJ list-based Life and its gun seed. Coordinate lists, neighbor
collection, lexicographic normalization and the next-generation algorithm
are unchanged. Profile generations are reduced from the original 25000
for practical portable runs; that value remains accepted by the driver.
All living coordinates are consumed into a count and Word32 checksum,
including cells that the original drawing helper would hide outside its
nonnegative plotting window. An independent set/neighbor-counter simulator
supplies the reviewed expected generations.

The unmodified source and separate adaptation patch accompany the port.
