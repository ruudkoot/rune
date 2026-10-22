(* Test-only constant-selection libraries. The normal library remains the
   compiler control; neither specialization changes packed representation. *)
structure MeasureIntInfDesign =
struct
  open MeasureIntInfCommon
  fun once source old replacement =
    let val (prefix,suffix)=Substring.position old (Substring.full source)
        val ()=need (not (Substring.isEmpty suffix),"specialization binding is missing")
        val rest=Substring.string (Substring.triml (size old) suffix)
        val ()=need (not (String.isSubstring old rest),"specialization binding is ambiguous")
    in Substring.string prefix ^ replacement ^ rest end
  fun bytes file=Json.Number (Position.toString (OS.FileSys.fileSize file))
  fun main args =
    let val opts=options args val ()=checkedOptions ["--run","--out","--samples","--compiler-samples"] opts
        val samples=samples opts "25" val compilerSamples=integer (option opts "--compiler-samples" "25") val ()=need (compilerSamples>=2,"at least two compiler pairs are required")
        val output=fromRoot (required opts "--out") val ()=fresh output val run=runner output
        val normal=fromRoot (required opts "--run") val reference=readJson (normal ^ "/report.json") val ()=verifiedVM (fromRoot "bin/runevm") reference
        val report=base samples 2 val ()=current report
        val ()=set report "description" (str "Runtime backend selection against test-only constant-selection Basis copies; packed representation and normal compiler input are preserved.")
        val ()=set report "driver_sha256" (str (driver ())) val ()=set report "normal_report_sha256" (str (hash (normal ^ "/report.json")))
        val ()=set report "compiler_samples" (number compilerSamples) val ()=set report "modes" (obj [])
        val ()=set report "revision" (str (trim (#output (run root ["git","rev-parse","HEAD"]))))
        val primitives=List.mapPartial (fn line => case String.tokens Char.isSpace line of [] => NONE | first::_ => if String.isPrefix "#" first then NONE else SOME first) (lines (read (fromRoot "runtime/prims.def")))
        fun index [] _=raise Failed "missing IntInf capability primitive" | index (name::rest) n=if name="intinf_gmp_available" then n else index rest (n+1)
        val capability=index primitives 0
        val pattern=TerminalPattern.compile false ("PRIM(PUSH)?\\s+" ^ Int.toString capability ^ "([^0-9]|$)")
        fun count text start n=case TerminalPattern.find pattern text start of NONE => n | SOME matched => count text (#2 matched) (n+1)
        fun usageKernel result expected=merge (usage result) "kernel" (real (kernel expected (#output result)))
        fun kernelOf value=decimal (case field "kernel" value of Json.Number n => n | _ => raise Failed "invalid stored timing")
        fun timingOf key value=decimal (case field key value of Json.Number n => n | _ => raise Failed "invalid stored timing")
        fun paired warmup n sides expected command =
          let val destinations=List.map (fn side => (side,ref [])) sides
              fun sample side measured=
                let val result=command side val value=if isSome expected then usageKernel result (valOf expected) else usage result
                    val dest= #2 (valOf (List.find (fn (name,_) => name=side) destinations))
                in if measured then dest:= !dest @ [value] else () end
              val ()=pairs n warmup sides sample
          in List.map (fn (side,values) => (side,!values)) destinations end
        fun lookup key rows= #2 (valOf (List.find (fn (name,_) => name=key) rows))
        fun mode (mode,constant) =
          let val directory=output ^ "/" ^ mode val library=directory ^ "/lib" val ()=copyTree (fromRoot "lib") library
              val basis=library ^ "/basis/intinf.sml" val old="  val gmpAvailable = _prim \"intinf_gmp_available\" : unit -> bool" val replacement="  fun gmpAvailable () = " ^ constant
              val ()=write (basis,once (read basis) old replacement)
              val ()=Posix.FileSys.symlink {old=fromRoot "src",new=directory ^ "/src"} val ()=copy (fromRoot "build/config.sml") (directory ^ "/build/config.sml")
              val entry=ref [("changed_line",obj [("from",str old),("to",str replacement)]),("experimental_intinf_sha256",str (hash basis)),("workloads",obj []),("compilers",obj [])]
              fun saveEntry ()=(add report "modes" mode (obj (!entry));save output report)
              val checks=directory ^ "/checks.rbc"
              val _=run directory [fromRoot "bin/rune","--lib","lib","-o",checks,fromRoot "tests/intinf/oracle.sml",normal ^ "/vectors.sml",fromRoot "tests/intinf/checks.sml"]
              val checked=run root [fromRoot "bin/runevm","--intinf=" ^ mode,checks]
              val ()=need (#output checked="current: 1154 checks\noracle: 1154 checks\n","specialized arithmetic corpus differs")
              fun workload (name,w) =
                let val program=directory ^ "/" ^ name ^ ".rbc"
                    val _=run directory [fromRoot "bin/rune","--lib","lib","-o",program,normal ^ "/" ^ name ^ ".sml"]
                    fun rbc "normal"=normal ^ "/" ^ name ^ ".rbc" | rbc _=program
                    val disassembly=List.map (fn side =>
                      let val result=run root [fromRoot "bin/runevm","--disasm",rbc side] val text= #output result
                          val queries=count text 0 0 val ()=if side="specialized" then need (queries=0,"specialization retained a capability query") else ()
                          val file=directory ^ "/" ^ name ^ "-" ^ side ^ ".disasm" val ()=write (file,text)
                      in (side,obj [("sha256",str (hash file)),("capability_queries",number queries)]) end) ["normal","specialized"]
                    val runs=paired 2 samples ["normal","specialized"] (SOME (text (field "expected" w))) (fn side => run root [fromRoot "bin/runevm","--intinf=" ^ mode,rbc side])
                    val ratios=ratios (List.map kernelOf (lookup "normal" runs)) (List.map kernelOf (lookup "specialized" runs))
                    val stats=List.map (fn side => (side,str (#errors (run root [fromRoot "bin/runevm","--intinf=" ^ mode,"--count","--stats","--intinf-stats",rbc side])))) ["normal","specialized"]
                    val result=obj [("runs",obj (List.map (fn (k,v) => (k,arr v)) runs)),("normal_over_specialized_ratios",values ratios),("median_ratio",real (median ratios)),("stats",obj stats),("disassembly",obj disassembly),
                       ("bytecode_bytes",obj (List.map (fn side => (side,bytes (rbc side))) ["normal","specialized"])),("bytecode_sha256",obj (List.map (fn side => (side,str (hash (rbc side)))) ["normal","specialized"]))]
                in add entry "workloads" name result;saveEntry ();say (mode ^ " " ^ name ^ " " ^ general (median ratios) ^ "\n") end
              val ()=List.app workload (object (field "workloads" reference))
              val compiler=directory ^ "/compiler.rbc" val boot=List.map text (array (field "inputs" (field "bootstrap" (field "compiler_workloads" reference))))
              val _=run directory ([fromRoot "bin/rune","--lib","lib","--target=registers","-o",compiler] @ boot)
              val ()=set entry "compiler_bytes" (obj [("normal",bytes (fromRoot "bin/rune.rbc")),("specialized",bytes compiler)])
              val ()=set entry "compiler_sha256" (str (hash compiler))
              fun compilation (name,w) =
                let fun command side=
                      let val target=directory ^ "/" ^ name ^ "-" ^ side ^ ".rbc" val ()=rmTree target
                          val result=run root ([fromRoot "bin/runevm","--intinf=" ^ mode,"--heap-size","67108864",if side="normal" then fromRoot "bin/rune.rbc" else compiler,"--lib","lib","--target=registers","-o",target] @ List.map text (array (field "inputs" w)))
                      in need (hash target=text (field "output_sha256" w),"compiler control bytecode differs: " ^ name);result end
                    val runs=paired 2 compilerSamples ["normal","specialized"] NONE command
                    val ratios=ratios (List.map (timingOf "wall") (lookup "normal" runs)) (List.map (timingOf "wall") (lookup "specialized" runs))
                in add entry "compilers" name (obj [("runs",obj (List.map (fn (k,v) => (k,arr v)) runs)),("normal_over_specialized_ratios",values ratios),("median_ratio",real (median ratios))]);saveEntry ();say (mode ^ " " ^ name ^ " " ^ general (median ratios) ^ "\n") end
          in List.app compilation (object (field "compiler_workloads" reference)) end
        val ()=List.app mode [("gmp","true"),("sml","false")]
        val ()=set report "machine_int" (obj [])
        fun machine (name,w)=if text (field "group" w)<>"small" then () else
          let val source=output ^ "/" ^ name ^ "-machine-int.sml" val ()=write (source,once (read (normal ^ "/" ^ name ^ ".sml")) "structure I = IntInf\n" "structure I = Int\n")
              val program=OS.Path.base source ^ ".rbc" val _=run root [fromRoot "bin/rune","--lib","lib","-o",program,source]
              fun rbc "intinf"=normal ^ "/" ^ name ^ ".rbc" | rbc _=program
              val runs=paired 2 samples ["intinf","int"] (SOME (text (field "expected" w))) (fn side => run root [fromRoot "bin/runevm","--intinf=gmp",rbc side])
              val ratios=ratios (List.map kernelOf (lookup "intinf" runs)) (List.map kernelOf (lookup "int" runs))
              val stats=List.map (fn side => (side,str (#errors (run root [fromRoot "bin/runevm","--intinf=gmp","--count","--stats",rbc side])))) ["intinf","int"]
          in add report "machine_int" name (obj [("runs",obj (List.map (fn (k,v) => (k,arr v)) runs)),("intinf_over_int_ratios",values ratios),("median_ratio",real (median ratios)),("stats",obj stats),("limitation",str "Finite-precision Int on these bounded operands; not a replacement for IntInf.")]);save output report;say ("machine-int " ^ name ^ " " ^ general (median ratios) ^ "\n") end
        val ()=List.app machine (object (field "workloads" reference))
    in set report "result" (str "pass");save output report;0 end
end
