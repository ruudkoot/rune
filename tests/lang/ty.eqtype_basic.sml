(* equality types (Section 4.4, Appendix C) *)
fun eq (x, y) = x = y                  (* ''a * ''a -> bool *)
val () = print (Bool.toString (eq (1, 1)) ^ Bool.toString (eq ("a", "b")) ^ "\n")
fun ''a member (x : ''a, ys : ''a list) = List.exists (fn y => y = x) ys
val () = print (Bool.toString (member (3, [1, 2, 3])) ^ "\n")
(* datatypes admit equality when their constructor arguments do *)
datatype color = Red | Green of int
val () = print (Bool.toString (Green 1 = Green 1) ^ Bool.toString (Red <> Green 0) ^ "\n")
(* refs and arrays admit equality whatever they contain *)
val r = ref (fn x => x + 1)
val a : (int -> int) array = Array.fromList [fn x => x]
val () = print (Bool.toString (r = r) ^ Bool.toString (a = a) ^ Bool.toString (r <> ref (fn x => x)) ^ "\n")
(* an eqtype specification matched by a datatype, and ''a in a signature *)
structure S : sig eqtype t val mk : int -> t val same : ''a * ''a -> bool end =
struct datatype t = T of int fun mk n = T n fun same (x, y) = x = y end
val () = print (Bool.toString (S.mk 1 = S.mk 1) ^ Bool.toString (S.same (1.0 < 2.0, true)) ^ "\n")
(* equality on tuples, records, lists, options, strings, chars, words *)
val () = print (Bool.toString ((1, "a") = (1, "a") andalso {x = 0w1} = {x = 0w1} andalso [#"a"] = [#"a"] andalso SOME 1 <> NONE) ^ "\n")
