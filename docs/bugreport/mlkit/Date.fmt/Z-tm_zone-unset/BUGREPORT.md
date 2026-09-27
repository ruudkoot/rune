# MLKit 4.7.23: `Date.fmt "%Z"` names the local zone for a UTC date, and crashes for a local one: `sml_strftime` leaves `tm_zone` unset

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The runtime's `sml_strftime` leaves `tm_zone` unset, so `%Z` names the wrong zone or crashes the program.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `src/Runtime/Time.c` and `basis/Date.sml` are identical
to 4.7.23's.

## Summary

* **The trigger:** `Date.fmt` (or `Date.toString`'s kin) with the directive
  `%Z`.
* **What goes wrong:** the runtime's `sml_strftime` fills a `struct tm` on
  the stack field by field and never sets `tm_zone` (nor `tm_gmtoff`),
  which glibc's `strftime` reads for `%Z`. What `%Z` gives therefore
  depends on whatever the stack held: for a UTC date the name of the local
  zone (`"NST"` in the run below; glibc takes `tzname[tm_isdst]` when
  `tm_zone` is null or empty), in an earlier version of the program the
  single byte 17, and for a local date from `fromTimeLocal` a segmentation
  fault (`tm_zone` was `0x1`).
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html),
  `fmt`: `%Z` is the "time zone name or abbreviation, or the empty string if
  no time zone information exists". A date made by `fromTimeUniv` or with
  `offset = SOME Time.zeroTime` is in UTC ("SOME(Time.zeroTime) is UTC"),
  not in the local zone.

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04 (glibc 2.39),
  `TZ='NST3:30NDT,M3.2.0,M11.1.0'` (3:30 west of UTC with summer time).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* %Z: "time zone name or abbreviation, or the empty string if no time zone
   information exists". Run with TZ='NST3:30NDT,M3.2.0,M11.1.0'. *)
fun show s = "\"" ^ String.toString s ^ "\" (" ^ String.concatWith " " (map (Int.toString o ord) (explode s)) ^ ")"
val u = Date.date {year = 1995, month = Date.Mar, day = 8, hour = 19, minute = 6, second = 45,
                   offset = SOME Time.zeroTime}
