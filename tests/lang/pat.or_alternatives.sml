(* Or-patterns (compiled with --or-patterns, pat.or_alternatives.cargs):
   in fun clauses, case, fn and val, nested, layered, over constants and
   tuples, and binding variables in every alternative. *)
datatype color = Red | Green | Blue | Rgb of int * int * int
fun warm (Red | Rgb (_, 0, 0)) = true
  | warm (Green | Blue | Rgb _) = false
val () = print (String.concatWith " " (List.map (Bool.toString o warm) [Red, Rgb (9, 0, 0), Rgb (9, 1, 0), Blue]) ^ "\n")
fun name c = case c of (Red | Green) => "rg" | Blue => "b" | Rgb (r, _, _) => "rgb" ^ Int.toString r
val () = print (String.concatWith " " (List.map name [Red, Green, Blue, Rgb (7, 1, 1)]) ^ "\n")
datatype t = A of int | B of int | C of string * int
fun num (A n | B n | C (_, n)) = n
val () = print (String.concatWith " " (List.map (Int.toString o num) [A 1, B 2, C ("c", 3)]) ^ "\n")
(* the first alternative that matches binds the variables *)
fun either ((0, y) | (y, _)) = y
val () = print (String.concatWith " " (List.map (Int.toString o either) [(0, 5), (6, 0), (2, 3)]) ^ "\n")
fun last ([x] | [_, x] | [_, _, x]) = x | last _ = ~1
val () = print (String.concatWith " " (List.map (Int.toString o last) [[1], [2, 9], [8, 8, 3], []]) ^ "\n")
fun small ((1 | 2 | 3), (#"a" | #"b")) = true | small _ = false
val () = print (String.concatWith " " (List.map (Bool.toString o small) [(2, #"b"), (4, #"a"), (1, #"c")]) ^ "\n")
fun keep (x as (Red | Blue)) = x | keep _ = Green
val () = print (name (keep Blue) ^ " " ^ name (keep (Rgb (0, 0, 0))) ^ "\n")
val f = fn (A x | B x) => x | C (s, x) => size s + x
val (A y | B y | C (_, y)) = B 40
val ((z, 0) | (0, z)) = (0, 2)
val () = print (Int.toString (f (C ("ab", 1)) + y + z) ^ "\n")
fun deep (SOME (A _ | B _) | NONE) = "short" | deep (SOME (C (s, _))) = s
val () = print (deep NONE ^ " " ^ deep (SOME (B 1)) ^ " " ^ deep (SOME (C ("long", 0))) ^ "\n")
