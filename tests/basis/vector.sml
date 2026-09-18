(* requires: Vector List *)
(* The Vector structure (signature VECTOR). Expected values follow the text of
   https://smlfamily.github.io/Basis/vector.html.

   Results are compared as lists, read with Vector.length and Vector.sub, so
   that only the checks of Vector.vector depend on the equality of vectors.
   The checks of Size that need a length above Vector.maxLen come last: an
   implementation that does not make them may run out of memory. *)
structure TestVector =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val eqO = T.eq (T.option T.int)
  val eqOrd = T.eq T.order
  val eqIL = T.eq (T.list (T.pair (T.int, T.int)))
  val eqIO = T.eq (T.option (T.pair (T.int, T.int)))

  fun toList (v : 'a vector) : 'a list = List.tabulate (Vector.length v, fn i => Vector.sub (v, i))

  (* eqV (label, expected, f): the elements of the vector f () are expected. *)
  fun eqV (label, expected : int list, f : unit -> int vector) : unit =
    eqL (label, expected, fn () => toList (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end

  val l5 = [1, 2, 3, 4, 5]
  val v5 = Vector.fromList l5
  val v3 = Vector.fromList [10, 20, 30]
  val i3 = [(0, 10), (1, 20), (2, 30)]
  val empty : int vector = Vector.fromList []
  val even = fn x => x mod 2 = 0

  (* ---- fromList: "the i(th) element of l used as the i(th) element of the
     vector" ---- *)
  val () = eqV ("Vector.fromList/basic", [1, 2, 3], fn () => Vector.fromList [1, 2, 3])
  val () = eqV ("Vector.fromList/nil", [], fn () => Vector.fromList [])
  val () = eqV ("Vector.fromList/singleton", [7], fn () => Vector.fromList [7])
  val () = eqI ("Vector.fromList/length", 5, fn () => Vector.length (Vector.fromList l5))
  val () = T.eq (T.list T.string)
             ("Vector.fromList/strings", ["a", "", "bc"], fn () => toList (Vector.fromList ["a", "", "bc"]))

  (* ---- tabulate: "the elements are defined in order of increasing index by
     applying f to the element's index" ---- *)
  val () = eqV ("Vector.tabulate/basic", [0, 1, 4, 9], fn () => Vector.tabulate (4, fn i => i * i))
  val () = eqV ("Vector.tabulate/zero", [], fn () => Vector.tabulate (0, fn i => i))
  val () = eqV ("Vector.tabulate/one", [5], fn () => Vector.tabulate (1, fn i => i + 5))
  val () = eqL ("Vector.tabulate/order", [0, 1, 2, 3],
                fn () => let val (f, seen) = trace (fn i => i) in ignore (Vector.tabulate (4, f)); seen () end)
  val () = T.raises ("Vector.tabulate/Size-negative", T.isSize, fn () => Vector.tabulate (~1, fn i => i))
  val () = eqL ("Vector.tabulate/Size-before-f", [],
                fn () => let val (f, seen) = trace (fn i => i)
                         in ignore (Vector.tabulate (~3, f)) handle Size => (); seen () end)

  (* ---- length ---- *)
  val () = eqI ("Vector.length/empty", 0, fn () => Vector.length empty)
  val () = eqI ("Vector.length/five", 5, fn () => Vector.length v5)
  val () = eqI ("Vector.length/tabulate", 1000, fn () => Vector.length (Vector.tabulate (1000, fn i => i)))

  (* ---- sub: "If i < 0 or |vec| <= i, then the Subscript exception is
     raised." ---- *)
  val () = eqI ("Vector.sub/first", 1, fn () => Vector.sub (v5, 0))
  val () = eqI ("Vector.sub/middle", 3, fn () => Vector.sub (v5, 2))
  val () = eqI ("Vector.sub/last", 5, fn () => Vector.sub (v5, 4))
  val () = T.raises ("Vector.sub/Subscript-length", T.isSubscript, fn () => Vector.sub (v5, 5))
  val () = T.raises ("Vector.sub/Subscript-beyond", T.isSubscript, fn () => Vector.sub (v5, 1000))
  val () = T.raises ("Vector.sub/Subscript-negative", T.isSubscript, fn () => Vector.sub (v5, ~1))
  val () = T.raises ("Vector.sub/Subscript-empty", T.isSubscript, fn () => Vector.sub (empty, 0))

  (* ---- update: "returns a new vector, identical to vec, except the i(th)
     element of vec is set to x" ---- *)
  val () = eqV ("Vector.update/first", [9, 2, 3, 4, 5], fn () => Vector.update (v5, 0, 9))
  val () = eqV ("Vector.update/middle", [1, 2, 9, 4, 5], fn () => Vector.update (v5, 2, 9))
  val () = eqV ("Vector.update/last", [1, 2, 3, 4, 9], fn () => Vector.update (v5, 4, 9))
  val () = eqV ("Vector.update/singleton", [8], fn () => Vector.update (Vector.fromList [7], 0, 8))
  val () = eqV ("Vector.update/argument-unchanged", l5,
                fn () => let val v = Vector.fromList l5 in ignore (Vector.update (v, 2, 9)); v end)
  val () = eqV ("Vector.update/twice", [1, 8, 3, 9, 5], fn () => Vector.update (Vector.update (v5, 3, 9), 1, 8))
  val () = T.raises ("Vector.update/Subscript-length", T.isSubscript, fn () => Vector.update (v5, 5, 9))
  val () = T.raises ("Vector.update/Subscript-beyond", T.isSubscript, fn () => Vector.update (v5, 1000, 9))
  val () = T.raises ("Vector.update/Subscript-negative", T.isSubscript, fn () => Vector.update (v5, ~1, 9))
  val () = T.raises ("Vector.update/Subscript-empty", T.isSubscript, fn () => Vector.update (empty, 0, 9))

  (* ---- concat ---- *)
  val () = eqV ("Vector.concat/basic", [1, 2, 3, 4],
                fn () => Vector.concat [Vector.fromList [1], empty, Vector.fromList [2, 3], Vector.fromList [4]])
  val () = eqV ("Vector.concat/nil", [], fn () => Vector.concat [])
  val () = eqV ("Vector.concat/one", l5, fn () => Vector.concat [v5])
  val () = eqV ("Vector.concat/empties", [], fn () => Vector.concat [empty, empty, empty])
  val () = eqV ("Vector.concat/same-twice", [10, 20, 30, 10, 20, 30], fn () => Vector.concat [v3, v3])
  val () = eqV ("Vector.concat/order", [10, 20, 30, 1, 2, 3, 4, 5], fn () => Vector.concat [v3, v5])

  (* ---- appi, app: "in left to right order (i.e., in order of increasing
     indices)" ---- *)
  val () = eqIL ("Vector.appi/order", i3,
                 fn () => let val (f, seen) = trace (fn _ => ()) in Vector.appi f v3; seen () end)
  val () = eqIL ("Vector.appi/empty", [],
                 fn () => let val (f, seen) = trace (fn _ => ()) in Vector.appi f empty; seen () end)
  val () = eqL ("Vector.app/order", l5,
                fn () => let val (f, seen) = trace (fn _ => ()) in Vector.app f v5; seen () end)
  val () = eqL ("Vector.app/empty", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in Vector.app f empty; seen () end)

  (* ---- mapi, map: "mapping the function f from left to right" ---- *)
  val () = eqV ("Vector.mapi/basic", [10, 21, 32], fn () => Vector.mapi (op +) v3)
  val () = eqV ("Vector.mapi/index-and-element", [0, 20, 60], fn () => Vector.mapi (op * ) v3)
  val () = eqV ("Vector.mapi/empty", [], fn () => Vector.mapi (op +) empty)
  val () = eqIL ("Vector.mapi/order", i3,
                 fn () => let val (f, seen) = trace (fn _ => 0) in ignore (Vector.mapi f v3); seen () end)
  val () = eqV ("Vector.map/basic", [2, 4, 6, 8, 10], fn () => Vector.map (fn x => 2 * x) v5)
  val () = eqV ("Vector.map/empty", [], fn () => Vector.map (fn x => 2 * x) empty)
  val () = eqL ("Vector.map/order", l5,
                fn () => let val (f, seen) = trace (fn _ => 0) in ignore (Vector.map f v5); seen () end)
  val () = T.eq (T.list T.string)
             ("Vector.map/other-type", ["10", "20", "30"], fn () => toList (Vector.map Int.toString v3))
  val () = eqV ("Vector.map/argument-unchanged", [10, 20, 30],
                fn () => let val v = Vector.fromList [10, 20, 30] in ignore (Vector.map (fn x => x + 1) v); v end)

  (* ---- foldli, foldri, foldl, foldr: "foldli and foldl apply the function f
     from left to right (increasing indices), while the functions foldri and
     foldr work from right to left (decreasing indices)".
     With f (i, a, x) = i * a - 2 * x over [10, 20, 30]:
       foldli: 0*10-0 = 0, 1*20-0 = 20, 2*30-40 = 20;
       foldri: 2*30-0 = 60, 1*20-120 = ~100, 0*10+200 = 200.
     With f (a, x) = a - 2 * x over [1, 2, 3]:
       foldl: 1-0 = 1, 2-2 = 0, 3-0 = 3;  foldr: 3-0 = 3, 2-6 = ~4, 1+8 = 9. ---- *)
  val () = eqIL ("Vector.foldli/conses-reversed", [(2, 30), (1, 20), (0, 10)],
                 fn () => Vector.foldli (fn (i, a, l) => (i, a) :: l) [] v3)
  val () = eqI ("Vector.foldli/nonassociative", 20, fn () => Vector.foldli (fn (i, a, x) => i * a - 2 * x) 0 v3)
  val () = eqI ("Vector.foldli/empty", 42, fn () => Vector.foldli (fn (i, a, x) => i + a + x) 42 empty)
  val () = eqIL ("Vector.foldri/conses-in-order", i3, fn () => Vector.foldri (fn (i, a, l) => (i, a) :: l) [] v3)
  val () = eqI ("Vector.foldri/nonassociative", 200, fn () => Vector.foldri (fn (i, a, x) => i * a - 2 * x) 0 v3)
  val () = eqI ("Vector.foldri/empty", 42, fn () => Vector.foldri (fn (i, a, x) => i + a + x) 42 empty)
  val () = eqL ("Vector.foldl/conses-reversed", [5, 4, 3, 2, 1], fn () => Vector.foldl (op ::) [] v5)
  val () = eqI ("Vector.foldl/nonassociative", 3, fn () => Vector.foldl (fn (a, x) => a - 2 * x) 0 (Vector.fromList [1, 2, 3]))
  val () = eqI ("Vector.foldl/empty", 42, fn () => Vector.foldl (op +) 42 empty)
  val () = eqL ("Vector.foldr/conses-in-order", l5, fn () => Vector.foldr (op ::) [] v5)
  val () = eqI ("Vector.foldr/nonassociative", 9, fn () => Vector.foldr (fn (a, x) => a - 2 * x) 0 (Vector.fromList [1, 2, 3]))
  val () = eqI ("Vector.foldr/empty", 42, fn () => Vector.foldr (op +) 42 empty)

  (* ---- findi, find: "from left to right (i.e., increasing indices), until a
     true value is returned"; findi "returns that index with the element" ---- *)
  val () = eqIO ("Vector.findi/first-match", SOME (1, 20), fn () => Vector.findi (fn (_, a) => a > 10) v3)
  val () = eqIO ("Vector.findi/by-index", SOME (2, 30), fn () => Vector.findi (fn (i, _) => i = 2) v3)
  val () = eqIO ("Vector.findi/index-zero", SOME (0, 10), fn () => Vector.findi (fn _ => true) v3)
  val () = eqIO ("Vector.findi/none", NONE, fn () => Vector.findi (fn (_, a) => a > 30) v3)
  val () = eqIO ("Vector.findi/empty", NONE, fn () => Vector.findi (fn _ => true) empty)
  val () = eqIL ("Vector.findi/stops", [(0, 10), (1, 20)],
                 fn () => let val (f, seen) = trace (fn (_, a) => a = 20) in ignore (Vector.findi f v3); seen () end)
  val () = eqIL ("Vector.findi/order", i3,
                 fn () => let val (f, seen) = trace (fn _ => false) in ignore (Vector.findi f v3); seen () end)
  val () = eqO ("Vector.find/first-match", SOME 2, fn () => Vector.find even v5)
  val () = eqO ("Vector.find/last-element", SOME 5, fn () => Vector.find (fn x => x > 4) v5)
  val () = eqO ("Vector.find/none", NONE, fn () => Vector.find (fn x => x > 9) v5)
  val () = eqO ("Vector.find/empty", NONE, fn () => Vector.find (fn _ => true) empty)
  val () = eqL ("Vector.find/stops", [1, 2],
                fn () => let val (f, seen) = trace even in ignore (Vector.find f v5); seen () end)

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB ("Vector.exists/true", true, fn () => Vector.exists (fn x => x = 3) v5)
  val () = eqB ("Vector.exists/false", false, fn () => Vector.exists (fn x => x = 9) v5)
  val () = eqB ("Vector.exists/empty", false, fn () => Vector.exists (fn _ => true) empty)
  val () = eqL ("Vector.exists/stops", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn x => x = 3) in ignore (Vector.exists f v5); seen () end)
  val () = eqL ("Vector.exists/order", l5,
                fn () => let val (f, seen) = trace (fn _ => false) in ignore (Vector.exists f v5); seen () end)
  val () = eqB ("Vector.all/true", true, fn () => Vector.all (fn x => x > 0) v5)
  val () = eqB ("Vector.all/false", false, fn () => Vector.all (fn x => x < 3) v5)
  val () = eqB ("Vector.all/empty", true, fn () => Vector.all (fn _ => false) empty)
  val () = eqL ("Vector.all/stops", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn x => x < 3) in ignore (Vector.all f v5); seen () end)
  val () = eqL ("Vector.all/order", l5,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (Vector.all f v5); seen () end)

  (* ---- collate: "lexicographic comparison of the two vectors using the given
     ordering f on elements" ---- *)
  fun collate cmp (l, m) = Vector.collate cmp (Vector.fromList l, Vector.fromList m)
  val () = eqOrd ("Vector.collate/equal", EQUAL, fn () => collate Int.compare ([1, 2], [1, 2]))
  val () = eqOrd ("Vector.collate/empty-empty", EQUAL, fn () => collate Int.compare ([], []))
  val () = eqOrd ("Vector.collate/empty-less", LESS, fn () => collate Int.compare ([], [1]))
  val () = eqOrd ("Vector.collate/empty-greater", GREATER, fn () => collate Int.compare ([1], []))
  val () = eqOrd ("Vector.collate/prefix-less", LESS, fn () => collate Int.compare ([1], [1, 2]))
  val () = eqOrd ("Vector.collate/prefix-greater", GREATER, fn () => collate Int.compare ([1, 2], [1]))
  val () = eqOrd ("Vector.collate/first-difference", GREATER, fn () => collate Int.compare ([1, 3], [1, 2, 9]))
  val () = eqOrd ("Vector.collate/not-by-length", LESS, fn () => collate Int.compare ([0, 9, 9], [1]))
  val () = eqOrd ("Vector.collate/given-ordering", GREATER,
                  fn () => collate (fn (a, b) => Int.compare (b, a)) ([0, 9, 9], [1]))
  val () = eqOrd ("Vector.collate/argument-order", LESS,
                  fn () => Vector.collate (fn (a, b) => if a = 1 andalso b = 2 then LESS else GREATER)
                                          (Vector.fromList [1], Vector.fromList [2]))

  (* ---- vector: an equality type ("eqtype 'a vector"); vectors are immutable,
     so they are equal when their lengths and their elements are ---- *)
  val () = eqB ("Vector.vector/equal", true, fn () => Vector.fromList [1, 2, 3] = Vector.fromList [1, 2, 3])
  val () = eqB ("Vector.vector/equal-tabulate", true,
                fn () => Vector.tabulate (3, fn i => i + 1) = Vector.fromList [1, 2, 3])
  val () = eqB ("Vector.vector/element-differs", false, fn () => Vector.fromList [1, 2, 3] = Vector.fromList [1, 2, 4])
  val () = eqB ("Vector.vector/prefix", false, fn () => Vector.fromList [1, 2] = Vector.fromList [1, 2, 3])
  val () = eqB ("Vector.vector/empty-equal", true, fn () => (Vector.fromList [] : int vector) = Vector.tabulate (0, fn i => i))
  val () = eqB ("Vector.vector/empty-nonempty", false, fn () => empty = Vector.fromList [0])
  val () = eqB ("Vector.vector/unequal", true, fn () => Vector.fromList [1] <> Vector.fromList [2])
  val () = eqB ("Vector.vector/strings", true, fn () => Vector.fromList ["a", "b"] = Vector.fromList ["a", "b"])
  val () = eqB ("Vector.vector/nested", true,
                fn () => Vector.fromList [Vector.fromList [1], empty] = Vector.fromList [Vector.fromList [1], empty])
  val () = eqB ("Vector.vector/nested-differs", false,
                fn () => Vector.fromList [Vector.fromList [1], empty] = Vector.fromList [Vector.fromList [1], v3])
  val () = eqB ("Vector.vector/update-to-same", true, fn () => Vector.update (v5, 2, 3) = v5)
  val () = eqB ("Vector.vector/update-differs", false, fn () => Vector.update (v5, 2, 9) = v5)
  val () = eqB ("Vector.vector/is-toplevel", true, fn () => (v5 : int vector) = (v5 : int Vector.vector))

  (* ---- maxLen: "If n < 0 or maxLen < n, then the Size exception is raised",
     so a length that tabulate accepts is at most maxLen ---- *)
  val () = eqB ("Vector.maxLen/covers-created-vectors", true,
                fn () => Vector.length (Vector.tabulate (1000, fn i => i)) <= Vector.maxLen)

  (* ---- laws, on pseudo-random vectors, against lists ---- *)
  fun randomList () = List.tabulate (T.range (0, 12), fn _ => T.range (~50, 50))
  fun indexed l = List.tabulate (List.length l, fn j => (j, List.nth (l, j)))
  val () = T.seed 3
  val () = T.repeat (50, fn i =>
    let
      val n = Int.toString i
      val l = randomList ()
      val m = randomList ()
      val v = Vector.fromList l
      val w = Vector.fromList m
      val len = List.length l
      val k = T.range (0, len)            (* 0 <= k <= len *)
      val x = T.range (~50, 50)
      val fi = fn (j, a) => 3 * j - a
      val gi = fn (j, a, b) => j * a - 2 * b
      val g = fn (a, b) => a - 2 * b
      val pi = fn (j, a) => (j + a) mod 5 = 0
      val p = fn a => a mod 5 = 0
    in
      eqV ("Vector.fromList/round-trip-" ^ n, l, fn () => Vector.fromList l);
      eqI ("Vector.length/model-" ^ n, len, fn () => Vector.length v);
      eqV ("Vector.tabulate/model-" ^ n, l, fn () => Vector.tabulate (len, fn j => List.nth (l, j)));
      (if k < len
       then (eqI ("Vector.sub/model-" ^ n, List.nth (l, k), fn () => Vector.sub (v, k));
             eqV ("Vector.update/model-" ^ n, List.take (l, k) @ [x] @ List.drop (l, k + 1),
                  fn () => Vector.update (v, k, x)))
       else (T.raises ("Vector.sub/model-" ^ n, T.isSubscript, fn () => Vector.sub (v, k));
             T.raises ("Vector.update/model-" ^ n, T.isSubscript, fn () => Vector.update (v, k, x))));
      eqV ("Vector.concat/model-" ^ n, l @ m @ l, fn () => Vector.concat [v, w, v]);
      eqIL ("Vector.appi/model-" ^ n, indexed l,
            fn () => let val (f, seen) = trace (fn _ => ()) in Vector.appi f v; seen () end);
      eqL ("Vector.app/model-" ^ n, l,
           fn () => let val (f, seen) = trace (fn _ => ()) in Vector.app f v; seen () end);
      eqV ("Vector.mapi/model-" ^ n, List.map fi (indexed l), fn () => Vector.mapi fi v);
      eqV ("Vector.map/model-" ^ n, List.map (fn a => a * a) l, fn () => Vector.map (fn a => a * a) v);
      eqI ("Vector.foldli/model-" ^ n, List.foldl (fn ((j, a), b) => gi (j, a, b)) 1 (indexed l),
           fn () => Vector.foldli gi 1 v);
      eqI ("Vector.foldri/model-" ^ n, List.foldr (fn ((j, a), b) => gi (j, a, b)) 1 (indexed l),
           fn () => Vector.foldri gi 1 v);
      eqI ("Vector.foldl/model-" ^ n, List.foldl g 1 l, fn () => Vector.foldl g 1 v);
      eqI ("Vector.foldr/model-" ^ n, List.foldr g 1 l, fn () => Vector.foldr g 1 v);
      eqIO ("Vector.findi/model-" ^ n, List.find pi (indexed l), fn () => Vector.findi pi v);
      eqO ("Vector.find/model-" ^ n, List.find p l, fn () => Vector.find p v);
      eqB ("Vector.exists/model-" ^ n, List.exists p l, fn () => Vector.exists p v);
      eqB ("Vector.all/model-" ^ n, List.all (not o p) l, fn () => Vector.all (not o p) v);
      eqB ("Vector.all/de-morgan-" ^ n, true, fn () => Vector.all p v = not (Vector.exists (not o p) v));
      eqOrd ("Vector.collate/model-" ^ n, List.collate Int.compare (l, m), fn () => Vector.collate Int.compare (v, w));
      eqOrd ("Vector.collate/reflexive-" ^ n, EQUAL, fn () => Vector.collate Int.compare (v, Vector.fromList l));
      eqB ("Vector.vector/model-" ^ n, l = m, fn () => v = w);
      eqB ("Vector.vector/reflexive-" ^ n, true, fn () => v = Vector.fromList l)
    end)

  (* ---- long vectors: no stack or quadratic trouble ---- *)
  val big = Vector.tabulate (200000, fn i => i)
  val () = eqI ("Vector.length/long", 200000, fn () => Vector.length big)
  val () = eqI ("Vector.sub/long", 199999, fn () => Vector.sub (big, 199999))
  val () = eqI ("Vector.fromList/long", 200000, fn () => Vector.length (Vector.fromList (List.tabulate (200000, fn i => i))))
  val () = eqI ("Vector.update/long", ~1, fn () => Vector.sub (Vector.update (big, 100000, ~1), 100000))
  val () = eqI ("Vector.map/long", 200000, fn () => Vector.sub (Vector.map (fn x => x + 1) big, 199999))
  val () = eqI ("Vector.mapi/long", 0, fn () => Vector.sub (Vector.mapi (op -) big, 199999))
  val () = eqI ("Vector.foldl/long", 199999, fn () => Vector.foldl Int.max 0 big)
  val () = eqI ("Vector.foldr/long", 199999, fn () => Vector.foldr Int.max 0 big)
  val () = eqI ("Vector.foldr/long-list", 200000, fn () => List.length (Vector.foldr (op ::) [] big))
  val () = eqO ("Vector.find/long", SOME 199999, fn () => Vector.find (fn x => x = 199999) big)
  val () = eqB ("Vector.all/long", true, fn () => Vector.all (fn x => x >= 0) big)
  val () = eqI ("Vector.concat/long", 400000, fn () => Vector.length (Vector.concat [big, big]))
  val () = eqI ("Vector.concat/many", 200000,
                fn () => Vector.length (Vector.concat (List.tabulate (2000, fn _ => Vector.tabulate (100, fn i => i)))))
  val () = eqOrd ("Vector.collate/long", EQUAL, fn () => Vector.collate Int.compare (big, Vector.tabulate (200000, fn i => i)))
  val () = eqB ("Vector.vector/long", true, fn () => big = Vector.tabulate (200000, fn i => i))

  (* ---- Size above maxLen: "Attempts to create larger vectors will result in
     the Size exception being raised." maxLen + 1 exists unless maxLen is
     Int.maxInt. The function that is tabulated gives up after 1000
     applications, so that an implementation that applies it before it looks at
     the length fails the check instead of running out of memory. ---- *)
  val aboveMaxLen : int option =
    case Int.maxInt of
      NONE => SOME (Vector.maxLen + 1)
    | SOME most => if Vector.maxLen < most then SOME (Vector.maxLen + 1) else NONE
  val () =
    case aboveMaxLen of
      NONE => ()
    | SOME n =>
        T.raises ("Vector.tabulate/Size-above-maxLen", T.isSize,
                  fn () => Vector.tabulate (n, fn i => if i < 1000 then i else raise Fail "f applied before Size"))
  (* concat can only be given more than maxLen elements where maxLen is small:
     1024 times a vector of maxLen div 1024 + 1 elements. (For fromList that
     takes a list of maxLen + 1 elements, which is too much everywhere.) *)
  val () =
    if Vector.maxLen <= 16777216
    then T.raises ("Vector.concat/Size-above-maxLen", T.isSize,
                   fn () => let val part = Vector.tabulate (Vector.maxLen div 1024 + 1, fn _ => 0)
                            in Vector.concat (List.tabulate (1024, fn _ => part)) end)
    else ()
end