val () = print ("UTC date:   Date.fmt \"%Z\" = " ^ show (Date.fmt "%Z" u) ^ "\n")
fun again () = Date.fmt "[%Z]" u
val () = print ("UTC date:   Date.fmt \"[%Z]\" = " ^ show (again ()) ^ "\n")
val l = Date.fromTimeLocal (Time.fromSeconds (IntInf.fromInt 794689605))
val () = print ("local date: Date.fmt \"%Y\" = " ^ show (Date.fmt "%Y" l) ^ "\n")
val () = print ("local date: Date.fmt \"%Z\" = " ^ show (Date.fmt "%Z" l) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && TZ='NST3:30NDT,M3.2.0,M11.1.0' ./bug; echo "exit $?"
UTC date:   Date.fmt "%Z" = "NST" (78 83 84)
UTC date:   Date.fmt "[%Z]" = "[NST]" (91 78 83 84 93)
local date: Date.fmt "%Y" = "1995" (49 57 57 53)
Segmentation fault
exit 139
```

Three runs in a row gave the same output. An earlier version of the
program, with other `print`s before the first `Date.fmt`, got the single
byte 17 for the UTC date instead of `"NST"`. Under `gdb`, the
crash of this program is in `__strftime_internal` (glibc
`time/strftime_l.c:1316`) called from `sml_strftime` (`Time.c:143`), with

```
$1 = {tm_sec = 45, tm_min = 36, tm_hour = 15, tm_mday = 8, tm_mon = 2, tm_year = 95,
      tm_wday = 3, tm_yday = 66, tm_isdst = 0, tm_gmtoff = 1589379211,
      tm_zone = 0x1 <error: Cannot access memory at address 0x1>}
```

## The cause

`src/Runtime/Time.c`, `sml_strftime` (line 123):

```c
  struct tm tmr;
  int ressize;
#define BUFSIZE 256
  char buf[BUFSIZE];
  tmr.tm_hour = convertIntToC(elemRecordML(v,0));
  tmr.tm_isdst = convertIntToC(elemRecordML(v,1));
  ...
  tmr.tm_year = convertIntToC(elemRecordML(v,8));
  ...
  ressize = strftime(buf, BUFSIZE, fmt->data, &tmr);
```

`tm_gmtoff` and `tm_zone`, glibc's extensions of `struct tm`, are left
uninitialised; `strftime` reads `tm_zone` for `%Z` (and `tm_gmtoff` for
`%z`). With a null or empty `tm_zone` glibc uses `tzname[tm_isdst]`, the
name of the local zone, which is also wrong for a date in UTC; a stray
pointer prints garbage or faults. `basis/Date.sml` passes `%Z` through to
`strftime` for every date (`fmt`, line 239).

## The fix

Clear the structure in C, so that `%Z` of a local date is the local zone's
name (glibc then uses `tzname[tm_isdst]`, and `""` for `tm_isdst = -1`),
and give a date that is not local its own zone name in SML:

```diff
--- a/src/Runtime/Time.c
+++ b/src/Runtime/Time.c
@@ REG_POLY_FUN_HDR(sml_strftime, Region rAddr, Context ctx, String fmt, uintptr_t v, uintptr_t exn)
   struct tm tmr;
   int ressize;
 #define BUFSIZE 256
   char buf[BUFSIZE];
+  /* tm_zone and tm_gmtoff, which strftime reads for %Z and %z */
+  memset(&tmr, 0, sizeof tmr);
   tmr.tm_hour = convertIntToC(elemRecordML(v,0));
```

(with `#include <string.h>`), and

```diff
--- a/basis/Date.sml
+++ b/basis/Date.sml
@@
-    fun fmt fmtstr date =
+    fun fmt fmtstr (date as DATE {offset, ...}) =
 	let val tm = dateToTmoz date
+	    (* strftime knows the name of the local zone only: a date in UTC
+	       is "UTC", and one at another offset has no name *)
+	    val zone = case offset of
+			   NONE => NONE
+			 | SOME 0 => SOME "UTC"
+			 | SOME _ => SOME ""
 	    fun known c = Char.contains "aAbBcdHIjmMpSUwWxXyYZ%" c
-	    fun sanitize (#"%" :: c :: rest) acc =
+	    fun sanitize (#"%" :: #"Z" :: rest) acc =
+		(case zone of
+		     SOME z => sanitize rest (List.revAppend (String.explode z, acc))
+		   | NONE => sanitize rest (#"Z" :: #"%" :: acc))
+	      | sanitize (#"%" :: c :: rest) acc =
```

The runtime was not rebuilt here; a small C program under the same `TZ`
confirms the glibc side: with `tm_zone` null, `strftime ("%Z")` gives
`NST` for `tm_isdst = 0`, `NDT` for 1 and `""` for -1, and `UTC` when
`tm_zone` is `"UTC"`. The SML part was tested in a copy of
`basis/Date.sml` (with the fixes of the other `Date` reports) shadowing
`Date`, in a program built with MLKit 4.7.23: all 93 checks of Rune's
`tests/basis/date_fmt.sml` pass, `Date.fmt/%Z-UTC` among them. A local
date still goes to `strftime` with `%Z`, so without the C part it can
still crash.

## Relation to Rune

The check `Date.fmt/%Z-UTC` of `tests/basis/date_fmt.sml`, which accepts
`"UTC"`, `"GMT"`, `"Z"` or `""` for a UTC date, fails on MLKit ("got
false, expected true"). The suite formats no local date with `%Z`, so the
crash does not show there. MLton and SML/NJ 110.99.9 also give the local
zone's name (`HOST-BUG` lines of `tests/basis/deviations.txt`). Proposed
line:

```
native:mlkit@* | Date.fmt/%Z-UTC | HOST-BUG | fmt "%Z" of a UTC date gives the name of the local time zone ("NST") or garbage: the runtime's sml_strftime leaves tm_zone unset, and strftime reads it (for a local date it may crash)
```
