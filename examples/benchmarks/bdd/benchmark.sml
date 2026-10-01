(* Copyright 1996 Institut National de Recherche en Informatique et en
   Automatique. All rights reserved. Q Public License version 1.0: LICENSE.
   SML translation of Xavier Leroy's Caml translation; the original SML
   author is unspecified upstream. The unmodified original and separate
   translation patch accompany this file. *)
structure Benchmark =
struct
  val name = "bdd"
  datatype bdd = One | Zero | Node of bdd * int * int * bdd
  fun id (Node (_, _, n, _)) = n | id Zero = 0 | id One = 1
  fun eval Zero _ = false
    | eval One _ = true
    | eval (Node (lo, v, _, hi)) vars =
        eval (if Array.sub (vars, v) then hi else lo) vars

  val initial = 8191
  val nodeC = ref 1
  val sizeMask = ref initial
  val table : bdd list array ref = ref (Array.array (initial + 1, []))
  val items = ref 0
  val cacheSize = 1999
  val and1 = Array.array (cacheSize, 0)
  val and2 = Array.array (cacheSize, 0)
  val and3 = Array.array (cacheSize, Zero)
  val xor1 = Array.array (cacheSize, 0)
  val xor2 = Array.array (cacheSize, 0)
  val xor3 = Array.array (cacheSize, Zero)
  val not1 = Array.array (cacheSize, 0)
  val not2 = Array.array (cacheSize, One)

  fun hashVal (x, y, v) =
    Word32.+ (Word32.+ (Word32.<< (Word32.fromInt x, 0w1), Word32.fromInt y),
              Word32.<< (Word32.fromInt v, 0w2))
  fun index (x, y, v) = Word32.toInt (Word32.andb (hashVal (x, y, v), Word32.fromInt (!sizeMask)))
  fun hash (x, y) = (x * 2 + y) mod cacheSize

  fun reset () =
    (sizeMask := initial; table := Array.array (initial + 1, []); items := 0; nodeC := 1;
     Array.modify (fn _ => 0) and1; Array.modify (fn _ => 0) and2;
     Array.modify (fn _ => Zero) and3;
     Array.modify (fn _ => 0) xor1; Array.modify (fn _ => 0) xor2;
     Array.modify (fn _ => Zero) xor3;
     Array.modify (fn _ => 0) not1; Array.modify (fn _ => One) not2)

  fun resize newSize =
    let
      val old = !table
      val fresh : bdd list array = Array.array (newSize, [])
      fun copy [] = ()
        | copy ((n as Node (lo, v, _, hi)) :: ns) =
            let val i = Word32.toInt (Word32.andb (hashVal (id lo, id hi, v), Word32.fromInt (newSize - 1)))
            in Array.update (fresh, i, n :: Array.sub (fresh, i)); copy ns end
        | copy _ = raise Fail "invalid unique bucket"
      fun loop i = if i > !sizeMask then () else (copy (Array.sub (old, i)); loop (i + 1))
    in loop 0; table := fresh; sizeMask := newSize - 1 end

  fun make (lo, v, hi) =
    let
      val il = id lo
      val ih = id hi
      val i = index (il, ih, v)
      val bucket = Array.sub (!table, i)
      fun lookup [] =
            let
              val _ = nodeC := !nodeC + 1
              val n = Node (lo, v, !nodeC, hi)
              val _ =
                if !items <= !sizeMask then
                  (Array.update (!table, i, n :: bucket); items := !items + 1)
                else
                  (resize (!sizeMask + !sizeMask + 2);
                   let val j = index (il, ih, v)
                   in Array.update (!table, j, n :: Array.sub (!table, j)) end)
            in n end
        | lookup ((n as Node (l, w, _, h)) :: rest) =
            if v = w andalso il = id l andalso ih = id h then n else lookup rest
        | lookup _ = raise Fail "invalid unique bucket"
    in if il = ih then lo else lookup bucket end

  fun variable n = make (Zero, n, One)

  (* Explicit right-before-left evaluation preserves the OCaml allocation
     schedule. The shared AND/XOR cache is an upstream benchmark choice. *)
  fun negate Zero = One
    | negate One = Zero
    | negate (Node (lo, v, n, hi)) =
        let val slot = n mod cacheSize
        in
          if n = Array.sub (not1, slot) then Array.sub (not2, slot)
          else
            let val high = negate hi
                val low = negate lo
                val result = make (low, v, high)
            in Array.update (not1, slot, n); Array.update (not2, slot, result); result end
        end

  fun conjunction (left, right) =
    case (left, right) of
      (Node (l1, v1, i1, r1), Node (l2, v2, i2, r2)) =>
        let val slot = hash (i1, i2)
        in
          if i1 = Array.sub (and1, slot) andalso i2 = Array.sub (and2, slot)
          then Array.sub (and3, slot)
          else
            let
              val (low, v, high) =
                case Int.compare (v1, v2) of
                  EQUAL => let val high = conjunction (r1, r2)
                               val low = conjunction (l1, l2) in (low, v1, high) end
                | LESS => let val high = conjunction (r1, right)
                              val low = conjunction (l1, right) in (low, v1, high) end
                | GREATER => let val high = conjunction (left, r2)
                                 val low = conjunction (left, l2) in (low, v2, high) end
              val result = make (low, v, high)
            in Array.update (and1, slot, i1); Array.update (and2, slot, i2);
               Array.update (and3, slot, result); result end
        end
    | (Zero, _) => Zero
    | (_, Zero) => Zero
    | (One, _) => right
    | (_, One) => left


  fun exclusive (left, right) =
    case (left, right) of
      (Node (l1, v1, i1, r1), Node (l2, v2, i2, r2)) =>
        let val slot = hash (i1, i2)
        in
          if i1 = Array.sub (and1, slot) andalso i2 = Array.sub (and2, slot)
          then Array.sub (and3, slot)
          else
            let
              val (low, v, high) =
                case Int.compare (v1, v2) of
                  EQUAL => let val high = exclusive (r1, r2)
                               val low = exclusive (l1, l2) in (low, v1, high) end
                | LESS => let val high = exclusive (r1, right)
                              val low = exclusive (l1, right) in (low, v1, high) end
                | GREATER => let val high = exclusive (left, r2)
                                 val low = exclusive (left, l2) in (low, v2, high) end
              val result = make (low, v, high)
            in Array.update (and1, slot, i1); Array.update (and2, slot, i2);
               Array.update (and3, slot, result); result end
        end
    | (Zero, _) => right
    | (_, Zero) => left
    | (One, _) => negate right
    | (_, One) => negate left

  fun hwb n =
    let
      fun h (i, j) = if i = j then variable i else
            let val childR = g (i, j - 1)
                val vR = variable j
                val right = conjunction (vR, childR)
                val childL = h (i, j - 1)
                val vL = negate (variable j)
                val left = conjunction (vL, childL)
            in exclusive (left, right) end
      and g (i, j) = if i = j then variable i else
            let val childR = g (i + 1, j)
                val vR = variable i
                val right = conjunction (vR, childR)
                val childL = h (i + 1, j)
                val vL = negate (variable i)
                val left = conjunction (vL, childL)
            in exclusive (left, right) end
    in h (0, n - 1) end

  fun correct tree vars =
    let val count = Array.foldl (fn (b, n) => if b then n + 1 else n) 0 vars
    in eval tree vars = (count > 0 andalso Array.sub (vars, count - 1)) end

  fun truthTable n =
    let
      val _ = reset ()
      val tree = hwb n
      val limit = Word32.<< (0w1, Word.fromInt n)
      fun loop bits =
        if bits = limit then ()
        else
          let val vars = Array.tabulate (n, fn i => Word32.andb (bits, Word32.<< (0w1, Word.fromInt i)) <> 0w0)
          in if correct tree vars then loop (Word32.+ (bits, 0w1)) else raise Fail "BDD truth table" end
    in loop 0w0 end

  fun run [size, tests] =
        let
          val n = BenchInput.between (1, 22) (BenchInput.integer size)
          val count = BenchInput.between (1, 100000) (BenchInput.integer tests)
          val _ = reset ()
          val tree = hwb n
          val seed : Word32.word ref = ref 0w0
          fun random () =
            (seed := Word32.+ (Word32.* (!seed, 0w25173), 0w17431);
             Word32.andb (!seed, 0w1) <> 0w0)
          fun loop 0 = ()
            | loop k =
                if correct tree (Array.tabulate (n, fn _ => random ())) then loop (k - 1)
                else raise Fail "BDD generated assignment"
        in loop count; Int.toString n ^ " " ^ Int.toString (!nodeC) ^ " " ^ Int.toString count end
    | run _ = raise Fail "bdd expects variables tests"
end
