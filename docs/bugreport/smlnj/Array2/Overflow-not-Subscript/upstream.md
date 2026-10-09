# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Array2` raises `Overflow` instead of `Subscript` for an index or a region near `Int.maxInt`

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | Yes: 2026.2 gives the same, and `system/Basis/Implementation/array2.sml` of smlnj/smlnj `033dd76` has the same tests |

### Description

`Array2.row (a, maxInt)`, `appi`/`foldi`/`modifyi` of a region whose
`row + nrows` or `col + ncols` passes `Int.maxInt`, and `copy` with a
destination index near `Int.maxInt` or `Int.minInt` raise `Overflow`. The
specification asks for `Subscript` ("If reg is not valid, then the
exception Subscript is raised"). The tests add or multiply with the
checked `int` arithmetic before they compare.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
row (a, maxInt): Overflow (WRONG: expected Subscript)
foldi of {row = 1, nrows = SOME maxInt}: Overflow (WRONG: expected Subscript)
appi of {col = 1, ncols = SOME maxInt}: Overflow (WRONG: expected Subscript)
modifyi of {row = maxInt, nrows = SOME maxInt}: Overflow (WRONG: expected Subscript)
copy of a 2 x 2 region to dst_row = maxInt: Overflow (WRONG: expected Subscript)
copy of a 2 x 2 region to dst_row = dst_col = minInt: Overflow (WRONG: expected Subscript)
```

### Expected Behavior

`Subscript` in each case, as MLton gives.

### Steps to Reproduce

`bug.sml` of this directory.

### Additional Information

The patch compares without adding or multiplying (every operand is then
between 0 and the size of the array):

```diff
--- a/system/Basis/Implementation/array2.sml
+++ b/system/Basis/Implementation/array2.sml
@@ -107,17 +107,18 @@
     fun dimensions {data, nrows, ncols} = (nrows, ncols)
     fun nCols (arr : 'a array) = #ncols arr
     fun nRows (arr : 'a array) = #nrows arr
-    fun row ({data, nrows, ncols}, i) = let
-	  val stop = i*ncols
-	  fun mkVec (j, l) =
-		if (j < stop)
-		  then Vector.fromList l
-		  else mkVec(j-1, A.sub(data, j)::l)
-	  in
-	    if ltu(i, nrows) (* 0 <= i < nrows *)
-	      then mkVec (stop+ncols-1, [])
-	      else raise General.Subscript
-	  end
+    fun row ({data, nrows, ncols}, i) =
+	  if ltu(i, nrows) (* 0 <= i < nrows *)
+	    then let
+	      val stop = i*ncols
+	      fun mkVec (j, l) =
+		    if (j < stop)
+		      then Vector.fromList l
+		      else mkVec(j-1, A.sub(data, j)::l)
+	      in
+		mkVec (stop+ncols-1, [])
+	      end
+	    else raise General.Subscript
     fun column ({data, nrows, ncols}, j) = let
 	  fun mkVec (i, l) =
 		if (i < 0)
@@ -137,7 +138,7 @@
 		  then raise General.Subscript
 		  else n-start
 	    | chk (start, n, SOME len) =
-		if ((start < 0) orelse (len < 0) orelse (n < start+len))
+		if ((start < 0) orelse (len < 0) orelse (n < start) orelse (n-start < len))
 		  then raise General.Subscript
 		  else len
 	  val nr = chk (row, nrows, nr)
@@ -168,7 +169,8 @@
 			       dst = ddata, di = d };
 		     up (i-1, d - dncols, s - bncols))
 		else ()
-	in if src_nrows + dst_row > dnrows orelse src_ncols + dst_col > dncols
+	in if dst_row < 0 orelse dst_col < 0
+	      orelse dnrows - src_nrows < dst_row orelse dncols - src_ncols < dst_col
 	   then raise General.Subscript
 	   else if dst_row <= srow then
 	       dn (src_nrows,
```

That is the patch for smlnj/smlnj `main`. For legacy, whose `row` is the
one before `204968a`, `fix.diff` applies after the backport of `204968a`
in the companion issue on `Array2` without rows or columns. Tested by
compiling the patched `array2.sml` as a program on 110.99.9 with stand-ins
for the compiler's primitives, not by rebuilding the Basis: Rune's Basis
suite's `Array2` test (1,255 checks) then passes in full.
