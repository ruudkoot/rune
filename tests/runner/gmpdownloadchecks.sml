(* Offline archive/cache policy through the producer's public CLI. Curl is
   a fixture executable; no production function is imported or monkeypatched. *)
structure GMPDownloadChecks =
struct
  open IntInfChecks
  val content="a deterministic stand-in for the pinned archive\n"
  val checksum="8f575c6c250ad327f05fb52ed8f171eefe343904668abf03a85916357e87bd33"
  val urls=["https://first.invalid/gmp.tar.xz","https://second.invalid/gmp.tar.xz"]
  fun args archive logs curl timeout=GMPChecks.tool "GMP_BUILDER" "bin/rune-build build-gmp" @
       ["download","--archive",archive,"--out",logs,"--checksum",checksum,"--url",hd urls,"--url",List.nth (urls,1),"--curl",curl,"--timeout",timeout]
  fun executable file text=(write (file,"#!/bin/sh\n" ^ text ^ "\n");Posix.FileSys.chmod (file,
         Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr]))
  fun one (c : context) () =
    let val ()=mkdirs (#directory c)
        val curl=path c "fixture curl"
        val ()=executable curl
          ("output=''; url=''\nwhile [ $# -gt 0 ]; do case $1 in -o) output=$2; shift 2 ;; https://*) url=$1; shift ;; *) shift ;; esac; done\n"
           ^ "test ! -e \"$FAKE_CURL_ARCHIVE\" || exit 81\ntest ! -e \"$output\" || exit 82\nprintf '%s\\n' \"$url\" >> \"$FAKE_CURL_CALLS\"\n"
           ^ "case $FAKE_CURL_MODE in\ninterrupt) printf partial > \"$output\"; printf '%s\\n' \"$$\" > \"$FAKE_CURL_READY\"; sleep 30; exit 83 ;;\n"
           ^ "all-fail) printf partial > \"$output\"; printf 'synthetic curl timeout\\n' >&2; exit 28 ;;\n"
           ^ "fallback|process-timeout|corrupt-second) case $url in *first.invalid*) printf partial > \"$output\"; "
           ^ "if [ \"$FAKE_CURL_MODE\" = process-timeout ]; then sleep 30; fi; printf 'synthetic curl timeout\\n' >&2; exit 28 ;; esac ;;\nesac\n"
           ^ "case $FAKE_CURL_MODE in corrupt-first|corrupt-second) printf 'wrong archive' > \"$output\" ;; *) printf '%s' "
           ^ quote content ^ " > \"$output\" ;; esac")
        val checks=ref 0
        fun casePaths name =
          let val dir=path c name
              val ()=(mkdirs (dir ^ "/downloads");mkdirs (dir ^ "/logs"))
          in (dir,dir ^ "/downloads/gmp.tar.xz",dir ^ "/logs") end
        fun environment dir archive mode=[("FAKE_CURL_MODE",mode),("FAKE_CURL_ARCHIVE",archive),
               ("FAKE_CURL_CALLS",dir ^ "/calls"),("FAKE_CURL_READY",dir ^ "/ready")]
        fun attempts logs=array (Json.decode (read (logs ^ "/commands.json")))
        fun number logs=length (attempts logs)
        fun cleaned archive=need (entries (OS.Path.dir archive)=[OS.Path.file archive],"verified cache retained a partial or lost its archive")
        fun empty archive=need (null (entries (OS.Path.dir archive)),"failed download left cache artifacts")
        fun result logs=Json.decode (read (logs ^ "/result.json"))
        fun checked ()=checks:= !checks+1
        fun invoke name mode expected initial curl timeout =
          let val (dir,archive,logs)=casePaths name
              val ()=initial archive
              val result=GMPChecks.process c name root 60 (environment dir archive mode) (args archive logs curl timeout)
              val ()=need ((#status result=0)=expected,"download CLI outcome differs: " ^ name ^ ": " ^ #errors result)
          in (result,dir,archive,logs) end
        val (_,_,archive,logs)=invoke "primary" "primary" true (fn _ => ()) curl "5"
        val ()=need (read archive=content andalso field "url" (result logs)=Json.String (hd urls) andalso number logs=1,"primary release was not verified and published")
        val ()=(cleaned archive;checked ())
        val argv=List.map string (array (field "argv" (hd (attempts logs))))
        fun value flag=case List.find (fn (name,_) => name=flag) (ListPair.zip (List.take (argv,length argv-1),tl argv)) of
                          SOME (_,value) => value | NONE => raise Failed ("missing download flag " ^ flag)
        val ()=List.app (fn (flag,wanted) => need (value flag=wanted,"unbounded/wrong curl retry flag " ^ flag))
              [("--retry","2"),("--retry-delay","2"),("--retry-max-time","180"),("--max-time","60"),("--connect-timeout","15")]
        val ()=List.app (fn flag => need (List.exists (fn arg => arg=flag) argv,"missing curl policy flag " ^ flag))
              ["--fail","--location","--show-error","--retry-connrefused"]
        val ()=checked ()
        val (_,_,archive,logs)=invoke "cached" "primary" true (fn archive => write (archive,content)) (path c "missing curl") "5"
        val ()=(need (number logs=0 andalso field "url" (result logs)=Json.Null andalso read archive=content,"verified cache invoked curl");cleaned archive;checked ())
        val (output,_,archive,logs)=invoke "corrupt-cache" "primary" false (fn archive => write (archive,"corrupt cache")) curl "5"
        val ()=(need (number logs=0 andalso read archive="corrupt cache" andalso String.isSubstring "cached source checksum mismatch" (#errors output),
                      "corrupt cache was replaced or trusted");checked ())
        fun fallback name mode =
          let val (_,_,archive,logs)=invoke name mode true (fn _ => ()) curl (if mode="process-timeout" then "1" else "5")
          in need (number logs=2 andalso field "url" (result logs)=Json.String (List.nth (urls,1)) andalso read archive=content,"mirror fallback did not publish verified content");
             cleaned archive;checked () end
        val ()=fallback "fallback" "fallback"
        val ()=fallback "process-timeout" "process-timeout"
        val (output,_,archive,logs)=invoke "all-fail" "all-fail" false (fn _ => ()) curl "5"
        val ()=(need (number logs=2 andalso String.isSubstring "all release sites" (#errors output)
                   andalso List.all (fn url => String.isSubstring url (#errors output)) urls,"all-site failure lost diagnostics");empty archive;checked ())
        fun mismatch name mode count =
          let val (output,_,archive,logs)=invoke name mode false (fn _ => ()) curl "5"
          in need (number logs=count andalso String.isSubstring "source checksum mismatch from https://" (#errors output),"checksum mismatch did not stop publication/fallback");
             empty archive;checked () end
        val ()=mismatch "corrupt-first" "corrupt-first" 1
        val ()=mismatch "corrupt-second" "corrupt-second" 2
        val (interruptDir,interruptArchive,interruptLogs)=casePaths "interrupted"
        val processArgs=args interruptArchive interruptLogs curl "5"
        val mode=Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr]
        val input=Posix.FileSys.openf ("/dev/null",Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
        val output=Posix.FileSys.creat (interruptDir ^ "/cli.stdout",mode)
        val errors=Posix.FileSys.creat (interruptDir ^ "/cli.stderr",mode)
        fun fd file=SysWord.toInt (Posix.FileSys.fdToWord file)
        val pid=Subprocess.spawn {program=hd processArgs,args=processArgs,env=SOME (IntInfChecks.environment
                   (environment interruptDir interruptArchive "interrupt") (Posix.ProcEnv.environ ())),
                   search=not (String.isSubstring "/" (hd processArgs)),dir=SOME root,
                   stdin=SOME (fd input),stdout=SOME (fd output),stderr=SOME (fd errors),group=false,
                   limits={addressSpace=NONE,cpuTime=SOME 60,fileSize=SOME (64*1024*1024),core=SOME 0}}
        val ()=(Posix.IO.close input;Posix.IO.close output;Posix.IO.close errors)
        fun kill selector signal=(Posix.Process.kill (selector,signal) handle OS.SysErr _ => ())
        fun cleanup ()=
          (case Int.fromString (read (interruptDir ^ "/ready")) of SOME child => if child>0 then
               kill (Posix.Process.K_GROUP (Posix.Process.wordToPid (SysWord.fromInt child))) Posix.Signal.kill else () | NONE => ();
           kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid))) Posix.Signal.kill;
           ignore (Subprocess.wait (SOME pid)) handle OS.SysErr _ => ())
        val start=Runtime.clock ()
        fun ready ()=if exists (interruptDir ^ "/ready") then () else
             if Time.toSeconds (Time.- (Runtime.clock (),start))>=10 then raise Failed "interrupt fixture did not start"
             else (case Subprocess.poll (SOME pid) of SOME _ => raise Failed "download ended before interruption"
                    | NONE => (OS.Process.sleep (Time.fromMilliseconds 10);ready ()))
        fun ended ()=case Subprocess.poll (SOME pid) of SOME result => result | NONE =>
             if Time.toSeconds (Time.- (Runtime.clock (),start))>=15 then raise Failed "interrupted download did not exit"
             else (OS.Process.sleep (Time.fromMilliseconds 10);ended ())
        val interrupted=(ready ();Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)),Posix.Signal.int);ended ())
                         handle e => (cleanup ();raise e)
        val ()=(case Int.fromString (read (interruptDir ^ "/ready")) of SOME child => if child>0 then
                    kill (Posix.Process.K_GROUP (Posix.Process.wordToPid (SysWord.fromInt child))) Posix.Signal.kill else () | NONE => ())
        val ()=need (#status interrupted<>Posix.Process.W_EXITED andalso number interruptLogs=1,"interruption retried or passed")
        val ()=(empty interruptArchive;checked ())
        val (output,_,archive,logs)=invoke "missing-curl" "primary" false (fn _ => ()) (path c "missing curl") "5"
        val ()=(need (number logs=1 andalso not (String.isSubstring "all release sites" (#errors output)),"missing tool was treated as a failed mirror");empty archive;checked ())
        val (_,_,archive,logs)=invoke "legacy-partial" "primary" true (fn archive => write (archive ^ ".part","old interrupted transfer")) curl "5"
        val ()=(need (number logs=1 andalso read archive=content andalso read (archive ^ ".part")="old interrupted transfer"
                andalso length (entries (OS.Path.dir archive))=2,"legacy partial file was trusted or overwritten");checked ())
        val (output,_,archive,logs)=invoke "cli-diagnostics" "all-fail" false (fn _ => ()) curl "5"
        val ()=need (number logs=2,"CLI did not retain each download failure")
        val ()=List.app (fn name => need (read (logs ^ "/" ^ name ^ ".log")="synthetic curl timeout\n"
                 andalso String.isSubstring "exit:28" (read (logs ^ "/" ^ name ^ ".status")),"CLI failure lost its attempt transcript")) ["download-1","download-2"]
        val ()=need (length (List.filter (String.isSubstring "synthetic curl timeout") (lines (#errors output)))=2,"curl diagnostics were not printed once per attempt")
        val ()=(empty archive;checked ())
    in say ("PASS offline GMP download/cache policy: " ^ Int.toString (!checks) ^ " scenarios\n") end
end
