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
  fun observations () =
    let exception Stopped
        val parent=compiler() val context=A.create(parent,{context="observations"})
        val source=input("observed.sml","val answer=42\n","1")
        val initial=analyze(context,[source])
        val events=ref [] : A.observation list ref
        val ()=A.observe(context,SOME(fn event=>events:=event:: !events))
        val measured=analyze(context,[source])
        val ()=check("observations preserve frozen semantic results",same(initial,measured))
        val ()=check("observations include publication and cache reuse",List.exists(fn event=>
          #phase event="snapshot-published" andalso #reused event>0)(!events))
        val ()=A.observe(context,NONE)
        val count=length(!events) val _=analyze(context,[source])
        val ()=check("disabled observer receives no phases",length(!events)=count)
        val ()=A.observe(context,SOME(fn _=>raise Stopped))
        val stopped=(analyze(context,[source]);false)handle Stopped=>true
        val ()=check("observer failure leaves earlier snapshots readable",stopped andalso same(initial,measured))
        val ()=A.observe(context,NONE) val recovered=analyze(context,[source])
        val ()=check("observer failure releases the busy context",same(initial,recovered))
    in A.close context;C.close parent end
  fun snapshots () =
    let val parent=compiler ()
        val context=A.create (parent,{context="target-one"})
        val first=input ("one.sml","fun id x=x\nval answer=42\n","v1")
        val second=input ("two.sml","val copy=id answer\n","v1")
        val initial=analyze (context,[first,second])
        val firstUnit=A.unitAt (initial,{ordinal=0})
        val secondUnit=A.unitAt (initial,{ordinal=1})
        val ()=check ("unit identities address source occurrences without interpreting their spelling",
          isSome firstUnit andalso isSome secondUnit andalso firstUnit<>secondUnit andalso
          List.exists (fn occurrence:A.occurrence => SOME (#unit occurrence)=firstUnit andalso #file occurrence="one.sml") (A.occurrences initial)
          andalso A.unitAt (initial,{ordinal= ~1})=NONE andalso A.unitAt (initial,{ordinal=2})=NONE)
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
    in check ("frozen snapshot survives closing",A.inputs initial=[first,second] andalso not (null (A.facts initial))
      andalso A.unitAt (initial,{ordinal=0})=firstUnit) end
  fun syntaxSnapshots () =
    let val parent=compiler ()
        val context=A.create (parent,{context="syntax-snapshots"})
        val first=input ("fixity.sml","infixr 6 %%\nfun (a %% b)=a+b\n","1")
        val second=input ("uses.sml","val value=1 %% 2 %% 3\n","1")
        val snapshot=analyze (context,[first,second])
        val incoming=valOf (A.syntaxAt (snapshot,{ordinal=0}))
        val syntax=valOf (A.syntaxAt (snapshot,{ordinal=1}))
        fun parse fixity=C.Syntax.parse {file= #file second,text= #text second,mode="ascii",orPatterns=false,fixity=fixity}
        val oracle=parse (C.Syntax.fixities incoming)
        val wrong=parse C.Syntax.initial
        val ()=check ("captured syntax uses actual cross-file fixities",null (A.diagnostics snapshot) andalso
          C.Syntax.events syntax=C.Syntax.events oracle andalso C.Syntax.events syntax<>C.Syntax.events wrong)
        val replayed=analyze (context,[first,second])
        val ()=check ("replayed syntax remains available",C.Syntax.events (valOf (A.syntaxAt (replayed,{ordinal=1})))=C.Syntax.events syntax)
        val brokenText="val value=(\n"
        val failed=analyze (context,[first,input ("uses.sml",brokenText,"2")])
        val broken=valOf (A.syntaxAt (failed,{ordinal=1}))
        val ()=check ("failed syntax has current text rather than the last successful tree",
          C.Syntax.text broken=brokenText andalso not (null (C.Syntax.diagnostics broken)))
        val blocked=analyze (context,[input ("fixity.sml","val bad=(\n","3"),second])
        val ()=check ("unattempted and invalid source ordinals have no syntax",
          not (isSome (A.syntaxAt (blocked,{ordinal=1}))) andalso
          not (isSome (A.syntaxAt (snapshot,{ordinal= ~1}))) andalso not (isSome (A.syntaxAt (snapshot,{ordinal=2}))))
        val ()=(A.close context;C.close parent)
    in check ("syntax snapshots survive closing and later failed attempts",C.Syntax.text syntax= #text second andalso
      C.Syntax.events syntax=C.Syntax.events oracle andalso C.Syntax.text broken=brokenText) end
  fun typeHints () =
    let val parent=compiler ()
        val context=A.create (parent,{context="type-hints"})
        val text="datatype choice=C | D of int\nval plain=1\nval typed:int=2\n"
          ^ "val (left,right)=(3,true)\nval (a,b):(int*bool)=(4,false)\n"
          ^ "fun id x=x\nval f=fn y=>y\nval nested=case D 1 of D z=>z | C=>0\n"
          ^ "val C=C\nval op @@ = fn operand=>operand\nval whole as (u,v)=(1,false)\n"
        val first=input ("hints.sml",text,"1")
        val snapshot=analyze (context,[first])
        fun hints snapshot=A.typeHints (snapshot,{ordinal=0,start=0,stop=size text})
        val found=hints snapshot
        fun named name=List.find (fn hint:A.typeHint => #name hint=name) found
        val ()=check ("inferred variable patterns use checked types",null (A.diagnostics snapshot) andalso
          List.all (fn (name,ty) => case named name of SOME hint => #ty hint=ty | NONE => false)
            [("plain","int"),("left","int"),("right","bool"),("nested","int"),("z","int"),("whole","int * bool"),("u","int"),("v","bool")])
        val ()=check ("explicit patterns and constructor occurrences have no hints",List.all
          (fn name => not (isSome (named name))) ["typed","a","b","C","D","id"])
        val ()=check ("function arguments and symbolic val bindings retain inferred types",
          List.all (fn name => isSome (named name)) ["x","f","y","@@","operand"])
        val ()=check ("hint locations select actual name tokens",List.all (fn hint:A.typeHint =>
          let val location= #location hint
          in #position hint= #stop location andalso String.substring (text,#start location,#stop location- #start location)= #name hint end) found)
        val one=valOf (named "plain")
        val ()=check ("hint ranges address their exact insertion position",
          A.typeHints (snapshot,{ordinal=0,start= #position one,stop= #position one})=[one] andalso
          null (A.typeHints (snapshot,{ordinal=0,start= ~1,stop=0})) andalso
          null (A.typeHints (snapshot,{ordinal=0,start=5,stop=4})) andalso
          null (A.typeHints (snapshot,{ordinal=1,start=0,stop=size text})))
        val ()=check ("replayed hints keep their frozen relationships",hints (analyze (context,[first]))=found)
        val failed=analyze (context,[input ("hints.sml","val broken:int=true\n","2")])
        val ()=check ("failed units cannot publish old hints",not (null (A.diagnostics failed)) andalso null (hints failed))
        val shared=input ("shared.sml","val item=seed\n","1")
        val repeated=analyze (context,[input ("first.sml","val seed=1\n","1"),shared,
          input ("second.sml","val seed=true\n","1"),shared])
        fun sharedType ordinal=List.map #ty (A.typeHints (repeated,{ordinal=ordinal,start=0,stop=size (#text shared)}))
        val ()=check ("source ordinals preserve different incoming types",sharedType 1=["int"] andalso sharedType 3=["bool"])
        val ()=(A.close context;C.close parent)
    in check ("hints remain readable after the owner closes",hints snapshot=found) end
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
  fun frozenLibrary () =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir handle _ => ();OS.FileSys.mkDir dir;OS.FileSys.mkDir (dir ^ "/basis"))
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/basis/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val ()=write ("captured.sml","structure Captured=struct (* Frozen member documentation. *) val member=1 end\n")
        val ()=write ("MANIFEST","captured.sml | always | yes | Captured | \n")
        fun clean ()=(List.app (fn path => OS.FileSys.remove path handle _ => ())
          [dir ^ "/basis/captured.sml",dir ^ "/basis/MANIFEST"];
          OS.FileSys.rmDir (dir ^ "/basis") handle _ => ();OS.FileSys.rmDir dir handle _ => ())
        fun work () =
          let val parent=C.session {lib=SOME dir,flags=[]}
              val context=A.create (parent,{context="frozen-library"})
              val snapshot=analyze (context,[input ("frozen.sml","val sample=Captured.member\n","1")])
              val ()=check ("temporary library was checked",null (A.diagnostics snapshot))
              val ()=(A.close context;C.close parent;clean ())
              val names=A.visibleAt (snapshot,{ordinal=0,offset=20,path=["Captured"]})
              val member=List.find (fn candidate:A.candidate => #name candidate="member") names
              val ()=check ("declaration documentation uses captured source after library deletion",case member of
                SOME candidate => (case #definition candidate of SOME location =>
                  A.documentationAt (snapshot,location)=SOME "Frozen member documentation." | NONE => false) | NONE => false)
          in check ("lexical query uses captured library plan after library deletion",
            List.exists (fn candidate:A.candidate => #name candidate="member" andalso #detail candidate=SOME "int") names) end
    in (work () before clean ()) handle error => (clean ();raise error) end
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
  fun repeatedSources () =
    let val parent=compiler ()
        val context=A.create (parent,{context="repeated-source"})
        val sources=[input ("before.sml","val input=1\n","1"),input ("same.sml","val result=input\n","1"),
          input ("between.sml","val input=true\n","1"),input ("same.sml","val result=input\n","1")]
        val snapshot=analyze (context,sources)
        val ()=check ("ambiguous source query has no implicit context",A.typeAt (snapshot,{file="same.sml",offset=4})=NONE)
        val ()=check ("repeated source occurrences keep incoming types",A.typeAtOccurrence (snapshot,{ordinal=1,offset=4})=SOME "int"
          andalso A.typeAtOccurrence (snapshot,{ordinal=3,offset=4})=SOME "bool")
    in A.close context;C.close parent end
  fun lexicalVisibility () =
    let val parent=compiler ()
        val context=A.create (parent,{context="visibility"})
        val text="val outer=1\nstructure S=struct val member=true end\nfun f outer=let val localName=true in outer end\n"
        val snapshot=analyze (context,[input ("visible.sml",text,"1")])
        val (prefix,_)=Substring.position "in outer" (Substring.full text)
        val offset=Substring.size prefix+3
        val names=A.visibleAt (snapshot,{ordinal=0,offset=offset,path=[]})
        val ()=check ("lexical parameter shadows outer binding",List.exists (fn candidate:A.candidate =>
          #name candidate="outer" andalso #detail candidate=SOME "'a") names)
        val ()=check ("local declaration is visible",List.exists (fn candidate:A.candidate =>
          #name candidate="localName" andalso #detail candidate=SOME "bool") names)
        val members=A.visibleAt (snapshot,{ordinal=0,offset=offset,path=["S"]})
        val ()=check ("qualified completion uses actual structure environment",List.exists (fn candidate:A.candidate =>
          #name candidate="member" andalso #detail candidate=SOME "bool") members)
        val gap=analyze (context,[input ("gap.sml","val earlier=1\n\nval later=true\n","2")])
        val gapNames=A.visibleAt (gap,{ordinal=0,offset=14,path=[]})
        val ()=check ("whitespace sees preceding declarations without forward names",
          List.exists (fn candidate:A.candidate => #name candidate="earlier") gapNames andalso
          not (List.exists (fn candidate:A.candidate => #name candidate="later") gapNames))
        val unfinished="structure S : sig val visible:int end = struct val visible=1 val hidden=2 end\nval x=S."
        val partial=analyze (context,[input ("partial.sml",unfinished,"3")])
        val partialNames=A.visibleAt (partial,{ordinal=0,offset=size unfinished,path=["S"]})
        val ()=check ("unfinished qualification observes the sealed structure",
          List.exists (fn candidate:A.candidate => #name candidate="visible") partialNames andalso
          not (List.exists (fn candidate:A.candidate => #name candidate="hidden") partialNames))
        val localText="fun f parameter = let val localName=1 in "
        val localSnapshot=analyze (context,[input ("local.sml",localText,"4")])
        val localNames=A.visibleAt (localSnapshot,{ordinal=0,offset=size localText,path=[]})
        val ()=check ("unfinished local expression retains lexical parameters and locals",
          List.exists (fn candidate:A.candidate => #name candidate="parameter") localNames andalso
          List.exists (fn candidate:A.candidate => #name candidate="localName") localNames)
        val recordText="val record={name=1,other=true}\nval selected= #na record\n"
        val recordSnapshot=analyze (context,[input ("record.sml",recordText,"5")])
        val (recordPrefix,_)=Substring.position "#na" (Substring.full recordText)
        val recordQuery=A.completionAt (recordSnapshot,{ordinal=0,offset=Substring.size recordPrefix+3,path=[]})
        val ()=check ("record labels come from the concrete operand even when the selector is unfinished",
          #role recordQuery="field" andalso List.exists (fn (name,ty) => name="name" andalso ty="int") (#fields recordQuery)
          andalso List.exists (fn (name,ty) => name="other" andalso ty="bool") (#fields recordQuery))
        val ()=(A.close context;C.close parent)
        val closedNames=A.visibleAt (snapshot,{ordinal=0,offset=offset,path=["S"]})
    in check ("closed context retains frozen lexical queries",List.exists (fn candidate:A.candidate =>
      #name candidate="member" andalso #detail candidate=SOME "bool") closedNames) end
  fun signatures () =
    let val parent=compiler ()
        val context=A.create (parent,{context="signatures"})
        fun query (text,needle) =
          let val snapshot=analyze (context,[input ("calls.sml",text,"1")])
              val (prefix,_)=Substring.position needle (Substring.full text)
          in A.signatureAt (snapshot,{ordinal=0,offset=Substring.size prefix+size needle}) end
        val curried=query ("fun choose (x:int) (y:bool)=x\nval result=choose 1 false\n","fals")
        val ()=check ("curried signature selects its second domain",case curried of SOME call =>
          #name call="choose" andalso #arguments call=[["int"],["bool"]] andalso #argument call=1 andalso #parameter call=0 | NONE => false)
        val tuple=query ("fun pair (x:int,y:bool)=x\nval result=pair(1,false)\n","fals")
        val ()=check ("tuple signature selects its second component",case tuple of SOME call =>
          #arguments call=[["int","bool"]] andalso #argument call=0 andalso #parameter call=1 | NONE => false)
        val infixCall=query ("infix 5 <+>\nfun (x:int) <+> (y:bool)=x\nval result=1 <+> false\n","fals")
        val ()=check ("infix signature uses compiler desugaring",case infixCall of SOME call =>
          #name call="<+>" andalso #arguments call=[["int","bool"]] andalso #parameter call=1 | NONE => false)
        val partial="structure S=struct fun f(x:int,y:bool)=x end\nval result=S.f(1, "
        val qualified=query (partial,partial)
        val ()=check ("unfinished qualified call retains compiler argument position",case qualified of SOME call =>
          #name call="f" andalso #path call=["S"] andalso #arguments call=[["int","bool"]] andalso #parameter call=1 | NONE => false)
        val localText="fun f (x:int)=x\nval result=let fun f (x:bool)=x in f ("
        val localCall=query (localText,localText)
        val ()=check ("signature selects the lexical function rather than a same-name outer binding",case localCall of
          SOME call => #arguments call=[["bool"]] | NONE => false)
    in A.close context;C.close parent end
end
structure CompilerAnalysisTestMain=Main (struct
  val name="compiler-analysis"
  val tests=Test.describe "compiler-analysis"
    [Test.it "observations" CompilerAnalysisTests.observations,
     Test.it "snapshots-checkpoints-cancellation" CompilerAnalysisTests.snapshots,
     Test.it "captured-syntax-snapshots" CompilerAnalysisTests.syntaxSnapshots,
     Test.it "inferred-pattern-type-hints" CompilerAnalysisTests.typeHints,
     Test.it "lexical-bindings" CompilerAnalysisTests.bindings,
     Test.it "generative-identities" CompilerAnalysisTests.generative,
     Test.it "static-library-replay" CompilerAnalysisTests.libraries,
     Test.it "frozen-library-query" CompilerAnalysisTests.frozenLibrary,
     Test.it "project-scopes" CompilerAnalysisTests.projects,
     Test.it "batch-compiler-oracle" CompilerAnalysisTests.batchOracle,
     Test.it "repeated-source-contexts" CompilerAnalysisTests.repeatedSources,
     Test.it "lexical-visibility" CompilerAnalysisTests.lexicalVisibility,
     Test.it "call-signatures" CompilerAnalysisTests.signatures]
end)
val ()=CompilerAnalysisTestMain.main ()
