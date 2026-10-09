# Drafts: an issue on smlnj/legacy and one on smlnj/smlnj

## 1. New issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Array2` traverses rows and columns that an array or a region does not have (backport of smlnj/smlnj 204968a)

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Major (a traversal writes past the end of an array) |
| Also present in the "development" version? | In 2026.2, yes; smlnj/smlnj `204968a` (2026-10-05) fixes most of it, see the second issue |

### Description

* `Array2.array (0, 5, x)` and `Array2.array (4, 0, x)` have the
  dimensions (0, 0).
* `Array2.row (a, 0)` of an array without rows is an empty vector, not
  `Subscript`.
* `appi`, `foldi` and `modifyi` of a valid region without rows
  (`RowMajor`) or columns (`ColMajor`) apply `f` to one row or column; at
  the end of the array that row is past the end, and `modifyi` writes it.
* `app`, `fold` and `modify` in `ColMajor` order of `tabulate (3, 0, f)`
  apply `f` three times to elements past the end of the empty array, and
  `modify` writes them.

smlnj/smlnj fixed all but the `fold` and `modify` cases in `204968a`
("fixed various boundary cases in the `Array2` structure").

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
dimensions (array (0, 5, 0)) = (0, 0), expected (0, 5): WRONG
dimensions (array (4, 0, 0)) = (0, 0), expected (4, 0): WRONG
row (array (0, 3, 0), 0) = 0, expected Subscript: WRONG
elements foldi RowMajor visits in a region without rows = 3, expected 0: WRONG
elements foldi ColMajor visits in a region without columns = 3, expected 0: WRONG
sub (a, 1, 0) after modifyi of a region without rows = 110, expected 10: WRONG
elements foldi RowMajor visits in the empty region at the end = 3, expected 0: WRONG
elements app ColMajor visits in tabulate (3, 0, f) = 3, expected 0: WRONG
elements fold ColMajor visits in tabulate (3, 0, f) = 3, expected 0: WRONG
elements modify ColMajor visits in tabulate (3, 0, f) = 3, expected 0: WRONG
```

### Expected Behavior

The dimensions asked for; `Subscript` from `row (a, i)` when
`nRows a <= i`; no application of `f` for a region or an array without
elements. Each line gives the expected value.

### Steps to Reproduce

`bug.sml` of this directory.

### Additional Information

`fix.diff` is `204968a` backported to legacy `main` (`12f1dfe`, whose
`array2.sml` is that of 110.99.9), with `foldCM` and `modifyCM` also
returning at once for an array without columns. It was tested by compiling
the patched `array2.sml` as a program on 110.99.9 with stand-ins for the
compiler's primitives, not by rebuilding the Basis: `bug.sml` is then right,
and Rune's Basis suite's `Array2` test runs to the end where it otherwise
dies with a segmentation fault.

## 2. New issue on smlnj/smlnj

Where: https://github.com/smlnj/smlnj/issues/new

**Title:** after 204968a, `Array2.fold ColMajor` and `modify ColMajor` still traverse an array with rows and no columns

### Description

`204968a` gave `appCM` a case for an array without columns, but not
`foldCM` and `modifyCM`. For `tabulate (3, 0, f)` (and now `array (3, 0,
x)`, which keeps its dimensions) `fold ColMajor` applies `f` to three
elements read past the end of the empty array, and `modify ColMajor` also
writes them back there.

```sml
val e = Array2.tabulate Array2.RowMajor (3, 0, fn _ => 0)
val n = Array2.fold Array2.ColMajor (fn (_, n) => n + 1) 0 e    (* 3, expected 0 *)
val () = Array2.modify Array2.ColMajor (fn x => x) e            (* writes data[0] of an empty array *)
```

### Patch

`fix-development.diff`:

```diff
--- a/system/Basis/Implementation/array2.sml
+++ b/system/Basis/Implementation/array2.sml
@@ -291,7 +291,8 @@
 	  end
 
     fun modifyRM f {data, ncols, nrows} = A.modify f data
-    fun modifyCM f {data, ncols, nrows} = let
+    fun modifyCM f {ncols=0, ...} = ()
+      | modifyCM f {data, ncols, nrows} = let
 	  val delta = A.length data - 1
 	  fun modf (i, k) = if (i < nrows)
 		then (unsafeUpdate(data, k, f(unsafeSub(data, k))); modf(i+1, k+ncols))
@@ -320,7 +321,8 @@
 	  end
 
     fun foldRM f init {data, ncols, nrows} = A.foldl f init data
-    fun foldCM f init {data, ncols, nrows} = let
+    fun foldCM f init {ncols=0, ...} = init
+      | foldCM f init {data, ncols, nrows} = let
 	  val delta = A.length data - 1
 	  fun foldf (i, k, accum) = if (i < nrows)
 		then foldf (i+1, k+ncols, f(unsafeSub(data, k), accum))
```
