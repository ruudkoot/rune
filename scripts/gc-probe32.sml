(* The address-space probe of scripts/gc-probe32.sh: live data grows by STEP
   MiB at a time, all of it kept to the end, until the heap cannot grow or
   MAX MiB are held. After every step it prints and flushes "live N MiB", so
   the last such line is the most the program held.

   Arguments: STEP KIND MAX, where KIND is
     bytes   byte arrays of 1 MiB, one object each
     tuples  lists of 18,724 4-tuples a MiB step (a cons and its tuple are
             64 bytes: 1.14 MiB), many small objects as a program has *)
structure Probe32 =
struct
  val mib = 1048576

  datatype chunk = B of Word8Array.array | T of (int * int * int * int) list

  fun bytes k = B (Word8Array.array (mib, Word8.fromInt (k mod 256)))

  fun tuples k =
    let
      fun go (0, acc) = acc
        | go (j, acc) = go (j - 1, (k, j, k + j, k - j) :: acc)
    in T (go (18724, [])) end

  fun touch (B a) = Word8.toInt (Word8Array.sub (a, 0))
    | touch (T l) = length l

  fun say s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)

  fun number s =
    case Int.fromString s of
      SOME n => if n > 0 then n else raise Fail "probe32: a number from 1 expected"
    | NONE => raise Fail "probe32: a number expected"

  fun main [step, kind, max] =
        let
          val step = number step
          val max = number max
          val make = case kind of
                       "bytes" => bytes
                     | "tuples" => tuples
                     | _ => raise Fail "probe32: KIND is bytes or tuples"
          fun add (held, k, 0) = (held, k)
            | add (held, k, n) = add (make k :: held, k + 1, n - 1)
          fun grow (held, mibs) =
            if mibs >= max then held
            else
              let val (held, _) = add (held, mibs, step)
              in say ("live " ^ Int.toString (mibs + step) ^ " MiB\n"); grow (held, mibs + step) end
          val held = grow ([], 0)
        in
          say ("done " ^ Int.toString (List.foldl (fn (c, s) => s + touch c) 0 held) ^ "\n")
        end
    | main _ = raise Fail "usage: probe32 STEP KIND MAX"

  val _ = main (CommandLine.arguments ())
    handle Fail message => (TextIO.output (TextIO.stdErr, message ^ "\n"); OS.Process.exit OS.Process.failure)
end
