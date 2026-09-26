# Writing doc comments

The reference documentation of a library is generated from its sources by
`runedoc` ([plans/docgen.md](plans/docgen.md)). This page is for whoever
writes the comments: where a comment must stand to document something, and
the small language it is written in. `make check-docs` runs
`runedoc --lint` over `lib/basis` and `src`, so a comment that breaks these
rules fails the build.

## Where a comment stands

The signature is what is documented. A comment documents

* **the item directly below it**, when it is on lines of its own and no blank
  line separates them: a `signature`, `structure` or `functor`, a
  specification (also one after `and`), a constructor on its own line, a
  field of a record type;
* **the item that ends on its line**, when it follows code: a constructor, a
  field (the comma after it does not matter), a specification. Of several
  items that end there it is the innermost, so a comment after the last
  constructor of a datatype documents that constructor; to document the
  datatype, write above it.

```sml
(* Shapes. This comment documents the datatype. *)
datatype shape =
    Circle of {centre : real * real,   (* where it is *)
               radius : real}          (* this one documents Circle, not radius:
                                          the brace ends the constructor *)
  | Square of real                     (* the length of a side *)
```

Inside a signature two more kinds of comment mean something:

* a comment that starts with `----` is a **section heading**:
  `(* ---- Taking lists apart ---- *)`;
* a comment on lines of its own that a blank line (or `end`) follows is
  **prose** of the section it stands in.

Anything else in a signature is an error: a comment after something that
cannot be documented (an argument type, an `=`), two comments stacked above
one item. No comment is dropped silently. In structure bodies only the
comment above a `structure` binding is read; everything else is yours.

## The language

Plain prose is always correct. A comment is paragraphs separated by blank
lines.

| You write | It means |
|---|---|
| `` `code` `` | code; it may wrap over a line end. A span that is one (long) identifier is a reference and becomes a link |
| a paragraph indented by four, after a blank line | a block of code |
| lines that start with `- `, after a blank line | a list |
| `https://...` | a link |
| anything else | text, as it stands: `*`, `_`, `<`, `[`, `\|`, `'a` and quotation marks are not markup |

`Subject: explanation` at the start of a paragraph is ordinary prose, unless
the subject is one of the reserved words below.

### Usage heads

Begin the description of a function with the function applied to arguments:

```sml
(* `take (l, i)` is the list of the first `i` elements of `l`. *)
val take : 'a list * int -> 'a list

(* `l @ m` is the elements of `l` followed by those of `m`. *)
val @ : 'a list * 'a list -> 'a list

(* `joinDirFile {dir, file}` ... : fields may be named as in a pattern. *)
```

The head is parsed by the compiler's parser, under the fixity of the top
level (so `@` is applied infix and `<<` is not: `` `<< (w, n)` ``), and checked
against the type: the arity of tuples, the labels of records, the number of
curried arguments (an argument beyond the arrows is accepted where the result
is a type constructor, which may abbreviate a function type, as for
`scan getc strm`). The names of the arguments are the names the rest of the
comment uses for them. The first paragraph is also the summary that index
pages show, so keep it to a sentence or two.

One comment can document a run of values: those that follow the first with
no blank line and no comment of their own, provided the first paragraph has a
head for each (`` `toLarge i` and `fromLarge i` convert ... ``).

### Reserved paragraphs

A paragraph that starts with one of these words and a colon is checked. The
set is closed and case-sensitive.

| Paragraph | In the comment of | What follows the colon |
|---|---|---|
| `Raises:` | a value | the exception in backquotes, then when it is raised; one paragraph per exception |
| `Law:` | a value | an equation, in backquotes |
| `Complexity:` | a value | prose |
| `Example:` | anything | code; a piece that is an equation, `e = v`, is run (below) |
| `See also:` | anything | references in backquotes |
| `Area:` | a signature, a functor, a structure that no signature describes | the area of the library's overview page that lists it |
| `Status:` | a signature, structure or functor | `required`, `optional` or `extension`; a signature without one is required, a structure without one has the status of its signature |
| `Implements:` | a structure, a functor | the signature it implements, with its `where type`s |
| `Reading:` `Erratum:` `Deviation:` `Implementation:` `Limitation:` | anything | a note: its id in backquotes, then prose. `Reading (the suite differs):` is the one modifier |
| `Pinned by:` | directly after a note | labels (or globs of labels) of the checks of `tests/basis` that pin the note |

A structure that no signature of the library describes -- `WideTextIO` matches
none, since the transcription of `TEXT_IO` writes `string` and `char` -- names
its own area, because there is no signature to take it from. Where a signature
does describe the structure, the area is that signature's and the structure's
comment must not name one.

A structure says what it implements in the comment above it, because most
structures of the library are not sealed with their signature:

```sml
(* Int: fixed precision integers ...

   Implements: INTEGER where type int = int *)
structure Int = struct ... end
```

The claim puts `Int` on the page of `INTEGER`, sends `Int.toString` there, and
is written to `docs/generated/basis/claims.tsv`. `tests/basis/check-claims.sh`
(part of `make check-docs`) wants every claim to be backed by a line
`structure C : SPEC_INTEGER = Int` of a `tests/basis/*_sig.sml`, and every such
line to be claimed. `runedoc` also elaborates the library and checks every
claim with the compiler: a structure that does not match what it claims fails
`make docs` with the compiler's message. An ascription in the source is a
claim by itself. A
substructure is claimed above its binding (`structure Path = RunePath` in
`os.sml`). In the body of a structure or a functor, a note in the comment
above a declaration is shown under that member on the signature's page, as
what holds "in `Int`"; the notes of a functor hold for its applications.

