(* Small command-oriented development tools and benchmark provenance. *)
structure MeasureBasics =
struct
  open MeasureCommon
  fun opt args =
    let val (output,sources)=case args of "-o"::output::rest => (output,rest)
           | first::rest => ((if String.isSuffix ".sml" first then String.substring (first,0,size first-4) else first),args)
           | [] => raise Usage "opt [-o EXE] FILE.sml ..."
        val ()=need (not (null sources),"opt requires sources")
        val compiler=tool "RUNE" (fromRoot "bin/rune")
        val optimizer=tool "RUNEOPT" (fromRoot "bin/runeopt")
        val cwd=OS.FileSys.getDir ()
        val status=inherited cwd (compiler @ ["--target=stack"] @ sources @ ["-o",output ^ ".rbc"])
    in if status=0 then inherited cwd (optimizer @ [output ^ ".rbc","-o",output]) else status end
  fun bisect args =
    let val compiler=ref "bin/rune-stack" val vm=ref "bin/runevm-stack"
        fun parse ("--rune"::value::rest)=(compiler:=value;parse rest)
          | parse ("--vm"::value::rest)=(vm:=value;parse rest)
          | parse (source::args)=(source,args)
          | parse []=raise Usage "bisect-fuel [--rune BIN] [--vm BIN] PROGRAM [ARGS...]"
        val (source,args)=parse args
        val output=fromRoot "tests/out/bisect"
        val ()=mkdirs output
        fun run label options =
          let val compiled=execute root (output ^ "/" ^ label ^ "-compile") ([!compiler] @ options @ [source,"-o",output ^ "/" ^ label ^ ".rbc"])
              val ()=say (#output compiled)
              val ()=write (output ^ "/" ^ label ^ ".cerr",#errors compiled)
              val all=if #status compiled<>0 then "compile error\n" ^ #errors compiled else
                   let val result=execute root (output ^ "/" ^ label) (!vm :: output ^ "/" ^ label ^ ".rbc" :: args)
                       val ()=copy (output ^ "/" ^ label ^ ".stdout") (output ^ "/" ^ label ^ ".out")
                       val ()=copy (output ^ "/" ^ label ^ ".stderr") (output ^ "/" ^ label ^ ".err")
                   in #output result ^ "--- stderr\n" ^ #errors result ^ "--- exit " ^ Int.toString (#status result) ^ "\n" end
          in write (output ^ "/" ^ label ^ ".all",all);all end
        val reference=run "reference" ["-O0"]
        val full=run "full" ["-O2"]
        fun breaks n=run "fuel" ["-O2","--fuel=" ^ Int.toString n]<>reference
        fun upper hi=if breaks hi then SOME hi else if hi>=1073741824 then NONE else upper (hi*2)
        fun lower (lo,hi)=if hi-lo<=1 then (lo,hi) else let val mid=(lo+hi) div 2 in if breaks mid then lower (lo,mid) else lower (mid,hi) end
    in if full=reference then (say ("bisect-fuel: " ^ source ^ " runs the same at -O2 as at -O0\n");0)
       else if breaks 0 then (say ("bisect-fuel: " ^ source ^ " differs even with no rewrite: not a rewrite of the optimiser\n");1)
       else case upper 1 of NONE => (say ("bisect-fuel: no fuel breaks " ^ source ^ ", only -O2 does\n");1)
          | SOME hi => let val (lo,hi)=lower (hi div 2,hi)
             in say ("bisect-fuel: rewrite " ^ Int.toString hi ^ " breaks " ^ source ^ "; compare\n");
                say ("  " ^ !compiler ^ " -O2 --fuel=" ^ Int.toString lo ^ " --dump-after=all " ^ source ^ "\n");
                say ("  " ^ !compiler ^ " -O2 --fuel=" ^ Int.toString hi ^ " --dump-after=all " ^ source ^ "\n");1 end
    end
  fun provenance role selected bundle =
    let val ()=mkdirs bundle
        val result=execute root (bundle ^ "/" ^ role ^ "-git-root") ["git","-C",OS.Path.dir selected,"rev-parse","--show-toplevel"]
        val repository=if #status result=0 then trim (#output result) else ""
        fun git args=trim (successful (execute root (bundle ^ "/" ^ role ^ "-git") (["git","-C",repository] @ args)))
        val record="tool\t" ^ selected ^ "\n" ^
           (if repository="" then "repository\tunavailable\nrevision\tunavailable\ndirty\tunavailable\nidentity_scope\tcustom or installed tool; repository identity unavailable, executable hash retained\n"
            else "repository\t" ^ repository ^ "\nrevision\t" ^ git ["rev-parse","HEAD"] ^ "\ndirty\t" ^ Int.toString (length (lines (git ["status","--porcelain"]))) ^ "\nidentity_scope\tselected tool repository at measurement time; payload hashes identify actual bytes\n")
        val ()=write (bundle ^ "/" ^ role ^ "-repository.tsv",record)
        fun sum file=hash file ^ "  " ^ file ^ "\n"
        val payloads=["rune.rbc","rune.stack.rbc","rune.new.rbc","rune-mlton.bin","rune-polyml.bin","runevm","runevm-stack","runevm-new","runevm-native","runeopt-mlton","runeopt-mlton.bin"]
        val paths=if repository="" then [] else List.filter exists (List.map (fn name => repository ^ "/bin/" ^ name) payloads)
        val ()=write (bundle ^ "/" ^ role ^ "-payloads.sha256",String.concat (List.map sum paths))
        val ()=if role<>"compiler" orelse repository="" orelse not (exists (repository ^ "/lib/basis/MANIFEST")) then () else
             let val paths="lib/basis/MANIFEST" :: List.map (fn file => "lib/basis/" ^ file)
                    (List.filter (String.isSuffix ".sml") (sort (entries (repository ^ "/lib/basis"))))
             in write (bundle ^ "/basis.sha256",String.concat (List.map (fn file => hash (repository ^ "/" ^ file) ^ "  " ^ file ^ "\n") paths)) end
    in 0 end
end
