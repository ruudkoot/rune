(* requires: Array Vector List *)
(* The Array structure (signature ARRAY). Expected values follow the text of
   https://smlfamily.github.io/Basis/array.html.

   Arrays are read back as lists with Array.length and Array.sub. The checks
   of Size that need a length above Array.maxLen come last: an implementation
   that does not make them may run out of memory. *)
structure TestArray =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val eqLL = T.eq (T.list (T.list T.int))
  val eqO = T.eq (T.option T.int)
  val eqOrd = T.eq T.order
  val eqIL = T.eq (T.list (T.pair (T.int, T.int)))
  val eqIO = T.eq (T.option (T.pair (T.int, T.int)))

  fun toList (a : 'a array) : 'a list = List.tabulate (Array.length a, fn i => Array.sub (a, i))
  fun vectorToList (v : 'a vector) : 'a list = List.tabulate (Vector.length v, fn i => Vector.sub (v, i))

  (* eqA (label, expected, f): the elements of the array f () are expected. *)
  fun eqA (label, expected : int list, f : unit -> int array) : unit =
    eqL (label, expected, fn () => toList (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end

  (* The arrays of a check are made inside its thunk: a check never sees the
     updates of another one. *)
  val l5 = [1, 2, 3, 4, 5]
  val l3 = [10, 20, 30]
  val i3 = [(0, 10), (1, 20), (2, 30)]
  fun a5 () = Array.fromList l5
  fun a3 () = Array.fromList l3
  fun empty () : int array = Array.fromList []
  fun zeros n = Array.array (n, 0)
  val even = fn x => x mod 2 = 0

  (* ---- array: "creates a new array of length n; each element is initialized
     to the value init. If n < 0 or maxLen < n, then the Size exception is
     raised." ---- *)
  val () = eqA ("Array.array/basic", [7, 7, 7], fn () => Array.array (3, 7))
  val () = eqA ("Array.array/zero", [], fn () => Array.array (0, 7))
  val () = eqA ("Array.array/one", [7], fn () => Array.array (1, 7))
  val () = eqI ("Array.array/length", 1000, fn () => Array.length (Array.array (1000, 7)))
  val () = T.raises ("Array.array/Size-negative", T.isSize, fn () => Array.array (~1, 7))
  val () = eqA ("Array.array/elements-are-separate", [7, 8, 7],
                fn () => let val a = Array.array (3, 7) in Array.update (a, 1, 8); a end)
  val () = eqI ("Array.array/every-element-is-init", 5,
                fn () => let val a = Array.array (2, ref 0) in Array.sub (a, 0) := 5; !(Array.sub (a, 1)) end)

  (* ---- fromList: "the i(th) element of the array is the i(th) element of the
     the list" ---- *)
  val () = eqA ("Array.fromList/basic", [1, 2, 3], fn () => Array.fromList [1, 2, 3])
  val () = eqA ("Array.fromList/nil", [], fn () => Array.fromList [])
  val () = eqA ("Array.fromList/singleton", [7], fn () => Array.fromList [7])
  val () = eqI ("Array.fromList/length", 5, fn () => Array.length (Array.fromList l5))
  val () = T.eq (T.list T.string)
             ("Array.fromList/strings", ["a", "", "bc"], fn () => toList (Array.fromList ["a", "", "bc"]))

  (* ---- tabulate: "the elements are defined in order of increasing index by
     applying f to the element's index" ---- *)
  val () = eqA ("Array.tabulate/basic", [0, 1, 4, 9], fn () => Array.tabulate (4, fn i => i * i))
  val () = eqA ("Array.tabulate/zero", [], fn () => Array.tabulate (0, fn i => i))
  val () = eqA ("Array.tabulate/one", [5], fn () => Array.tabulate (1, fn i => i + 5))
  val () = eqL ("Array.tabulate/order", [0, 1, 2, 3],
                fn () => let val (f, seen) = trace (fn i => i) in ignore (Array.tabulate (4, f)); seen () end)
  val () = T.raises ("Array.tabulate/Size-negative", T.isSize, fn () => Array.tabulate (~1, fn i => i))
  val () = eqL ("Array.tabulate/Size-before-f", [],
                fn () => let val (f, seen) = trace (fn i => i)
                         in ignore (Array.tabulate (~3, f)) handle Size => (); seen () end)

  (* ---- length ---- *)
  val () = eqI ("Array.length/empty", 0, fn () => Array.length (empty ()))
  val () = eqI ("Array.length/five", 5, fn () => Array.length (a5 ()))
  val () = eqI ("Array.length/tabulate", 1000, fn () => Array.length (Array.tabulate (1000, fn i => i)))

  (* ---- sub: "If i < 0 or |arr| <= i, then the Subscript exception is
     raised." ---- *)
  val () = eqI ("Array.sub/first", 1, fn () => Array.sub (a5 (), 0))
  val () = eqI ("Array.sub/middle", 3, fn () => Array.sub (a5 (), 2))
  val () = eqI ("Array.sub/last", 5, fn () => Array.sub (a5 (), 4))
  val () = T.raises ("Array.sub/Subscript-length", T.isSubscript, fn () => Array.sub (a5 (), 5))
  val () = T.raises ("Array.sub/Subscript-beyond", T.isSubscript, fn () => Array.sub (a5 (), 1000))
  val () = T.raises ("Array.sub/Subscript-negative", T.isSubscript, fn () => Array.sub (a5 (), ~1))
  val () = T.raises ("Array.sub/Subscript-empty", T.isSubscript, fn () => Array.sub (empty (), 0))

  (* ---- update: "sets the i(th) element of the array arr to x" ---- *)
  val () = eqA ("Array.update/first", [9, 2, 3, 4, 5], fn () => let val a = a5 () in Array.update (a, 0, 9); a end)
  val () = eqA ("Array.update/middle", [1, 2, 9, 4, 5], fn () => let val a = a5 () in Array.update (a, 2, 9); a end)
  val () = eqA ("Array.update/last", [1, 2, 3, 4, 9], fn () => let val a = a5 () in Array.update (a, 4, 9); a end)
  val () = eqA ("Array.update/twice-same-index", [1, 7, 3, 4, 5],
                fn () => let val a = a5 () in Array.update (a, 1, 9); Array.update (a, 1, 7); a end)
  val () = eqI ("Array.update/seen-by-sub", 9, fn () => let val a = a5 () in Array.update (a, 3, 9); Array.sub (a, 3) end)
  val () = eqI ("Array.update/seen-through-alias", 9,
                fn () => let val a = a5 () val b = a in Array.update (b, 3, 9); Array.sub (a, 3) end)
  val () = T.raises ("Array.update/Subscript-length", T.isSubscript, fn () => Array.update (a5 (), 5, 9))
  val () = T.raises ("Array.update/Subscript-beyond", T.isSubscript, fn () => Array.update (a5 (), 1000, 9))
  (* The index is read from a ref because the compiler of Poly/ML 5.7.1 stops
     with "Exception- Overflow unexpectedly raised while compiling" on
     Array.update with the constant index ~1. *)
  val minusOne = ref ~1
  val () = T.raises ("Array.update/Subscript-negative", T.isSubscript, fn () => Array.update (a5 (), !minusOne, 9))
  val () = T.raises ("Array.update/Subscript-empty", T.isSubscript, fn () => Array.update (empty (), 0, 9))
  val () = eqA ("Array.update/Subscript-changes-nothing", l5,
                fn () => let val a = a5 () in Array.update (a, 5, 9) handle Subscript => (); a end)

  (* ---- vector: "the result is equivalent to
     Vector.tabulate (length arr, fn i => sub (arr, i))" ---- *)
  val () = eqL ("Array.vector/basic", l5, fn () => vectorToList (Array.vector (a5 ())))
  val () = eqL ("Array.vector/empty", [], fn () => vectorToList (Array.vector (empty ())))
  val () = eqB ("Array.vector/equals-tabulate", true,
                fn () => let val a = a5 () in Array.vector a = Vector.tabulate (Array.length a, fn i => Array.sub (a, i)) end)
  val () = eqL ("Array.vector/after-update", [1, 2, 9, 4, 5],
                fn () => let val a = a5 () in Array.update (a, 2, 9); vectorToList (Array.vector a) end)
  val () = eqL ("Array.vector/is-a-snapshot", l5,
                fn () => let val a = a5 () val v = Array.vector a in Array.update (a, 2, 9); vectorToList v end)

  (* ---- copy: "copy the entire array or vector src into the array dst, with
     the i(th) element in src, for 0 <= i < |src|, being copied to position
     di + i in the destination array. If di < 0 or if |dst| < di+|src|, then
     the Subscript exception is raised." ---- *)
  val () = eqA ("Array.copy/start", [10, 20, 30, 0, 0],
                fn () => let val d = zeros 5 in Array.copy {src = a3 (), dst = d, di = 0}; d end)
  val () = eqA ("Array.copy/middle", [0, 10, 20, 30, 0],
                fn () => let val d = zeros 5 in Array.copy {src = a3 (), dst = d, di = 1}; d end)
  val () = eqA ("Array.copy/end", [0, 0, 10, 20, 30],
                fn () => let val d = zeros 5 in Array.copy {src = a3 (), dst = d, di = 2}; d end)
  val () = eqA ("Array.copy/whole", l3,
                fn () => let val d = zeros 3 in Array.copy {src = a3 (), dst = d, di = 0}; d end)
  val () = eqA ("Array.copy/field-order", [0, 10, 20, 30, 0],
                fn () => let val d = zeros 5 in Array.copy {di = 1, dst = d, src = a3 ()}; d end)
  val () = eqA ("Array.copy/src-unchanged", l3,
                fn () => let val s = a3 () in Array.copy {src = s, dst = zeros 5, di = 1}; s end)
  val () = eqA ("Array.copy/empty-src", l5,
                fn () => let val d = a5 () in Array.copy {src = empty (), dst = d, di = 2}; d end)
  val () = eqA ("Array.copy/empty-src-at-length", l5,
                fn () => let val d = a5 () in Array.copy {src = empty (), dst = d, di = 5}; d end)
  val () = eqA ("Array.copy/empty-to-empty", [],
                fn () => let val d = empty () in Array.copy {src = empty (), dst = d, di = 0}; d end)
  val () = eqA ("Array.copy/copies-elements-not-the-array", [0, 10, 20, 30, 0],
                fn () => let val s = a3 () val d = zeros 5
                         in Array.copy {src = s, dst = d, di = 1}; Array.update (s, 0, 99); d end)
  val () = T.raises ("Array.copy/Subscript-too-far", T.isSubscript,
                     fn () => Array.copy {src = a3 (), dst = zeros 5, di = 3})
  val () = T.raises ("Array.copy/Subscript-negative", T.isSubscript,
                     fn () => Array.copy {src = a3 (), dst = zeros 5, di = ~1})
  val () = T.raises ("Array.copy/Subscript-src-longer", T.isSubscript,
                     fn () => Array.copy {src = a5 (), dst = zeros 3, di = 0})
  val () = T.raises ("Array.copy/Subscript-to-empty", T.isSubscript,
                     fn () => Array.copy {src = a3 (), dst = empty (), di = 0})
  val () = T.raises ("Array.copy/Subscript-empty-src-beyond", T.isSubscript,
                     fn () => Array.copy {src = empty (), dst = a5 (), di = 6})
  val () = T.raises ("Array.copy/Subscript-empty-src-negative", T.isSubscript,
                     fn () => Array.copy {src = empty (), dst = a5 (), di = ~1})
  (* The page does not say what is left in dst when Subscript is raised; the
     test takes it that nothing is copied, as the condition is on the arguments
     alone. *)
  val () = eqA ("Array.copy/Subscript-changes-nothing", [0, 0, 0, 0, 0],
                fn () => let val d = zeros 5 in Array.copy {src = a3 (), dst = d, di = 3} handle Subscript => (); d end)
  (* "In copy, if dst and src are equal, we must have di = 0 to avoid an
     exception, and copy is then the identity." *)
  val () = eqA ("Array.copy/onto-itself", l5,
                fn () => let val a = a5 () in Array.copy {src = a, dst = a, di = 0}; a end)
  val () = T.raises ("Array.copy/Subscript-onto-itself-shifted", T.isSubscript,
                     fn () => let val a = a5 () in Array.copy {src = a, dst = a, di = 1} end)

  (* ---- appi, app: "in order of increasing indices" ---- *)
  val () = eqIL ("Array.appi/order", i3,
                 fn () => let val (f, seen) = trace (fn _ => ()) in Array.appi f (a3 ()); seen () end)
  val () = eqIL ("Array.appi/empty", [],
                 fn () => let val (f, seen) = trace (fn _ => ()) in Array.appi f (empty ()); seen () end)
  val () = eqL ("Array.app/order", l5,
                fn () => let val (f, seen) = trace (fn _ => ()) in Array.app f (a5 ()); seen () end)
  val () = eqL ("Array.app/empty", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in Array.app f (empty ()); seen () end)
  val () = eqA ("Array.app/array-unchanged", l5, fn () => let val a = a5 () in Array.app (fn _ => ()) a; a end)

  (* ---- modifyi, modify: "apply the function f to the elements of the array
     arr in order of increasing indices, and replace each element with the
     result" ---- *)
  val () = eqA ("Array.modifyi/basic", [10, 21, 32], fn () => let val a = a3 () in Array.modifyi (op +) a; a end)
  val () = eqA ("Array.modifyi/index-and-element", [0, 20, 60],
                fn () => let val a = a3 () in Array.modifyi (op * ) a; a end)
  val () = eqA ("Array.modifyi/empty", [], fn () => let val a = empty () in Array.modifyi (op +) a; a end)
  val () = eqIL ("Array.modifyi/order", i3,
                 fn () => let val (f, seen) = trace (fn (_, x) => x + 1) in Array.modifyi f (a3 ()); seen () end)
  val () = eqA ("Array.modify/basic", [2, 4, 6, 8, 10], fn () => let val a = a5 () in Array.modify (fn x => 2 * x) a; a end)
  val () = eqA ("Array.modify/empty", [], fn () => let val a = empty () in Array.modify (fn x => 2 * x) a; a end)
  val () = eqL ("Array.modify/order", l5,
                fn () => let val (f, seen) = trace (fn x => x + 1) in Array.modify f (a5 ()); seen () end)
  val () = eqA ("Array.modify/twice", [4, 8, 12, 16, 20],
                fn () => let val a = a5 () in Array.modify (fn x => 2 * x) a; Array.modify (fn x => 2 * x) a; a end)
  val () = eqLL ("Array.modify/is-modifyi-of-second", [[2, 3, 4, 5, 6], [2, 3, 4, 5, 6]],
                 fn () => let val a = a5 () val b = a5 () val f = fn x => x + 1
                          in Array.modify f a; Array.modifyi (f o #2) b; [toList a, toList b] end)

  (* ---- foldli, foldri, foldl, foldr: "foldli and foldl apply the function f
     from left to right (increasing indices), while the functions foldri and
     foldr work from right to left (decreasing indices)".
     With f (i, a, x) = i * a - 2 * x over [10, 20, 30]:
       foldli: 0*10-0 = 0, 1*20-0 = 20, 2*30-40 = 20;
       foldri: 2*30-0 = 60, 1*20-120 = ~100, 0*10+200 = 200.
     With f (a, x) = a - 2 * x over [1, 2, 3]:
       foldl: 1-0 = 1, 2-2 = 0, 3-0 = 3;  foldr: 3-0 = 3, 2-6 = ~4, 1+8 = 9. ---- *)
  val () = eqIL ("Array.foldli/conses-reversed", [(2, 30), (1, 20), (0, 10)],
                 fn () => Array.foldli (fn (i, a, l) => (i, a) :: l) [] (a3 ()))
  val () = eqI ("Array.foldli/nonassociative", 20, fn () => Array.foldli (fn (i, a, x) => i * a - 2 * x) 0 (a3 ()))
  val () = eqI ("Array.foldli/empty", 42, fn () => Array.foldli (fn (i, a, x) => i + a + x) 42 (empty ()))
  val () = eqIL ("Array.foldri/conses-in-order", i3, fn () => Array.foldri (fn (i, a, l) => (i, a) :: l) [] (a3 ()))
  val () = eqI ("Array.foldri/nonassociative", 200, fn () => Array.foldri (fn (i, a, x) => i * a - 2 * x) 0 (a3 ()))
  val () = eqI ("Array.foldri/empty", 42, fn () => Array.foldri (fn (i, a, x) => i + a + x) 42 (empty ()))
  val () = eqL ("Array.foldl/conses-reversed", [5, 4, 3, 2, 1], fn () => Array.foldl (op ::) [] (a5 ()))
  val () = eqI ("Array.foldl/nonassociative", 3, fn () => Array.foldl (fn (a, x) => a - 2 * x) 0 (Array.fromList [1, 2, 3]))
  val () = eqI ("Array.foldl/empty", 42, fn () => Array.foldl (op +) 42 (empty ()))
  val () = eqL ("Array.foldr/conses-in-order", l5, fn () => Array.foldr (op ::) [] (a5 ()))
  val () = eqI ("Array.foldr/nonassociative", 9, fn () => Array.foldr (fn (a, x) => a - 2 * x) 0 (Array.fromList [1, 2, 3]))
  val () = eqI ("Array.foldr/empty", 42, fn () => Array.foldr (op +) 42 (empty ()))
  val () = eqA ("Array.foldl/array-unchanged", l5, fn () => let val a = a5 () in ignore (Array.foldl (op +) 0 a); a end)

  (* ---- findi, find: "from left to right (i.e., increasing indices), until a
     true value is returned"; findi "returns that index with the element" ---- *)
  val () = eqIO ("Array.findi/first-match", SOME (1, 20), fn () => Array.findi (fn (_, a) => a > 10) (a3 ()))
  val () = eqIO ("Array.findi/by-index", SOME (2, 30), fn () => Array.findi (fn (i, _) => i = 2) (a3 ()))
  val () = eqIO ("Array.findi/index-zero", SOME (0, 10), fn () => Array.findi (fn _ => true) (a3 ()))
  val () = eqIO ("Array.findi/none", NONE, fn () => Array.findi (fn (_, a) => a > 30) (a3 ()))
  val () = eqIO ("Array.findi/empty", NONE, fn () => Array.findi (fn _ => true) (empty ()))
  val () = eqIL ("Array.findi/stops", [(0, 10), (1, 20)],
                 fn () => let val (f, seen) = trace (fn (_, a) => a = 20) in ignore (Array.findi f (a3 ())); seen () end)
  val () = eqIL ("Array.findi/order", i3,
                 fn () => let val (f, seen) = trace (fn _ => false) in ignore (Array.findi f (a3 ())); seen () end)
  val () = eqO ("Array.find/first-match", SOME 2, fn () => Array.find even (a5 ()))
  val () = eqO ("Array.find/last-element", SOME 5, fn () => Array.find (fn x => x > 4) (a5 ()))
  val () = eqO ("Array.find/none", NONE, fn () => Array.find (fn x => x > 9) (a5 ()))
  val () = eqO ("Array.find/empty", NONE, fn () => Array.find (fn _ => true) (empty ()))
  val () = eqL ("Array.find/stops", [1, 2],
                fn () => let val (f, seen) = trace even in ignore (Array.find f (a5 ())); seen () end)

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB ("Array.exists/true", true, fn () => Array.exists (fn x => x = 3) (a5 ()))
  val () = eqB ("Array.exists/false", false, fn () => Array.exists (fn x => x = 9) (a5 ()))
  val () = eqB ("Array.exists/empty", false, fn () => Array.exists (fn _ => true) (empty ()))
  val () = eqL ("Array.exists/stops", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn x => x = 3) in ignore (Array.exists f (a5 ())); seen () end)
  val () = eqL ("Array.exists/order", l5,
                fn () => let val (f, seen) = trace (fn _ => false) in ignore (Array.exists f (a5 ())); seen () end)
  val () = eqB ("Array.all/true", true, fn () => Array.all (fn x => x > 0) (a5 ()))
  val () = eqB ("Array.all/false", false, fn () => Array.all (fn x => x < 3) (a5 ()))
  val () = eqB ("Array.all/empty", true, fn () => Array.all (fn _ => false) (empty ()))
  val () = eqL ("Array.all/stops", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn x => x < 3) in ignore (Array.all f (a5 ())); seen () end)
  val () = eqL ("Array.all/order", l5,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (Array.all f (a5 ())); seen () end)

  (* ---- collate: "lexicographic comparison of the two arrays using the given
     ordering f on elements" ---- *)
  fun collate cmp (l, m) = Array.collate cmp (Array.fromList l, Array.fromList m)
  val () = eqOrd ("Array.collate/equal", EQUAL, fn () => collate Int.compare ([1, 2], [1, 2]))
  val () = eqOrd ("Array.collate/same-array", EQUAL, fn () => let val a = a5 () in Array.collate Int.compare (a, a) end)
  val () = eqOrd ("Array.collate/empty-empty", EQUAL, fn () => collate Int.compare ([], []))
  val () = eqOrd ("Array.collate/empty-less", LESS, fn () => collate Int.compare ([], [1]))
  val () = eqOrd ("Array.collate/empty-greater", GREATER, fn () => collate Int.compare ([1], []))
  val () = eqOrd ("Array.collate/prefix-less", LESS, fn () => collate Int.compare ([1], [1, 2]))
  val () = eqOrd ("Array.collate/prefix-greater", GREATER, fn () => collate Int.compare ([1, 2], [1]))
  val () = eqOrd ("Array.collate/first-difference", GREATER, fn () => collate Int.compare ([1, 3], [1, 2, 9]))
  val () = eqOrd ("Array.collate/not-by-length", LESS, fn () => collate Int.compare ([0, 9, 9], [1]))
  val () = eqOrd ("Array.collate/given-ordering", GREATER,
                  fn () => collate (fn (a, b) => Int.compare (b, a)) ([0, 9, 9], [1]))
  val () = eqOrd ("Array.collate/argument-order", LESS,
                  fn () => collate (fn (a, b) => if a = 1 andalso b = 2 then LESS else GREATER) ([1], [2]))

  (* ---- array: "two arrays are equal if they are the same array, i.e.,
     created by the same call to a primitive array constructor such as array,
     fromList, etc.; otherwise they are not equal. This also holds for arrays
     of zero length. Thus, the type ty array admits equality even if ty does
     not." ---- *)
  val () = eqB ("Array.array/same-array-is-equal", true, fn () => let val a = a5 () in a = a end)
  val () = eqB ("Array.array/alias-is-equal", true, fn () => let val a = a5 () val b = a in a = b end)
  val () = eqB ("Array.array/equal-after-update", true,
                fn () => let val a = a5 () val b = a in Array.update (a, 0, 9); a = b end)
  val () = eqB ("Array.array/same-elements-not-equal", false, fn () => Array.array (3, 7) = Array.array (3, 7))
  val () = eqB ("Array.fromList/same-elements-not-equal", false, fn () => a5 () = a5 ())
  val () = eqB ("Array.tabulate/same-elements-not-equal", false,
                fn () => Array.tabulate (3, fn i => i) = Array.tabulate (3, fn i => i))
  val () = eqB ("Array.array/unequal", true, fn () => a5 () <> a5 ())
  val () = eqB ("Array.array/zero-length-same", true, fn () => let val a = empty () in a = a end)
  val () = eqB ("Array.array/zero-length-not-equal", false, fn () => Array.array (0, 7) = Array.array (0, 7))
  val () = eqB ("Array.fromList/zero-length-not-equal", false, fn () => empty () = empty ())
  val () = eqB ("Array.tabulate/zero-length-not-equal", false,
                fn () => Array.tabulate (0, fn i => i) = Array.tabulate (0, fn i => i))
  val () = eqB ("Array.array/of-reals-same", true, fn () => let val a = Array.array (2, 1.5) in a = a end)
  val () = eqB ("Array.array/of-reals-not-equal", false, fn () => Array.array (2, 1.5) = Array.array (2, 1.5))
  val () = eqB ("Array.array/of-functions-same", true,
                fn () => let val a = Array.array (2, fn (x : int) => x) in a = a end)
  val () = eqB ("Array.array/in-a-list", true,
                fn () => let val a = a5 () val b = a5 () in [a, b] = [a, b] andalso [a, b] <> [b, a] end)
  val () = eqB ("Array.array/is-toplevel", true, fn () => let val a = a5 () in (a : int array) = (a : int Array.array) end)
  val () = eqB ("Array.vector/is-Vector.vector", true,
                fn () => (Array.vector (a5 ()) : int Array.vector) = (Vector.fromList l5 : int Vector.vector))
  val () = eqB ("Array.vector/structural-equality", true, fn () => Array.vector (a5 ()) = Array.vector (a5 ()))

  (* ---- maxLen: "If n < 0 or maxLen < n, then the Size exception is raised",
     so a length that array accepts is at most maxLen ---- *)
  val () = eqB ("Array.maxLen/covers-created-arrays", true,
                fn () => Array.length (Array.array (1000, 0)) <= Array.maxLen)

  (* ---- laws, on pseudo-random arrays, against lists ---- *)
  fun randomList n = List.tabulate (n, fn _ => T.range (~50, 50))
  fun indexed l = List.tabulate (List.length l, fn j => (j, List.nth (l, j)))
  val () = T.seed 4
  val () = T.repeat (50, fn i =>
    let
      val n = Int.toString i
      val l = randomList (T.range (0, 12))
      val m = randomList (T.range (0, 12))
      val len = List.length l
      val k = T.range (0, len)            (* 0 <= k <= len *)
      val x = T.range (~50, 50)
      fun a () = Array.fromList l
      val fi = fn (j, e) => 3 * j - e
      val gi = fn (j, e, b) => j * e - 2 * b
      val g = fn (e, b) => e - 2 * b
      val pi = fn (j, e) => (j + e) mod 5 = 0
      val p = fn e => e mod 5 = 0
      (* a destination of 0..6 more elements than l, and an offset into it
         that is valid, or one too large *)
      val d = randomList (len + T.range (0, 6))
      val di = T.range (0, List.length d - len + 1)
    in
      eqA ("Array.fromList/round-trip-" ^ n, l, fn () => a ());
      eqI ("Array.length/model-" ^ n, len, fn () => Array.length (a ()));
      eqA ("Array.tabulate/model-" ^ n, l, fn () => Array.tabulate (len, fn j => List.nth (l, j)));
      eqA ("Array.array/model-" ^ n, List.tabulate (len, fn _ => x), fn () => Array.array (len, x));
      (if k < len
       then (eqI ("Array.sub/model-" ^ n, List.nth (l, k), fn () => Array.sub (a (), k));
             eqA ("Array.update/model-" ^ n, List.take (l, k) @ [x] @ List.drop (l, k + 1),
                  fn () => let val b = a () in Array.update (b, k, x); b end))
       else (T.raises ("Array.sub/model-" ^ n, T.isSubscript, fn () => Array.sub (a (), k));
             T.raises ("Array.update/model-" ^ n, T.isSubscript, fn () => Array.update (a (), k, x))));
      eqL ("Array.vector/model-" ^ n, l, fn () => vectorToList (Array.vector (a ())));
      eqB ("Array.vector/fromList-" ^ n, true, fn () => Array.vector (a ()) = Vector.fromList l);
      (if di + len <= List.length d
       then eqA ("Array.copy/model-" ^ n, List.take (d, di) @ l @ List.drop (d, di + len),
                 fn () => let val b = Array.fromList d in Array.copy {src = a (), dst = b, di = di}; b end)
       else T.raises ("Array.copy/model-" ^ n, T.isSubscript,
                      fn () => Array.copy {src = a (), dst = Array.fromList d, di = di}));
      eqIL ("Array.appi/model-" ^ n, indexed l,
            fn () => let val (f, seen) = trace (fn _ => ()) in Array.appi f (a ()); seen () end);
      eqL ("Array.app/model-" ^ n, l,
           fn () => let val (f, seen) = trace (fn _ => ()) in Array.app f (a ()); seen () end);
      eqA ("Array.modifyi/model-" ^ n, List.map fi (indexed l), fn () => let val b = a () in Array.modifyi fi b; b end);
      eqA ("Array.modify/model-" ^ n, List.map (fn e => e * e) l,
           fn () => let val b = a () in Array.modify (fn e => e * e) b; b end);
      eqI ("Array.foldli/model-" ^ n, List.foldl (fn ((j, e), b) => gi (j, e, b)) 1 (indexed l),
           fn () => Array.foldli gi 1 (a ()));
      eqI ("Array.foldri/model-" ^ n, List.foldr (fn ((j, e), b) => gi (j, e, b)) 1 (indexed l),
           fn () => Array.foldri gi 1 (a ()));
      eqI ("Array.foldl/model-" ^ n, List.foldl g 1 l, fn () => Array.foldl g 1 (a ()));
      eqI ("Array.foldr/model-" ^ n, List.foldr g 1 l, fn () => Array.foldr g 1 (a ()));
      eqIO ("Array.findi/model-" ^ n, List.find pi (indexed l), fn () => Array.findi pi (a ()));
      eqO ("Array.find/model-" ^ n, List.find p l, fn () => Array.find p (a ()));
      eqB ("Array.exists/model-" ^ n, List.exists p l, fn () => Array.exists p (a ()));
      eqB ("Array.all/model-" ^ n, List.all (not o p) l, fn () => Array.all (not o p) (a ()));
      eqB ("Array.all/de-morgan-" ^ n, true,
           fn () => let val b = a () in Array.all p b = not (Array.exists (not o p) b) end);
      eqOrd ("Array.collate/model-" ^ n, List.collate Int.compare (l, m),
             fn () => Array.collate Int.compare (a (), Array.fromList m));
      eqOrd ("Array.collate/reflexive-" ^ n, EQUAL, fn () => Array.collate Int.compare (a (), a ()));
      eqB ("Array.array/identity-" ^ n, true, fn () => let val b = a () in b = b andalso b <> a () end)
    end)

  (* ---- long arrays: no stack or quadratic trouble ---- *)
  fun big () = Array.tabulate (200000, fn i => i)
  val () = eqI ("Array.length/long", 200000, fn () => Array.length (big ()))
  val () = eqI ("Array.array/long", 200000, fn () => Array.length (Array.array (200000, 0)))
  val () = eqI ("Array.sub/long", 199999, fn () => Array.sub (big (), 199999))
  val () = eqI ("Array.fromList/long", 200000, fn () => Array.length (Array.fromList (List.tabulate (200000, fn i => i))))
  val () = eqI ("Array.modify/long", 200000, fn () => let val a = big () in Array.modify (fn x => x + 1) a; Array.sub (a, 199999) end)
  val () = eqI ("Array.modifyi/long", 0, fn () => let val a = big () in Array.modifyi (op -) a; Array.sub (a, 199999) end)
  val () = eqI ("Array.foldl/long", 199999, fn () => Array.foldl Int.max 0 (big ()))
  val () = eqI ("Array.foldr/long", 199999, fn () => Array.foldr Int.max 0 (big ()))
  val () = eqI ("Array.foldr/long-list", 200000, fn () => List.length (Array.foldr (op ::) [] (big ())))
  val () = eqO ("Array.find/long", SOME 199999, fn () => Array.find (fn x => x = 199999) (big ()))
  val () = eqB ("Array.all/long", true, fn () => Array.all (fn x => x >= 0) (big ()))
  val () = eqI ("Array.vector/long", 200000, fn () => Vector.length (Array.vector (big ())))
  val () = eqI ("Array.copy/long", 199999,
                fn () => let val d = Array.array (200001, ~1) in Array.copy {src = big (), dst = d, di = 1}; Array.sub (d, 200000) end)
  val () = eqOrd ("Array.collate/long", EQUAL, fn () => Array.collate Int.compare (big (), big ()))

  (*<< copyVec *)
  (* ---- copyVec: as copy, from a vector ---- *)
  val v3 = Vector.fromList l3
  val noV : int vector = Vector.fromList []
  val () = eqA ("Array.copyVec/start", [10, 20, 30, 0, 0],
                fn () => let val d = zeros 5 in Array.copyVec {src = v3, dst = d, di = 0}; d end)
  val () = eqA ("Array.copyVec/middle", [0, 10, 20, 30, 0],
                fn () => let val d = zeros 5 in Array.copyVec {src = v3, dst = d, di = 1}; d end)
  val () = eqA ("Array.copyVec/end", [0, 0, 10, 20, 30],
                fn () => let val d = zeros 5 in Array.copyVec {src = v3, dst = d, di = 2}; d end)
  val () = eqA ("Array.copyVec/whole", l3,
                fn () => let val d = zeros 3 in Array.copyVec {src = v3, dst = d, di = 0}; d end)
  val () = eqA ("Array.copyVec/field-order", [0, 10, 20, 30, 0],
                fn () => let val d = zeros 5 in Array.copyVec {di = 1, dst = d, src = v3}; d end)
  val () = eqL ("Array.copyVec/src-unchanged", l3,
                fn () => (Array.copyVec {src = v3, dst = zeros 5, di = 1}; vectorToList v3))
  val () = eqA ("Array.copyVec/empty-src", l5,
                fn () => let val d = a5 () in Array.copyVec {src = noV, dst = d, di = 2}; d end)
  val () = eqA ("Array.copyVec/empty-src-at-length", l5,
                fn () => let val d = a5 () in Array.copyVec {src = noV, dst = d, di = 5}; d end)
  val () = eqA ("Array.copyVec/empty-to-empty", [],
                fn () => let val d = empty () in Array.copyVec {src = noV, dst = d, di = 0}; d end)
  val () = eqA ("Array.copyVec/from-Array.vector", [1, 1, 2, 3, 4],
                fn () => let val a = a5 () in Array.copyVec {src = Array.vector (Array.fromList [1, 2, 3, 4]), dst = a, di = 1}; a end)
  val () = T.raises ("Array.copyVec/Subscript-too-far", T.isSubscript,
                     fn () => Array.copyVec {src = v3, dst = zeros 5, di = 3})
  val () = T.raises ("Array.copyVec/Subscript-negative", T.isSubscript,
                     fn () => Array.copyVec {src = v3, dst = zeros 5, di = ~1})
  val () = T.raises ("Array.copyVec/Subscript-src-longer", T.isSubscript,
                     fn () => Array.copyVec {src = Vector.fromList l5, dst = zeros 3, di = 0})
  val () = T.raises ("Array.copyVec/Subscript-to-empty", T.isSubscript,
                     fn () => Array.copyVec {src = v3, dst = empty (), di = 0})
  val () = T.raises ("Array.copyVec/Subscript-empty-src-beyond", T.isSubscript,
                     fn () => Array.copyVec {src = noV, dst = a5 (), di = 6})
  val () = T.raises ("Array.copyVec/Subscript-empty-src-negative", T.isSubscript,
                     fn () => Array.copyVec {src = noV, dst = a5 (), di = ~1})
  (* As for copy: the test takes it that nothing is copied when Subscript is
     raised. *)
  val () = eqA ("Array.copyVec/Subscript-changes-nothing", [0, 0, 0, 0, 0],
                fn () => let val d = zeros 5 in Array.copyVec {src = v3, dst = d, di = 3} handle Subscript => (); d end)
  val () = T.seed 5
  val () = T.repeat (50, fn i =>
    let
      val n = Int.toString i
      val l = randomList (T.range (0, 12))
      val len = List.length l
      val d = randomList (len + T.range (0, 6))
      val di = T.range (0, List.length d - len + 1)
    in
      if di + len <= List.length d
      then eqA ("Array.copyVec/model-" ^ n, List.take (d, di) @ l @ List.drop (d, di + len),
                fn () => let val b = Array.fromList d in Array.copyVec {src = Vector.fromList l, dst = b, di = di}; b end)
      else T.raises ("Array.copyVec/model-" ^ n, T.isSubscript,
                     fn () => Array.copyVec {src = Vector.fromList l, dst = Array.fromList d, di = di})
    end)
  val () = eqI ("Array.copyVec/long", 199999,
                fn () => let val d = Array.array (200001, ~1)
                         in Array.copyVec {src = Vector.tabulate (200000, fn i => i), dst = d, di = 1}; Array.sub (d, 200000) end)
  (*>> copyVec *)

  (* ---- Size above maxLen: "Attempts to create larger arrays will result in
     the Size exception being raised." maxLen + 1 exists unless maxLen is
     Int.maxInt. The function that is tabulated gives up after 1000
     applications, so that an implementation that applies it before it looks at
     the length fails the check instead of running out of memory. (fromList
     would take a list of maxLen + 1 elements, which is too much everywhere.) ---- *)
  val aboveMaxLen : int option =
    case Int.maxInt of
      NONE => SOME (Array.maxLen + 1)
    | SOME most => if Array.maxLen < most then SOME (Array.maxLen + 1) else NONE
  val () =
    case aboveMaxLen of
      NONE => ()
    | SOME n =>
        (T.raises ("Array.tabulate/Size-above-maxLen", T.isSize,
                   fn () => Array.tabulate (n, fn i => if i < 1000 then i else raise Fail "f applied before Size"));
         T.raises ("Array.array/Size-above-maxLen", T.isSize, fn () => Array.array (n, 0)))
end
