(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)
(* Portable buffer/table adaptation: see knucleotide/upstream/ocaml/LICENSE.
   Kernel provenance: Sandmark knucleotide, Troestler Christophe and Mauricio Fernandez. *)
structure BenchKnucleotide =
struct
  fun for first last f =
    if first > last then () else (f first; for (first + 1) last f)

  fun dna path =
    let
      val input = TextIO.openIn path
      fun line () =
        case TextIO.inputLine input of
          NONE => raise IO.Io {name = path, function = "inputLine", cause = Fail "EOF"}
        | SOME s => if String.size s > 0 andalso String.sub (s, String.size s - 1) = #"\n"
                    then String.substring (s, 0, String.size s - 1) else s
      val capacity = ref 1000
      val buffer = ref (CharArray.array (!capacity, #"\000"))
      val used = ref 0
      fun append s =
        let
          val s = String.map Char.toUpper s
          val required = !used + String.size s
          fun grow n = if n >= required then n else grow (n * 2)
          val _ = if required <= !capacity then () else
            let val size = grow (!capacity)
                val next = CharArray.array (size, #"\000")
                val _ = for 0 (!used - 1) (fn i => CharArray.update (next, i, CharArray.sub (!buffer, i)))
            in buffer := next; capacity := size end
          val _ = for 0 (String.size s - 1) (fn i =>
            CharArray.update (!buffer, !used + i, String.sub (s, i)))
        in used := required end
      fun header () =
        let val s = line ()
        in if String.size s >= 6 andalso String.substring (s, 0, 6) = ">THREE"
           then () else header () end
      exception First
      exception End
      fun first () =
        let val s = line ()
        in if String.sub (s, 0) = #";" then first () else (append s; raise First) end
      fun rest () =
        case TextIO.inputLine input of
          NONE => ()
        | SOME raw =>
            let val s = if String.size raw > 0 andalso String.sub (raw, String.size raw - 1) = #"\n"
                        then String.substring (raw, 0, String.size raw - 1) else raw
            in if String.sub (s, 0) = #">" then raise End else (append s; rest ()) end
      val _ = (header (); (first () handle _ => ()); (rest () handle End => ()))
        handle ex => (TextIO.closeIn input; raise ex)
      val _ = TextIO.closeIn input
    in CharArray.tabulate (!used, fn i => CharArray.sub (!buffer, i)) end

  datatype bucket = Empty
    | Entry of {key : CharArray.array, count : int ref, next : bucket ref}
  type table = {buckets : bucket Array.array ref, size : int ref}
  fun create () : table = {buckets = ref (Array.array (262144, Empty)), size = ref 0}
  fun hash key =
    let fun loop i h = if i = CharArray.length key then h else
          loop (i + 1) (Word64.andb (Word64.+ (Word64.* (h, 0w5),
            Word64.fromInt (Char.ord (CharArray.sub (key, i)))), 0wx7fffffffffffffff))
    in loop 0 0w0 end
  fun index buckets key = Word64.toInt (Word64.andb (hash key,
    Word64.fromInt (Array.length buckets - 1)))
  fun equal (a, b) =
    CharArray.length a = CharArray.length b andalso
    let fun loop i = i = CharArray.length a orelse
          (CharArray.sub (a, i) = CharArray.sub (b, i) andalso loop (i + 1))
    in loop 0 end
  fun find ({buckets, ...} : table) key =
    let fun search Empty = NONE
          | search (Entry {key = k, count, next}) =
              if equal (key, k) then SOME count else search (!next)
    in search (Array.sub (!buckets, index (!buckets) key)) end
  fun clear ({buckets, size} : table) =
    if !size = 0 then () else
      (size := 0; for 0 (Array.length (!buckets) - 1) (fn i => Array.update (!buckets, i, Empty)))
  fun resize ({buckets, ...} : table) =
    let val old = !buckets
        val next = Array.array (2 * Array.length old, Empty)
        val tails = Array.array (Array.length next, Empty)
        fun transfer Empty = ()
          | transfer (entry as Entry {key, next = link, ...}) =
              let val rest = !link val i = index next key
                  val _ = case Array.sub (tails, i) of
                    Empty => Array.update (next, i, entry)
                  | Entry {next = tail, ...} => tail := entry
                  val _ = Array.update (tails, i, entry)
              in transfer rest end
        val _ = for 0 (Array.length old - 1) (fn i => transfer (Array.sub (old, i)))
        val _ = for 0 (Array.length next - 1) (fn i =>
          case Array.sub (tails, i) of Empty => () | Entry {next, ...} => next := Empty)
    in buckets := next end
  fun add (table as {buckets, size} : table) key =
    let val i = index (!buckets) key
        val copy = CharArray.tabulate (CharArray.length key, fn j => CharArray.sub (key, j))
        val _ = Array.update (!buckets, i,
          Entry {key = copy, count = ref 1, next = ref (Array.sub (!buckets, i))})
        val _ = size := !size + 1
    in if !size > 2 * Array.length (!buckets) then resize table else () end
  fun fold ({buckets, ...} : table) f initial =
    let fun chain Empty acc = acc
          | chain (Entry {key, count, next}) acc = chain (!next) (f (key, !count, acc))
        fun loop i acc = if i = Array.length (!buckets) then acc
          else loop (i + 1) (chain (Array.sub (!buckets, i)) acc)
    in loop 0 initial end
  fun counts table k input =
    let val _ = clear table val key = CharArray.array (k, #"\000")
    in for 0 (CharArray.length input - k) (fn i =>
      (for 0 (k - 1) (fn j => CharArray.update (key, j, CharArray.sub (input, i + j)));
       case find table key of SOME n => n := !n + 1 | NONE => add table key)) end
  fun keyString key = String.implode (List.tabulate (CharArray.length key, fn i => CharArray.sub (key, i)))
  fun sort xs =
    let fun precedes ((a, x : real), (b, y)) = x > y orelse (Real.== (x, y) andalso String.compare (a, b) = LESS)
        fun merge ([], ys) = ys | merge (xs, []) = xs
          | merge (x :: xs, y :: ys) = if precedes (x, y) then x :: merge (xs, y :: ys) else y :: merge (x :: xs, ys)
        fun split [] = ([], []) | split [x] = ([x], [])
          | split (x :: y :: xs) = let val (a, b) = split xs in (x :: a, y :: b) end
        fun loop [] = [] | loop [x] = [x]
          | loop xs = let val (a, b) = split xs in merge (loop a, loop b) end
    in loop xs end
  fun run path emit =
    let val input = dna path val table = create ()
        fun frequencies k =
          let val _ = counts table k input
              val total = Real.fromInt (fold table (fn (_, n, acc) => n + acc) 0)
              val values = fold table (fn (key, n, acc) =>
                (keyString key, 100.0 * Real.fromInt n / total) :: acc) []
          in List.app (fn (key, value) => emit (key ^ " " ^ Real.fmt (StringCvt.FIX (SOME 3)) value ^ "\n")) (sort values);
             emit "\n" end
        fun count pattern =
          let val k = String.size pattern val _ = counts table k input
              val key = CharArray.tabulate (k, fn i => String.sub (pattern, i))
              val n = case find table key of NONE => 0 | SOME n => !n
          in emit (Int.toString n ^ "\t" ^ pattern ^ "\n") end
    in List.app frequencies [1, 2];
       List.app count ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"] end
end
