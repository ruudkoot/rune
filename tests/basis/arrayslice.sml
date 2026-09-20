(* requires: ArraySlice VectorSlice Array Vector List *)
(* The ArraySlice structure (signature ARRAY_SLICE). Expected values follow the
   text of https://smlfamily.github.io/Basis/array-slice.html.

   "A slice value can be viewed as a triple (a, i, n), where a is the
   underlying array, i is the starting index, and n is the length of the
   subarray, with the constraint that 0 <= i <= i + n <= |a|."

   The arrays of a check are made inside its thunk: a check never sees the
   updates of another one. The indices that appi, modifyi, foldli, foldri and
   findi pass and return are those "of the corresponding element in the
   slice": they start at 0 whatever the start of the slice in its array is. *)
structure TestArraySlice =
struct
  structure S = ArraySlice

  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val eqO = T.eq (T.option T.int)
  val eqOrd = T.eq T.order
  val eqIL = T.eq (T.list (T.pair (T.int, T.int)))
  val eqIO = T.eq (T.option (T.pair (T.int, T.int)))

  fun arrayToList (a : 'a array) : 'a list = List.tabulate (Array.length a, fn i => Array.sub (a, i))
  fun vectorToList (v : 'a vector) : 'a list = List.tabulate (Vector.length v, fn i => Vector.sub (v, i))
  fun toList (sl : 'a S.slice) : 'a list = List.tabulate (S.length sl, fn i => S.sub (sl, i))

  (* eqS, eqA (label, expected, f): the elements of the slice, or of the array,
     f () are expected. *)
  fun eqS (label, expected : int list, f : unit -> int S.slice) : unit =
    eqL (label, expected, fn () => toList (f ()))
  fun eqA (label, expected : int list, f : unit -> int array) : unit =
    eqL (label, expected, fn () => arrayToList (f ()))

  (* eqBase (label, (l, i, n), f): the base of the slice f () is an array of
     the elements l, the start i and the length n. *)
  val showBase = T.triple (T.list T.int, T.int, T.int)
  fun baseOf (sl : int S.slice) = let val (a, i, n) = S.base sl in (arrayToList a, i, n) end
  fun eqBase (label, expected : int list * int * int, f : unit -> int S.slice) : unit =
    T.eq showBase (label, expected, fn () => baseOf (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end

  fun fromTo (lo, hi) = if lo > hi then [] else lo :: fromTo (lo + 1, hi)

  val l8 = [10, 11, 12, 13, 14, 15, 16, 17]
  fun a8 () = Array.fromList l8
  fun a0 () : int array = Array.fromList []
  fun zeros n = Array.array (n, 0)
  (* 12 13 14 15, in the middle of an array of the elements l8 *)
  val lMid = [12, 13, 14, 15]
  val iMid = [(0, 12), (1, 13), (2, 14), (3, 15)]
  fun midOf a = S.slice (a, 2, SOME 4)
  fun mid () = midOf (a8 ())
  (* an empty slice in the middle of such an array *)
  fun nothing () = S.slice (a8 (), 3, SOME 0)
  val even = fn x => x mod 2 = 0

  (* model (len, i, sz): the start and the length of the slice (i, sz) of a
     sequence of len elements, or NONE where the page says Subscript: "if i < 0
     or |arr| < i" for NONE, "if i < 0 or j < 0 or |arr| < i + j" for SOME j.
     (The arguments of the tests are small: i + j exists.) *)
  fun model (len, i, NONE) = if i < 0 orelse len < i then NONE else SOME (i, len - i)
    | model (len, i, SOME j) = if i < 0 orelse j < 0 orelse len < i + j then NONE else SOME (i, j)
  val sizes = NONE :: List.map SOME (fromTo (~2, 10))
  val arguments = List.concat (List.map (fn i => List.map (fn sz => (i, sz)) sizes) (fromTo (~2, 10)))
  val eqArgs = T.eq (T.list (T.pair (T.int, T.option T.int)))

  (* ---- slice: "If sz is NONE, the slice includes all of the elements to the
     end of the array, i.e., arr[i..|arr|-1]. This raises Subscript if i < 0 or
     |arr| < i. If sz is SOME(j), the slice has length j, that is, it
     corresponds to arr[i..i+j-1]. It raises Subscript if i < 0 or j < 0 or
     |arr| < i + j. Note that, if defined, slice returns an empty slice when
     i = |arr|." ---- *)
  val () = eqS ("ArraySlice.slice/NONE-from-zero", l8, fn () => S.slice (a8 (), 0, NONE))
  val () = eqS ("ArraySlice.slice/NONE-middle", [13, 14, 15, 16, 17], fn () => S.slice (a8 (), 3, NONE))
  val () = eqS ("ArraySlice.slice/NONE-last", [17], fn () => S.slice (a8 (), 7, NONE))
  val () = eqS ("ArraySlice.slice/NONE-at-length", [], fn () => S.slice (a8 (), 8, NONE))
  val () = eqBase ("ArraySlice.slice/NONE-middle-base", (l8, 3, 5), fn () => S.slice (a8 (), 3, NONE))
  val () = eqBase ("ArraySlice.slice/NONE-at-length-base", (l8, 8, 0), fn () => S.slice (a8 (), 8, NONE))
  val () = T.raises ("ArraySlice.slice/NONE-Subscript-negative", T.isSubscript, fn () => S.slice (a8 (), ~1, NONE))
  val () = T.raises ("ArraySlice.slice/NONE-Subscript-beyond", T.isSubscript, fn () => S.slice (a8 (), 9, NONE))
  val () = eqS ("ArraySlice.slice/SOME-middle", lMid, fn () => S.slice (a8 (), 2, SOME 4))
  val () = eqS ("ArraySlice.slice/SOME-whole", l8, fn () => S.slice (a8 (), 0, SOME 8))
  val () = eqS ("ArraySlice.slice/SOME-to-the-end", [15, 16, 17], fn () => S.slice (a8 (), 5, SOME 3))
  val () = eqS ("ArraySlice.slice/SOME-one", [10], fn () => S.slice (a8 (), 0, SOME 1))
  val () = eqS ("ArraySlice.slice/SOME-zero", [], fn () => S.slice (a8 (), 3, SOME 0))
  val () = eqBase ("ArraySlice.slice/SOME-middle-base", (l8, 2, 4), fn () => S.slice (a8 (), 2, SOME 4))
  val () = eqBase ("ArraySlice.slice/SOME-zero-base", (l8, 3, 0), fn () => S.slice (a8 (), 3, SOME 0))
  val () = eqBase ("ArraySlice.slice/SOME-zero-at-length-base", (l8, 8, 0), fn () => S.slice (a8 (), 8, SOME 0))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-negative-start", T.isSubscript, fn () => S.slice (a8 (), ~1, SOME 2))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-negative-start-zero-size", T.isSubscript, fn () => S.slice (a8 (), ~1, SOME 0))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-negative-size", T.isSubscript, fn () => S.slice (a8 (), 2, SOME ~1))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-negative-size-at-length", T.isSubscript, fn () => S.slice (a8 (), 8, SOME ~1))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-one-too-many", T.isSubscript, fn () => S.slice (a8 (), 5, SOME 4))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-whole-and-one", T.isSubscript, fn () => S.slice (a8 (), 0, SOME 9))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-one-at-length", T.isSubscript, fn () => S.slice (a8 (), 8, SOME 1))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-zero-size-beyond", T.isSubscript, fn () => S.slice (a8 (), 9, SOME 0))
  val () = eqBase ("ArraySlice.slice/empty-array-NONE", ([], 0, 0), fn () => S.slice (a0 (), 0, NONE))
  val () = eqBase ("ArraySlice.slice/empty-array-SOME", ([], 0, 0), fn () => S.slice (a0 (), 0, SOME 0))
  val () = T.raises ("ArraySlice.slice/empty-array-NONE-Subscript", T.isSubscript, fn () => S.slice (a0 (), 1, NONE))
  val () = T.raises ("ArraySlice.slice/empty-array-SOME-Subscript", T.isSubscript, fn () => S.slice (a0 (), 0, SOME 1))
  val () = eqB ("ArraySlice.slice/of-the-array-itself", true,
                fn () => let val a = a8 () in #1 (S.base (S.slice (a, 2, SOME 4))) = a end)
  (* every start and size from ~2 to 10: the arguments whose result differs from the model *)
  val () = eqArgs ("ArraySlice.slice/every-argument", [],
                   fn () => List.filter (fn (i, sz) =>
                                (SOME (baseOf (S.slice (a8 (), i, sz))) handle Subscript => NONE)
                                <> Option.map (fn (start, n) => (l8, start, n)) (model (8, i, sz)))
                              arguments)

  (* ---- subslice: "creates a slice based on the given slice sl starting at
     index i of sl. ... This raises Subscript if i < 0 or |sl| < i. ... It
     raises Subscript if i < 0 or j < 0 or |sl| < i + j." The bounds are those
     of the slice, not those of its array. ---- *)
  val () = eqS ("ArraySlice.subslice/NONE-from-zero", lMid, fn () => S.subslice (mid (), 0, NONE))
  val () = eqS ("ArraySlice.subslice/NONE-middle", [13, 14, 15], fn () => S.subslice (mid (), 1, NONE))
  val () = eqS ("ArraySlice.subslice/NONE-at-length", [], fn () => S.subslice (mid (), 4, NONE))
  val () = eqBase ("ArraySlice.subslice/NONE-middle-base", (l8, 3, 3), fn () => S.subslice (mid (), 1, NONE))
  val () = eqBase ("ArraySlice.subslice/NONE-at-length-base", (l8, 6, 0), fn () => S.subslice (mid (), 4, NONE))
  val () = T.raises ("ArraySlice.subslice/NONE-Subscript-negative", T.isSubscript, fn () => S.subslice (mid (), ~1, NONE))
  val () = T.raises ("ArraySlice.subslice/NONE-Subscript-beyond", T.isSubscript, fn () => S.subslice (mid (), 5, NONE))
  val () = eqS ("ArraySlice.subslice/SOME-middle", [13, 14], fn () => S.subslice (mid (), 1, SOME 2))
  val () = eqS ("ArraySlice.subslice/SOME-whole", lMid, fn () => S.subslice (mid (), 0, SOME 4))
  val () = eqS ("ArraySlice.subslice/SOME-to-the-end", [14, 15], fn () => S.subslice (mid (), 2, SOME 2))
  val () = eqBase ("ArraySlice.subslice/SOME-middle-base", (l8, 3, 2), fn () => S.subslice (mid (), 1, SOME 2))
  val () = eqBase ("ArraySlice.subslice/SOME-zero-base", (l8, 3, 0), fn () => S.subslice (mid (), 1, SOME 0))
  val () = eqBase ("ArraySlice.subslice/SOME-zero-at-length-base", (l8, 6, 0), fn () => S.subslice (mid (), 4, SOME 0))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-negative-start", T.isSubscript, fn () => S.subslice (mid (), ~1, SOME 2))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-negative-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME ~1))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-one-too-many", T.isSubscript, fn () => S.subslice (mid (), 3, SOME 2))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-whole-and-one", T.isSubscript, fn () => S.subslice (mid (), 0, SOME 5))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-zero-size-beyond", T.isSubscript, fn () => S.subslice (mid (), 5, SOME 0))
  val () = eqBase ("ArraySlice.subslice/of-subslice", (l8, 4, 1), fn () => S.subslice (S.subslice (mid (), 1, NONE), 1, SOME 1))
  val () = eqBase ("ArraySlice.subslice/of-empty", (l8, 3, 0), fn () => S.subslice (nothing (), 0, NONE))
  val () = T.raises ("ArraySlice.subslice/of-empty-Subscript", T.isSubscript, fn () => S.subslice (nothing (), 1, NONE))
  val () = eqB ("ArraySlice.subslice/of-the-same-array", true,
                fn () => let val a = a8 () in #1 (S.base (S.subslice (midOf a, 1, SOME 2))) = a end)
  val () = eqArgs ("ArraySlice.subslice/every-argument", [],
                   fn () => List.filter (fn (i, sz) =>
                                (SOME (baseOf (S.subslice (mid (), i, sz))) handle Subscript => NONE)
                                <> Option.map (fn (start, n) => (l8, 2 + start, n)) (model (4, i, sz)))
                              arguments)

  (* ---- full: "creates a slice representing the entire array arr. It is
     equivalent to slice(arr, 0, NONE)" ---- *)
  val () = eqS ("ArraySlice.full/basic", l8, fn () => S.full (a8 ()))
  val () = eqBase ("ArraySlice.full/base", (l8, 0, 8), fn () => S.full (a8 ()))
  val () = eqBase ("ArraySlice.full/empty-array", ([], 0, 0), fn () => S.full (a0 ()))
  val () = eqB ("ArraySlice.full/is-slice-0-NONE", true,
                fn () => let val a = a8 () in S.base (S.full a) = S.base (S.slice (a, 0, NONE)) end)
  val () = eqB ("ArraySlice.full/of-the-array-itself", true, fn () => let val a = a8 () in #1 (S.base (S.full a)) = a end)

  (* ---- length: "This is equivalent to #3 (base sl)." ---- *)
  val () = eqI ("ArraySlice.length/full", 8, fn () => S.length (S.full (a8 ())))
  val () = eqI ("ArraySlice.length/middle", 4, fn () => S.length (mid ()))
  val () = eqI ("ArraySlice.length/NONE", 5, fn () => S.length (S.slice (a8 (), 3, NONE)))
  val () = eqI ("ArraySlice.length/empty", 0, fn () => S.length (nothing ()))
  val () = eqI ("ArraySlice.length/empty-array", 0, fn () => S.length (S.full (a0 ())))
  val () = eqB ("ArraySlice.length/is-third-of-base", true, fn () => let val sl = mid () in S.length sl = #3 (S.base sl) end)

  (* ---- sub: "returns the i(th) element of the slice sl. If i < 0 or
     |sl| <= i, then the Subscript exception is raised." The array has elements
     on both sides of mid (). ---- *)
  val () = eqI ("ArraySlice.sub/first", 12, fn () => S.sub (mid (), 0))
  val () = eqI ("ArraySlice.sub/middle", 13, fn () => S.sub (mid (), 1))
  val () = eqI ("ArraySlice.sub/last", 15, fn () => S.sub (mid (), 3))
  val () = eqI ("ArraySlice.sub/sees-Array.update", 99,
                fn () => let val a = a8 () val sl = midOf a in Array.update (a, 3, 99); S.sub (sl, 1) end)
  val () = T.raises ("ArraySlice.sub/Subscript-length", T.isSubscript, fn () => S.sub (mid (), 4))
  val () = T.raises ("ArraySlice.sub/Subscript-negative", T.isSubscript, fn () => S.sub (mid (), ~1))
  val () = T.raises ("ArraySlice.sub/Subscript-beyond-the-array", T.isSubscript, fn () => S.sub (mid (), 6))
  val () = T.raises ("ArraySlice.sub/Subscript-before-the-array", T.isSubscript, fn () => S.sub (mid (), ~3))
  val () = T.raises ("ArraySlice.sub/Subscript-empty", T.isSubscript, fn () => S.sub (nothing (), 0))
  val () = T.raises ("ArraySlice.sub/Subscript-full", T.isSubscript, fn () => S.sub (S.full (a8 ()), 8))

  (* ---- update: "sets the i(th) element of the slice sl to a. If i < 0 or
     |sl| <= i, then the Subscript exception is raised." ---- *)
  val () = eqA ("ArraySlice.update/first", [10, 11, 99, 13, 14, 15, 16, 17],
                fn () => let val a = a8 () in S.update (midOf a, 0, 99); a end)
  val () = eqA ("ArraySlice.update/last", [10, 11, 12, 13, 14, 99, 16, 17],
                fn () => let val a = a8 () in S.update (midOf a, 3, 99); a end)
  val () = eqA ("ArraySlice.update/twice-same-index", [10, 11, 12, 98, 14, 15, 16, 17],
                fn () => let val a = a8 () in S.update (midOf a, 1, 99); S.update (midOf a, 1, 98); a end)
  val () = eqI ("ArraySlice.update/seen-by-sub", 99, fn () => let val sl = mid () in S.update (sl, 2, 99); S.sub (sl, 2) end)
  val () = eqI ("ArraySlice.update/seen-through-another-slice", 99,
                fn () => let val a = a8 () in S.update (midOf a, 2, 99); S.sub (S.full a, 4) end)
  val () = eqA ("ArraySlice.update/full", [10, 11, 12, 13, 14, 15, 16, 99],
                fn () => let val a = a8 () in S.update (S.full a, 7, 99); a end)
  (* The negative index is read from a ref: the compiler of Poly/ML 5.7.1 stops
     with "Overflow unexpectedly raised while compiling" on Array.update with
     the constant index ~1. *)
  val minusOne = ref ~1
  val () = T.raises ("ArraySlice.update/Subscript-length", T.isSubscript, fn () => S.update (mid (), 4, 99))
  val () = T.raises ("ArraySlice.update/Subscript-negative", T.isSubscript, fn () => S.update (mid (), !minusOne, 99))
  val () = T.raises ("ArraySlice.update/Subscript-beyond-the-array", T.isSubscript, fn () => S.update (mid (), 6, 99))
  val () = T.raises ("ArraySlice.update/Subscript-empty", T.isSubscript, fn () => S.update (nothing (), 0, 99))
  val () = eqA ("ArraySlice.update/Subscript-changes-nothing", l8,
                fn () => let val a = a8 ()
                         in S.update (midOf a, 4, 99) handle Subscript => ();
                            S.update (midOf a, !minusOne, 99) handle Subscript => ();
                            a
                         end)

  (* ---- base: "returns a triple (arr, i, n) representing the concrete
     representation of the slice. arr is the underlying array" ---- *)
  val () = eqBase ("ArraySlice.base/middle", (l8, 2, 4), mid)
  val () = eqBase ("ArraySlice.base/empty", (l8, 3, 0), nothing)
  val () = eqB ("ArraySlice.base/the-array-itself", true,
                fn () => let val a = a8 () val (b, _, _) = S.base (midOf a) in Array.update (b, 0, 99); a = b andalso Array.sub (a, 0) = 99 end)

  (* ---- vector: "the result is equivalent to
     Vector.tabulate (length sl, fn i => sub (sl, i))" ---- *)
  val () = eqL ("ArraySlice.vector/middle", lMid, fn () => vectorToList (S.vector (mid ())))
  val () = eqL ("ArraySlice.vector/full", l8, fn () => vectorToList (S.vector (S.full (a8 ()))))
  val () = eqL ("ArraySlice.vector/empty", [], fn () => vectorToList (S.vector (nothing ())))
  val () = eqB ("ArraySlice.vector/equals-tabulate", true,
                fn () => let val sl = mid () in S.vector sl = Vector.tabulate (S.length sl, fn i => S.sub (sl, i)) end)
  val () = eqL ("ArraySlice.vector/is-a-snapshot", lMid,
                fn () => let val sl = mid () val v = S.vector sl in S.update (sl, 0, 99); vectorToList v end)

  (* ---- copy: "copy the given slice into the array dst, with the i(th)
     element of src, for 0 <= i < |src|, being copied to position di + i in the
     destination array. If di < 0 or if |dst| < di+|src|, then the Subscript
     exception is raised." ---- *)
  val () = eqA ("ArraySlice.copy/start", [12, 13, 14, 15, 0, 0],
                fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 0}; d end)
  val () = eqA ("ArraySlice.copy/middle", [0, 12, 13, 14, 15, 0],
                fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 1}; d end)
  val () = eqA ("ArraySlice.copy/end", [0, 0, 12, 13, 14, 15],
                fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 2}; d end)
  val () = eqA ("ArraySlice.copy/whole", lMid, fn () => let val d = zeros 4 in S.copy {src = mid (), dst = d, di = 0}; d end)
  val () = eqA ("ArraySlice.copy/field-order", [0, 12, 13, 14, 15, 0],
                fn () => let val d = zeros 6 in S.copy {di = 1, dst = d, src = mid ()}; d end)
  val () = eqA ("ArraySlice.copy/src-unchanged", l8,
                fn () => let val a = a8 () in S.copy {src = midOf a, dst = zeros 6, di = 1}; a end)
  val () = eqA ("ArraySlice.copy/empty-src", [0, 0, 0], fn () => let val d = zeros 3 in S.copy {src = nothing (), dst = d, di = 1}; d end)
  val () = eqA ("ArraySlice.copy/empty-src-at-length", [0, 0, 0],
                fn () => let val d = zeros 3 in S.copy {src = nothing (), dst = d, di = 3}; d end)
  val () = eqA ("ArraySlice.copy/empty-to-empty", [], fn () => let val d = a0 () in S.copy {src = nothing (), dst = d, di = 0}; d end)
  val () = T.raises ("ArraySlice.copy/Subscript-too-far", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 6, di = 3})
  val () = T.raises ("ArraySlice.copy/Subscript-negative", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 6, di = !minusOne})
  val () = T.raises ("ArraySlice.copy/Subscript-src-longer", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 3, di = 0})
  val () = T.raises ("ArraySlice.copy/Subscript-to-empty", T.isSubscript, fn () => S.copy {src = mid (), dst = a0 (), di = 0})
  val () = T.raises ("ArraySlice.copy/Subscript-empty-src-beyond", T.isSubscript, fn () => S.copy {src = nothing (), dst = zeros 3, di = 4})
  val () = T.raises ("ArraySlice.copy/Subscript-empty-src-negative", T.isSubscript,
                     fn () => S.copy {src = nothing (), dst = zeros 3, di = !minusOne})
  (* The page does not say what is left in dst when Subscript is raised; the
     test takes it that nothing is copied, as the condition is on the arguments
     alone. *)
  val () = eqA ("ArraySlice.copy/Subscript-changes-nothing", [0, 0, 0, 0, 0, 0],
                fn () => let val d = zeros 6 in S.copy {src = mid (), dst = d, di = 3} handle Subscript => (); d end)
  (* "The copy function must correctly handle the case in which dst and the
     base array of src are equal, and the source and destination slices
     overlap": the elements 2 3 4 5 6 of 0 .. 9 arrive as they were before the
     copy, whichever way they move. *)
  fun a10 () = Array.tabulate (10, fn i => i)
  fun within di = let val a = a10 () in S.copy {src = S.slice (a, 2, SOME 5), dst = a, di = di}; a end
  val () = eqA ("ArraySlice.copy/overlap-to-the-right", [0, 1, 2, 3, 2, 3, 4, 5, 6, 9], fn () => within 4)
  val () = eqA ("ArraySlice.copy/overlap-one-to-the-right", [0, 1, 2, 2, 3, 4, 5, 6, 8, 9], fn () => within 3)
  val () = eqA ("ArraySlice.copy/overlap-onto-itself", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], fn () => within 2)
  val () = eqA ("ArraySlice.copy/overlap-one-to-the-left", [0, 2, 3, 4, 5, 6, 6, 7, 8, 9], fn () => within 1)
  val () = eqA ("ArraySlice.copy/overlap-to-the-left", [2, 3, 4, 5, 6, 5, 6, 7, 8, 9], fn () => within 0)
  val () = eqA ("ArraySlice.copy/overlap-to-the-end", [0, 1, 2, 3, 4, 2, 3, 4, 5, 6], fn () => within 5)
  val () = T.raises ("ArraySlice.copy/overlap-Subscript", T.isSubscript, fn () => within 6)
  val () = eqA ("ArraySlice.copy/same-array-apart", [0, 1, 2, 3, 4, 5, 6, 0, 1, 2],
                fn () => let val a = a10 () in S.copy {src = S.slice (a, 0, SOME 3), dst = a, di = 7}; a end)
  val () = eqA ("ArraySlice.copy/full-onto-itself", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
                fn () => let val a = a10 () in S.copy {src = S.full a, dst = a, di = 0}; a end)
  val () = T.raises ("ArraySlice.copy/full-onto-itself-shifted-Subscript", T.isSubscript,
                     fn () => let val a = a10 () in S.copy {src = S.full a, dst = a, di = 1} end)

  (* ---- copyVec: as copy, from a slice of a vector ---- *)
  val v8 = Vector.fromList l8
  fun vmid () = VectorSlice.slice (v8, 2, SOME 4)
  fun vnothing () = VectorSlice.slice (v8, 3, SOME 0)
  val () = eqA ("ArraySlice.copyVec/start", [12, 13, 14, 15, 0, 0],
                fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 0}; d end)
  val () = eqA ("ArraySlice.copyVec/middle", [0, 12, 13, 14, 15, 0],
                fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 1}; d end)
  val () = eqA ("ArraySlice.copyVec/end", [0, 0, 12, 13, 14, 15],
                fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 2}; d end)
  val () = eqA ("ArraySlice.copyVec/whole", lMid, fn () => let val d = zeros 4 in S.copyVec {src = vmid (), dst = d, di = 0}; d end)
  val () = eqA ("ArraySlice.copyVec/full-vector", [0] @ l8,
                fn () => let val d = zeros 9 in S.copyVec {src = VectorSlice.full v8, dst = d, di = 1}; d end)
  val () = eqA ("ArraySlice.copyVec/field-order", [0, 12, 13, 14, 15, 0],
                fn () => let val d = zeros 6 in S.copyVec {di = 1, dst = d, src = vmid ()}; d end)
  val () = eqA ("ArraySlice.copyVec/empty-src", [0, 0, 0], fn () => let val d = zeros 3 in S.copyVec {src = vnothing (), dst = d, di = 1}; d end)
  val () = eqA ("ArraySlice.copyVec/empty-src-at-length", [0, 0, 0],
                fn () => let val d = zeros 3 in S.copyVec {src = vnothing (), dst = d, di = 3}; d end)
  val () = eqA ("ArraySlice.copyVec/empty-to-empty", [], fn () => let val d = a0 () in S.copyVec {src = vnothing (), dst = d, di = 0}; d end)
  val () = T.raises ("ArraySlice.copyVec/Subscript-too-far", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 6, di = 3})
  val () = T.raises ("ArraySlice.copyVec/Subscript-negative", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 6, di = !minusOne})
  val () = T.raises ("ArraySlice.copyVec/Subscript-src-longer", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 3, di = 0})
  val () = T.raises ("ArraySlice.copyVec/Subscript-to-empty", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = a0 (), di = 0})
  val () = T.raises ("ArraySlice.copyVec/Subscript-empty-src-beyond", T.isSubscript,
                     fn () => S.copyVec {src = vnothing (), dst = zeros 3, di = 4})
  val () = T.raises ("ArraySlice.copyVec/Subscript-empty-src-negative", T.isSubscript,
                     fn () => S.copyVec {src = vnothing (), dst = zeros 3, di = !minusOne})
  (* As for copy: the test takes it that nothing is copied when Subscript is raised. *)
  val () = eqA ("ArraySlice.copyVec/Subscript-changes-nothing", [0, 0, 0, 0, 0, 0],
                fn () => let val d = zeros 6 in S.copyVec {src = vmid (), dst = d, di = 3} handle Subscript => (); d end)

  (* ---- isEmpty: "returns true if sl has length 0" ---- *)
  val () = eqB ("ArraySlice.isEmpty/empty", true, fn () => S.isEmpty (nothing ()))
  val () = eqB ("ArraySlice.isEmpty/empty-array", true, fn () => S.isEmpty (S.full (a0 ())))
  val () = eqB ("ArraySlice.isEmpty/at-length", true, fn () => S.isEmpty (S.slice (a8 (), 8, NONE)))
  val () = eqB ("ArraySlice.isEmpty/one", false, fn () => S.isEmpty (S.slice (a8 (), 7, NONE)))
  val () = eqB ("ArraySlice.isEmpty/middle", false, fn () => S.isEmpty (mid ()))

  (* ---- getItem: "returns the first item in sl and the rest of the slice, or
     NONE if sl is empty" ---- *)
  val eqItem = T.eq (T.option (T.pair (T.int, showBase)))
  fun getItem sl = Option.map (fn (x, rest) => (x, baseOf rest)) (S.getItem sl)
  val () = eqItem ("ArraySlice.getItem/middle", SOME (12, (l8, 3, 3)), fn () => getItem (mid ()))
  val () = eqItem ("ArraySlice.getItem/full", SOME (10, (l8, 1, 7)), fn () => getItem (S.full (a8 ())))
  val () = eqItem ("ArraySlice.getItem/one", SOME (13, (l8, 4, 0)), fn () => getItem (S.slice (a8 (), 3, SOME 1)))
  val () = eqItem ("ArraySlice.getItem/last-of-the-array", SOME (17, (l8, 8, 0)), fn () => getItem (S.slice (a8 (), 7, NONE)))
  val () = eqItem ("ArraySlice.getItem/empty", NONE, fn () => getItem (nothing ()))
  val () = eqItem ("ArraySlice.getItem/empty-array", NONE, fn () => getItem (S.full (a0 ())))
  fun items sl = case S.getItem sl of NONE => [] | SOME (x, rest) => x :: items rest
  val () = eqL ("ArraySlice.getItem/repeated", lMid, fn () => items (mid ()))
  val () = eqB ("ArraySlice.getItem/rest-of-the-same-array", true,
                fn () => let val a = a8 ()
                         in case S.getItem (midOf a) of SOME (_, rest) => #1 (S.base rest) = a | NONE => false end)

  (* ---- appi, app: "apply the function f to the elements of a slice in order
     of increasing indices. The more general appi function supplies f with the
     index of the corresponding element in the slice." ---- *)
  val () = eqIL ("ArraySlice.appi/index-in-the-slice", iMid,
                 fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (mid ()); seen () end)
  val () = eqIL ("ArraySlice.appi/full", [(0, 5), (1, 6)],
                 fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (S.full (Array.fromList [5, 6])); seen () end)
  val () = eqIL ("ArraySlice.appi/empty", [],
                 fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (nothing ()); seen () end)
  val () = eqL ("ArraySlice.app/order", lMid,
                fn () => let val (f, seen) = trace (fn _ => ()) in S.app f (mid ()); seen () end)
  val () = eqL ("ArraySlice.app/empty", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in S.app f (nothing ()); seen () end)
  val () = eqA ("ArraySlice.app/array-unchanged", l8, fn () => let val a = a8 () in S.app (fn _ => ()) (midOf a); a end)

  (* ---- modifyi, modify: "apply the function f to the elements of a slice in
     order of increasing indices, and replace each element with the result.
     The more general modifyi supplies f with the index of the corresponding
     element in the slice." ---- *)
  val () = eqA ("ArraySlice.modifyi/index-in-the-slice", [10, 11, 12, 113, 214, 315, 16, 17],
                fn () => let val a = a8 () in S.modifyi (fn (i, x) => 100 * i + x) (midOf a); a end)
  val () = eqA ("ArraySlice.modifyi/full", [0, 11, 24], fn () => let val a = Array.fromList [10, 11, 12] in S.modifyi (op * ) (S.full a); a end)
  val () = eqA ("ArraySlice.modifyi/empty", l8, fn () => let val a = a8 () in S.modifyi (op +) (S.slice (a, 3, SOME 0)); a end)
  val () = eqIL ("ArraySlice.modifyi/order", iMid,
                 fn () => let val (f, seen) = trace (fn (_, x) => x + 1) in S.modifyi f (mid ()); seen () end)
  val () = eqA ("ArraySlice.modify/basic", [10, 11, 24, 26, 28, 30, 16, 17],
                fn () => let val a = a8 () in S.modify (fn x => 2 * x) (midOf a); a end)
  val () = eqA ("ArraySlice.modify/empty", l8, fn () => let val a = a8 () in S.modify (fn x => 2 * x) (S.slice (a, 3, SOME 0)); a end)
  val () = eqL ("ArraySlice.modify/order", lMid,
                fn () => let val (f, seen) = trace (fn x => x + 1) in S.modify f (mid ()); seen () end)
  val () = eqA ("ArraySlice.modify/twice", [10, 11, 48, 52, 56, 60, 16, 17],
                fn () => let val a = a8 () in S.modify (fn x => 2 * x) (midOf a); S.modify (fn x => 2 * x) (midOf a); a end)
  val () = eqL ("ArraySlice.modify/seen-by-the-slice", [13, 14, 15, 16],
                fn () => let val sl = mid () in S.modify (fn x => x + 1) sl; toList sl end)

  (* ---- foldli, foldri, foldl, foldr: "foldli and foldl apply the function f
     from left to right (increasing indices), while the functions foldri and
     foldr work from right to left (decreasing indices). The more general
     functions foldli and foldri supply f with the index of the corresponding
     element in the slice."
     With f (i, a, x) = i * a - 2 * x over the slice [12, 13, 14, 15]:
       foldli: 0*12-0 = 0, 1*13-0 = 13, 2*14-26 = 2, 3*15-4 = 41;
       foldri: 3*15-0 = 45, 2*14-90 = ~62, 1*13+124 = 137, 0*12-274 = ~274.
     With f (a, x) = a - 2 * x:
       foldl: 12-0 = 12, 13-24 = ~11, 14+22 = 36, 15-72 = ~57;
       foldr: 15-0 = 15, 14-30 = ~16, 13+32 = 45, 12-90 = ~78. ---- *)
  val () = eqIL ("ArraySlice.foldli/conses-reversed", List.rev iMid,
                 fn () => S.foldli (fn (i, a, l) => (i, a) :: l) [] (mid ()))
  val () = eqI ("ArraySlice.foldli/nonassociative", 41, fn () => S.foldli (fn (i, a, x) => i * a - 2 * x) 0 (mid ()))
  val () = eqI ("ArraySlice.foldli/empty", 42, fn () => S.foldli (fn (i, a, x) => i + a + x) 42 (nothing ()))
  val () = eqIL ("ArraySlice.foldri/conses-in-order", iMid, fn () => S.foldri (fn (i, a, l) => (i, a) :: l) [] (mid ()))
  val () = eqI ("ArraySlice.foldri/nonassociative", ~274, fn () => S.foldri (fn (i, a, x) => i * a - 2 * x) 0 (mid ()))
  val () = eqI ("ArraySlice.foldri/empty", 42, fn () => S.foldri (fn (i, a, x) => i + a + x) 42 (nothing ()))
  val () = eqL ("ArraySlice.foldl/conses-reversed", List.rev lMid, fn () => S.foldl (op ::) [] (mid ()))
  val () = eqI ("ArraySlice.foldl/nonassociative", ~57, fn () => S.foldl (fn (a, x) => a - 2 * x) 0 (mid ()))
  val () = eqI ("ArraySlice.foldl/empty", 42, fn () => S.foldl (op +) 42 (nothing ()))
  val () = eqL ("ArraySlice.foldr/conses-in-order", lMid, fn () => S.foldr (op ::) [] (mid ()))
  val () = eqI ("ArraySlice.foldr/nonassociative", ~78, fn () => S.foldr (fn (a, x) => a - 2 * x) 0 (mid ()))
  val () = eqI ("ArraySlice.foldr/empty", 42, fn () => S.foldr (op +) 42 (nothing ()))

  (* ---- findi, find: "in order of increasing indices, until a true value is
     returned"; findi "also supplies f with the index of the element in the
     slice and, upon finding an entry satisfying the predicate, returns that
     index with the element" ---- *)
  val () = eqIO ("ArraySlice.findi/first-match", SOME (1, 13), fn () => S.findi (fn (_, a) => a > 12) (mid ()))
  val () = eqIO ("ArraySlice.findi/by-index", SOME (3, 15), fn () => S.findi (fn (i, _) => i = 3) (mid ()))
  val () = eqIO ("ArraySlice.findi/index-zero", SOME (0, 12), fn () => S.findi (fn _ => true) (mid ()))
  val () = eqIO ("ArraySlice.findi/none", NONE, fn () => S.findi (fn (_, a) => a > 15) (mid ()))
  val () = eqIO ("ArraySlice.findi/not-before-the-slice", NONE, fn () => S.findi (fn (_, a) => a < 12) (mid ()))
  val () = eqIO ("ArraySlice.findi/empty", NONE, fn () => S.findi (fn _ => true) (nothing ()))
  val () = eqIL ("ArraySlice.findi/stops", [(0, 12), (1, 13)],
                 fn () => let val (f, seen) = trace (fn (_, a) => a = 13) in ignore (S.findi f (mid ())); seen () end)
  val () = eqIL ("ArraySlice.findi/order", iMid,
                 fn () => let val (f, seen) = trace (fn _ => false) in ignore (S.findi f (mid ())); seen () end)
  val () = eqO ("ArraySlice.find/first-match", SOME 13, fn () => S.find (not o even) (mid ()))
  val () = eqO ("ArraySlice.find/last-element", SOME 15, fn () => S.find (fn x => x > 14) (mid ()))
  val () = eqO ("ArraySlice.find/none", NONE, fn () => S.find (fn x => x > 15) (mid ()))
  val () = eqO ("ArraySlice.find/not-before-the-slice", NONE, fn () => S.find (fn x => x < 12) (mid ()))
  val () = eqO ("ArraySlice.find/empty", NONE, fn () => S.find (fn _ => true) (nothing ()))
  val () = eqL ("ArraySlice.find/stops", [12, 13],
                fn () => let val (f, seen) = trace (not o even) in ignore (S.find f (mid ())); seen () end)

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB ("ArraySlice.exists/true", true, fn () => S.exists (fn x => x = 14) (mid ()))
  val () = eqB ("ArraySlice.exists/false", false, fn () => S.exists (fn x => x = 9) (mid ()))
  val () = eqB ("ArraySlice.exists/not-outside-the-slice", false, fn () => S.exists (fn x => x = 11 orelse x = 16) (mid ()))
  val () = eqB ("ArraySlice.exists/empty", false, fn () => S.exists (fn _ => true) (nothing ()))
  val () = eqL ("ArraySlice.exists/stops", [12, 13, 14],
                fn () => let val (f, seen) = trace (fn x => x = 14) in ignore (S.exists f (mid ())); seen () end)
  val () = eqL ("ArraySlice.exists/order", lMid,
                fn () => let val (f, seen) = trace (fn _ => false) in ignore (S.exists f (mid ())); seen () end)
  val () = eqB ("ArraySlice.all/true", true, fn () => S.all (fn x => x >= 12 andalso x <= 15) (mid ()))
  val () = eqB ("ArraySlice.all/false", false, fn () => S.all (fn x => x < 14) (mid ()))
  val () = eqB ("ArraySlice.all/empty", true, fn () => S.all (fn _ => false) (nothing ()))
  val () = eqL ("ArraySlice.all/stops", [12, 13, 14],
                fn () => let val (f, seen) = trace (fn x => x < 14) in ignore (S.all f (mid ())); seen () end)
  val () = eqL ("ArraySlice.all/order", lMid,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (S.all f (mid ())); seen () end)

  (* ---- collate: "lexicographic comparison of the two slices using the given
     ordering f on elements" ---- *)
  fun part (i, n) = S.slice (Array.fromList [1, 2, 1, 2, 3, 0], i, SOME n)
  val () = eqOrd ("ArraySlice.collate/equal-elements", EQUAL, fn () => S.collate Int.compare (part (0, 2), part (2, 2)))
  val () = eqOrd ("ArraySlice.collate/parts-of-one-array", EQUAL,
                  fn () => let val a = Array.fromList [1, 2, 1, 2] in S.collate Int.compare (S.slice (a, 0, SOME 2), S.slice (a, 2, NONE)) end)
  val () = eqOrd ("ArraySlice.collate/same-slice", EQUAL, fn () => let val sl = mid () in S.collate Int.compare (sl, sl) end)
  val () = eqOrd ("ArraySlice.collate/empty-empty", EQUAL, fn () => S.collate Int.compare (part (1, 0), part (4, 0)))
  val () = eqOrd ("ArraySlice.collate/empty-less", LESS, fn () => S.collate Int.compare (part (1, 0), part (5, 1)))
  val () = eqOrd ("ArraySlice.collate/empty-greater", GREATER, fn () => S.collate Int.compare (part (5, 1), part (1, 0)))
  val () = eqOrd ("ArraySlice.collate/prefix-less", LESS, fn () => S.collate Int.compare (part (0, 2), part (2, 3)))
  val () = eqOrd ("ArraySlice.collate/prefix-greater", GREATER, fn () => S.collate Int.compare (part (2, 3), part (0, 2)))
  val () = eqOrd ("ArraySlice.collate/first-difference", GREATER, fn () => S.collate Int.compare (part (3, 3), part (1, 3)))
  val () = eqOrd ("ArraySlice.collate/not-by-length", LESS, fn () => S.collate Int.compare (part (0, 4), part (1, 1)))
  val () = eqOrd ("ArraySlice.collate/ends-with-the-slice", EQUAL,
                  fn () => S.collate Int.compare (S.slice (Array.fromList [1, 2, 3], 0, SOME 2), S.slice (Array.fromList [1, 2, 4], 0, SOME 2)))
  val () = eqOrd ("ArraySlice.collate/starts-with-the-slice", EQUAL,
                  fn () => S.collate Int.compare (S.slice (Array.fromList [0, 2, 3], 1, NONE), S.slice (Array.fromList [9, 2, 3], 1, NONE)))
  val () = eqOrd ("ArraySlice.collate/given-ordering", GREATER,
                  fn () => S.collate (fn (a, b) => Int.compare (b, a)) (part (0, 4), part (1, 1)))
  val () = eqOrd ("ArraySlice.collate/argument-order", LESS,
                  fn () => S.collate (fn (a, b) => if a = 1 andalso b = 2 then LESS else GREATER) (part (0, 1), part (1, 1)))

  (* ---- laws, on pseudo-random slices, against lists ---- *)
  fun randomList n = List.tabulate (n, fn _ => T.range (~50, 50))
  fun indexed l = List.tabulate (List.length l, fn j => (j, List.nth (l, j)))
  val () = T.seed 9
  val () = T.repeat (40, fn k =>
    let
      val n = Int.toString k
      val whole = randomList (T.range (0, 12))
      val len = List.length whole
      val start = T.range (0, len)
      val size = T.range (0, len - start)
      val pre = List.take (whole, start)
      val l = List.take (List.drop (whole, start), size)       (* the elements of the slice *)
      val post = List.drop (whole, start + size)
      (* withSlice f: f applied to a new array of the elements whole and the
         slice of it, and then that array *)
      fun withSlice f = let val a = Array.fromList whole in ignore (f (a, S.slice (a, start, SOME size))); a end
      fun sl () = S.slice (Array.fromList whole, start, SOME size)
      (* another slice, of another array *)
      val whole2 = randomList (T.range (0, 6))
      val start2 = T.range (0, List.length whole2)
      val l2 = List.drop (whole2, start2)
      fun sl2 () = S.slice (Array.fromList whole2, start2, NONE)
      (* arguments for slice and subslice that are valid, or just not *)
      val i = T.range (~1, len + 1)
      val sz = if T.range (0, 3) = 0 then NONE else SOME (T.range (~1, len + 1))
      val j = T.range (0, size)             (* 0 <= j <= size *)
      val x = T.range (~50, 50)
      (* a destination of 0..4 more elements than the slice, and an offset into
         it that is valid, or one too large; and an offset into the array of
         the slice itself *)
      val d = randomList (size + T.range (0, 4))
      val di = T.range (0, List.length d - size + 1)
      val own = T.range (0, len - size + 1)
      val fi = fn (j, e) => 3 * j - e
      val gi = fn (j, e, b) => j * e - 2 * b
      val g = fn (e, b) => e - 2 * b
      val pi = fn (j, e) => (j + e) mod 5 = 0
      val p = fn e => e mod 5 = 0
    in
      T.eq (T.option showBase) ("ArraySlice.slice/model-" ^ n, Option.map (fn (a, b) => (whole, a, b)) (model (len, i, sz)),
                                fn () => SOME (baseOf (S.slice (Array.fromList whole, i, sz))) handle Subscript => NONE);
      T.eq (T.option showBase) ("ArraySlice.subslice/model-" ^ n,
                                Option.map (fn (a, b) => (whole, start + a, b)) (model (size, i, sz)),
                                fn () => SOME (baseOf (S.subslice (sl (), i, sz))) handle Subscript => NONE);
      eqBase ("ArraySlice.full/model-" ^ n, (whole, 0, len), fn () => S.full (Array.fromList whole));
      eqBase ("ArraySlice.base/model-" ^ n, (whole, start, size), sl);
      eqI ("ArraySlice.length/model-" ^ n, size, fn () => S.length (sl ()));
      (if j < size
       then (eqI ("ArraySlice.sub/model-" ^ n, List.nth (l, j), fn () => S.sub (sl (), j));
             eqA ("ArraySlice.update/model-" ^ n, pre @ List.take (l, j) @ [x] @ List.drop (l, j + 1) @ post,
                  fn () => withSlice (fn (_, s) => S.update (s, j, x))))
       else (T.raises ("ArraySlice.sub/model-" ^ n, T.isSubscript, fn () => S.sub (sl (), j));
             T.raises ("ArraySlice.update/model-" ^ n, T.isSubscript, fn () => S.update (sl (), j, x))));
      eqL ("ArraySlice.vector/model-" ^ n, l, fn () => vectorToList (S.vector (sl ())));
      (if di + size <= List.length d
       then (eqA ("ArraySlice.copy/model-" ^ n, List.take (d, di) @ l @ List.drop (d, di + size),
                  fn () => let val b = Array.fromList d in S.copy {src = sl (), dst = b, di = di}; b end);
             eqA ("ArraySlice.copyVec/model-" ^ n, List.take (d, di) @ l @ List.drop (d, di + size),
                  fn () => let val b = Array.fromList d
                           in S.copyVec {src = VectorSlice.slice (Vector.fromList whole, start, SOME size), dst = b, di = di}; b end))
       else (T.raises ("ArraySlice.copy/model-" ^ n, T.isSubscript,
                       fn () => S.copy {src = sl (), dst = Array.fromList d, di = di});
             T.raises ("ArraySlice.copyVec/model-" ^ n, T.isSubscript,
                       fn () => S.copyVec {src = VectorSlice.slice (Vector.fromList whole, start, SOME size),
                                           dst = Array.fromList d, di = di})));
      (if own + size <= len
       then eqA ("ArraySlice.copy/within-model-" ^ n, List.take (whole, own) @ l @ List.drop (whole, own + size),
                 fn () => withSlice (fn (a, s) => S.copy {src = s, dst = a, di = own}))
       else T.raises ("ArraySlice.copy/within-model-" ^ n, T.isSubscript,
                      fn () => withSlice (fn (a, s) => S.copy {src = s, dst = a, di = own})));
      eqB ("ArraySlice.isEmpty/model-" ^ n, size = 0, fn () => S.isEmpty (sl ()));
      eqL ("ArraySlice.getItem/model-" ^ n, l, fn () => items (sl ()));
      eqIL ("ArraySlice.appi/model-" ^ n, indexed l,
            fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (sl ()); seen () end);
      eqL ("ArraySlice.app/model-" ^ n, l,
           fn () => let val (f, seen) = trace (fn _ => ()) in S.app f (sl ()); seen () end);
      eqA ("ArraySlice.modifyi/model-" ^ n, pre @ List.map fi (indexed l) @ post,
           fn () => withSlice (fn (_, s) => S.modifyi fi s));
      eqA ("ArraySlice.modify/model-" ^ n, pre @ List.map (fn e => e * e) l @ post,
           fn () => withSlice (fn (_, s) => S.modify (fn e => e * e) s));
      eqI ("ArraySlice.foldli/model-" ^ n, List.foldl (fn ((j, e), b) => gi (j, e, b)) 1 (indexed l),
           fn () => S.foldli gi 1 (sl ()));
      eqI ("ArraySlice.foldri/model-" ^ n, List.foldr (fn ((j, e), b) => gi (j, e, b)) 1 (indexed l),
           fn () => S.foldri gi 1 (sl ()));
      eqI ("ArraySlice.foldl/model-" ^ n, List.foldl g 1 l, fn () => S.foldl g 1 (sl ()));
      eqI ("ArraySlice.foldr/model-" ^ n, List.foldr g 1 l, fn () => S.foldr g 1 (sl ()));
      eqIO ("ArraySlice.findi/model-" ^ n, List.find pi (indexed l), fn () => S.findi pi (sl ()));
      eqO ("ArraySlice.find/model-" ^ n, List.find p l, fn () => S.find p (sl ()));
      eqB ("ArraySlice.exists/model-" ^ n, List.exists p l, fn () => S.exists p (sl ()));
      eqB ("ArraySlice.all/model-" ^ n, List.all (not o p) l, fn () => S.all (not o p) (sl ()));
      eqB ("ArraySlice.all/de-morgan-" ^ n, true,
           fn () => S.all p (sl ()) = not (S.exists (not o p) (sl ())));
      eqOrd ("ArraySlice.collate/model-" ^ n, List.collate Int.compare (l, l2),
             fn () => S.collate Int.compare (sl (), sl2 ()))
    end)

  (* ---- long slices: no stack or quadratic trouble ---- *)
  fun big () = Array.tabulate (200002, fn i => i)
  fun long () = S.slice (big (), 1, SOME 200000)
  val () = eqI ("ArraySlice.foldr/long-list", 200000, fn () => List.length (S.foldr (op ::) [] (long ())))
  val () = eqI ("ArraySlice.foldl/long", 200000, fn () => S.foldl Int.max 0 (long ()))
  val () = eqI ("ArraySlice.modify/long", 200001, fn () => let val sl = long () in S.modify (fn x => x + 1) sl; S.sub (sl, 199999) end)
  val () = eqI ("ArraySlice.vector/long", 200000, fn () => Vector.length (S.vector (long ())))
  val () = eqL ("ArraySlice.copy/long-overlap", [0, 1, 1, 2, 199999, 200000],
                fn () => let val a = big ()
                         in S.copy {src = S.slice (a, 1, SOME 200000), dst = a, di = 2};
                            List.map (fn i => Array.sub (a, i)) [0, 1, 2, 3, 200000, 200001]
                         end)
  val () = eqOrd ("ArraySlice.collate/long", EQUAL, fn () => S.collate Int.compare (long (), long ()))

  (*<< overflow *)
  (* ---- Subscript, not Overflow: the page gives the conditions as "i < 0 or
     j < 0 or |arr| < i + j", "i < 0 or |sl| <= i" and "di < 0 or
     |dst| < di+|src|", which hold for the numbers below although i + j, di +
     |src|, or the index in the array, does not exist as an int (in the checks
     labelled sum-* both numbers are valid by themselves). ---- *)
  val most = case Int.maxInt of SOME m => m | NONE => 1073741823
  val least = case Int.minInt of SOME m => m | NONE => ~1073741824
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.slice (a8 (), 1, SOME most))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.slice (a8 (), most, SOME 1))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.slice (a8 (), most, SOME most))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-not-Overflow-least-start", T.isSubscript, fn () => S.slice (a8 (), least, SOME 1))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.slice (a8 (), 1, SOME least))
  val () = T.raises ("ArraySlice.slice/SOME-Subscript-not-Overflow-least-and-most", T.isSubscript, fn () => S.slice (a8 (), least, SOME most))
  val () = T.raises ("ArraySlice.slice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.slice (a8 (), most, NONE))
  val () = T.raises ("ArraySlice.slice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.slice (a8 (), least, NONE))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME most))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.subslice (mid (), most, SOME 1))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-not-Overflow-start-zero-size", T.isSubscript, fn () => S.subslice (mid (), most, SOME 0))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.subslice (mid (), most, SOME most))
  val () = T.raises ("ArraySlice.subslice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME least))
  val () = T.raises ("ArraySlice.subslice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.subslice (mid (), most, NONE))
  val () = T.raises ("ArraySlice.subslice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.subslice (mid (), least, NONE))
  val () = T.raises ("ArraySlice.sub/Subscript-not-Overflow", T.isSubscript, fn () => S.sub (mid (), most))
  val () = T.raises ("ArraySlice.sub/Subscript-not-Overflow-least", T.isSubscript, fn () => S.sub (mid (), least))
  val () = T.raises ("ArraySlice.update/Subscript-not-Overflow", T.isSubscript, fn () => S.update (mid (), most, 99))
  val () = T.raises ("ArraySlice.update/Subscript-not-Overflow-least", T.isSubscript, fn () => S.update (mid (), least, 99))
  val () = T.raises ("ArraySlice.copy/Subscript-not-Overflow-sum", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 6, di = most})
  val () = T.raises ("ArraySlice.copy/Subscript-not-Overflow-least", T.isSubscript, fn () => S.copy {src = mid (), dst = zeros 6, di = least})
  val () = T.raises ("ArraySlice.copyVec/Subscript-not-Overflow-sum", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 6, di = most})
  val () = T.raises ("ArraySlice.copyVec/Subscript-not-Overflow-least", T.isSubscript, fn () => S.copyVec {src = vmid (), dst = zeros 6, di = least})
  (*>> overflow *)
end
