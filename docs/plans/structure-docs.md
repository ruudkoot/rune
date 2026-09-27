# Documenting the structures, not only the signatures

A design, 2026-09-21. The owner asked whether there is a good reason not to
generate a page per structure, and how to do it without repeating in the
`.sml` files what the signature already says.

## There is no good reason not to

The one that looked like a reason does not hold. The worry was that tests,
complexity and the values a structure fixes belong to the structure rather
than the signature, and would have to be written twice. They do belong to
the structure -- and that is an argument **for** the pages, not against:
today they are written on the signature and qualified in prose, which is
where the awkwardness already shows.

Three examples of what the library has to say in an awkward place now:

* `String.maxSize/value` is 1073741823. That is a fact about `String`, and it
  sits in `STRING`, which `WideString` also implements.
* `WideChar.isAlpha/ascii-classes` explains that the classes of `WideChar`
  are ASCII's. It sits in `CHAR`, which `Char` also implements, where it is
  not true.
* `MONO_VECTOR` is implemented by nineteen structures with nineteen different
  element types, and its page shows one `elem`.

The costs are real but small: about 210 more pages, and the question of what
to do when a structure implements two signatures. Neither is a reason to keep
a reader guessing which of nineteen structures a sentence is about.

## Where the information comes from, with nothing written twice

The rule: **the signature says what a member means; the structure says what
it is here.** Nothing that is true of every implementation is written in a
structure's file, and nothing that is true of only one is written in the
signature's.

| On a structure's page | Where it comes from | Written twice? |
| --- | --- | --- |
| the member list, with the types instantiated (`Word8Vector.elem` is `Word8.word`, not `elem`) | elaboration: `DocElab` already computes this, which is how `types.md` knows | no -- computed |
| each member's description | the signature's doc comment | no -- shared |
| the structure's own prose | the doc comment above the structure in its `.sml` | no -- it is the only place |
| notes about this structure (`String.maxSize/value`) | notes whose id names a member of *this* structure, moved out of the signature | no -- each note has one home |
| the checks of the suite | `tests/basis`, keyed by the label `Structure.member/case`, which is already per structure | no -- already keyed that way |
| what other systems do | `tests/basis/annotations.txt`, already per structure | no |

So the only source change is **moving** the notes that are about one
structure from the signature's file to the structure's, which the note ids
already say: a note `String.maxSize/value` belongs to `String`, and one
`STRING/string-types` to `STRING`. `runedoc` can route them automatically and
warn when a note on a signature names a member of one implementation only --
that check is worth having whether or not the pages are built.

## What a structure implementing two signatures does

`TextIO` implements `TEXT_IO` and `IMPERATIVE_IO`; `Posix.FileSys.S`
implements `BIT_FLAGS`. The page lists the signatures at the top, in the
order of the claims, and shows each member once under the first signature
that names it, with a line saying which others name it too. The synopsis
block of the signature pages already prints the ascriptions, so the shape is
familiar.

## The work

1. `DocPage` gains a structure page beside its signature page: the same
   sections, with the types instantiated and the structure's own prose at the
   top. Most of it is the signature page with a different environment.
2. `DocSite` writes `str/<Name>.md`, links them from `structures.md` (which
   becomes an index rather than the only place a structure is named) and from
   each signature page, and checks the anchors and the size as it does now.
3. `DocNotes` routes a note to the structure when its id names one, and warns
   when a note on a signature is about one implementation.
4. The notes that are about one structure move in the sources -- about forty
   of them, by the count of ids in `notes.tsv` whose first part is a
   structure and not a signature.
5. `DOCUMENTED` and the coverage report gain the structures, so that a new
   one cannot go undocumented.

Sized M: the page kind is mostly the signature page, and the routing is a
rule on note ids. Step 4 is the one that touches many files, and it is a move
rather than a rewrite.

## What it turned out to be, when it was built (2026-09-26)

Steps 1 and 2 are as described. Step 5 is, except that `DOCUMENTED` did not
have to change: it is the ratchet of the *entries* of a signature, and a
structure has no entries of its own, so what keeps a new structure from going
undocumented is a check instead -- a public structure that neither claims a
signature nor has a comment that describes it is an error -- and coverage.md
gained a table of how much of each structure a signature describes. Steps 3
and 4 are not as described: they rested on the
assumption that a note id naming a structure means the note is about that
structure alone. It does not. **A note id is a test label**, and a check must
name a concrete structure, never a signature: `Int.mod/minInt-by-minus-one` is
a *reading of `INTEGER`* that holds for every structure implementing it, and
it names `Int` because that is where the check that pins it lives. Of the 324
notes, 229 have an id naming a structure -- not the forty the plan expected --
and most of them belong where they are written.

So nothing moved in the sources, and the warning of step 3 was not written:
there is nothing in an id to warn about. Instead `runedoc` **routes** a note
to the page of the structure its id names, wherever the note is written. A
note has one home in the sources (the file where it is read) and appears on
two pages: the signature's, where it belongs to the member's description, and
the structure's, under **Notes**. The plan's two examples come out right
without an edit: `String.maxSize/value` is written in `STRING` and shows on
`String`, `WideChar.isAlpha/ascii-classes` is written in `CHAR` and shows on
`WideChar`, since the id of each names the structure and not the signature.

