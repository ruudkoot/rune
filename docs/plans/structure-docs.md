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

## Recommendation

Do it. The library has 210 structures and 65 signatures, and a reader looking
up `Word8Vector.sub` should not have to read `MONO_VECTOR` and work out which
of nineteen element types applies. The one thing to settle first is step 3's
warning: it will find notes that are on a signature and should not be, and
those are the ones worth reading before the pages exist at all.
