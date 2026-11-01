(* The program the lints' negative tests corrupt (RUNE_FAULT,
   lib/compiler/backend/fault.sml; tests/runner/tools.sml, compiler/faults):
   a place of each kind of fault, after each stage -- constructors and
   their tags, an exception's payload, primitives, constants, handlers,
   closures and known calls, a functor's slots and its parameter's
   constructor of an abstract type (functor_cast, open_cast), an exception
   of a function's type variable (type-checker.md's open case), a
   declaration of the top level that sets two globals (a Do), and a field
   of a tuple a function is given (a Select in Low). *)
datatype shape = Circle of int | Rect of int * int | Tri of int * int * int | Dot
fun area s = case s of Circle r => 3 * r * r | Rect (w, h) => w * h | Tri (a, b, c) => a + b + c | Dot => 0
exception Bad of int
fun check n = if n > 100 then raise Bad n else n
fun safe n = check n handle Bad m => m - 100
fun adder k = fn x => x + k
fun sum (f, xs) = List.foldl (fn (x, acc) => f x + acc) 0 xs
fun 'a first (x : 'a) : 'a = let exception E of 'a in (raise E x) handle E y => y end

signature S = sig
  type info
  datatype t = C of info | D
  val mk : int -> info
  val show : info -> string
end
functor F (X : S) = struct
  fun build n = if n = 0 then X.D else X.C (X.mk n)
  fun look v = case v of X.C i => "C " ^ X.show i | X.D => "D"
end
structure Flat = struct
  type info = int * int
  datatype t = C of info | D
  fun mk n = (n, n + 1)
  fun show (a, b) = Int.toString a ^ "," ^ Int.toString b
end
structure A = F (Flat)

val (lo, hi) = if safe 150 > 0 then (first 1, 2) else (3, first 4)
val shapes = [Circle 2, Rect (3, 4), Tri (1, 2, 3), Dot, Circle 5]
val total = List.foldl (fn (s, acc) => area s + acc) 0 shapes
val () = print (Int.toString total ^ " " ^ Int.toString (safe 150) ^ " " ^ Int.toString (sum (adder 10, [lo, hi, 3]))
                ^ " " ^ first "a" ^ " " ^ A.look (A.build 0) ^ " " ^ A.look (A.build 5) ^ "\n")
val fs = List.map adder [1, 2, 3]
val () = print (String.concatWith "," (List.map (fn f => Int.toString (f 5)) fs) ^ "\n")
val pairs = [(1, "a"), (2, "bb")]
val lens = List.map (fn p => #1 p + String.size (#2 p)) pairs
val () = print (String.concatWith "," (List.map Int.toString lens) ^ "\n")
