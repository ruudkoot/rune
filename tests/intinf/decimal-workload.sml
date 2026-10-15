(* Decimal-formatting phase benchmark; compile with --allow-prim --library pretty.
   Arguments: squaring count, multiplication repetitions, output file.
   A negative count selects a square with exactly 50,000 decimal digits.
   Times exclude setup, one warm-up and collection before each phase.
   Output bytes are retained for an independent correctness check. *)
val args = CommandLine.arguments ()
val n = valOf (Int.fromString (List.nth(args,0)))
val mulReps = valOf (Int.fromString (List.nth(args,1)))
val output = List.nth(args,2)
val clock = _prim "rt_clock_ns" : unit -> int
val seed : IntInf.int = 3472347895
fun squares (0,x) = x | squares (n,x) = squares(n-1,IntInf.*(x,x))
val operand = if n < 0 then IntInf.-(IntInf.<<(IntInf.fromInt 1,0w83047),IntInf.fromInt 1)
              else squares(n,seed)
val product = ref (IntInf.fromInt 0)
val decimal = ref ""
val rendered = ref ""
fun repeat (0,f) = () | repeat(n,f) = (f (); repeat(n-1,f))
fun measure (name,reps,f) =
  let
    val () = f ()
    val () = Runtime.collect ()
    val startStats = Runtime.stats ()
    val start = clock ()
    val () = repeat(reps,f)
    val elapsed = clock()-start
    val after = Runtime.stats ()
  in
    print (name ^ " " ^ Int.toString reps ^ " " ^ Int.toString elapsed ^ " " ^
           Int.toString (#bytes after - #bytes startStats) ^ " " ^
           Int.toString (#collections after - #collections startStats) ^ "\n")
  end
val () = measure("multiply",mulReps,fn () => product := IntInf.*(operand,operand))
val () = measure("decimal",1,fn () => decimal := IntInf.toString (!product))
val document = Pretty.concat [Pretty.text "val it = ",
  Pretty.annotate ("syn.number", Pretty.text (!decimal)),
  Pretty.group (Pretty.nest 2 (Pretty.concat [Pretty.line, Pretty.text ": IntInf.int"]))]
val () = measure("layout",10,fn () => rendered := Pretty.render 80 document)
val sink = TextIO.openOut "/dev/null"
val () = measure("write",10,fn () => (TextIO.output(sink,!rendered); TextIO.flushOut sink))
val () = TextIO.closeOut sink
val () = print("digits " ^ Int.toString(String.size (!decimal)) ^ "\n")
val out = TextIO.openOut output
val () = TextIO.output(out,!decimal)
val () = TextIO.closeOut out
