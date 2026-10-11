# MLton 20241230: `Date.date` raises `Overflow`, not `Date`, for a year it cannot represent

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (SML/NJ 110.99.9 and 2026.2, Poly/ML 5.9.2 and MLKit 4.7.23) does the same.** MLKit raises `Overflow` too, from the year 12,626,108,195,557,532 on, where the same arithmetic overflows its 63-bit `int`. SML/NJ and Poly/ML make a date for every year tried here, up to 2^31 - 1.

## Status

Not reported upstream from here. MLton's tracker has no matching issue or
pull request: searching the issues and the pull requests of MLton/mlton
for `Date`, `Date.date`, `Overflow Date`, `toTime` and `2038` (on
2026-10-11) found nothing about it. On MLton's `master` at `5fe943391`
(2026-10-03), `Date.date` was changed by pull request #654 ("Fix bug with
`offset` interpretation in `Date.date`", merged 2026-09-18). That change is
about the offset, and the arithmetic that overflows is the same there.

## Summary

* **The trigger:** `Date.date r` where `#year r` is about 5.88 million or
  more. With MLton's default 32-bit `int`, the first year for which
  1 January fails is 5,879,491. All the other fields can be in range.
* **What goes wrong:** the exception `Overflow` of the day-number arithmetic
  inside `Date` escapes from `Date.date`.
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html#SIG:DATE.date:VAL)
  says that `date` "creates a canonical date from the given date
  information. If the resulting date is outside the range supported by the
  implementation, the Date exception is raised." MLton may refuse such a
  year, but it must do so with `Date`.

## Environment

* **MLton:** 20241230, the official binary release (`mlton` prints
  "MLton 20241230"), with its default 32-bit `int`.
* **System:** Linux x86-64, Ubuntu 24.04 on WSL2 (kernel
  6.18.33.2-microsoft-standard-WSL2), glibc 2.39, `TZ` unset (the machine's
  zone is Europe/London; the result does not depend on it).
* **Basis Library: MLton's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlton bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "If the resulting date is outside the range supported by the
   implementation, the Date exception is raised." *)
fun try y =
    let
      val what = "Date.date of 1 January " ^ Int.toString y
      val d = Date.date {year = y, month = Date.Jan, day = 1, hour = 0, minute = 0,
                         second = 0, offset = SOME Time.zeroTime}
    in
      print (what ^ ": a date of the year " ^ Int.toString (Date.year d) ^ "\n")
    end
    handle Date.Date => print ("Date.date of 1 January " ^ Int.toString y ^ ": raised Date\n")
         | e => print ("Date.date of 1 January " ^ Int.toString y ^ ": raised " ^ exnName e
                       ^ " (expected Date or a date)\n")
val () = List.app try [2200, 5879490, 5879491, 1000000000, 2147483647]
```

```
$ mlton bug.mlb && ./bug
Date.date of 1 January 2200: a date of the year 2200
Date.date of 1 January 5879490: a date of the year 5879490
Date.date of 1 January 5879491: raised Overflow (expected Date or a date)
Date.date of 1 January 1000000000: raised Overflow (expected Date or a date)
Date.date of 1 January 2147483647: raised Overflow (expected Date or a date)
```

The same happens with `offset = NONE`. A negative year correctly raises
`Date` (`date` checks `year < 0` first).

## The other implementations

The same `bug.sml`, run on each of them:

* **SML/NJ 110.99.9 (64 bits) and SML/NJ 2026.2** (`use "bug.sml";`): a date
  of the year asked for, on every line.
* **Poly/ML 5.9.2** (`use "bug.sml";`): a date of the year asked for, on
  every line.
* **MLKit 4.7.23** (`mlkit -o bug bug.mlb`): a date of the year asked for, on
  every line. MLKit's `int` has 63 bits. Its `Date.date` raises `Overflow`
  as well from the year 12,626,108,195,557,532 on, where the same
  `todaynumber` overflows (MLton's `date.sml` is modified from MLKit's).
* **Rune** (`bin/rune bug.sml -o bug.rbc && bin/runevm bug.rbc`): a date of
  the year asked for, on every line.

## The cause

`basis-library/system/date.sml`. `date` (line 522) checks only for a
negative year and then normalises the fields:

```sml
    fun date { year, month, day, hour, minute, second, offset } =
       if year < 0 then raise Date 
       else
          let
             ...
             val day' = day + dayoffset
          in
             normalizedate year month day' hour minute second offset'
          end
