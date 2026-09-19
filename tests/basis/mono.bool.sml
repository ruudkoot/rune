(* requires: BoolVector BoolArray List String *)
(* BoolVector, BoolArray, BoolVectorSlice, BoolArraySlice and BoolArray2
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = bool"). Expected values
   follow mono-vector.html, mono-array.html, mono-vector-slice.html,
   mono-array-slice.html and mono-array2.html.

   The test functors of fn/ need eight distinct elements, and bool has two, so
   the checks are written here for each member. A sequence of booleans is
   written as a string of t and f: "tff" is [true, false, false], and a
   two-dimensional array is the list of the strings of its rows. The arrays of
   a check are made inside its thunk. The slices and the two-dimensional
   arrays are in sections, for a host that has the vectors and arrays
   alone. *)
structure TestMonoBool =
struct
  structure V = BoolVector
  structure A = BoolArray

  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqOrd = T.eq T.order
  val eqInts = T.eq (T.list T.int)
  val eqBools = T.eq (T.list T.bool)
  val eqIB = T.eq (T.list (T.pair (T.int, T.bool)))
  val eqIBO = T.eq (T.option (T.pair (T.int, T.bool)))
  val eqBO = T.eq (T.option T.bool)

  fun bools s = List.map (fn c => c = #"t") (String.explode s)
  fun text l = String.implode (List.map (fn true => #"t" | false => #"f") l)
  fun vec s = V.fromList (bools s)
  fun showV v = text (List.tabulate (V.length v, fn i => V.sub (v, i)))
  fun arr s = A.fromList (bools s)
  fun showA a = text (List.tabulate (A.length a, fn i => A.sub (a, i)))
  fun eqV (label, expected, f) = eqS (label, expected, fn () => showV (f ()))
  fun eqA (label, expected, f) = eqS (label, expected, fn () => showA (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end
  fun seenBy app f s = let val (g, seen) = trace f in app g s; seen () end

  val minusOne = ref ~1
  (* false < true *)
  fun cmp (false, true) = LESS
    | cmp (true, false) = GREATER
    | cmp _ = EQUAL
  (* a number in binary, the most significant digit first: foldl and foldli
     see the digits in order, foldr and foldri in reverse *)
  fun digit (b, n) = 2 * n + (if b then 1 else 0)
  fun digitI (i, b, n) = 2 * n + (if b then i + 1 else 0)

  (* ---- BoolVector ---- *)
  val () = eqB ("BoolVector.maxLen/covers-created-vectors", true, fn () => V.length (V.tabulate (1000, fn _ => true)) <= V.maxLen)
  val () = eqV ("BoolVector.fromList/basic", "tft", fn () => V.fromList [true, false, true])
  val () = eqV ("BoolVector.fromList/nil", "", fn () => V.fromList [])
  val () = eqI ("BoolVector.fromList/length", 5, fn () => V.length (vec "ttfft"))
  val () = eqV ("BoolVector.tabulate/basic", "tftft", fn () => V.tabulate (5, fn i => i mod 2 = 0))
  val () = eqV ("BoolVector.tabulate/zero", "", fn () => V.tabulate (0, fn _ => true))
  val () = eqInts ("BoolVector.tabulate/order", [0, 1, 2, 3],
                   fn () => let val (f, seen) = trace (fn _ => true) in ignore (V.tabulate (4, f)); seen () end)
  val () = T.raises ("BoolVector.tabulate/Size-negative", T.isSize, fn () => V.tabulate (!minusOne, fn _ => true))
  val () = eqInts ("BoolVector.tabulate/Size-before-f", [],
                   fn () => let val (f, seen) = trace (fn _ => true) in ignore (V.tabulate (~3, f)) handle Size => (); seen () end)
  val () = eqI ("BoolVector.length/empty", 0, fn () => V.length (vec ""))
  val () = eqI ("BoolVector.length/long", 100000, fn () => V.length (V.tabulate (100000, fn i => i mod 3 = 0)))
  val () = eqBools ("BoolVector.sub/each", [false, true, true], fn () => List.map (fn i => V.sub (vec "ftt", i)) [0, 1, 2])
  val () = T.raises ("BoolVector.sub/Subscript-length", T.isSubscript, fn () => V.sub (vec "ftt", 3))
  val () = T.raises ("BoolVector.sub/Subscript-negative", T.isSubscript, fn () => V.sub (vec "ftt", !minusOne))
  val () = T.raises ("BoolVector.sub/Subscript-empty", T.isSubscript, fn () => V.sub (vec "", 0))
  val () = eqV ("BoolVector.update/first", "tfff", fn () => V.update (vec "ffff", 0, true))
  val () = eqV ("BoolVector.update/middle", "fftf", fn () => V.update (vec "ffff", 2, true))
  val () = eqV ("BoolVector.update/last", "ttft", fn () => V.update (vec "tttt", 2, false))
  val () = eqV ("BoolVector.update/argument-unchanged", "ffff", fn () => let val v = vec "ffff" in ignore (V.update (v, 1, true)); v end)
  val () = T.raises ("BoolVector.update/Subscript-length", T.isSubscript, fn () => V.update (vec "ff", 2, true))
  val () = T.raises ("BoolVector.update/Subscript-negative", T.isSubscript, fn () => V.update (vec "ff", !minusOne, true))
  val () = eqV ("BoolVector.concat/basic", "tffft", fn () => V.concat [vec "tf", vec "", vec "ff", vec "t"])
  val () = eqV ("BoolVector.concat/nil", "", fn () => V.concat [])
  val () = eqV ("BoolVector.concat/empties", "", fn () => V.concat [vec "", vec ""])
  val () = eqIB ("BoolVector.appi/order", [(0, true), (1, false), (2, false)], fn () => seenBy V.appi (fn _ => ()) (vec "tff"))
  val () = eqIB ("BoolVector.appi/empty", [], fn () => seenBy V.appi (fn _ => ()) (vec ""))
  val () = eqBools ("BoolVector.app/order", [false, true, true, false], fn () => seenBy V.app (fn _ => ()) (vec "fttf"))
  (* (i mod 2 = 0) <> b over t t f f *)
  val () = eqV ("BoolVector.mapi/basic", "fttf", fn () => V.mapi (fn (i, b) => (i mod 2 = 0) <> b) (vec "ttff"))
  val () = eqIB ("BoolVector.mapi/order", [(0, true), (1, true), (2, false)], fn () => seenBy (fn f => ignore o V.mapi f) (fn (_, b) => b) (vec "ttf"))
  val () = eqV ("BoolVector.map/not", "ftt", fn () => V.map not (vec "tff"))
  val () = eqV ("BoolVector.map/empty", "", fn () => V.map not (vec ""))
  val () = eqBools ("BoolVector.map/order", [true, false, false], fn () => seenBy (fn f => ignore o V.map f) not (vec "tff"))
  (* digitI over t f t: foldli 0*2+1 = 1, 1*2+0 = 2, 2*2+3 = 7; foldri 0*2+3 = 3, 3*2+0 = 6, 6*2+1 = 13 *)
  val () = eqIB ("BoolVector.foldli/conses-reversed", [(1, false), (0, true)], fn () => V.foldli (fn (i, b, l) => (i, b) :: l) [] (vec "tf"))
  val () = eqI ("BoolVector.foldli/nonassociative", 7, fn () => V.foldli digitI 0 (vec "tft"))
  val () = eqI ("BoolVector.foldli/empty", 42, fn () => V.foldli digitI 42 (vec ""))
  val () = eqIB ("BoolVector.foldri/conses-in-order", [(0, true), (1, false)], fn () => V.foldri (fn (i, b, l) => (i, b) :: l) [] (vec "tf"))
  val () = eqI ("BoolVector.foldri/nonassociative", 13, fn () => V.foldri digitI 0 (vec "tft"))
  (* digit over t f f: foldl reads 100 = 4, foldr reads 001 = 1 *)
  val () = eqI ("BoolVector.foldl/nonassociative", 4, fn () => V.foldl digit 0 (vec "tff"))
  val () = eqBools ("BoolVector.foldl/conses-reversed", [false, false, true], fn () => V.foldl op :: [] (vec "tff"))
  val () = eqI ("BoolVector.foldr/nonassociative", 1, fn () => V.foldr digit 0 (vec "tff"))
  val () = eqBools ("BoolVector.foldr/conses-in-order", [true, false, false], fn () => V.foldr op :: [] (vec "tff"))
  val () = eqIBO ("BoolVector.findi/first-true", SOME (2, true), fn () => V.findi #2 (vec "fftft"))
  val () = eqIBO ("BoolVector.findi/by-index", SOME (3, false), fn () => V.findi (fn (i, _) => i = 3) (vec "fftft"))
  val () = eqIBO ("BoolVector.findi/none", NONE, fn () => V.findi #2 (vec "fff"))
  val () = eqIBO ("BoolVector.findi/empty", NONE, fn () => V.findi (fn _ => true) (vec ""))
  val () = eqIB ("BoolVector.findi/stops", [(0, false), (1, false), (2, true)], fn () => seenBy (fn f => ignore o V.findi f) #2 (vec "fftft"))
  val () = eqBO ("BoolVector.find/true", SOME true, fn () => V.find (fn b => b) (vec "fft"))
  val () = eqBO ("BoolVector.find/false", SOME false, fn () => V.find not (vec "tft"))
  val () = eqBO ("BoolVector.find/none", NONE, fn () => V.find not (vec "ttt"))
  val () = eqBools ("BoolVector.find/stops", [true, false], fn () => seenBy (fn f => ignore o V.find f) not (vec "tftf"))
  val () = eqB ("BoolVector.exists/true", true, fn () => V.exists (fn b => b) (vec "fft"))
  val () = eqB ("BoolVector.exists/false", false, fn () => V.exists (fn b => b) (vec "fff"))
  val () = eqB ("BoolVector.exists/empty", false, fn () => V.exists (fn _ => true) (vec ""))
  val () = eqBools ("BoolVector.exists/stops", [false, true], fn () => seenBy (fn f => ignore o V.exists f) (fn b => b) (vec "ftf"))
  val () = eqB ("BoolVector.all/true", true, fn () => V.all (fn b => b) (vec "ttt"))
  val () = eqB ("BoolVector.all/false", false, fn () => V.all (fn b => b) (vec "tft"))
  val () = eqB ("BoolVector.all/empty", true, fn () => V.all (fn _ => false) (vec ""))
  val () = eqBools ("BoolVector.all/stops", [true, false], fn () => seenBy (fn f => ignore o V.all f) (fn b => b) (vec "tft"))
  fun collateV (s, t) = V.collate cmp (vec s, vec t)
  val () = eqOrd ("BoolVector.collate/equal", EQUAL, fn () => collateV ("tf", "tf"))
  val () = eqOrd ("BoolVector.collate/empty-empty", EQUAL, fn () => collateV ("", ""))
  val () = eqOrd ("BoolVector.collate/empty-less", LESS, fn () => collateV ("", "f"))
  val () = eqOrd ("BoolVector.collate/prefix-less", LESS, fn () => collateV ("t", "tf"))
  val () = eqOrd ("BoolVector.collate/prefix-greater", GREATER, fn () => collateV ("tf", "t"))
  val () = eqOrd ("BoolVector.collate/first-difference", LESS, fn () => collateV ("tft", "ttf"))
  val () = eqOrd ("BoolVector.collate/not-by-length", LESS, fn () => collateV ("ftt", "t"))
  val () = eqOrd ("BoolVector.collate/given-ordering", GREATER, fn () => V.collate (fn (a, b) => cmp (b, a)) (vec "ftt", vec "t"))

  (* ---- BoolArray ---- *)
  val () = eqB ("BoolArray.maxLen/covers-created-arrays", true, fn () => A.length (A.array (1000, true)) <= A.maxLen)
  val () = eqA ("BoolArray.array/basic", "ttt", fn () => A.array (3, true))
  val () = eqA ("BoolArray.array/zero", "", fn () => A.array (0, true))
  val () = T.raises ("BoolArray.array/Size-negative", T.isSize, fn () => A.array (!minusOne, true))
  val () = eqA ("BoolArray.array/elements-are-separate", "ftf", fn () => let val a = A.array (3, false) in A.update (a, 1, true); a end)
  val () = eqA ("BoolArray.fromList/basic", "tft", fn () => A.fromList [true, false, true])
  val () = eqA ("BoolArray.fromList/nil", "", fn () => A.fromList [])
  val () = eqA ("BoolArray.tabulate/basic", "fftff", fn () => A.tabulate (5, fn i => i = 2))
  val () = eqInts ("BoolArray.tabulate/order", [0, 1, 2],
                   fn () => let val (f, seen) = trace (fn _ => true) in ignore (A.tabulate (3, f)); seen () end)
  val () = T.raises ("BoolArray.tabulate/Size-negative", T.isSize, fn () => A.tabulate (!minusOne, fn _ => true))
  val () = eqInts ("BoolArray.tabulate/Size-before-f", [],
                   fn () => let val (f, seen) = trace (fn _ => true) in ignore (A.tabulate (~3, f)) handle Size => (); seen () end)
  val () = eqI ("BoolArray.length/basic", 4, fn () => A.length (arr "tfft"))
  val () = eqI ("BoolArray.length/empty", 0, fn () => A.length (arr ""))
  val () = eqBools ("BoolArray.sub/each", [true, false, false], fn () => List.map (fn i => A.sub (arr "tff", i)) [0, 1, 2])
  val () = T.raises ("BoolArray.sub/Subscript-length", T.isSubscript, fn () => A.sub (arr "tff", 3))
  val () = T.raises ("BoolArray.sub/Subscript-negative", T.isSubscript, fn () => A.sub (arr "tff", !minusOne))
  val () = eqA ("BoolArray.update/basic", "tfft", fn () => let val a = arr "tfff" in A.update (a, 3, true); a end)
  val () = eqA ("BoolArray.update/twice", "ffff", fn () => let val a = arr "ffff" in A.update (a, 1, true); A.update (a, 1, false); a end)
  val () = T.raises ("BoolArray.update/Subscript-length", T.isSubscript, fn () => A.update (arr "tff", 3, true))
  val () = T.raises ("BoolArray.update/Subscript-negative", T.isSubscript, fn () => A.update (arr "tff", !minusOne, true))
  val () = eqA ("BoolArray.update/Subscript-changes-nothing", "tff",
                fn () => let val a = arr "tff" in A.update (a, 3, true) handle Subscript => (); a end)
  val () = eqV ("BoolArray.vector/basic", "tft", fn () => A.vector (arr "tft"))
  val () = eqV ("BoolArray.vector/is-a-snapshot", "tft", fn () => let val a = arr "tft" val v = A.vector a in A.update (a, 1, true); v end)
  (* copy: "copies the entire array src into the array dst, with the i(th)
     element in src stored at the (di+i)(th) position in the destination
     array. If di < 0 or if |dst| < di+|src|, then the Subscript exception is
     raised." *)
  fun copyA (src, dst, di) = let val d = arr dst in A.copy {src = arr src, dst = d, di = di}; d end
  val () = eqA ("BoolArray.copy/middle", "fttf", fn () => copyA ("tt", "ffff", 1))
  val () = eqA ("BoolArray.copy/to-the-end", "fftf", fn () => copyA ("tf", "ffff", 2))
  val () = eqA ("BoolArray.copy/empty-at-length", "ff", fn () => copyA ("", "ff", 2))
  val () = eqA ("BoolArray.copy/onto-itself", "tft", fn () => let val a = arr "tft" in A.copy {src = a, dst = a, di = 0}; a end)
  val () = T.raises ("BoolArray.copy/Subscript-too-long", T.isSubscript, fn () => copyA ("tt", "ffff", 3))
  val () = T.raises ("BoolArray.copy/Subscript-negative", T.isSubscript, fn () => copyA ("tt", "ffff", ~1))
  val () = eqA ("BoolArray.copy/Subscript-changes-nothing", "ffff",
                fn () => let val d = arr "ffff" in A.copy {src = arr "ttt", dst = d, di = 2} handle Subscript => (); d end)
  fun copyVecA (src, dst, di) = let val d = arr dst in A.copyVec {src = vec src, dst = d, di = di}; d end
  val () = eqA ("BoolArray.copyVec/middle", "fttf", fn () => copyVecA ("tt", "ffff", 1))
  val () = eqA ("BoolArray.copyVec/whole", "tft", fn () => copyVecA ("tft", "fff", 0))
  val () = T.raises ("BoolArray.copyVec/Subscript-too-long", T.isSubscript, fn () => copyVecA ("tt", "ffff", 3))
  val () = T.raises ("BoolArray.copyVec/Subscript-negative", T.isSubscript, fn () => copyVecA ("tt", "ffff", ~1))
  val () = eqIB ("BoolArray.appi/order", [(0, false), (1, true)], fn () => seenBy A.appi (fn _ => ()) (arr "ft"))
  val () = eqBools ("BoolArray.app/order", [true, true, false], fn () => seenBy A.app (fn _ => ()) (arr "ttf"))
  val () = eqA ("BoolArray.modifyi/basic", "tftt", fn () => let val a = arr "ffft" in A.modifyi (fn (i, b) => i mod 2 = 0 orelse b) a; a end)
  val () = eqIB ("BoolArray.modifyi/order", [(0, false), (1, false), (2, true)],
                 fn () => let val a = arr "fft" in seenBy A.modifyi #2 a end)
  val () = eqA ("BoolArray.modify/not", "ftt", fn () => let val a = arr "tff" in A.modify not a; a end)
  val () = eqBools ("BoolArray.modify/order", [true, false, false], fn () => seenBy A.modify not (arr "tff"))
  val () = eqI ("BoolArray.foldli/nonassociative", 7, fn () => A.foldli digitI 0 (arr "tft"))
  val () = eqI ("BoolArray.foldri/nonassociative", 13, fn () => A.foldri digitI 0 (arr "tft"))
  val () = eqI ("BoolArray.foldl/nonassociative", 4, fn () => A.foldl digit 0 (arr "tff"))
  val () = eqI ("BoolArray.foldr/nonassociative", 1, fn () => A.foldr digit 0 (arr "tff"))
  val () = eqI ("BoolArray.foldl/empty", 42, fn () => A.foldl digit 42 (arr ""))
  val () = eqIBO ("BoolArray.findi/first-true", SOME (2, true), fn () => A.findi #2 (arr "fftft"))
  val () = eqIBO ("BoolArray.findi/none", NONE, fn () => A.findi #2 (arr "fff"))
  val () = eqIB ("BoolArray.findi/stops", [(0, false), (1, true)], fn () => seenBy (fn f => ignore o A.findi f) #2 (arr "ftt"))
  val () = eqBO ("BoolArray.find/false", SOME false, fn () => A.find not (arr "tft"))
  val () = eqBO ("BoolArray.find/none", NONE, fn () => A.find not (arr ""))
  val () = eqB ("BoolArray.exists/true", true, fn () => A.exists not (arr "ttf"))
  val () = eqB ("BoolArray.exists/false", false, fn () => A.exists not (arr "ttt"))
  val () = eqBools ("BoolArray.exists/stops", [true, false], fn () => seenBy (fn f => ignore o A.exists f) not (arr "tff"))
  val () = eqB ("BoolArray.all/true", true, fn () => A.all not (arr "fff"))
  val () = eqB ("BoolArray.all/false", false, fn () => A.all not (arr "ftf"))
  val () = eqB ("BoolArray.all/empty", true, fn () => A.all (fn _ => false) (arr ""))
  val () = eqOrd ("BoolArray.collate/equal", EQUAL, fn () => A.collate cmp (arr "tft", arr "tft"))
  val () = eqOrd ("BoolArray.collate/first-difference", GREATER, fn () => A.collate cmp (arr "tt", arr "tft"))
  val () = eqOrd ("BoolArray.collate/prefix-less", LESS, fn () => A.collate cmp (arr "tf", arr "tff"))
  val () = eqOrd ("BoolArray.collate/empty-less", LESS, fn () => A.collate cmp (arr "", arr "f"))
  (* "two arrays are equal if they are the same array" *)
  val () = eqB ("BoolArray.array/same-array-is-equal", true, fn () => let val a = arr "tf" in a = a end)
  val () = eqB ("BoolArray.array/same-elements-not-equal", false, fn () => arr "tf" = arr "tf")

  (*<< slices *)
  (* ---- BoolVectorSlice: "A slice value can be viewed as a triple (v, i, n),
     where v is the underlying vector, i is the starting index, and n is the
     length of the subarray". The indices that appi, mapi, foldli, foldri and
     findi pass are those in the slice. ---- *)
  structure VS = BoolVectorSlice
  fun showVS s = text (List.tabulate (VS.length s, fn i => VS.sub (s, i)))
  fun eqVS (label, expected, f) = eqS (label, expected, fn () => showVS (f ()))
  (* t t f f t f, and the slice f f t of it from index 2 *)
  fun v6 () = vec "ttfftf"
  fun mid () = VS.slice (v6 (), 2, SOME 3)
  val () = eqI ("BoolVectorSlice.length/basic", 3, fn () => VS.length (mid ()))
  val () = eqI ("BoolVectorSlice.length/NONE", 4, fn () => VS.length (VS.slice (v6 (), 2, NONE)))
  val () = eqBools ("BoolVectorSlice.sub/each", [false, false, true], fn () => List.map (fn i => VS.sub (mid (), i)) [0, 1, 2])
  val () = T.raises ("BoolVectorSlice.sub/Subscript-length", T.isSubscript, fn () => VS.sub (mid (), 3))
  val () = T.raises ("BoolVectorSlice.sub/Subscript-negative", T.isSubscript, fn () => VS.sub (mid (), !minusOne))
  val () = eqVS ("BoolVectorSlice.full/basic", "tft", fn () => VS.full (vec "tft"))
  val () = eqVS ("BoolVectorSlice.full/empty", "", fn () => VS.full (vec ""))
  val () = eqVS ("BoolVectorSlice.slice/SOME", "fft", fn () => mid ())
  val () = eqVS ("BoolVectorSlice.slice/NONE", "fftf", fn () => VS.slice (v6 (), 2, NONE))
  val () = eqVS ("BoolVectorSlice.slice/NONE-at-length", "", fn () => VS.slice (v6 (), 6, NONE))
  val () = eqVS ("BoolVectorSlice.slice/SOME-zero", "", fn () => VS.slice (v6 (), 6, SOME 0))
  val () = T.raises ("BoolVectorSlice.slice/Subscript-NONE-beyond", T.isSubscript, fn () => VS.slice (v6 (), 7, NONE))
  val () = T.raises ("BoolVectorSlice.slice/Subscript-too-long", T.isSubscript, fn () => VS.slice (v6 (), 2, SOME 5))
  val () = T.raises ("BoolVectorSlice.slice/Subscript-negative", T.isSubscript, fn () => VS.slice (v6 (), !minusOne, NONE))
  val () = T.raises ("BoolVectorSlice.slice/Subscript-negative-size", T.isSubscript, fn () => VS.slice (v6 (), 0, SOME (!minusOne)))
  val () = eqVS ("BoolVectorSlice.subslice/NONE", "ft", fn () => VS.subslice (mid (), 1, NONE))
  val () = eqVS ("BoolVectorSlice.subslice/SOME", "t", fn () => VS.subslice (mid (), 2, SOME 1))
  val () = eqVS ("BoolVectorSlice.subslice/at-length", "", fn () => VS.subslice (mid (), 3, NONE))
  val () = T.raises ("BoolVectorSlice.subslice/Subscript-beyond", T.isSubscript, fn () => VS.subslice (mid (), 4, NONE))
  val () = T.raises ("BoolVectorSlice.subslice/Subscript-too-long", T.isSubscript, fn () => VS.subslice (mid (), 1, SOME 3))
  val () = T.raises ("BoolVectorSlice.subslice/Subscript-negative", T.isSubscript, fn () => VS.subslice (mid (), !minusOne, NONE))
  val () = T.eq (T.triple (T.string, T.int, T.int)) ("BoolVectorSlice.base/slice", ("ttfftf", 2, 3),
                                                     fn () => let val (v, i, n) = VS.base (mid ()) in (showV v, i, n) end)
  val () = T.eq (T.triple (T.string, T.int, T.int)) ("BoolVectorSlice.base/subslice", ("ttfftf", 3, 2),
                                                     fn () => let val (v, i, n) = VS.base (VS.subslice (mid (), 1, NONE)) in (showV v, i, n) end)
  val () = eqV ("BoolVectorSlice.vector/basic", "fft", fn () => VS.vector (mid ()))
  val () = eqV ("BoolVectorSlice.vector/empty", "", fn () => VS.vector (VS.slice (v6 (), 3, SOME 0)))
  val () = eqV ("BoolVectorSlice.concat/basic", "ffttt", fn () => VS.concat [mid (), VS.full (vec "tt")])
  val () = eqV ("BoolVectorSlice.concat/nil", "", fn () => VS.concat [])
  val () = eqB ("BoolVectorSlice.isEmpty/false", false, fn () => VS.isEmpty (mid ()))
  val () = eqB ("BoolVectorSlice.isEmpty/true", true, fn () => VS.isEmpty (VS.slice (v6 (), 6, NONE)))
  val () = T.eq (T.option (T.pair (T.bool, T.string))) ("BoolVectorSlice.getItem/first", SOME (false, "ft"),
                 fn () => Option.map (fn (b, rest) => (b, showVS rest)) (VS.getItem (mid ())))
  val () = eqB ("BoolVectorSlice.getItem/empty", true, fn () => not (isSome (VS.getItem (VS.full (vec "")))))
  val () = eqIB ("BoolVectorSlice.appi/slice-indices", [(0, false), (1, false), (2, true)], fn () => seenBy VS.appi (fn _ => ()) (mid ()))
  val () = eqBools ("BoolVectorSlice.app/order", [false, false, true], fn () => seenBy VS.app (fn _ => ()) (mid ()))
  (* (i = 1) <> b over f f t: f t t *)
  val () = eqV ("BoolVectorSlice.mapi/slice-indices", "ftt", fn () => VS.mapi (fn (i, b) => (i = 1) <> b) (mid ()))
  val () = eqV ("BoolVectorSlice.map/not", "ttf", fn () => VS.map not (mid ()))
  (* digitI over f f t: foldli 0, 0, 0*2+3 = 3; foldri 0+3 = 3, 6, 12 *)
  val () = eqI ("BoolVectorSlice.foldli/nonassociative", 3, fn () => VS.foldli digitI 0 (mid ()))
  val () = eqI ("BoolVectorSlice.foldri/nonassociative", 12, fn () => VS.foldri digitI 0 (mid ()))
  (* digit over f f t: foldl reads 001 = 1, foldr 100 = 4 *)
  val () = eqI ("BoolVectorSlice.foldl/nonassociative", 1, fn () => VS.foldl digit 0 (mid ()))
  val () = eqI ("BoolVectorSlice.foldr/nonassociative", 4, fn () => VS.foldr digit 0 (mid ()))
  val () = eqIBO ("BoolVectorSlice.findi/slice-index", SOME (2, true), fn () => VS.findi #2 (mid ()))
  val () = eqIBO ("BoolVectorSlice.findi/none", NONE, fn () => VS.findi (fn (i, _) => i > 2) (mid ()))
  val () = eqBO ("BoolVectorSlice.find/true", SOME true, fn () => VS.find (fn b => b) (mid ()))
  val () = eqBO ("BoolVectorSlice.find/none-in-the-slice", NONE, fn () => VS.find (fn b => b) (VS.slice (v6 (), 2, SOME 2)))
  val () = eqB ("BoolVectorSlice.exists/only-the-slice", false, fn () => VS.exists (fn b => b) (VS.slice (v6 (), 2, SOME 2)))
  val () = eqB ("BoolVectorSlice.exists/true", true, fn () => VS.exists (fn b => b) (mid ()))
  val () = eqB ("BoolVectorSlice.all/only-the-slice", true, fn () => VS.all (fn b => b) (VS.slice (v6 (), 0, SOME 2)))
  val () = eqB ("BoolVectorSlice.all/false", false, fn () => VS.all (fn b => b) (mid ()))
  val () = eqOrd ("BoolVectorSlice.collate/equal", EQUAL, fn () => VS.collate cmp (mid (), VS.full (vec "fft")))
  val () = eqOrd ("BoolVectorSlice.collate/less", LESS, fn () => VS.collate cmp (mid (), VS.slice (v6 (), 1, SOME 2)))
  val () = eqOrd ("BoolVectorSlice.collate/prefix-greater", GREATER, fn () => VS.collate cmp (mid (), VS.slice (v6 (), 2, SOME 2)))

  (* ---- BoolArraySlice ---- *)
  structure AS = BoolArraySlice
  fun showAS s = text (List.tabulate (AS.length s, fn i => AS.sub (s, i)))
  fun eqAS (label, expected, f) = eqS (label, expected, fn () => showAS (f ()))
  fun a6 () = arr "ttfftf"
  fun amid a = AS.slice (a, 2, SOME 3)
  val () = eqI ("BoolArraySlice.length/basic", 3, fn () => AS.length (amid (a6 ())))
  val () = eqBools ("BoolArraySlice.sub/each", [false, false, true], fn () => List.map (fn i => AS.sub (amid (a6 ()), i)) [0, 1, 2])
  val () = T.raises ("BoolArraySlice.sub/Subscript-length", T.isSubscript, fn () => AS.sub (amid (a6 ()), 3))
  val () = T.raises ("BoolArraySlice.sub/Subscript-negative", T.isSubscript, fn () => AS.sub (amid (a6 ()), !minusOne))
  val () = eqA ("BoolArraySlice.update/in-the-base", "ttftttf", fn () => let val a = arr "ttffttf" in AS.update (amid a, 1, true); a end)
  val () = T.raises ("BoolArraySlice.update/Subscript-length", T.isSubscript, fn () => AS.update (amid (a6 ()), 3, true))
  val () = T.raises ("BoolArraySlice.update/Subscript-negative", T.isSubscript, fn () => AS.update (amid (a6 ()), !minusOne, true))
  val () = eqAS ("BoolArraySlice.full/basic", "tft", fn () => AS.full (arr "tft"))
  val () = eqAS ("BoolArraySlice.slice/SOME", "fft", fn () => amid (a6 ()))
  val () = eqAS ("BoolArraySlice.slice/NONE", "fftf", fn () => AS.slice (a6 (), 2, NONE))
  val () = eqAS ("BoolArraySlice.slice/NONE-at-length", "", fn () => AS.slice (a6 (), 6, NONE))
  val () = T.raises ("BoolArraySlice.slice/Subscript-NONE-beyond", T.isSubscript, fn () => AS.slice (a6 (), 7, NONE))
  val () = T.raises ("BoolArraySlice.slice/Subscript-too-long", T.isSubscript, fn () => AS.slice (a6 (), 2, SOME 5))
  val () = T.raises ("BoolArraySlice.slice/Subscript-negative", T.isSubscript, fn () => AS.slice (a6 (), !minusOne, SOME 1))
  val () = eqAS ("BoolArraySlice.subslice/NONE", "ft", fn () => AS.subslice (amid (a6 ()), 1, NONE))
  val () = eqAS ("BoolArraySlice.subslice/SOME", "f", fn () => AS.subslice (amid (a6 ()), 1, SOME 1))
  val () = T.raises ("BoolArraySlice.subslice/Subscript-too-long", T.isSubscript, fn () => AS.subslice (amid (a6 ()), 2, SOME 2))
  val () = T.raises ("BoolArraySlice.subslice/Subscript-beyond", T.isSubscript, fn () => AS.subslice (amid (a6 ()), 4, NONE))
  val () = eqB ("BoolArraySlice.base/is-the-array", true,
                fn () => let val a = a6 () val (b, i, n) = AS.base (amid a) in b = a andalso i = 2 andalso n = 3 end)
  val () = eqV ("BoolArraySlice.vector/basic", "fft", fn () => AS.vector (amid (a6 ())))
  val () = eqV ("BoolArraySlice.vector/is-a-snapshot", "fft",
                fn () => let val a = a6 () val v = AS.vector (amid a) in A.update (a, 2, true); v end)
  (* copy: "copies the slice src into the array dst, with the i(th) element of
     src stored at the (di+i)(th) position in the destination array", also
     when src is a slice of dst and they overlap *)
  val () = eqA ("BoolArraySlice.copy/other-array", "ffftf", fn () => let val d = arr "fffff" in AS.copy {src = amid (a6 ()), dst = d, di = 1}; d end)
  val () = eqA ("BoolArraySlice.copy/overlap-right", "ttffftf", fn () => let val a = arr "ttfftff" in AS.copy {src = amid a, dst = a, di = 3}; a end)
  val () = eqA ("BoolArraySlice.copy/overlap-left", "tffttf", fn () => let val a = a6 () in AS.copy {src = amid a, dst = a, di = 1}; a end)
  val () = T.raises ("BoolArraySlice.copy/Subscript-too-long", T.isSubscript, fn () => AS.copy {src = amid (a6 ()), dst = arr "fffff", di = 3})
  val () = T.raises ("BoolArraySlice.copy/Subscript-negative", T.isSubscript, fn () => AS.copy {src = amid (a6 ()), dst = arr "fffff", di = ~1})
  val () = eqA ("BoolArraySlice.copyVec/basic", "fttf", fn () => let val d = arr "ffff" in AS.copyVec {src = VS.slice (vec "ftt", 1, NONE), dst = d, di = 1}; d end)
  val () = T.raises ("BoolArraySlice.copyVec/Subscript-too-long", T.isSubscript,
                     fn () => AS.copyVec {src = VS.full (vec "tt"), dst = arr "fff", di = 2})
  val () = T.raises ("BoolArraySlice.copyVec/Subscript-negative", T.isSubscript,
                     fn () => AS.copyVec {src = VS.full (vec "tt"), dst = arr "fff", di = ~1})
  val () = eqB ("BoolArraySlice.isEmpty/false", false, fn () => AS.isEmpty (amid (a6 ())))
  val () = eqB ("BoolArraySlice.isEmpty/true", true, fn () => AS.isEmpty (AS.slice (a6 (), 3, SOME 0)))
  val () = T.eq (T.option (T.pair (T.bool, T.string))) ("BoolArraySlice.getItem/first", SOME (false, "ft"),
                 fn () => Option.map (fn (b, rest) => (b, showAS rest)) (AS.getItem (amid (a6 ()))))
  val () = eqB ("BoolArraySlice.getItem/empty", true, fn () => not (isSome (AS.getItem (AS.slice (a6 (), 6, NONE)))))
  val () = eqIB ("BoolArraySlice.appi/slice-indices", [(0, false), (1, false), (2, true)], fn () => seenBy AS.appi (fn _ => ()) (amid (a6 ())))
  val () = eqBools ("BoolArraySlice.app/order", [false, false, true], fn () => seenBy AS.app (fn _ => ()) (amid (a6 ())))
  (* (i = 1) <> b over f f t: f t t, in the base t t [f t t] t f *)
  val () = eqA ("BoolArraySlice.modifyi/slice-indices", "ttfttf", fn () => let val a = a6 () in AS.modifyi (fn (i, b) => (i = 1) <> b) (amid a); a end)
  val () = eqA ("BoolArraySlice.modify/not", "ttttff", fn () => let val a = a6 () in AS.modify not (amid a); a end)
  val () = eqI ("BoolArraySlice.foldli/nonassociative", 3, fn () => AS.foldli digitI 0 (amid (a6 ())))
  val () = eqI ("BoolArraySlice.foldri/nonassociative", 12, fn () => AS.foldri digitI 0 (amid (a6 ())))
  val () = eqI ("BoolArraySlice.foldl/nonassociative", 1, fn () => AS.foldl digit 0 (amid (a6 ())))
  val () = eqI ("BoolArraySlice.foldr/nonassociative", 4, fn () => AS.foldr digit 0 (amid (a6 ())))
  val () = eqIBO ("BoolArraySlice.findi/slice-index", SOME (2, true), fn () => AS.findi #2 (amid (a6 ())))
  val () = eqBO ("BoolArraySlice.find/none-in-the-slice", NONE, fn () => AS.find (fn b => b) (AS.slice (a6 (), 2, SOME 2)))
  val () = eqB ("BoolArraySlice.exists/true", true, fn () => AS.exists (fn b => b) (amid (a6 ())))
  val () = eqB ("BoolArraySlice.all/only-the-slice", true, fn () => AS.all not (AS.slice (a6 (), 2, SOME 2)))
  val () = eqOrd ("BoolArraySlice.collate/equal", EQUAL, fn () => AS.collate cmp (amid (a6 ()), AS.full (arr "fft")))
  val () = eqOrd ("BoolArraySlice.collate/greater", GREATER, fn () => AS.collate cmp (AS.slice (a6 (), 0, SOME 2), amid (a6 ())))
  (*>> slices *)

  (*<< array2 *)
  (* ---- BoolArray2: rows and columns are BoolVector.vector values; appi,
     foldi and modifyi pass the coordinates in the base array ---- *)
  structure A2 = BoolArray2
  fun rows a = List.tabulate (A2.nRows a, fn i => text (List.tabulate (A2.nCols a, fn j => A2.sub (a, i, j))))
  val eqR = T.eq (T.list T.string)
  fun eqA2 (label, expected, f) = eqR (label, expected, fn () => rows (f ()))
  fun mk l = A2.fromList (List.map bools l)
  (* t f f t / f t t f / t t f f *)
  fun m34 () = mk ["tfft", "ftff", "ttff"]
  fun region (a, r, c, nr, nc) : A2.region = {base = a, row = r, col = c, nrows = nr, ncols = nc}
  val eqT = T.eq (T.list (T.triple (T.int, T.int, T.bool)))
  val eqP = T.eq (T.list (T.pair (T.int, T.int)))
  val () = eqA2 ("BoolArray2.array/basic", ["ttt", "ttt"], fn () => A2.array (2, 3, true))
  val () = T.eq (T.pair (T.int, T.int)) ("BoolArray2.array/no-rows", (0, 3), fn () => A2.dimensions (A2.array (0, 3, true)))
  val () = T.raises ("BoolArray2.array/Size-negative", T.isSize, fn () => A2.array (2, ~1, true))
  val () = eqA2 ("BoolArray2.fromList/basic", ["tfft", "ftff", "ttff"], fn () => m34 ())
  val () = T.raises ("BoolArray2.fromList/Size-ragged", T.isSize, fn () => mk ["tf", "t"])
  val () = eqA2 ("BoolArray2.tabulate/RowMajor", ["tft", "ftf"], fn () => A2.tabulate A2.RowMajor (2, 3, fn (i, j) => (i + j) mod 2 = 0))
  val () = eqP ("BoolArray2.tabulate/ColMajor-order", [(0, 0), (1, 0), (0, 1), (1, 1)],
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (A2.tabulate A2.ColMajor (2, 2, f)); seen () end)
  val () = T.raises ("BoolArray2.tabulate/Size-negative", T.isSize, fn () => A2.tabulate A2.RowMajor (~1, 2, fn _ => true))
  val () = eqBools ("BoolArray2.sub/each", [true, false, true, false], fn () => List.map (fn (i, j) => A2.sub (m34 (), i, j)) [(0, 0), (0, 1), (2, 1), (2, 3)])
  val () = T.raises ("BoolArray2.sub/Subscript-row", T.isSubscript, fn () => A2.sub (m34 (), 3, 0))
  val () = T.raises ("BoolArray2.sub/Subscript-column", T.isSubscript, fn () => A2.sub (m34 (), 0, 4))
  val () = T.raises ("BoolArray2.sub/Subscript-negative", T.isSubscript, fn () => A2.sub (m34 (), 0, !minusOne))
  val () = eqA2 ("BoolArray2.update/basic", ["tfft", "fttf", "ttff"], fn () => let val a = m34 () in A2.update (a, 1, 2, true); a end)
  val () = T.raises ("BoolArray2.update/Subscript", T.isSubscript, fn () => A2.update (m34 (), 1, 4, true))
  val () = T.eq (T.pair (T.int, T.int)) ("BoolArray2.dimensions/basic", (3, 4), fn () => A2.dimensions (m34 ()))
  val () = eqI ("BoolArray2.nRows/basic", 3, fn () => A2.nRows (m34 ()))
  val () = eqI ("BoolArray2.nCols/basic", 4, fn () => A2.nCols (m34 ()))
  val () = eqV ("BoolArray2.row/basic", "ftff", fn () => A2.row (m34 (), 1))
  val () = T.raises ("BoolArray2.row/Subscript", T.isSubscript, fn () => A2.row (m34 (), 3))
  val () = eqV ("BoolArray2.column/basic", "tff", fn () => A2.column (m34 (), 3))
  val () = T.raises ("BoolArray2.column/Subscript", T.isSubscript, fn () => A2.column (m34 (), !minusOne))
  (* the region of rows 1 and 2 and columns 1 and 2: t f / t f *)
  fun inner a = region (a, 1, 1, SOME 2, SOME 2)
  val () = eqA2 ("BoolArray2.copy/region", ["ffff", "ftff", "ftff"],
                 fn () => let val d = A2.array (3, 4, false) in A2.copy {src = inner (m34 ()), dst = d, dst_row = 1, dst_col = 1}; d end)
  (* rows 0 and 1 moved down one row within the array *)
  val () = eqA2 ("BoolArray2.copy/overlap-down", ["tfft", "tfft", "ftff"],
                 fn () => let val a = m34 () in A2.copy {src = region (a, 0, 0, SOME 2, NONE), dst = a, dst_row = 1, dst_col = 0}; a end)
  val () = T.raises ("BoolArray2.copy/Subscript-dst", T.isSubscript,
                     fn () => A2.copy {src = inner (m34 ()), dst = A2.array (3, 3, false), dst_row = 2, dst_col = 0})
  val () = T.raises ("BoolArray2.copy/Subscript-src", T.isSubscript,
                     fn () => A2.copy {src = region (m34 (), 2, 0, SOME 2, NONE), dst = A2.array (3, 4, false), dst_row = 0, dst_col = 0})
  val () = eqT ("BoolArray2.appi/region-RowMajor", [(1, 1, true), (1, 2, false), (2, 1, true), (2, 2, false)],
                fn () => let val (f, seen) = trace (fn _ => ()) in A2.appi A2.RowMajor f (inner (m34 ())); seen () end)
  val () = eqT ("BoolArray2.appi/region-ColMajor", [(1, 1, true), (2, 1, true), (1, 2, false), (2, 2, false)],
                fn () => let val (f, seen) = trace (fn _ => ()) in A2.appi A2.ColMajor f (inner (m34 ())); seen () end)
  val () = T.raises ("BoolArray2.appi/Subscript", T.isSubscript, fn () => A2.appi A2.RowMajor (fn _ => ()) (region (m34 (), 0, 3, NONE, SOME 2)))
  val () = eqBools ("BoolArray2.app/ColMajor", [true, false, false, true, true, true],
                    fn () => let val (f, seen) = trace (fn _ => ()) in A2.app A2.ColMajor f (mk ["tft", "ftt"]); seen () end)
  (* digit over the region t f / t f: RowMajor 1010 = 10, ColMajor 1100 = 12 *)
  val () = eqI ("BoolArray2.foldi/RowMajor", 10, fn () => A2.foldi A2.RowMajor (fn (_, _, b, n) => digit (b, n)) 0 (inner (m34 ())))
  val () = eqI ("BoolArray2.foldi/ColMajor", 12, fn () => A2.foldi A2.ColMajor (fn (_, _, b, n) => digit (b, n)) 0 (inner (m34 ())))
  (* the sum of i * j over (1, 1), (1, 2), (2, 1), (2, 2) *)
  val () = eqI ("BoolArray2.foldi/coordinates", 9, fn () => A2.foldi A2.RowMajor (fn (i, j, _, n) => n + i * j) 0 (inner (m34 ())))
  val () = T.raises ("BoolArray2.foldi/Subscript", T.isSubscript, fn () => A2.foldi A2.RowMajor (fn (_, _, _, n) => n) 0 (region (m34 (), 4, 0, NONE, NONE)))
  (* t f t / f t t: RowMajor 101011 = 43, ColMajor 100111 = 39 *)
  val () = eqI ("BoolArray2.fold/RowMajor", 43, fn () => A2.fold A2.RowMajor digit 0 (mk ["tft", "ftt"]))
  val () = eqI ("BoolArray2.fold/ColMajor", 39, fn () => A2.fold A2.ColMajor digit 0 (mk ["tft", "ftt"]))
  (* (i + j = 3) <> b over the region t f / t f: t t / f f *)
  val () = eqA2 ("BoolArray2.modifyi/region", ["tfft", "fttf", "tfff"],
                 fn () => let val a = m34 () in A2.modifyi A2.RowMajor (fn (i, j, b) => (i + j = 3) <> b) (inner a); a end)
  val () = T.raises ("BoolArray2.modifyi/Subscript", T.isSubscript, fn () => A2.modifyi A2.RowMajor (fn (_, _, b) => b) (region (m34 (), 1, 1, SOME 3, NONE)))
  val () = eqA2 ("BoolArray2.modify/not", ["ftt", "tff"], fn () => let val a = mk ["tff", "ftt"] in A2.modify A2.ColMajor not a; a end)
  val () = eqBools ("BoolArray2.modify/order-ColMajor", [true, false, false, true],
                    fn () => let val (f, seen) = trace not in A2.modify A2.ColMajor f (mk ["tf", "ft"]); seen () end)
  val () = eqB ("BoolArray2.array/same-elements-not-equal", false, fn () => A2.array (1, 1, true) = A2.array (1, 1, true))
  val () = eqB ("BoolArray2.array/same-array-is-equal", true, fn () => let val a = m34 () in a = a end)
  (*>> array2 *)
end
