(* Checks of a structure with signature MONO_VECTOR_SLICE, for any element
   type. Expected values follow
   https://smlfamily.github.io/Basis/mono-vector-slice.html.

     structure Generic = TestMonoVectorSliceFn (structure S = Word8VectorSlice structure V = Word8Vector val name = "Word8VectorSlice" val elems = ... val show = ... val same = ...)

   needs spec-sigs/MONO_VECTOR.sml and spec-sigs/MONO_VECTOR_SLICE.sml. V is
   the matching vector structure ("with the vector types in the two structures
   identified"). The labels are name ^ ".member/case". `elems` holds at least
   8 distinct sample elements, `show` prints one and `same` is the equality of
   elements. An element is written below as its index in `elems`, its code:
   the vector [1, 2, 3] is the one of the samples 1, 2 and 3. Slices are read
   back with S.length and S.sub, and with S.base, as lists of codes.

   "A slice value can be viewed as a triple (v, i, n), where v is the
   underlying vector, i is the starting index, and n is the length of the
   subarray, with the constraint that 0 <= i <= i + n <= |v|." The indices
   that appi, mapi, foldli, foldri and findi pass and return are those "of the
   corresponding element in the slice": they start at 0 whatever the start of
   the slice in its vector is.

   TestMonoVectorSliceOverflowFn has the checks with numbers near Int.maxInt
   and TestMonoVectorSliceSizeFn the check of Size, which asks for more than
   V.maxLen elements; a test applies each in a section of its own. *)
functor TestMonoVectorSliceFn (structure V : SPEC_MONO_VECTOR
                               structure S : SPEC_MONO_VECTOR_SLICE where type vector = V.vector where type elem = V.elem
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
  fun toList sl = List.tabulate (S.length sl, fn i => code (S.sub (sl, i)))
  fun vec l = V.fromList (List.map e l)

  (* eqS, eqV (label, expected, f): the elements of the slice, or of the
     vector, f () are expected. *)
  fun eqS (label, expected : int list, f : unit -> S.slice) : unit = eqL (label, expected, fn () => toList (f ()))
  fun eqV (label, expected : int list, f : unit -> V.vector) : unit = eqL (label, expected, fn () => vectorToList (f ()))

  (* eqBase (label, (l, i, n), f): the base of the slice f () is a vector of
     the elements l, the start i and the length n. *)
  val showBase = T.triple (T.list showCode, T.int, T.int)
  fun baseOf sl = let val (v, i, n) = S.base sl in (vectorToList v, i, n) end
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
  fun v8 () = vec l8
  (* 2 3 4 5, in the middle of v8 *)
  val lMid = [2, 3, 4, 5]
  val iMid = [(0, 2), (1, 3), (2, 4), (3, 5)]
  fun mid () = S.slice (v8 (), 2, SOME 4)
  (* an empty slice in the middle of v8 *)
  fun nothing () = S.slice (v8 (), 3, SOME 0)
  val minusOne = ref ~1   (* not a constant: see Array.update in array.sml *)
  fun cmp (a, b) = Int.compare (code a, code b)
  fun even x = code x mod 2 = 0

  (* model (len, i, sz): the start and the length of the slice (i, sz) of a
     sequence of len elements, or NONE where the page says Subscript: "if i < 0
     or |vec| < i" for NONE, "if i < 0 or j < 0 or |vec| < i + j" for SOME j.
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
     end of the vector, i.e., vec[i..|vec|-1]. This raises Subscript if i < 0
     or |vec| < i. If sz is SOME(j), the slice has length j, that is, it
     corresponds to vec[i..i+j-1]. It raises Subscript if i < 0 or j < 0 or
     |vec| < i + j. Note that, if defined, slice returns an empty slice when
     i = |vec|." ---- *)
  val () = eqS (lab "slice/NONE-from-zero", l8, fn () => S.slice (v8 (), 0, NONE))
  val () = eqS (lab "slice/NONE-middle", [3, 4, 5, 6, 7], fn () => S.slice (v8 (), 3, NONE))
  val () = eqS (lab "slice/NONE-last", [7], fn () => S.slice (v8 (), 7, NONE))
  val () = eqS (lab "slice/NONE-at-length", [], fn () => S.slice (v8 (), 8, NONE))
  val () = eqBase (lab "slice/NONE-middle-base", (l8, 3, 5), fn () => S.slice (v8 (), 3, NONE))
  val () = eqBase (lab "slice/NONE-at-length-base", (l8, 8, 0), fn () => S.slice (v8 (), 8, NONE))
  val () = T.raises (lab "slice/NONE-Subscript-negative", T.isSubscript, fn () => S.slice (v8 (), !minusOne, NONE))
  val () = T.raises (lab "slice/NONE-Subscript-beyond", T.isSubscript, fn () => S.slice (v8 (), 9, NONE))
  val () = eqS (lab "slice/SOME-middle", lMid, fn () => S.slice (v8 (), 2, SOME 4))
  val () = eqS (lab "slice/SOME-all", l8, fn () => S.slice (v8 (), 0, SOME 8))
  val () = eqS (lab "slice/SOME-one", [7], fn () => S.slice (v8 (), 7, SOME 1))
  val () = eqS (lab "slice/SOME-zero", [], fn () => S.slice (v8 (), 3, SOME 0))
  val () = eqS (lab "slice/SOME-zero-at-length", [], fn () => S.slice (v8 (), 8, SOME 0))
  val () = eqBase (lab "slice/SOME-middle-base", (l8, 2, 4), fn () => S.slice (v8 (), 2, SOME 4))
  val () = eqBase (lab "slice/SOME-zero-base", (l8, 3, 0), fn () => S.slice (v8 (), 3, SOME 0))
  val () = T.raises (lab "slice/SOME-Subscript-negative-start", T.isSubscript, fn () => S.slice (v8 (), !minusOne, SOME 2))
  val () = T.raises (lab "slice/SOME-Subscript-negative-size", T.isSubscript, fn () => S.slice (v8 (), 2, SOME (!minusOne)))
  val () = T.raises (lab "slice/SOME-Subscript-too-long", T.isSubscript, fn () => S.slice (v8 (), 5, SOME 4))
  val () = T.raises (lab "slice/SOME-Subscript-beyond", T.isSubscript, fn () => S.slice (v8 (), 9, SOME 0))
  val () = eqS (lab "slice/of-empty-vector", [], fn () => S.slice (vec [], 0, NONE))
  val () = T.raises (lab "slice/of-empty-vector-Subscript", T.isSubscript, fn () => S.slice (vec [], 1, NONE))
  (* every start from ~2 to 10 with NONE and every size from ~2 to 10: the
     arguments that do not behave as the model says *)
  val () = eqArgs (lab "slice/every-argument", [],
                   fn () => List.filter (fn (i, sz) => (SOME (startAndLength (S.slice (v8 (), i, sz))) handle Subscript => NONE)
                                                       <> model (8, i, sz)) arguments)

  (* ---- full: "creates a slice representing the entire vector vec. It is
     equivalent to slice(vec, 0, NONE)" ---- *)
  val () = eqS (lab "full/basic", l8, fn () => S.full (v8 ()))
  val () = eqBase (lab "full/base", (l8, 0, 8), fn () => S.full (v8 ()))
  val () = eqS (lab "full/empty-vector", [], fn () => S.full (vec []))
  val () = eqBase (lab "full/empty-vector-base", ([], 0, 0), fn () => S.full (vec []))

  (* ---- subslice: "creates a slice based on the given slice sl starting at
     index i of sl. If sz is NONE, the slice includes all of the elements to
     the end of the slice, i.e., sl[i..|sl|-1]. This raises Subscript if i < 0
     or |sl| < i. If sz is SOME(j), the slice has length j, that is, it
     corresponds to sl[i..i+j-1]. It raises Subscript if i < 0 or j < 0 or
     |sl| < i + j." The bounds are those of the slice, not of its vector. ---- *)
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
  val () = T.raises (lab "subslice/SOME-Subscript-within-the-vector", T.isSubscript, fn () => S.subslice (mid (), 2, SOME 3))
  val () = T.raises (lab "subslice/SOME-Subscript-beyond", T.isSubscript, fn () => S.subslice (mid (), 5, SOME 0))
  val () = eqS (lab "subslice/of-empty", [], fn () => S.subslice (nothing (), 0, NONE))
  val () = T.raises (lab "subslice/of-empty-Subscript", T.isSubscript, fn () => S.subslice (nothing (), 1, NONE))
  val () = eqArgs (lab "subslice/every-argument", [],
                   fn () => List.filter (fn (i, sz) => (SOME (startAndLength (S.subslice (mid (), i, sz))) handle Subscript => NONE)
                                                       <> Option.map (fn (s, n) => (2 + s, n)) (model (4, i, sz))) arguments)

  (* ---- length, sub: "returns the i(th) element of the slice sl. If i < 0 or
     |sl| <= i, then the Subscript exception is raised." ---- *)
  val () = eqI (lab "length/middle", 4, fn () => S.length (mid ()))
  val () = eqI (lab "length/full", 8, fn () => S.length (S.full (v8 ())))
  val () = eqI (lab "length/empty", 0, fn () => S.length (nothing ()))
  val () = eqI (lab "sub/first", 2, fn () => code (S.sub (mid (), 0)))
  val () = eqI (lab "sub/last", 5, fn () => code (S.sub (mid (), 3)))
  val () = T.raises (lab "sub/Subscript-length-within-the-vector", T.isSubscript, fn () => S.sub (mid (), 4))
  val () = T.raises (lab "sub/Subscript-negative-within-the-vector", T.isSubscript, fn () => S.sub (mid (), !minusOne))
  val () = T.raises (lab "sub/Subscript-beyond", T.isSubscript, fn () => S.sub (mid (), 1000))
  val () = T.raises (lab "sub/Subscript-empty", T.isSubscript, fn () => S.sub (nothing (), 0))

  (* ---- base: "returns a triple (vec, i, n) representing the concrete
     representation of the slice" ---- *)
  val () = eqBase (lab "base/middle", (l8, 2, 4), mid)
  val () = eqBase (lab "base/empty", (l8, 3, 0), nothing)
  val () = eqS (lab "base/round-trip", lMid, fn () => let val (v, i, n) = S.base (mid ()) in S.slice (v, i, SOME n) end)

  (* ---- vector: "if vec is the resulting vector, we have |vec| = |sl| and,
     for 0 <= i < |sl|, element i of vec is sub (sl, i)" ---- *)
  val () = eqV (lab "vector/middle", lMid, fn () => S.vector (mid ()))
  val () = eqV (lab "vector/full", l8, fn () => S.vector (S.full (v8 ())))
  val () = eqV (lab "vector/empty", [], fn () => S.vector (nothing ()))

  (* ---- concat: "the concatenation of all the vectors in l" ---- *)
  val () = eqV (lab "concat/basic", [2, 3, 4, 5, 7, 0, 1],
                fn () => S.concat [mid (), nothing (), S.slice (v8 (), 7, NONE), S.slice (v8 (), 0, SOME 2)])
  val () = eqV (lab "concat/nil", [], fn () => S.concat [])
  val () = eqV (lab "concat/one", lMid, fn () => S.concat [mid ()])
  val () = eqV (lab "concat/empties", [], fn () => S.concat [nothing (), nothing ()])
  val () = eqV (lab "concat/same-twice", lMid @ lMid, fn () => let val sl = mid () in S.concat [sl, sl] end)

  (* ---- isEmpty, getItem: "returns the first item in sl and the rest of the
     slice, or NONE if sl is empty" ---- *)
  val () = eqB (lab "isEmpty/empty", true, fn () => S.isEmpty (nothing ()))
  val () = eqB (lab "isEmpty/empty-at-length", true, fn () => S.isEmpty (S.slice (v8 (), 8, NONE)))
  val () = eqB (lab "isEmpty/empty-vector", true, fn () => S.isEmpty (S.full (vec [])))
  val () = eqB (lab "isEmpty/one", false, fn () => S.isEmpty (S.slice (v8 (), 7, NONE)))
  val () = eqB (lab "isEmpty/middle", false, fn () => S.isEmpty (mid ()))
  val () = eqO (lab "getItem/first", SOME 2, fn () => Option.map (code o #1) (S.getItem (mid ())))
  val () = eqL (lab "getItem/rest", [3, 4, 5], fn () => case S.getItem (mid ()) of SOME (_, r) => toList r | NONE => [~1])
  val () = T.eq (T.option showBase) (lab "getItem/rest-base", SOME (l8, 3, 3),
                                     fn () => Option.map (baseOf o #2) (S.getItem (mid ())))
  val () = eqL (lab "getItem/last-rest-is-empty", [7],
                fn () => case S.getItem (S.slice (v8 (), 7, NONE)) of
                           SOME (x, r) => if S.isEmpty r then [code x] else [~1]
                         | NONE => [])
  val () = eqB (lab "getItem/empty", true, fn () => not (Option.isSome (S.getItem (nothing ()))))
  val () = eqL (lab "getItem/every-item", lMid,
                fn () => let fun go sl = case S.getItem sl of SOME (x, r) => code x :: go r | NONE => [] in go (mid ()) end)

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

  (* ---- mapi, map: "generate new vectors by mapping the function f from left
     to right over the argument slice"; mapi "supplies both the element and
     the element's index in the slice". With f (i, x) = the sample
     (2 * i + code x) mod 8 over [2, 3, 4, 5]: 0+2, 2+3, 4+4 = 0, (6+5) mod 8 = 3. ---- *)
  val () = eqV (lab "mapi/basic", [2, 5, 0, 3], fn () => S.mapi (fn (i, x) => e ((2 * i + code x) mod 8)) (mid ()))
  val () = eqV (lab "mapi/index-in-the-slice", [0, 1, 2, 3], fn () => S.mapi (fn (i, _) => e i) (mid ()))
  val () = eqV (lab "mapi/empty", [], fn () => S.mapi (fn (_, x) => x) (nothing ()))
  val () = eqIL (lab "mapi/order", iMid,
                 fn () => let val (f, seen) = codedI (trace (fn (_, x) => x)) in ignore (S.mapi f (mid ())); seen () end)
  val () = eqV (lab "map/basic", [3, 4, 5, 6], fn () => S.map next (mid ()))
  val () = eqV (lab "map/empty", [], fn () => S.map next (nothing ()))
  val () = eqL (lab "map/order", lMid,
                fn () => let val (f, seen) = coded (trace next) in ignore (S.map f (mid ())); seen () end)
  val () = eqBase (lab "map/argument-unchanged", (l8, 2, 4), fn () => let val sl = mid () in ignore (S.map next sl); sl end)

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
  fun sl (l, i, n) = S.slice (vec l, i, SOME n)
  val () = eqOrd (lab "collate/equal-in-different-vectors", EQUAL,
                  fn () => S.collate cmp (sl ([7, 1, 2, 7], 1, 2), sl ([0, 0, 1, 2], 2, 2)))
  val () = eqOrd (lab "collate/same-slice", EQUAL, fn () => let val s = mid () in S.collate cmp (s, s) end)
  val () = eqOrd (lab "collate/empty-empty", EQUAL, fn () => S.collate cmp (nothing (), S.full (vec [])))
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
  val () = T.seed 35
  val () = T.repeat (25, fn k =>
    let
      val t = "-" ^ Int.toString k
      val whole = randomList (T.range (0, 12))
      val len = List.length whole
      val i = T.range (0, len)
      val n = T.range (0, len - i)
      val l = part (whole, i, n)                 (* the elements of the slice *)
      fun s () = S.slice (vec whole, i, SOME n)
      val whole2 = randomList (T.range (0, 12))
      val i2 = T.range (0, List.length whole2)
      val m = List.drop (whole2, i2)
      fun s2 () = S.slice (vec whole2, i2, NONE)
      val j = T.range (~1, n + 1)                 (* an index, or one off either end *)
      val sz = if T.range (0, 2) = 0 then NONE else SOME (T.range (~1, n + 1))
      val fi = fn (j, c) => (3 * j + c) mod 8
      val hi = fn (j, c, b) => j * c - 2 * b
      val h = fn (c, b) => c - 2 * b
      val pi = fn (j, c) => (j + c) mod 3 = 0
      val p = fn c => c mod 3 = 0
    in
      eqS (lab "slice/model" ^ t, l, s);
      eqBase (lab "base/model" ^ t, (whole, i, n), s);
      eqI (lab "length/model" ^ t, n, fn () => S.length (s ()));
      eqS (lab "full/model" ^ t, whole, fn () => S.full (vec whole));
      (if 0 <= j andalso j < n
       then eqI (lab "sub/model" ^ t, List.nth (l, j), fn () => code (S.sub (s (), j)))
       else T.raises (lab "sub/model" ^ t, T.isSubscript, fn () => S.sub (s (), j)));
      (case model (n, j, sz) of
         SOME (a, b) => eqBase (lab "subslice/model" ^ t, (whole, i + a, b), fn () => S.subslice (s (), j, sz))
       | NONE => T.raises (lab "subslice/model" ^ t, T.isSubscript, fn () => S.subslice (s (), j, sz)));
      eqV (lab "vector/model" ^ t, l, fn () => S.vector (s ()));
      eqV (lab "concat/model" ^ t, l @ m @ l, fn () => S.concat [s (), s2 (), s ()]);
      eqB (lab "isEmpty/model" ^ t, n = 0, fn () => S.isEmpty (s ()));
      T.eq (T.option (T.pair (showCode, showBase)))
        (lab "getItem/model" ^ t, if n = 0 then NONE else SOME (List.hd l, (whole, i + 1, n - 1)),
         fn () => Option.map (fn (x, r) => (code x, baseOf r)) (S.getItem (s ())));
      eqIL (lab "appi/model" ^ t, indexed l,
            fn () => let val (f, seen) = codedI (trace (fn _ => ())) in S.appi f (s ()); seen () end);
      eqL (lab "app/model" ^ t, l,
           fn () => let val (f, seen) = coded (trace (fn _ => ())) in S.app f (s ()); seen () end);
      eqV (lab "mapi/model" ^ t, List.map fi (indexed l), fn () => S.mapi (fn (j, c) => e (fi (j, code c))) (s ()));
      eqV (lab "map/model" ^ t, List.map (fn c => (c + 1) mod 8) l, fn () => S.map next (s ()));
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
      eqOrd (lab "collate/reflexive" ^ t, EQUAL, fn () => S.collate cmp (s (), S.full (vec l)))
    end)

  (* ---- long slices: no stack or quadratic trouble ---- *)
  fun long () = S.slice (V.tabulate (100002, fn i => e (i mod 8)), 1, SOME 100000)
  val () = eqI (lab "length/long", 100000, fn () => S.length (long ()))
  val () = eqI (lab "sub/long", 0, fn () => code (S.sub (long (), 99999)))   (* element 100000 of the vector *)
  val () = eqI (lab "foldl/long", 12500, fn () => S.foldl (fn (c, k) => if code c = 7 then k + 1 else k) 0 (long ()))
  val () = eqI (lab "foldr/long", 100000, fn () => List.length (S.foldr (op ::) [] (long ())))
  val () = eqI (lab "map/long", 1, fn () => code (V.sub (S.map next (long ()), 99999)))
  val () = eqI (lab "vector/long", 100000, fn () => V.length (S.vector (long ())))
  val () = eqI (lab "getItem/long", 100000,
                fn () => let fun go (sl, k) = case S.getItem sl of SOME (_, r) => go (r, k + 1) | NONE => k in go (long (), 0) end)
  val () = eqI (lab "concat/many", 100000,
                fn () => let val v = V.tabulate (1100, fn i => e (i mod 8))
                         in V.length (S.concat (List.tabulate (1000, fn i => S.slice (v, i, SOME 100)))) end)
  val () = eqOrd (lab "collate/long", EQUAL, fn () => S.collate cmp (long (), long ()))
end

(* Subscript, not Overflow: the page gives the conditions as "i < 0 or j < 0 or
   |vec| < i + j" and "i < 0 or |sl| <= i", which hold for the numbers below
   although i + j, or the index in the vector, does not exist as an int (in the
   checks labelled sum-* both numbers are valid by themselves). *)
functor TestMonoVectorSliceOverflowFn (structure V : SPEC_MONO_VECTOR
                                       structure S : SPEC_MONO_VECTOR_SLICE where type vector = V.vector where type elem = V.elem
                                       val name : string
                                       val elem : V.elem) =
struct
  fun lab s = name ^ "." ^ s
  val most = case Int.maxInt of SOME m => m | NONE => 1073741823
  val least = case Int.minInt of SOME m => m | NONE => ~1073741824
  fun v8 () = V.tabulate (8, fn _ => elem)
  fun mid () = S.slice (v8 (), 2, SOME 4)
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.slice (v8 (), 1, SOME most))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.slice (v8 (), most, SOME 1))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.slice (v8 (), most, SOME most))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-least-start", T.isSubscript, fn () => S.slice (v8 (), least, SOME 1))
  val () = T.raises (lab "slice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.slice (v8 (), 1, SOME least))
  val () = T.raises (lab "slice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.slice (v8 (), most, NONE))
  val () = T.raises (lab "slice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.slice (v8 (), least, NONE))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-sum-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME most))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-sum-start", T.isSubscript, fn () => S.subslice (mid (), most, SOME 1))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-sum-both", T.isSubscript, fn () => S.subslice (mid (), most, SOME most))
  val () = T.raises (lab "subslice/SOME-Subscript-not-Overflow-least-size", T.isSubscript, fn () => S.subslice (mid (), 1, SOME least))
  val () = T.raises (lab "subslice/NONE-Subscript-not-Overflow", T.isSubscript, fn () => S.subslice (mid (), most, NONE))
  val () = T.raises (lab "subslice/NONE-Subscript-not-Overflow-least", T.isSubscript, fn () => S.subslice (mid (), least, NONE))
  val () = T.raises (lab "sub/Subscript-not-Overflow", T.isSubscript, fn () => S.sub (mid (), most))
  val () = T.raises (lab "sub/Subscript-not-Overflow-least", T.isSubscript, fn () => S.sub (mid (), least))
end

(* concat "raises Size if the sum of all the lengths is greater than the
   maximum length allowed by vectors of type vector". concat can only be given
   more than V.maxLen elements where maxLen is small: 1024 times the full
   slice of a vector of maxLen div 1024 + 1 elements. An implementation that
   does not make the check may run out of memory, so a test applies this
   functor in a section of its own. *)
functor TestMonoVectorSliceSizeFn (structure V : SPEC_MONO_VECTOR
                                   structure S : SPEC_MONO_VECTOR_SLICE where type vector = V.vector where type elem = V.elem
                                   val name : string
                                   val elem : V.elem) =
struct
  fun lab s = name ^ "." ^ s
  val () =
    if V.maxLen <= 16777216
    then T.raises (lab "concat/Size-above-maxLen", T.isSize,
                   fn () => let val part = S.full (V.tabulate (V.maxLen div 1024 + 1, fn _ => elem))
                            in S.concat (List.tabulate (1024, fn _ => part)) end)
    else ()
end
