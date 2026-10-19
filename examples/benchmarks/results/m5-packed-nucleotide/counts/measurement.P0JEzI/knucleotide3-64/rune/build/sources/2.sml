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
   Kernel provenance: Sandmark knucleotide3; full notices retained with the benchmark. *)
functor BenchKnucleotidePackedFn (P : sig val threshold : int end) =
struct
  fun for first last f =
    if first > last then () else (f first; for (first + 1) last f)

  fun code c = case c of #"A" => 0 | #"a" => 0 | #"T" => 1 | #"t" => 1
    | #"C" => 2 | #"c" => 2 | #"G" => 3 | #"g" => 3 | _ => 0

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
          val s = String.map (fn c => Char.chr (code c)) s
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

  datatype key = Small of Word64.word | Large of Word64.word * Word64.word
  datatype bucket = Empty
    | Entry of {key : key, count : int ref, next : bucket ref}
  type table = {buckets : bucket Array.array ref, size : int ref}
  fun create () : table = {buckets = ref (Array.array (262144, Empty)), size = ref 0}
  fun hash (Small n) = n | hash (Large (first, _)) = first
  fun index buckets key = Word64.toInt (Word64.andb (hash key,
    Word64.fromInt (Array.length buckets - 1)))
  fun equal (first : key, second) = first = second
  fun find ({buckets, ...} : table) key =
    let fun search Empty = NONE
          | search (Entry {key = k, count, next}) =
              if equal (key, k) then SOME count else search (!next)
    in search (Array.sub (!buckets, index (!buckets) key)) end
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
        val copy = key
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
  fun pack source at k =
    let fun part pos remaining value =
          let val next = Word64.+ (Word64.* (value, 0w4), source pos)
          in if remaining > 1 then part (pos + 1) (remaining - 1) next else next end
    in if k <= P.threshold then Small (part at k 0w0)
       else Large (part at P.threshold 0w0, part (at + P.threshold) (k - P.threshold) 0w0)
    end
  fun packDna input k at = pack (fn i => Word64.fromInt (Char.ord (CharArray.sub (input, i)))) at k
  fun packKey text = pack (fn i => Word64.fromInt (code (String.sub (text, i)))) 0 (String.size text)
  fun counts table k input =
    for 0 (CharArray.length input - k - 1) (fn i =>
      let val key = packDna input k i
      in case find table key of SOME n => n := !n + 1 | NONE => add table key end)
  fun keyString k key =
    let val output = CharArray.array (k, #"A")
        val letters = "ATCG"
        fun unpack value pos remaining =
          let val at = pos - 1
              val digit = Word64.toInt (Word64.andb (value, 0w3))
              val _ = CharArray.update (output, at, String.sub (letters, digit))
          in if remaining > 1 then unpack (Word64.>> (value, 0w2)) at (remaining - 1) else () end
        val _ = case key of Small value => unpack value k k
          | Large (first, second) =>
              (unpack first P.threshold P.threshold; unpack second k (k - P.threshold))
    in CharArray.vector output end
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
    let val input = dna path
        val small = create () val large = create ()
        fun table k = if k <= P.threshold then small else large
        fun frequencies k =
          let val selected = table k
              val _ = counts selected k input
              val total = Real.fromInt (fold selected (fn (_, n, acc) => n + acc) 0)
              val values = fold selected (fn (key, n, acc) =>
                (keyString k key, 100.0 * Real.fromInt n / total) :: acc) []
          in List.app (fn (key, value) => emit (key ^ " " ^ Real.fmt (StringCvt.FIX (SOME 3)) value ^ "\n")) (sort values);
             emit "\n" end
        fun count pattern =
          let val k = String.size pattern val selected = table k
              val _ = counts selected k input
              val key = packKey pattern
              val n = case find selected key of NONE => 0 | SOME n => !n
          in emit (Int.toString n ^ "\t" ^ pattern ^ "\n") end
    in List.app frequencies [1, 2];
       List.app count ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"] end
end
