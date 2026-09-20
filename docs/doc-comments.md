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
| `Example:` | anything | code |
| `See also:` | anything | references in backquotes |
| `Area:` | a signature, a functor | the area of the library's overview page that lists it |
| `Status:` | a signature, structure or functor | `required`, `optional` or `extension`; a signature without one is required, a structure without one has the status of its signature |
| `Implements:` | a structure, a functor | the signature it implements, with its `where type`s |
| `Reading:` `Erratum:` `Deviation:` `Implementation:` `Limitation:` | anything | a note: its id in backquotes, then prose. `Reading (the suite differs):` is the one modifier |
| `Pinned by:` | directly after a note | labels (or globs of labels) of the checks of `tests/basis` that pin the note |

The notes record how the library reads its specification: a **reading** of
text that is silent, ambiguous or contradictory; an **erratum** of the
specification; a **deviation** of Rune from it; a choice the specification
leaves to the **implementation**, with its value; a **limitation**. A note's
id is `scope/slug` (`Char.fromString/unescaped-double-quote`,
`LIST/list-spec`); when one check pins the note, its label is the id.

## Trying it

```
bin/runedoc --lint FILE...      # what is wrong with the comments of the files
bin/runedoc --dump-ir FILE...   # what the generator makes of them
```

`bin/runedoc-mlton` does the same at once; `bin/runedoc` runs on the VM.
