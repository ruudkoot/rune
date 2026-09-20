(* Checks of a structure with signature MONO_ARRAY_SLICE, for any element
   type. Expected values follow
   https://smlfamily.github.io/Basis/mono-array-slice.html.

     structure Generic = TestMonoArraySliceFn (structure S = Word8ArraySlice structure A = Word8Array structure V = Word8Vector structure VS = Word8VectorSlice val name = "Word8ArraySlice" val elems = ... val show = ... val same = ...)

   needs spec-sigs/MONO_VECTOR.sml, MONO_ARRAY.sml, MONO_VECTOR_SLICE.sml and
   MONO_ARRAY_SLICE.sml. A, V and VS are the matching array, vector and vector
   slice structures ("with the vector, array and vector slice types all
   respectively identified"). The labels are name ^ ".member/case". `elems`
   holds at least 8 distinct sample elements, `show` prints one and `same` is
   the equality of elements. An element is written below as its index in
   `elems`, its code: the array [1, 2, 3] is the one of the samples 1, 2 and
   3. Slices are read back with S.length and S.sub, and with S.base, as lists
   of codes. The arrays of a check are made inside its thunk: a check never
   sees the updates of another one.

   "A slice value can be viewed as a triple (a, i, n), where a is the
   underlying array, i is the starting index, and n is the length of the
   subarray, with the constraint that 0 <= i <= i + n <= |a|." The indices
   that appi, modifyi, foldli, foldri and findi pass and return are those "of
   the corresponding element in the slice": they start at 0 whatever the start
   of the slice in its array is.

   TestMonoArraySliceOverflowFn has the checks with numbers near Int.maxInt,
   which a test applies in a section of its own. *)
functor TestMonoArraySliceFn (structure V : SPEC_MONO_VECTOR
                              structure A : SPEC_MONO_ARRAY where type vector = V.vector where type elem = V.elem
                              structure VS : SPEC_MONO_VECTOR_SLICE where type vector = V.vector where type elem = V.elem
                              structure S : SPEC_MONO_ARRAY_SLICE where type array = A.array where type vector = V.vector where type vector_slice = VS.slice where type elem = V.elem
                              val name : string
                              val elems : V.elem vector
                              val show : V.elem -> string
                              val same : V.elem * V.elem -> bool) =
struct
  fun lab s = name ^ "." ^ s

  (* e i: the sample with code i; code x: the code of x, ~1 when it is none. *)
  val samples = Vector.length elems
  fun e i = Vector.sub (elems, i)
  fun code x =
    let fun go i = if i >= samples then ~1 else if same (e i, x) then i else go (i + 1)
    in go 0 end
  fun showCode i = if i >= 0 andalso i < samples then show (e i) else "?"
  fun next x = e ((code x + 1) mod 8)

  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list showCode)
  val eqO = T.eq (T.option showCode)
  val eqOrd = T.eq T.order
  val eqIL = T.eq (T.list (T.pair (T.int, showCode)))
  val eqIO = T.eq (T.option (T.pair (T.int, showCode)))

  fun vectorToList v = List.tabulate (V.length v, fn i => code (V.sub (v, i)))
  fun arrayToList a = List.tabulate (A.length a, fn i => code (A.sub (a, i)))
  fun toList sl = List.tabulate (S.length sl, fn i => code (S.sub (sl, i)))
  fun vec l = V.fromList (List.map e l)
  fun arr l = A.fromList (List.map e l)

  (* eqS, eqA, eqV (label, expected, f): the elements of the slice, of the
     array or of the vector f () are expected. *)
  fun eqS (label, expected : int list, f : unit -> S.slice) : unit = eqL (label, expected, fn () => toList (f ()))
  fun eqA (label, expected : int list, f : unit -> A.array) : unit = eqL (label, expected, fn () => arrayToList (f ()))
  fun eqV (label, expected : int list, f : unit -> V.vector) : unit = eqL (label, expected, fn () => vectorToList (f ()))

  (* eqBase (label, (l, i, n), f): the base of the slice f () is an array of
     the elements l, the start i and the length n. *)
  val showBase = T.triple (T.list showCode, T.int, T.int)
  fun baseOf sl = let val (a, i, n) = S.base sl in (arrayToList a, i, n) end
  fun eqBase (label, expected : int list * int * int, f : unit -> S.slice) : unit =
    T.eq showBase (label, expected, fn () => baseOf (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end
  fun coded (f, seen) = (f, fn () => List.map code (seen ()))
  fun codedI (f, seen) = (f, fn () => List.map (fn (i, x) => (i, code x)) (seen ()))

  fun fromTo (lo, hi) = if lo > hi then [] else lo :: fromTo (lo + 1, hi)

  val l8 = [0, 1, 2, 3, 4, 5, 6, 7]
  fun a8 () = arr l8
  (* 2 3 4 5, in the middle of a new a8 *)
  val lMid = [2, 3, 4, 5]
  val iMid = [(0, 2), (1, 3), (2, 4), (3, 5)]
  fun midOf a = S.slice (a, 2, SOME 4)
  fun mid () = midOf (a8 ())
  (* an empty slice in the middle of a new a8 *)
  fun nothing () = S.slice (a8 (), 3, SOME 0)
  fun zeros n = A.array (n, e 0)
  val minusOne = ref ~1   (* not a constant: see Array.update in array.sml *)
  fun cmp (a, b) = Int.compare (code a, code b)
  fun even x = code x mod 2 = 0

  (* model (len, i, sz): the start and the length of the slice (i, sz) of a
     sequence of len elements, or NONE where the page says Subscript: "if i < 0
     or |arr| < i" for NONE, "if i < 0 or j < 0 or |arr| < i + j" for SOME j.
     (The arguments of these checks are small: i + j exists.) *)
  fun model (len, i, NONE) = if i < 0 orelse len < i then NONE else SOME (i, len - i)
    | model (len, i, SOME j) = if i < 0 orelse j < 0 orelse len < i + j then NONE else SOME (i, j)
  val sizes = NONE :: List.map SOME (fromTo (~2, 10))
  val arguments = List.concat (List.map (fn i => List.map (fn sz => (i, sz)) sizes) (fromTo (~2, 10)))
  val eqArgs = T.eq (T.list (T.pair (T.int, T.option T.int)))
  fun startAndLength sl = let val (_, i, n) = S.base sl in (i, n) end

  val () = T.check (lab "elem/eight-distinct-samples",
                    fn () => samples >= 8 andalso List.tabulate (8, fn i => code (e i)) = l8)

  (* ---- slice: "If sz is NONE, the slice includes all of the elements to the
     end of the array, i.e., arr[i..|arr|-1]. This raises Subscript if i < 0
     or |arr| < i. If sz is SOME(j), the slice has length j, that is, it
     corresponds to arr[i..i+j-1]. It raises Subscript if i < 0 or j < 0 or
     |arr| < i + j. Note that, if defined, slice returns an empty slice when
     i = |arr|." ---- *)
  val () = eqS (lab "slice/NONE-from-zero", l8, fn () => S.slice (a8 (), 0, NONE))
  val () = eqS (lab "slice/NONE-middle", [3, 4, 5, 6, 7], fn () => S.slice (a8 (), 3, NONE))
  val () = eqS (lab "slice/NONE-last", [7], fn () => S.slice (a8 (), 7, NONE))
  val () = eqS (lab "slice/NONE-at-length", [], fn () => S.slice (a8 (), 8, NONE))
  val () = eqBase (lab "slice/NONE-middle-base", (l8, 3, 5), fn () => S.slice (a8 (), 3, NONE))
  val () = eqBase (lab "slice/NONE-at-length-base", (l8, 8, 0), fn () => S.slice (a8 (), 8, NONE))
  val () = T.raises (lab "slice/NONE-Subscript-negative", T.isSubscript, fn () => S.slice (a8 (), !minusOne, NONE))
  val () = T.raises (lab "slice/NONE-Subscript-beyond", T.isSubscript, fn () => S.slice (a8 (), 9, NONE))
  val () = eqS (lab "slice/SOME-middle", lMid, fn () => S.slice (a8 (), 2, SOME 4))
  val () = eqS (lab "slice/SOME-all", l8, fn () => S.slice (a8 (), 0, SOME 8))
  val () = eqS (lab "slice/SOME-one", [7], fn () => S.slice (a8 (), 7, SOME 1))
  val () = eqS (lab "slice/SOME-zero", [], fn () => S.slice (a8 (), 3, SOME 0))
  val () = eqS (lab "slice/SOME-zero-at-length", [], fn () => S.slice (a8 (), 8, SOME 0))
  val () = eqBase (lab "slice/SOME-middle-base", (l8, 2, 4), fn () => S.slice (a8 (), 2, SOME 4))
  val () = eqBase (lab "slice/SOME-zero-base", (l8, 3, 0), fn () => S.slice (a8 (), 3, SOME 0))
  val () = T.raises (lab "slice/SOME-Subscript-negative-start", T.isSubscript, fn () => S.slice (a8 (), !minusOne, SOME 2))
  val () = T.raises (lab "slice/SOME-Subscript-negative-size", T.isSubscript, fn () => S.slice (a8 (), 2, SOME (!minusOne)))
  val () = T.raises (lab "slice/SOME-Subscript-too-long", T.isSubscript, fn () => S.slice (a8 (), 5, SOME 4))
  val () = T.raises (lab "slice/SOME-Subscript-beyond", T.isSubscript, fn () => S.slice (a8 (), 9, SOME 0))
  val () = eqS (lab "slice/of-empty-array", [], fn () => S.slice (arr [], 0, NONE))
  val () = T.raises (lab "slice/of-empty-array-Subscript", T.isSubscript, fn () => S.slice (arr [], 1, NONE))
  (* the slice is a view of the array, not a copy of its elements *)
  val () = eqS (lab "slice/sees-later-updates-of-the-array", [2, 3, 7, 5],
                fn () => let val a = a8 () val sl = midOf a in A.update (a, 4, e 7); sl end)
  val () = eqB (lab "slice/base-is-the-same-array", true, fn () => let val a = a8 () in #1 (S.base (midOf a)) = a end)
  (* every start from ~2 to 10 with NONE and every size from ~2 to 10: the
     arguments that do not behave as the model says *)
  val () = eqArgs (lab "slice/every-argument", [],
                   fn () => List.filter (fn (i, sz) => (SOME (startAndLength (S.slice (a8 (), i, sz))) handle Subscript => NONE)
                                                       <> model (8, i, sz)) arguments)

  (* ---- full: "creates a slice representing the entire array arr. It is
     equivalent to slice(arr, 0, NONE)." ---- *)
  val () = eqS (lab "full/basic", l8, fn () => S.full (a8 ()))
  val () = eqBase (lab "full/base", (l8, 0, 8), fn () => S.full (a8 ()))
  val () = eqS (lab "full/empty-array", [], fn () => S.full (arr []))
  val () = eqBase (lab "full/empty-array-base", ([], 0, 0), fn () => S.full (arr []))
  val () = eqB (lab "full/base-is-the-same-array", true, fn () => let val a = a8 () in #1 (S.base (S.full a)) = a end)

  (* ---- subslice: "creates a slice based on the given slice sl starting at
     index i of sl. If sz is NONE, the slice includes all of the elements to
     the end of the slice, i.e., sl[i..|sl|-1]. This raises Subscript if i < 0
     or |sl| < i. If sz is SOME(j), the slice has length j, that is, it
     corresponds to sl[i..i+j-1]. It raises Subscript if i < 0 or j < 0 or
     |sl| < i + j." The bounds are those of the slice, not of its array. ---- *)
  val () = eqS (lab "subslice/NONE-from-zero", lMid, fn () => S.subslice (mid (), 0, NONE))
  val () = eqS (lab "subslice/NONE-middle", [3, 4, 5], fn () => S.subslice (mid (), 1, NONE))
  val () = eqS (lab "subslice/NONE-at-length", [], fn () => S.subslice (mid (), 4, NONE))
  val () = eqBase (lab "subslice/NONE-middle-base", (l8, 3, 3), fn () => S.subslice (mid (), 1, NONE))
  val () = eqBase (lab "subslice/NONE-at-length-base", (l8, 6, 0), fn () => S.subslice (mid (), 4, NONE))
  val () = T.raises (lab "subslice/NONE-Subscript-negative", T.isSubscript, fn () => S.subslice (mid (), !minusOne, NONE))
  val () = T.raises (lab "subslice/NONE-Subscript-beyond", T.isSubscript, fn () => S.subslice (mid (), 5, NONE))
  val () = eqS (lab "subslice/SOME-middle", [3, 4], fn () => S.subslice (mid (), 1, SOME 2))
  val () = eqS (lab "subslice/SOME-all", lMid, fn () => S.subslice (mid (), 0, SOME 4))
  val () = eqS (lab "subslice/SOME-zero", [], fn () => S.subslice (mid (), 2, SOME 0))
  val () = eqBase (lab "subslice/SOME-middle-base", (l8, 3, 2), fn () => S.subslice (mid (), 1, SOME 2))
  val () = eqBase (lab "subslice/of-subslice-base", (l8, 4, 1), fn () => S.subslice (S.subslice (mid (), 1, SOME 2), 1, NONE))
  val () = T.raises (lab "subslice/SOME-Subscript-negative-start", T.isSubscript, fn () => S.subslice (mid (), !minusOne, SOME 2))
  val () = T.raises (lab "subslice/SOME-Subscript-negative-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME (!minusOne)))
  val () = T.raises (lab "subslice/SOME-Subscript-within-the-array", T.isSubscript, fn () => S.subslice (mid (), 2, SOME 3))
  val () = T.raises (lab "subslice/SOME-Subscript-beyond", T.isSubscript, fn () => S.subslice (mid (), 5, SOME 0))
  val () = eqS (lab "subslice/of-empty", [], fn () => S.subslice (nothing (), 0, NONE))
  val () = T.raises (lab "subslice/of-empty-Subscript", T.isSubscript, fn () => S.subslice (nothing (), 1, NONE))
  val () = eqB (lab "subslice/base-is-the-same-array", true,
                fn () => let val a = a8 () in #1 (S.base (S.subslice (midOf a, 1, NONE))) = a end)
  val () = eqArgs (lab "subslice/every-argument", [],
                   fn () => List.filter (fn (i, sz) => (SOME (startAndLength (S.subslice (mid (), i, sz))) handle Subscript => NONE)
                                                       <> Option.map (fn (s, n) => (2 + s, n)) (model (4, i, sz))) arguments)

  (* ---- length, sub: "returns the i(th) element of the slice sl. If i < 0 or
     |sl| <= i, then the Subscript exception is raised." ---- *)
  val () = eqI (lab "length/middle", 4, fn () => S.length (mid ()))
  val () = eqI (lab "length/full", 8, fn () => S.length (S.full (a8 ())))
  val () = eqI (lab "length/empty", 0, fn () => S.length (nothing ()))
  val () = eqI (lab "sub/first", 2, fn () => code (S.sub (mid (), 0)))
  val () = eqI (lab "sub/last", 5, fn () => code (S.sub (mid (), 3)))
  val () = T.raises (lab "sub/Subscript-length-within-the-array", T.isSubscript, fn () => S.sub (mid (), 4))
  val () = T.raises (lab "sub/Subscript-negative-within-the-array", T.isSubscript, fn () => S.sub (mid (), !minusOne))
  val () = T.raises (lab "sub/Subscript-beyond", T.isSubscript, fn () => S.sub (mid (), 1000))
  val () = T.raises (lab "sub/Subscript-empty", T.isSubscript, fn () => S.sub (nothing (), 0))

  (* ---- update: "sets the i(th) element of the slice sl to a. If i < 0 or
     |sl| <= i, then the Subscript exception is raised." ---- *)
  val () = eqA (lab "update/first", [0, 1, 7, 3, 4, 5, 6, 7], fn () => let val a = a8 () in S.update (midOf a, 0, e 7); a end)
  val () = eqA (lab "update/last", [0, 1, 2, 3, 4, 0, 6, 7], fn () => let val a = a8 () in S.update (midOf a, 3, e 0); a end)
  val () = eqS (lab "update/seen-by-sub", [2, 7, 4, 5], fn () => let val sl = mid () in S.update (sl, 1, e 7); sl end)
  val () = eqS (lab "update/seen-through-an-overlapping-slice", [7, 4, 5, 6],
                fn () => let val a = a8 () in S.update (midOf a, 1, e 7); S.slice (a, 3, SOME 4) end)
  val () = T.raises (lab "update/Subscript-length-within-the-array", T.isSubscript, fn () => S.update (mid (), 4, e 7))
  val () = T.raises (lab "update/Subscript-negative-within-the-array", T.isSubscript, fn () => S.update (mid (), !minusOne, e 7))
  val () = T.raises (lab "update/Subscript-beyond", T.isSubscript, fn () => S.update (mid (), 1000, e 7))
  val () = T.raises (lab "update/Subscript-empty", T.isSubscript, fn () => S.update (nothing (), 0, e 7))
  val () = eqA (lab "update/Subscript-changes-nothing", l8,
                fn () => let val a = a8 ()
                         in S.update (midOf a, 4, e 0) handle Subscript => ();
                            S.update (midOf a, !minusOne, e 0) handle Subscript => (); a end)

  (* ---- base: "returns a triple (arr, i, n) representing the concrete
     representation of the slice" ---- *)
  val () = eqBase (lab "base/middle", (l8, 2, 4), mid)
  val () = eqBase (lab "base/empty", (l8, 3, 0), nothing)
  val () = eqS (lab "base/round-trip", lMid, fn () => let val (a, i, n) = S.base (mid ()) in S.slice (a, i, SOME n) end)

  (* ---- vector: "if vec is the resulting vector, we have |vec| = length sl
     and, for 0 <= i < length sl, element i of vec is sub (sl, i)" ---- *)
  val () = eqV (lab "vector/middle", lMid, fn () => S.vector (mid ()))
  val () = eqV (lab "vector/full", l8, fn () => S.vector (S.full (a8 ())))
  val () = eqV (lab "vector/empty", [], fn () => S.vector (nothing ()))
  val () = eqV (lab "vector/is-a-snapshot", lMid, fn () => let val sl = mid () val v = S.vector sl in S.update (sl, 0, e 7); v end)

  (* ---- copy, copyVec: "copy the given slice into the array dst, with element
     sub (src,i), for 0 <= i < |src|, being copied to position di + i in the
     destination array. If di < 0 or if |dst| < di+|src|, then the Subscript
     exception is raised." The page does not say what is left in dst when
     Subscript is raised; the checks take it that nothing is copied, as the
     condition is on the arguments alone. ---- *)
  val () = eqA (lab "copy/start", [2, 3, 4, 5, 0, 0], fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 0}; d end)
  val () = eqA (lab "copy/middle", [0, 2, 3, 4, 5, 0], fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 1}; d end)
  val () = eqA (lab "copy/end", [0, 0, 2, 3, 4, 5], fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 2}; d end)
  val () = eqA (lab "copy/whole", lMid, fn () => let val d = zeros 4 in S.copy {src = mid (), dst = d, di = 0}; d end)
  val () = eqBase (lab "copy/src-unchanged", (l8, 2, 4), fn () => let val sl = mid () in S.copy {src = sl, dst = zeros 6, di = 1}; sl end)
  val () = eqA (lab "copy/empty-src", [0, 0, 0], fn () => let val d = zeros 3 in S.copy {src = nothing (), dst = d, di = 1}; d end)
  val () = eqA (lab "copy/empty-src-at-length", [0, 0, 0], fn () => let val d = zeros 3 in S.copy {src = nothing (), dst = d, di = 3}; d end)
  val () = eqA (lab "copy/empty-to-empty", [], fn () => let val d = arr [] in S.copy {src = nothing (), dst = d, di = 0}; d end)
  val () = T.raises (lab "copy/Subscript-too-far", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 6, di = 3})
  val () = T.raises (lab "copy/Subscript-negative", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 6, di = !minusOne})
  val () = T.raises (lab "copy/Subscript-src-longer", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 3, di = 0})
  val () = T.raises (lab "copy/Subscript-to-empty", T.isSubscript, fn () => S.copy {src = mid (), dst = arr [], di = 0})
  val () = T.raises (lab "copy/Subscript-empty-src-beyond", T.isSubscript, fn () => S.copy {src = nothing (), dst = zeros 3, di = 4})
  val () = T.raises (lab "copy/Subscript-empty-src-negative", T.isSubscript,
                     fn () => S.copy {src = nothing (), dst = zeros 3, di = !minusOne})
  val () = eqA (lab "copy/Subscript-changes-nothing", [0, 0, 0, 0, 0, 0],
                fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 3} handle Subscript => (); d end)
  (* "The copy function must correctly handle the case in which dst and the
     base array of src are equal, and the source and destination slices
     overlap." *)
  val () = eqA (lab "copy/overlap-to-the-right", [0, 1, 0, 1, 2, 3, 4, 7],
                fn () => let val a = a8 () in S.copy {src = S.slice (a, 0, SOME 5), dst = a, di = 2}; a end)
  val () = eqA (lab "copy/overlap-to-the-left", [2, 3, 4, 5, 6, 5, 6, 7],
                fn () => let val a = a8 () in S.copy {src = S.slice (a, 2, SOME 5), dst = a, di = 0}; a end)
  val () = eqA (lab "copy/overlap-by-one", [0, 0, 1, 2, 3, 4, 5, 6],
                fn () => let val a = a8 () in S.copy {src = S.slice (a, 0, SOME 7), dst = a, di = 1}; a end)
  val () = eqA (lab "copy/onto-itself", l8, fn () => let val a = a8 () in S.copy {src = midOf a, dst = a, di = 2}; a end)
  val () = eqA (lab "copy/same-array-no-overlap", [0, 1, 2, 3, 0, 1, 2, 3],
                fn () => let val a = a8 () in S.copy {src = S.slice (a, 0, SOME 4), dst = a, di = 4}; a end)
  val () = T.raises (lab "copy/Subscript-same-array", T.isSubscript,
                     fn () => let val a = a8 () in S.copy {src = midOf a, dst = a, di = 5} end)

  fun vmid () = VS.slice (vec l8, 2, SOME 4)
  fun vnothing () = VS.slice (vec l8, 3, SOME 0)
  val () = eqA (lab "copyVec/start", [2, 3, 4, 5, 0, 0], fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 0}; d end)
  val () = eqA (lab "copyVec/middle", [0, 2, 3, 4, 5, 0], fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 1}; d end)
  val () = eqA (lab "copyVec/end", [0, 0, 2, 3, 4, 5], fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 2}; d end)
  val () = eqA (lab "copyVec/whole", lMid, fn () => let val d = zeros 4 in S.copyVec {src = vmid (), dst = d, di = 0}; d end)
  val () = eqA (lab "copyVec/full-vector", l8, fn () => let val d = zeros 8 in S.copyVec {src = VS.full (vec l8), dst = d, di = 0}; d end)
  val () = eqA (lab "copyVec/empty-src", [0, 0, 0], fn () => let val d = zeros 3 in S.copyVec {src = vnothing (), dst = d, di = 1}; d end)
  val () = eqA (lab "copyVec/empty-src-at-length", [0, 0, 0],
                fn () => let val d = zeros 3 in S.copyVec {src = vnothing (), dst = d, di = 3}; d end)
  val () = eqA (lab "copyVec/from-vector-of-slice", [0, 1, 2, 2, 3, 4, 5, 7],
                fn () => let val a = a8 () in S.copyVec {src = VS.full (S.vector (midOf a)), dst = a, di = 3}; a end)
  val () = T.raises (lab "copyVec/Subscript-too-far", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 6, di = 3})
  val () = T.raises (lab "copyVec/Subscript-negative", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 6, di = !minusOne})
  val () = T.raises (lab "copyVec/Subscript-src-longer", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 3, di = 0})
  val () = T.raises (lab "copyVec/Subscript-to-empty", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = arr [], di = 0})
  val () = T.raises (lab "copyVec/Subscript-empty-src-beyond", T.isSubscript,
                     fn () => S.copyVec {src = vnothing (), dst = zeros 3, di = 4})
  val () = T.raises (lab "copyVec/Subscript-empty-src-negative", T.isSubscript,
                     fn () => S.copyVec {src = vnothing (), dst = zeros 3, di = !minusOne})
  val () = eqA (lab "copyVec/Subscript-changes-nothing", [0, 0, 0, 0, 0, 0],
                fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 3} handle Subscript => (); d end)

  (* ---- isEmpty, getItem: "returns the first item in sl and the rest of the
     slice, or NONE if sl is empty" ---- *)
  val () = eqB (lab "isEmpty/empty", true, fn () => S.isEmpty (nothing ()))
  val () = eqB (lab "isEmpty/empty-at-length", true, fn () => S.isEmpty (S.slice (a8 (), 8, NONE)))
  val () = eqB (lab "isEmpty/empty-array", true, fn () => S.isEmpty (S.full (arr [])))
  val () = eqB (lab "isEmpty/one", false, fn () => S.isEmpty (S.slice (a8 (), 7, NONE)))
  val () = eqB (lab "isEmpty/middle", false, fn () => S.isEmpty (mid ()))
  val () = eqO (lab "getItem/first", SOME 2, fn () => Option.map (code o #1) (S.getItem (mid ())))
  val () = eqL (lab "getItem/rest", [3, 4, 5], fn () => case S.getItem (mid ()) of SOME (_, r) => toList r | NONE => [~1])
  val () = T.eq (T.option showBase) (lab "getItem/rest-base", SOME (l8, 3, 3),
                                     fn () => Option.map (baseOf o #2) (S.getItem (mid ())))
  val () = eqL (lab "getItem/last-rest-is-empty", [7],
                fn () => case S.getItem (S.slice (a8 (), 7, NONE)) of
                           SOME (x, r) => if S.isEmpty r then [code x] else [~1]
                         | NONE => [])
  val () = eqB (lab "getItem/empty", true, fn () => not (Option.isSome (S.getItem (nothing ()))))
  val () = eqL (lab "getItem/every-item", lMid,
                fn () => let fun go sl = case S.getItem sl of SOME (x, r) => code x :: go r | NONE => [] in go (mid ()) end)
  val () = eqA (lab "getItem/rest-is-the-same-array", [0, 1, 2, 7, 4, 5, 6, 7],
                fn () => let val a = a8 ()
                         in (case S.getItem (midOf a) of SOME (_, r) => S.update (r, 0, e 7) | NONE => ()); a end)

  (* ---- appi, app: "in left to right order (i.e., increasing indices)";
     appi "supplies f with the index of the corresponding element in the
     slice" ---- *)
  val () = eqIL (lab "appi/order", iMid,
                 fn () => let val (f, seen) = codedI (trace (fn _ => ())) in S.appi f (mid ()); seen () end)
  val () = eqIL (lab "appi/empty", [],
                 fn () => let val (f, seen) = codedI (trace (fn _ => ())) in S.appi f (nothing ()); seen () end)
  val () = eqL (lab "app/order", lMid,
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in S.app f (mid ()); seen () end)
  val () = eqL (lab "app/empty", [],
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in S.app f (nothing ()); seen () end)

  (* ---- modifyi, modify: "apply the function f to the elements of an array
     slice in left to right order (i.e., increasing indices), and replace each
     element with the result. The more general modifyi supplies f with the
     index of the corresponding element in the slice." With f (i, x) = the
     sample (2 * i + code x) mod 8 over [2, 3, 4, 5]: 0+2, 2+3, 4+4 = 0,
     (6+5) mod 8 = 3. The elements outside the slice stay. ---- *)
  val () = eqA (lab "modifyi/basic", [0, 1, 2, 5, 0, 3, 6, 7],
                fn () => let val a = a8 () in S.modifyi (fn (i, x) => e ((2 * i + code x) mod 8)) (midOf a); a end)
  val () = eqA (lab "modifyi/index-in-the-slice", [0, 1, 0, 1, 2, 3, 6, 7],
                fn () => let val a = a8 () in S.modifyi (fn (i, _) => e i) (midOf a); a end)
  val () = eqA (lab "modifyi/empty", l8, fn () => let val a = a8 () in S.modifyi (fn _ => e 7) (S.slice (a, 3, SOME 0)); a end)
  val () = eqIL (lab "modifyi/order", iMid,
                 fn () => let val (f, seen) = codedI (trace (fn (_, x) => next x)) in S.modifyi f (mid ()); seen () end)
  val () = eqA (lab "modify/basic", [0, 1, 3, 4, 5, 6, 6, 7], fn () => let val a = a8 () in S.modify next (midOf a); a end)
  val () = eqA (lab "modify/full-wraps", [1, 2, 3, 4, 5, 6, 7, 0], fn () => let val a = a8 () in S.modify next (S.full a); a end)
  val () = eqA (lab "modify/empty", l8, fn () => let val a = a8 () in S.modify (fn _ => e 7) (S.slice (a, 3, SOME 0)); a end)
  val () = eqL (lab "modify/order", lMid,
                fn () => let val (f, seen) = coded (trace next) in S.modify f (mid ()); seen () end)
  val () = eqS (lab "modify/seen-by-the-slice", [3, 4, 5, 6], fn () => let val sl = mid () in S.modify next sl; sl end)

  (* ---- foldli, foldri, foldl, foldr: "foldli and foldl apply the function f
     from left to right (increasing indices), while the functions foldri and
     foldr work from right to left (decreasing indices). The more general
     functions foldli and foldri supply f with the index of the corresponding
     element in the slice."
     With f (i, a, x) = i * code a - 2 * x over [2, 3, 4, 5]:
       foldli: 0*2-0 = 0, 1*3-0 = 3, 2*4-6 = 2, 3*5-4 = 11;
       foldri: 3*5-0 = 15, 2*4-30 = ~22, 1*3+44 = 47, 0*2-94 = ~94.
     With f (a, x) = code a - 2 * x:
       foldl: 2-0 = 2, 3-4 = ~1, 4+2 = 6, 5-12 = ~7;
       foldr: 5-0 = 5, 4-10 = ~6, 3+12 = 15, 2-30 = ~28. ---- *)
  fun gi (i, a, x) = i * code a - 2 * x
  fun g (a, x) = code a - 2 * x
  val () = eqIL (lab "foldli/conses-reversed", List.rev iMid, fn () => S.foldli (fn (i, a, l) => (i, code a) :: l) [] (mid ()))
  val () = eqI (lab "foldli/nonassociative", 11, fn () => S.foldli gi 0 (mid ()))
  val () = eqI (lab "foldli/empty", 42, fn () => S.foldli gi 42 (nothing ()))
  val () = eqIL (lab "foldri/conses-in-order", iMid, fn () => S.foldri (fn (i, a, l) => (i, code a) :: l) [] (mid ()))
  val () = eqI (lab "foldri/nonassociative", ~94, fn () => S.foldri gi 0 (mid ()))
  val () = eqI (lab "foldri/empty", 42, fn () => S.foldri gi 42 (nothing ()))
  val () = eqL (lab "foldl/conses-reversed", List.rev lMid, fn () => S.foldl (fn (a, l) => code a :: l) [] (mid ()))
  val () = eqI (lab "foldl/nonassociative", ~7, fn () => S.foldl g 0 (mid ()))
  val () = eqI (lab "foldl/empty", 42, fn () => S.foldl g 42 (nothing ()))
  val () = eqL (lab "foldr/conses-in-order", lMid, fn () => S.foldr (fn (a, l) => code a :: l) [] (mid ()))
  val () = eqI (lab "foldr/nonassociative", ~28, fn () => S.foldr g 0 (mid ()))
  val () = eqI (lab "foldr/empty", 42, fn () => S.foldr g 42 (nothing ()))

  (* ---- findi, find: "from left to right (i.e., increasing indices), until a
     true value is returned"; findi "also supplies f with the index of the
     element in the slice and, upon finding an entry satisfying the predicate,
     returns that index with the element" ---- *)
  fun found r = Option.map (fn (i, x) => (i, code x)) r
  val () = eqIO (lab "findi/first-match", SOME (2, 4), fn () => found (S.findi (fn (_, a) => code a > 3) (mid ())))
  val () = eqIO (lab "findi/by-index", SOME (3, 5), fn () => found (S.findi (fn (i, _) => i = 3) (mid ())))
  val () = eqIO (lab "findi/index-zero", SOME (0, 2), fn () => found (S.findi (fn _ => true) (mid ())))
  val () = eqIO (lab "findi/none-outside-the-slice", NONE, fn () => found (S.findi (fn (_, a) => code a > 5) (mid ())))
  val () = eqIO (lab "findi/empty", NONE, fn () => found (S.findi (fn _ => true) (nothing ())))
  val () = eqIL (lab "findi/stops", [(0, 2), (1, 3)],
                 fn () => let val (f, seen) = codedI (trace (fn (_, a) => code a = 3)) in ignore (S.findi f (mid ())); seen () end)
  val () = eqIL (lab "findi/order", iMid,
                 fn () => let val (f, seen) = codedI (trace (fn _ => false)) in ignore (S.findi f (mid ())); seen () end)
  val () = eqO (lab "find/first-match", SOME 2, fn () => Option.map code (S.find even (mid ())))
  val () = eqO (lab "find/last-element", SOME 5, fn () => Option.map code (S.find (fn x => code x > 4) (mid ())))
  val () = eqO (lab "find/none-outside-the-slice", NONE, fn () => Option.map code (S.find (fn x => code x < 2) (mid ())))
  val () = eqO (lab "find/empty", NONE, fn () => Option.map code (S.find (fn _ => true) (nothing ())))
  val () = eqL (lab "find/stops", [2, 3],
                fn () => let val (f, seen) = coded (trace (fn x => code x = 3)) in ignore (S.find f (mid ())); seen () end)

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB (lab "exists/true", true, fn () => S.exists (fn x => code x = 4) (mid ()))
  val () = eqB (lab "exists/false-outside-the-slice", false, fn () => S.exists (fn x => code x = 6) (mid ()))
  val () = eqB (lab "exists/empty", false, fn () => S.exists (fn _ => true) (nothing ()))
  val () = eqL (lab "exists/stops", [2, 3, 4],
                fn () => let val (f, seen) = coded (trace (fn x => code x = 4)) in ignore (S.exists f (mid ())); seen () end)
  val () = eqL (lab "exists/order", lMid,
                fn () => let val (f, seen) = coded (trace (fn _ => false)) in ignore (S.exists f (mid ())); seen () end)
  val () = eqB (lab "all/true-but-not-outside-the-slice", true, fn () => S.all (fn x => code x >= 2 andalso code x <= 5) (mid ()))
  val () = eqB (lab "all/false", false, fn () => S.all (fn x => code x < 4) (mid ()))
  val () = eqB (lab "all/empty", true, fn () => S.all (fn _ => false) (nothing ()))
  val () = eqL (lab "all/stops", [2, 3, 4],
                fn () => let val (f, seen) = coded (trace (fn x => code x < 4)) in ignore (S.all f (mid ())); seen () end)
  val () = eqL (lab "all/order", lMid,
                fn () => let val (f, seen) = coded (trace (fn _ => true)) in ignore (S.all f (mid ())); seen () end)

  (* ---- collate: "lexicographic comparison of the two slices using the given
     ordering f on elements"; the elements outside the slices do not count ---- *)
  fun sl (l, i, n) = S.slice (arr l, i, SOME n)
  val () = eqOrd (lab "collate/equal-in-different-arrays", EQUAL,
                  fn () => S.collate cmp (sl ([7, 1, 2, 7], 1, 2), sl ([0, 0, 1, 2], 2, 2)))
  val () = eqOrd (lab "collate/same-slice", EQUAL, fn () => let val s = mid () in S.collate cmp (s, s) end)
  val () = eqOrd (lab "collate/empty-empty", EQUAL, fn () => S.collate cmp (nothing (), S.full (arr [])))
  val () = eqOrd (lab "collate/empty-less", LESS, fn () => S.collate cmp (nothing (), mid ()))
  val () = eqOrd (lab "collate/empty-greater", GREATER, fn () => S.collate cmp (mid (), nothing ()))
  val () = eqOrd (lab "collate/prefix-less", LESS, fn () => S.collate cmp (sl (l8, 2, 2), sl (l8, 2, 3)))
  val () = eqOrd (lab "collate/prefix-greater", GREATER, fn () => S.collate cmp (sl (l8, 2, 3), sl (l8, 2, 2)))
  val () = eqOrd (lab "collate/first-difference", GREATER, fn () => S.collate cmp (sl ([0, 1, 3, 0], 1, 2), sl ([7, 1, 2, 7], 1, 3)))
  val () = eqOrd (lab "collate/not-by-length", LESS, fn () => S.collate cmp (sl ([0, 7, 7], 0, 3), sl ([7, 1], 1, 1)))
  val () = eqOrd (lab "collate/given-ordering", GREATER,
                  fn () => S.collate (fn (a, b) => cmp (b, a)) (sl ([0, 7, 7], 0, 3), sl ([7, 1], 1, 1)))
  val () = eqOrd (lab "collate/argument-order", LESS,
                  fn () => S.collate (fn (a, b) => if code a = 1 andalso code b = 2 then LESS else GREATER)
                                     (sl ([1], 0, 1), sl ([2], 0, 1)))

  (* ---- laws, on pseudo-random slices, against lists of codes ---- *)
  fun randomList n = List.tabulate (n, fn _ => T.range (0, 7))
  fun indexed l = List.tabulate (List.length l, fn j => (j, List.nth (l, j)))
  fun part (l, i, n) = List.take (List.drop (l, i), n)
  (* put (d, di, l): d with the elements of l from position di on *)
  fun put (d, di, l) = List.take (d, di) @ l @ List.drop (d, di + List.length l)
  val () = T.seed 36
  val () = T.repeat (25, fn k =>
    let
      val t = "-" ^ Int.toString k
      val whole = randomList (T.range (0, 12))
      val len = List.length whole
      val i = T.range (0, len)
      val n = T.range (0, len - i)
      val l = part (whole, i, n)                 (* the elements of the slice *)
      fun s () = S.slice (arr whole, i, SOME n)
      val whole2 = randomList (T.range (0, 12))
      val i2 = T.range (0, List.length whole2)
      val m = List.drop (whole2, i2)
      fun s2 () = S.slice (arr whole2, i2, NONE)
      val j = T.range (~1, n + 1)                 (* an index, or one off either end *)
      val sz = if T.range (0, 2) = 0 then NONE else SOME (T.range (~1, n + 1))
      val x = T.range (0, 7)
      (* a destination of 0..6 more elements than the slice, and an offset
         into it that is valid, or one too large *)
      val d = randomList (n + T.range (0, 6))
      val di = T.range (0, List.length d - n + 1)
      (* an offset into the array of the slice itself *)
      val si = T.range (0, len - n)
      val fi = fn (j, c) => (3 * j + c) mod 8
      val hi = fn (j, c, b) => j * c - 2 * b
      val h = fn (c, b) => c - 2 * b
      val pi = fn (j, c) => (j + c) mod 3 = 0
      val p = fn c => c mod 3 = 0
    in
      eqS (lab "slice/model" ^ t, l, s);
      eqBase (lab "base/model" ^ t, (whole, i, n), s);
      eqI (lab "length/model" ^ t, n, fn () => S.length (s ()));
      eqS (lab "full/model" ^ t, whole, fn () => S.full (arr whole));
      (if 0 <= j andalso j < n
       then (eqI (lab "sub/model" ^ t, List.nth (l, j), fn () => code (S.sub (s (), j)));
             eqBase (lab "update/model" ^ t, (put (whole, i + j, [x]), i, n),
                     fn () => let val sl = s () in S.update (sl, j, e x); sl end))
       else (T.raises (lab "sub/model" ^ t, T.isSubscript, fn () => S.sub (s (), j));
             T.raises (lab "update/model" ^ t, T.isSubscript, fn () => S.update (s (), j, e x))));
      (case model (n, j, sz) of
         SOME (a, b) => eqBase (lab "subslice/model" ^ t, (whole, i + a, b), fn () => S.subslice (s (), j, sz))
       | NONE => T.raises (lab "subslice/model" ^ t, T.isSubscript, fn () => S.subslice (s (), j, sz)));
      eqV (lab "vector/model" ^ t, l, fn () => S.vector (s ()));
      (if di + n <= List.length d
       then (eqA (lab "copy/model" ^ t, put (d, di, l), fn () => let val b = arr d in S.copy {src = s (), dst = b, di = di}; b end);
             eqA (lab "copyVec/model" ^ t, put (d, di, l),
                  fn () => let val b = arr d in S.copyVec {src = VS.slice (vec whole, i, SOME n), dst = b, di = di}; b end))
       else (T.raises (lab "copy/model" ^ t, T.isSubscript, fn () => S.copy {src = s (), dst = arr d, di = di});
             T.raises (lab "copyVec/model" ^ t, T.isSubscript,
                       fn () => S.copyVec {src = VS.slice (vec whole, i, SOME n), dst = arr d, di = di})));
      eqA (lab "copy/same-array-model" ^ t, put (whole, si, l),
           fn () => let val a = arr whole in S.copy {src = S.slice (a, i, SOME n), dst = a, di = si}; a end);
      eqB (lab "isEmpty/model" ^ t, n = 0, fn () => S.isEmpty (s ()));
      T.eq (T.option (T.pair (showCode, showBase)))
        (lab "getItem/model" ^ t, if n = 0 then NONE else SOME (List.hd l, (whole, i + 1, n - 1)),
         fn () => Option.map (fn (x, r) => (code x, baseOf r)) (S.getItem (s ())));
      eqIL (lab "appi/model" ^ t, indexed l,
            fn () => let val (f, seen) = codedI (trace (fn _ => ())) in S.appi f (s ()); seen () end);
      eqL (lab "app/model" ^ t, l,
           fn () => let val (f, seen) = coded (trace (fn _ => ())) in S.app f (s ()); seen () end);
      eqBase (lab "modifyi/model" ^ t, (put (whole, i, List.map fi (indexed l)), i, n),
              fn () => let val sl = s () in S.modifyi (fn (j, c) => e (fi (j, code c))) sl; sl end);
      eqBase (lab "modify/model" ^ t, (put (whole, i, List.map (fn c => (c + 1) mod 8) l), i, n),
              fn () => let val sl = s () in S.modify next sl; sl end);
      eqI (lab "foldli/model" ^ t, List.foldl (fn ((j, c), b) => hi (j, c, b)) 1 (indexed l),
           fn () => S.foldli (fn (j, c, b) => hi (j, code c, b)) 1 (s ()));
      eqI (lab "foldri/model" ^ t, List.foldr (fn ((j, c), b) => hi (j, c, b)) 1 (indexed l),
           fn () => S.foldri (fn (j, c, b) => hi (j, code c, b)) 1 (s ()));
      eqI (lab "foldl/model" ^ t, List.foldl h 1 l, fn () => S.foldl (fn (c, b) => h (code c, b)) 1 (s ()));
      eqI (lab "foldr/model" ^ t, List.foldr h 1 l, fn () => S.foldr (fn (c, b) => h (code c, b)) 1 (s ()));
      eqIO (lab "findi/model" ^ t, List.find pi (indexed l), fn () => found (S.findi (fn (j, c) => pi (j, code c)) (s ())));
      eqO (lab "find/model" ^ t, List.find p l, fn () => Option.map code (S.find (p o code) (s ())));
      eqB (lab "exists/model" ^ t, List.exists p l, fn () => S.exists (p o code) (s ()));
      eqB (lab "all/model" ^ t, List.all (not o p) l, fn () => S.all (not o p o code) (s ()));
      eqB (lab "all/de-morgan" ^ t, true,
           fn () => S.all (p o code) (s ()) = not (S.exists (not o p o code) (s ())));
      eqOrd (lab "collate/model" ^ t, List.collate Int.compare (l, m), fn () => S.collate cmp (s (), s2 ()));
      eqOrd (lab "collate/reflexive" ^ t, EQUAL, fn () => S.collate cmp (s (), S.full (arr l)))
    end)

  (* ---- long slices: no stack or quadratic trouble ---- *)
  fun bigArray () = A.tabulate (100002, fn i => e (i mod 8))
  fun long () = S.slice (bigArray (), 1, SOME 100000)
  val () = eqI (lab "length/long", 100000, fn () => S.length (long ()))
  val () = eqI (lab "sub/long", 0, fn () => code (S.sub (long (), 99999)))   (* element 100000 of the array *)
  val () = eqI (lab "foldl/long", 12500, fn () => S.foldl (fn (c, k) => if code c = 7 then k + 1 else k) 0 (long ()))
  val () = eqI (lab "foldr/long", 100000, fn () => List.length (S.foldr (op ::) [] (long ())))
  val () = eqI (lab "modify/long", 1, fn () => let val sl = long () in S.modify next sl; code (S.sub (sl, 99999)) end)
  val () = eqI (lab "vector/long", 100000, fn () => V.length (S.vector (long ())))
  val () = eqI (lab "getItem/long", 100000,
                fn () => let fun go (sl, k) = case S.getItem sl of SOME (_, r) => go (r, k + 1) | NONE => k in go (long (), 0) end)
  (* the slices overlap in all but one element: element i becomes what element
     i - 1 was, to the right, and what element i + 1 was, to the left *)
  val () = eqL (lab "copy/long-overlap-to-the-right", [0, 0, 7, 0],
                fn () => let val a = bigArray ()
                         in S.copy {src = S.slice (a, 0, SOME 100001), dst = a, di = 1};
                            List.map (fn i => code (A.sub (a, i))) [0, 1, 50000, 100001] end)
  val () = eqL (lab "copy/long-overlap-to-the-left", [1, 3, 1, 1],
                fn () => let val a = bigArray ()
                         in S.copy {src = S.slice (a, 1, NONE), dst = a, di = 0};
                            List.map (fn i => code (A.sub (a, i))) [0, 50002, 100000, 100001] end)
  val () = eqI (lab "copyVec/long", 0,
                fn () => let val d = A.array (100000, e 7)
                         in S.copyVec {src = VS.slice (V.tabulate (100002, fn i => e (i mod 8)), 1, SOME 100000), dst = d, di = 0};
                            code (A.sub (d, 99999)) end)
  val () = eqOrd (lab "collate/long", EQUAL, fn () => S.collate cmp (long (), long ()))
end

(* Subscript, not Overflow: the page gives the conditions as "i < 0 or j < 0 or
   |arr| < i + j", "i < 0 or |sl| <= i" and "di < 0 or |dst| < di+|src|", which
   hold for the numbers below although i + j, the index in the array, or
   di + |src| does not exist as an int (in the checks labelled sum-* both
   numbers are valid by themselves). *)
functor TestMonoArraySliceOverflowFn (structure A : SPEC_MONO_ARRAY
                                      structure S : SPEC_MONO_ARRAY_SLICE where type array = A.array where type elem = A.elem
                                      val name : string
                                      val elem : A.elem) =
struct
  fun lab s = name ^ "." ^ s
  val most = case Int.maxInt of SOME m => m | NONE => 1073741823
  val least = case Int.minInt of SOME m => m | NONE => ~1073741824
  fun a8 () = A.array (8, elem)
  fun mid () = S.slice (a8 (), 2, SOME 4)
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.slice (a8 (), 1, SOME most))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.slice (a8 (), most, SOME 1))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.slice (a8 (), most, SOME most))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-least-start", T.isSubscript, fn () => S.slice (a8 (), least, SOME 1))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.slice (a8 (), 1, SOME least))
  val () = T.raises (lab "slice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.slice (a8 (), most, NONE))
  val () = T.raises (lab "slice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.slice (a8 (), least, NONE))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME most))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.subslice (mid (), most, SOME 1))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.subslice (mid (), most, SOME most))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME least))
  val () = T.raises (lab "subslice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.subslice (mid (), most, NONE))
  val () = T.raises (lab "subslice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.subslice (mid (), least, NONE))
  val () = T.raises (lab "sub/Subscript-not-Overflow", T.isSubscript, fn () => S.sub (mid (), most))
  val () = T.raises (lab "sub/Subscript-not-Overflow-least", T.isSubscript, fn () => S.sub (mid (), least))
  val () = T.raises (lab "update/Subscript-not-Overflow", T.isSubscript, fn () => S.update (mid (), most, elem))
  val () = T.raises (lab "update/Subscript-not-Overflow-least", T.isSubscript, fn () => S.update (mid (), least, elem))
  val () = T.raises (lab "copy/Subscript-not-Overflow", T.isSubscript, fn () => S.copy {src = mid (), dst = a8 (), di = most})
  val () = T.raises (lab "copy/Subscript-not-Overflow-least", T.isSubscript, fn () => S.copy {src = mid (), dst = a8 (), di = least})
end