```

`normalizedate` (line 246) turns the date into a day number with
`todaynumber` (line 203), in `int` arithmetic:

```sml
    fun todaynumber year month day = 
        let val prioryears = year - 1
        in
            dayinyear (year, month, day)
          + 1
          + 365 * prioryears
          + prioryears div 4
          - prioryears div 100
          + prioryears div 400
        end
```

With a 32-bit `int`, `365 * prioryears + prioryears div 4` passes 2^31 - 1
from the year 5,879,491 on, and `365 * prioryears` alone from the year
5,883,518. Nothing turns the resulting `Overflow` into `Date`.

## The fix

Raise `Date` for a date whose arithmetic overflows (`fix.patch`):

```diff
--- a/basis-library/system/date.sml
+++ b/basis-library/system/date.sml
@@ -538,6 +538,10 @@
           in
              normalizedate year month day' hour minute second offset'
           end
+          (* The day numbers of normalizedate overflow int for a year
+           * past about 5.8 million (with the default 32-bit int):
+           * such a date is outside the range supported. *)
+          handle Overflow => raise Date
 
     fun offset (T {offset, ...}) = 
         Option.map
```

The handler also covers an `Overflow` of `day + dayoffset` or of
`Time.toSeconds` of an offset, which are likewise dates out of range. To
support such years instead, the day numbers would have to be computed in
`LargeInt` or `Int64`. The specification does not ask for that: it asks
for 1900 to 2200.

How it was tested: MLton compiles its Basis Library from source into every
program, so the fix was built without rebuilding MLton. The
installed library (`lib/mlton/sml/basis`, identical to `basis-library` of
the 20241230 sources) was copied with this patch applied and used with
`mlton -mlb-path-var 'SML_LIB <copy>' bug.mlb`. `bug.sml` then prints
`raised Date` for the years 5,879,491, 10^9 and 2^31 - 1, and still a date
for 2200 and 5,879,490. Rune's `tests/basis/date.sml` and
`tests/basis/date_fmt.sml`, built the same way with the patches of all four
MLton reports of this directory applied together, lose the two
failures `Date.date/Date-or-a-year-far-away` and
`Date.toTime/Date-or-a-year-far-away` and gain none, in the time zones
`NST3:30NDT,M3.2.0,M11.1.0` and Europe/London. The patch applies to
`master` with fuzz (its `let` was rewritten by #654). The handler goes after
the same `end`.

## Related: `Overflow` after 2038

`Date.toTime` of a date after 2038-01-19 03:14:07 UTC, and
`Date.fromTimeUniv` and `Date.fromTimeLocal` of a time after it, also raise
`Overflow`. On this machine, `toTime` of 2039-01-01 00:00:00 UTC raises it,
and so does `fromTimeUniv (Time.fromSeconds 2147483648)`. The cause is the
same 32-bit `int`: `date.sml` narrows `Time.toSeconds` to `int` (lines 20
to 25) and `toTime` narrows the `time_t` of `mktime` with `C_Time.toInt`.
The fix above does not touch this. Those dates are within "around 1900 to
2200", so the remedy there is wider arithmetic, not `Date`. Rune's suite
records this as `Date.toTime/century-to-2100-beyond-2038` in
`tests/basis/deviations.txt`.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` in
`lib/basis` is tested on generated values. The laws were run against MLton's
own Basis Library with `tests/basis/run-laws-hosts.py` (see the sections on
the other compilers in `docs/plans/quickcheck-hunt.md`). The second law of
`year` in `lib/basis/sig_date.sml` is run for years drawn from all of
`Int.minInt` to `Int.maxInt`, with the other fields in range. It allows
`Date`:

```
Law: `(year (date r) = #year r) handle Date => true`, and `(month (date r)
= #month r) handle Date => true`, and ...
```

On MLton the laws `DATE.year/law-*` at `Date` failed with `Overflow`. The
owner's decision on the laws of `Date.year` is in the section "The other
compilers (D10, 2026-10-10)" of `docs/plans/quickcheck-hunt.md`. The line of
`tests/basis/law-deviations.txt`:

```
native:mlton | DATE.year/law-*@Date | HOST-BUG | Date.date raises Overflow for a year it cannot represent, where the specification asks for Date
```

Rune's Basis Library suite had already met it, in the checks
`Date.date/Date-or-a-year-far-away` and `Date.toTime/Date-or-a-year-far-away`
of `tests/basis/date.sml` (a date of the year 10^8, or `Date`). Both are
recorded as known `HOST-BUG`s for `mlton@*` in `tests/basis/deviations.txt`
("date of year 10^8 raises Overflow, not Date").
