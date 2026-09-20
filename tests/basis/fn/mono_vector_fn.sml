(* Checks of a structure with signature MONO_VECTOR, for any element type.
   Expected values follow https://smlfamily.github.io/Basis/mono-vector.html.

     structure Generic = TestMonoVectorFn (structure V = Word8Vector val name = "Word8Vector" val elems = ... val show = ... val same = ...)

   needs spec-sigs/MONO_VECTOR.sml. The labels are name ^ ".member/case".
   `elems` holds at least 8 distinct sample elements, `show` prints one and
   `same` is the equality of elements (the signature says `type elem`, and
   `type vector`: nothing here relies on the equality of either). An element
   is written below as its index in `elems`, its code: the vector [1, 2, 3] is
   the one of the samples 1, 2 and 3, and vectors are compared as the lists of
   the codes of their elements, read with V.length and V.sub.

   TestMonoVectorSizeFn has the checks of Size that ask for more than V.maxLen
   elements; an implementation that does not make them may run out of memory,
   so a test applies it in a section of its own. *)
functor TestMonoVectorFn (structure V : SPEC_MONO_VECTOR
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
  val eqInts = T.eq (T.list T.int)

  fun toList v = List.tabulate (V.length v, fn i => code (V.sub (v, i)))
  fun vec l = V.fromList (List.map e l)
  fun eqV (label, expected : int list, f : unit -> V.vector) : unit =
    eqL (label, expected, fn () => toList (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end
  fun coded (f, seen) = (f, fn () => List.map code (seen ()))
  fun codedI (f, seen) = (f, fn () => List.map (fn (i, x) => (i, code x)) (seen ()))

  val l5 = [1, 2, 3, 4, 5]
  fun v5 () = vec l5
  fun v3 () = vec [3, 5, 7]
  val i3 = [(0, 3), (1, 5), (2, 7)]
  fun empty () = vec []
  val minusOne = ref ~1   (* not a constant: see Array.update in array.sml *)
  fun cmp (a, b) = Int.compare (code a, code b)
  fun even x = code x mod 2 = 0

  val () = T.check (lab "elem/eight-distinct-samples",
                    fn () => samples >= 8 andalso List.tabulate (8, fn i => code (e i)) = [0, 1, 2, 3, 4, 5, 6, 7])

  (* ---- fromList: "whose length is length l and with the i(th) element of l
     used as the i(th) element of the vector" ---- *)
  val () = eqV (lab "fromList/basic", [1, 2, 3], fn () => V.fromList [e 1, e 2, e 3])
  val () = eqV (lab "fromList/nil", [], fn () => V.fromList [])
  val () = eqV (lab "fromList/singleton", [7], fn () => V.fromList [e 7])
  val () = eqV (lab "fromList/every-sample", [0, 1, 2, 3, 4, 5, 6, 7], fn () => V.fromList (List.tabulate (8, e)))
  val () = eqI (lab "fromList/length", 5, fn () => V.length (V.fromList (List.map e l5)))

  (* ---- tabulate: "the elements are defined in order of increasing index by
     applying f to the element's index. This is equivalent to the expression
     fromList (List.tabulate (n, f)). If n < 0 or maxLen < n, then the Size
     exception is raised." ---- *)
  val () = eqV (lab "tabulate/basic", [0, 2, 4, 6], fn () => V.tabulate (4, fn i => e (2 * i)))
  val () = eqV (lab "tabulate/zero", [], fn () => V.tabulate (0, e))
  val () = eqV (lab "tabulate/one", [5], fn () => V.tabulate (1, fn i => e (i + 5)))
  val () = eqInts (lab "tabulate/order", [0, 1, 2, 3],
                   fn () => let val (f, seen) = trace e in ignore (V.tabulate (4, f)); seen () end)
  val () = T.raises (lab "tabulate/Size-negative", T.isSize, fn () => V.tabulate (!minusOne, e))
  val () = eqInts (lab "tabulate/Size-before-f", [],
                   fn () => let val (f, seen) = trace (fn _ => e 0)
                            in ignore (V.tabulate (~3, f)) handle Size => (); seen () end)

  (* ---- length ---- *)
  val () = eqI (lab "length/empty", 0, fn () => V.length (empty ()))
  val () = eqI (lab "length/five", 5, fn () => V.length (v5 ()))
  val () = eqI (lab "length/tabulate", 1000, fn () => V.length (V.tabulate (1000, fn i => e (i mod 8))))

  (* ---- sub: "If i < 0 or |vec| <= i, then the Subscript exception is
     raised." ---- *)
  val () = eqI (lab "sub/first", 1, fn () => code (V.sub (v5 (), 0)))
  val () = eqI (lab "sub/middle", 3, fn () => code (V.sub (v5 (), 2)))
  val () = eqI (lab "sub/last", 5, fn () => code (V.sub (v5 (), 4)))
  val () = T.raises (lab "sub/Subscript-length", T.isSubscript, fn () => V.sub (v5 (), 5))
  val () = T.raises (lab "sub/Subscript-beyond", T.isSubscript, fn () => V.sub (v5 (), 1000))
  val () = T.raises (lab "sub/Subscript-negative", T.isSubscript, fn () => V.sub (v5 (), !minusOne))
  val () = T.raises (lab "sub/Subscript-empty", T.isSubscript, fn () => V.sub (empty (), 0))

  (* ---- update: "returns a new vector, identical to vec, except the i(th)
     element of vec is set to x. If i < 0 or |vec| <= i, then the Subscript
     exception is raised." ---- *)
  val () = eqV (lab "update/first", [7, 2, 3, 4, 5], fn () => V.update (v5 (), 0, e 7))
  val () = eqV (lab "update/middle", [1, 2, 7, 4, 5], fn () => V.update (v5 (), 2, e 7))
  val () = eqV (lab "update/last", [1, 2, 3, 4, 7], fn () => V.update (v5 (), 4, e 7))
  val () = eqV (lab "update/singleton", [0], fn () => V.update (vec [7], 0, e 0))
  val () = eqV (lab "update/argument-unchanged", l5,
                fn () => let val v = vec l5 in ignore (V.update (v, 2, e 7)); v end)
  val () = eqV (lab "update/twice", [1, 6, 3, 7, 5], fn () => V.update (V.update (v5 (), 3, e 7), 1, e 6))
  val () = T.raises (lab "update/Subscript-length", T.isSubscript, fn () => V.update (v5 (), 5, e 7))
  val () = T.raises (lab "update/Subscript-beyond", T.isSubscript, fn () => V.update (v5 (), 1000, e 7))
  val () = T.raises (lab "update/Subscript-negative", T.isSubscript, fn () => V.update (v5 (), !minusOne, e 7))
  val () = T.raises (lab "update/Subscript-empty", T.isSubscript, fn () => V.update (empty (), 0, e 7))

  (* ---- concat ---- *)
  val () = eqV (lab "concat/basic", [1, 2, 3, 4], fn () => V.concat [vec [1], empty (), vec [2, 3], vec [4]])
  val () = eqV (lab "concat/nil", [], fn () => V.concat [])
  val () = eqV (lab "concat/one", l5, fn () => V.concat [v5 ()])
  val () = eqV (lab "concat/empties", [], fn () => V.concat [empty (), empty (), empty ()])
  val () = eqV (lab "concat/same-twice", [3, 5, 7, 3, 5, 7], fn () => V.concat [v3 (), v3 ()])
  val () = eqV (lab "concat/order", [3, 5, 7, 1, 2, 3, 4, 5], fn () => V.concat [v3 (), v5 ()])

  (* ---- appi, app: "in left to right order (i.e., increasing indices)" ---- *)
  val () = eqIL (lab "appi/order", i3,
                 fn () => let val (f, seen) = codedI (trace (fn _ => ())) in V.appi f (v3 ()); seen () end)
  val () = eqIL (lab "appi/empty", [],
                 fn () => let val (f, seen) = codedI (trace (fn _ => ())) in V.appi f (empty ()); seen () end)
  val () = eqL (lab "app/order", l5,
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in V.app f (v5 ()); seen () end)
  val () = eqL (lab "app/empty", [],
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in V.app f (empty ()); seen () end)

  (* ---- mapi, map: "produce new vectors by mapping the function f from left
     to right over the argument vector". With f (i, x) = the sample
     (i + code x) mod 8 over [3, 5, 7]: 0+3, 1+5, (2+7) mod 8 = 1. ---- *)
  val () = eqV (lab "mapi/basic", [3, 6, 1], fn () => V.mapi (fn (i, x) => e ((i + code x) mod 8)) (v3 ()))
  val () = eqV (lab "mapi/index-only", [0, 1, 2], fn () => V.mapi (fn (i, _) => e i) (v3 ()))
  val () = eqV (lab "mapi/empty", [], fn () => V.mapi (fn (_, x) => x) (empty ()))
  val () = eqIL (lab "mapi/order", i3,
                 fn () => let val (f, seen) = codedI (trace (fn (_, x) => x)) in ignore (V.mapi f (v3 ())); seen () end)
  val () = eqV (lab "map/basic", [2, 3, 4, 5, 6], fn () => V.map next (v5 ()))
  val () = eqV (lab "map/wraps", [0], fn () => V.map next (vec [7]))
  val () = eqV (lab "map/empty", [], fn () => V.map next (empty ()))
  val () = eqL (lab "map/order", l5,
                fn () => let val (f, seen) = coded (trace next) in ignore (V.map f (v5 ())); seen () end)
  val () = eqV (lab "map/argument-unchanged", [3, 5, 7],
                fn () => let val v = vec [3, 5, 7] in ignore (V.map next v); v end)

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
                 fn () => V.foldli (fn (i, a, l) => (i, code a) :: l) [] (v3 ()))
  val () = eqI (lab "foldli/nonassociative", 4, fn () => V.foldli gi 0 (v3 ()))
  val () = eqI (lab "foldli/empty", 42, fn () => V.foldli gi 42 (empty ()))
  val () = eqIL (lab "foldri/conses-in-order", i3, fn () => V.foldri (fn (i, a, l) => (i, code a) :: l) [] (v3 ()))
  val () = eqI (lab "foldri/nonassociative", 46, fn () => V.foldri gi 0 (v3 ()))
  val () = eqI (lab "foldri/empty", 42, fn () => V.foldri gi 42 (empty ()))
  val () = eqL (lab "foldl/conses-reversed", [5, 4, 3, 2, 1], fn () => V.foldl (fn (a, l) => code a :: l) [] (v5 ()))
  val () = eqI (lab "foldl/nonassociative", 3, fn () => V.foldl g 0 (vec [1, 2, 3]))
  val () = eqI (lab "foldl/empty", 42, fn () => V.foldl g 42 (empty ()))
  val () = eqL (lab "foldr/conses-in-order", l5, fn () => V.foldr (fn (a, l) => code a :: l) [] (v5 ()))
  val () = eqI (lab "foldr/nonassociative", 9, fn () => V.foldr g 0 (vec [1, 2, 3]))
  val () = eqI (lab "foldr/empty", 42, fn () => V.foldr g 42 (empty ()))

  (* ---- findi, find: "from left to right (i.e., increasing indices), until a
     true value is returned"; findi "returns that index with the element" ---- *)
  fun found r = Option.map (fn (i, x) => (i, code x)) r
  val () = eqIO (lab "findi/first-match", SOME (1, 5), fn () => found (V.findi (fn (_, a) => code a > 3) (v3 ())))
  val () = eqIO (lab "findi/by-index", SOME (2, 7), fn () => found (V.findi (fn (i, _) => i = 2) (v3 ())))
  val () = eqIO (lab "findi/index-zero", SOME (0, 3), fn () => found (V.findi (fn _ => true) (v3 ())))
  val () = eqIO (lab "findi/none", NONE, fn () => found (V.findi (fn (_, a) => code a > 7) (v3 ())))
  val () = eqIO (lab "findi/empty", NONE, fn () => found (V.findi (fn _ => true) (empty ())))
  val () = eqIL (lab "findi/stops", [(0, 3), (1, 5)],
                 fn () => let val (f, seen) = codedI (trace (fn (_, a) => code a = 5)) in ignore (V.findi f (v3 ())); seen () end)
  val () = eqIL (lab "findi/order", i3,
                 fn () => let val (f, seen) = codedI (trace (fn _ => false)) in ignore (V.findi f (v3 ())); seen () end)
  val () = eqO (lab "find/first-match", SOME 2, fn () => Option.map code (V.find even (v5 ())))
  val () = eqO (lab "find/last-element", SOME 5, fn () => Option.map code (V.find (fn x => code x > 4) (v5 ())))
  val () = eqO (lab "find/none", NONE, fn () => Option.map code (V.find (fn x => code x > 5) (v5 ())))
  val () = eqO (lab "find/empty", NONE, fn () => Option.map code (V.find (fn _ => true) (empty ())))
  val () = eqL (lab "find/stops", [1, 2],
                fn () => let val (f, seen) = coded (trace even) in ignore (V.find f (v5 ())); seen () end)

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB (lab "exists/true", true, fn () => V.exists (fn x => code x = 3) (v5 ()))
  val () = eqB (lab "exists/false", false, fn () => V.exists (fn x => code x = 7) (v5 ()))
  val () = eqB (lab "exists/empty", false, fn () => V.exists (fn _ => true) (empty ()))
  val () = eqL (lab "exists/stops", [1, 2, 3],
                fn () => let val (f, seen) = coded (trace (fn x => code x = 3)) in ignore (V.exists f (v5 ())); seen () end)
  val () = eqL (lab "exists/order", l5,
                fn () => let val (f, seen) = coded (trace (fn _ => false)) in ignore (V.exists f (v5 ())); seen () end)
  val () = eqB (lab "all/true", true, fn () => V.all (fn x => code x > 0) (v5 ()))
  val () = eqB (lab "all/false", false, fn () => V.all (fn x => code x < 3) (v5 ()))
  val () = eqB (lab "all/empty", true, fn () => V.all (fn _ => false) (empty ()))
  val () = eqL (lab "all/stops", [1, 2, 3],
                fn () => let val (f, seen) = coded (trace (fn x => code x < 3)) in ignore (V.all f (v5 ())); seen () end)
  val () = eqL (lab "all/order", l5,
                fn () => let val (f, seen) = coded (trace (fn _ => true)) in ignore (V.all f (v5 ())); seen () end)

  (* ---- collate: "lexicographic comparison of the two vectors using the given
     ordering f on elements" ---- *)
  fun collate c (l, m) = V.collate c (vec l, vec m)
  val () = eqOrd (lab "collate/equal", EQUAL, fn () => collate cmp ([1, 2], [1, 2]))
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

  (* ---- maxLen: "If n < 0 or maxLen < n, then the Size exception is raised",
     so a length that tabulate accepts is at most maxLen ---- *)
  val () = eqB (lab "maxLen/covers-created-vectors", true,
                fn () => V.length (V.tabulate (1000, fn _ => e 0)) <= V.maxLen)

  (* ---- laws, on pseudo-random vectors, against lists of codes ---- *)
  fun randomList () = List.tabulate (T.range (0, 12), fn _ => T.range (0, 7))
  fun indexed l = List.tabulate (List.length l, fn j => (j, List.nth (l, j)))
  val () = T.seed 31
  val () = T.repeat (25, fn i =>
    let
      val n = "-" ^ Int.toString i
      val l = randomList ()
      val m = randomList ()
      fun v () = vec l
      fun w () = vec m
      val len = List.length l
      val k = T.range (0, len)            (* 0 <= k <= len *)
      val x = T.range (0, 7)
      val fi = fn (j, a) => (3 * j + a) mod 8
      val hi = fn (j, a, b) => j * a - 2 * b
      val h = fn (a, b) => a - 2 * b
      val pi = fn (j, a) => (j + a) mod 3 = 0
      val p = fn a => a mod 3 = 0
    in
      eqV (lab "fromList/round-trip" ^ n, l, v);
      eqI (lab "length/model" ^ n, len, fn () => V.length (v ()));
      eqV (lab "tabulate/model" ^ n, l, fn () => V.tabulate (len, fn j => e (List.nth (l, j))));
      (if k < len
       then (eqI (lab "sub/model" ^ n, List.nth (l, k), fn () => code (V.sub (v (), k)));
             eqV (lab "update/model" ^ n, List.take (l, k) @ [x] @ List.drop (l, k + 1),
                  fn () => V.update (v (), k, e x)))
       else (T.raises (lab "sub/model" ^ n, T.isSubscript, fn () => V.sub (v (), k));
             T.raises (lab "update/model" ^ n, T.isSubscript, fn () => V.update (v (), k, e x))));
      eqV (lab "concat/model" ^ n, l @ m @ l, fn () => V.concat [v (), w (), v ()]);
      eqIL (lab "appi/model" ^ n, indexed l,
            fn () => let val (f, seen) = codedI (trace (fn _ => ())) in V.appi f (v ()); seen () end);
      eqL (lab "app/model" ^ n, l,
           fn () => let val (f, seen) = coded (trace (fn _ => ())) in V.app f (v ()); seen () end);
      eqV (lab "mapi/model" ^ n, List.map fi (indexed l), fn () => V.mapi (fn (j, a) => e (fi (j, code a))) (v ()));
      eqV (lab "map/model" ^ n, List.map (fn a => (a + 1) mod 8) l, fn () => V.map next (v ()));
      eqI (lab "foldli/model" ^ n, List.foldl (fn ((j, a), b) => hi (j, a, b)) 1 (indexed l),
           fn () => V.foldli (fn (j, a, b) => hi (j, code a, b)) 1 (v ()));
      eqI (lab "foldri/model" ^ n, List.foldr (fn ((j, a), b) => hi (j, a, b)) 1 (indexed l),
           fn () => V.foldri (fn (j, a, b) => hi (j, code a, b)) 1 (v ()));
      eqI (lab "foldl/model" ^ n, List.foldl h 1 l, fn () => V.foldl (fn (a, b) => h (code a, b)) 1 (v ()));
      eqI (lab "foldr/model" ^ n, List.foldr h 1 l, fn () => V.foldr (fn (a, b) => h (code a, b)) 1 (v ()));
      eqIO (lab "findi/model" ^ n, List.find pi (indexed l), fn () => found (V.findi (fn (j, a) => pi (j, code a)) (v ())));
      eqO (lab "find/model" ^ n, List.find p l, fn () => Option.map code (V.find (p o code) (v ())));
      eqB (lab "exists/model" ^ n, List.exists p l, fn () => V.exists (p o code) (v ()));
      eqB (lab "all/model" ^ n, List.all (not o p) l, fn () => V.all (not o p o code) (v ()));
      eqB (lab "all/de-morgan" ^ n, true, fn () => V.all (p o code) (v ()) = not (V.exists (not o p o code) (v ())));
      eqOrd (lab "collate/model" ^ n, List.collate Int.compare (l, m), fn () => V.collate cmp (v (), w ()));
      eqOrd (lab "collate/reflexive" ^ n, EQUAL, fn () => V.collate cmp (v (), vec l))
    end)

  (* ---- long vectors: no stack or quadratic trouble ---- *)
  fun big () = V.tabulate (100000, fn i => e (i mod 8))
  val () = eqI (lab "length/long", 100000, fn () => V.length (big ()))
  val () = eqI (lab "sub/long", 7, fn () => code (V.sub (big (), 99999)))
  val () = eqI (lab "fromList/long", 100000, fn () => V.length (V.fromList (List.tabulate (100000, fn i => e (i mod 8)))))
  val () = eqI (lab "update/long", 0, fn () => code (V.sub (V.update (big (), 50001, e 0), 50001)))
  val () = eqI (lab "map/long", 0, fn () => code (V.sub (V.map next (big ()), 99999)))
  val () = eqI (lab "mapi/long", 99999 mod 8, fn () => code (V.sub (V.mapi (fn (i, _) => e (i mod 8)) (big ()), 99999)))
  val () = eqI (lab "foldl/long", 12500, fn () => V.foldl (fn (a, k) => if code a = 7 then k + 1 else k) 0 (big ()))
  val () = eqI (lab "foldr/long", 100000, fn () => List.length (V.foldr (op ::) [] (big ())))
  val () = eqB (lab "all/long", true, fn () => V.all (fn a => code a >= 0) (big ()))
  val () = eqI (lab "concat/long", 200000, fn () => V.length (V.concat [big (), big ()]))
  val () = eqI (lab "concat/many", 100000,
                fn () => V.length (V.concat (List.tabulate (1000, fn _ => V.tabulate (100, fn _ => e 1)))))
  val () = eqOrd (lab "collate/long", EQUAL, fn () => V.collate cmp (big (), V.tabulate (100000, fn i => e (i mod 8))))
end

(* "The maximum length of vectors supported by this implementation. Attempts to
   create larger vectors will result in the Size exception being raised."
   maxLen + 1 exists unless maxLen is Int.maxInt. The function that is
   tabulated gives up after 1000 applications, so that an implementation that
   applies it before it looks at the length fails the check instead of running
   out of memory. concat can only be given more than maxLen elements where
   maxLen is small: 1024 times a vector of maxLen div 1024 + 1 elements. (For
   fromList that takes a list of maxLen + 1 elements, which is too much
   everywhere.) *)
functor TestMonoVectorSizeFn (structure V : SPEC_MONO_VECTOR
                              val name : string
                              val elem : V.elem) =
struct
  fun lab s = name ^ "." ^ s

  val aboveMaxLen : int option =
    case Int.maxInt of
      NONE => SOME (V.maxLen + 1)
    | SOME most => if V.maxLen < most then SOME (V.maxLen + 1) else NONE
  val () =
    case aboveMaxLen of
      NONE => ()
    | SOME n =>
        T.raises (lab "tabulate/Size-above-maxLen", T.isSize,
                  fn () => V.tabulate (n, fn i => if i < 1000 then elem else raise Fail "f applied before Size"))
  val () =
    if V.maxLen <= 16777216
    then T.raises (lab "concat/Size-above-maxLen", T.isSize,
                   fn () => let val part = V.tabulate (V.maxLen div 1024 + 1, fn _ => elem)
                            in V.concat (List.tabulate (1024, fn _ => part)) end)
    else ()
end
