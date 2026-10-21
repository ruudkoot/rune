structure BuildGMP =
struct
  open BuildCommon
  structure O=BuildOptions
  exception CommandFailed of string
  val version="6.3.0"
  val checksum="a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898"
  val url="https://gmplib.org/download/gmp/gmp-" ^ version ^ ".tar.xz"
  val urls=["https://ftp.gnu.org/gnu/gmp/gmp-" ^ version ^ ".tar.xz",url]
  fun replace text key value =
    let fun loop text=case Substring.position key (Substring.full text) of (a,b) =>
             if Substring.isEmpty b then text else Substring.string a ^ value ^ loop (Substring.string (Substring.triml (size key) b))
    in loop text end
  fun absolute file=resolved file
  fun tail file bytes=let val data=read file val start=Int.max (0,size data-bytes) in Utf8.implode (Utf8.explode (String.extract (data,start,NONE))) end
  fun downloads archive checksum urls curl run =
    if exists archive then (need (hash archive=checksum,"GMP cached source checksum mismatch");NONE) else
     let val temporary=privateDirectory (OS.Path.dir archive) (OS.Path.file archive) val part=temporary ^ "/" ^ OS.Path.file archive val failures=ref [] : string list ref
         fun attempts [] _=raise Failed ("GMP download failed from all release sites:\n" ^ String.concatWith "\n" (List.rev (!failures)))
           | attempts (url::rest) i=
             let val ()=remove part
                 val command=[curl,"--fail","--location","--silent","--show-error","--connect-timeout","15","--max-time","60","--retry","2","--retry-delay","2","--retry-max-time","180","--retry-connrefused",url,"-o",part]
                 val failed=(run command ("download-" ^ Int.toString i);NONE) handle CommandFailed why => SOME why
                       | BuildIO.TimedOut _ => SOME "download timed out"
             in case failed of SOME why => (failures:=(url ^ ": " ^ why):: !failures;warn ("GMP download failed: " ^ hd (!failures) ^ "\n");attempts rest (i+1))
                 | NONE => (need (exists part andalso hash part=checksum,"GMP source checksum mismatch from " ^ url);OS.FileSys.rename {old=part,new=archive};say ("GMP source verified: " ^ url ^ "\n");SOME url) end
         val result=(attempts urls 1 handle e => (remove temporary;raise e))
     in remove temporary;result end
  fun errorName e=case e of BuildIO.Interrupted => "KeyboardInterrupt" | BuildIO.TimedOut _ => "TimeoutExpired" | CommandFailed _ => "CommandFailed" | _ => "RuntimeError"
  fun message e=case e of Failed why => why | Usage why => why | CommandFailed why => why | BuildIO.Interrupted => "" | BuildIO.TimedOut _ => "interrupted or timed out" | _ => General.exnMessage e
  fun makeRunner output timeout timed =
    let val commands=ref [] : Json.value list ref val ()=json (output ^ "/commands.json") (Json.Array [])
        fun run directory environment args name =
          let val ()=commands:= !commands @ [Json.Object [("name",str name),("argv",strings args),("cwd",str directory)]]
              val ()=json (output ^ "/commands.json") (Json.Array (!commands))
              val ()=if timed then say ("GMP " ^ name ^ ": " ^ command args ^ "\n") else ()
              val log=output ^ "/" ^ name ^ ".log" val statusFile=output ^ "/" ^ name ^ ".status"
              val result=(BuildIO.execute {args=args,directory=directory,input="",output=log,errors=log,environment=environment,timeout=timeout}
                    handle e => (atomic statusFile "interrupted or timed out\n";raise e))
              val ()=atomic statusFile ("exit:" ^ Int.toString (#status result) ^ "\n" ^ (if timed then "seconds:" ^ minus (Real.fmt (StringCvt.FIX (SOME 3)) (#seconds result)) ^ "\n" else ""))
          in if #status result=0 then () else
               (warn (tail log 4096 ^ "\n");raise CommandFailed ("GMP " ^ name ^ " failed (" ^ Int.toString (#status result) ^ "); see " ^ log)) end
    in (run,commands) end
  fun download args =
    let fun separate [] regular urls=(List.rev regular,List.rev urls)
          | separate ("--url"::url::rest) regular urls=separate rest regular (url::urls)
          | separate (arg::rest) regular urls=separate rest (arg::regular) urls
        val (args,supplied)=separate args [] []
        val options=O.parse [("--archive",O.Value),("--out",O.Value),("--checksum",O.Value),("--curl",O.Value),("--timeout",O.Value)] [] args
        val archive=absolute (O.require options "--archive") val output=absolute (O.require options "--out") val ()=mkdirs output
        val checksum=String.map Char.toLower (O.get options "--checksum" checksum) val curl=O.get options "--curl" "curl" val timeout=real (O.get options "--timeout" "1800")
        val ()=need (timeout>0.0 andalso size checksum=64 andalso CharVector.all (fn c => Char.isDigit c orelse (c>= #"a" andalso c<= #"f")) checksum,"timeout must be positive and checksum must be SHA256")
        val (run,_)=makeRunner output timeout false
        fun work () =
          let val url=downloads archive checksum (if null supplied then urls else supplied) curl (fn args => fn name => run output (Posix.ProcEnv.environ ()) args name)
          in json (output ^ "/result.json") (Json.Object [("state",str "verified"),("url",case url of NONE => Json.Null | SOME url => str url),("archive",str archive),("sha256",str (hash archive))]);0 end
    in work () handle e => (json (output ^ "/result.json") (Json.Object [("state",str "failed"),("error",str (errorName e)),("message",str (message e))]);raise e) end
  fun recipe () =
    let val names=["tools/builder/io.sig","tools/builder/native-io.sml","tools/builder/rune-io.sml","tools/builder/common.sml","tools/builder/options.sml","tools/builder/gmp-build.sml","tools/builder/archive.sml"]
        val names=List.filter (exists o fromRoot) names
        val text=String.concat (List.map (fn name => name ^ "\000" ^ hash (fromRoot name) ^ "\000") names)
    in Hex.fromBytes (Sha256.digest text) end
  fun validateSource archive build sourceRoot run =
    let val raw=build ^ "/pinned-source.tar" val ()=run build (Posix.ProcEnv.environ ()) ["xz","--decompress","--stdout",archive] "source-unpack"
        val unpacked=read (build ^ "/source-unpack.log") val members=BuildArchive.readTar unpacked
        fun safe name=not (OS.Path.isAbsolute name) andalso not (List.exists (fn part => part="..") (fields #"/" name))
        val ()=List.app (fn (member:BuildArchive.member) => need (safe (#name member),"unsafe source archive member " ^ #name member)) members
        val source=sourceRoot ^ "/gmp-" ^ version
        val ()=if exists (source ^ "/configure") then () else
            (mkdirs sourceRoot;run build (Posix.ProcEnv.environ ()) ["tar","--extract","--xz","--file",archive,"--directory",sourceRoot,"--no-same-owner"] "source-extract")
        fun verify (member:BuildArchive.member) =
          let val file=sourceRoot ^ "/" ^ #name member
          in if #kind member = #"0" orelse #kind member = #"\000" then
                 need (exists file andalso not (isDir file) andalso hash file=Hex.fromBytes (Sha256.digest (#data member)),"GMP source cache differs from the pinned archive: " ^ #name member)
             else if #kind member = #"2" then need (isLink file andalso OS.FileSys.readLink file= #link member,"GMP source symlink differs from the pinned archive: " ^ #name member) else () end
    in List.app verify members;source end
  fun build args =
    let val ()=OS.FileSys.chDir root
        val options=O.parse [("--prefix",O.Value),("--cc",O.Value),("--cflags",O.Value),("--ldflags",O.Value),("--host",O.Value),("--build",O.Value),("--cc-for-build",O.Value),("--runner",O.Value),("--jobs",O.Value),("--timeout",O.Value),("--disable-assembly",O.Flag),("--enable-fat",O.Flag),("--with-pic",O.Flag),("--abi",O.Value)] [] args
        val prefix=absolute (O.get options "--prefix" "build/deps/gmp/native") val cc=O.get options "--cc" (env ("CC","cc")) val cflags=O.get options "--cflags" "-O2" val ldflags=O.get options "--ldflags" ""
        val host=O.get options "--host" "" val buildTarget=O.get options "--build" "" val buildCC=O.get options "--cc-for-build" "cc" val runner=O.get options "--runner" "" val jobs=integer (O.get options "--jobs" "4") val timeout=integer (O.get options "--timeout" "1800")
        val disabled=O.flag options "--disable-assembly" val fat=O.flag options "--enable-fat" val pic=O.flag options "--with-pic" val abi=O.get options "--abi" ""
        val ()=need (jobs>=1 andalso timeout>=1,"jobs and timeout must be positive") val ()=need (not (fat andalso disabled),"fat CPU selection requires assembly") val ()=need (List.exists (fn value => value=abi) ["","32","64"],"ABI must be 32 or 64")
        val config=Json.Object [("prefix",str prefix),("cc",str cc),("cflags",str cflags),("ldflags",str ldflags),("host",str host),("build",str buildTarget),("cc_for_build",str buildCC),("runner",str runner),("jobs",number jobs),("timeout",number timeout),
             ("disable_assembly",Json.Bool disabled),("enable_fat",Json.Bool fat),("with_pic",Json.Bool pic),("abi",str abi),("version",str version),("sha256",str checksum),("url",str url),("download_urls",strings urls),("linkage",str "static"),("upstream_tests",str "required"),("recipe_sha256",str (recipe ()))]
        val key=String.substring (Hex.fromBytes (Sha256.digest (BuildGMPConfig.metadataJSON (BuildGMPConfig.canonical config))),0,16)
        val directory=fromRoot ("build/deps/gmp-build/" ^ key) val ()=mkdirs directory val metadata=prefix ^ "/rune-gmp.json"
        val previous=if exists metadata then SOME (readJson metadata) else NONE
        val fresh=case previous of NONE => false | SOME old => field "config" old=config andalso exists (prefix ^ "/lib/libgmp.a") andalso exists (prefix ^ "/include/gmp.h") andalso text (field "library_sha256" old)=hash (prefix ^ "/lib/libgmp.a") andalso text (field "header_sha256" old)=hash (prefix ^ "/include/gmp.h")
    in if fresh then (say ("GMP " ^ version ^ ": verified existing build " ^ prefix ^ "\n");0) else
       let val (run,commands)=makeRunner directory (Real.fromInt timeout) true
           val archive=fromRoot ("build/deps/downloads/gmp-" ^ version ^ ".tar.xz") val ()=mkdirs (OS.Path.dir archive)
           val downloaded=downloads archive checksum urls "curl" (fn args => fn name => run directory (Posix.ProcEnv.environ ()) args name)
           val sourceRoot=directory ^ "/source" val source=validateSource archive directory sourceRoot run
           val environment=setEnv ("CPPFLAGS","") (unset "ABI" (setEnv ("CC_FOR_BUILD",buildCC) (setEnv ("LDFLAGS",ldflags) (setEnv ("CFLAGS",cflags) (setEnv ("CC",cc) (Posix.ProcEnv.environ ()))))))
           val environment=if abi="" then environment else setEnv ("ABI",abi) environment
           fun observe label args=successful (execute root (directory ^ "/" ^ label) 60.0 args environment)
           val hostTarget=if fat andalso host="" then observe "host-target" (words cc @ ["-dumpmachine"]) else host
           val buildTarget=if hostTarget<>"" orelse buildTarget<>"" then if buildTarget<>"" then buildTarget else observe "build-target" (words buildCC @ ["-dumpmachine"]) else ""
           val configure=[source ^ "/configure","--prefix=" ^ prefix,"--disable-shared","--enable-static"] @ (if hostTarget="" then [] else ["--host=" ^ hostTarget]) @ (if buildTarget="" then [] else ["--build=" ^ buildTarget]) @ (if disabled then ["--disable-assembly"] else []) @ (if fat then ["--enable-fat"] else []) @ (if pic then ["--with-pic"] else [])
           val ()=run directory environment configure "configure"
           val ()=run directory environment ["make","-j" ^ Int.toString jobs] "build"
           val ()=run directory environment (["make","-j" ^ Int.toString jobs,"check"] @ (if runner="" then [] else ["LOG_COMPILER=" ^ runner])) "check"
           val ()=run directory environment ["make","install"] "install"
           val keys=["ABI","CC","CFLAGS","CPPFLAGS","GMP_LDFLAGS","build","host"]
           val configured=Json.Object (List.mapPartial (fn line => case Substring.position " = " (Substring.full line) of (a,b) =>
                    let val key=Substring.string a in if Substring.isEmpty b orelse not (List.exists (fn name => name=key) keys) then NONE else SOME (key,str (Substring.string (Substring.triml 3 b))) end) (lines (read (directory ^ "/Makefile"))))
           val compiler=case lines (observe "compiler-version" (words cc @ ["--version"])) of first::_ => first | [] => raise Failed "compiler has no version"
           val record=Json.Object [("config",config),("configured",configured),("commands",Json.Array (!commands)),("build_directory",str directory),("source_archive",Json.Object [("path",str archive),("sha256",str checksum),("download_url",case downloaded of NONE => Json.Null | SOME url => str url)]),
                    ("c_compiler",str compiler),("library_sha256",str (hash (prefix ^ "/lib/libgmp.a"))),("header_sha256",str (hash (prefix ^ "/include/gmp.h"))),("upstream_check",str "pass")]
           val ()=json metadata record val license=prefix ^ "/share/licenses/gmp" val ()=mkdirs license
           val ()=List.app (fn name => if exists (source ^ "/" ^ name) then copy (source ^ "/" ^ name) (license ^ "/" ^ name) else ()) ["COPYING","COPYING.LESSERv3","COPYINGv2","COPYINGv3"]
       in say ("GMP " ^ version ^ ": built and tested in " ^ prefix ^ "\n");0 end end
  fun main ("download"::args)=download args | main args=build args
end
