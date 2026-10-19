# ratio-regions provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/ratio-regions.sml`. Original, adaptation patch and notices retained.

Jeff Siskind Scheme algorithm translated by Stephen Weeks. The Cox/Rao/Zhong
ratio-region reduction and preflow-push wave scheduling are retained.
The original generated capacities and weights remain fixed; expose and
consume the returned min-cut mask by counting true cells. No clock limit
is introduced. Reference fixtures must check the retained mask as well as
the count, before performance interpretations about flow behavior.
