(* libraries: test/unit random compiler *)
(* Public API checks use no compiler implementation names. They also run
   on native SML hosts, where execution is deliberately unavailable. *)
structure CompilerApiTests =
struct
  structure C = RuneCompiler
  val check = Expect.that
  fun session () = C.session {lib=NONE,flags=[]}
  fun text (context,file,source) = C.compileText (context,{file=file,text=source})
  fun fails action = (action ();false) handle C.Failed ds => not (null ds)
  fun read path =
    let val input=BinIO.openIn path
    in BinIO.inputAll input before BinIO.closeIn input end
  fun remove path = OS.FileSys.remove path handle _ => ()
  fun temporary action =
    let val dir=OS.FileSys.tmpName ()
        val ()=remove dir
        val ()=OS.FileSys.mkDir dir
        fun clean () =
          let val stream=OS.FileSys.openDir dir
              fun loop () = case OS.FileSys.readDir stream of
                NONE => () | SOME name => (remove (OS.Path.concat (dir,name));loop ())
          in loop ();OS.FileSys.closeDir stream;OS.FileSys.rmDir dir end
    in (action dir before clean ()) handle e => (clean () handle _ => ();raise e) end
  val generative = "signature S = sig type t val x:t end\n"
    ^ "functor F () = struct datatype t=C val x=C end\n"
    ^ "structure A :> S = F ()\nstructure B :> S = F ()\n"
    ^ "exception E of int\nexception E2=E\nval answer=42\n"
  fun isolation () = temporary (fn dir =>
    let val a=session ()
        val b=session ()
        val first=text (a,"first.sml",generative)
        val ()=check ("fresh context has no other context's names",
          fails (fn () => ignore (text (b,"missing.sml","val missing=answer\n"))))
        val ()=check ("opaque functor results remain distinct",
          fails (fn () => ignore (text (a,"generative.sml","val wrong:A.t=B.x\n"))))
        val second=text (b,"first.sml",generative)
        val ()=C.writeUnit (first,dir ^ "/a.rbu")
        val ()=C.writeUnit (second,dir ^ "/b.rbu")
        val ()=check ("independent contexts produce identical unit bytes",read (dir ^ "/a.rbu")=read (dir ^ "/b.rbu"))
        val ()=check ("mixed contexts cannot form a program",
          fails (fn () => C.writeProgram ([first,second],dir ^ "/mixed.rbc")))
        val _=text (a,"later.sml","val later=answer+1\nval replicated=E2 3\n")
        val ()=C.close a
        val ()=C.close a
        val ()=check ("closed context rejects compilation",
          (ignore (text (a,"closed.sml","val x=1"));false) handle C.Closed => true)
        val ()=check ("closed context rejects queries",
          (ignore (C.typeAt (a,{file="first.sml",offset=0}));false) handle C.Closed => true)
        val ()=C.writeUnit (first,dir ^ "/closed.rbu")
        val ()=check ("immutable artifact survives closing",read (dir ^ "/closed.rbu")=read (dir ^ "/a.rbu"))
    in C.close b end)
  fun diagnostics () =
    let val context=session ()
        val diagnostics=(ignore (text (context,"bad.sml","val bad:int=true\n"));[])
          handle C.Failed ds => ds
        val ()=check ("errors carry source and positions",List.exists (fn d : C.diagnostic =>
          #file d="bad.sml" andalso #severity d="error" andalso #line d=1 andalso #column d>=1
          andalso #start d>=0 andalso #stop d>= #start d andalso #message d<>"") diagnostics)
        val _=text (context,"good.sml","val answer=42\n")
        val ()=check ("bad flag is a diagnostic",fails (fn () => ignore (C.session {lib=NONE,flags=["--unknown"]})))
    in C.close context end
  fun queries () =
    let val context=session ()
        val _=text (context,"local.sml","val result=let val r=ref [] val _=r:=[1] in !r end\n")
        val _=text (context,"function.sml","fun id x=x\n")
        val ()=check ("local late constraints reach binder queries",
          C.typeAt (context,{file="local.sml",offset=19})=SOME "int list ref")
        val ()=check ("polymorphic parameter query",C.typeAt (context,{file="function.sml",offset=7})=SOME "'a")
        val ()=check ("non-occurrence query",C.typeAt (context,{file="absent.sml",offset=0})=NONE)
    in C.close context end
  fun artifacts () = temporary (fn dir =>
    let val context=session ()
        val first=text (context,"first.sml","val answer=42\n")
        val second=text (context,"second.sml","val copy=answer\n")
        val ()=C.writeUnit (first,dir ^ "/first.rbu")
        val ()=C.writeUnit (second,dir ^ "/second.rbu")
        val imported=session ()
        val ()=check ("missing dependency rejected",fails (fn () => ignore (C.readUnit (imported,dir ^ "/second.rbu"))))
        val _=C.readUnit (imported,dir ^ "/first.rbu")
        val loaded=C.readUnit (imported,dir ^ "/second.rbu")
        val ()=check ("duplicate imports are rejected",fails (fn () => ignore (C.readUnit (imported,dir ^ "/second.rbu"))))
        val ()=C.writeUnit (loaded,dir ^ "/loaded.rbu")
        val ()=check ("unit round trip preserves code",read (dir ^ "/loaded.rbu")=read (dir ^ "/second.rbu"))
        val _=text (imported,"later.sml","val later=copy+1\n")
        val midContext=session ()
        val _=C.readMid (midContext,{basis=dir ^ "/first.rbi",mid=dir ^ "/first.rbm"})
        val mid=C.readMid (midContext,{basis=dir ^ "/second.rbi",mid=dir ^ "/second.rbm"})
        val ()=C.writeProgram ([mid],dir ^ "/program.rbc")
        val ()=check ("Mid can produce a program",Word8Vector.length (read (dir ^ "/program.rbc"))>0)
        val stack=C.session {lib=NONE,flags=["--target=stack"]}
        val _=C.readMid (stack,{basis=dir ^ "/first.rbi",mid=dir ^ "/first.rbm"})
        val stackMid=C.readMid (stack,{basis=dir ^ "/second.rbi",mid=dir ^ "/second.rbm"})
        val ()=C.writeProgram ([stackMid],dir ^ "/stack.rbc")
        val ()=check ("Mid regenerates the other backend",read (dir ^ "/stack.rbc")<>read (dir ^ "/program.rbc"))
        val output=BinIO.openOut (dir ^ "/first.rbs")
        val ()=BinIO.output (output,Byte.stringToBytes "corrupt")
        val ()=BinIO.closeOut output
        val corrupt=session ()
        val ()=check ("corrupt source companion rejected",fails (fn () => ignore (C.readUnit (corrupt,dir ^ "/first.rbu"))))
        val output=BinIO.openOut (dir ^ "/first.rbs")
        val ()=BinIO.output (output,Byte.stringToBytes "RCS\002\255\255\255\255\127")
        val ()=BinIO.closeOut output
        val ()=check ("oversized metadata length is a diagnostic on every host",
          fails (fn () => ignore (C.readUnit (corrupt,dir ^ "/first.rbu"))))
        val _=text (corrupt,"after-corrupt.sml","val recovered=1\n")
    in List.app C.close [context,imported,midContext,corrupt,stack] end)
  fun projects () = temporary (fn dir =>
    let val context=session ()
        val root=dir ^ "/root.build"
        val child=dir ^ "/child.build"
        val rootText="libraries json end\nannotate \"unicode\" \"allowPrim\" in use child.build end\nuse child.build\ncache $(ROOT)/cache\n"
        val overlays=[{file=root,text=rootText},{file=child,text="files first.sml second.sml end\n"}]
        fun plan overlays=C.Project.read (context,{file=root,variables=[("ROOT",dir)],overlays=overlays,windows=false})
        val first=plan overlays
        val second=plan overlays
        val sources=C.Project.sources first
        val ()=check ("project use/order",List.map #file sources=[dir ^ "/first.sml",dir ^ "/second.sml"])
        val ()=check ("project annotations through use",List.all (fn s:C.Project.source =>
          #mode s="unicode" andalso #annotations s=["unicode","allowPrim"]) sources)
        val ()=check ("project inputs captured once",length (C.Project.inputs first)=2)
        val ()=check ("project library/cache metadata",C.Project.libraries first=["json"] andalso
          C.Project.cacheDirectories first=[dir ^ "/cache"])
        val ()=check ("project fingerprint deterministic",C.Project.fingerprint first=C.Project.fingerprint second)
        val changed=plan [{file=root,text="files another.sml end\n"}]
        val ()=check ("project changes invalidate fingerprint",C.Project.fingerprint first<>C.Project.fingerprint changed)
        val ()=check ("project path variables do not leak",fails (fn () => ignore (C.Project.read (context,
          {file=root,variables=[],overlays=overlays,windows=false}))))
        val grouped=C.Project.read (context,{file=root,variables=[],windows=false,overlays=
          [{file=root,text="group second.sml first.sml end\n"},
           {file=dir ^ "/second.sml",text="structure B=struct val x=A.x end\n"},
           {file=dir ^ "/first.sml",text="structure A=struct val x=1 end\n"}]})
        val ()=check ("group order uses compiler dependency rules",List.map #file (C.Project.sources grouped)=
          [dir ^ "/first.sml",dir ^ "/second.sml"])
        val ()=check ("group discovery inputs recorded",length (C.Project.inputs grouped)=3)
        val windows=C.Project.read (context,{file="C:\\project\\root.build",variables=[("DEP","D:\\dependency")],
          windows=true,overlays=[{file="C:/project/root.build",text="files $(DEP)/a.sml end\n"}]})
        val ()=check ("Windows absolute path variables",List.map #file (C.Project.sources windows)=["D:/dependency/a.sml"])
        val ()=C.close context
    in check ("project value survives session close",length (C.Project.sources first)=2) end)
end
structure CompilerApiTestMain = Main (struct
  val name="compiler-api"
  val tests=Test.describe "compiler-api"
    [Test.it "isolation" CompilerApiTests.isolation,
     Test.it "diagnostics" CompilerApiTests.diagnostics,
     Test.it "queries" CompilerApiTests.queries,
     Test.it "artifacts" CompilerApiTests.artifacts,
     Test.it "projects" CompilerApiTests.projects]
end)
val ()=CompilerApiTestMain.main ()
