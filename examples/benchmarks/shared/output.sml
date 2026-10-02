(* Observe deterministic textual results without printing in timed kernels.
   Consumers must check the result; an empty trace is not a success marker. *)
structure BenchOutput =
struct
  val pieces : string list ref = ref []
  fun reset () = pieces := []
  fun put text = pieces := text :: !pieces
  fun text () = String.concat (List.rev (!pieces))
  fun summary () =
    let val value = text ()
        fun loop (i, hash) =
          if i = String.size value then hash
          else loop (i + 1, Word32.+ (Word32.* (hash, 0w16777619),
                                     Word32.fromInt (Char.ord (String.sub (value, i)))))
    in if value = "" then raise Fail "empty result trace"
       else Int.toString (String.size value) ^ " " ^ Word32.toString (loop (0, 0w2166136261)) end
end
