(* A program that puts itself away and is taken up again.

   Run it once: it writes checkpoint.img and stops. Then
   `runevm --restore checkpoint.img` carries it on from inside the same call,
   as often as you like -- the image is a file, not a process, and it is not
   used up by being restored.

   The image is of no particular machine: one written by bin/runevm is
   restored by bin/runevm32.exe. *)

fun primes limit =
  let
    fun sieve ([], acc) = List.rev acc
      | sieve (p :: rest, acc) =
          sieve (List.filter (fn n => n mod p <> 0) rest, p :: acc)
  in
    sieve (List.tabulate (limit - 1, fn i => i + 2), [])
  end

val found = primes 2000
val () = print ("found " ^ Int.toString (List.length found) ^ " primes below 2000\n")

val () =
  case Runtime.save "checkpoint.img" of
    Runtime.Saved =>
      print "written to checkpoint.img; run: runevm --restore checkpoint.img\n"
  | Runtime.Restored =>
      let
        val biggest = List.foldl Int.max 0 found
      in
        print ("taken up again, with the " ^ Int.toString (List.length found)
               ^ " primes still in hand; the biggest is " ^ Int.toString biggest ^ "\n");
        print ("this world has run " ^ Int.toString (#instructions (Runtime.stats ()))
               ^ " instructions, the ones the saved world had and the ones since\n")
      end