The notes record how the library reads its specification: a **reading** of
text that is silent, ambiguous or contradictory; an **erratum** of the
specification; a **deviation** of Rune from it; a choice the specification
leaves to the **implementation**, with its value; a **limitation**. A note's
id is `scope/slug` (`Char.fromString/unescaped-double-quote`,
`LIST/list-spec`); when one check pins the note, its label is the id, and
otherwise `Pinned by:` lists the labels, which must exist in the suite. An id
names one note. The notes are collected in
`docs/generated/basis/readings.md` and exported as `notes.tsv`, which
`tests/basis/check-notes.sh` (part of `make check-docs`) holds against
`tests/basis/deviations.txt`: a check that fails on Rune because Rune reads
the specification differently needs a `Reading (the suite differs):` that the
check pins (and the other way round), and what a host reads differently in a
signature that is documented in full needs a `Reading:` of that member.
`coverage.md` lists the deviations and limitations that no check pins.

## Examples that run

A piece of code in an `Example:` paragraph that is an equation, `e = v`, is a
claim, and it is checked twice. When the documentation is made it is
elaborated against the library, so that an example that is no Standard ML,
names what is not there or compares what has no equality is an error at its
comment. And `runedoc --examples DIR` writes the examples of each signature
as a program, which `make test-basis` compiles and runs
(`tests/basis/run-examples.sh`): an example that is false, or raises an
exception, fails it.

The members of the signature are in scope as they are inside a structure that
implements it: the example is read under `open S`, where `S` is the structure
with the shortest name among those the specification requires (`Int` for
`INTEGER`, `String` for `STRING`), and for a member of a substructure under
`open S.Sub` as well. Name any other structure in full: `Word8.toIntX 0wxFF =
~1`. The fixity is that of the top level, so `Real.== (x, y)` and not `x ==
y`. What holds for every argument is a `Law:`, which is not run; an example
has no free variables. Code that is no equation is only shown, so a value of
a type without equality is compared through its text: `Real.fmt (StringCvt.FIX
(SOME 1)) (Math.sqrt 4.0) = "2.0"`.

An example says what this library does, so `Int.precision = SOME 64` is a
fine example; the programs are not tried on other implementations.

## Annotations

What is said about a member from outside the library's sources comes in a
file, `runedoc --annotations FILE`:

```
# a comment
@title Other implementations
@intro what the test suite finds other implementations to do differently.
Bool.scan/case-* | MLton | scan is case-sensitive
```

A line is `glob | whom it is about | text`; the text is plain and may hold a
bar. The glob is that of a check's label, `Structure.member/case`, with `*`,
`?` and `[...]` as the shell has them, and the text is shown, folded, under
every member that has such a check: `*Vector.update/[Sm]*` under `update` of
`VECTOR` and of `MONO_VECTOR`. A constructor counts for its datatype, and a
label `Structure:SIG/case` for the signature as a whole. A check whose label
is computed (`"Int.scan/" ^ name`) counts by the beginning that is written
out. One of which only the member is known counts when no other check has
the label, and then only with reason: the glob writes the structure and the
member out, or the words of its case begin a part of a string constant of
the test's file (`"whitespace-tab"` for `*.scan/DEC-whitespace-*`) and the
text, where it speaks of `X.member` by name, speaks of that structure. A glob that finds no check of a documented member is an error,
so an annotation does not outlive the check it is about; the exception is a
member with a check whose label is computed in full, which may be any label. `@title` names the block
and `@intro` describes it on the page "How to read these pages".

For the Basis Library the file is `tests/basis/annotations.txt`, which
`tests/basis/gen-annotations.sh` makes from the host lines of
`tests/basis/deviations.txt`. It is committed and `make check-docs` checks
that it is up to date, so `runedoc` never reads `deviations.txt`.

## The ratchet

`lib/basis/DOCUMENTED` lists the signatures that are documented in full. For
them `runedoc` makes an error of what it only counts elsewhere
(`docs/generated/basis/coverage.md`): an entry without a comment (one that is
documented together with the entry before it counts as documented), a
function without a usage head, a first paragraph of more than 160 characters
(it is the summary of the index pages: say the rest in a second paragraph), a
qualified name in backquotes that leads nowhere, a `Raises:` whose exception
is not documented anywhere (the exceptions of the top level are `General`'s). Add a signature to the list
in the commit that finishes its documentation.

## Trying it

```
bin/runedoc --lint FILE...      # what is wrong with the comments of the files
bin/runedoc --page FILE...      # the pages of the signatures of the files, on the standard output
bin/runedoc --dump-ir FILE...   # what the generator makes of them, before any rendering
bin/runedoc --library basis --examples DIR   # the examples that are equations, as programs
sh tests/basis/run-examples.sh  # write them, compile them and run them
make docs                       # write docs/generated/basis; commit the result
```

`bin/runedoc-mlton` does the same at once; `bin/runedoc` runs on the VM.
