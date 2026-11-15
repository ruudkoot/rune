(* The general path's cases (eval/apply, the haskell98 roadmap's D15 C),
   every function through a ref so that the compiler sees neither the
   closure nor the helper, each in a loop long enough for the JIT to
   compile it: a partial application made (in a call and a tail call), one
   entered with what it wants (one more, two more; in a call and a tail
   call), a closure of one over-applied (in a call and a tail call), a
   partial application given fewer than it wants, a closure of two given
   three; exceptions through each; and partial applications enough that
   the nursery fills under them *)
val f3 : (int -> int -> int -> int) ref = ref (fn a => fn b => fn c => a + 2 * b + 3 * c)
val g1 : (int -> int -> int) ref = ref (fn a => (if a < 0 then print "neg\n" else (); fn b => a - b))
val h2 : (int -> int -> int -> int) ref = ref (fn a => fn b => (if b < 0 then print "neg\n" else (); fn c => a * 100 + b * 10 + c))
val boom : (int -> int -> int) ref = ref (fn a => fn b => if a = b then raise Fail "equal" else a div (b - a))

val call1 = ref (fn (f : int -> int -> int -> int) => fn a => let val p = f a in p end)
val tail1 = ref (fn (f : int -> int -> int -> int) => fn a => f a)
val call2 = ref (fn (f : int -> int -> int) => fn a => fn b => (f a b) + 0)
val tail2 = ref (fn (f : int -> int -> int) => fn a => fn b => f a b)
val call1v = ref (fn (f : int -> int) => fn a => (f a) + 0)
val tailp = ref (fn (f : int -> int -> int) => fn a => f a)
val tail1v = ref (fn (f : int -> int) => fn a => f a)
val call3 = ref (fn (f : int -> int -> int -> int) => fn a => fn b => fn c => (f a b c) + 0)
val call2p = ref (fn (f : int -> int -> int -> int) => fn a => fn b => let val p = f a b in p end)
val tail2p = ref (fn (f : int -> int -> int -> int) => fn a => fn b => f a b)
val callp = ref (fn (f : int -> int -> int) => fn a => let val p = f a in p end)

fun loop n acc k = if n = 0 then acc else loop (n - 1) ((acc + k n) mod 1000000007) k

val n = 3000
val s1 = loop n 0 (fn i => !call2 (!call1 (!f3) i) i 1)
val s2 = loop n 0 (fn i => !tail2 (!tail1 (!f3) i) 2 i)
val s3 = loop n 0 (fn i => !call1v (!call2p (!f3) i 3) 4)
val s4 = loop n 0 (fn i => !tail1v (!tail2p (!f3) i 5) i)
val s5 = loop n 0 (fn i => !call2 (!g1) i 3)
val s6 = loop n 0 (fn i => !tail2 (!g1) 9 i)
val s7 = loop n 0 (fn i => !call1v (!callp (!call1 (!f3) i) 2) 3)
val s8 = loop 1000 0 (fn i => !call3 (!h2) i 2 3)
val s11 = loop n 0 (fn i => !tail1v (!tailp (!tail1 (!f3) 7) i) 3)
fun safe th = th () handle Fail _ => 1 | Div => 2
val s9 = loop 1000 0 (fn i => safe (fn () => !call2 (!boom) (i mod 3) 1) + safe (fn () => !tail2 (!boom) 2 (i mod 4)))
val paps = List.tabulate (5000, fn i => !tail1 (!f3) i)
val s10 = List.foldl (fn (p, acc) => (acc + !tail2 p 1 2) mod 1000000007) 0 paps
val () = List.app (fn s => print (Int.toString s ^ "\n")) [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11]
