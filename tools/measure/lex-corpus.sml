(* Lexer corpus decisions and finite-difference instruction costs, with
   independent file jobs and an explicit intersection of accepted inputs. *)
structure MeasureLexCorpus =
struct
  open MeasureCommon
  structure F=MeasureFormat
  fun absolute path=OS.Path.mkAbsolute {path=path,relativeTo=OS.FileSys.getDir ()}
  fun flags "default"=[] | flags "unicode"=["--unicode"] | flags "latin1"=["--unicode=latin1"]
    | flags mode=raise Usage ("unknown lexer source mode: " ^ mode)
  fun main args =
    let val tree=ref root val output=ref (fromRoot "tests/out/lex-corpus") val modes=ref ["default","unicode","latin1"]
        val cost=ref 0 val against=ref "" val jobs=ref (Runtime.processors ())
        fun parse ("--rune"::v::rest)=(tree:=absolute v;parse rest) | parse ("--out"::v::rest)=(output:=v;parse rest)
          | parse ("--modes"::v::rest)=(modes:=fields #"," v;parse rest) | parse ("--cost"::v::rest)=(cost:=integer v;parse rest)
          | parse ("--against"::v::rest)=(against:=absolute v;parse rest) | parse ("-j"::v::rest)=(jobs:=integer v;parse rest)
          | parse (arg::rest)=if String.isPrefix "-" arg then raise Usage ("unknown lex-corpus option: " ^ arg) else arg::rest | parse []=[]
        val corpora=parse args
        val ()=if null corpora then raise Usage "lex-corpus [OPTIONS] CORPUS..." else ()
        val ()=need (!jobs>0 andalso !cost>=0 andalso not (null (!modes)),"invalid lexer job/cost/mode selection")
        val ()=List.app (fn mode => ignore (flags mode)) (!modes)
        val ()=mkdirs (!output)
        val cwd=OS.FileSys.getDir ()
        fun once files selectedTree options =
          let fun count n =
                let val args=[selectedTree ^ "/bin/runevm","--count","--heap-size","268435456",selectedTree ^ "/bin/rune.rbc","--lib",selectedTree ^ "/lib"]
                          @ options @ ["--lex-count",Int.toString n] @ files
                    val result=execute cwd (!output ^ "/cost-" ^ Int.toString n) (["/bin/sh","-c","ulimit -v 8000000 || exit 125; exec \"$@\"","lex-cost"] @ args)
                in if #status result<>0 then NONE else
                     let val rows=List.mapPartial (fn line =>
                              let val (_,rest)=Substring.position "count: " (Substring.full line)
                              in if Substring.isEmpty rest then NONE else IntInf.fromString (Substring.string (Substring.triml 7 rest)) end) (lines (#errors result))
                     in last rows end end
          in case (count 1,count (1+ !cost)) of (SOME a,SOME b) => SOME (IntInf.div (b-a,IntInf.fromInt (!cost))) | _ => NONE end
        fun corpus spec =
          let val (name,input)=if spec="rune" then ("rune",NONE) else
                    let val (name,path)=Substring.position "=" (Substring.full spec)
                    in if Substring.isEmpty path then raise Usage "corpus must be rune, NAME=DIR or NAME=@LIST"
                       else (Substring.string name,SOME (Substring.string (Substring.triml 1 path))) end
              val files=case input of NONE =>
                    List.map (fn file => root ^ "/" ^ file) (lines (successful (execute root (!output ^ "/tracked") ["git","-C",root,"ls-files","*.sml","*.sig","*.fun"])))
                | SOME path => if String.isPrefix "@" path then lines (read (String.extract (path,1,NONE))) else
                    sort (List.filter (fn file => not (OS.FileSys.isLink file) andalso List.exists (fn suffix => String.isSuffix suffix file) [".sml",".sig",".fun"]) (MeasureCommon.files path))
              val total=length files
              val ()=write (!output ^ "/" ^ name ^ ".files",String.concat (List.map (fn file => file ^ "\n") files))
              val every=ref files
              fun refusing selectedTree options label =
                let val directory= !output ^ "/" ^ name ^ "-" ^ label ^ "-jobs"
                    val ()=mkdirs directory
                    val commands=Vector.fromList (List.map (fn (file,index) =>
                       {program="/bin/sh",args=["sh","-c","ulimit -v 6000000 || exit 125; exec \"$@\"","lex-quota",selectedTree ^ "/bin/rune"] @ options @ ["--lex-count","1",file],
                        env=Posix.ProcEnv.environ (),dir=cwd,stdin="/dev/null",stdout=directory ^ "/" ^ Int.toString index ^ ".out",stderr=directory ^ "/" ^ Int.toString index ^ ".err",
                        timeout=Time.fromSeconds 600,cap=1024*1024,cost=1.0,cpus=1,memory=5859,pools=[],exclusive=false,failedLast=false,deps=[]}:Supervisor.command)
                        (ListPair.zip (files,List.tabulate (total,fn i => i))))
                    val refused=ref [] : (string*string) list ref
                    fun finished (index,result:Supervisor.result)=
                      let val first=firstLine (directory ^ "/" ^ Int.toString index ^ ".err")
                          val error=if first<>"" then first else case #outcome result of Supervisor.Exited 0 => if #leaked result then "lexer left processes behind" else "" | outcome => Supervisor.outcomeName outcome
                          val ()=if error="" then () else refused:=(List.nth (files,index),error):: !refused
                      in Supervisor.Passed end
                    val ()=Supervisor.run {commands=commands,cpus= !jobs,memory=Int.max (5859,MeasureGCEval.available () div 1024*4 div 5),finished=finished,tick=fn _ => ()}
                    val refused=sorted (fn ((a,_),(b,_)) => a<b) (!refused)
                    val ()=write (!output ^ "/" ^ name ^ "." ^ label ^ ".refused",String.concat (List.map (fn (file,error) => file ^ "\t" ^ error ^ "\n") refused))
                    val names=List.map #1 refused
                    val ()=write (!output ^ "/" ^ name ^ "." ^ label ^ ".names",String.concat (List.map (fn file => file ^ "\n") names))
                    val ()=every:=List.filter (fn file => not (List.exists (fn name => name=file) names)) (!every)
                in total-length refused end
              val lexed=List.map (fn mode => (mode,refusing (!tree) (flags mode) mode)) (!modes)
              val ()=if !cost>0 andalso !against<>"" then ignore (refusing (!against) [] "against") else ()
              val ()=write (!output ^ "/" ^ name ^ ".every",String.concat (List.map (fn file => file ^ "\n") (sort (!every))))
              val baseline=if !cost>0 andalso !against<>"" andalso not (null (!every)) then once (!every) (!against) [] else NONE
              val ()=List.app (fn (mode,lexed) =>
                  let val instr=if !cost>0 andalso not (null (!every)) then once (!every) (!tree) (flags mode) else NONE
                      val text=case instr of SOME n => intText n | NONE => if !cost>0 andalso not (null (!every)) then "failed" else ""
                      val base=case baseline of SOME n => intText n | NONE => ""
                      val change=case (instr,baseline) of (SOME a,SOME b) => if b=0 then "" else
                           F.format "%+.1f%%" [F.Decimal (100.0*Real.fromLargeInt (IntInf.toLarge (a-b))/Real.fromLargeInt (IntInf.toLarge b))] | _ => ""
                  in say (F.format "%-10s %-8s %7s %7s %15s %15s %8s\n" [F.Text name,F.Text mode,F.Text (Int.toString lexed),F.Text (Int.toString total),F.Text text,F.Text base,F.Text change]) end) lexed
          in () end
    in say (F.format "%-10s %-8s %7s %7s %15s %15s %8s\n" (List.map F.Text ["corpus","mode","lexed","files","instructions","against","change"]));List.app corpus corpora;0 end
end
