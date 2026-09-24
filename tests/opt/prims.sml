(* The primitives that runeopt does inline (runeopt --inlined;
   docs/native.md) on their edge cases: tests/opt runs this under
   runevm and as native code and wants the same output and the same counts.
   Each result, or the exception raised, is printed; the inline code takes
   the common case and leaves the rest -- an overflow, a divisor of zero, an
   index out of bounds, a real or a pointer for `=` -- to the primitive, and
   both are here. tests/opt also checks that the program has a PRIM of every
   primitive runeopt inlines. *)

fun show (name : string) (f : unit -> string) =
  print (name ^ ": " ^ (f () handle Overflow => "Overflow" | Div => "Div" | Subscript => "Subscript"
                                  | e => "exception " ^ exnName e) ^ "\n")

fun b (x : bool) = Bool.toString x
fun ord3 LESS = "LESS" | ord3 EQUAL = "EQUAL" | ord3 GREATER = "GREATER"

(* ---- int: int_add int_sub int_mul int_neg int_div int_mod int_quot int_rem int_lt int_le int_gt int_ge int_order *)
val maxInt = valOf Int.maxInt
val minInt = valOf Int.minInt
val ints = [0, 1, ~1, 2, ~2, 7, ~7, 3, maxInt, minInt, maxInt - 1, minInt + 1, 4611686018427387904]
fun int2 (x, y) =
  let val p = Int.toString x ^ " " ^ Int.toString y
  in
    show ("+ " ^ p) (fn () => Int.toString (x + y));
    show ("- " ^ p) (fn () => Int.toString (x - y));
    show ("* " ^ p) (fn () => Int.toString (x * y));
    show ("div " ^ p) (fn () => Int.toString (x div y));
    show ("mod " ^ p) (fn () => Int.toString (x mod y));
    show ("quot " ^ p) (fn () => Int.toString (Int.quot (x, y)));
    show ("rem " ^ p) (fn () => Int.toString (Int.rem (x, y)));
    show ("cmp " ^ p) (fn () => b (x < y) ^ b (x <= y) ^ b (x > y) ^ b (x >= y) ^ b (x = y));
    show ("compare " ^ p) (fn () => ord3 (Int.compare (x, y)))
  end
val () = List.app (fn x => List.app (fn y => int2 (x, y)) ints) ints
val () = List.app (fn x => show ("~ " ^ Int.toString x) (fn () => Int.toString (~ x))) ints

(* ---- word: word_add word_sub word_mul word_div word_mod word_lt word_le word_gt word_ge word_order word_andb word_orb word_xorb word_notb word_lsl word_lsr *)
val words = [0w0, 0w1, 0w2, 0w3, 0w7, 0w63, 0w64, 0w65, Word.fromInt ~1, Word.fromInt minInt, 0wx8000000000000001]
fun word2 (x, y) =
  let val p = Word.toString x ^ " " ^ Word.toString y
  in
    show ("w+ " ^ p) (fn () => Word.toString (x + y));
    show ("w- " ^ p) (fn () => Word.toString (x - y));
    show ("w* " ^ p) (fn () => Word.toString (x * y));
    show ("wdiv " ^ p) (fn () => Word.toString (x div y));
    show ("wmod " ^ p) (fn () => Word.toString (x mod y));
    show ("wbits " ^ p) (fn () => Word.toString (Word.andb (x, y)) ^ " " ^ Word.toString (Word.orb (x, y))
                                  ^ " " ^ Word.toString (Word.xorb (x, y)));
    show ("wshift " ^ p) (fn () => Word.toString (Word.<< (x, y)) ^ " " ^ Word.toString (Word.>> (x, y)));
    show ("wcmp " ^ p) (fn () => b (x < y) ^ b (x <= y) ^ b (x > y) ^ b (x >= y) ^ b (x = y));
    show ("wcompare " ^ p) (fn () => ord3 (Word.compare (x, y)))
  end
val () = List.app (fn x => List.app (fn y => word2 (x, y)) words) words
val () = List.app (fn x => show ("wnot " ^ Word.toString x) (fn () => Word.toString (Word.notb x))) words

(* ---- conversions: word_to_int word_to_int_x word_from_int int_to_char *)
val () = List.app (fn w => show ("toInt " ^ Word.toString w)
                                (fn () => Int.toString (Word.toInt w) ^ " " ^ Int.toString (Word.toIntX w))) words
val () = List.app (fn i => show ("fromInt " ^ Int.toString i) (fn () => Word.toString (Word.fromInt i))) ints
val () = List.app (fn i => show ("chr " ^ Int.toString i) (fn () => Int.toString (ord (chr i))))
                  [0, 1, 97, 255, 256, ~1, maxInt, minInt]

