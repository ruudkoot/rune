(* The values of the top-level environment. Compiled before every program,
   so this file names no structure: everything is written on primitives, and
   List, String, Char, Real, Vector and Option take their members of the same
   name from here. *)

fun not true = false
  | not false = true

fun ignore _ = ()

fun (f o g) x = f (g x)

fun a before b = a

fun getOpt (SOME v, _) = v
  | getOpt (NONE, d) = d

fun isSome (SOME _) = true
  | isSome NONE = false

fun valOf (SOME v) = v
  | valOf NONE = raise Option

val print = _prim "print" : string -> unit

(* ---- lists ---- *)
fun null [] = true
  | null _ = false

fun hd (x :: _) = x
  | hd [] = raise Empty

fun tl (_ :: xs) = xs
  | tl [] = raise Empty

fun length l =
  let fun go ([], n) = n
        | go (_ :: xs, n) = go (xs, n + 1)
  in go (l, 0) end

fun rev l =
  let fun go ([], acc) = acc
        | go (x :: xs, acc) = go (xs, x :: acc)
  in go (l, []) end

fun [] @ ys = ys
  | (x :: xs) @ ys = x :: (xs @ ys)

fun app f [] = ()
  | app f (x :: xs) = (f x; app f xs)

fun map f [] = []
  | map f (x :: xs) = f x :: map f xs

fun foldl f init [] = init
  | foldl f init (x :: xs) = foldl f (f (x, init)) xs

fun foldr f init [] = init
  | foldr f init (x :: xs) = f (x, foldr f init xs)

(* ---- strings and characters ---- *)
val size = _prim "string_size" : string -> int
val op ^ = _prim "string_concat" : string * string -> string
val str = _prim "string_from_char" : char -> string
val concat = _prim "string_concat_list" : string list -> string
val implode = _prim "string_implode" : char list -> string
val explode = _prim "string_explode" : string -> char list
val substring = _prim "string_extract" : string * int * int -> string
val ord = _prim "char_ord" : char -> int
val chr = _prim "int_to_char" : int -> char

(* ---- reals and vectors ---- *)
val real = _prim "int_to_real" : int -> real
val floor = _prim "real_floor" : real -> int
val ceil = _prim "real_ceil" : real -> int
val round = _prim "real_round" : real -> int
val trunc = _prim "real_trunc" : real -> int
val vector = _prim "vector_from_list" : 'a list -> 'a vector

(* ---- exceptions ---- *)
val exnName = _prim "exn_name" : exn -> string

(* "will at least contain the string exnName ex" *)
fun exnMessage (Fail s) = "Fail: " ^ s
  | exnMessage e = exnName e
