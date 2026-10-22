structure MeasureIntInfDispatch =
struct
  open MeasureIntInfCommon
  fun main args =
    let val opts=options args val ()=checkedOptions ["--samples","--out","--baseline-root","--workload","--reuse-run"] opts
        val samples=samples opts "7" val output=fromRoot (option opts "--out" "tests/out/intinf/dispatch") val ()=mkdirs output val run=runner output
        val base=option opts "--baseline-root" "" val base=if base="" then "" else fromRoot base
        val reuse=option opts "--reuse-run" "" val reuse=if reuse="" then "" else fromRoot reuse
        val fixture=readJson (fromRoot "tests/intinf/fixtures/dispatch-v1.json") val cases=array (field "cases" fixture)
        fun name row=text (field "op" row) ^ "-" ^ intText (MeasureMMU.exact (field "bits" row)) ^ "-" ^ intText (MeasureMMU.exact (field "other_bits" row))
        val ()=List.app (fn n => need (List.exists (fn row => name row=n) cases,"unknown workload " ^ n)) (many opts "--workload")
        val report=MeasureIntInfCommon.base samples 1 val ()=current report val ()=set report "driver_sha256" (str (driver ()))
        val ()=set report "description" (str "Exploratory dispatch sweep, independent of the fixed acceptance corpus")
        val baseline=if base="" then NONE else SOME (obj [("root",str base),("vm_sha256",str (hash (base ^ "/bin/runevm"))),("compiler_sha256",str (hash (base ^ "/bin/rune.rbc")))])
        val ()=case baseline of NONE => () | SOME value => set report "baseline" value
        val original=if reuse="" then NONE else SOME (readJson (reuse ^ "/report.json"))
        val ()=case original of NONE => () | SOME old =>
          (List.app (fn key => need (field key old=field key (obj (!report)),"changed reuse input: " ^ key)) ["vm_sha256","compiler_sha256","source_hashes"];
           need (Json.member ("baseline",old)=baseline,"changed reuse baseline");set report "reused_report_sha256" (str (hash (reuse ^ "/report.json"))))
        fun one row =
          let val name=name row
          in if not (selected opts name) then () else
            let val source=text (field "source" row) val expected=text (field "expected" row) val dir=if reuse="" then output else reuse
                val path=dir ^ "/" ^ name ^ ".sml" val program=dir ^ "/" ^ name ^ ".rbc" val old=dir ^ "/" ^ name ^ "-baseline.rbc"
                val retainedEntry=case original of NONE => obj [] | SOME original => field name (field "workloads" original)
                val ()=if reuse="" then (write (path,source);ignore (run root [fromRoot "bin/rune","--lib","lib","-o",program,path])) else
                    (need (binary path=source,"changed reuse source");need (hash program=text (field "current" (field "bytecode_sha256" retainedEntry)),"changed reuse bytecode"))
                val ()=if base="" then () else if reuse="" then ignore (run base [base ^ "/bin/rune","--lib","lib","-o",old,path])
                       else need (hash old=text (field "baseline" (field "bytecode_sha256" retainedEntry)),"changed reuse baseline bytecode")
                val modes=["gmp","sml"] @ (if base="" then [] else ["baseline"])
                val runs=List.map (fn mode => (mode,ref [])) modes
                fun sample side measured=
                  let val cmd=if side="baseline" then [base ^ "/bin/runevm",old] else [fromRoot "bin/runevm","--intinf=" ^ side,program]
                      val n=kernel expected (#output (run root cmd)) val destination= #2 (valOf (List.find (fn (key,_) => key=side) runs))
                  in if measured then destination:= !destination @ [n] else () end
                val ()=pairs samples 1 modes sample
                fun valuesFor mode= !(#2 (valOf (List.find (fn (key,_) => key=mode) runs)))
                val speed=median (ratios (valuesFor "sml") (valuesFor "gmp"))
                val fields=List.map (fn key => (key,field key row)) ["bits","other_bits","op","iterations"] @
                   [("runs",obj (List.map (fn (mode,runs) => (mode,values (!runs))) runs)),("paired_speedup",real speed),("expected",str expected),("source_sha256",str (hash path)),
                    ("bytecode_sha256",obj ([("current",str (hash program))] @ (if base="" then [] else [("baseline",str (hash old))])))] @
                    (if base="" then [] else [("ratios_to_baseline",obj (List.map (fn mode => (mode,real (median (ratios (valuesFor mode) (valuesFor "baseline"))))) ["gmp","sml"]))])
            in add report "workloads" name (obj fields);save output report;say (name ^ " " ^ general speed ^ "\n") end end
    in List.app one cases;0 end
end