Three more things the work found:

* **A structure that claims no signature needs a page most of all.**
  `WideTextIO` matches no signature of the library -- the transcription of
  `TEXT_IO` writes `string` and `char` -- and was named nowhere in the
  documentation. It now has a page, and a check errors when a public
  structure is documented nowhere.
* **A page is needed for the substructures a signature specifies**, such as
  `Socket.Ctl`, `Posix.FileSys.S` and `OS.IO.Kind`: 195 structures have a page
  in all. A structure that is bound by name to another public one -- `Position`
  is `Int`, `Text.Char` is `Char` -- has no page of its own, and every link to
  it leads to the page of what it is.
* **The types have to be printed under the name that reaches them.** The
  compiler's printer writes the name a type was declared under, and tells two
  of one name apart by a stamp (`instream/1371`), which means nothing to a
  reader. `Types.toStringNamed` now takes the caller's names, and a structure
  page shows `Word8Vector.sub` as `vector * int -> Word8.word`: `vector`
  because the structure names it, `Word8.word` because `elem` names the use
  and not the type, and `StreamIO.instream` rather than a stamp.

## Recommendation

Do it. The library has 210 structures and 65 signatures, and a reader looking
up `Word8Vector.sub` should not have to read `MONO_VECTOR` and work out which
of nineteen element types applies. The one thing to settle first is step 3's
warning: it will find notes that are on a signature and should not be, and
those are the ones worth reading before the pages exist at all.

## Verification

The pages are generated, so they are no better than the comments they are made
from. This is the ledger of reading every module of the library: once in its own
source, once against the page that is generated from it, and once against the
specification. A column for each thing those readings have to be able to say:

* **Documented** -- every value, type, datatype and exception the module
  declares is documented, in clear and well-written English prose. This is read
  in the source, where the comments are.
* **Generated docs** -- the generated pages say everything the source does:
  every member reaches its page with the right type, its description, its links
  and its notes, and nothing is lost on the way. This is the cross-check of the
  pages against the module, and it is where a fault of `runedoc` shows.
* **Basis spec docs** -- the comments say the same as the *Standard ML Basis
  Library* specification. Where the library departs from it on purpose, a note
  of the doc-comment language says so, and where the specification is silent,
  ambiguous or wrong, a `Reading:` or an `Erratum:` says how it is read.
* **Examples** and **Laws** -- every function that can carry one has the
  examples and the laws that are worth having. An example that is an equation
  is compiled and run when the pages are made, so it is a check as well as an
  illustration.
* **Tests** -- the checks of `tests/basis` that name the module are rigorous,
  and the suite is extended where they are not.

A cell is empty until that reading is done, `done` when it is, and `n/a` where
there is nothing to read. A structure that is another structure by name --
`Position` is `Int`, `Real64` is `Real` -- links to the page of what it is;
reading one reads both.

### Structures

