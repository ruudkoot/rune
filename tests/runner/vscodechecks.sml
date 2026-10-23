(* Independent staging fixtures: real packager, literal expected member set,
   inert ELF/PE headers, and planted failures. No npm/network dependency. *)
structure VSCodeChecks =
struct
  open Sh
  fun check (ok,why)=if ok then () else raise Fail ("VSIX staging: " ^ why)
  fun archive file =
    let val dir=run ^ "/vscode-archive" val ()=mkdirs dir
        val members=ArchiveCheck.zip(ArchiveCheck.binary file)
        val basis=List.mapPartial(fn line=>
          let val line=Hosts.trim line
          in if line="" orelse String.isPrefix "#" line then NONE else
            SOME("extension/server/lib/basis/" ^ Hosts.trim(hd(String.fields(fn c=>c= #"|")line))) end)
          (String.fields(fn c=>c= #"\n")(read(fromRoot "lib/basis/MANIFEST")))
        val expected=["extension.vsixmanifest","[Content_Types].xml","extension/LICENSE.txt","extension/readme.md",
          "extension/ThirdPartyNotices.txt","extension/package.json","extension/sml-language.json","extension/dist/extension.js",
          "extension/notices/gmp/COPYING","extension/notices/gmp/COPYING.LESSERv3","extension/notices/gmp/COPYINGv2",
          "extension/notices/gmp/COPYINGv3","extension/server/bin/runevm","extension/server/bin/runevm.exe",
          "extension/server/bin/runelsp.rbc","extension/server/lib/basis/MANIFEST"] @ basis
        val ()=ArchiveCheck.memberNames expected(List.map(fn m:ArchiveCheck.zipped=> #name m)members)
        val ()=List.app(fn m:ArchiveCheck.zipped=>if String.isSuffix "/runevm" (#name m) orelse String.isSuffix "/runevm.exe" (#name m)
          then check(IntInf.mod(IntInf.div(#attributes m,65536),512)=493,"packaged runtime permissions") else ())members
        fun decode label name=ArchiveCheck.decode dir label ["unzip","-p",file,name]
        val ()=List.app(fn(name,source)=>check(decode(OS.Path.file name)name=read(fromRoot source),"payload differs: " ^ name))
          [("extension/server/bin/runevm","bin/dist/runevm"),("extension/server/bin/runevm.exe","bin/dist/runevm.exe"),
           ("extension/server/bin/runelsp.rbc","bin/runelsp.rbc")]
        val manifest=Json.decode(decode "manifest" "extension/package.json")
        val version=case Json.member("runeVersion",manifest) of SOME(Json.String value)=>value | _=>raise Fail "missing Rune version"
        val ()=check(OS.Path.file file="rune-language-server-" ^ version ^ ".vsix","filename/version mismatch")
        val ()=check(Json.member("publisher",manifest)=SOME(Json.String "ruudkoot"),"publisher mismatch")
    in say "PASS vscode/archive-members-payload-modes-version\n" end
  fun stage () =
    let val dir=run ^ "/vscode-stage"
        val ()=mkdirs dir
        fun put (name,text)=(mkdirs(OS.Path.dir(dir ^ "/" ^ name));write(dir ^ "/" ^ name,text))
        val ()=List.app put [("lib/basis/MANIFEST","one.sml | always | yes | One | \n"),
          ("lib/basis/one.sml","structure One=struct end\n"),("lib/basis/stray.sml","exclude\n"),
          ("lib/other/MANIFEST","exclude\n"),("server.rbc","bytecode\n"),
          ("client/extension.js","client\n"),("client/ThirdPartyNotices.txt","licenses\n")]
        val ()=BinaryFixtures.write(dir ^ "/linux") (BinaryFixtures.elf "x86_64" "/lib64/ld-linux-x86-64.so.2" ["libc.so.6"])
        val ()=BinaryFixtures.write(dir ^ "/windows") (BinaryFixtures.pe 0x8664)
        val out=dir ^ "/extension with spaces"
        fun package name extra = InstallChecks.execute dir name root ""
          ([fromRoot "bin/rune-build","package-lsp","--version","1.2.3","--out",out,
            "--server",dir ^ "/server.rbc","--lib",dir ^ "/lib","--linux",dir ^ "/linux",
            "--windows",dir ^ "/windows","--client",dir ^ "/client","--publisher","testpublisher"] @ extra)
        val ()=Scenarios.success(package "good" [])
        val manifest=Json.decode(read(out ^ "/package.json"))
        val ()=check(Json.member("version",manifest)=SOME(Json.String "1.2.3") andalso
          Json.member("runeVersion",manifest)=SOME(Json.String "1.2.3") andalso
          Json.member("publisher",manifest)=SOME(Json.String "testpublisher"),"version/publisher metadata")
        val ()=check(Json.member("devDependencies",manifest)=NONE andalso Json.member("scripts",manifest)=NONE,"build tools leaked")
        val expected=["package.json","README.md","LICENSE","sml-language.json","ThirdPartyNotices.txt",".rune-vscode",".vscodeignore",
          "dist/extension.js","server/bin/runevm","server/bin/runevm.exe","server/bin/runelsp.rbc",
          "server/lib/basis/MANIFEST","server/lib/basis/one.sml"]
        val actual=List.filter(fn name=>not(String.isPrefix "notices/" name))
          (List.map(fn path=>String.extract(path,size out+1,NONE))(InstallChecks.files out))
        val ()=check(sort expected=sort actual,"member set")
        val ()=check(same(dir ^ "/linux",out ^ "/server/bin/runevm") andalso
          OS.FileSys.access(out ^ "/server/bin/runevm",[OS.FileSys.A_EXEC]),"runtime bytes/mode")
        val ()=put("linux","changed build output\n")
        val ()=check(read(out ^ "/server/bin/runevm")<>read(dir ^ "/linux"),"runtime was not a private copy")
        val original=read(out ^ "/package.json")
        val refused=package "bad-binary" []
        val ()=check(#status refused<>0 andalso String.isSubstring "not an ELF file" (#errors refused)
          andalso read(out ^ "/package.json")=original,"bad binary replaced previous stage")
        val ()=BinaryFixtures.write(dir ^ "/linux") (BinaryFixtures.elf "x86_64" "/lib64/ld-linux-x86-64.so.2" ["libc.so.6"])
        val ()=put("lib/basis/MANIFEST","../outside | always | yes | | \n")
        val refused=package "bad-manifest" []
        val ()=check(#status refused<>0 andalso String.isSubstring "unsafe Basis source" (#errors refused)
          andalso read(out ^ "/package.json")=original,"unsafe manifest replaced previous stage")
        val ()=put("lib/basis/MANIFEST","one.sml | always | yes | One | \n")
        val refused=package "missing-notices" ["--gmp-notices",dir ^ "/missing-notices"]
        val ()=check(#status refused<>0 andalso String.isSubstring "missing packaged GMP notices" (#errors refused)
          andalso read(out ^ "/package.json")=original,"missing notices replaced previous stage")
        val ()=Scenarios.success(package "repeat" [])
    in say "PASS vscode/staging\n" end
end
