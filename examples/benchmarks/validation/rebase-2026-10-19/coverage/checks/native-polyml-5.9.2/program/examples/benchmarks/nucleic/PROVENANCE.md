# nucleic provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/nucleic.sml`. Project notice: LICENSE.

Pseudoknot (nucleic) molecular search. The biological data, coordinate
transforms, geometry and search are unchanged. The numeric result is
checked against the upstream 33.797594890762724 reference with the same
relative 1e-6 tolerance. The returned sum counts verified computations,
not mere successful termination. Hartel et al., JFP 1996, is the literature
reference. Upstream explicitly notes earlier assembler versions of the
coordinate transform; this port retains its SML implementation.

The unmodified source and separate adaptation patch accompany the port.
