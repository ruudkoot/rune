(* A register that is dead while its frame waits for a call is not a root of
   a collection (docs/runtime.md, the roots): what the frame needs when the
   call returns -- in the next instruction, after a loop's back edge, in a
   handler the callee raises into -- is there, and what it does not need is
   gone without harm. Run with a collection at every allocation. *)
fun churn 0 = [] | churn n = (n, Int.toString n) :: churn (n - 1)
fun sum xs = List.foldl (op +) 0 xs
fun mk n = List.tabulate (n, fn i => i * i)

(* live after the call, and dead after it *)
fun across () =
  let val kept = mk 20
      val dropped = mk 30
      val a = sum dropped              (* the last use of dropped *)
      val _ = churn 50
  in a + sum kept end
val () = print (Int.toString (across ()) ^ "\n")

(* needed by the handler alone *)
exception Out of int
fun raises n = (ignore (churn 20); raise Out n)
fun handled () =
  let val forHandler = mk 10
      val s = "handler"
  in (raises 7; 0) handle Out k => k + sum forHandler + size s end
val () = print (Int.toString (handled ()) ^ "\n")

(* a handler further out, with frames between that wait and need nothing *)
fun inner n = if n = 0 then raises 3 else 1 + inner (n - 1)
fun outer () =
  let val v = Vector.fromList (mk 8)
  in inner 25 handle Out k => k + Vector.foldl (op +) 0 v end
val () = print (Int.toString (outer ()) ^ "\n")

(* around a loop: live at the back edge, dead after the last turn *)
fun loop (0, acc, _) = acc
  | loop (n, acc, xs) = loop (n - 1, acc + length (churn 5) + hd xs, tl xs @ [hd xs])
val () = print (Int.toString (loop (40, 0, mk 6)) ^ "\n")

(* in the arms of a case, and in a closure made after the call *)
datatype t = A of int list | B of string | C
fun arms x =
  case x of
      A xs => let val n = length (churn 10) in fn () => n + sum xs end
    | B s => let val ys = mk 5 val n = length (churn 10) in fn () => n + size s + sum ys end
    | C => (ignore (churn 10); fn () => 0)
val () = print (String.concatWith " " (map (fn x => Int.toString (arms x ())) [A (mk 4), B "four", C]) ^ "\n")

(* a number that is a box, and a real that is one, across a call *)
fun boxes () =
  let val w : Word64.word = 0wxFEDCBA9876543210
      val i : Int64.int = ~9223372036854775807
      val r = 4.9E~324
      val z = ~0.0
      val _ = churn 30
  in Word64.toString w ^ " " ^ Int64.toString i ^ " " ^ Real.toString (r * 2.0) ^ " " ^ Bool.toString (Real.signBit z) end
val () = print (boxes () ^ "\n")

(* more registers than the 64 the liveness follows: the rest are roots *)
fun wide () =
  let
    val a1 = mk 1 val a2 = mk 2 val a3 = mk 3 val a4 = mk 4 val a5 = mk 5 val a6 = mk 6 val a7 = mk 7 val a8 = mk 8
    val b1 = mk 1 val b2 = mk 2 val b3 = mk 3 val b4 = mk 4 val b5 = mk 5 val b6 = mk 6 val b7 = mk 7 val b8 = mk 8
    val c1 = mk 1 val c2 = mk 2 val c3 = mk 3 val c4 = mk 4 val c5 = mk 5 val c6 = mk 6 val c7 = mk 7 val c8 = mk 8
    val d1 = mk 1 val d2 = mk 2 val d3 = mk 3 val d4 = mk 4 val d5 = mk 5 val d6 = mk 6 val d7 = mk 7 val d8 = mk 8
    val e1 = mk 1 val e2 = mk 2 val e3 = mk 3 val e4 = mk 4 val e5 = mk 5 val e6 = mk 6 val e7 = mk 7 val e8 = mk 8
    val f1 = mk 1 val f2 = mk 2 val f3 = mk 3 val f4 = mk 4 val f5 = mk 5 val f6 = mk 6 val f7 = mk 7 val f8 = mk 8
    val g1 = mk 1 val g2 = mk 2 val g3 = mk 3 val g4 = mk 4 val g5 = mk 5 val g6 = mk 6 val g7 = mk 7 val g8 = mk 8
    val h1 = mk 1 val h2 = mk 2 val h3 = mk 3 val h4 = mk 4 val h5 = mk 5 val h6 = mk 6 val h7 = mk 7 val h8 = mk 8
    val i1 = mk 1 val i2 = mk 2 val i3 = mk 3 val i4 = mk 4 val i5 = mk 5 val i6 = mk 6 val i7 = mk 7 val i8 = mk 8
    val _ = churn 40
    val all = [a1, a2, a3, a4, a5, a6, a7, a8, b1, b2, b3, b4, b5, b6, b7, b8, c1, c2, c3, c4, c5, c6, c7, c8,
               d1, d2, d3, d4, d5, d6, d7, d8, e1, e2, e3, e4, e5, e6, e7, e8, f1, f2, f3, f4, f5, f6, f7, f8,
               g1, g2, g3, g4, g5, g6, g7, g8, h1, h2, h3, h4, h5, h6, h7, h8, i1, i2, i3, i4, i5, i6, i7, i8]
  in sum (map sum all) end
val () = print (Int.toString (wide ()) ^ "\n")
