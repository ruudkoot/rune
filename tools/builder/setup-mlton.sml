structure BuildSetupMLton =
struct
  open BuildCommon
  val commit="5fe943391e539a502699327a6266b6e8e97939e1"
  fun main args =
    let val (directory,repository)=case args of [directory] => (directory,"https://github.com/MLton/mlton.git") | [directory,repository] => (directory,repository) | _ => raise Usage "setup-mlton DIR [REPOSITORY]"
        val displayDirectory=directory
        val directory=resolved directory
        val mlton=env ("MLTON",env ("RUNE_HOSTS",env ("HOME","") ^ "/.local/rune-hosts") ^ "/mlton/bin/mlton")
        val ()=need (OS.FileSys.access (mlton,[OS.FileSys.A_EXEC]),"no MLton at " ^ mlton ^ " (make hosts, or MLTON=)")
        val work=privateDirectory (fromRoot "tests/out/build-observations") "setup-mlton"
        fun run label args=successful (execute (OS.FileSys.getDir ()) (work ^ "/" ^ label) 900.0 args (Posix.ProcEnv.environ ()))
        val ()=if exists directory then () else
              (ignore (run "clone" ["git","-c","advice.detachedHead=false","clone","--quiet",repository,directory]);ignore (run "checkout" ["git","-c","advice.detachedHead=false","-C",directory,"checkout","--quiet",commit]))
        val revision=run "revision" ["git","--no-optional-locks","-C",directory,"rev-parse","HEAD"]
        val ()=need (revision=commit,directory ^ " is at " ^ revision ^ ", not at " ^ commit ^ " (git -C " ^ directory ^ " checkout " ^ commit ^ ")")
        val environment=setEnv ("PATH",OS.Path.dir mlton ^ ":" ^ env ("PATH","")) (Posix.ProcEnv.environ ())
        val log=directory ^ "/mlton/setup-mlton.log"
        val result=BuildIO.execute {args=["make","-C",directory ^ "/mlton","rune-mlton","RUNE=true"],directory=OS.FileSys.getDir (),input="",output=log,errors=log,environment=environment,timeout=1800.0}
        val ()=if #status result=0 then () else (warn (BuildGMP.tail log 4096 ^ "\n");raise Failed "MLton source preparation failed")
        val sourceList=directory ^ "/mlton/mlton-rune.txt" val count=length (List.filter (fn c => c = #"\n") (String.explode (read sourceList)))
        val ()=need (count=606,sourceList ^ " has " ^ Int.toString count ^ " files, not 606")
    in remove work;say ("setup-mlton: " ^ displayDirectory ^ "/mlton/mlton-rune.txt lists MLton's 606 files; MLTON_SOURCES=" ^ directory ^ "\n");0 end
end