| Module | Documented | Generated docs | Basis spec docs | Examples | Laws | Tests |
| --- | --- | --- | --- | --- | --- | --- |
| [`Array`](../generated/basis/str/Array.md) | done | done | done | done | done | done |
| [`Array2`](../generated/basis/str/Array2.md) | done | done | done | done | done | done |
| [`ArraySlice`](../generated/basis/str/ArraySlice.md) | done | done | done | done | done | done |
| [`BinIO`](../generated/basis/str/BinIO.md) | done | done | done | done | done | done |
| [`BinIO.StreamIO`](../generated/basis/str/BinIO.StreamIO.md) | done | done | done | done | done | done |
| [`BinPrimIO`](../generated/basis/str/BinPrimIO.md) | done | done | done | done | done | done |
| [`Bool`](../generated/basis/str/Bool.md) | done | done | done | done | done | done |
| [`BoolArray`](../generated/basis/str/BoolArray.md) | done | done | done | done | done | done |
| [`BoolArray2`](../generated/basis/str/BoolArray2.md) | done | done | done | done | done | done |
| [`BoolArraySlice`](../generated/basis/str/BoolArraySlice.md) |  |  |  |  |  |  |
| [`BoolVector`](../generated/basis/str/BoolVector.md) |  |  |  |  |  |  |
| [`BoolVectorSlice`](../generated/basis/str/BoolVectorSlice.md) |  |  |  |  |  |  |
| [`Byte`](../generated/basis/str/Byte.md) |  |  |  |  |  |  |
| [`Char`](../generated/basis/str/Char.md) |  |  |  |  |  |  |
| [`CharArray`](../generated/basis/str/CharArray.md) |  |  |  |  |  |  |
| [`CharArray2`](../generated/basis/str/CharArray2.md) |  |  |  |  |  |  |
| [`CharArraySlice`](../generated/basis/str/CharArraySlice.md) |  |  |  |  |  |  |
| [`CharVector`](../generated/basis/str/CharVector.md) |  |  |  |  |  |  |
| [`CharVectorSlice`](../generated/basis/str/CharVectorSlice.md) |  |  |  |  |  |  |
| [`CommandLine`](../generated/basis/str/CommandLine.md) |  |  |  |  |  |  |
| [`Date`](../generated/basis/str/Date.md) |  |  |  |  |  |  |
| [`FixedInt`](../generated/basis/str/Int.md) |  |  |  |  |  |  |
| [`General`](../generated/basis/str/General.md) |  |  |  |  |  |  |
| [`GenericSock`](../generated/basis/str/GenericSock.md) |  |  |  |  |  |  |
| [`IEEEReal`](../generated/basis/str/IEEEReal.md) |  |  |  |  |  |  |
| [`INet6Sock`](../generated/basis/str/INet6Sock.md) |  |  |  |  |  |  |
| [`INet6Sock.TCP`](../generated/basis/str/INet6Sock.TCP.md) |  |  |  |  |  |  |
| [`INet6Sock.UDP`](../generated/basis/str/INet6Sock.UDP.md) |  |  |  |  |  |  |
| [`INetSock`](../generated/basis/str/INetSock.md) |  |  |  |  |  |  |
| [`INetSock.TCP`](../generated/basis/str/INetSock.TCP.md) |  |  |  |  |  |  |
| [`INetSock.UDP`](../generated/basis/str/INetSock.UDP.md) |  |  |  |  |  |  |
| [`IO`](../generated/basis/str/IO.md) |  |  |  |  |  |  |
| [`Int`](../generated/basis/str/Int.md) |  |  |  |  |  |  |
| [`Int16`](../generated/basis/str/Int16.md) |  |  |  |  |  |  |
| [`Int16Array`](../generated/basis/str/Int16Array.md) |  |  |  |  |  |  |
| [`Int16Array2`](../generated/basis/str/Int16Array2.md) |  |  |  |  |  |  |
| [`Int16ArraySlice`](../generated/basis/str/Int16ArraySlice.md) |  |  |  |  |  |  |
| [`Int16Vector`](../generated/basis/str/Int16Vector.md) |  |  |  |  |  |  |
| [`Int16VectorSlice`](../generated/basis/str/Int16VectorSlice.md) |  |  |  |  |  |  |
| [`Int32`](../generated/basis/str/Int32.md) |  |  |  |  |  |  |
| [`Int32Array`](../generated/basis/str/Int32Array.md) |  |  |  |  |  |  |
| [`Int32Array2`](../generated/basis/str/Int32Array2.md) |  |  |  |  |  |  |
| [`Int32ArraySlice`](../generated/basis/str/Int32ArraySlice.md) |  |  |  |  |  |  |
| [`Int32Vector`](../generated/basis/str/Int32Vector.md) |  |  |  |  |  |  |
| [`Int32VectorSlice`](../generated/basis/str/Int32VectorSlice.md) |  |  |  |  |  |  |
| [`Int64`](../generated/basis/str/Int.md) |  |  |  |  |  |  |
| [`Int64Array`](../generated/basis/str/Int64Array.md) |  |  |  |  |  |  |
| [`Int64Array2`](../generated/basis/str/Int64Array2.md) |  |  |  |  |  |  |
| [`Int64ArraySlice`](../generated/basis/str/Int64ArraySlice.md) |  |  |  |  |  |  |
| [`Int64Vector`](../generated/basis/str/Int64Vector.md) |  |  |  |  |  |  |
| [`Int64VectorSlice`](../generated/basis/str/Int64VectorSlice.md) |  |  |  |  |  |  |
| [`Int8`](../generated/basis/str/Int8.md) |  |  |  |  |  |  |
| [`Int8Array`](../generated/basis/str/Int8Array.md) |  |  |  |  |  |  |
| [`Int8Array2`](../generated/basis/str/Int8Array2.md) |  |  |  |  |  |  |
| [`Int8ArraySlice`](../generated/basis/str/Int8ArraySlice.md) |  |  |  |  |  |  |
| [`Int8Vector`](../generated/basis/str/Int8Vector.md) |  |  |  |  |  |  |
| [`Int8VectorSlice`](../generated/basis/str/Int8VectorSlice.md) |  |  |  |  |  |  |
| [`IntArray`](../generated/basis/str/IntArray.md) |  |  |  |  |  |  |
| [`IntArray2`](../generated/basis/str/IntArray2.md) |  |  |  |  |  |  |
| [`IntArraySlice`](../generated/basis/str/IntArraySlice.md) |  |  |  |  |  |  |
| [`IntInf`](../generated/basis/str/IntInf.md) |  |  |  |  |  |  |
| [`IntVector`](../generated/basis/str/IntVector.md) |  |  |  |  |  |  |
| [`IntVectorSlice`](../generated/basis/str/IntVectorSlice.md) |  |  |  |  |  |  |
| [`LargeInt`](../generated/basis/str/IntInf.md) |  |  |  |  |  |  |
| [`LargeIntArray`](../generated/basis/str/LargeIntArray.md) |  |  |  |  |  |  |
| [`LargeIntArray2`](../generated/basis/str/LargeIntArray2.md) |  |  |  |  |  |  |
| [`LargeIntArraySlice`](../generated/basis/str/LargeIntArraySlice.md) |  |  |  |  |  |  |
| [`LargeIntVector`](../generated/basis/str/LargeIntVector.md) |  |  |  |  |  |  |
| [`LargeIntVectorSlice`](../generated/basis/str/LargeIntVectorSlice.md) |  |  |  |  |  |  |
| [`LargeReal`](../generated/basis/str/Real.md) |  |  |  |  |  |  |
| [`LargeReal.Math`](../generated/basis/str/Real.Math.md) |  |  |  |  |  |  |
| [`LargeRealArray`](../generated/basis/str/RealArray.md) |  |  |  |  |  |  |
| [`LargeRealArray2`](../generated/basis/str/RealArray2.md) |  |  |  |  |  |  |
| [`LargeRealArraySlice`](../generated/basis/str/RealArraySlice.md) |  |  |  |  |  |  |
| [`LargeRealVector`](../generated/basis/str/RealVector.md) |  |  |  |  |  |  |
| [`LargeRealVectorSlice`](../generated/basis/str/RealVectorSlice.md) |  |  |  |  |  |  |
| [`LargeWord`](../generated/basis/str/Word.md) |  |  |  |  |  |  |
| [`LargeWordArray`](../generated/basis/str/WordArray.md) |  |  |  |  |  |  |
| [`LargeWordArray2`](../generated/basis/str/WordArray2.md) |  |  |  |  |  |  |
| [`LargeWordArraySlice`](../generated/basis/str/WordArraySlice.md) |  |  |  |  |  |  |
| [`LargeWordVector`](../generated/basis/str/WordVector.md) |  |  |  |  |  |  |
| [`LargeWordVectorSlice`](../generated/basis/str/WordVectorSlice.md) |  |  |  |  |  |  |
| [`List`](../generated/basis/str/List.md) |  |  |  |  |  |  |
| [`ListPair`](../generated/basis/str/ListPair.md) |  |  |  |  |  |  |
| [`Math`](../generated/basis/str/Math.md) |  |  |  |  |  |  |
| [`NetHostDB`](../generated/basis/str/NetHostDB.md) |  |  |  |  |  |  |
| [`NetProtDB`](../generated/basis/str/NetProtDB.md) |  |  |  |  |  |  |
| [`NetServDB`](../generated/basis/str/NetServDB.md) |  |  |  |  |  |  |
| [`OS`](../generated/basis/str/OS.md) |  |  |  |  |  |  |
| [`OS.FileSys`](../generated/basis/str/OS.FileSys.md) |  |  |  |  |  |  |
| [`OS.IO`](../generated/basis/str/OS.IO.md) |  |  |  |  |  |  |
| [`OS.IO.Kind`](../generated/basis/str/OS.IO.Kind.md) |  |  |  |  |  |  |
| [`OS.Path`](../generated/basis/str/OS.Path.md) |  |  |  |  |  |  |
| [`OS.Process`](../generated/basis/str/OS.Process.md) |  |  |  |  |  |  |
| [`Option`](../generated/basis/str/Option.md) |  |  |  |  |  |  |
| [`PackReal32Big`](../generated/basis/str/PackReal32Big.md) |  |  |  |  |  |  |
| [`PackReal32Little`](../generated/basis/str/PackReal32Little.md) |  |  |  |  |  |  |
| [`PackReal64Big`](../generated/basis/str/PackRealBig.md) |  |  |  |  |  |  |
| [`PackReal64Little`](../generated/basis/str/PackRealLittle.md) |  |  |  |  |  |  |
| [`PackRealBig`](../generated/basis/str/PackRealBig.md) |  |  |  |  |  |  |
| [`PackRealLittle`](../generated/basis/str/PackRealLittle.md) |  |  |  |  |  |  |
| [`PackWord16Big`](../generated/basis/str/PackWord16Big.md) |  |  |  |  |  |  |
| [`PackWord16Little`](../generated/basis/str/PackWord16Little.md) |  |  |  |  |  |  |
| [`PackWord32Big`](../generated/basis/str/PackWord32Big.md) |  |  |  |  |  |  |
| [`PackWord32Little`](../generated/basis/str/PackWord32Little.md) |  |  |  |  |  |  |
| [`PackWord64Big`](../generated/basis/str/PackWord64Big.md) |  |  |  |  |  |  |
| [`PackWord64Little`](../generated/basis/str/PackWord64Little.md) |  |  |  |  |  |  |
| [`Position`](../generated/basis/str/Int.md) |  |  |  |  |  |  |
| [`Posix`](../generated/basis/str/Posix.md) |  |  |  |  |  |  |
| [`Posix.Error`](../generated/basis/str/Posix.Error.md) |  |  |  |  |  |  |
| [`Posix.FileSys`](../generated/basis/str/Posix.FileSys.md) |  |  |  |  |  |  |
| [`Posix.FileSys.O`](../generated/basis/str/Posix.FileSys.O.md) |  |  |  |  |  |  |
| [`Posix.FileSys.S`](../generated/basis/str/Posix.FileSys.S.md) |  |  |  |  |  |  |
| [`Posix.FileSys.ST`](../generated/basis/str/Posix.FileSys.ST.md) |  |  |  |  |  |  |
| [`Posix.IO`](../generated/basis/str/Posix.IO.md) |  |  |  |  |  |  |
| [`Posix.IO.FD`](../generated/basis/str/Posix.IO.FD.md) |  |  |  |  |  |  |
| [`Posix.IO.FLock`](../generated/basis/str/Posix.IO.FLock.md) |  |  |  |  |  |  |
| [`Posix.IO.O`](../generated/basis/str/Posix.IO.O.md) |  |  |  |  |  |  |
| [`Posix.ProcEnv`](../generated/basis/str/Posix.ProcEnv.md) |  |  |  |  |  |  |
| [`Posix.Process`](../generated/basis/str/Posix.Process.md) |  |  |  |  |  |  |
| [`Posix.Process.W`](../generated/basis/str/Posix.Process.W.md) |  |  |  |  |  |  |
| [`Posix.Signal`](../generated/basis/str/Posix.Signal.md) |  |  |  |  |  |  |
| [`Posix.SysDB`](../generated/basis/str/Posix.SysDB.md) |  |  |  |  |  |  |
| [`Posix.SysDB.Group`](../generated/basis/str/Posix.SysDB.Group.md) |  |  |  |  |  |  |
| [`Posix.SysDB.Passwd`](../generated/basis/str/Posix.SysDB.Passwd.md) |  |  |  |  |  |  |
| [`Posix.TTY`](../generated/basis/str/Posix.TTY.md) |  |  |  |  |  |  |
| [`Posix.TTY.C`](../generated/basis/str/Posix.TTY.C.md) |  |  |  |  |  |  |
| [`Posix.TTY.CF`](../generated/basis/str/Posix.TTY.CF.md) |  |  |  |  |  |  |
| [`Posix.TTY.I`](../generated/basis/str/Posix.TTY.I.md) |  |  |  |  |  |  |
| [`Posix.TTY.L`](../generated/basis/str/Posix.TTY.L.md) |  |  |  |  |  |  |
| [`Posix.TTY.O`](../generated/basis/str/Posix.TTY.O.md) |  |  |  |  |  |  |
| [`Posix.TTY.TC`](../generated/basis/str/Posix.TTY.TC.md) |  |  |  |  |  |  |
| [`Posix.TTY.V`](../generated/basis/str/Posix.TTY.V.md) |  |  |  |  |  |  |
| [`Real`](../generated/basis/str/Real.md) |  |  |  |  |  |  |
| [`Real.Math`](../generated/basis/str/Real.Math.md) |  |  |  |  |  |  |
| [`Real32`](../generated/basis/str/Real32.md) |  |  |  |  |  |  |
| [`Real32.Math`](../generated/basis/str/Real32.Math.md) |  |  |  |  |  |  |
| [`Real32Array`](../generated/basis/str/Real32Array.md) |  |  |  |  |  |  |
| [`Real32Array2`](../generated/basis/str/Real32Array2.md) |  |  |  |  |  |  |
| [`Real32ArraySlice`](../generated/basis/str/Real32ArraySlice.md) |  |  |  |  |  |  |
| [`Real32Vector`](../generated/basis/str/Real32Vector.md) |  |  |  |  |  |  |
| [`Real32VectorSlice`](../generated/basis/str/Real32VectorSlice.md) |  |  |  |  |  |  |
| [`Real64`](../generated/basis/str/Real.md) |  |  |  |  |  |  |
| [`Real64.Math`](../generated/basis/str/Real.Math.md) |  |  |  |  |  |  |
| [`Real64Array`](../generated/basis/str/RealArray.md) |  |  |  |  |  |  |
| [`Real64Array2`](../generated/basis/str/RealArray2.md) |  |  |  |  |  |  |
| [`Real64ArraySlice`](../generated/basis/str/RealArraySlice.md) |  |  |  |  |  |  |
| [`Real64Vector`](../generated/basis/str/RealVector.md) |  |  |  |  |  |  |
| [`Real64VectorSlice`](../generated/basis/str/RealVectorSlice.md) |  |  |  |  |  |  |
| [`RealArray`](../generated/basis/str/RealArray.md) |  |  |  |  |  |  |
| [`RealArray2`](../generated/basis/str/RealArray2.md) |  |  |  |  |  |  |
| [`RealArraySlice`](../generated/basis/str/RealArraySlice.md) |  |  |  |  |  |  |
| [`RealVector`](../generated/basis/str/RealVector.md) |  |  |  |  |  |  |
| [`RealVectorSlice`](../generated/basis/str/RealVectorSlice.md) |  |  |  |  |  |  |
| [`Runtime`](../generated/basis/str/Runtime.md) |  |  |  |  |  |  |
| [`SML90`](../generated/basis/str/SML90.md) |  |  |  |  |  |  |
| [`Socket`](../generated/basis/str/Socket.md) |  |  |  |  |  |  |
| [`Socket.AF`](../generated/basis/str/Socket.AF.md) |  |  |  |  |  |  |
| [`Socket.Ctl`](../generated/basis/str/Socket.Ctl.md) |  |  |  |  |  |  |
| [`Socket.SOCK`](../generated/basis/str/Socket.SOCK.md) |  |  |  |  |  |  |
| [`String`](../generated/basis/str/String.md) |  |  |  |  |  |  |
| [`StringCvt`](../generated/basis/str/StringCvt.md) |  |  |  |  |  |  |
| [`Substring`](../generated/basis/str/Substring.md) |  |  |  |  |  |  |
| [`SysWord`](../generated/basis/str/Word.md) |  |  |  |  |  |  |
| [`Text`](../generated/basis/str/Text.md) |  |  |  |  |  |  |
| [`TextIO`](../generated/basis/str/TextIO.md) |  |  |  |  |  |  |
| [`TextIO.StreamIO`](../generated/basis/str/TextIO.StreamIO.md) |  |  |  |  |  |  |
| [`TextPrimIO`](../generated/basis/str/TextPrimIO.md) |  |  |  |  |  |  |
| [`Time`](../generated/basis/str/Time.md) |  |  |  |  |  |  |
| [`Timer`](../generated/basis/str/Timer.md) |  |  |  |  |  |  |
| [`Unix`](../generated/basis/str/Unix.md) |  |  |  |  |  |  |
| [`UnixSock`](../generated/basis/str/UnixSock.md) |  |  |  |  |  |  |
| [`UnixSock.DGrm`](../generated/basis/str/UnixSock.DGrm.md) |  |  |  |  |  |  |
| [`UnixSock.Strm`](../generated/basis/str/UnixSock.Strm.md) |  |  |  |  |  |  |
| [`Vector`](../generated/basis/str/Vector.md) |  |  |  |  |  |  |
| [`VectorSlice`](../generated/basis/str/VectorSlice.md) |  |  |  |  |  |  |
| [`WideChar`](../generated/basis/str/WideChar.md) |  |  |  |  |  |  |
| [`WideCharArray`](../generated/basis/str/WideCharArray.md) |  |  |  |  |  |  |
| [`WideCharArraySlice`](../generated/basis/str/WideCharArraySlice.md) |  |  |  |  |  |  |
| [`WideCharVector`](../generated/basis/str/WideCharVector.md) |  |  |  |  |  |  |
| [`WideCharVectorSlice`](../generated/basis/str/WideCharVectorSlice.md) |  |  |  |  |  |  |
| [`WideString`](../generated/basis/str/WideString.md) |  |  |  |  |  |  |
| [`WideSubstring`](../generated/basis/str/WideSubstring.md) |  |  |  |  |  |  |
| [`WideText`](../generated/basis/str/WideText.md) |  |  |  |  |  |  |
| [`WideTextIO`](../generated/basis/str/WideTextIO.md) |  |  |  |  |  |  |
| [`WideTextIO.StreamIO`](../generated/basis/str/WideTextIO.StreamIO.md) |  |  |  |  |  |  |
| [`WideTextPrimIO`](../generated/basis/str/WideTextPrimIO.md) |  |  |  |  |  |  |
| [`Windows`](../generated/basis/str/Windows.md) |  |  |  |  |  |  |
| [`Windows.Config`](../generated/basis/str/Windows.Config.md) |  |  |  |  |  |  |
| [`Windows.DDE`](../generated/basis/str/Windows.DDE.md) |  |  |  |  |  |  |
| [`Windows.Key`](../generated/basis/str/Windows.Key.md) |  |  |  |  |  |  |
| [`Windows.Reg`](../generated/basis/str/Windows.Reg.md) |  |  |  |  |  |  |
| [`Windows.Status`](../generated/basis/str/Windows.Status.md) |  |  |  |  |  |  |
| [`Word`](../generated/basis/str/Word.md) |  |  |  |  |  |  |
| [`Word16`](../generated/basis/str/Word16.md) |  |  |  |  |  |  |
| [`Word16Array`](../generated/basis/str/Word16Array.md) |  |  |  |  |  |  |
| [`Word16Array2`](../generated/basis/str/Word16Array2.md) |  |  |  |  |  |  |
| [`Word16ArraySlice`](../generated/basis/str/Word16ArraySlice.md) |  |  |  |  |  |  |
| [`Word16Vector`](../generated/basis/str/Word16Vector.md) |  |  |  |  |  |  |
| [`Word16VectorSlice`](../generated/basis/str/Word16VectorSlice.md) |  |  |  |  |  |  |
| [`Word32`](../generated/basis/str/Word32.md) |  |  |  |  |  |  |
| [`Word32Array`](../generated/basis/str/Word32Array.md) |  |  |  |  |  |  |
| [`Word32Array2`](../generated/basis/str/Word32Array2.md) |  |  |  |  |  |  |
| [`Word32ArraySlice`](../generated/basis/str/Word32ArraySlice.md) |  |  |  |  |  |  |
| [`Word32Vector`](../generated/basis/str/Word32Vector.md) |  |  |  |  |  |  |
| [`Word32VectorSlice`](../generated/basis/str/Word32VectorSlice.md) |  |  |  |  |  |  |
| [`Word64`](../generated/basis/str/Word.md) |  |  |  |  |  |  |
| [`Word64Array`](../generated/basis/str/Word64Array.md) |  |  |  |  |  |  |
| [`Word64Array2`](../generated/basis/str/Word64Array2.md) |  |  |  |  |  |  |
| [`Word64ArraySlice`](../generated/basis/str/Word64ArraySlice.md) |  |  |  |  |  |  |
| [`Word64Vector`](../generated/basis/str/Word64Vector.md) |  |  |  |  |  |  |
| [`Word64VectorSlice`](../generated/basis/str/Word64VectorSlice.md) |  |  |  |  |  |  |
| [`Word8`](../generated/basis/str/Word8.md) |  |  |  |  |  |  |
| [`Word8Array`](../generated/basis/str/Word8Array.md) |  |  |  |  |  |  |
| [`Word8Array2`](../generated/basis/str/Word8Array2.md) |  |  |  |  |  |  |
| [`Word8ArraySlice`](../generated/basis/str/Word8ArraySlice.md) |  |  |  |  |  |  |
| [`Word8Vector`](../generated/basis/str/Word8Vector.md) |  |  |  |  |  |  |
| [`Word8VectorSlice`](../generated/basis/str/Word8VectorSlice.md) |  |  |  |  |  |  |
| [`WordArray`](../generated/basis/str/WordArray.md) |  |  |  |  |  |  |
| [`WordArray2`](../generated/basis/str/WordArray2.md) |  |  |  |  |  |  |
| [`WordArraySlice`](../generated/basis/str/WordArraySlice.md) |  |  |  |  |  |  |
| [`WordVector`](../generated/basis/str/WordVector.md) |  |  |  |  |  |  |
| [`WordVectorSlice`](../generated/basis/str/WordVectorSlice.md) |  |  |  |  |  |  |

