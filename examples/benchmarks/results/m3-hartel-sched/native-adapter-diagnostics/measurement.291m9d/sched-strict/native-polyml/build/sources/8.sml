(* Portable measurement entrypoint. Host-specific exports call main; loading
   these declarations never executes a benchmark. Every retained round is
   validated, including the first rounds of repeated in-process execution. *)
structure BenchMeasure =
struct
  fun print text = TextIO.output (TextIO.stdOut, text)
  fun line () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => raise Fail "missing measurement input"
    | SOME s =>
        if String.size s > 0 andalso String.sub (s, String.size s - 1) = #"\n"
        then String.substring (s, 0, String.size s - 1) else s

  fun main () =
    (let
       val name = line ()
       val _ = if name = Benchmark.name then () else raise Fail "benchmark name mismatch"
       val args = String.tokens Char.isSpace (line ())
       val expected = line ()
       val rounds = BenchInput.between (1,100000) (BenchInput.integer (line ()))
       fun run i =
         if i > rounds then ()
         else
           let
             val start = Time.now ()
             val result = Benchmark.run args
             val elapsed = Time.- (Time.now (), start)
             val _ = print ("RESULT " ^ result ^ "\n")
             val _ = if result = expected then () else raise Fail "incorrect result"
             val _ = print ("PASS " ^ name ^ "\n")
             val _ = print ("SAMPLE " ^ Int.toString i ^ " " ^
                            Time.fmt 9 elapsed ^ "\n")
           in run (i + 1) end
       val _ = run 1
       val _ = print ("SUMMARY " ^ Int.toString rounds ^ " checks, 0 failed\n")
     in OS.Process.success end)
    handle e =>
      (print ("FAIL " ^ Benchmark.name ^ " -- " ^ General.exnMessage e ^
              "\nSUMMARY 1 checks, 1 failed\n"); OS.Process.failure)
end
