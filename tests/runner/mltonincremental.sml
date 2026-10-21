(* S44-S48 on a provisioned MLton compiler tree. Expensive builds are guarded
   by the same 14 GiB availability and 12 GiB address-space limits as before. *)
structure MLtonIncremental =
struct
  open Sh
  exception Failed of string
  fun need (ok,why) = if ok then () else raise Failed why
  fun available () =
    case List.find (String.isPrefix "MemAvailable:") (lines (read "/proc/meminfo")) of
      SOME line => (case String.tokens Char.isSpace line of [_,kb,_] => IntInf.fromString kb | _ => NONE)
    | NONE => NONE
  fun insert path prefix replacement removed =
    let fun loop [] = raise Failed ("missing MLton edit marker: " ^ prefix)
          | loop (line :: rest) = if String.isPrefix prefix line then
                line :: replacement :: (case rest of next :: tail => if next = removed then tail else rest | [] => [])
              else line :: loop rest
    in write (path,String.concatWith "\n" (loop (String.fields (fn c => c = #"\n") (read path)))) end
  fun run source output =
    let val source = fromRoot source
        val output = fromRoot output
        val list = source ^ "/mlton/mlton-rune.txt"
        val () = need (exists list, "missing prepared MLton source list " ^ list)
        val () = need (case available () of SOME kb => kb >= 14*1024*1024 | NONE => false,
                       "MLton incremental scenarios require 14 GiB available memory")
        val () = need (String.isPrefix (root ^ "/tests/out/") (OS.Path.mkCanonical output), "MLton scenario output must be under tests/out")
        val () = (rmTree output; mkdirs (output ^ "/work/mlton"))
        val work = output ^ "/work/mlton"
        val files = words list
        val () = List.app (fn file =>
          (need (file <> "" andalso not (OS.Path.isAbsolute file)
                   andalso String.isPrefix (output ^ "/work/") (OS.Path.mkCanonical (work ^ "/" ^ file))
                   andalso String.isPrefix (source ^ "/") (OS.Path.mkCanonical (source ^ "/mlton/" ^ file)),
                 "external source escapes its corpus or private work tree: " ^ file);
           need (exists (source ^ "/mlton/" ^ file), "missing external MLton source " ^ file);
           Incremental.copy (source ^ "/mlton/" ^ file) (work ^ "/" ^ file))) files
        val () = Incremental.copy list (work ^ "/files")
        val table = output ^ "/mlton.md"
        val () = write (table,"| Build | Status | Wall s | MLton units compiled |\n|---|---|---:|---:|\n")
        val errors = ref [] : string list ref
        fun build name flags =
          let val start = Runtime.clock ()
              val status = Children.exec {addressSpace=SOME (12*1024*1024*1024), cpuTime=SOME 7200,
                                         fileSize=SOME (1024*1024*1024),core=SOME 0} (unsetEnv ["FORCE_COLOR","CLICOLOR_FORCE"])
                {cmd=[fromRoot "bin/runevm","--heap-size","67108864","--heap-limit","5368709120",fromRoot "bin/rune.rbc","--lib",fromRoot "lib",
                      "--units","--type-work=1000000000"] @ flags @ files @ ["-o",output ^ "/" ^ name ^ ".rbc"],
                 dir=SOME work, stdin="",stdout=output ^ "/" ^ name ^ ".out",stderr=output ^ "/" ^ name ^ ".err",timeout=7200}
              val count = length (List.filter (fn line => String.isPrefix "rune: compiled " line andalso not (String.isSubstring "lib/basis/" line))
                                            (lines (read (output ^ "/" ^ name ^ ".err"))))
              val row = "| " ^ name ^ " | " ^ Int.toString status ^ " | " ^ Time.fmt 1 (Time.- (Runtime.clock (),start)) ^ " | " ^ Int.toString count ^ " |\n"
              val () = (append (table,row); say row)
          in if status = 0 then () else errors := name :: !errors end
        fun cached name extra = build name (extra @ ["--cache-dir",output ^ "/work/cache","--explain-rebuild"])
        val () = cached "S44-cold" []
        val () = cached "S44-warm" []
        val () = append (work ^ "/main/main.sml","val _ = ()\n")
        val () = cached "S45-leaf" []
        val () = insert (work ^ "/control/control.sml") "structure Control: CONTROL =" "struct val _ = ()" "struct"
        val () = cached "S46-root" []
        val () = insert (work ^ "/control/control-flags.sig") "signature CONTROL_FLAGS =" "   sig val runeScenarioS47: int" "   sig"
        val () = insert (work ^ "/control/control-flags.sml") "structure ControlFlags: CONTROL_FLAGS =" "struct val runeScenarioS47 = 0" "struct"
        val () = cached "S47-interface" []
        val () = insert (work ^ "/ssa/profile.fun") "functor Profile " "struct val _ = ()" "struct"
        val () = cached "S48-functor" []
        val () = cached "S44-whole-warm" ["--whole"]
        val () = build "nocache" ["--no-cache"]
        val () = need (null (!errors), "MLton incremental build failures: " ^ String.concatWith " " (List.rev (!errors)))
        val () = need (same (output ^ "/S48-functor.rbc",output ^ "/nocache.rbc"), "last warm MLton build differs from compilation without cache")
    in say ("PASS mlton incremental: final warm bytecode equals uncached build; " ^ table ^ "\n") end
end
