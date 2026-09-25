# MLton 20241230: `String.fromCString` returns `SOME ""` instead of `NONE`

## Status: reported upstream, unfixed

Filed as [MLton/mlton#658](https://github.com/MLton/mlton/issues/658) on
2026-09-25. No matching report existed before that (searched `fromCString`,
`escape`, `invalid escape`, `scanString`). Inspection of
`basis-library/text/string.sml` and `basis-library/util/reader.sml` on the
current `master` branch shows the same code that causes the bug below is
still present, so it is not fixed either.

## Summary

* **The trigger:** `String.fromCString s` where the very first character of
  `s` cannot be converted (an illegal escape sequence such as `\q`, a bare
  trailing backslash, or a non-printing character such as `\n`).
* **Required behavior:** the [Basis `STRING` specification](https://smlfamily.github.io/Basis/string.html#SIG:STRING.fromCString:VAL)
  gives `fromCString` the same failure rule as `fromString`: "returns `NONE`
  ... if `s` cannot be scanned completely, i.e., if it is empty or if it
  contains an improper escape sequence and no characters precede the
  improper escape sequence". `Char.fromCString` and `String.fromString`
  already implement this correctly; only `String.fromCString` returns
  `SOME ""` in this case.

## Environment

* **MLton:** 20241230, the official binary release.
* **System:** Linux x86-64.
* **Basis Library: MLton's own.** The program is standalone,
  `mlton bug.sml`, with no `.mlb` file and nothing of Rune involved.

## The program

`bug.sml`:

```sml
fun showFromString label s =
  print (label ^ " " ^ String.toString s ^ " = " ^
         (case String.fromString s of
            NONE => "NONE"
          | SOME r => "SOME \"" ^ String.toString r ^ "\"") ^ "\n")

fun showChar label s =
  print (label ^ " " ^ String.toString s ^ " = " ^
         (case Char.fromCString s of
            NONE => "NONE"
          | SOME c => "SOME #\"" ^ Char.toString c ^ "\"") ^ "\n")

fun show label s =
  print (label ^ " " ^ String.toString s ^ " = " ^
         (case String.fromCString s of
            NONE => "NONE"
          | SOME r => "SOME \"" ^ String.toString r ^ "\"") ^ "\n")

val () = showFromString "String.fromString " "\\q"
val () = showChar        "Char.fromCString  " "\\q"
val () = show            "String.fromCString" "\\q"
val () = show            "String.fromCString" "\\"
val () = show            "String.fromCString" "\n"
val () = show            "String.fromCString" "abc\\qdef"
```

```
$ mlton bug.sml && ./bug
String.fromString  \q = NONE
Char.fromCString   \q = NONE
String.fromCString \q = SOME ""
String.fromCString \ = SOME ""
String.fromCString \n = SOME ""
String.fromCString abc\qdef = SOME "abc"
```

The last line shows that partial conversion after at least one good
character already works correctly (`"abc\\qdef"` correctly stops at the bad
escape and returns `SOME "abc"`); only the case where *no* character
converts is wrong.

## The cause

`basis-library/text/string.sml` defines:

```sml
fun scanString scanChar reader =
   fn state =>
   Option.map (fn (cs, state) => (implode cs, state))
   (Reader.list (scanChar reader) state)

val fromCString = StringCvt.scanString (scanString Char.scanC)
```

and `basis-library/util/reader.sml`:

```sml
fun list (reader: ('a, 'b) reader): ('a list, 'b) reader =
   fn state =>
   let
      fun loop (state, accum) =
         case reader state of
            NONE => SOME (rev accum, state)
          | SOME (a, state) => loop (state, a :: accum)
   in loop (state, [])
   end
```

`Reader.list` is documented (`basis-library/util/reader.sig`) to "read as
many items as possible (never returns `NONE`)". That is correct for its
other uses, but `scanString` reuses it to build `fromCString`, so a `reader`
that fails on the very first character still produces `SOME ([], state)`,
i.e. `SOME ""`, instead of signalling failure.

`String.fromString` does not have this bug because its `scan` is written by
hand instead of going through `Reader.list`/`scanString`:

```sml
fun scan reader =
   let
      fun loop (state, cs) =
         case Char.scan reader state of
            NONE => SOME (implode (rev cs), Char.formatSequences reader state)
          | SOME (c, state) => loop (state, c :: cs)
      in
      fn state =>
      case reader state of
         NONE => SOME (implode [], state)
       | SOME _ =>
         case Char.scan reader state of
            SOME (c, state) => loop (state, [c])
          | NONE =>
            case Char.formatSequencesOpt reader state of
               SOME ((), state) => SOME (implode [], state)
             | NONE => NONE
      end

val fromString = StringCvt.scanString scan
```

It explicitly tries the first character and only returns `SOME ""` when the
*input itself* is empty (`reader state = NONE`), or when nothing but a
formatting sequence could be scanned. Everywhere else a first-character
failure falls through to `NONE`.

## The fix

Give `fromCString` its own hand-written scan, the `scanC` analogue of
`scan` above, instead of building it from the generic
`Reader.list`-based `scanString`. C-string escapes have no
`\ \`-style formatting sequences, so it is simpler than `scan`:

```sml
fun scanC reader =
   let
      fun loop (state, cs) =
         case Char.scanC reader state of
            NONE => SOME (implode (rev cs), state)
          | SOME (c, state) => loop (state, c :: cs)
   in
      fn state =>
      case Char.scanC reader state of
         NONE => NONE
       | SOME (c, state) => loop (state, [c])
   end

val fromCString = StringCvt.scanString scanC
```

This keeps the existing (correct) partial-conversion behavior — `loop` still
stops at the first bad escape and returns what came before it — and only
changes the empty/all-bad case: the outer `case` now returns `NONE` directly
when even the first character fails, instead of delegating to
`Reader.list`, which cannot distinguish "nothing needed converting" from
"the first conversion failed".

The general-purpose `scanString`/`Reader.list` combinator should probably be
left alone (other callers may rely on its "never fails" contract); the
targeted fix is to stop using it for `fromCString`.

## Relation to Rune

Rune's own Basis Library implements `String.fromCString` independently (not
via a shared `Reader.list`-style combinator; see
[`lib/basis/string.sml`](https://github.com/ruudkoot/rune/blob/e840204151663baf1139c8096b566301e9ced37d/lib/basis/string.sml#L72))
and does not have this bug. Rune's Basis Library suite already covers this
exact case in
[`tests/basis/string.sml`](https://github.com/ruudkoot/rune/blob/e840204151663baf1139c8096b566301e9ced37d/tests/basis/string.sml#L408-L410)
(`String.fromCString/NONE-illegal-escape`, `NONE-newline`,
`NONE-lone-backslash`), and records it as a known `HOST-BUG` for `mlton@*` in
[`tests/basis/deviations.txt`](https://github.com/ruudkoot/rune/blob/e840204151663baf1139c8096b566301e9ced37d/tests/basis/deviations.txt#L66).
`sh tests/basis/run-matrix.sh --configs native:mlton string` against the
pinned `mlton-20241230` reproduces the three failures above and 0 unexplained
ones. (Links are pinned to commit `e840204` of
[ruudkoot/rune](https://github.com/ruudkoot/rune); the repository is public
but not otherwise affiliated with MLton.)

This was first found independently while investigating SML/NJ regression
suite differences in the `rune-corpus-sml97` companion repository
(`packages/smlnj-regressions/95b939d/known-differences.md`, "Invalid C escape
at the start of a string").
