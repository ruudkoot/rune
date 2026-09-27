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
| [`BoolArraySlice`](../generated/basis/str/BoolArraySlice.md) | done | done | done | done | done | done |
| [`BoolVector`](../generated/basis/str/BoolVector.md) | done | done | done | done | done | done |
| [`BoolVectorSlice`](../generated/basis/str/BoolVectorSlice.md) | done | done | done | done | done | done |
| [`Byte`](../generated/basis/str/Byte.md) | done | done | done | done | done | done |
| [`Char`](../generated/basis/str/Char.md) | done | done | done | done | done | done |
| [`CharArray`](../generated/basis/str/CharArray.md) | done | done | done | done | done | done |
| [`CharArray2`](../generated/basis/str/CharArray2.md) | done | done | done | done | done | done |
| [`CharArraySlice`](../generated/basis/str/CharArraySlice.md) | done | done | done | done | done | done |
| [`CharVector`](../generated/basis/str/CharVector.md) | done | done | done | done | done | done |
| [`CharVectorSlice`](../generated/basis/str/CharVectorSlice.md) | done | done | done | done | done | done |
| [`CommandLine`](../generated/basis/str/CommandLine.md) | done | done | done | n/a | n/a | done |
| [`Date`](../generated/basis/str/Date.md) | done | done | done | done | done | done |
| [`FixedInt`](../generated/basis/str/Int64.md) | done | done | done | done | done | done |
| [`General`](../generated/basis/str/General.md) | done | done | done | done | done | done |
| [`GenericSock`](../generated/basis/str/GenericSock.md) | done | done | done | n/a | n/a | done |
| [`IEEEReal`](../generated/basis/str/IEEEReal.md) | done | done | done | done | done | done |
| [`INet6Sock`](../generated/basis/str/INet6Sock.md) | done | done | done | done | done | done |
| [`INet6Sock.TCP`](../generated/basis/str/INet6Sock.TCP.md) | done | done | done | n/a | done | done |
| [`INet6Sock.UDP`](../generated/basis/str/INet6Sock.UDP.md) | done | done | done | n/a | n/a | done |
| [`INetSock`](../generated/basis/str/INetSock.md) | done | done | done | done | done | done |
| [`INetSock.TCP`](../generated/basis/str/INetSock.TCP.md) | done | done | done | n/a | done | done |
| [`INetSock.UDP`](../generated/basis/str/INetSock.UDP.md) | done | done | done | n/a | n/a | done |
| [`IO`](../generated/basis/str/IO.md) | done | done | done | done | n/a | done |
| [`Int`](../generated/basis/str/Int.md) | done | done | done | done | done | done |
| [`Int16`](../generated/basis/str/Int16.md) | done | done | done | done | done | done |
| [`Int16Array`](../generated/basis/str/Int16Array.md) | done | done | done | done | done | done |
| [`Int16Array2`](../generated/basis/str/Int16Array2.md) | done | done | done | done | done | done |
| [`Int16ArraySlice`](../generated/basis/str/Int16ArraySlice.md) | done | done | done | done | done | done |
| [`Int16Vector`](../generated/basis/str/Int16Vector.md) | done | done | done | done | done | done |
| [`Int16VectorSlice`](../generated/basis/str/Int16VectorSlice.md) | done | done | done | done | done | done |
| [`Int32`](../generated/basis/str/Int32.md) | done | done | done | done | done | done |
| [`Int32Array`](../generated/basis/str/Int32Array.md) | done | done | done | done | done | done |
| [`Int32Array2`](../generated/basis/str/Int32Array2.md) | done | done | done | done | done | done |
| [`Int32ArraySlice`](../generated/basis/str/Int32ArraySlice.md) | done | done | done | done | done | done |
| [`Int32Vector`](../generated/basis/str/Int32Vector.md) | done | done | done | done | done | done |
| [`Int32VectorSlice`](../generated/basis/str/Int32VectorSlice.md) | done | done | done | done | done | done |
| [`Int64`](../generated/basis/str/Int64.md) | done | done | done | done | done | done |
| [`Int64Array`](../generated/basis/str/Int64Array.md) | done | done | done | done | done | done |
| [`Int64Array2`](../generated/basis/str/Int64Array2.md) | done | done | done | done | done | done |
| [`Int64ArraySlice`](../generated/basis/str/Int64ArraySlice.md) | done | done | done | done | done | done |
| [`Int64Vector`](../generated/basis/str/Int64Vector.md) | done | done | done | done | done | done |
| [`Int64VectorSlice`](../generated/basis/str/Int64VectorSlice.md) | done | done | done | done | done | done |
| [`Int8`](../generated/basis/str/Int8.md) | done | done | done | done | done | done |
| [`Int8Array`](../generated/basis/str/Int8Array.md) | done | done | done | done | done | done |
| [`Int8Array2`](../generated/basis/str/Int8Array2.md) | done | done | done | done | done | done |
| [`Int8ArraySlice`](../generated/basis/str/Int8ArraySlice.md) | done | done | done | done | done | done |
| [`Int8Vector`](../generated/basis/str/Int8Vector.md) | done | done | done | done | done | done |
| [`Int8VectorSlice`](../generated/basis/str/Int8VectorSlice.md) | done | done | done | done | done | done |
| [`IntArray`](../generated/basis/str/IntArray.md) | done | done | done | done | done | done |
| [`IntArray2`](../generated/basis/str/IntArray2.md) | done | done | done | done | done | done |
| [`IntArraySlice`](../generated/basis/str/IntArraySlice.md) | done | done | done | done | done | done |
| [`IntInf`](../generated/basis/str/IntInf.md) | done | done | done | done | done | done |
| [`IntVector`](../generated/basis/str/IntVector.md) | done | done | done | done | done | done |
| [`IntVectorSlice`](../generated/basis/str/IntVectorSlice.md) | done | done | done | done | done | done |
| [`LargeInt`](../generated/basis/str/IntInf.md) | done | done | done | done | done | done |
| [`LargeIntArray`](../generated/basis/str/LargeIntArray.md) | done | done | done | done | done | done |
| [`LargeIntArray2`](../generated/basis/str/LargeIntArray2.md) | done | done | done | done | done | done |
| [`LargeIntArraySlice`](../generated/basis/str/LargeIntArraySlice.md) | done | done | done | done | done | done |
| [`LargeIntVector`](../generated/basis/str/LargeIntVector.md) | done | done | done | done | done | done |
| [`LargeIntVectorSlice`](../generated/basis/str/LargeIntVectorSlice.md) | done | done | done | done | done | done |
| [`LargeReal`](../generated/basis/str/Real.md) | done | done | done | done | done | done |
| [`LargeReal.Math`](../generated/basis/str/Real.Math.md) | done | done | done | done | done | done |
| [`LargeRealArray`](../generated/basis/str/RealArray.md) | done | done | done | done | done | done |
| [`LargeRealArray2`](../generated/basis/str/RealArray2.md) | done | done | done | done | done | done |
| [`LargeRealArraySlice`](../generated/basis/str/RealArraySlice.md) | done | done | done | done | done | done |
| [`LargeRealVector`](../generated/basis/str/RealVector.md) | done | done | done | done | done | done |
| [`LargeRealVectorSlice`](../generated/basis/str/RealVectorSlice.md) | done | done | done | done | done | done |
| [`LargeWord`](../generated/basis/str/Word.md) | done | done | done | done | done | done |
| [`LargeWordArray`](../generated/basis/str/WordArray.md) | done | done | done | done | done | done |
| [`LargeWordArray2`](../generated/basis/str/WordArray2.md) | done | done | done | done | done | done |
| [`LargeWordArraySlice`](../generated/basis/str/WordArraySlice.md) | done | done | done | done | done | done |
| [`LargeWordVector`](../generated/basis/str/WordVector.md) | done | done | done | done | done | done |
| [`LargeWordVectorSlice`](../generated/basis/str/WordVectorSlice.md) | done | done | done | done | done | done |
| [`List`](../generated/basis/str/List.md) | done | done | done | done | done | done |
| [`ListPair`](../generated/basis/str/ListPair.md) | done | done | done | done | done | done |
| [`Math`](../generated/basis/str/Real.Math.md) | done | done | done | done | done | done |
| [`NetHostDB`](../generated/basis/str/NetHostDB.md) | done | done | done | done | done | done |
| [`NetProtDB`](../generated/basis/str/NetProtDB.md) | done | done | done | done | done | done |
| [`NetServDB`](../generated/basis/str/NetServDB.md) | done | done | done | done | done | done |
| [`OS`](../generated/basis/str/OS.md) | done | done | done | done | done | done |
| [`OS.FileSys`](../generated/basis/str/OS.FileSys.md) | done | done | done | done | done | done |
| [`OS.IO`](../generated/basis/str/OS.IO.md) | done | done | done | done | done | done |
| [`OS.IO.Kind`](../generated/basis/str/OS.IO.Kind.md) | done | done | done | done | done | done |
| [`OS.Path`](../generated/basis/str/OS.Path.md) | done | done | done | done | done | done |
| [`OS.Process`](../generated/basis/str/OS.Process.md) | done | done | done | done | done | done |
| [`Option`](../generated/basis/str/Option.md) | done | done | done | done | done | done |
| [`PackReal32Big`](../generated/basis/str/PackReal32Big.md) | done | done | done | done | done | done |
| [`PackReal32Little`](../generated/basis/str/PackReal32Little.md) | done | done | done | done | done | done |
| [`PackReal64Big`](../generated/basis/str/PackRealBig.md) | done | done | done | done | done | done |
| [`PackReal64Little`](../generated/basis/str/PackRealLittle.md) | done | done | done | done | done | done |
| [`PackRealBig`](../generated/basis/str/PackRealBig.md) | done | done | done | done | done | done |
| [`PackRealLittle`](../generated/basis/str/PackRealLittle.md) | done | done | done | done | done | done |
| [`PackWord16Big`](../generated/basis/str/PackWord16Big.md) | done | done | done | done | done | done |
| [`PackWord16Little`](../generated/basis/str/PackWord16Little.md) | done | done | done | done | done | done |
| [`PackWord32Big`](../generated/basis/str/PackWord32Big.md) | done | done | done | done | done | done |
| [`PackWord32Little`](../generated/basis/str/PackWord32Little.md) | done | done | done | done | done | done |
| [`PackWord64Big`](../generated/basis/str/PackWord64Big.md) | done | done | done | done | done | done |
| [`PackWord64Little`](../generated/basis/str/PackWord64Little.md) | done | done | done | done | done | done |
| [`Position`](../generated/basis/str/Int.md) | done | done | done | done | done | done |
| [`Posix`](../generated/basis/str/Posix.md) | done | done | done | done | done | done |
| [`Posix.Error`](../generated/basis/str/Posix.Error.md) | done | done | done | done | done | done |
| [`Posix.FileSys`](../generated/basis/str/Posix.FileSys.md) | done | done | done | done | done | done |
| [`Posix.FileSys.O`](../generated/basis/str/Posix.FileSys.O.md) | done | done | done | done | done | done |
| [`Posix.FileSys.S`](../generated/basis/str/Posix.FileSys.S.md) | done | done | done | done | done | done |
| [`Posix.FileSys.ST`](../generated/basis/str/Posix.FileSys.ST.md) | done | done | done | done | done | done |
| [`Posix.IO`](../generated/basis/str/Posix.IO.md) | done | done | done | done | done | done |
| [`Posix.IO.FD`](../generated/basis/str/Posix.IO.FD.md) | done | done | done | done | done | done |
| [`Posix.IO.FLock`](../generated/basis/str/Posix.IO.FLock.md) | done | done | done | done | done | done |
| [`Posix.IO.O`](../generated/basis/str/Posix.IO.O.md) | done | done | done | done | done | done |
| [`Posix.ProcEnv`](../generated/basis/str/Posix.ProcEnv.md) | done | done | done | done | done | done |
| [`Posix.Process`](../generated/basis/str/Posix.Process.md) | done | done | done | done | done | done |
| [`Posix.Process.W`](../generated/basis/str/Posix.Process.W.md) | done | done | done | done | done | done |
| [`Posix.Signal`](../generated/basis/str/Posix.Signal.md) | done | done | done | done | done | done |
| [`Posix.SysDB`](../generated/basis/str/Posix.SysDB.md) | done | done | done | done | done | done |
| [`Posix.SysDB.Group`](../generated/basis/str/Posix.SysDB.Group.md) | done | done | done | done | done | done |
| [`Posix.SysDB.Passwd`](../generated/basis/str/Posix.SysDB.Passwd.md) | done | done | done | done | done | done |
| [`Posix.TTY`](../generated/basis/str/Posix.TTY.md) | done | done | done | done | done | done |
| [`Posix.TTY.C`](../generated/basis/str/Posix.TTY.C.md) | done | done | done | done | done | done |
| [`Posix.TTY.CF`](../generated/basis/str/Posix.TTY.CF.md) | done | done | done | done | done | done |
| [`Posix.TTY.I`](../generated/basis/str/Posix.TTY.I.md) | done | done | done | done | done | done |
| [`Posix.TTY.L`](../generated/basis/str/Posix.TTY.L.md) | done | done | done | done | done | done |
| [`Posix.TTY.O`](../generated/basis/str/Posix.TTY.O.md) | done | done | done | done | done | done |
| [`Posix.TTY.TC`](../generated/basis/str/Posix.TTY.TC.md) | done | done | done | done | done | done |
| [`Posix.TTY.V`](../generated/basis/str/Posix.TTY.V.md) | done | done | done | done | done | done |
| [`Real`](../generated/basis/str/Real.md) | done | done | done | done | done | done |
| [`Real.Math`](../generated/basis/str/Real.Math.md) | done | done | done | done | done | done |
| [`Real32`](../generated/basis/str/Real32.md) | done | done | done | done | done | done |
| [`Real32.Math`](../generated/basis/str/Real32.Math.md) | done | done | done | done | done | done |
| [`Real32Array`](../generated/basis/str/Real32Array.md) | done | done | done | done | done | done |
| [`Real32Array2`](../generated/basis/str/Real32Array2.md) | done | done | done | done | done | done |
| [`Real32ArraySlice`](../generated/basis/str/Real32ArraySlice.md) | done | done | done | done | done | done |
| [`Real32Vector`](../generated/basis/str/Real32Vector.md) | done | done | done | done | done | done |
| [`Real32VectorSlice`](../generated/basis/str/Real32VectorSlice.md) | done | done | done | done | done | done |
| [`Real64`](../generated/basis/str/Real.md) | done | done | done | done | done | done |
| [`Real64.Math`](../generated/basis/str/Real.Math.md) | done | done | done | done | done | done |
| [`Real64Array`](../generated/basis/str/RealArray.md) | done | done | done | done | done | done |
| [`Real64Array2`](../generated/basis/str/RealArray2.md) | done | done | done | done | done | done |
| [`Real64ArraySlice`](../generated/basis/str/RealArraySlice.md) | done | done | done | done | done | done |
| [`Real64Vector`](../generated/basis/str/RealVector.md) | done | done | done | done | done | done |
| [`Real64VectorSlice`](../generated/basis/str/RealVectorSlice.md) | done | done | done | done | done | done |
| [`RealArray`](../generated/basis/str/RealArray.md) | done | done | done | done | done | done |
| [`RealArray2`](../generated/basis/str/RealArray2.md) | done | done | done | done | done | done |
| [`RealArraySlice`](../generated/basis/str/RealArraySlice.md) | done | done | done | done | done | done |
| [`RealVector`](../generated/basis/str/RealVector.md) | done | done | done | done | done | done |
| [`RealVectorSlice`](../generated/basis/str/RealVectorSlice.md) | done | done | done | done | done | done |
| [`Runtime`](../generated/basis/str/Runtime.md) | done | done | done | done | done | done |
| [`SML90`](../generated/basis/str/SML90.md) | done | done | done | done | done | done |
| [`Socket`](../generated/basis/str/Socket.md) | done | done | done | done | done | done |
| [`Socket.AF`](../generated/basis/str/Socket.AF.md) | done | done | done | done | done | done |
| [`Socket.Ctl`](../generated/basis/str/Socket.Ctl.md) | done | done | done | done | done | done |
| [`Socket.SOCK`](../generated/basis/str/Socket.SOCK.md) | done | done | done | done | done | done |
| [`String`](../generated/basis/str/String.md) | done | done | done | done | done | done |
| [`StringCvt`](../generated/basis/str/StringCvt.md) | done | done | done | done | done | done |
| [`Substring`](../generated/basis/str/Substring.md) | done | done | done | done | done | done |
| [`SysWord`](../generated/basis/str/Word.md) | done | done | done | done | done | done |
| [`Text`](../generated/basis/str/Text.md) | done | done | done | done | done | done |
| [`TextIO`](../generated/basis/str/TextIO.md) | done | done | done | done | done | done |
| [`TextIO.StreamIO`](../generated/basis/str/TextIO.StreamIO.md) | done | done | done | done | done | done |
| [`TextPrimIO`](../generated/basis/str/TextPrimIO.md) | done | done | done | done | done | done |
| [`Time`](../generated/basis/str/Time.md) | done | done | done | done | done | done |
| [`Timer`](../generated/basis/str/Timer.md) | done | done | done | done | done | done |
| [`Unix`](../generated/basis/str/Unix.md) | done | done | done | done | done | done |
| [`UnixSock`](../generated/basis/str/UnixSock.md) | done | done | done | done | done | done |
| [`UnixSock.DGrm`](../generated/basis/str/UnixSock.DGrm.md) | done | done | done | done | done | done |
| [`UnixSock.Strm`](../generated/basis/str/UnixSock.Strm.md) | done | done | done | done | done | done |
| [`Vector`](../generated/basis/str/Vector.md) | done | done | done | done | done | done |
| [`VectorSlice`](../generated/basis/str/VectorSlice.md) | done | done | done | done | done | done |
| [`WideChar`](../generated/basis/str/WideChar.md) | done | done | done | done | done | done |
| [`WideCharArray`](../generated/basis/str/WideCharArray.md) | done | done | done | done | done | done |
| [`WideCharArray2`](../generated/basis/str/WideCharArray2.md) | done | done | done | done | done | done |
| [`WideCharArraySlice`](../generated/basis/str/WideCharArraySlice.md) | done | done | done | done | done | done |
| [`WideCharVector`](../generated/basis/str/WideCharVector.md) | done | done | done | done | done | done |
| [`WideCharVectorSlice`](../generated/basis/str/WideCharVectorSlice.md) | done | done | done | done | done | done |
| [`WideString`](../generated/basis/str/WideString.md) | done | done | done | done | done | done |
| [`WideSubstring`](../generated/basis/str/WideSubstring.md) | done | done | done | done | done | done |
| [`WideText`](../generated/basis/str/WideText.md) | done | done | done | done | done | done |
| [`WideTextIO`](../generated/basis/str/WideTextIO.md) | done | done | done | done | done | done |
| [`WideTextIO.StreamIO`](../generated/basis/str/WideTextIO.StreamIO.md) | done | done | done | done | done | done |
| [`WideTextPrimIO`](../generated/basis/str/WideTextPrimIO.md) | done | done | done | done | done | done |
| [`Windows`](../generated/basis/str/Windows.md) | done | done | done | done | done | done |
| [`Windows.Config`](../generated/basis/str/Windows.Config.md) | done | done | done | done | done | done |
| [`Windows.DDE`](../generated/basis/str/Windows.DDE.md) | done | done | done | done | done | done |
| [`Windows.Key`](../generated/basis/str/Windows.Key.md) | done | done | done | done | done | done |
| [`Windows.Reg`](../generated/basis/str/Windows.Reg.md) | done | done | done | done | done | done |
| [`Windows.Status`](../generated/basis/str/Windows.Status.md) | done | done | done | done | done | done |
| [`Word`](../generated/basis/str/Word.md) | done | done | done | done | done | done |
| [`Word16`](../generated/basis/str/Word16.md) | done | done | done | done | done | done |
| [`Word16Array`](../generated/basis/str/Word16Array.md) | done | done | done | done | done | done |
| [`Word16Array2`](../generated/basis/str/Word16Array2.md) | done | done | done | done | done | done |
| [`Word16ArraySlice`](../generated/basis/str/Word16ArraySlice.md) | done | done | done | done | done | done |
| [`Word16Vector`](../generated/basis/str/Word16Vector.md) | done | done | done | done | done | done |
| [`Word16VectorSlice`](../generated/basis/str/Word16VectorSlice.md) | done | done | done | done | done | done |
| [`Word32`](../generated/basis/str/Word32.md) | done | done | done | done | done | done |
| [`Word32Array`](../generated/basis/str/Word32Array.md) | done | done | done | done | done | done |
| [`Word32Array2`](../generated/basis/str/Word32Array2.md) | done | done | done | done | done | done |
| [`Word32ArraySlice`](../generated/basis/str/Word32ArraySlice.md) | done | done | done | done | done | done |
| [`Word32Vector`](../generated/basis/str/Word32Vector.md) | done | done | done | done | done | done |
| [`Word32VectorSlice`](../generated/basis/str/Word32VectorSlice.md) | done | done | done | done | done | done |
| [`Word64`](../generated/basis/str/Word64.md) | done | done | done | done | done | done |
| [`Word64Array`](../generated/basis/str/Word64Array.md) | done | done | done | done | done | done |
| [`Word64Array2`](../generated/basis/str/Word64Array2.md) | done | done | done | done | done | done |
| [`Word64ArraySlice`](../generated/basis/str/Word64ArraySlice.md) | done | done | done | done | done | done |
| [`Word64Vector`](../generated/basis/str/Word64Vector.md) | done | done | done | done | done | done |
| [`Word64VectorSlice`](../generated/basis/str/Word64VectorSlice.md) | done | done | done | done | done | done |
| [`Word8`](../generated/basis/str/Word8.md) | done | done | done | done | done | done |
| [`Word8Array`](../generated/basis/str/Word8Array.md) | done | done | done | done | done | done |
| [`Word8Array2`](../generated/basis/str/Word8Array2.md) | done | done | done | done | done | done |
| [`Word8ArraySlice`](../generated/basis/str/Word8ArraySlice.md) | done | done | done | done | done | done |
| [`Word8Vector`](../generated/basis/str/Word8Vector.md) | done | done | done | done | done | done |
| [`Word8VectorSlice`](../generated/basis/str/Word8VectorSlice.md) | done | done | done | done | done | done |
| [`WordArray`](../generated/basis/str/WordArray.md) | done | done | done | done | done | done |
| [`WordArray2`](../generated/basis/str/WordArray2.md) | done | done | done | done | done | done |
| [`WordArraySlice`](../generated/basis/str/WordArraySlice.md) | done | done | done | done | done | done |
| [`WordVector`](../generated/basis/str/WordVector.md) | done | done | done | done | done | done |
| [`WordVectorSlice`](../generated/basis/str/WordVectorSlice.md) | done | done | done | done | done | done |