(* ---- real: real_add real_sub real_mul real_div real_neg real_lt real_le real_gt real_ge real_eq *)
val reals = [0.0, ~0.0, 1.5, ~2.25, 3.0, Real.posInf, Real.negInf, 0.0 / 0.0, 1E308, 1E~308, 5E~324,
             Real.maxFinite, Real.minPos]
fun r (x : real) = Real.toString x
fun real2 (x, y) =
  let val p = r x ^ " " ^ r y
  in
    show ("r+ " ^ p) (fn () => r (x + y));
    show ("r- " ^ p) (fn () => r (x - y));
    show ("r* " ^ p) (fn () => r (x * y));
    show ("r/ " ^ p) (fn () => r (x / y));
    show ("rcmp " ^ p) (fn () => b (x < y) ^ b (x <= y) ^ b (x > y) ^ b (x >= y) ^ b (Real.== (x, y)))
  end
val () = List.app (fn x => List.app (fn y => real2 (x, y)) reals) reals
val () = List.app (fn x => show ("r~ " ^ r x) (fn () => r (~ x) ^ " " ^ b (Real.signBit (~ x)))) reals

(* ---- char: char_ord char_lt char_le char_gt char_ge char_order *)
val chars = [#"\000", #"\001", #"a", #"b", #"\127", #"\128", #"\255"]
val () =
  List.app (fn x => List.app (fn y =>
    show ("ccmp " ^ Int.toString (ord x) ^ " " ^ Int.toString (ord y))
         (fn () => b (x < y) ^ b (x <= y) ^ b (x > y) ^ b (x >= y) ^ " " ^ ord3 (Char.compare (x, y)))) chars) chars

(* ---- poly: poly_eq, on immediates of one tag and of two, and on pointers *)
datatype t = A | B of int | C
val () = show "eq ints" (fn () => b (maxInt = maxInt) ^ b (minInt = maxInt))
val () = show "eq words" (fn () => b (0w5 = 0w5) ^ b (0w5 = Word.fromInt ~1))
val () = show "eq chars" (fn () => b (#"a" = #"a") ^ b (#"a" = #"\255"))
val () = show "eq bools" (fn () => b (true = true) ^ b (true = false))
val () = show "eq units" (fn () => b (() = ()))
val () = show "eq constructors" (fn () => b (A = A) ^ b (A = C) ^ b (A = B 1) ^ b (B 1 = B 1) ^ b (B 1 = B 2))
val () = show "eq options" (fn () => b (NONE = SOME 1) ^ b (SOME 1 = SOME 1) ^ b (NONE = (NONE : int option)))
val () = show "eq strings" (fn () => b ("abc" = "abc") ^ b ("abc" = "abd") ^ b ("" = ""))
val () = show "eq lists" (fn () => b ([1, 2] = [1, 2]) ^ b ([1] = [1, 2]) ^ b ([] = [3]))
val () = show "eq tuples" (fn () => b ((1, "x") = (1, "x")) ^ b ((1, "x") = (2, "x")))

(* ---- ref: ref_get ref_set *)
val cell = ref 41
val () = show "ref" (fn () => (cell := !cell + 1; Int.toString (!cell)))
val sref = ref "a"
val () = show "ref string" (fn () => (sref := !sref ^ "b"; !sref))

(* ---- string: string_size string_sub *)
val s = "h\000\255llo"
val () = show "size" (fn () => Int.toString (String.size s) ^ " " ^ Int.toString (String.size ""))
val () = List.app (fn i => show ("sub " ^ Int.toString i) (fn () => Int.toString (ord (String.sub (s, i)))))
                  [0, 1, 2, 5, 6, ~1, maxInt, minInt]

(* ---- vector: vector_length vector_sub *)
val vec = Vector.fromList ["x", "y", "z"]
val () = show "vlength" (fn () => Int.toString (Vector.length vec) ^ " " ^ Int.toString (Vector.length (Vector.fromList [])))
val () = List.app (fn i => show ("vsub " ^ Int.toString i) (fn () => Vector.sub (vec, i))) [0, 2, 3, ~1, minInt]

(* ---- array: array_length array_sub array_update *)
val arr = Array.fromList [10, 20, 30]
val () = show "length" (fn () => Int.toString (Array.length arr) ^ " " ^ Int.toString (Array.length (Array.fromList [])))
val () = List.app (fn i => show ("asub " ^ Int.toString i) (fn () => Int.toString (Array.sub (arr, i)))) [0, 2, 3, ~1, maxInt]
val () = List.app (fn i => show ("aupdate " ^ Int.toString i)
                                (fn () => (Array.update (arr, i, i * 2); Int.toString (Array.sub (arr, 0)))))
                  [0, 2, 3, ~1, minInt]
