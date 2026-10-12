(* A raise from a function with a handler, at tier 2, while a home holds a
   Word64 raw (its 64 bits) whose slot is behind: the raise writes the
   homes back first, and this one's word is a box, made by a helper -- which
   once clobbered the exception the raise was carrying, loaded before (the
   handler got the box: "expected exception"; runtime/register/jit/emit.c,
   emit_RAISE). Compiled at -O0 (.cargs), where a raise to a handler of the
   same function stays a RAISE; the words pass 63 bits, so that they have
   no immediate. *)
exception Stop of int

fun guarded (0, a : Word64.word, b : Word64.word, acc) = (a, b, acc)
  | guarded (n, a, b, acc) =
      let
        val d = Word64.* (Word64.+ (a, b), 0wx9E3779B97F4A7C15)
        val (a', acc') =
          (if n mod 3 = 0 then raise Stop n else (Word64.xorb (d, a), acc + 1))
          handle Stop k => (Word64.+ (d, Word64.fromInt k), acc + k)
      in guarded (n - 1, b, a', acc') end

val (a, b, acc) = guarded (300, 0wx8000000000000001, 0wxFEDCBA9876543210, 0)
val () = print (Word64.toString a ^ " " ^ Word64.toString b ^ " " ^ Int.toString acc ^ "\n")

(* the same with a real *)
fun realGuarded (0, x : real, acc) = (x, acc)
  | realGuarded (n, x, acc) =
      let
        val y = x * 1.000001 + 0.5
        val (x', acc') =
          (if n mod 4 = 0 then raise Stop n else (y - 0.25, acc + 1))
          handle Stop k => (y + real k, acc + k)
      in realGuarded (n - 1, x', acc') end

val (x, acc2) = realGuarded (200, 0.1, 0)
val () = print (Real.fmt (StringCvt.FIX (SOME 3)) x ^ " " ^ Int.toString acc2 ^ "\n")
