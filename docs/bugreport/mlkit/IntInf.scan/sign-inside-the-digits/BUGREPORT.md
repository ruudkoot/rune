# MLKit 4.7.23: `IntInf.scan` reads a sign inside the digits (`"1~2"` is 98, `"~~5"` a malformed number)

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ and Poly/ML stop at the second sign.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same `basis/IntInf.sml` as 4.7.23 (the files are identical), so
the bug is not fixed there either.

## Summary

* **The trigger:** `IntInf.scan` (any radix) or `IntInf.fromString`
  (`LargeInt.scan`, `LargeInt.fromString`) on a string in which a sign
  (`+`, `-` or `~`) follows the digits of the number, or follows its sign.
* **What goes wrong:**
  * a sign after the digits starts another group of digits, which is added
    with its sign: `"1~2"` and `"1-2"` are read as 98 (= 1 * 100 - 2),
    `"1+2"` as 102, `"12~34"` as 11966, and the whole string is consumed;
  * a second sign after the first is accepted: `"++5"` is 5, and `"~~5"`,
    `"~-1"`, `"+-5"` and `"-~5"` give a *malformed* `IntInf.int` (for
    `"~~5"`: `sign` is `~1`, but it is equal neither to `~5` nor to `5`),
    on which `IntInf.toString` never returns (the program allocates without
    bound; under a limit of its memory, `ulimit -v`, it ends with a
    segmentation fault when an allocation fails).
