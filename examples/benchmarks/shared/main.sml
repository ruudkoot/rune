(* The input lines are the benchmark name, workload arguments and reviewed
   expected result. Reading the input at runtime also works on interactive
   hosts without exposing their launcher arguments to the benchmark. *)
structure BenchMain =
struct
  fun line () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => raise Fail "missing benchmark input"
    | SOME s =>
        if String.size s > 0 andalso String.sub (s, String.size s - 1) = #"\n"
        then String.substring (s, 0, String.size s - 1)
        else s

  fun main () =
    let
      val name = line ()
      val _ = if name = Benchmark.name then () else raise Fail "benchmark name mismatch"
      val args = String.tokens Char.isSpace (line ())
      val expected = line ()
      val result = Benchmark.run args
      val _ = print ("RESULT " ^ result ^ "\n")
    in
      if result = expected then
        (print ("PASS " ^ Benchmark.name ^ "\nSUMMARY 1 checks, 0 failed\n");
         OS.Process.exit OS.Process.success)
      else
        (print ("FAIL " ^ Benchmark.name ^ " -- expected " ^ expected ^ "\nSUMMARY 1 checks, 1 failed\n");
         OS.Process.exit OS.Process.failure)
    end

  val _ = main () handle e =>
    (print ("FAIL " ^ Benchmark.name ^ " -- " ^ General.exnMessage e ^ "\nSUMMARY 1 checks, 1 failed\n");
     OS.Process.exit OS.Process.failure)
end
