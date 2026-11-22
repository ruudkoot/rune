(* rhc's reducer (D55; the haskell98 roadmap's *Generators and metamorphic
   relations*: "a reducer comes with the printer"): shrink a Haskell program
   while a predicate holds. The predicate is a command, run with the
   candidate's path as its last argument, in a directory of its own; it holds
   when it exits 0 (a difference between rhc and an oracle, two settings of
   rhc, a crash). Delta debugging (Zeller's ddmin) over the program's
   top-level blocks, its header kept, then over its lines; every candidate is
   a whole file, so a predicate that compiles keeps the result valid.

   `bin/rune-test hs-reduce FILE -- CMD...` writes FILE.reduced and prints
   it. hs/reduce/@self (check) reduces a program of 30 declarations under a
   predicate that rhc's parser accepts it and it still says boom, and wants
   the declaration that says it and nothing more. *)
structure HsReduce =
struct
  open Sh

  (* ddmin: a smallest sublist of xs that test holds of, to one-minimality *)
  fun ddmin (test : 'a list -> bool) (xs : 'a list) =
    let
      fun chunks (ys, n) =
        let val size = Int.max (1, (length ys + n - 1) div n)
            fun go [] = []
              | go zs = let val k = Int.min (size, length zs) in List.take (zs, k) :: go (List.drop (zs, k)) end
        in go ys end
      fun loop (ys, n) =
        if length ys <= 1 then ys
        else
          let
            val cs = chunks (ys, n)
            fun complement i = List.concat (List.take (cs, i) @ List.drop (cs, i + 1))
            fun firstChunk [] = NONE
              | firstChunk (c :: rest) = if test c then SOME c else firstChunk rest
            fun firstComplement i = if i >= length cs then NONE
                                    else let val c = complement i in if test c then SOME c else firstComplement (i + 1) end
          in
            case firstChunk cs of
              SOME c => loop (c, 2)
            | NONE =>
                (case firstComplement 0 of
                   SOME c => loop (c, Int.max (n - 1, 2))
                 | NONE => if n < length ys then loop (ys, Int.min (2 * n, length ys)) else ys)
          end
    in if test xs then loop (xs, 2) else xs end

  fun reduce (cmd, text, work) =
    let
      val () = mkdirs work
      val count = ref 0
      fun holds candidate =
        let
          val () = count := !count + 1
          val f = work ^ "/candidate.hs"
          val () = write (f, candidate)
        in exec {cmd = cmd @ [f], dir = SOME work, stdin = "", stdout = work ^ "/out", stderr = work ^ "/out", timeout = 300} = 0 end
      val (h, bs) = HsMeta.blocks text
      val bs' = ddmin (fn ys => holds (HsMeta.unblocks (h @ ys))) bs
      val ls = String.fields (fn c => c = #"\n") (HsMeta.unblocks (h @ bs'))
      val ls' = ddmin (fn ys => holds (String.concatWith "\n" ys ^ "\n")) ls
    in (String.concatWith "\n" ls' ^ "\n", !count) end

  fun reduceFile (file, cmd) () =
    let
      val text = read (fromRoot file)
      val (small, n) = reduce (cmd, text, run ^ "/hs-reduce/" ^ OS.Path.base (OS.Path.file file))
    in
      write (fromRoot file ^ ".reduced", small);
      say (small ^ "-- hs-reduce: " ^ Int.toString n ^ " candidates, " ^ Int.toString (length (lines text)) ^ " lines to "
           ^ Int.toString (length (lines small)) ^ "\n")
    end

  (* the reducer's own check, on rhc's parser *)
  fun self () =
    let
      val decls = List.tabulate (30, fn i => if i = 17 then "f17 :: Int\nf17 = boom 17" else "f" ^ Int.toString i ^ " :: Int\nf" ^ Int.toString i ^ " = " ^ Int.toString i)
      val text = "module Main (main) where\n\n" ^ String.concatWith "\n\n" decls ^ "\n\nmain :: IO ()\nmain = print f0\n"
      val cmd = ["sh", "-c", "grep -q boom \"$1\" && \"$0\"/bin/rhc --parse-only \"$1\" > /dev/null 2>&1", root]
      val (small, n) = reduce (cmd, text, run ^ "/hs-reduce/self")
      val ls = lines small
    in
      if List.exists (String.isSubstring "boom") ls andalso length ls <= 2
      then say ("PASS hs-reduce: 64 lines to " ^ Int.toString (length ls) ^ " in " ^ Int.toString n ^ " candidates\n")
      else say ("FAIL hs-reduce: the reduced program is not the one line that says boom:\n" ^ small)
    end

  fun command args =
    case args of
      "hs-reduce" :: file :: "--" :: cmd => if null cmd then NONE else SOME (reduceFile (file, cmd))
    | ["hs-reduce-self"] => SOME self
    | _ => NONE

  fun tree () =
    Test.tag "covers:tests/runner/hsreduce.sml"
      (Test.tag "check" (Test.tag "hs" (Test.describe "hs/reduce"
         [Test.requires ["rhc"] (Oracles.jobIn ("", "@self", ["hs-reduce-self"], [], 1, 600, 1800))])))
end
