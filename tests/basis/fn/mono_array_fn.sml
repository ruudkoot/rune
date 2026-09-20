(* Checks of a structure with signature MONO_ARRAY, for any element type.
   Expected values follow https://smlfamily.github.io/Basis/mono-array.html.

     structure Generic = TestMonoArrayFn (structure A = Word8Array structure V = Word8Vector val name = "Word8Array" val elems = ... val show = ... val same = ...)

   needs spec-sigs/MONO_VECTOR.sml and spec-sigs/MONO_ARRAY.sml. V is the
   matching vector structure ("with the vector types in the two structures
   identified"). The labels are name ^ ".member/case". `elems` holds at least
   8 distinct sample elements, `show` prints one and `same` is the equality of
   elements. An element is written below as its index in `elems`, its code:
   the array [1, 2, 3] is the one of the samples 1, 2 and 3, and arrays are
   compared as the lists of the codes of their elements, read with A.length
   and A.sub. The arrays of a check are made inside its thunk: a check never
   sees the updates of another one.

   TestMonoArraySizeFn has the checks of Size that ask for more than A.maxLen
   elements; an implementation that does not make them may run out of memory,
   so a test applies it in a section of its own. *)
functor TestMonoArrayFn (structure A : SPEC_MONO_ARRAY
                         structure V : SPEC_MONO_VECTOR where type vector = A.vector where type elem = A.elem
                         val name : string
                         val elems : A.elem vector
                         val show : A.elem -> string
                         val same : A.elem * A.elem -> bool) =
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
  val eqLL = T.eq (T.list (T.list showCode))
  val eqO = T.eq (T.option showCode)
  val eqOrd = T.eq T.order
  val eqIL = T.eq (T.list (T.pair (T.int, showCode)))
  val eqIO = T.eq (T.option (T.pair (T.int, showCode)))
  val eqInts = T.eq (T.list T.int)

  fun toList a = List.tabulate (A.length a, fn i => code (A.sub (a, i)))
  fun vectorToList v = List.tabulate (V.length v, fn i => code (V.sub (v, i)))
  fun arr l = A.fromList (List.map e l)
  fun vec l = V.fromList (List.map e l)
  fun eqA (label, expected : int list, f : unit -> A.array) : unit =
    eqL (label, expected, fn () => toList (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end
  fun coded (f, seen) = (f, fn () => List.map code (seen ()))
  fun codedI (f, seen) = (f, fn () => List.map (fn (i, x) => (i, code x)) (seen ()))

  val l5 = [1, 2, 3, 4, 5]
  val l3 = [3, 5, 7]
  val i3 = [(0, 3), (1, 5), (2, 7)]
  fun a5 () = arr l5
  fun a3 () = arr l3
  fun empty () = arr []
  fun zeros n = A.array (n, e 0)
  val minusOne = ref ~1   (* not a constant: see Array.update in array.sml *)
  fun cmp (a, b) = Int.compare (code a, code b)
  fun even x = code x mod 2 = 0

  val () = T.check (lab "elem/eight-distinct-samples",
                    fn () => samples >= 8 andalso List.tabulate (8, fn i => code (e i)) = [0, 1, 2, 3, 4, 5, 6, 7])

  (* ---- array: "creates a new array of length n; each element is initialized
     to the value init. If n < 0 or maxLen < n, then the Size exception is
     raised." ---- *)
  val () = eqA (lab "array/basic", [7, 7, 7], fn () => A.array (3, e 7))
  val () = eqA (lab "array/zero", [], fn () => A.array (0, e 7))
  val () = eqA (lab "array/one", [7], fn () => A.array (1, e 7))
  val () = eqI (lab "array/length", 1000, fn () => A.length (A.array (1000, e 7)))
  val () = T.raises (lab "array/Size-negative", T.isSize, fn () => A.array (!minusOne, e 7))
  val () = eqA (lab "array/elements-are-separate", [7, 6, 7],
                fn () => let val a = A.array (3, e 7) in A.update (a, 1, e 6); a end)

  (* ---- fromList: "whose length is length l and with the i(th) element of l
     used as the i(th) element of the array" ---- *)
  val () = eqA (lab "fromList/basic", [1, 2, 3], fn () => A.fromList [e 1, e 2, e 3])
  val () = eqA (lab "fromList/nil", [], fn () => A.fromList [])
  val () = eqA (lab "fromList/singleton", [7], fn () => A.fromList [e 7])
  val () = eqA (lab "fromList/every-sample", [0, 1, 2, 3, 4, 5, 6, 7], fn () => A.fromList (List.tabulate (8, e)))
  val () = eqI (lab "fromList/length", 5, fn () => A.length (a5 ()))

  (* ---- tabulate: "the elements are defined in order of increasing index by
     applying f to the element's index. This is equivalent to the expression
     fromList (List.tabulate (n, f)). If n < 0 or maxLen < n, then the Size
     exception is raised." ---- *)
  val () = eqA (lab "tabulate/basic", [0, 2, 4, 6], fn () => A.tabulate (4, fn i => e (2 * i)))
  val () = eqA (lab "tabulate/zero", [], fn () => A.tabulate (0, e))
  val () = eqA (lab "tabulate/one", [5], fn () => A.tabulate (1, fn i => e (i + 5)))
  val () = eqInts (lab "tabulate/order", [0, 1, 2, 3],
                   fn () => let val (f, seen) = trace e in ignore (A.tabulate (4, f)); seen () end)
  val () = T.raises (lab "tabulate/Size-negative", T.isSize, fn () => A.tabulate (!minusOne, e))
  val () = eqInts (lab "tabulate/Size-before-f", [],
                   fn () => let val (f, seen) = trace (fn _ => e 0)
                            in ignore (A.tabulate (~3, f)) handle Size => (); seen () end)

  (* ---- length ---- *)
  val () = eqI (lab "length/empty", 0, fn () => A.length (empty ()))
  val () = eqI (lab "length/five", 5, fn () => A.length (a5 ()))
  val () = eqI (lab "length/tabulate", 1000, fn () => A.length (A.tabulate (1000, fn i => e (i mod 8))))

  (* ---- sub: "If i < 0 or |arr| <= i, then the Subscript exception is
     raised." ---- *)
  val () = eqI (lab "sub/first", 1, fn () => code (A.sub (a5 (), 0)))
  val () = eqI (lab "sub/middle", 3, fn () => code (A.sub (a5 (), 2)))
  val () = eqI (lab "sub/last", 5, fn () => code (A.sub (a5 (), 4)))
  val () = T.raises (lab "sub/Subscript-length", T.isSubscript, fn () => A.sub (a5 (), 5))
  val () = T.raises (lab "sub/Subscript-beyond", T.isSubscript, fn () => A.sub (a5 (), 1000))
  val () = T.raises (lab "sub/Subscript-negative", T.isSubscript, fn () => A.sub (a5 (), !minusOne))
  val () = T.raises (lab "sub/Subscript-empty", T.isSubscript, fn () => A.sub (empty (), 0))

  (* ---- update: "sets the i(th) element of the array arr to x. If i < 0 or
     |arr| <= i, then the Subscript exception is raised." ---- *)
  val () = eqA (lab "update/first", [7, 2, 3, 4, 5], fn () => let val a = a5 () in A.update (a, 0, e 7); a end)
  val () = eqA (lab "update/middle", [1, 2, 7, 4, 5], fn () => let val a = a5 () in A.update (a, 2, e 7); a end)
  val () = eqA (lab "update/last", [1, 2, 3, 4, 7], fn () => let val a = a5 () in A.update (a, 4, e 7); a end)
  val () = eqA (lab "update/twice-same-index", [1, 6, 3, 4, 5],
                fn () => let val a = a5 () in A.update (a, 1, e 7); A.update (a, 1, e 6); a end)
  val () = eqI (lab "update/seen-through-alias", 7,
                fn () => let val a = a5 () val b = a in A.update (b, 3, e 7); code (A.sub (a, 3)) end)
  val () = T.raises (lab "update/Subscript-length", T.isSubscript, fn () => A.update (a5 (), 5, e 7))
  val () = T.raises (lab "update/Subscript-beyond", T.isSubscript, fn () => A.update (a5 (), 1000, e 7))
  val () = T.raises (lab "update/Subscript-negative", T.isSubscript, fn () => A.update (a5 (), !minusOne, e 7))
  val () = T.raises (lab "update/Subscript-empty", T.isSubscript, fn () => A.update (empty (), 0, e 7))
  val () = eqA (lab "update/Subscript-changes-nothing", l5,
                fn () => let val a = a5 () in A.update (a, 5, e 7) handle Subscript => (); a end)

  (* ---- vector: "if vec is the resulting vector, we have |vec| = |arr| and,
     for 0 <= i < |arr|, element i of vec is sub (arr, i)" ---- *)
  val () = eqL (lab "vector/basic", l5, fn () => vectorToList (A.vector (a5 ())))
  val () = eqL (lab "vector/empty", [], fn () => vectorToList (A.vector (empty ())))
  val () = eqL (lab "vector/after-update", [1, 2, 7, 4, 5],
                fn () => let val a = a5 () in A.update (a, 2, e 7); vectorToList (A.vector a) end)
  val () = eqL (lab "vector/is-a-snapshot", l5,
                fn () => let val a = a5 () val v = A.vector a in A.update (a, 2, e 7); vectorToList v end)

  (* ---- copy, copyVec: "copy the entire array or vector src into the array
     dst, with the i(th) element in src, for 0 <= i < |src|, being copied to
     position di + i in the destination array. If di < 0 or if
     |dst| < di+|src|, then the Subscript exception is raised." The page does
     not say what is left in dst when Subscript is raised; the checks take it
     that nothing is copied, as the condition is on the arguments alone. ---- *)
  val () = eqA (lab "copy/start", [3, 5, 7, 0, 0],
                fn () => let val d = zeros 5 in A.copy {src = a3 (), dst = d, di = 0}; d end)
  val () = eqA (lab "copy/middle", [0, 3, 5, 7, 0],
                fn () => let val d = zeros 5 in A.copy {src = a3 (), dst = d, di = 1}; d end)
  val () = eqA (lab "copy/end", [0, 0, 3, 5, 7],
                fn () => let val d = zeros 5 in A.copy {src = a3 (), dst = d, di = 2}; d end)
  val () = eqA (lab "copy/whole", l3, fn () => let val d = zeros 3 in A.copy {src = a3 (), dst = d, di = 0}; d end)
  val () = eqA (lab "copy/src-unchanged", l3, fn () => let val s = a3 () in A.copy {src = s, dst = zeros 5, di = 1}; s end)
  val () = eqA (lab "copy/empty-src", l5, fn () => let val d = a5 () in A.copy {src = empty (), dst = d, di = 2}; d end)
  val () = eqA (lab "copy/empty-src-at-length", l5,
                fn () => let val d = a5 () in A.copy {src = empty (), dst = d, di = 5}; d end)
  val () = eqA (lab "copy/empty-to-empty", [], fn () => let val d = empty () in A.copy {src = empty (), dst = d, di = 0}; d end)
  val () = eqA (lab "copy/copies-elements-not-the-array", [0, 3, 5, 7, 0],
                fn () => let val s = a3 () val d = zeros 5 in A.copy {src = s, dst = d, di = 1}; A.update (s, 0, e 6); d end)
  val () = T.raises (lab "copy/Subscript-too-far", T.isSubscript, fn () => A.copy {src = a3 (), dst = zeros 5, di = 3})
  val () = T.raises (lab "copy/Subscript-negative", T.isSubscript,
                     fn () => A.copy {src = a3 (), dst = zeros 5, di = !minusOne})
  val () = T.raises (lab "copy/Subscript-src-longer", T.isSubscript, fn () => A.copy {src = a5 (), dst = zeros 3, di = 0})
  val () = T.raises (lab "copy/Subscript-to-empty", T.isSubscript, fn () => A.copy {src = a3 (), dst = empty (), di = 0})
  val () = T.raises (lab "copy/Subscript-empty-src-beyond", T.isSubscript,
                     fn () => A.copy {src = empty (), dst = a5 (), di = 6})
  val () = T.raises (lab "copy/Subscript-empty-src-negative", T.isSubscript,
                     fn () => A.copy {src = empty (), dst = a5 (), di = !minusOne})
  val () = eqA (lab "copy/Subscript-changes-nothing", [0, 0, 0, 0, 0],
                fn () => let val d = zeros 5 in A.copy {src = a3 (), dst = d, di = 3} handle Subscript => (); d end)
  (* "In copy, if dst and src are equal, we must have di = 0 to avoid an
     exception, and copy is then the identity." *)
  val () = eqA (lab "copy/onto-itself", l5, fn () => let val a = a5 () in A.copy {src = a, dst = a, di = 0}; a end)
  val () = T.raises (lab "copy/Subscript-onto-itself-shifted", T.isSubscript,
                     fn () => let val a = a5 () in A.copy {src = a, dst = a, di = 1} end)

  val () = eqA (lab "copyVec/start", [3, 5, 7, 0, 0],
                fn () => let val d = zeros 5 in A.copyVec {src = vec l3, dst = d, di = 0}; d end)
  val () = eqA (lab "copyVec/middle", [0, 3, 5, 7, 0],
                fn () => let val d = zeros 5 in A.copyVec {src = vec l3, dst = d, di = 1}; d end)
  val () = eqA (lab "copyVec/end", [0, 0, 3, 5, 7],
                fn () => let val d = zeros 5 in A.copyVec {src = vec l3, dst = d, di = 2}; d end)
  val () = eqA (lab "copyVec/whole", l3, fn () => let val d = zeros 3 in A.copyVec {src = vec l3, dst = d, di = 0}; d end)
  val () = eqL (lab "copyVec/src-unchanged", l3,
                fn () => let val v = vec l3 in A.copyVec {src = v, dst = zeros 5, di = 1}; vectorToList v end)
  val () = eqA (lab "copyVec/empty-src", l5, fn () => let val d = a5 () in A.copyVec {src = vec [], dst = d, di = 2}; d end)
  val () = eqA (lab "copyVec/empty-src-at-length", l5,
                fn () => let val d = a5 () in A.copyVec {src = vec [], dst = d, di = 5}; d end)
  val () = eqA (lab "copyVec/empty-to-empty", [], fn () => let val d = empty () in A.copyVec {src = vec [], dst = d, di = 0}; d end)
  val () = eqA (lab "copyVec/from-vector-of-array", [1, 1, 2, 3, 4],
                fn () => let val a = a5 () in A.copyVec {src = A.vector (arr [1, 2, 3, 4]), dst = a, di = 1}; a end)
  val () = T.raises (lab "copyVec/Subscript-too-far", T.isSubscript, fn () => A.copyVec {src = vec l3, dst = zeros 5, di = 3})
  val () = T.raises (lab "copyVec/Subscript-negative", T.isSubscript,
                     fn () => A.copyVec {src = vec l3, dst = zeros 5, di = !minusOne})
  val () = T.raises (lab "copyVec/Subscript-src-longer", T.isSubscript, fn () => A.copyVec {src = vec l5, dst = zeros 3, di = 0})
  val () = T.raises (lab "copyVec/Subscript-to-empty", T.isSubscript, fn () => A.copyVec {src = vec l3, dst = empty (), di = 0})
  val () = T.raises (lab "copyVec/Subscript-empty-src-beyond", T.isSubscript,
                     fn () => A.copyVec {src = vec [], dst = a5 (), di = 6})
  val () = T.raises (lab "copyVec/Subscript-empty-src-negative", T.isSubscript,
                     fn () => A.copyVec {src = vec [], dst = a5 (), di = !minusOne})
  val () = eqA (lab "copyVec/Subscript-changes-nothing", [0, 0, 0, 0, 0],
                fn () => let val d = zeros 5 in A.copyVec {src = vec l3, dst = d, di = 3} handle Subscript => (); d end)

  (* ---- appi, app: "in left to right order (i.e., increasing indices)" ---- *)
  val () = eqIL (lab "appi/order", i3,
                 fn () => let val (f, seen) = codedI (trace (fn _ => ())) in A.appi f (a3 ()); seen () end)
  val () = eqIL (lab "appi/empty", [],
                 fn () => let val (f, seen) = codedI (trace (fn _ => ())) in A.appi f (empty ()); seen () end)
  val () = eqL (lab "app/order", l5,
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in A.app f (a5 ()); seen () end)
  val () = eqL (lab "app/empty", [],
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in A.app f (empty ()); seen () end)
  val () = eqA (lab "app/array-unchanged", l5, fn () => let val a = a5 () in A.app (fn _ => ()) a; a end)

  (* ---- modifyi, modify: "apply the function f to the elements of an array in
     left to right order (i.e., increasing indices), and replace each element
     with the result of applying f". With f (i, x) = the sample
     (i + code x) mod 8 over [3, 5, 7]: 0+3, 1+5, (2+7) mod 8 = 1. ---- *)
  val () = eqA (lab "modifyi/basic", [3, 6, 1],
                fn () => let val a = a3 () in A.modifyi (fn (i, x) => e ((i + code x) mod 8)) a; a end)
  val () = eqA (lab "modifyi/index-only", [0, 1, 2], fn () => let val a = a3 () in A.modifyi (fn (i, _) => e i) a; a end)
  val () = eqA (lab "modifyi/empty", [], fn () => let val a = empty () in A.modifyi (fn (_, x) => x) a; a end)
  val () = eqIL (lab "modifyi/order", i3,
                 fn () => let val (f, seen) = codedI (trace (fn (_, x) => next x)) in A.modifyi f (a3 ()); seen () end)
  val () = eqA (lab "modify/basic", [2, 3, 4, 5, 6], fn () => let val a = a5 () in A.modify next a; a end)
  val () = eqA (lab "modify/wraps", [0], fn () => let val a = arr [7] in A.modify next a; a end)
  val () = eqA (lab "modify/empty", [], fn () => let val a = empty () in A.modify next a; a end)
  val () = eqL (lab "modify/order", l5,
                fn () => let val (f, seen) = coded (trace next) in A.modify f (a5 ()); seen () end)
  val () = eqA (lab "modify/twice", [3, 4, 5, 6, 7], fn () => let val a = a5 () in A.modify next a; A.modify next a; a end)
  val () = eqLL (lab "modify/is-modifyi-of-second", [[2, 3, 4, 5, 6], [2, 3, 4, 5, 6]],
                 fn () => let val a = a5 () val b = a5 () in A.modify next a; A.modifyi (next o #2) b; [toList a, toList b] end)

  (* ---- foldli, foldri, foldl, foldr: "foldli and foldl apply the function f
     from left to right (increasing indices), while the functions foldri and
     foldr work from right to left (decreasing indices)".
     With f (i, a, x) = i * code a - 2 * x over [3, 5, 7]:
       foldli: 0*3-0 = 0, 1*5-0 = 5, 2*7-10 = 4;
       foldri: 2*7-0 = 14, 1*5-28 = ~23, 0*3+46 = 46.
     With f (a, x) = code a - 2 * x over [1, 2, 3]:
       foldl: 1-0 = 1, 2-2 = 0, 3-0 = 3;  foldr: 3-0 = 3, 2-6 = ~4, 1+8 = 9. ---- *)
  fun gi (i, a, x) = i * code a - 2 * x
  fun g (a, x) = code a - 2 * x
  val () = eqIL (lab "foldli/conses-reversed", [(2, 7), (1, 5), (0, 3)],
                 fn () => A.foldli (fn (i, a, l) => (i, code a) :: l) [] (a3 ()))
  val () = eqI (lab "foldli/nonassociative", 4, fn () => A.foldli gi 0 (a3 ()))
  val () = eqI (lab "foldli/empty", 42, fn () => A.foldli gi 42 (empty ()))
  val () = eqIL (lab "foldri/conses-in-order", i3, fn () => A.foldri (fn (i, a, l) => (i, code a) :: l) [] (a3 ()))
  val () = eqI (lab "foldri/nonassociative", 46, fn () => A.foldri gi 0 (a3 ()))
  val () = eqI (lab "foldri/empty", 42, fn () => A.foldri gi 42 (empty ()))
  val () = eqL (lab "foldl/conses-reversed", [5, 4, 3, 2, 1], fn () => A.foldl (fn (a, l) => code a :: l) [] (a5 ()))
  val () = eqI (lab "foldl/nonassociative", 3, fn () => A.foldl g 0 (arr [1, 2, 3]))
  val () = eqI (lab "foldl/empty", 42, fn () => A.foldl g 42 (empty ()))
  val () = eqL (lab "foldr/conses-in-order", l5, fn () => A.foldr (fn (a, l) => code a :: l) [] (a5 ()))
  val () = eqI (lab "foldr/nonassociative", 9, fn () => A.foldr g 0 (arr [1, 2, 3]))
  val () = eqI (lab "foldr/empty", 42, fn () => A.foldr g 42 (empty ()))

  (* ---- findi, find: "from left to right (i.e., increasing indices), until a
     true value is returned"; findi "returns that index with the element" ---- *)
  fun found r = Option.map (fn (i, x) => (i, code x)) r
  val () = eqIO (lab "findi/first-match", SOME (1, 5), fn () => found (A.findi (fn (_, a) => code a > 3) (a3 ())))
  val () = eqIO (lab "findi/by-index", SOME (2, 7), fn () => found (A.findi (fn (i, _) => i = 2) (a3 ())))
  val () = eqIO (lab "findi/index-zero", SOME (0, 3), fn () => found (A.findi (fn _ => true) (a3 ())))
  val () = eqIO (lab "findi/none", NONE, fn () => found (A.findi (fn (_, a) => code a > 7) (a3 ())))
  val () = eqIO (lab "findi/empty", NONE, fn () => found (A.findi (fn _ => true) (empty ())))
  val () = eqIL (lab "findi/stops", [(0, 3), (1, 5)],
                 fn () => let val (f, seen) = codedI (trace (fn (_, a) => code a = 5)) in ignore (A.findi f (a3 ())); seen () end)
  val () = eqIL (lab "findi/order", i3,
                 fn () => let val (f, seen) = codedI (trace (fn _ => false)) in ignore (A.findi f (a3 ())); seen () end)
  val () = eqO (lab "find/first-match", SOME 2, fn () => Option.map code (A.find even (a5 ())))
  val () = eqO (lab "find/last-element", SOME 5, fn () => Option.map code (A.find (fn x => code x > 4) (a5 ())))
  val () = eqO (lab "find/none", NONE, fn () => Option.map code (A.find (fn x => code x > 5) (a5 ())))
  val () = eqO (lab "find/empty", NONE, fn () => Option.map code (A.find (fn _ => true) (empty ())))
  val () = eqL (lab "find/stops", [1, 2],
                fn () => let val (f, seen) = coded (trace even) in ignore (A.find f (a5 ())); seen () end)

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB (lab "exists/true", true, fn () => A.exists (fn x => code x = 3) (a5 ()))
  val () = eqB (lab "exists/false", false, fn () => A.exists (fn x => code x = 7) (a5 ()))
  val () = eqB (lab "exists/empty", false, fn () => A.exists (fn _ => true) (empty ()))
  val () = eqL (lab "exists/stops", [1, 2, 3],
                fn () => let val (f, seen) = coded (trace (fn x => code x = 3)) in ignore (A.exists f (a5 ())); seen () end)
  val () = eqL (lab "exists/order", l5,
                fn () => let val (f, seen) = coded (trace (fn _ => false)) in ignore (A.exists f (a5 ())); seen () end)
  val () = eqB (lab "all/true", true, fn () => A.all (fn x => code x > 0) (a5 ()))
  val () = eqB (lab "all/false", false, fn () => A.all (fn x => code x < 3) (a5 ()))
  val () = eqB (lab "all/empty", true, fn () => A.all (fn _ => false) (empty ()))
  val () = eqL (lab "all/stops", [1, 2, 3],
                fn () => let val (f, seen) = coded (trace (fn x => code x < 3)) in ignore (A.all f (a5 ())); seen () end)
  val () = eqL (lab "all/order", l5,
                fn () => let val (f, seen) = coded (trace (fn _ => true)) in ignore (A.all f (a5 ())); seen () end)

  (* ---- collate: "lexicographic comparison of the two arrays using the given
     ordering f on elements" ---- *)
  fun collate c (l, m) = A.collate c (arr l, arr m)
  val () = eqOrd (lab "collate/equal", EQUAL, fn () => collate cmp ([1, 2], [1, 2]))
  val () = eqOrd (lab "collate/same-array", EQUAL, fn () => let val a = a5 () in A.collate cmp (a, a) end)
  val () = eqOrd (lab "collate/empty-empty", EQUAL, fn () => collate cmp ([], []))
  val () = eqOrd (lab "collate/empty-less", LESS, fn () => collate cmp ([], [1]))
  val () = eqOrd (lab "collate/empty-greater", GREATER, fn () => collate cmp ([1], []))
  val () = eqOrd (lab "collate/prefix-less", LESS, fn () => collate cmp ([1], [1, 2]))
  val () = eqOrd (lab "collate/prefix-greater", GREATER, fn () => collate cmp ([1, 2], [1]))
  val () = eqOrd (lab "collate/first-difference", GREATER, fn () => collate cmp ([1, 3], [1, 2, 7]))
  val () = eqOrd (lab "collate/not-by-length", LESS, fn () => collate cmp ([0, 7, 7], [1]))
  val () = eqOrd (lab "collate/given-ordering", GREATER, fn () => collate (fn (a, b) => cmp (b, a)) ([0, 7, 7], [1]))
  val () = eqOrd (lab "collate/argument-order", LESS,
                  fn () => collate (fn (a, b) => if code a = 1 andalso code b = 2 then LESS else GREATER) ([1], [2]))

  (* ---- array: "eqtype array". The page of MONO_ARRAY says no more; its
     arrays are "mutable sequences", and the page of Array gives the equality
     of those: "two arrays are equal if they are the same array, i.e., created
     by the same call to a primitive array constructor such as array,
     fromList, etc.; otherwise they are not equal. This also holds for arrays
     of zero length." ---- *)
  val () = eqB (lab "array/same-array-is-equal", true, fn () => let val a = a5 () in a = a end)
  val () = eqB (lab "array/alias-is-equal", true, fn () => let val a = a5 () val b = a in a = b end)
  val () = eqB (lab "array/equal-after-update", true,
                fn () => let val a = a5 () val b = a in A.update (a, 0, e 7); a = b end)
  val () = eqB (lab "array/same-elements-not-equal", false, fn () => A.array (3, e 7) = A.array (3, e 7))
  val () = eqB (lab "fromList/same-elements-not-equal", false, fn () => a5 () = a5 ())
  val () = eqB (lab "tabulate/same-elements-not-equal", false, fn () => A.tabulate (3, e) = A.tabulate (3, e))
  val () = eqB (lab "array/unequal", true, fn () => a5 () <> a5 ())
  val () = eqB (lab "array/zero-length-same", true, fn () => let val a = empty () in a = a end)
  val () = eqB (lab "array/zero-length-not-equal", false, fn () => A.array (0, e 7) = A.array (0, e 7))
  val () = eqB (lab "fromList/zero-length-not-equal", false, fn () => empty () = empty ())
  val () = eqB (lab "tabulate/zero-length-not-equal", false, fn () => A.tabulate (0, e) = A.tabulate (0, e))

  (* ---- maxLen: "If n < 0 or maxLen < n, then the Size exception is raised",
     so a length that array accepts is at most maxLen ---- *)
  val () = eqB (lab "maxLen/covers-created-arrays", true, fn () => A.length (A.array (1000, e 0)) <= A.maxLen)

  (* ---- laws, on pseudo-random arrays, against lists of codes ---- *)
  fun randomList n = List.tabulate (n, fn _ => T.range (0, 7))
  fun indexed l = List.tabulate (List.length l, fn j => (j, List.nth (l, j)))
  val () = T.seed 33
  val () = T.repeat (25, fn i =>
    let
      val n = "-" ^ Int.toString i
      val l = randomList (T.range (0, 12))
      val m = randomList (T.range (0, 12))
      val len = List.length l
      val k = T.range (0, len)            (* 0 <= k <= len *)
      val x = T.range (0, 7)
      fun a () = arr l
      val fi = fn (j, c) => (3 * j + c) mod 8
      val hi = fn (j, c, b) => j * c - 2 * b
      val h = fn (c, b) => c - 2 * b
      val pi = fn (j, c) => (j + c) mod 3 = 0
      val p = fn c => c mod 3 = 0
      (* a destination of 0..6 more elements than l, and an offset into it
         that is valid, or one too large *)
      val d = randomList (len + T.range (0, 6))
      val di = T.range (0, List.length d - len + 1)
      val copied = List.take (d, Int.min (di, List.length d)) @ l @ List.drop (d, Int.min (di + len, List.length d))
    in
      eqA (lab "fromList/round-trip" ^ n, l, a);
      eqI (lab "length/model" ^ n, len, fn () => A.length (a ()));
      eqA (lab "tabulate/model" ^ n, l, fn () => A.tabulate (len, fn j => e (List.nth (l, j))));
      eqA (lab "array/model" ^ n, List.tabulate (len, fn _ => x), fn () => A.array (len, e x));
      (if k < len
       then (eqI (lab "sub/model" ^ n, List.nth (l, k), fn () => code (A.sub (a (), k)));
             eqA (lab "update/model" ^ n, List.take (l, k) @ [x] @ List.drop (l, k + 1),
                  fn () => let val b = a () in A.update (b, k, e x); b end))
       else (T.raises (lab "sub/model" ^ n, T.isSubscript, fn () => A.sub (a (), k));
             T.raises (lab "update/model" ^ n, T.isSubscript, fn () => A.update (a (), k, e x))));
      eqL (lab "vector/model" ^ n, l, fn () => vectorToList (A.vector (a ())));
      (if di + len <= List.length d
       then (eqA (lab "copy/model" ^ n, copied, fn () => let val b = arr d in A.copy {src = a (), dst = b, di = di}; b end);
             eqA (lab "copyVec/model" ^ n, copied, fn () => let val b = arr d in A.copyVec {src = vec l, dst = b, di = di}; b end))
       else (T.raises (lab "copy/model" ^ n, T.isSubscript, fn () => A.copy {src = a (), dst = arr d, di = di});
             T.raises (lab "copyVec/model" ^ n, T.isSubscript, fn () => A.copyVec {src = vec l, dst = arr d, di = di})));
      eqIL (lab "appi/model" ^ n, indexed l,
            fn () => let val (f, seen) = codedI (trace (fn _ => ())) in A.appi f (a ()); seen () end);
      eqL (lab "app/model" ^ n, l,
           fn () => let val (f, seen) = coded (trace (fn _ => ())) in A.app f (a ()); seen () end);
      eqA (lab "modifyi/model" ^ n, List.map fi (indexed l),
           fn () => let val b = a () in A.modifyi (fn (j, c) => e (fi (j, code c))) b; b end);
      eqA (lab "modify/model" ^ n, List.map (fn c => (c + 1) mod 8) l, fn () => let val b = a () in A.modify next b; b end);
      eqI (lab "foldli/model" ^ n, List.foldl (fn ((j, c), b) => hi (j, c, b)) 1 (indexed l),
           fn () => A.foldli (fn (j, c, b) => hi (j, code c, b)) 1 (a ()));
      eqI (lab "foldri/model" ^ n, List.foldr (fn ((j, c), b) => hi (j, c, b)) 1 (indexed l),
           fn () => A.foldri (fn (j, c, b) => hi (j, code c, b)) 1 (a ()));
      eqI (lab "foldl/model" ^ n, List.foldl h 1 l, fn () => A.foldl (fn (c, b) => h (code c, b)) 1 (a ()));
      eqI (lab "foldr/model" ^ n, List.foldr h 1 l, fn () => A.foldr (fn (c, b) => h (code c, b)) 1 (a ()));
      eqIO (lab "findi/model" ^ n, List.find pi (indexed l), fn () => found (A.findi (fn (j, c) => pi (j, code c)) (a ())));
      eqO (lab "find/model" ^ n, List.find p l, fn () => Option.map code (A.find (p o code) (a ())));
      eqB (lab "exists/model" ^ n, List.exists p l, fn () => A.exists (p o code) (a ()));
      eqB (lab "all/model" ^ n, List.all (not o p) l, fn () => A.all (not o p o code) (a ()));
      eqB (lab "all/de-morgan" ^ n, true,
           fn () => let val b = a () in A.all (p o code) b = not (A.exists (not o p o code) b) end);
      eqOrd (lab "collate/model" ^ n, List.collate Int.compare (l, m), fn () => A.collate cmp (a (), arr m));
      eqOrd (lab "collate/reflexive" ^ n, EQUAL, fn () => A.collate cmp (a (), a ()));
      eqB (lab "array/identity" ^ n, true, fn () => let val b = a () in b = b andalso b <> a () end)
    end)

  (* ---- long arrays: no stack or quadratic trouble ---- *)
  fun big () = A.tabulate (100000, fn i => e (i mod 8))
  val () = eqI (lab "length/long", 100000, fn () => A.length (big ()))
  val () = eqI (lab "array/long", 100000, fn () => A.length (A.array (100000, e 0)))
  val () = eqI (lab "sub/long", 7, fn () => code (A.sub (big (), 99999)))
  val () = eqI (lab "fromList/long", 100000, fn () => A.length (A.fromList (List.tabulate (100000, fn i => e (i mod 8)))))
  val () = eqI (lab "modify/long", 0, fn () => let val a = big () in A.modify next a; code (A.sub (a, 99999)) end)
  val () = eqI (lab "modifyi/long", 3, fn () => let val a = big () in A.modifyi (fn (i, _) => e (i mod 4)) a; code (A.sub (a, 99999)) end)
  val () = eqI (lab "foldl/long", 12500, fn () => A.foldl (fn (c, k) => if code c = 7 then k + 1 else k) 0 (big ()))
  val () = eqI (lab "foldr/long", 100000, fn () => List.length (A.foldr (op ::) [] (big ())))
  val () = eqB (lab "all/long", true, fn () => A.all (fn c => code c >= 0) (big ()))
  val () = eqI (lab "vector/long", 100000, fn () => V.length (A.vector (big ())))
  val () = eqI (lab "copy/long", 7,
                fn () => let val d = A.array (100001, e 0) in A.copy {src = big (), dst = d, di = 1}; code (A.sub (d, 100000)) end)
  val () = eqI (lab "copyVec/long", 7,
                fn () => let val d = A.array (100001, e 0)
                         in A.copyVec {src = A.vector (big ()), dst = d, di = 1}; code (A.sub (d, 100000)) end)
  val () = eqOrd (lab "collate/long", EQUAL, fn () => A.collate cmp (big (), big ()))
end

(* "The maximum length of arrays supported by this implementation. Attempts to
   create larger arrays will result in the Size exception being raised."
   maxLen + 1 exists unless maxLen is Int.maxInt. The function that is
   tabulated gives up after 1000 applications, so that an implementation that
   applies it before it looks at the length fails the check instead of running
   out of memory. (fromList would take a list of maxLen + 1 elements, which is
   too much everywhere.) *)
functor TestMonoArraySizeFn (structure A : SPEC_MONO_ARRAY
                             val name : string
                             val elem : A.elem) =
struct
  fun lab s = name ^ "." ^ s

  val aboveMaxLen : int option =
    case Int.maxInt of
      NONE => SOME (A.maxLen + 1)
    | SOME most => if A.maxLen < most then SOME (A.maxLen + 1) else NONE
  val () =
    case aboveMaxLen of
      NONE => ()
    | SOME n =>
        (T.raises (lab "tabulate/Size-above-maxLen", T.isSize,
                   fn () => A.tabulate (n, fn i => if i < 1000 then elem else raise Fail "f applied before Size"));
         T.raises (lab "array/Size-above-maxLen", T.isSize, fn () => A.array (n, elem)))
end