### Signatures

| Module | Documented | Generated docs | Basis spec docs | Examples | Laws | Tests |
| --- | --- | --- | --- | --- | --- | --- |
| [`ARRAY`](../generated/basis/sig/ARRAY.md) |  |  |  |  |  |  |
| [`ARRAY2`](../generated/basis/sig/ARRAY2.md) |  |  |  |  |  |  |
| [`ARRAY_SLICE`](../generated/basis/sig/ARRAY_SLICE.md) |  |  |  |  |  |  |
| [`BIN_IO`](../generated/basis/sig/BIN_IO.md) |  |  |  |  |  |  |
| [`BIT_FLAGS`](../generated/basis/sig/BIT_FLAGS.md) |  |  |  |  |  |  |
| [`BOOL`](../generated/basis/sig/BOOL.md) |  |  |  |  |  |  |
| [`BYTE`](../generated/basis/sig/BYTE.md) |  |  |  |  |  |  |
| [`CHAR`](../generated/basis/sig/CHAR.md) |  |  |  |  |  |  |
| [`COMMAND_LINE`](../generated/basis/sig/COMMAND_LINE.md) |  |  |  |  |  |  |
| [`DATE`](../generated/basis/sig/DATE.md) |  |  |  |  |  |  |
| [`GENERAL`](../generated/basis/sig/GENERAL.md) |  |  |  |  |  |  |
| [`GENERIC_SOCK`](../generated/basis/sig/GENERIC_SOCK.md) |  |  |  |  |  |  |
| [`IEEE_REAL`](../generated/basis/sig/IEEE_REAL.md) |  |  |  |  |  |  |
| [`IMPERATIVE_IO`](../generated/basis/sig/IMPERATIVE_IO.md) |  |  |  |  |  |  |
| [`INET6_SOCK`](../generated/basis/sig/INET6_SOCK.md) |  |  |  |  |  |  |
| [`INET_SOCK`](../generated/basis/sig/INET_SOCK.md) |  |  |  |  |  |  |
| [`INTEGER`](../generated/basis/sig/INTEGER.md) |  |  |  |  |  |  |
| [`INT_INF`](../generated/basis/sig/INT_INF.md) |  |  |  |  |  |  |
| [`IO`](../generated/basis/sig/IO.md) |  |  |  |  |  |  |
| [`LIST`](../generated/basis/sig/LIST.md) |  |  |  |  |  |  |
| [`LIST_PAIR`](../generated/basis/sig/LIST_PAIR.md) |  |  |  |  |  |  |
| [`MATH`](../generated/basis/sig/MATH.md) |  |  |  |  |  |  |
| [`MONO_ARRAY`](../generated/basis/sig/MONO_ARRAY.md) |  |  |  |  |  |  |
| [`MONO_ARRAY2`](../generated/basis/sig/MONO_ARRAY2.md) |  |  |  |  |  |  |
| [`MONO_ARRAY_SLICE`](../generated/basis/sig/MONO_ARRAY_SLICE.md) |  |  |  |  |  |  |
| [`MONO_VECTOR`](../generated/basis/sig/MONO_VECTOR.md) |  |  |  |  |  |  |
| [`MONO_VECTOR_EQ`](../generated/basis/sig/MONO_VECTOR_EQ.md) |  |  |  |  |  |  |
| [`MONO_VECTOR_SLICE`](../generated/basis/sig/MONO_VECTOR_SLICE.md) |  |  |  |  |  |  |
| [`NET_HOST_DB`](../generated/basis/sig/NET_HOST_DB.md) |  |  |  |  |  |  |
| [`NET_PROT_DB`](../generated/basis/sig/NET_PROT_DB.md) |  |  |  |  |  |  |
| [`NET_SERV_DB`](../generated/basis/sig/NET_SERV_DB.md) |  |  |  |  |  |  |
| [`OPTION`](../generated/basis/sig/OPTION.md) |  |  |  |  |  |  |
| [`OS`](../generated/basis/sig/OS.md) |  |  |  |  |  |  |
| [`OS_FILE_SYS`](../generated/basis/sig/OS_FILE_SYS.md) |  |  |  |  |  |  |
| [`OS_IO`](../generated/basis/sig/OS_IO.md) |  |  |  |  |  |  |
| [`OS_PATH`](../generated/basis/sig/OS_PATH.md) |  |  |  |  |  |  |
| [`OS_PROCESS`](../generated/basis/sig/OS_PROCESS.md) |  |  |  |  |  |  |
| [`PACK_REAL`](../generated/basis/sig/PACK_REAL.md) |  |  |  |  |  |  |
| [`PACK_WORD`](../generated/basis/sig/PACK_WORD.md) |  |  |  |  |  |  |
| [`POSIX`](../generated/basis/sig/POSIX.md) |  |  |  |  |  |  |
| [`POSIX_ERROR`](../generated/basis/sig/POSIX_ERROR.md) |  |  |  |  |  |  |
| [`POSIX_FILE_SYS`](../generated/basis/sig/POSIX_FILE_SYS.md) |  |  |  |  |  |  |
| [`POSIX_IO`](../generated/basis/sig/POSIX_IO.md) |  |  |  |  |  |  |
| [`POSIX_PROCESS`](../generated/basis/sig/POSIX_PROCESS.md) |  |  |  |  |  |  |
| [`POSIX_PROC_ENV`](../generated/basis/sig/POSIX_PROC_ENV.md) |  |  |  |  |  |  |
| [`POSIX_SIGNAL`](../generated/basis/sig/POSIX_SIGNAL.md) |  |  |  |  |  |  |
| [`POSIX_SYS_DB`](../generated/basis/sig/POSIX_SYS_DB.md) |  |  |  |  |  |  |
| [`POSIX_TTY`](../generated/basis/sig/POSIX_TTY.md) |  |  |  |  |  |  |
| [`PRIM_IO`](../generated/basis/sig/PRIM_IO.md) |  |  |  |  |  |  |
| [`REAL`](../generated/basis/sig/REAL.md) |  |  |  |  |  |  |
| [`RUNTIME`](../generated/basis/sig/RUNTIME.md) |  |  |  |  |  |  |
| [`SML90`](../generated/basis/sig/SML90.md) |  |  |  |  |  |  |
| [`SOCKET`](../generated/basis/sig/SOCKET.md) |  |  |  |  |  |  |
| [`STREAM_IO`](../generated/basis/sig/STREAM_IO.md) |  |  |  |  |  |  |
| [`STRING`](../generated/basis/sig/STRING.md) |  |  |  |  |  |  |
| [`STRING_CVT`](../generated/basis/sig/STRING_CVT.md) |  |  |  |  |  |  |
| [`SUBSTRING`](../generated/basis/sig/SUBSTRING.md) |  |  |  |  |  |  |
| [`TEXT`](../generated/basis/sig/TEXT.md) |  |  |  |  |  |  |
| [`TEXT_IO`](../generated/basis/sig/TEXT_IO.md) |  |  |  |  |  |  |
| [`TEXT_STREAM_IO`](../generated/basis/sig/TEXT_STREAM_IO.md) |  |  |  |  |  |  |
| [`TIME`](../generated/basis/sig/TIME.md) |  |  |  |  |  |  |
| [`TIMER`](../generated/basis/sig/TIMER.md) |  |  |  |  |  |  |
| [`UNIX`](../generated/basis/sig/UNIX.md) |  |  |  |  |  |  |
| [`UNIX_SOCK`](../generated/basis/sig/UNIX_SOCK.md) |  |  |  |  |  |  |
| [`VECTOR`](../generated/basis/sig/VECTOR.md) |  |  |  |  |  |  |
| [`VECTOR_SLICE`](../generated/basis/sig/VECTOR_SLICE.md) |  |  |  |  |  |  |
| [`WINDOWS`](../generated/basis/sig/WINDOWS.md) |  |  |  |  |  |  |
| [`WORD`](../generated/basis/sig/WORD.md) |  |  |  |  |  |  |

### Functors

| Module | Documented | Generated docs | Basis spec docs | Examples | Laws | Tests |
| --- | --- | --- | --- | --- | --- | --- |
| [`ImperativeIO`](../generated/basis/fun/ImperativeIO.md) |  |  |  |  |  |  |
| [`PrimIO`](../generated/basis/fun/PrimIO.md) |  |  |  |  |  |  |
| [`StreamIO`](../generated/basis/fun/StreamIO.md) |  |  |  |  |  |  |
