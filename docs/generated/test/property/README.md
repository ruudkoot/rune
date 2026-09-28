# Property testing

[How to read these pages](conventions.md) &middot; [the top-level environment](top-level.md) &middot; [the structures](structures.md) &middot; [exceptions](exceptions.md) &middot; [what depends on what](depends.md) &middot; [types that are one type](types.md) &middot; [readings of the specification](readings.md) &middot; [what is documented](coverage.md) &middot; index: [a](index/a.md) [b](index/b.md) [c](index/c.md) [d](index/d.md) [e](index/e.md) [f](index/f.md) [g](index/g.md) [h](index/h.md) [i](index/i.md) [l](index/l.md) [m](index/m.md) [o](index/o.md) [p](index/p.md) [r](index/r.md) [s](index/s.md) [t](index/t.md) [u](index/u.md) [v](index/v.md) [w](index/w.md) [symbols](index/symbols.md)

## Property testing

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`ARB`](sig/ARB.md) | Arbitraries: the generator, the printer, the observer and the equality of a type, as one record -- what QuickCheck finds by a type class and a program here passes by name (docs/plans/quickcheck.md, D4). | required | 26 of 26 |
| [`ARB_OF`](sig/ARB_OF.md) | The arbitrary of one type of a structure: what the functors of the library make of a structure of the Basis Library, and what the structures [`Int8Arb`](str/Int8Arb.md), [`Word8Arb`](str/Word8Arb.md), [`CharArraySliceArb`](str/CharArraySliceArb.md) and the rest are. | required | 2 of 2 |
| [`BASIS_DATA_ARB`](sig/BASIS_DATA_ARB.md) | The arbitraries of the small datatypes and readers of the Basis Library. | required | 4 of 4 |
| [`CHECK`](sig/CHECK.md) | Running properties: many cases, each from its own seed at a size that grows over the run, and a report. | required | 9 of 9 |
| [`CO`](sig/CO.md) | Observers: what a generated function sees of its argument (QuickCheck's CoArbitrary, reduced to a hash). Two arguments with the same observation get the same result from a generated function. | required | 14 of 14 |
| [`DATE_ARB`](sig/DATE_ARB.md) | The arbitraries of `Date.date`, of its months, weekdays and record of fields, by the generator principle P12 (docs/plans/quickcheck.md). | required | 5 of 5 |
| [`GEN`](sig/GEN.md) | Generators: values drawn from the source of a case of a property. | required | 43 of 43 |
| [`IEEE_REAL_ARB`](sig/IEEE_REAL_ARB.md) | The arbitraries of `IEEEReal`'s types, by the generator principle P12. | required | 3 of 3 |
| [`INET6_SOCK_ARB`](sig/INET6_SOCK_ARB.md) | The arbitraries of Rune's IPv6 sockets and addresses (docs/plans/quickcheck.md, M6), apart from [`SYSTEM_ARB`](sig/SYSTEM_ARB.md) because `INet6Sock` is Rune's own. | required | 2 of 2 |
| [`PROP`](sig/PROP.md) | Properties: what must hold for every value a generator draws. | required | 15 of 15 |
| [`SHOW`](sig/SHOW.md) | Printers: how a value of a counterexample is shown, as Standard ML that reads back where the type has a literal syntax. | required | 17 of 17 |
| [`SML90_ARB`](sig/SML90_ARB.md) | The arbitrary of the input streams of the optional structure `SML90`, apart from [`SYSTEM_ARB`](sig/SYSTEM_ARB.md) because not every compiler has that structure. | required | 1 of 1 |
| [`SYSTEM_ARB`](sig/SYSTEM_ARB.md) | The arbitraries of the values of the operating system that the Basis Library's laws are written over (docs/plans/quickcheck.md, M6). | required | 33 of 33 |

## Functors

| Functor |  |
| --- | --- |
| [`IntegerArbFn`](fun/IntegerArbFn.md) | The arbitrary of the integers of a structure of `INTEGER`, by the generator principles P1 and P2: small, on an edge, or anywhere in the range, a third each; an `IntInf` without bounds by [`Gen.intInf`](sig/GEN.md#val-intinf). |
| [`WordArbFn`](fun/WordArbFn.md) | The arbitrary of the words of a structure of `WORD`, by the generator principle P3: small, on an edge (0, 1, the largest, powers of two and their neighbours), or anywhere, a third each. The words are at most 64 bits. |
| [`RealArbFn`](fun/RealArbFn.md) | The arbitrary of the reals of a structure of `REAL`, by the generator principle P4: a special one, a small one, or any bit pattern, a third each. |
| [`CharArbFn`](fun/CharArbFn.md) | The arbitrary of the characters of a structure of `CHAR`, by the generator principle P5, as [`Gen.code`](sig/GEN.md#val-code) draws their codes. |
| [`StringArbFn`](fun/StringArbFn.md) | The arbitrary of the strings of a structure of `STRING`: lists of the characters of `char`, by the generator principle P6. |
| [`SubstringArbFn`](fun/SubstringArbFn.md) | The arbitrary of the substrings of a structure of `SUBSTRING`: a string of `string`, and a start and a length within it. `name` is the structure's name, which the printer writes. |
| [`MonoVectorArbFn`](fun/MonoVectorArbFn.md) | The arbitrary of the vectors of a structure of `MONO_VECTOR`: lists of `elem`, by the generator principle P6. `name` is the structure's name, which the printer writes. |
| [`MonoArrayArbFn`](fun/MonoArrayArbFn.md) | The arbitrary of the arrays of a structure of `MONO_ARRAY`, as [`MonoVectorArbFn`](fun/MonoVectorArbFn.md) draws vectors: a fresh array at every draw, compared by its elements. |
| [`MonoVectorSliceArbFn`](fun/MonoVectorSliceArbFn.md) | The arbitrary of the slices of a structure of `MONO_VECTOR_SLICE`: a vector of `vector`, and a start and a length within it, compared as [`Arb.vectorSlice`](sig/ARB.md#val-vectorslice) compares slices. `name` is the structure's name. |
| [`MonoArraySliceArbFn`](fun/MonoArraySliceArbFn.md) | The arbitrary of the slices of a structure of `MONO_ARRAY_SLICE`, as [`MonoVectorSliceArbFn`](fun/MonoVectorSliceArbFn.md) draws them, over a fresh array of `array` at every draw. `name` is the structure's name. |
| [`MonoArray2ArbFn`](fun/MonoArray2ArbFn.md) | The arbitrary of the two-dimensional arrays of a structure of `MONO_ARRAY2`, as [`Arb.array2`](sig/ARB.md#val-array2) draws them. `name` is the structure's name. |

---

<sub>Generated by runedoc; do not edit.</sub>
