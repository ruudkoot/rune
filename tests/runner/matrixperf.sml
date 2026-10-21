(* Wall-clock matrix mode. Three rounds and the minimum, kept outside check
   in an exclusive runner job; deterministic instruction budgets stay separate. *)
structure MatrixPerf =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun budget name key =
    case List.filter (String.isPrefix (key ^ " ")) (lines (read (fromRoot ("tests/perf/" ^ name ^ ".budget")))) of
      [] => "" | [line] => String.extract (line, size key + 1, NONE) | _ => raise Failed ("duplicate performance field " ^ key)
  fun wrapper text repetitions cross =
    "structure CommandLine = struct fun name () = \"bench\" fun arguments () : string list = [] end\n"
    ^ "fun runeWallBody__ () = let\n" ^ text ^ "\nin () end\n"
    ^ (if cross then "val () = case Int.precision of SOME p => if p < 52 then print (\"NA the int has \" ^ Int.toString p ^ \" bits, Time needs 52\\n\") else () | NONE => ()\n"
                     ^ "val runeWallRun__ = case Int.precision of SOME p => p >= 52 | NONE => true\n"
       else "val runeWallRun__ = true\n")
    ^ "fun runeWallRound__ () = let val t = Timer.startRealTimer () fun loop 0 = () | loop k = (runeWallBody__ (); loop (k - 1))\n"
    ^ "  in loop " ^ Int.toString repetitions ^ "; Time.toMicroseconds (Timer.checkRealTimer t) end\n"
    ^ "val () = if runeWallRun__ then let val a = runeWallRound__ () val b = runeWallRound__ () val c = runeWallRound__ ()\n"
    ^ "  in print (\"TIME \" ^ LargeInt.toString (LargeInt.min (a, LargeInt.min (b, c))) ^ \"\\n\") end else ()\n"
    ^ "val () = print \"SUMMARY 0 checks\\n\"\n"
  fun collect config dir name =
    let val text = read (fromRoot ("tests/perf/" ^ name ^ ".sml"))
        val cross = MatrixLoad.kind config = "xc1"
        val repetitions = case budget name "wall" of "" => 1 | text =>
              (case Int.fromString text of SOME n => (need (n > 0, "nonpositive timing repetitions"); n) | NONE => raise Failed "invalid timing repetitions")
        val (prefix, image) = MatrixPrepare.ready config dir
        val ctx = MatrixPrepare.context config dir prefix image
        val source = dir ^ "/perf/" ^ name ^ ".sml"
        val () = mkdirs (OS.Path.dir source)
        val () = write (source, wrapper text repetitions cross)
        val dropped = List.map (fn line => hd (String.fields (fn c => c = #"\t") line)) (lines (read (dir ^ "/basis.dropped")))
        val providers = List.concat (List.map (fn line => case String.fields (fn c => c = #"\t") line of [file, names] =>
              if List.exists (fn d => d = OS.Path.file file) dropped then String.tokens Char.isSpace names else []
            | _ => raise Failed "invalid timing provider table") (lines (read (dir ^ "/basis/files"))))
        val mentioned = SmlScan.code text
        val unavailable = List.find (fn name => List.exists (fn token => token = name) mentioned
                                        orelse List.exists (fn needed => needed = name) ["Timer", "Time", "LargeInt"]) providers
        val exemption = if cross andalso budget name "noxc1" <> "" then SOME (budget name "noxc1")
                        else if cross then unavailable else NONE
        fun measure () =
          let val result = MatrixLoad.load ctx (dir ^ "/perf-" ^ name ^ ".dir") MatrixLoad.Run (prefix @ [source])
              val output = lines (#output result)
              val na = List.find (String.isPrefix "NA ") output
              val expected = lines (read (fromRoot ("tests/perf/" ^ name ^ ".expected")))
              val got = List.filter (fn line => List.exists (fn wanted => line = wanted) expected) output
              val times = List.filter (String.isPrefix "TIME ") output
          in if not (#loaded result) orelse #status result <> 0 then "FAIL " ^ MatrixPrepare.firstError (#messages result ^ #output result)
             else case na of SOME line => line | NONE =>
               if length got <> length expected * repetitions * 3 then "FAIL timing program output differs from its expected lines"
               else case times of [line] =>
                    let val value = String.extract (line, 5, NONE)
                        val () = need (value <> "" andalso CharVector.all Char.isDigit value, "invalid timing counter")
                    in line ^ " " ^ Int.toString repetitions end
                  | _ => "FAIL timing program did not print exactly one duration" end
        val output = case exemption of SOME why => "NA " ^ why | NONE => measure ()
    in MatrixPrepare.atomic (dir ^ "/perf-" ^ name ^ ".result", output ^ "\n") end
  fun report configs tests directory =
    let val errors = ref [] : string list ref
        fun cell (c : MatrixModel.config) name =
          let val text = read (directory c ^ "/perf-" ^ name ^ ".result")
          in case String.tokens Char.isSpace text of ["TIME", us, runs] =>
                (case (LargeInt.fromString us, Int.fromString runs) of (SOME us, SOME runs) =>
                     if us >= 0 andalso runs > 0 then SOME (Real.fromLargeInt us / Real.fromInt runs / 1000.0) else NONE | _ => NONE)
             | _ => NONE end
        fun render c name =
          case cell c name of SOME milliseconds =>
            let val base = case (cell c "fib", cell c "tak") of (SOME a, SOME b) =>
                      if a > 0.0 andalso b > 0.0 then SOME (Math.sqrt (a * b)) else NONE | _ => NONE
            in Real.fmt (StringCvt.FIX (SOME 2)) milliseconds ^
                (case base of NONE => "" | SOME base => " (" ^ Real.fmt (StringCvt.FIX (SOME 1)) (milliseconds / base) ^ ")") end
          | NONE => let val text = read (directory c ^ "/perf-" ^ name ^ ".result")
                        val na = String.isPrefix "NA " text
                        val () = errors := (if na then "n/a " else "error ") ^ #id c ^ " " ^ name ^ ": " ^ Hosts.trim text :: !errors
                    in if na then "n/a" else "error" end
        val architecture = getOpt (List.find (fn (key, _) => key = "machine") (Posix.ProcEnv.uname ()), ("machine", "unknown"))
        val text = "# Wall-clock times\n\nMilliseconds of one run of each program of tests/perf, on " ^ #2 architecture
          ^ " with " ^ Int.toString (Runtime.processors ()) ^ " CPUs, " ^ Date.fmt "%Y-%m-%d" (Date.fromTimeUniv (Time.now ())) ^ ".\n"
          ^ "In parentheses: the time divided by the baseline of the configuration (the geometric mean of fib and tak).\n\n"
          ^ "| Program |" ^ String.concat (List.map (fn c : MatrixModel.config => " " ^ #id c ^ " |") configs) ^ "\n|---|"
          ^ String.concat (List.map (fn _ => "---:|") configs) ^ "\n"
          ^ String.concat (List.map (fn name => "| " ^ name ^ " |" ^ String.concat (List.map (fn c => " " ^ render c name ^ " |") configs) ^ "\n") tests)
        val text = text ^ (if null (!errors) then "" else "\nNot measured:\n\n" ^ String.concat (List.map (fn line => "* " ^ line ^ "\n") (sort (!errors))))
        val file = fromRoot "tests/out/perf/wall.md"
        val () = mkdirs (OS.Path.dir file)
        val () = MatrixPrepare.atomic (file, text)
        val () = say text
        val () = List.app (fn line => if String.isPrefix "error rune " line then say ("FAIL " ^ line ^ "\n") else ()) (!errors)
    in () end
end
