(* MLton b15e2d289c3d701131733665a74e2dd8438410b6, source and changes in PROVENANCE.md.
   Copyright and permission notice retained in LICENSE. *)
structure Benchmark =
struct
  val name = "wc-scanStream"
  fun run [size, reps] =
        let val n = BenchInput.between (1, 1000000) (BenchInput.integer size)
            val count = BenchInput.between (1, 1000) (BenchInput.integer reps)
            val path = OS.FileSys.tmpName ()
            val out = TextIO.openOut path
            val _ = TextIO.output (out, String.implode (List.tabulate (n, fn i => if i mod 10 = 0 then #"\n" else #"a")))
            val _ = TextIO.closeOut out
            fun countFile () =
              let val ins = TextIO.openIn path
                  fun scan reader state =
                    let fun loop (s, total) = case reader s of
                          NONE => SOME (total, s)
                        | SOME (c, next) => loop (next, if c = #"\n" then total + 1 else total)
                    in loop (state, 0) end
                  val result = TextIO.scanStream scan ins handle e => (TextIO.closeIn ins; raise e)
              in TextIO.closeIn ins; case result of SOME n => n | NONE => raise Fail "scanner" end
            fun one () = let val found = countFile ()
                         in if found = (n + 9) div 10 then found else raise Fail "line count" end
            val result = BenchInput.repeat count one handle e => (OS.FileSys.remove path; raise e)
            val _ = OS.FileSys.remove path
        in IntInf.toString result end
    | run _ = raise Fail "wc expects input bytes repetitions"
end
