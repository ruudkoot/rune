(* lex.ident under --unicode: names of the identifier profile of
   lib/unicode, in Greek, Cyrillic, CJK and Devanagari, as values,
   functions, type variables, structures and long identifiers *)
structure Σ = struct
  val α = 1
  fun λ (x : int) = x + α
end
val работа = Σ.λ 41
fun 合計 (xs : int list) = List.foldl op+ 0 xs
fun ident (x : 'α) = x
val संख्या = ident (合計 [1, 2, 3])
datatype 形 = 円 of int | 四角
fun 面積 (円 r) = 3 * r * r | 面積 四角 = 1
val () = print (Int.toString работа ^ " " ^ Int.toString संख्या ^ " " ^ Int.toString (面積 (円 2)) ^ "\n")
