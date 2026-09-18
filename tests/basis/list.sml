(* requires: List *)
(* The List structure (signature LIST). Expected values follow the text of
   https://smlfamily.github.io/Basis/list.html. *)
structure TestList =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val eqLL = T.eq (T.list (T.list T.int))
  val eqO = T.eq (T.option T.int)
  val eqOrd = T.eq T.order
  val eqS = T.eq T.string

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : int -> 'a) : (int -> 'a) * (unit -> int list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end

  val l5 = [1, 2, 3, 4, 5]

  (* ---- null, length, @ ---- *)
  val () = eqB ("List.null/nil", true, fn () => List.null ([] : int list))
  val () = eqB ("List.null/cons", false, fn () => List.null [1])
  val () = eqI ("List.length/nil", 0, fn () => List.length ([] : int list))
  val () = eqI ("List.length/five", 5, fn () => List.length l5)
  val () = eqL ("List.@/basic", [1, 2, 3, 4], fn () => List.@ ([1, 2], [3, 4]))
  val () = eqL ("List.@/nil-left", [1], fn () => List.@ ([], [1]))
  val () = eqL ("List.@/nil-right", [1], fn () => List.@ ([1], []))
  val () = eqL ("List.@/infix", [1, 2, 3], fn () => [1] @ [2] @ [3])
  val () = eqL ("List.@/right-assoc", [1, 2, 3], fn () => 1 :: [2] @ [3])

  (* ---- hd, tl, last, getItem ---- *)
  val () = eqI ("List.hd/basic", 1, fn () => List.hd l5)
  val () = T.raises ("List.hd/Empty", T.isEmpty, fn () => List.hd ([] : int list))
  val () = eqL ("List.tl/basic", [2, 3, 4, 5], fn () => List.tl l5)
  val () = eqL ("List.tl/singleton", [], fn () => List.tl [1])
  val () = T.raises ("List.tl/Empty", T.isEmpty, fn () => List.tl ([] : int list))
  val () = eqI ("List.last/basic", 5, fn () => List.last l5)
  val () = eqI ("List.last/singleton", 7, fn () => List.last [7])
  val () = T.raises ("List.last/Empty", T.isEmpty, fn () => List.last ([] : int list))
  val () = T.eq (T.option (T.pair (T.int, T.list T.int)))
             ("List.getItem/cons", SOME (1, [2, 3]), fn () => List.getItem [1, 2, 3])
  val () = T.eq (T.option (T.pair (T.int, T.list T.int)))
             ("List.getItem/nil", NONE, fn () => List.getItem [])

  (* ---- nth, take, drop ---- *)
  val () = eqI ("List.nth/first", 1, fn () => List.nth (l5, 0))
  val () = eqI ("List.nth/last", 5, fn () => List.nth (l5, 4))
  val () = T.raises ("List.nth/Subscript-length", T.isSubscript, fn () => List.nth (l5, 5))
  val () = T.raises ("List.nth/Subscript-negative", T.isSubscript, fn () => List.nth (l5, ~1))
  val () = T.raises ("List.nth/Subscript-nil", T.isSubscript, fn () => List.nth ([] : int list, 0))
  val () = eqL ("List.take/zero", [], fn () => List.take (l5, 0))
  val () = eqL ("List.take/some", [1, 2], fn () => List.take (l5, 2))
  val () = eqL ("List.take/all", l5, fn () => List.take (l5, 5))
  val () = T.raises ("List.take/Subscript-long", T.isSubscript, fn () => List.take (l5, 6))
  val () = T.raises ("List.take/Subscript-negative", T.isSubscript, fn () => List.take (l5, ~1))
  val () = eqL ("List.drop/zero", l5, fn () => List.drop (l5, 0))
  val () = eqL ("List.drop/some", [3, 4, 5], fn () => List.drop (l5, 2))
  val () = eqL ("List.drop/all", [], fn () => List.drop (l5, 5))
  val () = T.raises ("List.drop/Subscript-long", T.isSubscript, fn () => List.drop (l5, 6))
  val () = T.raises ("List.drop/Subscript-negative", T.isSubscript, fn () => List.drop (l5, ~1))

  (* ---- rev, concat, revAppend ---- *)
  val () = eqL ("List.rev/basic", [5, 4, 3, 2, 1], fn () => List.rev l5)
  val () = eqL ("List.rev/nil", [], fn () => List.rev [])
  val () = eqL ("List.concat/basic", [1, 2, 3, 4], fn () => List.concat [[1], [], [2, 3], [4]])
  val () = eqL ("List.concat/nil", [], fn () => List.concat [])
  val () = eqL ("List.revAppend/basic", [3, 2, 1, 4, 5], fn () => List.revAppend ([1, 2, 3], [4, 5]))
  val () = eqL ("List.revAppend/nil-left", [4, 5], fn () => List.revAppend ([], [4, 5]))
  val () = eqL ("List.revAppend/nil-right", [2, 1], fn () => List.revAppend ([1, 2], []))

  (* ---- app, map, mapPartial: applied from left to right ---- *)
  val () = eqL ("List.app/order", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn _ => ()) in List.app f [1, 2, 3]; seen () end)
  val () = eqL ("List.map/basic", [2, 4, 6], fn () => List.map (fn x => 2 * x) [1, 2, 3])
  val () = eqL ("List.map/nil", [], fn () => List.map (fn x => 2 * x) [])
  val () = eqL ("List.map/order", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn x => x) in ignore (List.map f [1, 2, 3]); seen () end)
  val () = eqL ("List.mapPartial/basic", [20, 40],
                fn () => List.mapPartial (fn x => if x mod 2 = 0 then SOME (10 * x) else NONE) l5)
  val () = eqL ("List.mapPartial/order", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn _ => NONE : int option)
                         in ignore (List.mapPartial f [1, 2, 3]); seen () end)

  (* ---- find, filter, partition ---- *)
  val () = eqO ("List.find/first-match", SOME 2, fn () => List.find (fn x => x mod 2 = 0) l5)
  val () = eqO ("List.find/none", NONE, fn () => List.find (fn x => x > 9) l5)
  val () = eqL ("List.find/stops", [1, 2],
                fn () => let val (f, seen) = trace (fn x => x = 2) in ignore (List.find f l5); seen () end)
  val () = eqL ("List.filter/basic", [2, 4], fn () => List.filter (fn x => x mod 2 = 0) l5)
  val () = eqL ("List.filter/order", l5,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (List.filter f l5); seen () end)
  val () = T.eq (T.pair (T.list T.int, T.list T.int))
             ("List.partition/basic", ([2, 4], [1, 3, 5]), fn () => List.partition (fn x => x mod 2 = 0) l5)
  val () = eqL ("List.partition/order", l5,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (List.partition f l5); seen () end)

  (* ---- foldl, foldr ---- *)
  val () = eqL ("List.foldl/conses-reversed", [3, 2, 1], fn () => List.foldl (op ::) [] [1, 2, 3])
  val () = eqL ("List.foldr/conses-in-order", [1, 2, 3], fn () => List.foldr (op ::) [] [1, 2, 3])
  val () = eqI ("List.foldl/nonassociative", 2, fn () => List.foldl (op -) 0 [1, 2, 3])   (* 3-(2-(1-0)) *)
  val () = eqI ("List.foldr/nonassociative", 2, fn () => List.foldr (op -) 0 [1, 2, 3])   (* 1-(2-(3-0)) *)
  val () = eqI ("List.foldl/nil", 42, fn () => List.foldl (op +) 42 [])
  val () = eqI ("List.foldr/nil", 42, fn () => List.foldr (op +) 42 [])

  (* ---- exists, all: stop at the first deciding element ---- *)
  val () = eqB ("List.exists/true", true, fn () => List.exists (fn x => x = 3) l5)
  val () = eqB ("List.exists/false", false, fn () => List.exists (fn x => x = 9) l5)
  val () = eqB ("List.exists/nil", false, fn () => List.exists (fn _ => true) ([] : int list))
  val () = eqL ("List.exists/stops", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn x => x = 3) in ignore (List.exists f l5); seen () end)
  val () = eqB ("List.all/true", true, fn () => List.all (fn x => x > 0) l5)
  val () = eqB ("List.all/false", false, fn () => List.all (fn x => x < 3) l5)
  val () = eqB ("List.all/nil", true, fn () => List.all (fn _ => false) ([] : int list))
  val () = eqL ("List.all/stops", [1, 2, 3],
                fn () => let val (f, seen) = trace (fn x => x < 3) in ignore (List.all f l5); seen () end)

  (* ---- tabulate ---- *)
  val () = eqL ("List.tabulate/basic", [0, 1, 4, 9], fn () => List.tabulate (4, fn i => i * i))
  val () = eqL ("List.tabulate/zero", [], fn () => List.tabulate (0, fn i => i))
  val () = eqL ("List.tabulate/order", [0, 1, 2],
                fn () => let val (f, seen) = trace (fn i => i) in ignore (List.tabulate (3, f)); seen () end)
  val () = T.raises ("List.tabulate/Size", T.isSize, fn () => List.tabulate (~1, fn i => i))

  (* ---- collate: lexicographic ---- *)
  val () = eqOrd ("List.collate/equal", EQUAL, fn () => List.collate Int.compare ([1, 2], [1, 2]))
  val () = eqOrd ("List.collate/nil-nil", EQUAL, fn () => List.collate Int.compare ([], []))
  val () = eqOrd ("List.collate/prefix-less", LESS, fn () => List.collate Int.compare ([1], [1, 2]))
  val () = eqOrd ("List.collate/prefix-greater", GREATER, fn () => List.collate Int.compare ([1, 2], [1]))
  val () = eqOrd ("List.collate/first-difference", GREATER, fn () => List.collate Int.compare ([1, 3], [1, 2, 9]))
  val () = eqOrd ("List.collate/less", LESS, fn () => List.collate Int.compare ([0, 9], [1]))

  (* ---- the exception and the datatype are the top-level ones ---- *)
  val () = T.raises ("List.Empty/same-as-toplevel", fn List.Empty => true | _ => false,
                     fn () => hd ([] : int list))
  val () = eqL ("List.list/constructors", [1, 2], fn () => List.:: (1, List.:: (2, List.nil)))

  (* ---- laws, on pseudo-random lists ---- *)
  fun randomList () = List.tabulate (T.range (0, 12), fn _ => T.range (~50, 50))
  val () = T.seed 1
  val () = T.repeat (50, fn i =>
    let
      val n = Int.toString i
      val l = randomList ()
      val m = randomList ()
      val k = T.range (0, List.length l)
      val even = fn x => x mod 2 = 0
    in
      eqL ("List.rev/involution-" ^ n, l, fn () => List.rev (List.rev l));
      eqI ("List.length/append-" ^ n, List.length l + List.length m, fn () => List.length (l @ m));
      eqL ("List.take/take-drop-" ^ n, l, fn () => List.take (l, k) @ List.drop (l, k));
      eqL ("List.revAppend/law-" ^ n, List.rev l @ m, fn () => List.revAppend (l, m));
      eqL ("List.foldl/rev-" ^ n, List.rev l, fn () => List.foldl (op ::) [] l);
      eqL ("List.concat/append-" ^ n, l @ m @ l, fn () => List.concat [l, m, l]);
      eqLL ("List.partition/filter-" ^ n, [List.filter even l, List.filter (not o even) l],
            fn () => let val (a, b) = List.partition even l in [a, b] end);
      eqL ("List.mapPartial/map-filter-" ^ n, List.map (fn x => x + 1) (List.filter even l),
           fn () => List.mapPartial (fn x => if even x then SOME (x + 1) else NONE) l);
      eqB ("List.exists/de-morgan-" ^ n, not (List.all (not o even) l), fn () => List.exists even l);
      eqL ("List.tabulate/nth-" ^ n, l, fn () => List.tabulate (List.length l, fn j => List.nth (l, j)));
      eqOrd ("List.collate/reflexive-" ^ n, EQUAL, fn () => List.collate Int.compare (l, l))
    end)

  (* ---- long lists: no stack or quadratic trouble ---- *)
  val big = List.tabulate (200000, fn i => i)
  val () = eqI ("List.length/long", 200000, fn () => List.length big)
  val () = eqI ("List.foldl/long", 199999, fn () => List.foldl Int.max 0 big)
  val () = eqI ("List.foldr/long", 199999, fn () => List.foldr Int.max 0 big)
  val () = eqI ("List.map/long", 200000, fn () => List.length (List.map (fn x => x + 1) big))
  val () = eqI ("List.@/long", 400000, fn () => List.length (big @ big))
  val () = eqI ("List.rev/long", 199999, fn () => List.hd (List.rev big))
  val () = eqI ("List.filter/long", 100000, fn () => List.length (List.filter (fn x => x mod 2 = 0) big))
  val () = eqS ("List.last/long", "199999", fn () => Int.toString (List.last big))
end
