(* requires: Runtime *)
(* Runtime matches RUNTIME, which is Rune's own signature and has no
   transcription under spec-sigs: `stats` is a record of nine ints, named in
   the signature as in the structure, and nothing is abstract. *)
structure TestRuntimeSig =
struct
  val () = T.check ("Runtime:RUNTIME/stats-is-a-record-of-nine-ints",
                    fn () =>
                      let
                        val s : Runtime.stats = Runtime.stats ()
                        val {instructions, bytes, objects, collections, live, heapSize,
                             minorCollections, majorCollections, promoted} = s
                        val n : int = instructions + bytes + objects + collections + live + heapSize
                                      + minorCollections + majorCollections + promoted
                      in
                        n > 0
                      end)
end
