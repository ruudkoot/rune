(* A real is kept in a word of the VM where its exponent allows it (a normal
   number from 2^-511 up to 2^513) and in a box where it does not: zero, the
   subnormals, the infinities, NaN and the normals outside that range. Every
   one comes back bit for bit from a list, an array, a ref, a tuple and a
   closure, through polymorphic code and across collections. *)
fun bits (r : real) = StringCvt.padLeft #"0" 16 (LargeWord.toString (PackWord64Big.subVec (PackRealBig.toBytes r, 0)))
fun pow2 e = Real.fromManExp {man = 1.0, exp = e}
val named =
  [("zero", 0.0), ("minus zero", ~0.0), ("inf", Real.posInf), ("minus inf", Real.negInf),
   ("least subnormal", Real.minPos), ("least normal", Real.minNormalPos), ("greatest", Real.maxFinite),
   ("least", ~ Real.maxFinite), ("one", 1.0), ("minus one", ~1.0), ("pi", Math.pi),
   ("2^-512", pow2 ~512), ("2^-511", pow2 ~511), ("below 2^-511", Real.nextAfter (pow2 ~511, 0.0)),
   ("2^512", pow2 512), ("below 2^513", Real.nextAfter (pow2 513, 0.0)), ("2^513", pow2 513),
   ("minus 2^513", ~ (pow2 513)), ("minus 2^-512", ~ (pow2 ~512)), ("1E300", 1E300), ("1E~300", 1E~300)]
val () = List.app (fn (name, r) => print (name ^ ": " ^ bits r ^ "\n")) named

(* stored and read back: what comes out is what went in *)
fun id (x : 'a) : 'a = #1 (hd [(x, ())])
val rs = List.map #2 named
val arr = Array.fromList rs
val cells = List.map ref rs
val pairs = List.map (fn r => (r, [r])) rs
val thunks = List.map (fn r => fn () => r) rs
fun same (a, b) = bits a = bits b
fun allSame f = List.all (fn x => x) (ListPair.map same (rs, f ()))
(* a collection or more between the storing and the reading *)
fun churn (0, acc) = length acc
  | churn (n, acc) = churn (n - 1, if n mod 1000 = 0 then [] else real n :: acc)
val _ = churn (3000000, [])
val () = print (String.concatWith " " (List.map Bool.toString
  [allSame (fn () => List.map id rs),
   allSame (fn () => List.tabulate (Array.length arr, fn i => Array.sub (arr, i))),
   allSame (fn () => List.map ! cells),
   allSame (fn () => List.map (fn (r, l) => if same (r, hd l) then r else 0.0 / 0.0) pairs),
   allSame (fn () => List.map (fn f => f ()) thunks)]) ^ "\n")

(* the arithmetic of the ones that are boxes *)
val nan = 0.0 / 0.0
val () = print (String.concatWith " " (List.map Bool.toString
  [Real.isNan nan, Real.isNan (id nan), Real.== (nan, nan), Real.== (0.0, ~0.0), Real.signBit (~0.0),
   Real.signBit (id (~0.0 * 1.0)), Real.== (Real.posInf + 1.0, Real.posInf), Real.isNan (Real.posInf - Real.posInf),
   Real.== (1.0 / 0.0, Real.posInf), Real.== (~1.0 / 0.0, Real.negInf), Real.isNormal Real.minPos, Real.isFinite Real.maxFinite]) ^ "\n")
(* many zeros, summed: zero is everywhere and is one box *)
val zeros = Array.array (100000, 0.0)
val () = Array.modifyi (fn (i, z) => if i mod 3 = 0 then z * 2.0 else if i mod 3 = 1 then ~ z else z - z) zeros
val () = print (bits (Array.foldl op + 0.0 zeros) ^ " " ^ Int.toString (Array.foldl (fn (z, n) => if Real.signBit z then n + 1 else n) 0 zeros) ^ "\n")
