(* Tier 2's homes of pointers (runtime/register/jit, performance M7): a
   register the section says holds a pointer, a constructor or anything at
   all has a machine register for its home, written back to its slot at
   every safepoint and loaded again after every call into C that may
   collect, since the collector moves what it points to. Each part keeps
   pointers live in homes across what a home must survive -- allocation
   that collects, a call into C, a known call and a closure's, a handler --
   and its answer is right only if every one was.

   The first part is E12's bug (results/B1-report.md): string_order's
   slow path loaded its arguments from their homes into the registers of
   C's arguments, rsi and rdx, and rsi is itself a home: here `b` and `a`,
   compared in that order, live in rdi and rsi, so loading b into rsi
   first made the comparison b against b, EQUAL. The strings are longer
   than the eight bytes compared in line, so that the comparison is C's. *)

fun show LESS = "<" | show EQUAL = "=" | show GREATER = ">"

fun order (a : string, b : string, c : string, n) =
  if n = 0 then [] else
  let
    val x = String.compare (b, a)
    val y = String.compare (c, b)
    val z = String.compare (a, c)
  in x :: y :: z :: order (c, a, b, n - 1) end

val () = print (String.concat (map show (order ("apple pie and more", "banana split sundae",
                                                "cherry tart is best", 3))) ^ "\n")

(* lists built, walked and rebuilt, the nursery collected many times while
   the heads and tails are in homes *)
fun build (0, acc) = acc
  | build (n, acc) = build (n - 1, (n, Int.toString n) :: acc)
fun walk ([], s, l) = (s, l)
  | walk ((k, t) :: r, s, l) = walk (r, s + k, l + size t)
fun again (0, xs, s) = s
  | again (n, xs, s) =
      let val ys = List.rev (List.map (fn (k, t) => (k + 1, t ^ "!")) xs)
          val (a, b) = walk (ys, 0, 0)
      in again (n - 1, List.rev ys, s + a + b) end
val () = print (Int.toString (again (20, build (5000, []), 0)) ^ "\n")

(* a tree: pointers to nodes in homes across the allocation of their
   children, compared and taken apart *)
datatype tree = Leaf | Node of tree * string * tree
fun insert (Leaf, s) = Node (Leaf, s, Leaf)
  | insert (t as Node (l, v, r), s) =
      case String.compare (s, v) of
        LESS => Node (insert (l, s), v, r)
      | GREATER => Node (l, v, insert (r, s))
      | EQUAL => t
fun inorder (Leaf, acc) = acc
  | inorder (Node (l, v, r), acc) = inorder (l, v :: inorder (r, acc))
fun key i = "key number " ^ Int.toString ((i * 7919) mod 1009)
fun fill (0, t) = t
  | fill (i, t) = fill (i - 1, insert (t, key i))
val keys = inorder (fill (3000, Leaf), [])
val () = print (Int.toString (length keys) ^ " " ^ hd keys ^ " " ^ List.last keys ^ "\n")

(* values of any type in one register: reals and Int64s, which tier 2
   holds raw, moved into registers the section says nothing of, boxed on
   the way where they have no immediate *)
fun pairs (f, xs) = List.map (fn x => (f x, x)) xs
fun mean (xs : real list) = foldl op+ 0.0 xs / real (length xs)
val rs = pairs (fn r => r * 1.5 + 0.1, List.tabulate (200, fn i => real i / 3.0))
val is = pairs (fn i => i * 0x7FFFFFFF + 1, List.tabulate (200, fn i => Int64.fromInt i))
val () = print (Real.fmt (StringCvt.FIX (SOME 6)) (mean (map #1 rs)) ^ " "
                ^ Int64.toString (foldl op+ 0 (map #1 is)) ^ "\n")

(* a handler: pointers in homes live across a raise that unwinds frames *)
exception Found of string
fun find (p, []) = raise Found "none"
  | find (p, x :: r) = if p x then raise Found x else find (p, r)
fun lookup (names, n) =
  (find (fn s => size s = n, names); "unreachable")
  handle Found s => s ^ "/" ^ Int.toString (length names)
val names = List.tabulate (100, fn i => String.implode (List.tabulate (i mod 13 + 1, fn _ => #"x")))
val () = print (String.concatWith " " (List.tabulate (14, fn n => lookup (names, n))) ^ "\n")