* **Required behaviour:** the
  [Basis `INTEGER` specification](https://smlfamily.github.io/Basis/integer.html),
  which `INT_INF` includes, gives the format of `scan StringCvt.DEC` as
  `[+~-]?[0-9]+` (and the same sign, once, for the other radices), and
  `scan` returns the number "parsed from a prefix of the character stream".
  So `"1~2"` is `SOME (1, "~2")`, and `"++5"`, `"~~5"` and `"~-1"` have no
  prefix in the format: `NONE`. `fromString` "is equivalent to
  `StringCvt.scanString (scan StringCvt.DEC)`".

## Environment

* **MLKit:** v4.7.23 (`MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00)
  [X64 Backend]`), the official binary release `mlkit-bin-dist-linux.tgz`.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is standalone, built as
  `bug.mlb` (`$(SML_LIB)/basis/basis.mlb` and `bug.sml`) with
  `mlkit -o bug bug.mlb`.

## The program

`bug.sml`:

```sml
(* IntInf.scan (and fromString, which is scanString (scan DEC)) take a sign
   that follows the digits, or the sign, for the sign of a further group of
   digits.  The format is [+~-]?[0-9]+ (DEC): "1~2" is 1 followed by "~2",
   and "~~5", "~-1" and "++5" are no numbers at all (NONE). *)
fun reader s i = if i < String.size s then SOME (String.sub (s, i), i + 1) else NONE
fun say s = (print s; TextIO.flushOut TextIO.stdOut)
fun scan s =
  case IntInf.scan StringCvt.DEC (reader s) 0 of
    NONE => "NONE"
  | SOME (n, i) => "SOME (" ^ IntInf.toString n ^ ", \"" ^ String.extract (s, i, NONE) ^ "\")"
val () = List.app (fn s => say ("IntInf.scan DEC " ^ s ^ " = " ^ scan s ^ "\n"))
                  ["1~2", "1-2", "1+2", "12~34", "123456789+1", "++5"]
val () = say ("IntInf.fromString \"1~2\" = "
              ^ (case IntInf.fromString "1~2" of NONE => "NONE" | SOME n => "SOME " ^ IntInf.toString n) ^ "\n")
(* A second sign right after the first gives a value that is not a number:
   it is negative, but neither ~5 nor 5, and IntInf.toString does not return
   on it. *)
val () =
  case IntInf.fromString "~~5" of
    NONE => say "IntInf.fromString \"~~5\" = NONE\n"
  | SOME x =>
      (say ("IntInf.fromString \"~~5\" = SOME x: sign x = " ^ Int.toString (IntInf.sign x)
            ^ ", x = ~5: " ^ Bool.toString (x = IntInf.fromInt ~5)
            ^ ", x = 5: " ^ Bool.toString (x = IntInf.fromInt 5) ^ "\n");
       say "IntInf.toString x = ";
       say (IntInf.toString x ^ "\n"))
```

```
$ mlkit -o bug bug.mlb
[reading source file:	bug.sml]
[wrote X64 code file:	MLB/RI_GC/bug.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	bug]
$ timeout 10 ./bug; echo "exit status $?"
IntInf.scan DEC 1~2 = SOME (98, "")
IntInf.scan DEC 1-2 = SOME (98, "")
IntInf.scan DEC 1+2 = SOME (102, "")
IntInf.scan DEC 12~34 = SOME (11966, "")
IntInf.scan DEC 123456789+1 = SOME (12345678901, "")
IntInf.scan DEC ++5 = SOME (5, "")
IntInf.fromString "1~2" = SOME 98
IntInf.fromString "~~5" = SOME x: sign x = ~1, x = ~5: false, x = 5: false
IntInf.toString x = exit status 124
```

The program was stopped by `timeout` in the last `IntInf.toString`; its
resident size, sampled with `ps` in two runs, was about 0.9 GB after 5
seconds and 1.6-1.7 GB after 9 seconds. The required output is `SOME (1, "~2")`, `SOME (1, "-2")`,
`SOME (1, "+2")`, `SOME (12, "~34")`, `SOME (123456789, "+1")`, `NONE`,
`SOME 1` and `NONE` for `"~~5"`.

## The cause

`IntInf.scan` (`basis/IntInf.sml`) skips whitespace, reads the sign of the
number and passes the rest to `BigNat.scan`:

```sml
      fun scan' scanFn (getc:(char,'s)reader) (cs:'s) : (intinf * 's) option = let
            val cs' = NumScan.skipWS getc cs
            ...
              case (getc cs')
               of (SOME(#"~", cs'')) => cvt(scanFn getc cs'',zneg)
		| (SOME(#"-", cs'')) => cvt(scanFn getc cs'',zneg)
                | (SOME(#"+", cs'')) => cvt(scanFn getc cs'',posi)
                | (SOME _) => cvt(scanFn getc cs',posi)
```

`BigNat.scan` reads the digits in groups of at most `bound` characters
(9 for `DEC`), each with `NumScan.scanInt`, and goes on with another group
for as long as `scanInt` reads one:

```sml
        fun scan (bound,powers,geti) (getc:(char,'s)reader) (cs:'s) : (bignat*'s) option =
            let
              fun get (l,cs) = if l = bound then NONE
                               else case getc cs of
                                 NONE => NONE
                               | SOME(c,cs') => SOME(c, (l+1,cs'))
              fun loop (acc,cs) =
                    case geti get (0,cs) of
                      NONE => (acc,cs)
                    | SOME(0,(sh,cs')) =>
                        loop(add(muld(acc,Vector.sub(powers,sh)),[]),cs')
                    | SOME(i,(sh,cs')) =>
                        loop(add(muld(acc,Vector.sub(powers,sh)),[i]),cs')
```

But `NumScan.scanInt` reads a *signed* integer: its `scanPrefix` accepts a
sign before the digits of every group:

```sml
    	  in
    	    case (noSkipWS cs)
    	     of NONE => NONE
    	      | (SOME(c, cs')) =>
    		  if (c = plusCode) then getNext(false, cs')
    		  else if (c = minusCode) then getNext(true, cs')
    		  else SOME{neg=false, next=c, rest=cs'}
    	    (* end case *)
    	  end
```

So for `"1~2"` the first group is `1`; the loop then calls `scanInt` at
`"~2"`, which returns ~2 for a group of two characters, and the result is
`1 * 10^2 + ~2 = 98`. For `"~~5"`, `scan'` takes the first `~` and the
first group, `"~5"`, is ~5: the digit list of the result is `[~5]`, a
negative digit (the digits of a `bignat` are meant to lie in
0 .. 2^30 - 1), and `IntInf.toString` does not return on it.

`NumScan.scanInt` is used for nothing but these groups (`scan2`, `scan8`,
`scan10`, `scan16`), and the sign of the number is read by `scan'` before.

## The fix

Let `scanPrefix` read no sign:

```diff
--- a/basis/IntInf.sml
+++ b/basis/IntInf.sml
@@ -119,12 +119,11 @@
     		  | (SOME(c, cs)) => SOME{neg=neg, next=code c, rest=cs}
     		(* end case *))
     	  in
+    	    (* No sign: scanInt reads the groups of digits of a number for
+    	     * BigNat.scan, and IntInf.scan has read the sign of the number. *)
     	    case (noSkipWS cs)
     	     of NONE => NONE
-    	      | (SOME(c, cs')) =>
-    		  if (c = plusCode) then getNext(false, cs')
-    		  else if (c = minusCode) then getNext(true, cs')
-    		  else SOME{neg=false, next=c, rest=cs'}
+    	      | (SOME(c, cs')) => SOME{neg=false, next=c, rest=cs'}
     	    (* end case *)
     	  end
```

(`getNext`, `plusCode` and `minusCode` are then unused and can go.)

**Tested:** with this change applied to a copy of MLKit 4.7.23's library
(`SML_LIB` pointing at the copy), `bug.sml` prints

```
IntInf.scan DEC 1~2 = SOME (1, "~2")
IntInf.scan DEC 1-2 = SOME (1, "-2")
IntInf.scan DEC 1+2 = SOME (1, "+2")
IntInf.scan DEC 12~34 = SOME (12, "~34")
IntInf.scan DEC 123456789+1 = SOME (123456789, "+1")
IntInf.scan DEC ++5 = NONE
IntInf.fromString "1~2" = SOME 1
IntInf.fromString "~~5" = NONE
```

and the Rune test program `intinf_scan` (below) runs to its end, with no
failure left from this bug (the nine failures left are all of `HEX` with a
`0x` prefix, which `IntInf.scan` does not read at all: another bug). Not tried against a build of `master`.
The copy of the library had the fixes of the other reports of this
investigation applied as well (`Word.scan/0w-read-as-hex-prefix`,
`Word.fromLargeInt/Overflow-on-negative`, `IntInf.scan/*`,
`PackWord32Big.subVecX/no-sign-extension`, the `LargeIntVector` fix and
the runtime fix of `Int32.mod/SIGFPE-minInt-by-minus-one`); the Rune
programs were those the matrix compiled, `intn_word16` without its
`constants` section (`Int8.int/not-overloaded`).

## Relation to Rune

Rune's Basis Library suite (Rune at `3d83f11`) checks these formats in
`tests/basis/fn/integer_fn.sml` (`fromString/stops-at-tilde`,
`stops-at-minus`, `stops-at-plus`, line 267-268, and
`fromString/two-tildes`, `plus-minus`, `minus-tilde`, `two-pluses`,
line 274-275) and `tests/basis/fn/integer_scan_fn.sml`
(`scan/DEC-stops-at-second-sign`, line 90, and `scan/DEC-two-signs`,
line 93), run for `IntInf` by `tests/basis/intinf.sml` and
`tests/basis/intinf_scan.sml`. On MLKit:

* `IntInf.fromString/stops-at-tilde`, `stops-at-minus` and `stops-at-plus`
  fail (98, 98 and 102), and so does `IntInf.scan/DEC-stops-at-second-sign`;
* the next check that fails, `IntInf.fromString/two-tildes` (`"~~5"`) in
  `intinf` and `IntInf.scan/DEC-two-signs` (`"~-1"`) in `intinf_scan`,
  prints the malformed number it got with `IntInf.toString`, which does not
  return: `intinf` is stopped at the time limit of 120 s
  (`@load/intinf -- timed out after 120 s`), and `intinf_scan` grows until
  the process is killed (in a rerun here: 12 GB resident after 110 s,
  killed with `SIGKILL`), which the matrix reports as
  `@load/intinf_scan -- did not load`. The matrix now caps an MLKit
  program at 4 GiB of virtual memory (`RUNE_MATRIX_MEMORY`), so that both
  end with a segmentation fault instead.

The failures are explained in `tests/basis/deviations.txt` by

```
native:mlkit@* | IntInf.fromString/stops-at-[mpt][ilu]* | HOST-BUG | a sign after the digits is read as the sign of a further group of digits: "1~2" is 98 and "1+2" is 102, not 1 (IntInf.sml reads every group of digits with NumScan.scanInt, which takes a sign)
native:mlkit@* | IntInf.scan/DEC-stops-at-second-sign | HOST-BUG | a sign after the digits is read as the sign of a further group of digits: "1~2" is SOME (98, ""), not SOME (1, "~2")
native:mlkit@* | @load/intinf | HOST-BUG | fromString "~~5" (two-tildes) is not NONE but a malformed number (a negative digit), and IntInf.toString of it, which the failed check prints, never returns
native:mlkit@* | @load/intinf_scan | HOST-BUG | scan of "~-1" (DEC-two-signs) is not NONE but a malformed number (a negative digit), and IntInf.toString of it, which the failed check prints, never returns but allocates until the process is killed
```

With the fix, `intinf` does not hang there any more, but other failures of
the test, which the hang hides today, come to light (`IntInf.fromInt` and
`toInt` go through `Int32`, `pow`, `andb`/`orb`/`xorb` of negative
numbers, `~>>`), and the program then ends with a segmentation fault in
its section `bitops-laws` (at `IntInf.xorb/model-1`, under a limit of
4 GB of address space). These are not reported here.
