(* requires: VectorSlice Vector List *)
(* The VectorSlice structure (signature VECTOR_SLICE). Expected values follow
   the text of https://smlfamily.github.io/Basis/vector-slice.html.

   "A slice value can be viewed as a triple (v, i, n), where v is the
   underlying vector, i is the starting index, and n is the length of the
   subvector, with the constraint that 0 <= i <= i + n <= |v|."

   Slices are read back with length and sub, and with base. The indices that
   appi, mapi, foldli, foldri and findi pass and return are those "of the
   corresponding element in the slice": they start at 0 whatever the start of
   the slice in its vector is. *)
structure TestVectorSlice =
struct
  structure S = VectorSlice

  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val eqO = T.eq (T.option T.int)
  val eqOrd = T.eq T.order
  val eqIL = T.eq (T.list (T.pair (T.int, T.int)))
  val eqIO = T.eq (T.option (T.pair (T.int, T.int)))

  fun vectorToList (v : 'a vector) : 'a list = List.tabulate (Vector.length v, fn i => Vector.sub (v, i))
  fun toList (sl : 'a S.slice) : 'a list = List.tabulate (S.length sl, fn i => S.sub (sl, i))

  (* eqS, eqV (label, expected, f): the elements of the slice, or of the
     vector, f () are expected. *)
  fun eqS (label, expected : int list, f : unit -> int S.slice) : unit =
    eqL (label, expected, fn () => toList (f ()))
  fun eqV (label, expected : int list, f : unit -> int vector) : unit =
    eqL (label, expected, fn () => vectorToList (f ()))

  (* eqBase (label, (l, i, n), f): the base of the slice f () is a vector of
     the elements l, the start i and the length n. *)
  val showBase = T.triple (T.list T.int, T.int, T.int)
  fun baseOf (sl : int S.slice) = let val (v, i, n) = S.base sl in (vectorToList v, i, n) end
  fun eqBase (label, expected : int list * int * int, f : unit -> int S.slice) : unit =
    T.eq showBase (label, expected, fn () => baseOf (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end

  fun fromTo (lo, hi) = if lo > hi then [] else lo :: fromTo (lo + 1, hi)

  val l8 = [10, 11, 12, 13, 14, 15, 16, 17]
  val v8 = Vector.fromList l8
  val v0 : int vector = Vector.fromList []
  (* 12 13 14 15, in the middle of v8 *)
  val lMid = [12, 13, 14, 15]
  val iMid = [(0, 12), (1, 13), (2, 14), (3, 15)]
  fun mid () = S.slice (v8, 2, SOME 4)
  (* an empty slice in the middle of v8 *)
  fun nothing () = S.slice (v8, 3, SOME 0)
  val even = fn x => x mod 2 = 0

  (* model (len, i, sz): the start and the length of the slice (i, sz) of a
     sequence of len elements, or NONE where the page says Subscript: "if i < 0
     or |vec| < i" for NONE, "if i < 0 or j < 0 or |vec| < i + j" for SOME j.
     (The arguments of the tests are small: i + j exists.) *)
  fun model (len, i, NONE) = if i < 0 orelse len < i then NONE else SOME (i, len - i)
    | model (len, i, SOME j) = if i < 0 orelse j < 0 orelse len < i + j then NONE else SOME (i, j)
  val sizes = NONE :: List.map SOME (fromTo (~2, 10))
  val arguments = List.concat (List.map (fn i => List.map (fn sz => (i, sz)) sizes) (fromTo (~2, 10)))
  val eqArgs = T.eq (T.list (T.pair (T.int, T.option T.int)))

  (* ---- slice: "If sz is NONE, the slice includes all of the elements to the
     end of the vector, i.e., vec[i..|vec|-1]. This raises Subscript if i < 0
     or |vec| < i. If sz is SOME(j), the slice has length j, that is, it
     corresponds to vec[i..i+j-1]. It raises Subscript if i < 0 or j < 0 or
     |arr| < i + j. Note that, if defined, slice returns an empty slice when
     i = |vec|." ---- *)
  val () = eqS ("VectorSlice.slice/NONE-from-zero", l8, fn () => S.slice (v8, 0, NONE))
  val () = eqS ("VectorSlice.slice/NONE-middle", [13, 14, 15, 16, 17], fn () => S.slice (v8, 3, NONE))
  val () = eqS ("VectorSlice.slice/NONE-last", [17], fn () => S.slice (v8, 7, NONE))
  val () = eqS ("VectorSlice.slice/NONE-at-length", [], fn () => S.slice (v8, 8, NONE))
  val () = eqBase ("VectorSlice.slice/NONE-middle-base", (l8, 3, 5), fn () => S.slice (v8, 3, NONE))
  val () = eqBase ("VectorSlice.slice/NONE-at-length-base", (l8, 8, 0), fn () => S.slice (v8, 8, NONE))
  val () = T.raises ("VectorSlice.slice/NONE-Subscript-negative", T.isSubscript, fn () => S.slice (v8, ~1, NONE))
  val () = T.raises ("VectorSlice.slice/NONE-Subscript-beyond", T.isSubscript, fn () => S.slice (v8, 9, NONE))
  val () = eqS ("VectorSlice.slice/SOME-middle", lMid, fn () => S.slice (v8, 2, SOME 4))
  val () = eqS ("VectorSlice.slice/SOME-whole", l8, fn () => S.slice (v8, 0, SOME 8))
  val () = eqS ("VectorSlice.slice/SOME-to-the-end", [15, 16, 17], fn () => S.slice (v8, 5, SOME 3))
  val () = eqS ("VectorSlice.slice/SOME-one", [10], fn () => S.slice (v8, 0, SOME 1))
  val () = eqS ("VectorSlice.slice/SOME-zero", [], fn () => S.slice (v8, 3, SOME 0))
  val () = eqBase ("VectorSlice.slice/SOME-middle-base", (l8, 2, 4), fn () => S.slice (v8, 2, SOME 4))
  val () = eqBase ("VectorSlice.slice/SOME-zero-base", (l8, 3, 0), fn () => S.slice (v8, 3, SOME 0))
  val () = eqBase ("VectorSlice.slice/SOME-zero-at-length-base", (l8, 8, 0), fn () => S.slice (v8, 8, SOME 0))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-negative-start", T.isSubscript, fn () => S.slice (v8, ~1, SOME 2))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-negative-start-zero-size", T.isSubscript, fn () => S.slice (v8, ~1, SOME 0))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-negative-size", T.isSubscript, fn () => S.slice (v8, 2, SOME ~1))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-negative-size-at-length", T.isSubscript, fn () => S.slice (v8, 8, SOME ~1))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-one-too-many", T.isSubscript, fn () => S.slice (v8, 5, SOME 4))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-whole-and-one", T.isSubscript, fn () => S.slice (v8, 0, SOME 9))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-one-at-length", T.isSubscript, fn () => S.slice (v8, 8, SOME 1))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-zero-size-beyond", T.isSubscript, fn () => S.slice (v8, 9, SOME 0))
  val () = eqBase ("VectorSlice.slice/empty-vector-NONE", ([], 0, 0), fn () => S.slice (v0, 0, NONE))
  val () = eqBase ("VectorSlice.slice/empty-vector-SOME", ([], 0, 0), fn () => S.slice (v0, 0, SOME 0))
  val () = T.raises ("VectorSlice.slice/empty-vector-NONE-Subscript", T.isSubscript, fn () => S.slice (v0, 1, NONE))
  val () = T.raises ("VectorSlice.slice/empty-vector-SOME-Subscript", T.isSubscript, fn () => S.slice (v0, 0, SOME 1))
  (* every start and size from ~2 to 10: the arguments whose result differs from the model *)
  val () = eqArgs ("VectorSlice.slice/every-argument", [],
                   fn () => List.filter (fn (i, sz) =>
                                (SOME (baseOf (S.slice (v8, i, sz))) handle Subscript => NONE)
                                <> Option.map (fn (start, n) => (l8, start, n)) (model (8, i, sz)))
                              arguments)

  (* ---- subslice: "creates a slice based on the given slice sl starting at
     index i of sl. ... This raises Subscript if i < 0 or |sl| < i. ... It
     raises Subscript if i < 0 or j < 0 or |sl| < i + j." The bounds are those
     of the slice, not those of its vector. ---- *)
  val () = eqS ("VectorSlice.subslice/NONE-from-zero", lMid, fn () => S.subslice (mid (), 0, NONE))
  val () = eqS ("VectorSlice.subslice/NONE-middle", [13, 14, 15], fn () => S.subslice (mid (), 1, NONE))
  val () = eqS ("VectorSlice.subslice/NONE-at-length", [], fn () => S.subslice (mid (), 4, NONE))
  val () = eqBase ("VectorSlice.subslice/NONE-middle-base", (l8, 3, 3), fn () => S.subslice (mid (), 1, NONE))
  val () = eqBase ("VectorSlice.subslice/NONE-at-length-base", (l8, 6, 0), fn () => S.subslice (mid (), 4, NONE))
  val () = T.raises ("VectorSlice.subslice/NONE-Subscript-negative", T.isSubscript, fn () => S.subslice (mid (), ~1, NONE))
  val () = T.raises ("VectorSlice.subslice/NONE-Subscript-beyond", T.isSubscript, fn () => S.subslice (mid (), 5, NONE))
  val () = eqS ("VectorSlice.subslice/SOME-middle", [13, 14], fn () => S.subslice (mid (), 1, SOME 2))
  val () = eqS ("VectorSlice.subslice/SOME-whole", lMid, fn () => S.subslice (mid (), 0, SOME 4))
  val () = eqS ("VectorSlice.subslice/SOME-to-the-end", [14, 15], fn () => S.subslice (mid (), 2, SOME 2))
  val () = eqBase ("VectorSlice.subslice/SOME-middle-base", (l8, 3, 2), fn () => S.subslice (mid (), 1, SOME 2))
  val () = eqBase ("VectorSlice.subslice/SOME-zero-base", (l8, 3, 0), fn () => S.subslice (mid (), 1, SOME 0))
  val () = eqBase ("VectorSlice.subslice/SOME-zero-at-length-base", (l8, 6, 0), fn () => S.subslice (mid (), 4, SOME 0))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-negative-start", T.isSubscript, fn () => S.subslice (mid (), ~1, SOME 2))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-negative-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME ~1))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-one-too-many", T.isSubscript, fn () => S.subslice (mid (), 3, SOME 2))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-whole-and-one", T.isSubscript, fn () => S.subslice (mid (), 0, SOME 5))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-zero-size-beyond", T.isSubscript, fn () => S.subslice (mid (), 5, SOME 0))
  val () = eqBase ("VectorSlice.subslice/of-subslice", (l8, 4, 1), fn () => S.subslice (S.subslice (mid (), 1, NONE), 1, SOME 1))
  val () = eqBase ("VectorSlice.subslice/of-empty", (l8, 3, 0), fn () => S.subslice (nothing (), 0, NONE))
  val () = T.raises ("VectorSlice.subslice/of-empty-Subscript", T.isSubscript, fn () => S.subslice (nothing (), 1, NONE))
  val () = eqArgs ("VectorSlice.subslice/every-argument", [],
                   fn () => List.filter (fn (i, sz) =>
                                (SOME (baseOf (S.subslice (mid (), i, sz))) handle Subscript => NONE)
                                <> Option.map (fn (start, n) => (l8, 2 + start, n)) (model (4, i, sz)))
                              arguments)

  (* ---- full: "creates a slice representing the entire vector vec. It is
     equivalent to slice(vec, 0, NONE)" ---- *)
  val () = eqS ("VectorSlice.full/basic", l8, fn () => S.full v8)
  val () = eqBase ("VectorSlice.full/base", (l8, 0, 8), fn () => S.full v8)
  val () = eqBase ("VectorSlice.full/empty-vector", ([], 0, 0), fn () => S.full v0)
  val () = eqB ("VectorSlice.full/is-slice-0-NONE", true, fn () => baseOf (S.full v8) = baseOf (S.slice (v8, 0, NONE)))

  (* ---- length ---- *)
  val () = eqI ("VectorSlice.length/full", 8, fn () => S.length (S.full v8))
  val () = eqI ("VectorSlice.length/middle", 4, fn () => S.length (mid ()))
  val () = eqI ("VectorSlice.length/NONE", 5, fn () => S.length (S.slice (v8, 3, NONE)))
  val () = eqI ("VectorSlice.length/empty", 0, fn () => S.length (nothing ()))
  val () = eqI ("VectorSlice.length/empty-vector", 0, fn () => S.length (S.full v0))

  (* ---- sub: "returns the i(th) element of the slice sl. If i < 0 or
     |sl| <= i, then the Subscript exception is raised." The vector has
     elements on both sides of mid (). ---- *)
  val () = eqI ("VectorSlice.sub/first", 12, fn () => S.sub (mid (), 0))
  val () = eqI ("VectorSlice.sub/middle", 13, fn () => S.sub (mid (), 1))
  val () = eqI ("VectorSlice.sub/last", 15, fn () => S.sub (mid (), 3))
  val () = T.raises ("VectorSlice.sub/Subscript-length", T.isSubscript, fn () => S.sub (mid (), 4))
  val () = T.raises ("VectorSlice.sub/Subscript-negative", T.isSubscript, fn () => S.sub (mid (), ~1))
  val () = T.raises ("VectorSlice.sub/Subscript-beyond-the-vector", T.isSubscript, fn () => S.sub (mid (), 6))
  val () = T.raises ("VectorSlice.sub/Subscript-before-the-vector", T.isSubscript, fn () => S.sub (mid (), ~3))
  val () = T.raises ("VectorSlice.sub/Subscript-empty", T.isSubscript, fn () => S.sub (nothing (), 0))
  val () = T.raises ("VectorSlice.sub/Subscript-full", T.isSubscript, fn () => S.sub (S.full v8, 8))

  (* ---- base: "returns a triple (vec, i, n) representing the concrete
     representation of the slice" ---- *)
  val () = eqBase ("VectorSlice.base/middle", (l8, 2, 4), mid)
  val () = eqBase ("VectorSlice.base/empty", (l8, 3, 0), nothing)
  val () = eqB ("VectorSlice.base/round-trip", true,
                fn () => let val (v, i, n) = S.base (mid ()) in toList (S.slice (v, i, SOME n)) = lMid end)

  (* ---- vector: "the result is equivalent to
     Vector.tabulate (length sl, fn i => sub (sl, i))" ---- *)
  val () = eqV ("VectorSlice.vector/middle", lMid, fn () => S.vector (mid ()))
  val () = eqV ("VectorSlice.vector/full", l8, fn () => S.vector (S.full v8))
  val () = eqV ("VectorSlice.vector/empty", [], fn () => S.vector (nothing ()))
  val () = eqB ("VectorSlice.vector/equals-tabulate", true,
                fn () => let val sl = mid () in S.vector sl = Vector.tabulate (S.length sl, fn i => S.sub (sl, i)) end)

  (* ---- concat: "the concatenation of all the slices in l" ---- *)
  val () = eqV ("VectorSlice.concat/nil", [], fn () => S.concat [])
  val () = eqV ("VectorSlice.concat/one", lMid, fn () => S.concat [mid ()])
  val () = eqV ("VectorSlice.concat/empty-slices", [], fn () => S.concat [nothing (), S.full v0, nothing ()])
  val () = eqV ("VectorSlice.concat/order", [16, 17, 12, 13, 14, 15, 1, 2, 10],
                fn () => S.concat [S.slice (v8, 6, NONE), nothing (), mid (), S.full (Vector.fromList [1, 2]),
                                   S.slice (v8, 0, SOME 1)])
  val () = eqV ("VectorSlice.concat/same-slice-twice", lMid @ lMid, fn () => let val sl = mid () in S.concat [sl, sl] end)
  val () = eqV ("VectorSlice.concat/overlapping", [10, 11, 12, 11, 12, 13],
                fn () => S.concat [S.slice (v8, 0, SOME 3), S.slice (v8, 1, SOME 3)])

  (* ---- isEmpty: "returns true if sl has length 0" ---- *)
  val () = eqB ("VectorSlice.isEmpty/empty", true, fn () => S.isEmpty (nothing ()))
  val () = eqB ("VectorSlice.isEmpty/empty-vector", true, fn () => S.isEmpty (S.full v0))
  val () = eqB ("VectorSlice.isEmpty/at-length", true, fn () => S.isEmpty (S.slice (v8, 8, NONE)))
  val () = eqB ("VectorSlice.isEmpty/one", false, fn () => S.isEmpty (S.slice (v8, 7, NONE)))
  val () = eqB ("VectorSlice.isEmpty/middle", false, fn () => S.isEmpty (mid ()))

  (* ---- getItem: "returns the first item in sl and the rest of the slice, or
     NONE if sl is empty" ---- *)
  val eqItem = T.eq (T.option (T.pair (T.int, showBase)))
  fun getItem sl = Option.map (fn (x, rest) => (x, baseOf rest)) (S.getItem sl)
  val () = eqItem ("VectorSlice.getItem/middle", SOME (12, (l8, 3, 3)), fn () => getItem (mid ()))
  val () = eqItem ("VectorSlice.getItem/full", SOME (10, (l8, 1, 7)), fn () => getItem (S.full v8))
  val () = eqItem ("VectorSlice.getItem/one", SOME (13, (l8, 4, 0)), fn () => getItem (S.slice (v8, 3, SOME 1)))
  val () = eqItem ("VectorSlice.getItem/last-of-the-vector", SOME (17, (l8, 8, 0)), fn () => getItem (S.slice (v8, 7, NONE)))
  val () = eqItem ("VectorSlice.getItem/empty", NONE, fn () => getItem (nothing ()))
  val () = eqItem ("VectorSlice.getItem/empty-vector", NONE, fn () => getItem (S.full v0))
  fun items sl = case S.getItem sl of NONE => [] | SOME (x, rest) => x :: items rest
  val () = eqL ("VectorSlice.getItem/repeated", lMid, fn () => items (mid ()))

  (* ---- appi, app: "apply the function f to the elements of a slice in left
     to right order (i.e., increasing indices). The more general appi function
     supplies f with the index of the corresponding element in the slice." ---- *)
  val () = eqIL ("VectorSlice.appi/index-in-the-slice", iMid,
                 fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (mid ()); seen () end)
  val () = eqIL ("VectorSlice.appi/full", [(0, 5), (1, 6)],
                 fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (S.full (Vector.fromList [5, 6])); seen () end)
  val () = eqIL ("VectorSlice.appi/empty", [],
                 fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (nothing ()); seen () end)
  val () = eqL ("VectorSlice.app/order", lMid,
                fn () => let val (f, seen) = trace (fn _ => ()) in S.app f (mid ()); seen () end)
  val () = eqL ("VectorSlice.app/empty", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in S.app f (nothing ()); seen () end)

  (* ---- mapi, map: "generate new vectors by mapping the function f from left
     to right over the argument slice. The more general mapi function supplies
     both the element and the element's index in the slice" ---- *)
  val () = eqV ("VectorSlice.mapi/index-in-the-slice", [12, 113, 214, 315],
                fn () => S.mapi (fn (i, x) => 100 * i + x) (mid ()))
  val () = eqV ("VectorSlice.mapi/empty", [], fn () => S.mapi (fn (i, x) => i + x) (nothing ()))
  val () = eqIL ("VectorSlice.mapi/order", iMid,
                 fn () => let val (f, seen) = trace (fn (_, x) => x) in ignore (S.mapi f (mid ())); seen () end)
  val () = eqV ("VectorSlice.map/basic", [24, 26, 28, 30], fn () => S.map (fn x => 2 * x) (mid ()))
  val () = eqV ("VectorSlice.map/empty", [], fn () => S.map (fn x => 2 * x) (nothing ()))
  val () = eqL ("VectorSlice.map/order", lMid,
                fn () => let val (f, seen) = trace (fn x => x) in ignore (S.map f (mid ())); seen () end)
  val () = T.eq (T.list T.string) ("VectorSlice.map/other-type", ["12", "13", "14", "15"],
                                   fn () => vectorToList (S.map Int.toString (mid ())))
  val () = eqL ("VectorSlice.map/vector-unchanged", l8, fn () => (ignore (S.map (fn x => x + 1) (mid ())); vectorToList v8))

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
  val () = eqIL ("VectorSlice.foldli/conses-reversed", List.rev iMid,
                 fn () => S.foldli (fn (i, a, l) => (i, a) :: l) [] (mid ()))
  val () = eqI ("VectorSlice.foldli/nonassociative", 41, fn () => S.foldli (fn (i, a, x) => i * a - 2 * x) 0 (mid ()))
  val () = eqI ("VectorSlice.foldli/empty", 42, fn () => S.foldli (fn (i, a, x) => i + a + x) 42 (nothing ()))
  val () = eqIL ("VectorSlice.foldri/conses-in-order", iMid, fn () => S.foldri (fn (i, a, l) => (i, a) :: l) [] (mid ()))
  val () = eqI ("VectorSlice.foldri/nonassociative", ~274, fn () => S.foldri (fn (i, a, x) => i * a - 2 * x) 0 (mid ()))
  val () = eqI ("VectorSlice.foldri/empty", 42, fn () => S.foldri (fn (i, a, x) => i + a + x) 42 (nothing ()))
  val () = eqL ("VectorSlice.foldl/conses-reversed", List.rev lMid, fn () => S.foldl (op ::) [] (mid ()))
  val () = eqI ("VectorSlice.foldl/nonassociative", ~57, fn () => S.foldl (fn (a, x) => a - 2 * x) 0 (mid ()))
  val () = eqI ("VectorSlice.foldl/empty", 42, fn () => S.foldl (op +) 42 (nothing ()))
  val () = eqL ("VectorSlice.foldr/conses-in-order", lMid, fn () => S.foldr (op ::) [] (mid ()))
  val () = eqI ("VectorSlice.foldr/nonassociative", ~78, fn () => S.foldr (fn (a, x) => a - 2 * x) 0 (mid ()))
  val () = eqI ("VectorSlice.foldr/empty", 42, fn () => S.foldr (op +) 42 (nothing ()))

  (* ---- findi, find: "from left to right (i.e., increasing indices), until a
     true value is returned"; findi "also supplies f with the index of the
     element in the slice and, upon finding an entry satisfying the predicate,
     returns that index with the element" ---- *)
  val () = eqIO ("VectorSlice.findi/first-match", SOME (1, 13), fn () => S.findi (fn (_, a) => a > 12) (mid ()))
  val () = eqIO ("VectorSlice.findi/by-index", SOME (3, 15), fn () => S.findi (fn (i, _) => i = 3) (mid ()))
  val () = eqIO ("VectorSlice.findi/index-zero", SOME (0, 12), fn () => S.findi (fn _ => true) (mid ()))
  val () = eqIO ("VectorSlice.findi/none", NONE, fn () => S.findi (fn (_, a) => a > 15) (mid ()))
  val () = eqIO ("VectorSlice.findi/not-before-the-slice", NONE, fn () => S.findi (fn (_, a) => a < 12) (mid ()))
  val () = eqIO ("VectorSlice.findi/empty", NONE, fn () => S.findi (fn _ => true) (nothing ()))
  val () = eqIL ("VectorSlice.findi/stops", [(0, 12), (1, 13)],
                 fn () => let val (f, seen) = trace (fn (_, a) => a = 13) in ignore (S.findi f (mid ())); seen () end)
  val () = eqIL ("VectorSlice.findi/order", iMid,
                 fn () => let val (f, seen) = trace (fn _ => false) in ignore (S.findi f (mid ())); seen () end)
  val () = eqO ("VectorSlice.find/first-match", SOME 13, fn () => S.find (not o even) (mid ()))
  val () = eqO ("VectorSlice.find/last-element", SOME 15, fn () => S.find (fn x => x > 14) (mid ()))
  val () = eqO ("VectorSlice.find/none", NONE, fn () => S.find (fn x => x > 15) (mid ()))
  val () = eqO ("VectorSlice.find/not-before-the-slice", NONE, fn () => S.find (fn x => x < 12) (mid ()))
  val () = eqO ("VectorSlice.find/empty", NONE, fn () => S.find (fn _ => true) (nothing ()))
  val () = eqL ("VectorSlice.find/stops", [12, 13],
                fn () => let val (f, seen) = trace (not o even) in ignore (S.find f (mid ())); seen () end)

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB ("VectorSlice.exists/true", true, fn () => S.exists (fn x => x = 14) (mid ()))
  val () = eqB ("VectorSlice.exists/false", false, fn () => S.exists (fn x => x = 9) (mid ()))
  val () = eqB ("VectorSlice.exists/not-outside-the-slice", false, fn () => S.exists (fn x => x = 11 orelse x = 16) (mid ()))
  val () = eqB ("VectorSlice.exists/empty", false, fn () => S.exists (fn _ => true) (nothing ()))
  val () = eqL ("VectorSlice.exists/stops", [12, 13, 14],
                fn () => let val (f, seen) = trace (fn x => x = 14) in ignore (S.exists f (mid ())); seen () end)
  val () = eqL ("VectorSlice.exists/order", lMid,
                fn () => let val (f, seen) = trace (fn _ => false) in ignore (S.exists f (mid ())); seen () end)
  val () = eqB ("VectorSlice.all/true", true, fn () => S.all (fn x => x >= 12 andalso x <= 15) (mid ()))
  val () = eqB ("VectorSlice.all/false", false, fn () => S.all (fn x => x < 14) (mid ()))
  val () = eqB ("VectorSlice.all/empty", true, fn () => S.all (fn _ => false) (nothing ()))
  val () = eqL ("VectorSlice.all/stops", [12, 13, 14],
                fn () => let val (f, seen) = trace (fn x => x < 14) in ignore (S.all f (mid ())); seen () end)
  val () = eqL ("VectorSlice.all/order", lMid,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (S.all f (mid ())); seen () end)

  (* ---- collate: "lexicographic comparison of the two slices using the given
     ordering f on elements" ---- *)
  val v6 = Vector.fromList [1, 2, 1, 2, 3, 0]
  fun part (i, n) = S.slice (v6, i, SOME n)
  val () = eqOrd ("VectorSlice.collate/equal-parts-of-one-vector", EQUAL, fn () => S.collate Int.compare (part (0, 2), part (2, 2)))
  val () = eqOrd ("VectorSlice.collate/same-slice", EQUAL, fn () => let val sl = mid () in S.collate Int.compare (sl, sl) end)
  val () = eqOrd ("VectorSlice.collate/empty-empty", EQUAL, fn () => S.collate Int.compare (part (1, 0), part (4, 0)))
  val () = eqOrd ("VectorSlice.collate/empty-less", LESS, fn () => S.collate Int.compare (part (1, 0), part (5, 1)))
  val () = eqOrd ("VectorSlice.collate/empty-greater", GREATER, fn () => S.collate Int.compare (part (5, 1), part (1, 0)))
  val () = eqOrd ("VectorSlice.collate/prefix-less", LESS, fn () => S.collate Int.compare (part (0, 2), part (2, 3)))
  val () = eqOrd ("VectorSlice.collate/prefix-greater", GREATER, fn () => S.collate Int.compare (part (2, 3), part (0, 2)))
  val () = eqOrd ("VectorSlice.collate/first-difference", GREATER, fn () => S.collate Int.compare (part (3, 3), part (1, 3)))
  val () = eqOrd ("VectorSlice.collate/not-by-length", LESS, fn () => S.collate Int.compare (part (0, 4), part (1, 1)))
  val () = eqOrd ("VectorSlice.collate/ends-with-the-slice", EQUAL,
                  fn () => S.collate Int.compare (S.slice (Vector.fromList [1, 2, 3], 0, SOME 2), S.slice (Vector.fromList [1, 2, 4], 0, SOME 2)))
  val () = eqOrd ("VectorSlice.collate/starts-with-the-slice", EQUAL,
                  fn () => S.collate Int.compare (S.slice (Vector.fromList [0, 2, 3], 1, NONE), S.slice (Vector.fromList [9, 2, 3], 1, NONE)))
  val () = eqOrd ("VectorSlice.collate/given-ordering", GREATER,
                  fn () => S.collate (fn (a, b) => Int.compare (b, a)) (part (0, 4), part (1, 1)))
  val () = eqOrd ("VectorSlice.collate/argument-order", LESS,
                  fn () => S.collate (fn (a, b) => if a = 1 andalso b = 2 then LESS else GREATER) (part (0, 1), part (1, 1)))

  (* ---- laws, on pseudo-random slices, against lists ---- *)
  fun randomList n = List.tabulate (n, fn _ => T.range (~50, 50))
  fun indexed l = List.tabulate (List.length l, fn j => (j, List.nth (l, j)))
  val () = T.seed 8
  val () = T.repeat (40, fn k =>
    let
      val n = Int.toString k
      val whole = randomList (T.range (0, 12))
      val len = List.length whole
      val start = T.range (0, len)
      val size = T.range (0, len - start)
      val l = List.take (List.drop (whole, start), size)       (* the elements of the slice *)
      val v = Vector.fromList whole
      fun sl () = S.slice (v, start, SOME size)
      (* another slice, of another vector *)
      val whole2 = randomList (T.range (0, 6))
      val start2 = T.range (0, List.length whole2)
      val l2 = List.drop (whole2, start2)
      fun sl2 () = S.slice (Vector.fromList whole2, start2, NONE)
      (* arguments for slice and subslice that are valid, or just not *)
      val i = T.range (~1, len + 1)
      val sz = if T.range (0, 3) = 0 then NONE else SOME (T.range (~1, len + 1))
      val j = T.range (0, size)             (* 0 <= j <= size *)
      val fi = fn (j, e) => 3 * j - e
      val gi = fn (j, e, b) => j * e - 2 * b
      val g = fn (e, b) => e - 2 * b
      val pi = fn (j, e) => (j + e) mod 5 = 0
      val p = fn e => e mod 5 = 0
    in
      T.eq (T.option showBase) ("VectorSlice.slice/model-" ^ n, Option.map (fn (a, b) => (whole, a, b)) (model (len, i, sz)),
                                fn () => SOME (baseOf (S.slice (v, i, sz))) handle Subscript => NONE);
      T.eq (T.option showBase) ("VectorSlice.subslice/model-" ^ n,
                                Option.map (fn (a, b) => (whole, start + a, b)) (model (size, i, sz)),
                                fn () => SOME (baseOf (S.subslice (sl (), i, sz))) handle Subscript => NONE);
      eqB ("VectorSlice.full/model-" ^ n, true, fn () => baseOf (S.full v) = (whole, 0, len));
      eqBase ("VectorSlice.base/model-" ^ n, (whole, start, size), sl);
      eqI ("VectorSlice.length/model-" ^ n, size, fn () => S.length (sl ()));
      (if j < size
       then eqI ("VectorSlice.sub/model-" ^ n, List.nth (l, j), fn () => S.sub (sl (), j))
       else T.raises ("VectorSlice.sub/model-" ^ n, T.isSubscript, fn () => S.sub (sl (), j)));
      eqV ("VectorSlice.vector/model-" ^ n, l, fn () => S.vector (sl ()));
      eqV ("VectorSlice.concat/model-" ^ n, l @ l2 @ l, fn () => S.concat [sl (), sl2 (), sl ()]);
      eqB ("VectorSlice.isEmpty/model-" ^ n, size = 0, fn () => S.isEmpty (sl ()));
      eqL ("VectorSlice.getItem/model-" ^ n, l, fn () => items (sl ()));
      eqIL ("VectorSlice.appi/model-" ^ n, indexed l,
            fn () => let val (f, seen) = trace (fn _ => ()) in S.appi f (sl ()); seen () end);
      eqL ("VectorSlice.app/model-" ^ n, l,
           fn () => let val (f, seen) = trace (fn _ => ()) in S.app f (sl ()); seen () end);
      eqV ("VectorSlice.mapi/model-" ^ n, List.map fi (indexed l), fn () => S.mapi fi (sl ()));
      eqV ("VectorSlice.map/model-" ^ n, List.map (fn e => e * e) l, fn () => S.map (fn e => e * e) (sl ()));
      eqI ("VectorSlice.foldli/model-" ^ n, List.foldl (fn ((j, e), b) => gi (j, e, b)) 1 (indexed l),
           fn () => S.foldli gi 1 (sl ()));
      eqI ("VectorSlice.foldri/model-" ^ n, List.foldr (fn ((j, e), b) => gi (j, e, b)) 1 (indexed l),
           fn () => S.foldri gi 1 (sl ()));
      eqI ("VectorSlice.foldl/model-" ^ n, List.foldl g 1 l, fn () => S.foldl g 1 (sl ()));
      eqI ("VectorSlice.foldr/model-" ^ n, List.foldr g 1 l, fn () => S.foldr g 1 (sl ()));
      eqIO ("VectorSlice.findi/model-" ^ n, List.find pi (indexed l), fn () => S.findi pi (sl ()));
      eqO ("VectorSlice.find/model-" ^ n, List.find p l, fn () => S.find p (sl ()));
      eqB ("VectorSlice.exists/model-" ^ n, List.exists p l, fn () => S.exists p (sl ()));
      eqB ("VectorSlice.all/model-" ^ n, List.all (not o p) l, fn () => S.all (not o p) (sl ()));
      eqB ("VectorSlice.all/de-morgan-" ^ n, true,
           fn () => S.all p (sl ()) = not (S.exists (not o p) (sl ())));
      eqOrd ("VectorSlice.collate/model-" ^ n, List.collate Int.compare (l, l2),
             fn () => S.collate Int.compare (sl (), sl2 ()))
    end)

  (* ---- long slices: no stack or quadratic trouble ---- *)
  fun big () = Vector.tabulate (200002, fn i => i)
  fun long () = S.slice (big (), 1, SOME 200000)
  val () = eqI ("VectorSlice.foldr/long-list", 200000, fn () => List.length (S.foldr (op ::) [] (long ())))
  val () = eqI ("VectorSlice.foldl/long", 200000, fn () => S.foldl Int.max 0 (long ()))
  val () = eqI ("VectorSlice.map/long", 200001, fn () => Vector.sub (S.map (fn x => x + 1) (long ()), 199999))
  val () = eqI ("VectorSlice.vector/long", 200000, fn () => Vector.length (S.vector (long ())))
  val () = eqI ("VectorSlice.concat/many", 200000,
                fn () => let val v = big () in Vector.length (S.concat (List.tabulate (2000, fn i => S.slice (v, i, SOME 100)))) end)
  val () = eqOrd ("VectorSlice.collate/long", EQUAL, fn () => S.collate Int.compare (long (), long ()))

  (*<< overflow *)
  (* ---- Subscript, not Overflow: the page gives the conditions as "i < 0 or
     j < 0 or |vec| < i + j" and "i < 0 or |sl| <= i", which hold for the
     numbers below although i + j, or the index in the vector, does not exist
     as an int (in the checks labelled sum-* both numbers are valid by
     themselves). ---- *)
  val most = case Int.maxInt of SOME m => m | NONE => 1073741823
  val least = case Int.minInt of SOME m => m | NONE => ~1073741824
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.slice (v8, 1, SOME most))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.slice (v8, most, SOME 1))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.slice (v8, most, SOME most))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-not-Overflow-least-start", T.isSubscript, fn () => S.slice (v8, least, SOME 1))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.slice (v8, 1, SOME least))
  val () = T.raises ("VectorSlice.slice/SOME-Subscript-not-Overflow-least-and-most", T.isSubscript, fn () => S.slice (v8, least, SOME most))
  val () = T.raises ("VectorSlice.slice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.slice (v8, most, NONE))
  val () = T.raises ("VectorSlice.slice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.slice (v8, least, NONE))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME most))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.subslice (mid (), most, SOME 1))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-not-Overflow-start-zero-size", T.isSubscript, fn () => S.subslice (mid (), most, SOME 0))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.subslice (mid (), most, SOME most))
  val () = T.raises ("VectorSlice.subslice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME least))
  val () = T.raises ("VectorSlice.subslice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.subslice (mid (), most, NONE))
  val () = T.raises ("VectorSlice.subslice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.subslice (mid (), least, NONE))
  val () = T.raises ("VectorSlice.sub/Subscript-not-Overflow", T.isSubscript, fn () => S.sub (mid (), most))
  val () = T.raises ("VectorSlice.sub/Subscript-not-Overflow-least", T.isSubscript, fn () => S.sub (mid (), least))
  (*>> overflow *)

  (* ---- concat: "This raises Size if the sum of all the lengths is greater
     than Vector.maxLen." That many elements can only be given where maxLen is
     small: 1024 times a slice of maxLen div 1024 + 1 elements. ---- *)
  val () =
    if Vector.maxLen <= 16777216
    then T.raises ("VectorSlice.concat/Size-above-maxLen", T.isSize,
                   fn () => let val part = S.slice (Vector.tabulate (Vector.maxLen div 1024 + 2, fn _ => 0), 1, NONE)
                            in S.concat (List.tabulate (1024, fn _ => part)) end)
    else ()
end
