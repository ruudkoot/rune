(* IntInf.int at the edges of an immediate (haskell98 M31): a number of 63
   bits is the word itself, and two of them are added, compared and divided
   by the primitives in line; one past them is a sign and a magnitude, which
   the primitives' own code takes and makes. Each operation is run where its
   operands or its result cross -2^62 and 2^62 - 1, on constants (a small
   one an immediate the compiler makes, a larger one read from its digits)
   and on the results of arithmetic, and in loops that cross the edges, so
   that compiled code meets both kinds of number. *)
structure IntInfImmediate =
struct
  structure I = IntInf
  val lo : I.int = ~4611686018427387904
  val hi : I.int = 4611686018427387903
  val above : I.int = 4611686018427387904
  val below : I.int = ~4611686018427387905
  val values = [lo, hi, I.+ (hi, 1), I.- (lo, 1), 0, 1, ~1, 3, ~3, I.pow (2, 64)]
  fun t x = I.toString x
  fun guard f = f () handle Overflow => "Overflow" | Div => "Div" | Domain => "Domain"
  fun bool b = Bool.toString b
  fun order LESS = "LESS" | order EQUAL = "EQUAL" | order GREATER = "GREATER"
  fun pair (x, y) =
    print (String.concatWith " "
             [t x, t y ^ ":", t (x + y), t (x - y), t (x * y),
              guard (fn () => t (x div y)), guard (fn () => t (x mod y)),
              guard (fn () => t (I.quot (x, y))), guard (fn () => t (I.rem (x, y))),
              order (I.compare (x, y)), bool (x < y), bool (x = y)] ^ "\n")
  val () = List.app (fn x => List.app (fn y => pair (x, y)) values) values
  fun one x =
    print (String.concatWith " "
             [t x ^ ":", "neg", t (~ x), "abs", t (abs x), "sign", Int.toString (I.sign x),
              "toInt", guard (fn () => Int.toString (I.toInt x)), "notb", t (I.notb x),
              "<<1", t (I.<< (x, 0w1)), "~>>1", t (I.~>> (x, 0w1)),
              "log2", guard (fn () => Int.toString (I.log2 x)),
              "andb", t (I.andb (x, hi)), "orb", t (I.orb (x, lo)), "xorb", t (I.xorb (x, hi))] ^ "\n")
  val () = List.app one values
  fun steps (x, f, n, acc) = if n = 0 then List.rev acc else steps (f x, f, n - 1, t x :: acc)
  val () = print ("up: " ^ String.concatWith " " (steps (hi - 3, fn x => x + 1, 8, [])) ^ "\n")
  val () = print ("down: " ^ String.concatWith " " (steps (lo + 3, fn x => x - 1, 8, [])) ^ "\n")
  val () = print ("powers: " ^ String.concatWith " " (List.tabulate (8, fn e => t (I.pow (3, 36 + e)))) ^ "\n")
  val step : I.int = 17592186044416
  fun sum (j, acc) = if j > 200000 then acc else sum (j + 1, acc + I.fromInt j * step)
  val total = sum (1, 0)
  val () = print ("sum: " ^ t total ^ "\n")
  fun back (j, acc) = if j > 200000 then acc else back (j + 1, acc - I.fromInt j * step)
  val () = print ("back: " ^ t (back (1, total)) ^ "\n")
  val () = print ("fromInt: " ^ t (I.fromInt (valOf Int.maxInt)) ^ " " ^ t (I.fromInt (valOf Int.minInt)) ^ "\n")
  val () = print ("literals: " ^ String.concatWith " " (List.map t [hi, lo, above, below]) ^ "\n")
end
