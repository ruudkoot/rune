# MLKit 4.7.23: `IntInf.fromInt` and `IntInf.toInt` raise `Overflow` beyond 32 bits, so `Time` stops at 2^31 seconds (2038-01-19)

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/IntInf.sml` and `basis/Time.sml` are identical
to 4.7.23's.

## Summary

* **The trigger:** `IntInf.fromInt i` (= `LargeInt.fromInt`) for an `int`
  with `|i| >= 2^31`, or `IntInf.toInt` of such a number; and through them
  every `Time` value of 2^31 seconds or more (from 2038-01-19 03:14:08 UTC
  on, and before 1901-12-13 20:45:52 UTC).
* **What goes wrong:** both conversions raise `Overflow`, although `int`
  has 63 bits and `IntInf.int` is unbounded (`Int.toLarge`, which MLKit
  implements separately, converts the same numbers). `Time`, whose
  `time` is a record of 63-bit seconds and microseconds, converts with
  `LargeInt.fromInt` and `LargeInt.toInt`, so `Time.fromSeconds`,
  `fromReal` and the like raise `Time` for such times, while `Time.+` and
  `Time.-` make them without complaint and `Time.toSeconds`,
  `toMicroseconds`, `toString` and `fmt` of the result raise `Overflow`.
  `Date.toTime` of a date after 2038-01-19 03:14:07 UTC raises `Time`.
* **Required behaviour:**
  [`INTEGER`](https://smlfamily.github.io/Basis/integer.html) `fromInt`:
  "converts a value from type Int.int to type int. If the value cannot be
  represented as a value of type int, the Overflow exception is raised" --
  every `int` can be an `IntInf.int`, whose `precision` is `NONE`; and
  `toInt` raises `Overflow` only when "the argument cannot be represented as
  an int". [`TIME`](https://smlfamily.github.io/Basis/time.html) `toSeconds`
  and the like raise `Overflow` "When the result is not representable by
  LargeInt.int", which never happens for an unbounded `LargeInt`; and
  [`DATE`](https://smlfamily.github.io/Basis/date.html): "A conforming Date
  structure should support date values ranging from around 1900 to 2200".

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend (`Int.precision = SOME 63`, `IntInf.precision = NONE`).
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* IntInf.int (LargeInt.int) is unbounded and int has 63 bits, so neither
   conversion below should raise Overflow; Time.time is 63-bit seconds and
   microseconds, so 2^31 seconds (2038-01-19 03:14:08 UTC) is a time. *)
fun try (what, f) =
    print (what ^ " = " ^ (f () handle Overflow => "Overflow" | Time.Time => "Time.Time") ^ "\n")
val two31 : int = 2147483648
val () = try ("Int.toLarge 2147483648           ", fn () => IntInf.toString (Int.toLarge two31))
val () = try ("IntInf.fromInt 2147483647        ", fn () => IntInf.toString (IntInf.fromInt (two31 - 1)))
val () = try ("IntInf.fromInt 2147483648        ", fn () => IntInf.toString (IntInf.fromInt two31))
val () = try ("LargeInt.fromInt 2147483648      ", fn () => IntInf.toString (LargeInt.fromInt two31))
val () = try ("IntInf.toInt (IntInf.pow (2, 31))", fn () => Int.toString (IntInf.toInt (IntInf.pow (2, 31))))
val () = try ("Time.fromSeconds 2147483647      ", fn () => IntInf.toString (Time.toSeconds (Time.fromSeconds (IntInf.fromInt (two31 - 1)))))
val () = try ("Time.fromSeconds 2^31            ", fn () => IntInf.toString (Time.toSeconds (Time.fromSeconds (IntInf.pow (2, 31)))))
val () = try ("Time.fromReal 2147483648.0       ", fn () => IntInf.toString (Time.toSeconds (Time.fromReal 2147483648.0)))
val t = Time.+ (Time.fromSeconds (IntInf.fromInt (two31 - 1)), Time.fromSeconds (IntInf.fromInt 1))
val () = try ("Time.toSeconds ((2^31 - 1 s) + 1 s)", fn () => IntInf.toString (Time.toSeconds t))
val () = try ("Time.toString ((2^31 - 1 s) + 1 s) ", fn () => Time.toString t)
val () = try ("Date.toTime 2038-01-19 03:14:08 UTC", fn () =>
               Time.toString (Date.toTime (Date.date {year = 2038, month = Date.Jan, day = 19, hour = 3,
                                                      minute = 14, second = 8, offset = SOME Time.zeroTime})))
```

