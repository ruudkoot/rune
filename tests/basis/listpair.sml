(* requires: ListPair List *)
(* The ListPair structure (signature LIST_PAIR). Expected values follow the
   text of https://smlfamily.github.io/Basis/list-pair.html. *)
structure TestListPair =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val eqP = T.eq (T.list (T.pair (T.int, T.int)))
  val eqPO = T.eq (T.option (T.list (T.pair (T.int, T.int))))
  val eqLO = T.eq (T.option (T.list T.int))
  val eqIO = T.eq (T.option T.int)
  val eqU = T.eq (T.pair (T.list T.int, T.list T.int))

  val isUnequal = fn ListPair.UnequalLengths => true | _ => false

  (* trace f: f, and the pairs it has been applied to so far, in order. *)
  fun trace (f : int * int -> 'a) : (int * int -> 'a) * (unit -> (int * int) list) =
    let val log = ref []
    in (fn p => (log := p :: !log; f p), fn () => List.rev (!log)) end

  (* trace3 f: the same for the functions that are folded. *)
  fun trace3 (f : int * int * 'c -> 'c) : (int * int * 'c -> 'c) * (unit -> (int * int) list) =
    let val log = ref []
    in (fn (a, b, c) => (log := (a, b) :: !log; f (a, b, c)), fn () => List.rev (!log)) end

  (* guarded f: SOME (f ()), or NONE when f raises UnequalLengths. *)
  fun guarded (f : unit -> 'a) : 'a option = SOME (f ()) handle ListPair.UnequalLengths => NONE

  val a3 = [1, 2, 3]
  val b3 = [10, 20, 30]
  val b2 = [10, 20]
  val z3 = [(1, 10), (2, 20), (3, 30)]
  val z2 = [(1, 10), (2, 20)]
  fun cons (a, b, c) = (a, b) :: c
  fun mix (a, b, c) = a + b - 2 * c

  (* ---- UnequalLengths ---- *)
  val () = T.raises ("ListPair.UnequalLengths/raised-by-zipEq", isUnequal, fn () => ListPair.zipEq (a3, b2))
  val () = eqB ("ListPair.UnequalLengths/can-be-raised-and-handled", true,
                fn () => (raise ListPair.UnequalLengths) handle ListPair.UnequalLengths => true)
  val () = eqB ("ListPair.UnequalLengths/differs-from-Subscript-and-Size", false,
                fn () => (raise ListPair.UnequalLengths) handle Subscript => true | Size => true | _ => false)

  (* ---- zip, zipEq: "If the lists are of unequal lengths, zip ignores the
     excess elements from the tail of the longer one, while zipEq raises the
     exception UnequalLengths." ---- *)
  val () = eqP ("ListPair.zip/basic", z3, fn () => ListPair.zip (a3, b3))
  val () = eqP ("ListPair.zip/nil-nil", [], fn () => ListPair.zip ([], []))
  val () = eqP ("ListPair.zip/singleton", [(7, 8)], fn () => ListPair.zip ([7], [8]))
  val () = eqP ("ListPair.zip/left-longer", z2, fn () => ListPair.zip (a3, b2))
  val () = eqP ("ListPair.zip/right-longer", z2, fn () => ListPair.zip ([1, 2], b3))
  val () = eqP ("ListPair.zip/nil-left", [], fn () => ListPair.zip ([], b3))
  val () = eqP ("ListPair.zip/nil-right", [], fn () => ListPair.zip (a3, []))
  val () = T.eq (T.list (T.pair (T.int, T.string)))
             ("ListPair.zip/two-types", [(1, "a"), (2, "b")], fn () => ListPair.zip ([1, 2], ["a", "b"]))
  val () = eqP ("ListPair.zipEq/basic", z3, fn () => ListPair.zipEq (a3, b3))
  val () = eqP ("ListPair.zipEq/nil-nil", [], fn () => ListPair.zipEq ([], []))
  val () = eqP ("ListPair.zipEq/singleton", [(7, 8)], fn () => ListPair.zipEq ([7], [8]))
  val () = T.raises ("ListPair.zipEq/UnequalLengths-left-longer", isUnequal, fn () => ListPair.zipEq (a3, b2))
  val () = T.raises ("ListPair.zipEq/UnequalLengths-right-longer", isUnequal, fn () => ListPair.zipEq ([1, 2], b3))
  val () = T.raises ("ListPair.zipEq/UnequalLengths-nil-left", isUnequal, fn () => ListPair.zipEq ([], [1]))
  val () = T.raises ("ListPair.zipEq/UnequalLengths-nil-right", isUnequal, fn () => ListPair.zipEq ([1], []))

  (* ---- unzip: "the inverse of zip for equal length lists" ---- *)
  val () = eqU ("ListPair.unzip/basic", (a3, b3), fn () => ListPair.unzip z3)
  val () = eqU ("ListPair.unzip/nil", ([], []), fn () => ListPair.unzip [])
  val () = eqU ("ListPair.unzip/singleton", ([7], [8]), fn () => ListPair.unzip [(7, 8)])
  val () = T.eq (T.pair (T.list T.int, T.list T.string))
             ("ListPair.unzip/two-types", ([1, 2], ["a", "b"]), fn () => ListPair.unzip [(1, "a"), (2, "b")])
  val () = eqU ("ListPair.unzip/inverse-of-zip", (a3, b3), fn () => ListPair.unzip (ListPair.zip (a3, b3)))
  val () = eqP ("ListPair.unzip/zip-is-its-inverse", z3, fn () => ListPair.zip (ListPair.unzip z3))

  (* ---- app, appEq: "apply the function f to the list of pairs of elements
     generated from left to right" ---- *)
  val () = eqP ("ListPair.app/order", z3,
                fn () => let val (f, seen) = trace (fn _ => ()) in ListPair.app f (a3, b3); seen () end)
  val () = eqP ("ListPair.app/nil-nil", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in ListPair.app f ([], []); seen () end)
  val () = eqP ("ListPair.app/left-longer", z2,
                fn () => let val (f, seen) = trace (fn _ => ()) in ListPair.app f (a3, b2); seen () end)
  val () = eqP ("ListPair.app/right-longer", z2,
                fn () => let val (f, seen) = trace (fn _ => ()) in ListPair.app f ([1, 2], b3); seen () end)
  val () = eqP ("ListPair.app/nil-right", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in ListPair.app f (a3, []); seen () end)
  val () = eqP ("ListPair.appEq/order", z3,
                fn () => let val (f, seen) = trace (fn _ => ()) in ListPair.appEq f (a3, b3); seen () end)
  val () = eqP ("ListPair.appEq/nil-nil", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in ListPair.appEq f ([], []); seen () end)
  val () = T.raises ("ListPair.appEq/UnequalLengths-left-longer", isUnequal,
                     fn () => ListPair.appEq (fn _ => ()) (a3, b2))
  val () = T.raises ("ListPair.appEq/UnequalLengths-right-longer", isUnequal,
                     fn () => ListPair.appEq (fn _ => ()) ([1, 2], b3))
  val () = T.raises ("ListPair.appEq/UnequalLengths-nil-left", isUnequal,
                     fn () => ListPair.appEq (fn _ => ()) ([], [1]))
  (* Discussion: "a function requiring equal length arguments should determine
     this lazily, i.e., it should act as though the lists have equal length and
     invoke the user-supplied function argument, but raise the exception if it
     arrives at the end of one list before the end of the other." *)
  val () = eqP ("ListPair.appEq/applies-before-raising", z2,
                fn () => let val (f, seen) = trace (fn _ => ())
                         in ListPair.appEq f (a3, b2) handle ListPair.UnequalLengths => (); seen () end)

  (* ---- map, mapEq ---- *)
  val () = eqL ("ListPair.map/basic", [11, 22, 33], fn () => ListPair.map (op +) (a3, b3))
  val () = eqL ("ListPair.map/argument-order", [~9, ~18, ~27], fn () => ListPair.map (op -) (a3, b3))
  val () = eqL ("ListPair.map/nil-nil", [], fn () => ListPair.map (op +) ([], []))
  val () = eqL ("ListPair.map/left-longer", [11, 22], fn () => ListPair.map (op +) (a3, b2))
  val () = eqL ("ListPair.map/right-longer", [11, 22], fn () => ListPair.map (op +) ([1, 2], b3))
  val () = eqL ("ListPair.map/nil-left", [], fn () => ListPair.map (op +) ([], b3))
  val () = eqP ("ListPair.map/order", z3,
                fn () => let val (f, seen) = trace (fn _ => 0) in ignore (ListPair.map f (a3, b3)); seen () end)
  val () = T.eq (T.list T.string)
             ("ListPair.map/three-types", ["1a", "2b"],
              fn () => ListPair.map (fn (i, s) => Int.toString i ^ s) ([1, 2], ["a", "b"]))
  val () = eqL ("ListPair.mapEq/basic", [11, 22, 33], fn () => ListPair.mapEq (op +) (a3, b3))
  val () = eqL ("ListPair.mapEq/nil-nil", [], fn () => ListPair.mapEq (op +) ([], []))
  val () = eqP ("ListPair.mapEq/order", z3,
                fn () => let val (f, seen) = trace (fn _ => 0) in ignore (ListPair.mapEq f (a3, b3)); seen () end)
  val () = T.raises ("ListPair.mapEq/UnequalLengths-left-longer", isUnequal, fn () => ListPair.mapEq (op +) (a3, b2))
  val () = T.raises ("ListPair.mapEq/UnequalLengths-right-longer", isUnequal,
                     fn () => ListPair.mapEq (op +) ([1, 2], b3))
  val () = T.raises ("ListPair.mapEq/UnequalLengths-nil-right", isUnequal, fn () => ListPair.mapEq (op +) ([1], []))
  val () = eqP ("ListPair.mapEq/applies-before-raising", z2,
                fn () => let val (f, seen) = trace (fn _ => 0)
                         in ignore (ListPair.mapEq f (a3, b2)) handle ListPair.UnequalLengths => (); seen () end)

  (* ---- foldl, foldr, foldlEq, foldrEq: "equivalent to
     List.foldl f' init (zip (l1, l2))" and so on, "where f' is
     fn ((a,b),c) => f(a,b,c)".
     mix: foldl gives 1+4-0 = 5, 2+5-10 = ~3, 3+6+6 = 15;
          foldr gives 3+6-0 = 9, 2+5-18 = ~11, 1+4+22 = 27. ---- *)
  val () = eqP ("ListPair.foldl/conses-reversed", [(3, 30), (2, 20), (1, 10)], fn () => ListPair.foldl cons [] (a3, b3))
  val () = eqI ("ListPair.foldl/nonassociative", 15, fn () => ListPair.foldl mix 0 (a3, [4, 5, 6]))
  val () = eqI ("ListPair.foldl/nil-nil", 42, fn () => ListPair.foldl mix 42 ([], []))
  val () = eqP ("ListPair.foldl/left-longer", [(2, 20), (1, 10)], fn () => ListPair.foldl cons [] (a3, b2))
  val () = eqP ("ListPair.foldl/right-longer", [(2, 20), (1, 10)], fn () => ListPair.foldl cons [] ([1, 2], b3))
  val () = eqI ("ListPair.foldl/nil-right", 42, fn () => ListPair.foldl mix 42 (a3, []))
  val () = eqP ("ListPair.foldl/order", z3,
                fn () => let val (f, seen) = trace3 mix in ignore (ListPair.foldl f 0 (a3, b3)); seen () end)
  val () = eqP ("ListPair.foldr/conses-in-order", z3, fn () => ListPair.foldr cons [] (a3, b3))
  val () = eqI ("ListPair.foldr/nonassociative", 27, fn () => ListPair.foldr mix 0 (a3, [4, 5, 6]))
  val () = eqI ("ListPair.foldr/nil-nil", 42, fn () => ListPair.foldr mix 42 ([], []))
  val () = eqP ("ListPair.foldr/left-longer", z2, fn () => ListPair.foldr cons [] (a3, b2))
  val () = eqP ("ListPair.foldr/right-longer", z2, fn () => ListPair.foldr cons [] ([1, 2], b3))
  val () = eqI ("ListPair.foldr/nil-left", 42, fn () => ListPair.foldr mix 42 ([], b3))
  val () = eqP ("ListPair.foldr/order", [(3, 30), (2, 20), (1, 10)],
                fn () => let val (f, seen) = trace3 mix in ignore (ListPair.foldr f 0 (a3, b3)); seen () end)
  val () = eqP ("ListPair.foldr/order-left-longer", [(2, 20), (1, 10)],
                fn () => let val (f, seen) = trace3 mix in ignore (ListPair.foldr f 0 (a3, b2)); seen () end)
  val () = eqP ("ListPair.foldlEq/conses-reversed", [(3, 30), (2, 20), (1, 10)],
                fn () => ListPair.foldlEq cons [] (a3, b3))
  val () = eqI ("ListPair.foldlEq/nonassociative", 15, fn () => ListPair.foldlEq mix 0 (a3, [4, 5, 6]))
  val () = eqI ("ListPair.foldlEq/nil-nil", 42, fn () => ListPair.foldlEq mix 42 ([], []))
  val () = eqP ("ListPair.foldlEq/order", z3,
                fn () => let val (f, seen) = trace3 mix in ignore (ListPair.foldlEq f 0 (a3, b3)); seen () end)
  val () = T.raises ("ListPair.foldlEq/UnequalLengths-left-longer", isUnequal,
                     fn () => ListPair.foldlEq mix 0 (a3, b2))
  val () = T.raises ("ListPair.foldlEq/UnequalLengths-right-longer", isUnequal,
                     fn () => ListPair.foldlEq mix 0 ([1, 2], b3))
  val () = T.raises ("ListPair.foldlEq/UnequalLengths-nil-left", isUnequal, fn () => ListPair.foldlEq mix 0 ([], [1]))
  val () = eqP ("ListPair.foldlEq/applies-before-raising", z2,
                fn () => let val (f, seen) = trace3 mix
                         in ignore (ListPair.foldlEq f 0 (a3, b2)) handle ListPair.UnequalLengths => (); seen () end)
  val () = eqP ("ListPair.foldrEq/conses-in-order", z3, fn () => ListPair.foldrEq cons [] (a3, b3))
  val () = eqI ("ListPair.foldrEq/nonassociative", 27, fn () => ListPair.foldrEq mix 0 (a3, [4, 5, 6]))
  val () = eqI ("ListPair.foldrEq/nil-nil", 42, fn () => ListPair.foldrEq mix 42 ([], []))
  val () = eqP ("ListPair.foldrEq/order", [(3, 30), (2, 20), (1, 10)],
                fn () => let val (f, seen) = trace3 mix in ignore (ListPair.foldrEq f 0 (a3, b3)); seen () end)
  val () = T.raises ("ListPair.foldrEq/UnequalLengths-left-longer", isUnequal,
                     fn () => ListPair.foldrEq mix 0 (a3, b2))
  val () = T.raises ("ListPair.foldrEq/UnequalLengths-right-longer", isUnequal,
                     fn () => ListPair.foldrEq mix 0 ([1, 2], b3))
  val () = T.raises ("ListPair.foldrEq/UnequalLengths-nil-right", isUnequal, fn () => ListPair.foldrEq mix 0 ([1], []))
  (* Folding from the right applies f to the last pair first, so the end of
     one of the lists is reached, and the exception raised, before f is applied
     at all. *)
  val () = eqP ("ListPair.foldrEq/raises-before-applying", [],
                fn () => let val (f, seen) = trace3 mix
                         in ignore (ListPair.foldrEq f 0 (a3, b2)) handle ListPair.UnequalLengths => (); seen () end)

  (* ---- all, exists: "short-circuit testing of a predicate over a pair of
     lists", equivalent to List.all f (zip (l1, l2)) and
     List.exists f (zip (l1, l2)) ---- *)
  val () = eqB ("ListPair.all/true", true, fn () => ListPair.all (op <) (a3, b3))
  val () = eqB ("ListPair.all/false", false, fn () => ListPair.all (fn (a, _) => a < 3) (a3, b3))
  val () = eqB ("ListPair.all/nil-nil", true, fn () => ListPair.all (fn _ => false) ([] : int list, [] : int list))
  val () = eqB ("ListPair.all/nil-right", true, fn () => ListPair.all (fn _ => false) (a3, [] : int list))
  val () = eqB ("ListPair.all/excess-ignored", true, fn () => ListPair.all (fn (a, _) => a < 3) (a3, b2))
  val () = eqP ("ListPair.all/stops", z2,
                fn () => let val (f, seen) = trace (fn (a, _) => a < 2) in ignore (ListPair.all f (a3, b3)); seen () end)
  val () = eqP ("ListPair.all/order", z3,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (ListPair.all f (a3, b3)); seen () end)
  val () = eqB ("ListPair.exists/true", true, fn () => ListPair.exists (fn (a, b) => a + b = 22) (a3, b3))
  val () = eqB ("ListPair.exists/false", false, fn () => ListPair.exists (op >) (a3, b3))
  val () = eqB ("ListPair.exists/nil-nil", false, fn () => ListPair.exists (fn _ => true) ([] : int list, [] : int list))
  val () = eqB ("ListPair.exists/nil-left", false, fn () => ListPair.exists (fn _ => true) ([] : int list, b3))
  val () = eqB ("ListPair.exists/excess-ignored", false, fn () => ListPair.exists (fn (a, _) => a = 3) (a3, b2))
  val () = eqP ("ListPair.exists/stops", z2,
                fn () => let val (f, seen) = trace (fn (a, _) => a = 2) in ignore (ListPair.exists f (a3, b3)); seen () end)
  val () = eqP ("ListPair.exists/order", z3,
                fn () => let val (f, seen) = trace (fn _ => false) in ignore (ListPair.exists f (a3, b3)); seen () end)

  (* ---- allEq: "returns true if l1 and l2 have equal length and all pairs of
     elements satisfy the predicate f"; it never raises UnequalLengths ---- *)
  val () = eqB ("ListPair.allEq/true", true, fn () => ListPair.allEq (op <) (a3, b3))
  val () = eqB ("ListPair.allEq/false", false, fn () => ListPair.allEq (fn (a, _) => a < 3) (a3, b3))
  val () = eqB ("ListPair.allEq/nil-nil", true, fn () => ListPair.allEq (fn _ => false) ([] : int list, [] : int list))
  val () = eqB ("ListPair.allEq/left-longer", false, fn () => ListPair.allEq (fn _ => true) (a3, b2))
  val () = eqB ("ListPair.allEq/right-longer", false, fn () => ListPair.allEq (fn _ => true) ([1, 2], b3))
  val () = eqB ("ListPair.allEq/nil-left", false, fn () => ListPair.allEq (fn _ => true) ([] : int list, [1]))
  val () = eqB ("ListPair.allEq/nil-right", false, fn () => ListPair.allEq (fn _ => true) ([1], [] : int list))
  val () = eqB ("ListPair.allEq/list-equality", true, fn () => ListPair.allEq (op =) (a3, [1, 2, 3]))
  val () = eqB ("ListPair.allEq/list-inequality", false, fn () => ListPair.allEq (op =) (a3, [1, 9, 3]))
  val () = eqP ("ListPair.allEq/stops", [(1, 1), (2, 9)],
                fn () => let val (f, seen) = trace (op =) in ignore (ListPair.allEq f (a3, [1, 9, 3])); seen () end)
  val () = eqP ("ListPair.allEq/order", z3,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (ListPair.allEq f (a3, b3)); seen () end)
  (* The page gives two descriptions that differ in the applications of f when
     the lengths differ: the expression
     (List.length l1 = List.length l2) andalso (List.all f (zip (l1, l2)))
     applies f to nothing, the implementation note
       fun allEq p ([], []) = true
         | allEq p (x::xs, y::ys) = p(x,y) andalso allEq p (xs,ys)
         | allEq _ _ = false
     to the pairs of the common prefix. The test takes the implementation
     note, which is also what the Discussion asks for ("determine this
     lazily"). *)
  val () = eqP ("ListPair.allEq/applies-before-lengths-are-known", z2,
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (ListPair.allEq f (a3, b2)); seen () end)

  (* ---- laws, on pseudo-random lists, against a model that uses List only ---- *)
  fun randomList n = List.tabulate (n, fn _ => T.range (~20, 20))
  val () = T.seed 2
  val () = T.repeat (50, fn i =>
    let
      val n = Int.toString i
      val l = randomList (T.range (0, 8))
      val m = randomList (if T.range (0, 1) = 0 then List.length l else T.range (0, 8))
      val k = Int.min (List.length l, List.length m)
      val same = List.length l = List.length m
      val z = List.tabulate (k, fn j => (List.nth (l, j), List.nth (m, j)))
      fun whenSame v = if same then SOME v else NONE
      val f = fn (a, b) => 3 * a - b
      val f' = fn ((a, b), c) => mix (a, b, c)
      val p = fn (a, b) => a <= b + 8
      val q = fn (a, b) => a > b + 12
    in
      eqP ("ListPair.zip/model-" ^ n, z, fn () => ListPair.zip (l, m));
      eqPO ("ListPair.zipEq/model-" ^ n, whenSame z, fn () => guarded (fn () => ListPair.zipEq (l, m)));
      eqU ("ListPair.unzip/zip-" ^ n, (List.take (l, k), List.take (m, k)), fn () => ListPair.unzip (ListPair.zip (l, m)));
      eqP ("ListPair.unzip/inverse-" ^ n, z, fn () => ListPair.zip (ListPair.unzip z));
      eqL ("ListPair.map/model-" ^ n, List.map f z, fn () => ListPair.map f (l, m));
      eqLO ("ListPair.mapEq/model-" ^ n, whenSame (List.map f z), fn () => guarded (fn () => ListPair.mapEq f (l, m)));
      eqP ("ListPair.app/model-" ^ n, z,
           fn () => let val (g, seen) = trace (fn _ => ()) in ListPair.app g (l, m); seen () end);
      eqPO ("ListPair.appEq/model-" ^ n, whenSame z,
            fn () => let val (g, seen) = trace (fn _ => ())
                     in guarded (fn () => (ListPair.appEq g (l, m); seen ())) end);
      eqI ("ListPair.foldl/model-" ^ n, List.foldl f' 1 z, fn () => ListPair.foldl mix 1 (l, m));
      eqI ("ListPair.foldr/model-" ^ n, List.foldr f' 1 z, fn () => ListPair.foldr mix 1 (l, m));
      eqIO ("ListPair.foldlEq/model-" ^ n, whenSame (List.foldl f' 1 z),
            fn () => guarded (fn () => ListPair.foldlEq mix 1 (l, m)));
      eqIO ("ListPair.foldrEq/model-" ^ n, whenSame (List.foldr f' 1 z),
            fn () => guarded (fn () => ListPair.foldrEq mix 1 (l, m)));
      eqB ("ListPair.all/model-" ^ n, List.all p z, fn () => ListPair.all p (l, m));
      eqB ("ListPair.exists/model-" ^ n, List.exists q z, fn () => ListPair.exists q (l, m));
      eqB ("ListPair.exists/de-morgan-" ^ n, not (ListPair.all p (l, m)), fn () => ListPair.exists (not o p) (l, m));
      eqB ("ListPair.allEq/model-" ^ n, same andalso List.all p z, fn () => ListPair.allEq p (l, m));
      eqB ("ListPair.allEq/list-equality-" ^ n, l = m, fn () => ListPair.allEq (op =) (l, m))
    end)

  (* ---- long lists: no stack or quadratic trouble ---- *)
  val big = List.tabulate (100000, fn i => i)
  val bigger = List.tabulate (100001, fn i => i)
  val () = eqI ("ListPair.zip/long", 100000, fn () => List.length (ListPair.zip (big, bigger)))
  val () = eqI ("ListPair.zipEq/long", 100000, fn () => List.length (ListPair.zipEq (big, big)))
  val () = T.raises ("ListPair.zipEq/long-UnequalLengths", isUnequal, fn () => ListPair.zipEq (big, bigger))
  val () = eqI ("ListPair.unzip/long", 100000, fn () => List.length (#2 (ListPair.unzip (ListPair.zip (big, big)))))
  val () = eqI ("ListPair.app/long", 100000,
                fn () => let val count = ref 0 in ListPair.app (fn _ => count := !count + 1) (big, bigger); !count end)
  val () = eqI ("ListPair.appEq/long", 100000,
                fn () => let val count = ref 0 in ListPair.appEq (fn _ => count := !count + 1) (big, big); !count end)
  val () = eqI ("ListPair.map/long", 99999, fn () => List.last (ListPair.map Int.max (big, bigger)))
  val () = eqI ("ListPair.mapEq/long", 99999, fn () => List.last (ListPair.mapEq Int.max (big, big)))
  val () = eqI ("ListPair.foldl/long", 99999, fn () => ListPair.foldl (fn (a, _, c) => Int.max (a, c)) 0 (big, bigger))
  val () = eqI ("ListPair.foldr/long", 99999, fn () => ListPair.foldr (fn (a, _, c) => Int.max (a, c)) 0 (big, bigger))
  val () = eqI ("ListPair.foldlEq/long", 99999, fn () => ListPair.foldlEq (fn (a, _, c) => Int.max (a, c)) 0 (big, big))
  val () = eqI ("ListPair.foldrEq/long", 99999, fn () => ListPair.foldrEq (fn (a, _, c) => Int.max (a, c)) 0 (big, big))
  val () = eqB ("ListPair.all/long", true, fn () => ListPair.all (op =) (big, bigger))
  val () = eqB ("ListPair.exists/long", false, fn () => ListPair.exists (op <>) (big, bigger))
  val () = eqB ("ListPair.allEq/long", true, fn () => ListPair.allEq (op =) (big, big))
  val () = eqB ("ListPair.allEq/long-unequal", false, fn () => ListPair.allEq (op =) (big, bigger))
end
