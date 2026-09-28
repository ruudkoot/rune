(* SML/NJ for 64 bits: a function of six arguments gets its fourth to sixth in
   a record.  When one of them is an untagged Int64.int or Word64.word, the record
   holds the raw number among pointers:
   - if the arguments are constants, the record is a literal, which the runtime
     builds with the number boxed, so the function reads the address of the box;
   - otherwise a major garbage collection takes the number for a pointer, and the
     process stops with "Fatal error -- bogus fault not in ML".
   The loop passes words with the high bit set and keeps some data alive, so that
   major collections happen: sml @SMLalloc=64k bug.sml *)
structure A = struct
  fun f (a : int, b : int, c : int, d : int, e : int, w : Word64.word) =
        Word64.+ (w, Word64.fromInt (a + b + c + d + e))
end;

structure B = struct
  val r = A.f (1, 2, 3, 4, 5, 0wx8000000000000000)
  val () = print (concat ["A.f (1, 2, 3, 4, 5, 0wx8000000000000000) = ",
                          Word64.fmt StringCvt.HEX r, ", expected 800000000000000F: ",
                          if r = 0wx800000000000000F then "ok\n" else "WRONG\n"])
  val bad = ref 0
  val keep = ref ([] : int list list)
  fun go 0 = ()
    | go k = let
        val w = Word64.orb (0wx8000000000000000, Word64.fromInt k)
        in
          if A.f (k, 1, 2, 3, 4, w) <> Word64.+ (w, Word64.fromInt (k + 10))
            then bad := !bad + 1 else ();
          if k mod 50 = 0 then keep := List.tabulate (20, fn i => i) :: !keep else ();
          if k mod 20000 = 0 then keep := [] else ();
          go (k - 1)
        end
  val () = go 2000000
  val () = print (Int.toString (!bad) ^ " of 2000000 calls wrong\n")
end;

val () = OS.Process.exit OS.Process.success;