```
$ mlkit -o bug bug.mlb && ./bug
Int.toLarge 2147483648            = 2147483648
IntInf.fromInt 2147483647         = 2147483647
IntInf.fromInt 2147483648         = Overflow
LargeInt.fromInt 2147483648       = Overflow
IntInf.toInt (IntInf.pow (2, 31)) = Overflow
Time.fromSeconds 2147483647       = 2147483647
Time.fromSeconds 2^31             = Time.Time
Time.fromReal 2147483648.0        = Time.Time
Time.toSeconds ((2^31 - 1 s) + 1 s) = Overflow
Time.toString ((2^31 - 1 s) + 1 s)  = Overflow
Date.toTime 2038-01-19 03:14:08 UTC = Time.Time
```

(The annotation `val two31 : int` is needed: without it MLKit 4.7.23 stops
with "Impossible: resolve_tv.hmm; maybe insert cases for string, etc; ts =
{intinf,int64,int}", a separate matter.)

## The cause

`basis/IntInf.sml` converts through `Int32` (lines 680 to 727, "The
implementation works for both Int=Int31 and Int=Int32 ; mael 2005-12-14"):

```sml
    in
	fun toInt x = Int32.toInt(intInfToI32 x)
	fun fromInt x = i32ToIntInf(Int32.fromInt x)
    end (* local *)
```

`Int32.fromInt` of a 63-bit `int` beyond 32 bits raises `Overflow`, and so
does `intInfToI32` of a number beyond 32 bits. `basis/IntInfRep.sml` has
conversions through `Int64` (`fromInt x = i64ToIntInf(i_i64 x)`,
`toInt x = i64_i(intInfToI64 x)`), which `Int.toLarge` and `Int.fromLarge`
use, but `IntInf` does not.

`basis/Time.sml` converts with the `LargeInt` (= `IntInf`) functions:

```sml
    fun fromMicro (us : IntInf.int) : time =
        {sec = LargeInt.toInt (IntInf.div (us, millionL)),
         usec = LargeInt.toInt (IntInf.mod (us, millionL))}
        handle Overflow => raise Time

    fun toMicro ({sec, usec} : time) : IntInf.int =
        IntInf.+ (IntInf.* (LargeInt.fromInt sec, millionL), LargeInt.fromInt usec)
```

so `fromMicro` (behind every `from*` function) turns the `Overflow` into
`Time` for 2^31 seconds or more, and `toMicro` (behind every `to*`
function and `fmt`) lets it escape, while `Time.+` and `Time.-` add the
63-bit seconds directly.

## The fix

Use the conversions of `IntInfRep` through `Int`:

```diff
--- a/basis/IntInf.sml
+++ b/basis/IntInf.sml
@@
     in
-	fun toInt x = Int32.toInt(intInfToI32 x)
-	fun fromInt x = i32ToIntInf(Int32.fromInt x)
+	(* Int.toLarge and Int.fromLarge convert through Int64 (IntInfRep),
+	   so that every int, of 63 or 64 bits, is an IntInf.int *)
+	fun toInt x = Int.fromLarge x
+	fun fromInt x = Int.toLarge x
     end (* local *)
```

Not built as a patch of the library. Tested as follows in programs built
with MLKit 4.7.23: `Int.toLarge` and `Int.fromLarge` convert `maxInt` and
`minInt` both ways and raise `Overflow` for 2^62 and -2^62 - 1; and a copy
of `basis/Time.sml` whose four `LargeInt.toInt`/`LargeInt.fromInt` are
replaced by `Int.fromLarge`/`Int.toLarge`, shadowing `Time`, passes all
180 checks of Rune's `tests/basis/time.sml` but
`Time.fromString/nanoseconds-lost-or-kept` (a separate matter: MLKit rounds
digits below the microsecond), and with the fixes of the `Date` reports all
132 checks of `tests/basis/date.sml`.

## Relation to Rune

The checks `Time.+/Time-when-not-representable`,
`Time.+/Time-when-not-representable-negative`,
`Time.-/Time-when-not-representable` and
`Time.-/Time-when-not-representable-positive` of `tests/basis/time.sml`
double a time until `+` or `-` raises `Time`, checking `Time.toSeconds` of
each result; on MLKit `toSeconds` of 2^31 seconds raises `Overflow`
("raised an exception, expected true"). `Date.toTime/century-to-2100-beyond-2038`
of `tests/basis/date.sml` fails because `toTime` raises `Time`, and
`Date.toTime/1900-to-2200` and `Date.fromTimeUniv/calendar-1900-2199` need
this fix as well as that of the report `Date.toTime/before-1970`. Proposed
lines of `tests/basis/deviations.txt`:

```
native:mlkit@* | Time.[+-]/Time-when-not-representable* | HOST-BUG | toSeconds raises Overflow for a time of 2^31 seconds or more, which + and - make without raising Time: IntInf.fromInt and IntInf.toInt go through Int32, so that the conversions of Time hold 32 bits of seconds
native:mlkit@* | Date.toTime/century-to-2100-beyond-2038 | HOST-BUG | toTime of a date after 2038-01-19 03:14:07 UTC raises Time: IntInf.toInt goes through Int32, so that Time.fromReal raises Time for 2^31 seconds or more
```