### Signatures

| Module | Documented | Generated docs | Basis spec docs | Examples | Laws | Tests |
| --- | --- | --- | --- | --- | --- | --- |
| [`ARRAY`](../generated/basis/sig/ARRAY.md) | done | done | done | done | done | done |
| [`ARRAY2`](../generated/basis/sig/ARRAY2.md) | done | done | done | done | done | done |
| [`ARRAY_SLICE`](../generated/basis/sig/ARRAY_SLICE.md) | done | done | done | done | done | done |
| [`BIN_IO`](../generated/basis/sig/BIN_IO.md) | done | done | done | done | done | done |
| [`BIT_FLAGS`](../generated/basis/sig/BIT_FLAGS.md) | done | done | done | done | done | done |
| [`BOOL`](../generated/basis/sig/BOOL.md) | done | done | done | done | done | done |
| [`BYTE`](../generated/basis/sig/BYTE.md) | done | done | done | done | done | done |
| [`CHAR`](../generated/basis/sig/CHAR.md) | done | done | done | done | done | done |
| [`COMMAND_LINE`](../generated/basis/sig/COMMAND_LINE.md) | done | done | done | done | done | done |
| [`DATE`](../generated/basis/sig/DATE.md) | done | done | done | done | done | done |
| [`GENERAL`](../generated/basis/sig/GENERAL.md) | done | done | done | done | done | done |
| [`GENERIC_SOCK`](../generated/basis/sig/GENERIC_SOCK.md) | done | done | done | done | done | done |
| [`IEEE_REAL`](../generated/basis/sig/IEEE_REAL.md) | done | done | done | done | done | done |
| [`IMPERATIVE_IO`](../generated/basis/sig/IMPERATIVE_IO.md) | done | done | done | done | done | done |
| [`INET6_SOCK`](../generated/basis/sig/INET6_SOCK.md) | done | done | done | done | done | done |
| [`INET_SOCK`](../generated/basis/sig/INET_SOCK.md) | done | done | done | done | done | done |
| [`INTEGER`](../generated/basis/sig/INTEGER.md) | done | done | done | done | done | done |
| [`INT_INF`](../generated/basis/sig/INT_INF.md) | done | done | done | done | done | done |
| [`IO`](../generated/basis/sig/IO.md) | done | done | done | done | done | done |
| [`LIST`](../generated/basis/sig/LIST.md) | done | done | done | done | done | done |
| [`LIST_PAIR`](../generated/basis/sig/LIST_PAIR.md) | done | done | done | done | done | done |
| [`MATH`](../generated/basis/sig/MATH.md) | done | done | done | done | done | done |
| [`MONO_ARRAY`](../generated/basis/sig/MONO_ARRAY.md) | done | done | done | done | done | done |
| [`MONO_ARRAY2`](../generated/basis/sig/MONO_ARRAY2.md) | done | done | done | done | done | done |
| [`MONO_ARRAY_SLICE`](../generated/basis/sig/MONO_ARRAY_SLICE.md) | done | done | done | done | done | done |
| [`MONO_VECTOR`](../generated/basis/sig/MONO_VECTOR.md) | done | done | done | done | done | done |
| [`MONO_VECTOR_EQ`](../generated/basis/sig/MONO_VECTOR_EQ.md) | done | done | done | done | done | done |
| [`MONO_VECTOR_SLICE`](../generated/basis/sig/MONO_VECTOR_SLICE.md) | done | done | done | done | done | done |
| [`NET_HOST_DB`](../generated/basis/sig/NET_HOST_DB.md) | done | done | done | done | done | done |
| [`NET_PROT_DB`](../generated/basis/sig/NET_PROT_DB.md) | done | done | done | done | done | done |
| [`NET_SERV_DB`](../generated/basis/sig/NET_SERV_DB.md) | done | done | done | done | done | done |
| [`OPTION`](../generated/basis/sig/OPTION.md) | done | done | done | done | done | done |
| [`OS`](../generated/basis/sig/OS.md) | done | done | done | done | done | done |
| [`OS_FILE_SYS`](../generated/basis/sig/OS_FILE_SYS.md) | done | done | done | done | done | done |
| [`OS_IO`](../generated/basis/sig/OS_IO.md) | done | done | done | done | done | done |
| [`OS_PATH`](../generated/basis/sig/OS_PATH.md) | done | done | done | done | done | done |
| [`OS_PROCESS`](../generated/basis/sig/OS_PROCESS.md) | done | done | done | done | done | done |
| [`PACK_REAL`](../generated/basis/sig/PACK_REAL.md) | done | done | done | done | done | done |
| [`PACK_WORD`](../generated/basis/sig/PACK_WORD.md) | done | done | done | done | done | done |
| [`POSIX`](../generated/basis/sig/POSIX.md) | done | done | done | done | done | done |
| [`POSIX_ERROR`](../generated/basis/sig/POSIX_ERROR.md) | done | done | done | done | done | done |
| [`POSIX_FILE_SYS`](../generated/basis/sig/POSIX_FILE_SYS.md) | done | done | done | done | done | done |
| [`POSIX_IO`](../generated/basis/sig/POSIX_IO.md) | done | done | done | done | done | done |
| [`POSIX_PROCESS`](../generated/basis/sig/POSIX_PROCESS.md) | done | done | done | done | done | done |
| [`POSIX_PROC_ENV`](../generated/basis/sig/POSIX_PROC_ENV.md) | done | done | done | done | done | done |
| [`POSIX_SIGNAL`](../generated/basis/sig/POSIX_SIGNAL.md) | done | done | done | done | done | done |
| [`POSIX_SYS_DB`](../generated/basis/sig/POSIX_SYS_DB.md) | done | done | done | done | done | done |
| [`POSIX_TTY`](../generated/basis/sig/POSIX_TTY.md) | done | done | done | done | done | done |
| [`PRIM_IO`](../generated/basis/sig/PRIM_IO.md) | done | done | done | done | done | done |
| [`REAL`](../generated/basis/sig/REAL.md) | done | done | done | done | done | done |
| [`RUNTIME`](../generated/basis/sig/RUNTIME.md) | done | done | done | done | done | done |
| [`SML90`](../generated/basis/sig/SML90.md) | done | done | done | done | done | done |
| [`SOCKET`](../generated/basis/sig/SOCKET.md) | done | done | done | done | done | done |
| [`STREAM_IO`](../generated/basis/sig/STREAM_IO.md) | done | done | done | done | done | done |
| [`STRING`](../generated/basis/sig/STRING.md) | done | done | done | done | done | done |
| [`STRING_CVT`](../generated/basis/sig/STRING_CVT.md) | done | done | done | done | done | done |
| [`SUBSTRING`](../generated/basis/sig/SUBSTRING.md) | done | done | done | done | done | done |
| [`TEXT`](../generated/basis/sig/TEXT.md) | done | done | done | done | done | done |
| [`TEXT_IO`](../generated/basis/sig/TEXT_IO.md) | done | done | done | done | done | done |
| [`TEXT_STREAM_IO`](../generated/basis/sig/TEXT_STREAM_IO.md) | done | done | done | done | done | done |
| [`TIME`](../generated/basis/sig/TIME.md) | done | done | done | done | done | done |
| [`TIMER`](../generated/basis/sig/TIMER.md) | done | done | done | done | done | done |
| [`UNIX`](../generated/basis/sig/UNIX.md) | done | done | done | done | done | done |
| [`UNIX_SOCK`](../generated/basis/sig/UNIX_SOCK.md) | done | done | done | done | done | done |
| [`VECTOR`](../generated/basis/sig/VECTOR.md) | done | done | done | done | done | done |
| [`VECTOR_SLICE`](../generated/basis/sig/VECTOR_SLICE.md) | done | done | done | done | done | done |
| [`WINDOWS`](../generated/basis/sig/WINDOWS.md) | done | done | done | done | done | done |
| [`WORD`](../generated/basis/sig/WORD.md) | done | done | done | done | done | done |

### Functors

| Module | Documented | Generated docs | Basis spec docs | Examples | Laws | Tests |
| --- | --- | --- | --- | --- | --- | --- |
| [`ImperativeIO`](../generated/basis/fun/ImperativeIO.md) | done | done | done | done | done | done |
| [`PrimIO`](../generated/basis/fun/PrimIO.md) | done | done | done | done | done | done |
| [`StreamIO`](../generated/basis/fun/StreamIO.md) | done | done | done | done | done | done |
