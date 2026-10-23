structure BuildDist =
struct
  open BuildCommon
  structure O=BuildOptions
  val linuxArchitectures=["x86_64","i686","aarch64","ppc64"]
  val windowsArchitectures=["x86_64","i686"]
  fun manifestNames file=List.mapPartial (fn line => let val name=trim (hd (fields #"|" line))
         in if name="" orelse String.isPrefix "#" name then NONE else SOME name end) (lines (read file))
  fun pathLess (a,b) =
    let fun loop ([],[])=false | loop ([],_)=true | loop (_,[])=false | loop (a::ar,b::br)=if a=b then loop (ar,br) else a<b
    in loop (fields #"/" a,fields #"/" b) end
  fun libraryFiles library =
    let val builds=sort pathLess (List.filter (fn file => OS.Path.file file="library.build" andalso not (isDir file)) (tree library))
        val ()=need (not (null builds),"no library.build under " ^ library)
        fun relative file=String.extract (file,size library+1,NONE)
        fun one build =
          let val parent=OS.Path.dir build val manifest=parent ^ "/MANIFEST" val ()=need (exists manifest,"missing " ^ manifest ^ " (make manifests)")
              val sources=List.map (fn name => let val source=parent ^ "/" ^ name
                   in need (exists source andalso not (isDir source),manifest ^ " names " ^ name ^ ", which is not there");relative source end) (manifestNames manifest)
          in relative manifest::sources @ (if exists (parent ^ "/README.md") then [relative (parent ^ "/README.md")] else []) end
        (* Complete immutable FFI sets include non-SML outputs and pointers
           beside their derived MANIFESTs. Keep the same source tree as the
           source installer, including future regenerated set identities. *)
        val assets=List.concat(List.map(fn name=>
          let val generated=library ^ "/" ^ name
          in if isDir generated then List.map relative
            (List.filter(fn file=>not(isDir file) andalso not(isLink file))(tree generated)) else [] end)
          ["ffi/sdl","ffi/win32/generated"])
    in sort pathLess(unique(List.concat(List.map one builds) @ assets)) end
  fun crlf data =
    let val n=size data
        fun loop i acc=if i=n then String.concat (List.rev acc) else
             if String.sub (data,i) = #"\r" andalso i+1<n andalso String.sub (data,i+1) = #"\n" then loop (i+2) ("\r\n"::acc)
             else if String.sub (data,i) = #"\n" then loop (i+1) ("\r\n"::acc) else loop (i+1) (String.str (String.sub (data,i))::acc)
    in loop 0 [] end
  fun icon () =
    let val branding=readJson (fromRoot "tools/builder/data/branding.json")
        val source=fromRoot (text (field "source" branding)) val icon=fromRoot (text (field "icon" branding))
        val ()=need (hash source=text (field "source_sha256" branding),"branding PNG changed; update its canonical ICO alongside it")
        val ()=need (hash icon=text (field "icon_sha256" branding),"canonical branding ICO checksum differs")
        val data=read icon val ()=need (size data>=6 andalso String.isPrefix "\000\000\001\000" data andalso BuildFormats.uint data false 4 2=4,"invalid canonical ICO")
    in data end
  fun parseMap values =
    let fun one item entries =case Substring.position "=" (Substring.full item) of (a,b) =>
           if Substring.isEmpty b then raise Usage ("expected ARCH=PATH, got " ^ item) else
              let val key=Substring.string a val value=Substring.string (Substring.triml 1 b)
              in (key,value)::List.filter (fn (old,_) => old<>key) entries end
    in List.foldl (fn (value,entries) => one value entries) [] values end
  fun selfTest () =
    let val fixtures=readJson (fromRoot "tools/builder/data/formats-v1.json")
        fun one value=
          let val data=case Hex.toBytes (text (field "hex" value)) of SOME data => data | NONE => raise Failed "invalid format fixture bytes"
              val arch=text (field "arch" value) val expected=boolean (field "accepted" value) val message=text (field "message" value)
              val refused=(if text (field "system" value)="linux" then BuildFormats.linux data arch else BuildFormats.windows data arch;NONE) handle Failed why => SOME why
          in case (expected,refused) of (true,NONE) => () | (false,SOME why) => need (String.isSubstring message why,"format refusal lacks expected diagnostic: " ^ why)
               | (true,SOME why) => raise Failed ("format self-test rejected valid " ^ arch ^ ": " ^ why) | _ => raise Failed ("format self-test accepted invalid " ^ arch) end
    in List.app one (array (field "cases" fixtures)) end
  fun main args =
    let val specifications=[("--self-test",O.Flag),("--write-ico",O.Value),("--version",O.Value),("--out",O.Value),("--lib",O.Value),("--license",O.Value),("--compiler",O.Value),("--repl",O.Value),("--ffi",O.Value),("--ffi-assets",O.Value),("--fixture",O.Flag)]
        (* Repeated runtime maps have append semantics. *)
        fun separate [] regular linux windows=(List.rev regular,List.rev linux,List.rev windows)
          | separate ("--linux"::value::rest) regular linux windows=separate rest regular (value::linux) windows
          | separate ("--windows"::value::rest) regular linux windows=separate rest regular linux (value::windows)
          | separate (arg::rest) regular linux windows=separate rest (arg::regular) linux windows
        val (args,linux,windows)=separate args [] [] [] val options=O.parse specifications [] args
        val ico=O.get options "--write-ico" ""
    in if ico<>"" then (mkdirs (OS.Path.dir ico);atomic ico (icon ());0)
       else if O.flag options "--self-test" then (selfTest ();0)
       else
        let val version=O.require options "--version" val out=O.require options "--out" val library=O.require options "--lib"
            val license=O.get options "--license" (fromRoot "LICENSE") val compiler=O.require options "--compiler" val repl=O.require options "--repl"
            val ()=need (version<>"" andalso CharVector.all (fn c => (c>= #"A" andalso c<= #"Z") orelse (c>= #"a" andalso c<= #"z") orelse Char.isDigit c orelse Char.contains "._+-" c) version,"version is not made of letters, digits, and . _ + -")
            val linux=parseMap linux val windows=parseMap windows
            val ()=need (sorted (List.map #1 linux)=sorted linuxArchitectures,"linux runtimes must be " ^ String.concatWith ", " linuxArchitectures)
            val ()=need (sorted (List.map #1 windows)=sorted windowsArchitectures,"windows runtimes must be " ^ String.concatWith ", " windowsArchitectures)
            val libs=libraryFiles library
            fun entry name data mode : BuildArchive.entry={name=name,data=data,mode=mode}
            val ffi=O.get options "--ffi" "" val assets=O.get options "--ffi-assets" ""
            val ffiFiles=if ffi="" then [] else [entry "lib/rune/runeffi.rbc" (read ffi) 420]
            val ffiFiles=ffiFiles @ (if assets="" then [] else
              List.map(fn file=>entry("lib/rune/ffi-assets/" ^ String.extract(file,size assets+1,NONE))(read file)420)
                (List.filter(fn file=>not(isDir file) andalso not(isLink file))(tree assets)))
            val common=List.map (fn name => entry ("lib/rune/" ^ name) (read (library ^ "/" ^ name)) 420) libs @
                 [entry "lib/rune/rune.rbc" (read compiler) 420,entry "lib/rune/rune-repl.img" (read repl) 420,entry "LICENSE" (read license) 420,entry "VERSION" (version ^ "\n") 420] @ ffiFiles
            fun runtimes system vms =List.map (fn (arch,path) =>
              let val data=read path val ()=if O.flag options "--fixture" then () else if system="linux" then BuildFormats.linux data arch else BuildFormats.windows data arch
              in entry ("runtime/" ^ arch ^ "/" ^ (if system="windows" then "runevm.exe" else "runevm")) data 493 end) (sort (fn ((a,_),(b,_)) => a<b) vms)
            val linuxFiles=common @ runtimes "linux" linux @ [entry "install.sh" (read (fromRoot "scripts/dist-install.sh")) 493]
            val windowsFiles=common @ runtimes "windows" windows @
                  List.map (fn name => entry name (crlf (read (fromRoot ("scripts/dist-" ^ name)))) 420) ["install.bat","uninstall.bat"] @
                  [entry "register.ps1" (read (fromRoot "scripts/dist-register.ps1")) 420,entry "share/rune.ico" (icon ()) 420] @
                  List.map (fn name => entry ("wrappers/" ^ name) (crlf (read (fromRoot ("scripts/dist-" ^ name)))) 420) (["rune.cmd","rune-repl.cmd"] @ (if ffi="" then [] else ["runeffi.cmd"]))
            val ()=mkdirs out val linuxName="rune-" ^ version ^ "-linux" val windowsName="rune-" ^ version ^ "-windows"
            val ()=BuildArchive.tar (out ^ "/" ^ linuxName ^ ".tar.gz") linuxName linuxFiles
            val ()=BuildArchive.zip (out ^ "/" ^ windowsName ^ ".zip") windowsName windowsFiles
        in say (out ^ "/" ^ linuxName ^ ".tar.gz\n" ^ out ^ "/" ^ windowsName ^ ".zip\n");0 end end
end
