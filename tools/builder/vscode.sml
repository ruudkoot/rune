(* SML owns VSIX staging; JS tools bundle the client and encode the container. *)
structure BuildVSCode =
struct
  open BuildCommon
  structure O=BuildOptions
  fun numeric value=value<>"" andalso CharVector.all Char.isDigit value andalso
    (size value=1 orelse String.sub(value,0)<> #"0")
  fun release value=case fields #"." value of [a,b,c]=>List.all numeric [a,b,c] | _=>false
  fun manifestVersion (version,git) =
    if release version then version else
      let val ()=need(git ["rev-parse","--is-shallow-repository"]="false",
            "VSIX snapshot version requires complete Git history; fetch --unshallow")
          val count=git ["rev-list","--count","HEAD"]
          val ()=need(numeric count andalso count<>"0","cannot derive VSIX version from Git history")
      in "0.0." ^ count end
  fun safe path=path<>"" andalso not(OS.Path.isAbsolute path) andalso
    List.all(fn arc=>arc<>"" andalso arc<>"." andalso arc<>"..") (fields #"/" path) andalso
    not(String.isSubstring "\\" path)
  fun selfTest () =
    let fun git ["rev-parse","--is-shallow-repository"]="false"
          | git ["rev-list","--count","HEAD"]="1234" | git _=raise Failed "unexpected Git query"
        fun check(ok,why)=need(ok,"VSIX version self-test: " ^ why)
        val ()=check(manifestVersion("1.2.3",fn _=>raise Failed "release queried Git")="1.2.3","release")
        val ()=List.app(fn version=>check(manifestVersion(version,git)="0.0.1234",version))
          ["abcdef123","abcdef123-dirty","1.2.3-dirty","0.1","01.2.3"]
        val ()=check((manifestVersion("abcdef",fn _=>"true");false) handle Failed _=>true,"shallow history")
        val ()=check((manifestVersion("abcdef",fn _=>raise Failed "no Git");false) handle Failed _=>true,"missing history")
        val ()=List.app(fn path=>check(not(safe path),path))["/outside","../outside","x/../outside","x\\outside"]
    in say "PASS vscode/version-and-paths\n" end
  fun main args =
    let val options=O.parse [("--version",O.Value),("--out",O.Value),("--server",O.Value),
          ("--linux",O.Value),("--windows",O.Value),("--lib",O.Value),("--extension",O.Value),
          ("--client",O.Value),("--publisher",O.Value),("--vsix",O.Value),("--node",O.Value),
          ("--gmp-notices",O.Value),("--self-test",O.Flag)] [] args
    in if O.flag options "--self-test" then (selfTest();0) else
      let val version=O.require options "--version"
          val ()=need(version<>"" andalso CharVector.all(fn c=>Char.isAlphaNum c orelse Char.contains "._+-" c)version,
            "invalid Rune version for VSIX filename")
          val out=fromRoot(O.require options "--out")
          val source=fromRoot(O.get options "--extension" "editors/vscode")
          val client=fromRoot(O.get options "--client" "build/vscode/client")
          val library=fromRoot(O.require options "--lib") ^ "/basis"
          val linux=fromRoot(O.require options "--linux")
          val windows=fromRoot(O.require options "--windows")
          val server=fromRoot(O.require options "--server")
          val ()=BuildFormats.linux(read linux) "x86_64"
          val ()=BuildFormats.windows(read windows) "x86_64"
          val marker=".rune-vscode"
          val ()=need(not(exists out) orelse exists(out ^ "/" ^ marker),"refusing to replace an unowned extension directory: " ^ out)
          val pending=privateDirectory(OS.Path.dir out) ".vscode"
          fun run directory label command=successful(execute directory (pending ^ "/logs/" ^ label) 180.0 command (Posix.ProcEnv.environ()))
          fun git args=run root "git" ("git"::args)
          fun copyFile (name,input,mode) =
            let val target=pending ^ "/extension/" ^ name
            in copy input target;Posix.FileSys.chmod(target,Posix.FileSys.S.fromWord(SysWord.fromInt mode)) end
          fun build () =
            let val numericVersion=manifestVersion(version,git)
                val manifest=readJson(source ^ "/package.json")
                val publisher=O.get options "--publisher" (text(field "publisher" manifest))
                val manifest=Json.Object(List.filter(fn(key,_)=>not(List.exists(fn name=>name=key)
                  ["scripts","dependencies","devDependencies"])) (object manifest))
                val manifest=set "engines" (Json.Object[("vscode",field "vscode" (field "engines" manifest))]) manifest
                val manifest=set "publisher" (str publisher) (set "runeVersion" (str version)(set "version" (str numericVersion) manifest))
                val ()=mkdirs(pending ^ "/extension")
                val ()=json(pending ^ "/extension/package.json") manifest
                val ()=write(pending ^ "/extension/" ^ marker,"Rune VS Code extension staging\n")
                val ()=write(pending ^ "/extension/.vscodeignore",marker ^ "\n")
                val ()=List.app copyFile
                  [("README.md",source ^ "/README.md",420),("LICENSE",fromRoot "LICENSE",420),
                   ("sml-language.json",source ^ "/sml-language.json",420),
                   ("dist/extension.js",client ^ "/extension.js",420),
                   ("ThirdPartyNotices.txt",client ^ "/ThirdPartyNotices.txt",420),
                   ("server/bin/runevm",linux,493),("server/bin/runevm.exe",windows,493),
                   ("server/bin/runelsp.rbc",server,420),("server/lib/basis/MANIFEST",library ^ "/MANIFEST",420)]
                val names=unique(BuildDist.manifestNames(library ^ "/MANIFEST"))
                val ()=List.app(fn name=>
                  (need(safe name andalso not(isLink(library ^ "/" ^ name)),"unsafe Basis source in manifest: " ^ name);
                   copyFile("server/lib/basis/" ^ name,library ^ "/" ^ name,420)))names
                val supplied=O.get options "--gmp-notices" ""
                val gmp=fromRoot(if supplied="" then "build/deps/gmp/native-dist/share/licenses/gmp" else supplied)
                val ()=need(supplied="" orelse isDir gmp,"missing packaged GMP notices: " ^ gmp)
                val ()=if isDir gmp then List.app(fn name=>copyFile("notices/gmp/" ^ name,gmp ^ "/" ^ name,420)) (sorted(entries gmp)) else ()
                val vsix=O.get options "--vsix" ""
                val ()=if vsix="" then () else
                  let val directory=fromRoot vsix val ()=mkdirs directory
                      val package=pending ^ "/rune-language-server-" ^ version ^ ".vsix"
                      val node=O.get options "--node" (env("NODE","node"))
                      val _=run (pending ^ "/extension") "vsce" [node,source ^ "/node_modules/@vscode/vsce/vsce",
                        "package","--no-dependencies","--out",package]
                  in OS.FileSys.rename{old=package,new=directory ^ "/" ^ OS.Path.file package};say(directory ^ "/" ^ OS.Path.file package ^ "\n") end
                val old=pending ^ "/previous" val existed=exists out
                val ()=if existed then OS.FileSys.rename{old=out,new=old} else ()
                val ()=OS.FileSys.rename{old=pending ^ "/extension",new=out}
                  handle error=>(if existed then OS.FileSys.rename{old=old,new=out} else ();raise error)
            in say("VS Code extension: " ^ out ^ " (Rune " ^ version ^ ", manifest " ^ numericVersion ^ ")\n") end
      in (build() handle error=>(remove pending;raise error));remove pending;0 end
    end
end
