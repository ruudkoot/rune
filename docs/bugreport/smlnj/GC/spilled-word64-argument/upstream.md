# Draft: comment on smlnj/legacy#381

Where: https://github.com/smlnj/legacy/issues/381

---

The legacy version has this bug too: on 110.99.9 (64-bit, Linux), the
program of smlnj/smlnj#394 gets a heap address as the fourth field. Here
is a fix for legacy, since the 2026.3 `CPSTransFn` does not apply there.

In `base/compiler/CPS/convert/cpstrans.sml`, `spillIn` puts every spilled
argument that is not a real in an `RK_RECORD`, untagged `Int64`/`Word64`
values included. That gives two symptoms:

* **Constant arguments:** the record becomes a literal, which the runtime
  builds with the number boxed (`INT64` in `gc/build-literals.c`). The
  function selects it raw and gets the address of the box. This is the
  #394 case.
* **Other arguments:** the collector scans the raw number as a pointer. A
  number with any of bits 48 to 63 set indexes past the first level of the
  BIBOP, and the process stops with "Fatal error -- bogus fault not in ML"
  in `MajorGC_SweepToSpace`.

The patch puts spilled untagged machine words in an `RK_RAWBLOCK` of their
own, which goes in the `RK_RECORD` the way the `RK_RAW64BLOCK` of spilled
reals already does. `spillIn` and `spillOut` split the arguments the same
way.

```diff
diff --git a/base/compiler/CPS/convert/cpstrans.sml b/base/compiler/CPS/convert/cpstrans.sml
index 86bcc7a..959ecf2 100644
--- a/base/compiler/CPS/convert/cpstrans.sml
+++ b/base/compiler/CPS/convert/cpstrans.sml
@@ -103,6 +103,16 @@ functor CPStrans (MachSpec : MACH_SPEC) : sig
 		    then h (args, ctys, gpnum, fpnum, [], [], [], [], [])
 		    else NONE
 		end (* function argSpill *)
+        (* spilled arguments that are untagged machine words (e.g., `Int64.int` and
+         * `Word64.word` on 64-bit targets) are not pointers, so they cannot go in
+         * the record of spilled general arguments, which the GC scans; instead,
+         * we put them in a raw record of their own, which goes in that record.
+         * `rawSpill (vs, cts)` returns the untagged arguments of `vs` (with their
+         * types) and the others, both in order.
+         *)
+	  fun isRawWord (NUMt{sz, tag=false}) = (sz = Target.mlValueSz)
+	    | isRawWord _ = false
+	  fun rawSpill (vs, cts) = List.partition (isRawWord o #2) (ListPair.zipEq (vs, cts))
         (* spill code for the arguments of a function application *)
 	  fun spillIn (origargs, origctys, spgvars, spgctys, spfvars) = let
 		val (fhdr, spgvars, spgctys) = (case spfvars
@@ -117,6 +127,17 @@ functor CPStrans (MachSpec : MACH_SPEC) : sig
 			      (fh, (VAR v)::spgvars, ct::spgctys)
 			    end
 		      (* end case *))
+		val (fhdr, spgvars, spgctys) = (case rawSpill (spgvars, spgctys)
+		       of ([], _) => (fhdr, spgvars, spgctys)
+			| (raws, others) => let
+                          (* we have untagged machine words to spill *)
+			    val v = mkv()
+			    val vs = map (fn (x, _) => (x, OFFp 0)) raws
+			    fun rh e = fhdr (RECORD(RK_RAWBLOCK, vs, v, e))
+			    in
+			      (rh, (VAR v) :: map #1 others, PTRt VPT :: map #2 others)
+			    end
+		      (* end case *))
 		val (spgv, ghdr) = (case spgvars
 		       of [] => (NONE, fhdr)
 			| [x] => (SOME x, fhdr)
@@ -151,6 +172,19 @@ functor CPStrans (MachSpec : MACH_SPEC) : sig
 			      (SOME v, fh, v::spgvars, ct::spgctys)
 			    end
 		      (* end case *))
+		val (fhdr, spgvars, spgctys) = (case rawSpill (spgvars, spgctys)
+		       of ([], _) => (fhdr, spgvars, spgctys)
+			| (raws, others) => let
+                          (* we have spilled untagged machine words *)
+			    val v = mkv()
+			    val v' = VAR v
+                            fun rh e = List.foldri
+                                  (fn (i, (sv, st), e) => SELECT(i, v', sv, st, e))
+                                    (fhdr e) raws
+			    in
+			      (rh, v :: map #1 others, PTRt VPT :: map #2 others)
+			    end
+		      (* end case *))
 		val (spgv, ghdr) = (case (spgvars, spgctys)
 		       of ([], _) => (NONE, fhdr)
 			| ([x], t::_) => (SOME(x, t), fhdr)
```

A single file that shows both symptoms:

```sml
(* SML/NJ for 64 bits: a function of six arguments gets its fourth to sixth in
   a record.  When one of them is an untagged Int64.int or Word64.word, the record
   holds the raw number among pointers:
   - if the arguments are constants, the record is a literal, which the runtime
     builds with the number boxed, so the function reads the address of the box;
   - otherwise a major garbage collection takes the number for a pointer, and the
     process stops with "Fatal error -- bogus fault not in ML".
   The loop passes words with the high bit set and keeps some data alive, so that
   major collections happen: sml @SMLalloc=64k bug.sml *)
structure A = struct
  fun f (a : int, b : int, c : int, d : int, e : int, w : Word64.word) =
        Word64.+ (w, Word64.fromInt (a + b + c + d + e))
end;

structure B = struct
  val r = A.f (1, 2, 3, 4, 5, 0wx8000000000000000)
  val () = print (concat ["A.f (1, 2, 3, 4, 5, 0wx8000000000000000) = ",
                          Word64.fmt StringCvt.HEX r, ", expected 800000000000000F: ",
                          if r = 0wx800000000000000F then "ok\n" else "WRONG\n"])
  val bad = ref 0
  val keep = ref ([] : int list list)
  fun go 0 = ()
    | go k = let
        val w = Word64.orb (0wx8000000000000000, Word64.fromInt k)
        in
          if A.f (k, 1, 2, 3, 4, w) <> Word64.+ (w, Word64.fromInt (k + 10))
            then bad := !bad + 1 else ();
          if k mod 50 = 0 then keep := List.tabulate (20, fn i => i) :: !keep else ();
          if k mod 20000 = 0 then keep := [] else ();
          go (k - 1)
        end
  val () = go 2000000
  val () = print (Int.toString (!bad) ^ " of 2000000 calls wrong\n")
end;

val () = OS.Process.exit OS.Process.success;
```

```
$ sml @SMLalloc=64k bug.sml             # 110.99.9, 64-bit
A.f (1, 2, 3, 4, 5, 0wx8000000000000000) = 7C15AC717A4F, expected 800000000000000F: WRONG
.../bin/sml: Fatal error -- bogus fault not in ML: pc = 0x5dbc31e45e10, sig = 11
```

With the patch, built to a fixed point, it prints `ok` and
`0 of 2000000 calls wrong`, and #394's program gives 170000. 110.94, the
first 64-bit release for Linux, has the bug too.

(The patch goes with the fix for #299 that I posted there. A
property-testing library that crashed in 10 of 20 runs with only that fix
passes 20 of 20 with both.)
