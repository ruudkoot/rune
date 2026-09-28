(* The runner and the shrinker (docs/plans/quickcheck.md, D3, D9 and D13).
   Case k of a run has the k-th word of the run's generator as its seed, and
   the size k * maxSize / (tests - 1). A failing case is shrunk: its nodes are
   set to the words the case read, and changed (elements of lists deleted,
   joined and swapped, generated functions made constants, words lowered)
   while the case still fails in the same class and gets simpler. *)

(* Implements: CHECK *)
structure Check :> CHECK =
struct
  structure S = PropertySource

  type config = {seed : Word64.word option, tests : int, maxSize : int, maxDiscards : int, maxShrinks : int,
                 exhaustiveBelow : int, smallScope : int}

  val default : config = {seed = NONE, tests = 100, maxSize = 100, maxDiscards = 1000, maxShrinks = 5000,
                          exhaustiveBelow = 65536, smallScope = 100}

  datatype result =
      Passed of {tests : int, discarded : int, exhaustive : bool, labels : (string * int) list,
                 short : (string * real * real) list}
    | Failed of {test : int, size : int, class : string, message : string, counterexample : string list,
                 calls : string list list, shrinks : int, replay : string}
    | GaveUp of {tests : int, discarded : int}

  fun hex (w : Word64.word) : string = StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX w)

  fun token (seed : Word64.word, size : int) : string = hex seed ^ ":" ^ Int.toString size

  fun count (m : (string * int) list, l : string) : (string * int) list =
    case List.partition (fn (l', _) => l' = l) m of
      ([(_, n)], rest) => (l, n + 1) :: rest
    | _ => (l, 1) :: m

  fun classOf (r : Prop.result) : string option =
    case #verdict r of Prop.Fail {class, ...} => SOME class | _ => NONE

  (* the result of p on the source, the case's cleanups run *)
  fun runCase (p : Prop.prop) (s : S.source) : Prop.result =
    let val r = Prop.run p (s, S.root) handle e => (S.cleanUp s; raise e)
    in S.cleanUp s; r end

  (* ---- the shrinker ---- *)

  (* smaller words for a node's word: 0, then ever closer to it, each also
     with its parity, which under zigzag keeps a number's sign *)
  fun smaller (w : Word64.word) : Word64.word list =
    let
      fun halves (k, acc) =
        if k > 63 then acc
        else halves (k + 1, Word64.- (w, Word64.>> (w, Word.fromInt k)) :: acc)
      val parity = Word64.andb (w, 0w1)
      fun same c = Word64.orb (Word64.andb (c, Word64.notb 0w1), parity)
      val cs = List.concat (List.map (fn c => [c, same c]) (0w0 :: List.rev (halves (1, []))))
      fun dedup ([], _) = []
        | dedup (c :: rest, seen) = if List.exists (fn c' => c' = c) seen then dedup (rest, seen) else c :: dedup (rest, c :: seen)
    in
      List.filter (fn c => c < w) (dedup (cs, []))
    end

  (* a real is simpler when it is finite before infinite before NaN, whole
     before not, and smaller in magnitude, positive before negative *)
  fun realKey (x : real) : int * real * int =
    if Real.isNan x then (3, 0.0, 0)
    else if not (Real.isFinite x) then (2, 0.0, if x > 0.0 then 0 else 1)
    else (if Real.== (x, Real.realTrunc x) then 0 else 1, Real.abs x, if Real.signBit x then 1 else 0)
  fun realLess ((a, b, c) : int * real * int, (a', b', c') : int * real * int) : bool =
    a < a' orelse (a = a' andalso (b < b' orelse (Real.== (b, b') andalso c < c')))
  fun simplerReals (w : Word64.word) : Word64.word list =
    let
      val x = S.realOf w
      val cs = [0.0, 1.0, ~1.0, 0.5] @ (if Real.isFinite x then [Real.realTrunc x, Real.realRound x, x / 2.0, ~x] else [])
    in
      List.map S.bitsOf (List.filter (fn c => realLess (realKey c, realKey x)) cs)
    end

  fun candidates (n : S.node) : Word64.word list =
    case #kind n of
      S.MarkNode => if #word n = 0w0 then [] else [0w0]
    | S.BoolNode => if #word n = 0w0 then [] else [0w0]
    | S.RealNode => simplerReals (#word n)
    | _ => smaller (#word n)

  fun setWord (set : S.node list, a : Word64.word, w : Word64.word) : S.node list =
    List.map (fn n => if #address n = a then S.withWord (n, w) else n) set

  (* a case is simpler than another when it reads fewer nodes, or as many and
     its words are smaller where they first differ: an order with no endless
     descent, so that shrinking ends, and one in which a step that only
     draws a node anew never counts *)
  fun simpler (s : S.source, s' : S.source) : bool =
    let
      val (ws, ws') = (List.map #word (S.nodes s), List.map #word (S.nodes s'))
      fun lex (w :: ws, w' :: ws') = w < w' orelse (w = w' andalso lex (ws, ws'))
        | lex _ = false
    in
      List.length ws < List.length ws' orelse (List.length ws = List.length ws' andalso lex (ws, ws'))
    end

  (* the set with the elements below base renumbered: element j to f j, or
     gone where f j is NONE *)
  fun renumbered (set : S.node list, base : Word64.word list, f : int -> int option) : S.node list =
    let
      fun move (n : S.node) : S.node option =
        if List.length (#path n) > List.length base andalso S.isPrefix (base, #path n) then
          let val rest = List.drop (#path n, List.length base)
          in
            case f (Word64.toInt (hd rest)) of
              NONE => NONE
            | SOME j =>
                let val path = base @ [Word64.fromInt j] @ tl rest
                in SOME (S.withPath (n, path, S.addressOf path)) end
          end
        else SOME n
    in
      List.mapPartial move set
    end

  (* the same for a sequence's parts and marks *)
  fun renumber (set : S.node list, q : S.sequence, f : int -> int option) : S.node list =
    let val set = renumbered (set, #parts q, f)
    in case #marks q of SOME m => renumbered (set, m, f) | NONE => set end

  fun lengthOf (set : S.node list, q : S.sequence) : Word64.word option =
    Option.map #word (List.find (fn n => #address n = #length q) set)

  (* the set with element i of the sequence deleted and the elements after it
     moved down, its length one less *)
  fun deleted (set : S.node list, q : S.sequence, i : int) : S.node list =
    List.map (fn n => if #address n = #length q andalso #word n > 0w0 then S.withWord (n, Word64.- (#word n, 0w1)) else n)
             (renumber (set, q, fn j => if j = i then NONE else if j < i then SOME j else SOME (j - 1)))

  (* the set with elements i and i + 1 of the sequence swapped *)
  fun swapped (set : S.node list, q : S.sequence, i : int) : S.node list =
    renumber (set, q, fn j => if j = i then SOME (i + 1) else if j = i + 1 then SOME i else SOME j)

  (* the elements of a sequence: one more than the last index of a node below
     its parts or marks *)
  fun elementsOf (set : S.node list, q : S.sequence) : int =
    let
      fun last base =
        List.foldl (fn (n : S.node, m) =>
                      if List.length (#path n) > List.length base andalso S.isPrefix (base, #path n)
                      then Int.max (m, Word64.toInt (List.nth (#path n, List.length base)) + 1)
                      else m)
                   0 set
    in
      Int.max (last (#parts q), case #marks q of SOME m => last m | NONE => 0)
    end

  (* element i of the sequence o, when the element is a list (Gen.list): its
     length is its node's word, and its elements can be moved *)
  fun elementList (qs : S.sequence list, outer : S.sequence, i : int) : S.sequence option =
    let val at = #parts outer @ [Word64.fromInt i]
    in List.find (fn q => #parts q = at @ [0w2] andalso #marks q = SOME (at @ [0w1])) qs end

  (* the set with the list that is element j of outer appended to the one
     that is element i, and element j deleted: the move that the shrinking
     challenge's problems of lists of lists need *)
  fun joined (set : S.node list, qs : S.sequence list, outer : S.sequence, i : int, j : int) : S.node list option =
    case (elementList (qs, outer, i), elementList (qs, outer, j)) of
      (SOME q, SOME r) =>
        (case (lengthOf (set, q), lengthOf (set, r)) of
           (SOME m, SOME n) =>
             if m > 0w1000000 orelse n > 0w1000000 then NONE
             else
               let
                 fun into (from : Word64.word list, to : Word64.word list) set =
                   List.map (fn (nd : S.node) =>
                               if List.length (#path nd) > List.length from andalso S.isPrefix (from, #path nd) then
                                 let
                                   val rest = List.drop (#path nd, List.length from)
                                   val path = to @ [Word64.+ (m, hd rest)] @ tl rest
                                 in
                                   S.withPath (nd, path, S.addressOf path)
                                 end
                               else nd)
                            set
                 val set = into (#parts r, #parts q) set
                 val set = case (#marks r, #marks q) of (SOME a, SOME b) => into (a, b) set | _ => set
                 val set = setWord (set, #length q, Word64.+ (m, n))
               in
                 SOME (deleted (set, outer, j))
               end
         | _ => NONE)
    | _ => NONE

  (* The shrinker works in sweeps. A pass is a list of sites (an element of
     a list, a node, a pair of nodes, ...), each with the changes it may
     make, tried in order; a change that is taken is tried again at the same
     site, and a site with none moves the sweep on. The passes are swept in
     turn until none changes anything, or the runs are spent. *)
  fun shrink (p : Prop.prop, seed : Word64.word, size : int, class : string, maxRuns : int)
             (s0 : S.source, r0 : Prop.result) : S.source * Prop.result * int =
    let
      val runs = ref 0
      fun upTo n = List.tabulate (Int.max (n, 0), fn i => i)
      fun distinctBy key xs =
        List.foldl (fn (x, acc) => if List.exists (fn y => key y = key x) acc then acc else acc @ [x]) [] xs

      (* the case of the change, if it fails as s does and is simpler; a
         function made a constant need only be as simple, as the words it
         has read may already be 0, and the zeroed paths only grow *)
      fun attempt (s : S.source) (set : S.node list, zeros : Word64.word list list) : (S.source * Prop.result) option =
        if !runs >= maxRuns then NONE
        else
          let
            val () = runs := !runs + 1
            val s' = S.new (seed, size, set, zeros)
            val r = runCase p s'
          in
            if classOf r = SOME class andalso (simpler (s', s) orelse (List.length zeros > List.length (#zeros s)
                                                                        andalso not (simpler (s, s'))))
            then SOME (s', r) else NONE
          end

      (* the changes of a site, as sets and zeroed paths *)
      type change = S.node list * Word64.word list list
      (* each pass: the sites of a case, and a site's changes *)
      fun deletions (s : S.source) : (unit -> change list) list =
        let val set = S.nodes s
        in List.concat (List.map (fn q => List.map (fn i => fn () => [(deleted (set, q, i), #zeros s)])
                                                   (upTo (elementsOf (set, q))))
                                 (S.sequences s))
        end
      (* a generated function made a constant: all of it zeroed, which makes
         it pure, or its results and raises alone, which keeps its kind *)
      fun constants (s : S.source) : (unit -> change list) list =
        let
          val set = S.nodes s
          val zeros = #zeros s
          fun zeroed paths = (List.filter (fn n => not (List.exists (fn z => S.isPrefix (z, #path n)) paths)) set,
                              paths @ zeros)
          fun covered path = List.exists (fn z => S.isPrefix (z, path)) zeros
        in
          List.map (fn (f : S.position) => fn () =>
                      List.map zeroed (List.filter (fn ps => not (List.all covered ps))
                                                   [[#path f], [#path f @ [0w1], #path f @ [0w2]]]))
                   (distinctBy #address (List.map #1 (S.calls s)))
        end
      fun joins (s : S.source) : (unit -> change list) list =
        let
          val set = S.nodes s
          val qs = S.sequences s
        in
          List.concat (List.map (fn outer =>
            let val n = elementsOf (set, outer)
            in
              List.concat (List.map (fn i =>
                List.map (fn j => fn () => case joined (set, qs, outer, i, j) of SOME set => [(set, #zeros s)] | NONE => [])
                         (List.filter (fn j => j <> i) (upTo n)))
                (upTo n))
            end) qs)
        end
      fun lowerings (s : S.source) : (unit -> change list) list =
        let val set = S.nodes s
        in List.map (fn n => fn () => List.map (fn c => (setWord (set, #address n, c), #zeros s)) (candidates n)) set end
      fun together (s : S.source) : (unit -> change list) list =
        let
          val set = S.nodes s
          val groups =
            List.filter (fn g => List.length g > 1)
              (List.map (fn n => List.filter (fn m => #kind m = #kind n andalso #word m = #word n) set)
                        (distinctBy (fn n : S.node => (#kind n, #word n)) (List.filter (fn n => #word n <> 0w0) set)))
        in
          List.map (fn g => fn () =>
                      List.map (fn c => (List.foldl (fn (n, set) => setWord (set, #address n, c)) set g, #zeros s))
                               (candidates (hd g)))
                   groups
        end
      fun redistribute (s : S.source) : (unit -> change list) list =
        let
          val set = S.nodes s
          val ints = List.filter (fn n => #kind n = S.IntNode andalso #word n > 0w1) set
          fun pairs [] = []
            | pairs (n :: rest) = List.map (fn m => (n, m)) rest @ pairs rest
        in
          List.map (fn (n : S.node, m : S.node) => fn () =>
                      List.map (fn d => (setWord (setWord (set, #address n, Word64.- (#word n, d)), #address m, Word64.+ (#word m, d)),
                                         #zeros s))
                               (List.filter (fn d => d > 0w0 andalso d <= #word n)
                                            [Word64.andb (#word n, Word64.notb 0w1),
                                             Word64.andb (Word64.>> (#word n, 0w1), Word64.notb 0w1), 0w2]))
                   (pairs ints)
        end
      fun swaps (s : S.source) : (unit -> change list) list =
        let val set = S.nodes s
        in List.concat (List.map (fn q => List.map (fn i => fn () => [(swapped (set, q, i), #zeros s)])
                                                   (upTo (elementsOf (set, q) - 1)))
                                 (S.sequences s))
        end

      (* a sweep of a pass from site i: the case it ends with, and whether
         it changed anything *)
      fun sweep pass (st as (s, _), i, changed) =
        case List.drop (pass s, i) handle Subscript => [] of
          [] => (st, changed)
        | site :: _ =>
            let
              fun try [] = NONE
                | try (c :: cs) = case attempt s c of SOME st' => SOME st' | NONE => try cs
            in
              case try (site ()) of
                SOME st' => sweep pass (st', i, true)
              | NONE => if !runs >= maxRuns then (st, changed) else sweep pass (st, i + 1, changed)
            end
      val passes = [deletions, constants, joins, lowerings, together, redistribute, swaps]
      fun round st =
        let
          val (st, changed) = List.foldl (fn (pass, (st, changed)) =>
                                            let val (st, c) = sweep pass (st, 0, false) in (st, changed orelse c) end)
                                         (st, false) passes
        in
          if changed andalso !runs < maxRuns then round st else st
        end
      val (s, r) = round (s0, r0)
    in
      (s, r, !runs)
    end

  (* the calls of each generated function of a case, in the order made *)
  fun callsOf (s : S.source) : string list list =
    let
      val cs = S.calls s
      val fs = List.foldl (fn ((f : S.position, _), fs) => if List.exists (fn f' => f' = #address f) fs then fs else fs @ [#address f])
                          [] cs
    in
      List.map (fn f => List.map #2 (List.filter (fn (f' : S.position, _) => #address f' = f) cs)) fs
    end

  (* ---- exhaustive mode and the small scope ---- *)

  (* The case after s, when every node reads 0 unless it is set: the last
     node s read that has a word left below its bound (and below cap, where
     there is one) is raised by one, the nodes read before it are kept and
     those after it forgotten. So the cases come in the order of their
     words, simplest first, and each shape of the tree is met once. *)
  fun nextCase (s : S.source, cap : Word64.word option) : S.node list option =
    let
      fun top (n : S.node) =
        case cap of
          NONE => #bound n
        | SOME c => if #bound n = 0w0 then c else Word64.min (#bound n, c)
      fun bump [] = NONE
        | bump ((n : S.node) :: earlier) =
            if Word64.+ (#word n, 0w1) < top n then SOME (List.rev (S.withWord (n, Word64.+ (#word n, 0w1)) :: earlier))
            else bump earlier
    in
      bump (List.rev (S.nodes s))
    end

  fun finite (s : S.source) : bool = List.all (fn n => #bound n <> 0w0) (S.nodes s)

  (* the product of the bounds of the nodes s read, if it is at most limit *)
  fun product (s : S.source, limit : int) : int option =
    List.foldl (fn (n : S.node, SOME k) =>
                  if #bound n = 0w0 orelse #bound n > Word64.fromInt limit then NONE
                  else let val b = Word64.toInt (#bound n) in if k > limit div b then NONE else SOME (k * b) end
                | (_, NONE) => NONE)
               (SOME 1) (S.nodes s)

  fun exhaustiveToken (s : S.source, size : int) : string =
    "X" ^ String.concatWith "." (List.map (fn n => Word64.fmt StringCvt.HEX (#word n)) (S.nodes s)) ^ ":" ^ Int.toString size

  (* ---- runs ---- *)

  (* the result of a run that passed: coverage that fell short of what was
     asked for is reported *)
  fun passedAfter (passed : int, discarded : int, exhaustive : bool, labels : (string * int) list,
                   covers : (string * real * bool) list) : result =
    let
      val asked = List.foldl (fn ((l, pct, _), m) => if List.exists (fn (l', _) => l' = l) m then m else (l, pct) :: m)
                             [] covers
      val short =
        List.mapPartial (fn (l, pct) =>
                           let val had = 100.0 * real (List.length (List.filter (fn (l', _, b) => l' = l andalso b) covers))
                                         / real (Int.max (passed, 1))
                           in if had < pct then SOME (l, pct, had) else NONE end)
                        asked
    in
      Passed {tests = passed, discarded = discarded, exhaustive = exhaustive, labels = labels, short = short}
    end

  (* What running the cases in order found: a failure, every case passing,
     or a stop before the last. *)
  datatype enumerated =
      Found of result
    | Complete of int * int * (string * int) list * (string * real * bool) list
    | Stopped

  (* The cases of p in order, at most limit of them. Exhaustive: every node
     must have a finite bound, and the bounds of a case must multiply to at
     most limit, or the run stops. With a cap: every node's words are below
     it too. *)
  fun cases (p : Prop.prop, size : int, cap : Word64.word option, limit : int, exhaustive : bool) : enumerated =
    let
      fun loop (set, k, passed, discarded, labels, covers) =
        if k >= limit then Stopped
        else
          let
            val s = S.new (0w0, size, set, [[]])
            val r = runCase p s
          in
            if exhaustive andalso (not (finite s) orelse not (isSome (product (s, limit)))) then Stopped
            else
              case #verdict r of
                Prop.Fail {class, message} =>
                  Found (Failed {test = k, size = size, class = class, message = message, counterexample = #shown r,
                                 calls = callsOf s, shrinks = 0, replay = exhaustiveToken (s, size)})
              | v =>
                  let
                    val (passed, discarded, labels, covers) =
                      case v of
                        Prop.Pass => (passed + 1, discarded, List.foldl (fn (l, m) => count (m, l)) labels (#labels r),
                                      #covers r @ covers)
                      | _ => (passed, discarded + 1, labels, covers)
                  in
                    case nextCase (s, cap) of
                      SOME set => loop (set, k + 1, passed, discarded, labels, covers)
                    | NONE => Complete (passed, discarded, labels, covers)
                  end
          end
    in
      loop ([], 0, 0, 0, [], [])
    end

  fun check ({seed, tests, maxSize, maxDiscards, maxShrinks, exhaustiveBelow, smallScope} : config) (name : string)
            (p : Prop.prop) : result =
    let
      val seed = case seed of SOME s => s | NONE => Random.hashString name
      fun sizeOf k = if tests <= 1 then maxSize else Int.min (k, tests - 1) * maxSize div (tests - 1)
      fun loop (g, passed, discarded, labels, covers) =
        if passed >= tests then passedAfter (passed, discarded, false, labels, covers)
        else if discarded > maxDiscards then GaveUp {tests = passed, discarded = discarded}
        else
          let
            val (caseSeed, g) = Random.word64 g
            val size = sizeOf passed
            val s = S.new (caseSeed, size, [], [])
            val r = runCase p s
          in
            case #verdict r of
              Prop.Pass => loop (g, passed + 1, discarded, List.foldl (fn (l, m) => count (m, l)) labels (#labels r),
                                  #covers r @ covers)
            | Prop.Discard => loop (g, passed, discarded + 1, labels, covers)
            | Prop.Fail {class, ...} =>
                let
                  val (s', r', runs) = shrink (p, caseSeed, size, class, maxShrinks) (s, r)
                  val message = case #verdict r' of Prop.Fail {message, ...} => message | _ => ""
                in
                  Failed {test = passed + discarded, size = size, class = class, message = message,
                          counterexample = #shown r', calls = callsOf s', shrinks = runs,
                          replay = token (caseSeed, size)}
                end
          end
      fun random () = loop (Random.fromSeed seed, 0, 0, [], [])
    in
      case if exhaustiveBelow > 0 then cases (p, maxSize, NONE, exhaustiveBelow, true) else Stopped of
        Found r => r
      | Complete (passed, discarded, labels, covers) =>
          if passed = 0 andalso discarded > 0 then GaveUp {tests = 0, discarded = discarded}
          else passedAfter (passed, discarded, true, labels, covers)
      | Stopped =>
          (* the small scope: the cases whose words are all below 3, the
             simplest first, before the random ones *)
          case if smallScope > 0 then cases (p, maxSize, SOME 0w3, smallScope, false) else Stopped of
            Found r => r
          | _ => random ()
    end

  (* the case of an exhaustive token: its words set in the order they are
     read, one run for each *)
  fun exhaustiveCase (p : Prop.prop) (words : Word64.word list, size : int) : Prop.result option =
    let
      fun go (set, ws) =
        let
          val s = S.new (0w0, size, set, [[]])
          val r = runCase p s
        in
          case ws of
            [] => SOME r
          | w :: rest =>
              (case List.drop (S.nodes s, List.length set) of
                 n :: _ => go (set @ [S.withWord (n, w)], rest)
               | [] => NONE)
              handle Subscript => NONE
        end
    in
      go ([], words)
    end

  fun replay (t : string) (p : Prop.prop) : Prop.result option =
    case String.fields (fn c => c = #":") t of
      [s, n] =>
        if String.isPrefix "X" s then
          let
            val ws = List.map (StringCvt.scanString (Word64.scan StringCvt.HEX))
                              (List.filter (fn w => w <> "") (String.fields (fn c => c = #".") (String.extract (s, 1, NONE))))
          in
            case (List.all isSome ws, Int.fromString n) of
              (true, SOME size) => exhaustiveCase p (List.map valOf ws, size)
            | _ => NONE
          end
        else
          (case (StringCvt.scanString (Word64.scan StringCvt.HEX) s, Int.fromString n) of
             (SOME seed, SOME size) =>
               let
                 val src = S.new (seed, size, [], [])
                 val r = runCase p src
               in
                 case classOf r of
                   SOME class => SOME (#2 (shrink (p, seed, size, class, #maxShrinks default) (src, r)))
                 | NONE => SOME r
               end
           | _ => NONE)
    | _ => NONE

  fun passed (Passed {short, ...}) = List.null short
    | passed _ = false

  fun pct (x : real) : string = Real.fmt (StringCvt.FIX (SOME 1)) x ^ "%"

  fun report (name : string) (r : result) : string =
    case r of
      Passed {tests, discarded, exhaustive, labels, short} =>
        (if List.null short then "PASS " else "FAIL ") ^ name ^ ": " ^ Int.toString tests ^ " cases"
        ^ (if exhaustive then ", every one" else "")
        ^ (if discarded > 0 then ", " ^ Int.toString discarded ^ " discarded" else "") ^ "\n"
        ^ String.concat (List.map (fn (l, n) => "  " ^ pct (100.0 * real n / real (Int.max (tests, 1))) ^ " " ^ l ^ "\n")
                                  (List.rev labels))
        ^ String.concat (List.map (fn (l, want, had) => "  coverage of " ^ l ^ ": " ^ pct had ^ ", asked " ^ pct want ^ "\n")
                                  short)
    | Failed {test, size, class, message, counterexample, calls, shrinks, replay} =>
        "FAIL " ^ name ^ ": " ^ class ^ " at case " ^ Int.toString (test + 1) ^ " (size " ^ Int.toString size ^ ")"
        ^ (if message = "" then "" else ": " ^ message) ^ "\n"
        ^ String.concat (List.map (fn x => "  " ^ x ^ "\n") counterexample)
        ^ String.concat (List.map (fn cs => "  fn " ^ String.concatWith " | " cs ^ "\n") calls)
        ^ "  shrunk in " ^ Int.toString shrinks ^ " runs; replay " ^ replay ^ "\n"
    | GaveUp {tests, discarded} =>
        "FAIL " ^ name ^ ": gave up after " ^ Int.toString tests ^ " cases and " ^ Int.toString discarded
        ^ " discarded\n"

  fun main (ps : (string * Prop.prop) list) : unit =
    let
      val results = List.map (fn (name, p) => let val r = check default name p in print (report name r); r end) ps
    in
      if List.all passed results then () else OS.Process.exit OS.Process.failure
    end
end
