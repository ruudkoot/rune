(* libraries: test/unit random compiler *)
structure CompilerAnalysisTests =
struct
  structure C=RuneCompiler
  structure A=C.Analysis
  val check=Expect.that
  fun input (file,text,revision):A.input={file=file,text=text,revision=revision,mode="ascii",annotations=[]}
  fun compiler ()=C.session {lib=NONE,flags=[]}
  fun analyze (context,inputs)=A.check (context,{project=NONE,inputs=inputs,cancelled=fn () => false})
  fun same (left,right)=A.facts left=A.facts right andalso A.occurrences left=A.occurrences right
    andalso A.diagnostics left=A.diagnostics right andalso A.types left=A.types right
  fun snapshots () =
    let val parent=compiler ()
        val context=A.create (parent,{context="target-one"})
        val first=input ("one.sml","fun id x=x\nval answer=42\n","v1")
        val second=input ("two.sml","val copy=id answer\n","v1")
        val initial=analyze (context,[first,second])
        val saved=A.checkpoint context
        val repeated=analyze (context,[first,second])
        val ()=check ("warm query facts equal original",same (initial,repeated) andalso #checked (A.work repeated)=0)
        val ()=check ("snapshot ids do not repeat",A.id initial<>A.id repeated andalso A.context initial="target-one")
        val firstV2=input ("one.sml",#text first,"v2")
        val versioned=analyze (context,[firstV2,second])
        val ()=check ("version belongs to the new snapshot",#revision (hd (A.inputs versioned))="v2"
          andalso #revision (hd (A.inputs initial))="v1" andalso #checked (A.work versioned)=0)
        val changed=analyze (context,[first,input ("two.sml","val copy=id (answer+1)\n","v2")])
        val fresh=A.create (parent,{context="target-one"})
        val oracle=analyze (fresh,A.inputs changed)
        val ()=check ("changed suffix equals fresh analysis",same (changed,oracle) andalso #reused (A.work changed)=1)
        val failed=analyze (context,[first,input ("two.sml","val wrong:int=true\n","v3")])
        val ()=check ("rejected unit is unavailable",not (null (A.diagnostics failed))
          andalso not (List.exists (fn fact:A.fact => #file fact="two.sml") (A.facts failed)))
        val ()=A.restore (context,saved)
        val afterRestore=analyze (context,[first,second])
        val ()=check ("validated checkpoint replays",same (initial,afterRestore) andalso #checked (A.work afterRestore)=0)
        val polls=ref 0
        val cancelled=(ignore (A.check (context,{project=NONE,inputs=[first,second],
          cancelled=fn () => (polls:= !polls+1; !polls=4)}));false) handle A.Cancelled => true
        val afterCancel=analyze (context,[first,second])
        val ()=check ("cancelled attempts retain the cache",cancelled andalso same (initial,afterCancel) andalso #checked (A.work afterCancel)=0)
        val ()=check ("foreign checkpoints refused",(A.restore (fresh,saved);false) handle C.Failed _ => true)
        val ()=A.close context
        val ()=check ("closed analysis refused",(ignore (analyze (context,[]));false) handle C.Closed => true)
        val ()=C.close parent
    in check ("frozen snapshot survives closing",A.inputs initial=[first,second] andalso not (null (A.facts initial))) end
  fun bindings () =
    let val parent=compiler ()
        val context=A.create (parent,{context="bindings"})
        val sources=[input ("one.sml","exception E\n","1"),
          input ("two.sml","exception E2=E\nval original=E\nval alias=E2\n","1"),
          input ("three.sml","local exception E2=E in val shadow=E2 end\nval outside=E2\n","1")]
        val result=analyze (context,sources)
        val cached=analyze (context,sources)
        val refs=List.filter (fn occurrence:A.occurrence => #name occurrence="E2" andalso not (#isDefinition occurrence)) (A.occurrences result)
        val locations=List.map (fn occurrence:A.occurrence => Option.map #file (#definition occurrence)) refs
        val ids=List.map #binding refs
        val ()=check ("exception aliases have lexical identities",locations=[SOME "two.sml",SOME "three.sml",SOME "two.sml"]
          andalso hd ids=List.nth (ids,2) andalso hd ids<>List.nth (ids,1))
        val ()=check ("cached bindings equal fresh",same (result,cached))
    in A.close context;C.close parent end
  fun generative () =
    let val parent=compiler ()
        val context=A.create (parent,{context="generative"})
        val text="signature S=sig type t val x:t end\nfunctor F()=struct datatype t=C val x=C end\n"
          ^ "structure A:>S=F()\nstructure B:>S=F()\nval first=A.x\nval second=B.x\n"
        val result=analyze (context,[input ("generative.sml",text,"1")])
        fun constructors name=List.concat (List.map #constructors (List.filter (fn fact:A.fact => #ty fact=name) (A.facts result)))
        val left=constructors "A.t"
        val right=constructors "B.t"
        val ()=check ("opaque functor types stay distinct",null (A.diagnostics result) andalso not (null left)
          andalso not (null right) andalso not (List.exists (fn id => List.exists (fn other => id=other) right) left))
        val ()=check ("abstract type locations retained",List.all (fn id => List.exists (fn definition:A.typeDefinition =>
          #id definition=id andalso isSome (#declaration definition) andalso isSome (#implementation definition)) (A.types result)) (left @ right))
        val ()=check ("type identities survive replay",same (result,analyze (context,[input ("generative.sml",text,"1")])))
    in A.close context;C.close parent end
  fun libraries () =
    let val parent=C.session {lib=SOME "lib",flags=[]}
        val context=A.create (parent,{context="library"})
        val sources=[input ("effects.sml","val ()=print \"analysis must not execute\\n\"\nval count=List.length [1,2,3]\n","1")]
        val result=analyze (context,sources)
        val again=analyze (context,sources)
        val ()=check ("library source captured",null (A.diagnostics result) andalso not (null (A.dependencies result)))
        val ()=check ("libraries replay statically",same (result,again) andalso #checked (A.work again)=0)
    in A.close context;C.close parent end
  fun projects () =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir handle _ => ();OS.FileSys.mkDir dir)
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val files=[("hidden.sml","structure Hidden=struct val x=41 end\n"),
          ("public.sml","structure Public=struct val x=Hidden.x+1 end\n"),
          ("final.sml","val result=Public.x\n")]
        val ()=List.app write files
        val ()=write ("scope.build","local files hidden.sml end in files public.sml end end\nfiles final.sml end\n")
        fun clean ()=(List.app (fn file => OS.FileSys.remove (dir ^ "/" ^ file))
          ("scope.build" :: List.map #1 files);OS.FileSys.rmDir dir)
        fun work () =
          let val parent=compiler ()
              val context=A.create (parent,{context="scoped"})
              val project=C.Project.read (parent,{file=dir ^ "/scope.build",variables=[],overlays=[],windows=false})
              val inputs=List.map (fn source:C.Project.source =>
                let val name=OS.Path.file (#file source)
                    val text= #2 (valOf (List.find (fn (file,_) => file=name) files))
                in {file= #file source,text=text,mode= #mode source,annotations= #annotations source,revision="1"}:A.input end)
                (C.Project.sources project)
              fun run inputs=A.check (context,{project=SOME project,inputs=inputs,cancelled=fn () => false})
              val valid=run inputs
              val cached=run inputs
              val bad=List.take (inputs,2) @ [input (dir ^ "/final.sml","val wrong=Hidden.x\n","2")]
              val rejected=run bad
              val ()=check ("project scopes are shared with the compiler",null (A.diagnostics valid)
                andalso A.project valid=SOME (C.Project.fingerprint project) andalso same (valid,cached)
                andalso #checked (A.work cached)=0 andalso not (null (A.diagnostics rejected)))
              val other=compiler ()
              val otherContext=A.create (other,{context="other"})
              val refused=(ignore (A.check (otherContext,{project=SOME project,inputs=inputs,cancelled=fn () => false}));false)
                handle C.Failed _ => true
              val ()=check ("project ownership enforced",refused)
          in A.close context;A.close otherContext;C.close parent;C.close other end
    in (work () before clean ()) handle error => (clean () handle _ => ();raise error) end
  fun batchOracle () =
    let val parent=compiler ()
        val context=A.create (parent,{context="batch-oracle"})
        val text="infixr 5 ++\nfun op ++ (a,b)=a+b\nstructure S=struct val x=41 end\nopen S\n"
          ^ "fun sum {x,y}=x ++ y\nval answer=sum {x=x,y=1}\nexception E of int\nexception Alias=E\n"
          ^ "val caught=fn Alias n=>n|_=>0\nval localValue=let val r=ref [] val _=r:=[1] in !r end\n"
        val source=input ("oracle.sml",text,"1")
        val snapshot=analyze (context,[source])
        val _=C.compileText (parent,{file="oracle.sml",text=text})
        val points=List.filter (fn fact:A.fact => #file fact="oracle.sml" andalso not (#derived fact)) (A.facts snapshot)
        val ()=check ("oracle has typed occurrences",length points>20 andalso null (A.diagnostics snapshot))
        val ()=List.app (fn fact:A.fact =>
          check ("snapshot agrees with fresh batch compiler",A.typeAt (snapshot,{file="oracle.sml",offset= #start fact})=
            C.typeAt (parent,{file="oracle.sml",offset= #start fact}))) points
    in A.close context;C.close parent end
end
structure CompilerAnalysisTestMain=Main (struct
  val name="compiler-analysis"
  val tests=Test.describe "compiler-analysis"
    [Test.it "snapshots-checkpoints-cancellation" CompilerAnalysisTests.snapshots,
     Test.it "lexical-bindings" CompilerAnalysisTests.bindings,
     Test.it "generative-identities" CompilerAnalysisTests.generative,
     Test.it "static-library-replay" CompilerAnalysisTests.libraries,
     Test.it "project-scopes" CompilerAnalysisTests.projects,
     Test.it "batch-compiler-oracle" CompilerAnalysisTests.batchOracle]
end)
val ()=CompilerAnalysisTestMain.main ()
