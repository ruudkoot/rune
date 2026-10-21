(* Host structure availability, with one independent source probe per name. *)
structure GenerateStructures =
struct
  open MeasureCommon
  structure T=GenerateText
  fun main args =
    let val names=List.map text (array (readJson (fromRoot "tools/generate/data/basis-structures.json")))
        val configs=ref ["rune","mlton","smlnj-legacy","smlnj-dev","polyml","mlkit"] val out=ref (fromRoot "tests/out/structures") val jobs=ref 0
        fun parse []=() | parse ("--out"::v::rest)=(out:=fromRoot v;parse rest) | parse ("--configs"::v::rest)=(configs:=fields #"," v;parse rest) | parse ("-j"::v::rest)=(jobs:=integer v;parse rest)
          | parse _=raise Usage "structures [--out DIR] [--configs LIST] [-j N]"
        val ()=parse args val out= !out val ()=(rmTree out;mkdirs out)
        val hosts=GenerateXC2.hosts
        fun setting system=case system of "rune" => fromRoot "bin/rune" | "mlton" => env ("MLTON",hosts ^ "/mlton/bin/mlton")
          | "smlnj-legacy" => env ("SMLNJ",hosts ^ "/smlnj-legacy/bin/sml") | "smlnj-dev" => env ("SMLNJ_DEV",hosts ^ "/smlnj-dev/bin/sml")
          | "polyml" => env ("POLY",hosts ^ "/polyml/bin/poly") | "mlkit" => env ("MLKIT",hosts ^ "/mlkit/bin/mlkit") | _ => raise Usage ("unknown structure probe system " ^ system)
        val ()=List.app (fn system => need (OS.FileSys.access (setting system,[OS.FileSys.A_EXEC]),"structure probe compiler unavailable: " ^ system)) (!configs)
        fun path name=out ^ "/" ^ T.replace name "." "_" ^ ".sml"
        val ()=List.app (fn name => write (path name,"structure Probe = " ^ name ^ "\n")) names
        fun probe system prefix args environment=child {args=args,directory=root,input="",prefix=out ^ "/" ^ prefix,timeout=180,environment=environment}
        val results=ref [] : (string*string*bool) list ref
        fun result system name yes=results:= !results @ [(system,name,yes)]
        fun ordinary system=
          List.app (fn name =>
            let val file=path name
                val command=if system="rune" then [setting system,"--typecheck-only",file] else
                       let val mlb=out ^ "/mlton." ^ T.replace name "." "_" ^ ".mlb" val ()=write (mlb,"$(SML_LIB)/basis/basis.mlb\n\"" ^ file ^ "\"\n") in [setting system,"-stop","tc",mlb] end
                val r=probe system (system ^ "-" ^ name) command (fn e => e)
                val ()=need (#status r<128,"structure probe crashed: " ^ system ^ " " ^ name)
            in result system name (#status r=0) end) names
        fun session system=
          let val file=out ^ "/" ^ system ^ ".driver.sml"
              val source=String.concat (List.map (fn name => "val () = (use " ^ GenerateFixtures.literal (path name) ^ "; print \"PROBE " ^ name ^ " yes\\n\") handle _ => print \"PROBE " ^ name ^ " no\\n\";\n") names)
              val ()=write (file,source) val command=[setting system] @ (if system="polyml" then ["-q","--use"] else []) @ [file]
              val r=probe system (system ^ "-session") command (fn e => e)
              val ()=need (#status r=0,"structure probe session failed: " ^ system)
              val rows=List.mapPartial (fn line => if String.isPrefix "PROBE " line then SOME (String.tokens Char.isSpace line) else NONE) (lines (#output r))
              val ()=need (length rows=length names,"structure probe session omitted results: " ^ system)
          in List.app (fn name => case List.filter (fn row => length row=3 andalso List.nth (row,1)=name) rows of
                  [[_,_,value]] => (need (value="yes" orelse value="no","invalid structure probe verdict");result system name (value="yes")) | _ => raise Failed "missing or repeated structure probe result") names end
        fun mlkit ()=
          let val compiler=setting "mlkit" val library=env ("MLKIT_LIB",OS.Path.dir (OS.Path.dir compiler) ^ "/lib/mlkit")
              val ()=List.app (fn name => let val d=out ^ "/mlkit/" ^ T.replace name "." "_" val ()=mkdirs d
                      in copy (path name) (d ^ "/probe.sml");write (d ^ "/probe.mlb","$(SML_LIB)/basis/basis.mlb\nprobe.sml\n") end) names
              fun command name : Supervisor.command =
                let val d=out ^ "/mlkit/" ^ T.replace name "." "_"
                in {program=compiler,args=[compiler,"--no_messages","-c","probe.mlb"],env=setEnv ("SML_LIB",library) (Posix.ProcEnv.environ ()),dir=d,stdin="/dev/null",stdout=d ^ "/compile.stdout",stderr=d ^ "/compile.stderr",timeout=Time.fromSeconds 180,cap=4*1024*1024,cost=1.0,cpus=1,memory=256,pools=[],exclusive=false,failedLast=false,deps=[]} end
              val yes=Array.array (length names,false) val bad=ref false
              fun finished (i,r:Supervisor.result)=
                (case #outcome r of Supervisor.Exited n => if #leaked r then bad:=true else Array.update (yes,i,n=0) | _ => bad:=true;Supervisor.Passed)
              val cpus=if !jobs>0 then !jobs else case OS.Process.getEnv "RUNE_TEST_CPUS" of SOME s => Int.max (1,integer s) | NONE =>
                     Int.max (1,integer (trim (successful (execute root (out ^ "/cpus") ["getconf","_NPROCESSORS_ONLN"]))))
              val ()=Supervisor.run {commands=Vector.fromList (List.map command names),cpus=cpus,memory=4096,finished=finished,tick=fn _ => ()}
              val ()=need (not (!bad),"MLKit structure probe timed out, crashed or leaked")
          in List.app (fn (name,i) => result "mlkit" name (Array.sub (yes,i))) (ListPair.zip (names,List.tabulate (length names,fn i => i))) end
        val ()=List.app (fn system => if system="rune" orelse system="mlton" then ordinary system else if system="mlkit" then mlkit () else session system) (!configs)
        val ()=write (out ^ "/results",String.concat (List.map (fn (system,name,yes) => system ^ " " ^ name ^ " " ^ (if yes then "yes" else "no") ^ "\n") (!results)))
        fun version system =
          if system="rune" then "Rune" else
          let val args=case system of "mlton" => [] | "polyml" => ["-v"] | "mlkit" => ["--version"] | _ => ["@SMLversion"]
              val r=probe system (system ^ "-version") (setting system::args) (fn e => e)
              val raw= #output r ^ #errors r val first=case lines raw of first::_ => first | _ => ""
              val start=case system of "mlton" => "MLton " | "polyml" => "Poly/ML " | "mlkit" => "MLKit v" | _ => "sml "
              val tail=T.prefix start first val v=Substring.string (Substring.takel (fn c => Char.isDigit c orelse c = #".") (Substring.full tail))
              val label=case system of "mlton" => "MLton " | "polyml" => "Poly/ML " | "mlkit" => "MLKit " | _ => "SML/NJ "
          in label ^ v end
        fun provided system name=case List.find (fn (s,n,_) => s=system andalso n=name) (!results) of SOME (_,_,b) => b | _ => raise Failed "structure probe result lost"
        val ()=say ("| Structure |" ^ String.concat (List.map (fn system => " " ^ version system ^ " |") (!configs)) ^ "\n|---|" ^ String.concat (List.map (fn _ => ":---:|") (!configs)) ^ "\n")
        val all=ref [] : string list ref
        val ()=List.app (fn name => let val row=List.map (fn system => provided system name) (!configs)
                 in if List.all (fn yes => yes) row then all:= !all @ [name] else say ("| `" ^ name ^ "` |" ^ String.concat (List.map (fn yes => if yes then " yes |" else " |") row) ^ "\n") end) names
    in say ("\nProvided by all of them:" ^ (if null (!all) then "" else " `" ^ String.concatWith "`, `" (!all) ^ "`") ^ ".\n");0 end
end
