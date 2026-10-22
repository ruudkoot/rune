(* Paired IntInf experiments share provenance, finite process limits and
   strict independent-answer checks. Instrumented runs are separate. *)
structure MeasureIntInfCommon =
struct
  open MeasureCommon
  type report=(string*Json.value) list ref
  fun set target key value=target:=List.map (fn (name,old) => (name,if name=key then value else old)) (!target) @ (if List.exists (fn (name,_) => name=key) (!target) then [] else [(key,value)])
  fun obj pairs=Json.Object pairs
  fun arr values=Json.Array values
  fun str value=Json.String value
  fun number n=Json.Number (Int.toString n)
  fun values xs=arr (List.map real xs)
  fun strings xs=arr (List.map str xs)
  fun record target key pairs=set target key (obj pairs)
  fun merge old key value=obj (List.filter (fn (name,_) => name<>key) (object old) @ [(key,value)])
  fun options args =
    let fun loop [] acc=List.rev acc | loop (key::value::rest) acc=
             if String.isPrefix "--" key then loop rest ((key,value)::acc) else raise Usage ("invalid IntInf option " ^ key)
          | loop _ _=raise Usage "an IntInf option needs a value"
    in loop args [] end
  fun option opts key default=case List.find (fn (name,_) => name=key) (List.rev opts) of SOME (_,value) => value | NONE => default
  fun many opts key=List.map #2 (List.filter (fn (name,_) => name=key) opts)
  fun checkedOptions known opts=List.app (fn (key,_) => if List.exists (fn x => x=key) known then () else raise Usage ("unknown IntInf measurement option " ^ key)) opts
  fun required opts key=let val v=option opts key "" in if v="" then raise Usage ("missing " ^ key) else v end
  fun selected opts name=null (many opts "--workload") orelse List.exists (fn n => n=name) (many opts "--workload")
  fun finite n=(need (Real.isFinite n andalso n>=0.0,"invalid timing sample");n)
  fun kernel expected output =
    let val (line,rest)=Substring.position "\n" (Substring.full output)
        val ()=need (not (Substring.isEmpty rest) andalso Substring.string (Substring.triml 1 rest)=expected andalso String.isPrefix "TIMING " (Substring.string line),"IntInf independent answer differs")
    in finite (decimal (String.extract (Substring.string line,7,NONE))) end
  fun median values=let val values=sorted (op <) values val n=length values
       in need (n>0,"no paired samples");if n mod 2=1 then List.nth (values,n div 2) else (List.nth (values,n div 2-1)+List.nth (values,n div 2))/2.0 end
  fun ratios numerator denominator=ListPair.mapEq (fn (a,b) => (need (b>0.0,"zero-duration denominator");a/b)) (numerator,denominator)
  fun load ()=arr (List.map (real o decimal) (List.take (String.tokens Char.isSpace (read "/proc/loadavg"),3))) handle Subscript => arr []
  fun affinity ()=
    let val line=case List.find (String.isPrefix "Cpus_allowed_list:") (lines (read "/proc/self/status")) of NONE => "" | SOME line => trim (String.extract (line,18,NONE))
        fun range text=case fields #"-" text of [a,b] => List.tabulate (integer b-integer a+1,fn i => number (integer a+i)) | [""] => [] | [a] => [number (integer a)] | _ => raise Failed "invalid affinity list"
    in arr (List.concat (List.map range (fields #"," line))) end
  fun sourceHashes ()=obj (List.map (fn f => (f,str (hash (fromRoot f)))) ["runtime/intinf.c","lib/basis/intinf.sml"])
  fun base samples warmups =ref [("samples",number samples),("warmup_pairs",number warmups),("affinity",affinity ()),("load_start",load ()),("workloads",obj [])] : report
  fun save output target=(set target "load_end" (load ());json (output ^ "/report.json") (obj (!target)))
  fun driver ()=hash (CommandLine.name ())
  fun current target=(set target "vm_sha256" (str (hash (fromRoot "bin/runevm")));set target "compiler_sha256" (str (hash (fromRoot "bin/rune.rbc")));set target "source_hashes" (sourceHashes ()))
  fun verifiedVM vm reference =
    let val expected=case Json.member ("vm_sha256",reference) of SOME v => text v | NONE =>
           (case List.find (fn (name,_) => String.isSuffix "/runevm" name) (object (field "tool_hashes" reference)) of SOME (_,v) => text v | NONE => raise Failed "baseline report has no VM hash")
    in need (hash vm=expected,"baseline VM differs from its recorded artifact") end
  fun fresh output=(need (not (exists output),"use a fresh output directory to preserve earlier experiments");mkdirs output)
  fun runner output =
    let val seq=ref 0
        fun run directory args =
          let val ()=seq:= !seq+1 val prefix=output ^ "/" ^ StringCvt.padLeft #"0" 5 (Int.toString (!seq))
              val ()=json (prefix ^ ".recipe.json") (obj [("argv",strings args),("cwd",str directory)])
              fun clean env=List.filter (fn line => not (String.isPrefix "RUNEVM_" line orelse String.isPrefix "RUNE_GC_STRESS=" line)) env
              val result=measuredChild {args=["/bin/sh","-c","ulimit -v 4194304 || exit 125; exec \"$@\"","intinf-quota"] @ args,directory=directory,input="",prefix=prefix,timeout=180,environment=setEnv ("LC_ALL","C") o clean}
              val ()=need (#status result=0,"IntInf child failed: " ^ #errors result)
          in result end
    in run end
  fun usage result=obj [("wall",real (Time.toReal (#wall result))),("cpu",real (Time.toReal (Time.+ (#user result,#system result))))]
  fun pairs samples warmup sides action =List.app (fn i => List.app (fn side => action side (i>=warmup)) (if i mod 2=0 then List.rev sides else sides)) (List.tabulate (samples+warmup,fn i => i))
  fun samples opts default=let val n=integer (option opts "--samples" default) in need (n>=2 andalso n<=100000,"at least two measured pairs are required");n end
  fun add target key name value =
    let val old=case List.find (fn (n,_) => n=key) (!target) of NONE => obj [] | SOME (_,v) => v
    in set target key (merge old name value) end
end
