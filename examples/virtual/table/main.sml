(* The program, compiled against KEY and TABLE alone: another
   implementation of Table compiles none of it again. Two applications
   make two tables and two exceptions, and each table's key is its
   parameter's. *)
structure IntKey =
struct
  type t = int
  val compare = Int.compare
  val toString = Int.toString
end

structure StringKey =
struct
  type t = string
  val compare = String.compare
  fun toString s = "\"" ^ s ^ "\""
end

structure Squares = Table (IntKey)
structure Words = Table (StringKey)

fun show (toString, entries) =
  String.concatWith ", " (List.map (fn (k, v) => k ^ " " ^ toString v) entries)

val squares = List.foldl (fn (n, t) => Squares.insert (t, n, n * n)) Squares.empty [5, 3, 8, 1, 4, 7, 9, 2, 6, 3]
val () = print (Int.toString (Squares.size squares) ^ " squares: "
                ^ show (Int.toString, List.map (fn (k, v) => (IntKey.toString k, v)) (Squares.toList squares)) ^ "\n")

val text = String.tokens Char.isSpace "the cat and the dog and the bird saw the cat"
val counts = List.foldl (fn (w, t) => Words.insert (t, w, 1 + getOpt (Words.find (t, w), 0))) Words.empty text
val () = print (Int.toString (Words.size counts) ^ " words: "
                ^ show (Int.toString, List.map (fn (k, v) => (StringKey.toString k, v)) (Words.toList counts)) ^ "\n")

val () = print ("the square of 7 is " ^ Int.toString (Squares.get (squares, 7)) ^ "\n")
val () = (ignore (Squares.get (squares, 10)); print "10 found\n")
         handle Squares.Missing k => print ("no square of " ^ IntKey.toString k ^ "\n")
(* each application has an exception of its own: Squares.Missing is not Words.Missing *)
val () = (ignore (Words.get (counts, "zebra")) handle Squares.Missing _ => print "the wrong exception\n")
         handle Words.Missing w => print ("no word " ^ StringKey.toString w ^ "\n")
