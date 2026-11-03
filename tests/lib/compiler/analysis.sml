(* libraries: test/unit random compiler *)
structure CompilerAnalysisTests =
struct
  structure C=CompilerApi
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
        val ()=check("a reused unit sends no message per input (E23)",not(List.exists(fn event=>
          #phase event="names-start" orelse #phase event="unit-start")(!events)))
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
  (* What is kept against a fresh analysis, with how each check went: units
     held between checks, a change at its own place, usages past a change. *)
  fun freshly (parent,inputs)=
    let val context=A.create (parent,{context="fresh"})
        val result=analyze (context,inputs)
    in A.close context;result end
  val library=input ("library.sml","signature S=sig type t val make:int->t val read:t->int end\n" ^
    "structure L:S=struct type t=int fun make x=x fun read x=x end\ndatatype shape=Round|Square\nfun area Round=1 | area Square=2\n","1")
  val client=input ("client.sml","val made=L.make 1\nval back=L.read made\nval here=area Round\n","1")
  val other=input ("other.sml","fun twice x=x+x\nval four=twice 2\n","1")
  fun edited (source:A.input,text)=input (#file source,text,"2")
  fun around (old,new) (source:A.input)=
    let val text= #text source
        val (front,found)=Substring.position old (Substring.full text)
        val ()=if Substring.isEmpty found then raise Fail ("no such text: " ^ old) else ()
    in edited (source,Substring.string front ^ new ^ String.extract (text,Substring.size front+size old,NONE)) end
  fun routed (name,snapshot,walked,rebound,loaded,cutoff,broken)=
    let val found=A.route snapshot
    in check (name ^ ": walked " ^ Bool.toString (#walked found) ^ ", rebound " ^ Int.toString (#rebound found) ^ ", loaded " ^
        Int.toString (#loaded found) ^ ", cutoff " ^ Int.toString (#cutoff found) ^ ", broken " ^ Int.toString (#broken found),
        found={walked=walked,rebound=rebound,loaded=loaded,cutoff=cutoff,broken=broken,stored=0}) end
  (* the same answers, unit by unit, closed units opened *)
  fun sameUnits (left,right)=A.diagnostics left=A.diagnostics right andalso A.types left=A.types right andalso
    List.all (fn ordinal => case (A.unitAt (left,{ordinal=ordinal}),A.unitAt (right,{ordinal=ordinal})) of
        (SOME a,SOME b) => a=b andalso A.occurrencesIn (left,a)=A.occurrencesIn (right,b) andalso A.factsIn (left,a)=A.factsIn (right,b)
      | _ => false) (List.tabulate (length (A.inputs left),fn i => i))
  fun keptUnits () =
    let val parent=compiler ()
        val context=A.create (parent,{context="kept"})
        val ()=A.focus (context,SOME ["library.sml"])
        val cold=analyze (context,[library,client,other])
        val ()=routed ("the first check walks",cold,true,0,0,0,0)
        val again=analyze (context,[library,client,other])
        val ()=check ("nothing changed, nothing checked",sameUnits (cold,again) andalso #checked (A.work again)=0 andalso #reused (A.work again)=3)
        (* a body: the same length, so that no span moves *)
        val changed=analyze (context,[around ("fun read x=x","fun read y=y") library,client,other])
        val ()=routed ("a body of an early unit stays at its place",changed,false,0,0,1,0)
        val ()=check ("and equals fresh",sameUnits (changed,freshly (parent,A.inputs changed)))
        val ()=check ("and checks that unit alone",#checked (A.work changed)=1 andalso #reused (A.work changed)=2)
        val comment=[edited (library,"(* moved *)\n" ^ #text library),client,other]
        val moved=analyze (context,comment)
        val ()=routed ("a comment that moves a definition moves no identity",moved,false,0,0,1,0)
        val ()=check ("and equals fresh, bindings and all",sameUnits (moved,freshly (parent,comment)))
        val added=[around ("fun area","val extra=1\nfun area") library,client,other]
        val held=analyze (context,added)
        val ()=routed ("a name added walks, and keeps every client by its usages",held,true,0,2,0,0)
        val ()=check ("and equals fresh",sameUnits (held,freshly (parent,added)))
        val shape=[around ("Round|Square","Round|Square|Oval") library,client,other]
        val broken=analyze (context,shape)
        val ()=routed ("a datatype changed elaborates its client again, and not the rest",broken,true,0,1,0,1)
        val ()=check ("and equals fresh",sameUnits (broken,freshly (parent,shape)))
        val ()=check ("a body that changes length equals fresh",
          let val inputs=[library,around ("val made=L.make 1","val made=L.make (1+1)") client,other]
          in sameUnits (analyze (context,inputs),freshly (parent,inputs)) end)
        val failing=[around ("fun area","val wrong:int=true\nfun area") library,client,other]
        val failed=analyze (context,failing)
        val ()=check ("a unit that fails hides what follows it",not (null (A.diagnostics failed)) andalso
          A.unitAt (failed,{ordinal=1})=A.unitAt (cold,{ordinal=1}) andalso null (A.factsIn (failed,valOf (A.unitAt (failed,{ordinal=1})))))
        val back=analyze (context,[library,client,other])
        val ()=check ("and is put right",sameUnits (back,freshly (parent,[library,client,other])))
        val ()=check ("an old snapshot still answers",List.exists (fn candidate:A.candidate => #name candidate="make")
          (A.visibleAt (cold,{ordinal=1,offset=0,path=["L"]})))
        val ()=check ("the latest one answers at its unit's place",List.exists (fn candidate:A.candidate => #name candidate="make")
          (A.visibleAt (back,{ordinal=1,offset=0,path=["L"]})))
        val ()=check ("a query leaves the snapshot's check as it was",sameUnits (back,analyze (context,[library,client,other])))
        (* a plan that changes: a unit gone, units in another order, a unit new *)
        fun planned inputs=check ("a plan of " ^ Int.toString (length inputs) ^ " inputs equals fresh",
          sameUnits (analyze (context,inputs),freshly (parent,inputs)))
        val ()=planned [library,other]
        val ()=planned [library,client,other]
        val ()=planned [client,other]
        val ()=planned [other,library,client]
        val ()=planned [library,input ("new.sml","val added=area Round\n","1"),client,other]
        val _=analyze (context,[library,client,other])
        val ()=A.compact context
        val compacted=analyze (context,[library,client,other])
        val ()=routed ("a compaction loads every unit again",compacted,true,0,3,0,0)
        val ()=check ("and changes no answer",sameUnits (compacted,back))
    in A.close context;C.close parent end
  (* The path a type is printed by depends on the environment a unit stands in,
     which no usage covers: an open unit past a moved identity is elaborated. *)
  fun printedPaths () =
    let val parent=compiler ()
        val first=input ("zed.sml","structure Zed=struct datatype t=T of int val make=T end\n","1")
        val middle=input ("middle.sml","val nothing=()\n","1")
        val second=input ("made.sml","val made=Zed.make 1\n","1")
        val inputs=[first,middle,second]
        val aliased=[first,edited (middle,#text middle ^ "structure Alpha=Zed\n"),second]
        val context=A.create (parent,{context="printed"})
        val ()=A.focus (context,SOME ["made.sml"])
        val _=analyze (context,inputs)
        val now=analyze (context,aliased)
        val unit=valOf (A.unitAt (now,{ordinal=2}))
        val oracle=freshly (parent,aliased)
        val ()=check ("a type printed by a new path is printed so",A.factsIn (now,unit)=A.factsIn (oracle,unit)
          andalso List.exists (fn fact:A.fact => #ty fact="Alpha.t") (A.factsIn (oracle,unit)))
        val hidden=[input ("hidden.sml","local datatype t=A in val a=A end\nlocal datatype t=B in val b=B end\nval pair=(a,b)\n","1")]
        val shown=List.map #ty (A.facts (freshly (parent,hidden)))
        val ()=check ("two types of one name are told apart by their order, as no stamp would be",
          List.exists (fn ty => ty="t * t/2") shown)
    in A.close context;C.close parent end
  (* a walk cancelled at every point it can be: the context goes on as if it
     had never run, loaded or not *)
  fun cancelledWalks () =
    let val parent=compiler ()
        val inputs=[library,client,other]
        val interface=[around ("fun area","val extra=1\nfun area") library,client,other]
        val shape=[around ("Round|Square","Round|Square|Oval") library,client,other]
        val oracle=freshly (parent,shape)
        fun attempt n=
          let val context=A.create (parent,{context="cancelled"})
              val ()=A.focus (context,SOME [])
              val _=analyze (context,inputs)
              val _=analyze (context,interface)
              val polls=ref 0
              val stopped=(ignore (A.check (context,{project=NONE,inputs=shape,cancelled=fn () => (polls:= !polls+1;!polls=n)}));false)
                handle A.Cancelled => true
              val after=analyze (context,shape)
              val ()=check ("cancelled at poll " ^ Int.toString n ^ ", the next check equals fresh",sameUnits (after,oracle))
              val ()=check ("and so does a check of what it left",sameUnits (analyze (context,inputs),freshly (parent,inputs)))
          in A.close context;stopped end
        fun every n=if attempt n then every (n+1) else n
        val polls=every 1
        val ()=check ("the walk had points to stop at: " ^ Int.toString polls,polls>4)
        (* and a change at its place *)
        val body=[around ("fun read x=x","fun read y=y") library,client,other]
        val context=A.create (parent,{context="cancelled"})
        val _=analyze (context,inputs)
        val stopped=(ignore (A.check (context,{project=NONE,inputs=body,cancelled=fn () => true}));false) handle A.Cancelled => true
        val ()=check ("a change at its place, cancelled, leaves the context as it was",stopped andalso
          sameUnits (analyze (context,inputs),freshly (parent,inputs)))
    in A.close context;C.close parent end
  (* what a closed unit gives up, and gets back *)
  fun closedUnits () =
    let val parent=compiler ()
        val inputs=[library,client,other]
        val oracle=freshly (parent,inputs)
        val context=A.create (parent,{context="closed"})
        val ()=A.focus (context,SOME ["client.sml"])
        val focused=analyze (context,inputs)
        val unit=valOf (A.unitAt (focused,{ordinal=0}))
        val open'=valOf (A.unitAt (focused,{ordinal=1}))
        val ()=check ("an open unit holds its own",A.factsIn (focused,open')=A.factsIn (oracle,open'))
        val ()=check ("the flat lists hold no closed unit's facts",
          not (List.exists (fn fact:A.fact => #file fact="library.sml") (A.facts focused)))
        val ()=check ("a closed unit keeps its types",A.types focused=A.types oracle)
        val ()=check ("a closed unit opens at its place",A.occurrencesIn (focused,unit)=A.occurrencesIn (oracle,unit)
          andalso A.factsIn (focused,unit)=A.factsIn (oracle,unit))
        (* go-to-definition and hover into a closed unit: the open unit's
           occurrence of a name the closed one defines, and the closed
           unit's own, from its notes *)
        fun definitionOf (snapshot,unit,name)=Option.mapPartial #definition (List.find (fn occurrence:A.occurrence =>
          #name occurrence=name andalso not (#isDefinition occurrence)) (A.occurrencesIn (snapshot,unit)))
        val ()=check ("a definition in a closed unit is found from an open one",
          isSome (definitionOf (focused,open',"make")) andalso definitionOf (focused,open',"make")=definitionOf (oracle,open',"make")
          andalso Option.map #file (definitionOf (focused,open',"make"))=SOME "library.sml")
        val ()=check ("and its type is the closed unit's own",
          A.typeAtOccurrence (focused,{ordinal=1,offset=size "val made=L.ma"})=A.typeAtOccurrence (oracle,{ordinal=1,offset=size "val made=L.ma"})
          andalso isSome (A.typeAtOccurrence (focused,{ordinal=1,offset=size "val made=L.ma"})))
        val ()=check ("and gives its syntax and its types",isSome (A.syntaxAt (focused,{ordinal=0})) andalso
          A.typeAtOccurrence (focused,{ordinal=0,offset=0})=A.typeAtOccurrence (oracle,{ordinal=0,offset=0}))
        val ()=A.focus (context,SOME ["library.sml"])
        val moved=analyze (context,inputs)
        val ()=check ("a unit that opens is elaborated alone",#checked (A.work moved)=1)
        val ()=check ("and one that closes is dropped",not (List.exists (fn fact:A.fact => #file fact="client.sml") (A.facts moved)))
        val ()=A.focus (context,NONE)
        val whole=analyze (context,inputs)
        val ()=check ("all open again equals fresh",same (whole,oracle))
        val ()=A.close context
    in check ("an opened unit outlives its context",A.occurrencesIn (focused,open')=A.occurrencesIn (oracle,open'));C.close parent end
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
  fun missingLibrary () =
    let val parent=C.session {lib=SOME "/no/rune-analysis-library",flags=[]}
        val context=A.create(parent,{context="missing-library"})
        val diagnostics=(ignore(analyze(context,[input("missing.sml","val answer=42\n","1")]));[])
          handle C.Failed diagnostics=>diagnostics
        val ()=(A.close context;C.close parent)
    in check("missing library manifests become public compiler diagnostics",
      List.exists(fn diagnostic:C.diagnostic=>String.isSubstring "manifest" (#message diagnostic))diagnostics) end
  fun changedNames () =
    let val parent=C.session {lib=SOME "lib",flags=[]}
        val context=A.create(parent,{context="changed-names"})
        val fresh=A.create(parent,{context="changed-names"})
        val list=input("mentioned.sml","val answer=List.length [1]\n","same-revision")
        val vector=input("mentioned.sml","val answer=Vector.length(Vector.fromList [1,2])\n","same-revision")
        val _=analyze(context,[list])
        val changed=analyze(context,[vector]) val oracle=analyze(fresh,[vector])
        val repeated=analyze(context,[vector])
        val ()=check("changed names select the fresh library plan even at the same revision",
          null(A.diagnostics changed) andalso same(changed,oracle) andalso same(changed,repeated)
          andalso #checked(A.work repeated)=0)
    in A.close context;A.close fresh;C.close parent end
  (* A library root of its own, made for work and taken away after: a Basis of
     one file, and inner, a library with a header that exports Public and
     not Hidden, unless exports says otherwise, and has the friends given.
     settle () makes each file a minute old, a stamp an analysis trusts. *)
  fun scopedRoot (exports,friends,work) =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir handle _ => ();OS.FileSys.mkDir dir)
        val dirs=ref [dir] val made=ref [] : string list ref
        fun clean ()=(List.app (fn path => OS.FileSys.remove path handle _ => ()) (!made);
          List.app (fn path => OS.FileSys.rmDir path handle _ => ()) (!dirs))
        fun write (name,text)=
          let val path=dir ^ "/" ^ name
              val output=TextIO.openOut path
          in TextIO.output (output,text);TextIO.closeOut output;
             if List.exists (fn other => other=path) (!made) then () else made:=path:: !made end
        fun exporting names=write ("inner/MANIFEST","# exports: " ^ names ^ "\n" ^
          String.concat (List.map (fn friend => "# friends: " ^ friend ^ "\n") friends) ^
          "inner.sml | always | yes | Hidden Public | \n")
        fun settle ()=List.app (fn path => OS.FileSys.setTime (path,SOME (Time.- (Time.now (),Time.fromSeconds 60)))) (!made)
        val ()=List.app (fn name => (OS.FileSys.mkDir (dir ^ "/" ^ name);dirs:=(dir ^ "/" ^ name):: !dirs)) ["basis","inner","proj"]
        val ()=write ("basis/basis.sml","structure Base=struct val one=1 end\n")
        val ()=write ("basis/MANIFEST","basis.sml | always | yes | Base | \n")
        val ()=write ("inner/inner.sml","structure Hidden=struct val x=1 end\nstructure Public=struct val y=Hidden.x end\n")
        val ()=exporting exports
        val ()=write ("proj/client.sml","val seen=Hidden.x\n")
        val ()=write ("proj/friend.build","files client.sml end\n")
        val ()=settle ()
    in (work {dir=dir,exporting=exporting,settle=settle} before clean ()) handle error => (clean ();raise error) end
  (* A boundary narrowed under library files that stay as they were: what was
     kept was reached through the old one, so the check walks from the start
     (the engine's sameScopes) and sees what a fresh analysis sees. *)
  fun changedScope () = scopedRoot ("structure:Public structure:Hidden",[],fn {dir,exporting,settle} =>
    let val parent=C.session {lib=SOME dir,flags=["--library","inner"]}
        val context=A.create (parent,{context="changed-scope"})
        val sources=[input ("client.sml","val seen=Hidden.x\n","1")]
        val wide=analyze (context,sources)
        val ()=check ("a library's boundary lets out what it exports",null (A.diagnostics wide))
        val again=analyze (context,sources)
        val ()=check ("a check with nothing changed stays at its places",not (#walked (A.route again)) andalso #checked (A.work again)=0)
        val ()=(exporting "structure:Public";settle ())
        val narrow=analyze (context,sources)
        val fresh=freshly (parent,sources)
    in check ("a boundary narrowed under the same files walks from the start, and sees what a fresh analysis sees",
         #walked (A.route narrow) andalso not (null (A.diagnostics fresh)) andalso A.diagnostics narrow=A.diagnostics fresh);
       A.close context;C.close parent end)
  (* A friend of a library sees past its boundary (docs/build.md, A library's
     header). The plan a check keeps is the plan of the build it was for (the
     engine's sameBuilding): the same steps checked for another build select
     as a fresh check for that build would. *)
  fun friendBuilding () = scopedRoot ("structure:Public",["../proj/friend.build"],fn {dir,...} =>
    let val parent=C.session {lib=SOME dir,flags=["--library","inner"]}
        val project=C.Project.read (parent,{file=dir ^ "/proj/friend.build",workspace=NONE,variables=[],overlays=[],windows=false})
        val inputs=List.map (fn source:C.Project.source => {file= #file source,text="val seen=Hidden.x\n",mode= #mode source,
          annotations= #annotations source,revision="1"}:A.input) (C.Project.sources project)
        fun checkIn (context,project)=A.check (context,{project=project,inputs=inputs,cancelled=fn () => false})
        fun fresh project=let val context=A.create (parent,{context="fresh"})
          in checkIn (context,project) before A.close context end
        val context=A.create (parent,{context="friend"})
        val outside=checkIn (context,NONE)
        val ()=check ("a client that is no friend does not see past the boundary",not (null (A.diagnostics outside)))
        val friend=checkIn (context,SOME project)
        val ()=check ("the friend's build, checked after, selects as a fresh check of it and sees past it",
          null (A.diagnostics friend) andalso sameUnits (friend,fresh (SOME project)))
        val back=checkIn (context,NONE)
    in check ("and the same steps checked for no build again see only what is exported",
         not (null (A.diagnostics back)) andalso A.diagnostics back=A.diagnostics (fresh NONE));
       A.close context;C.close parent end)
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
        val ()=OS.FileSys.mkDir (dir ^ "/scoped")
        val ()=write ("scoped/library.build","exports (structure Public)\nfiles ../hidden.sml ../public.sml end\n")
        val ()=write ("scope.build","use scoped/library.build\nfiles final.sml end\n")
        fun clean ()=(List.app (fn file => OS.FileSys.remove (dir ^ "/" ^ file))
          ("scope.build" :: "scoped/library.build" :: List.map #1 files);OS.FileSys.rmDir (dir ^ "/scoped");OS.FileSys.rmDir dir)
        fun work () =
          let val parent=compiler ()
              val context=A.create (parent,{context="scoped"})
              val project=C.Project.read (parent,{file=dir ^ "/scope.build",workspace=NONE,variables=[],overlays=[],windows=false})
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
              (* a unit's name is rune's: no rank of its place, no spelling *)
              val ()=check ("a unit is named as rune names it",A.unitAt (valid,{ordinal=2})=SOME "final.sml")
              val twice=A.create (parent,{context="twice"})
              fun loose file=input (file,"val x=1\n","1")
              val snapshot=A.check (twice,{project=NONE,inputs=[loose (dir ^ "/hidden.sml"),loose (dir ^ "/./hidden.sml")],
                cancelled=fn () => false})
              val ()=check ("a file given twice has a rank, however it is spelt",
                A.unitAt (snapshot,{ordinal=0})=SOME "hidden.sml" andalso A.unitAt (snapshot,{ordinal=1})=SOME "hidden.sml#2")
              val ()=A.close twice
              (* Windows syntax, whatever the host: from the root, with ../
                 beside it, and whole on another drive, which nothing reaches *)
              val drives=C.Project.read (parent,{file="C:/project/root.build",workspace=NONE,variables=[("DEP","D:/dep")],
                overlays=[{file="C:/project/root.build",text="files sub/b.sml $(DEP)/a.sml ../up.sml end\n"}],windows=true})
              val windows=A.create (parent,{context="windows"})
              val snapshot=A.check (windows,{project=SOME drives,cancelled=fn () => false,
                inputs=List.map (fn source:C.Project.source => input (#file source,"val x=1\n","1")) (C.Project.sources drives)})
              val ()=check ("a unit's name on Windows",List.map (fn ordinal => A.unitAt (snapshot,{ordinal=ordinal})) [0,1,2]=
                [SOME "sub/b.sml",SOME "D:/dep/a.sml",SOME "../up.sml"])
              val ()=A.close windows
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
  (* the editor's types (the linting roadmap's M14): a type at every node,
     the application where an infix application and its tuple share a
     span, a binder's own generalised variables marked, one printer for the
     unit, and the batch query agreeing *)
  fun nodeTypes () =
    let val parent=compiler ()
        val context=A.create (parent,{context="node-types"})
        val text="fun id x=x\nfun pair x=(x,x)\nval p=pair 1\nval q=let val r=p in #1 r end\n"
          ^ "datatype t=C of int*int\nfun f (C (a,b))=a+b\nval s=1 + 2\nval g=fn y=>id y\n"
        val snapshot=analyze (context,[input ("nodes.sml",text,"1")])
        (* the offset of the k-th occurrence of a piece of the text, and some *)
        fun at (piece,k)=
          let fun go (from,k)=let val (prefix,rest)=Substring.position piece (Substring.extract (text,from,NONE))
                                  val here=from+Substring.size prefix
                              in if Substring.isEmpty rest then raise Fail ("no " ^ piece) else if k=1 then here else go (here+1,k-1) end
          in go (0,k) end
        fun hover offset=A.typeAtOccurrence (snapshot,{ordinal=0,offset=offset})
        val ()=check ("node types: no diagnostic",null (A.diagnostics snapshot))
        val ()=check ("a binder shows its own generalised variables marked",hover (at ("id",1))=SOME "'a. 'a -> 'a")
        val ()=check ("a lambda's variable is not marked",hover (at ("x=x",1))=SOME "'a")
        val ()=check ("one printer for the unit: the next variable named after the first",
          hover (at ("x,x",1))=SOME "'b" andalso hover (at ("pair",1))=SOME "'b. 'b -> 'b * 'b")
        val ()=check ("a tuple's type",hover (at ("(x,x)",1))=SOME "'b * 'b")
        val ()=check ("a let's type at its keyword",hover (at ("let",1))=SOME "int")
        val ()=check ("a constructor pattern's type",hover (at ("C (a",1))=SOME "t")
        val ()=check ("the application, not its tuple, where they share a span",hover (at (" + 2",1))=SOME "int")
        val ()=check ("an operator's own type",hover (at ("+ 2",1))=SOME "int * int -> int")
        val _=C.compileText (parent,{file="nodes.sml",text=text})
        (* where no type variable is shown: a query of its own names its first 'a *)
        val ()=check ("the batch query agrees",List.all (fn (piece,k) =>
          C.typeAt (parent,{file="nodes.sml",offset=at (piece,k)})=hover (at (piece,k)))
          [("let",1),("C (a",1),(" + 2",1),("+ 2",1),("p=",1)]
          andalso C.typeAt (parent,{file="nodes.sml",offset=at ("(x,x)",1)})=SOME "'a * 'a")
    in A.close context;C.close parent end
  (* A functor's result where no code is made: its fresh names are what a
     compile makes them, with their constructors and layouts, so an analysis
     refuses what a compile refuses of a datatype an application made, and
     its static layer is a compile's (build-system M4, step 4) *)
  fun generatedLayouts () =
    let val parent=compiler ()
        val context=A.create (parent,{context="generated"})
        val text=String.concatWith "\n"
          ["functor G () = struct type e = int * int * int * int * int * int * int * int * int  datatype t = C of e | N end",
           "structure B = G ()",
           "signature P = sig type e  datatype t = C of e | N end",
           "functor F (X : P) = struct fun f (X.C v) = 1 | f _ = 0 end",
           "structure R = F (B)",""]
        val says=String.isSubstring "lays out a constructor of t in 9 fields"
        val result=analyze (context,[input ("generated.sml",text,"1")])
        val ()=check ("the analysis refuses it as a compile does",
          List.exists (fn diagnostic:C.diagnostic => says (#message diagnostic)) (A.diagnostics result))
        val compiled=(ignore (C.compileText (parent,{file="generated.sml",text=text}));[])
          handle C.Failed diagnostics => diagnostics
        val ()=check ("a compile refuses it",List.exists (fn diagnostic:C.diagnostic => says (#message diagnostic)) compiled)
    in A.close context;C.close parent end
  (* The same refusal where the argument is the datatype of the parameter of
     the body the application is in: its layout is in the code's tables only
     where code is made, and the analysis reads it from its constructors
     (Elaborate.layoutAt) *)
  fun layoutsInABody () =
    let val parent=compiler ()
        val context=A.create (parent,{context="body-layouts"})
        val text=String.concatWith "\n"
          ["signature P = sig type e  datatype t = C of e | N end",
           "functor F (X : P) = struct fun f (X.C v) = 1 | f _ = 0 end",
           "signature Q = sig type e = int * int * int * int * int * int * int * int * int  datatype t = C of e | N end",
           "functor G (Y : Q) = struct structure R = F (Y) end",""]
        val says=String.isSubstring "lays out a constructor of t in 9 fields"
        val result=analyze (context,[input ("body.sml",text,"1")])
        val ()=check ("the analysis refuses it in a body as a compile does",
          List.exists (fn diagnostic:C.diagnostic => says (#message diagnostic)) (A.diagnostics result))
        val compiled=(ignore (C.compileText (parent,{file="body.sml",text=text}));[])
          handle C.Failed diagnostics => diagnostics
        val ()=check ("a compile refuses it in a body",List.exists (fn diagnostic:C.diagnostic => says (#message diagnostic)) compiled)
    in A.close context;C.close parent end
  (* A comment that moves every span moves no identity: where a name was bound
     is in a sidecar, outside what an identity hashes (build-system M4, step
     1), and a unit read back still says where. *)
  fun spansMoveNoIdentity () =
    let val parent=compiler ()
        val body="datatype t=C of int\nsignature S=sig type u val v:u end\n"
          ^ "functor F (X:S)=struct type w=X.u val y=X.v end\n"
          ^ "structure M=struct datatype d=D val z=D end\n"
        val comment="(* a comment of some length *)\n\n"
        fun check' text=
          let val context=A.create (parent,{context="spans"})
              val result=analyze (context,[input ("spans.sml",text,"1"),
                input ("client.sml","structure N=F (struct type u=t val v=C 1 end)\nval q=N.y\nval r=M.z\n","1")])
          in A.close context;result end
        val first=check' body
        val second=check' (comment ^ body)
        val moved=size comment
        fun ids result=List.map (fn definition:A.typeDefinition => #id definition) (A.types result)
        fun spots result=List.mapPartial (fn definition:A.typeDefinition =>
          Option.map (fn location:A.location => #start location) (#implementation definition)) (A.types result)
        val ()=check ("the analysis reads the program",null (A.diagnostics first) andalso null (A.diagnostics second))
        val ()=check ("a type's identity holds its unit's: a comment does not move it",
          not (null (ids first)) andalso ids first=ids second)
        val ()=check ("and the sidecar still says where it is",length (spots first)=length (ids first)
          andalso List.map (fn start => start+moved) (spots first)=spots second)
        (* a client's use of a name of the first unit, its origin read from the sidecar *)
        fun uses result=List.filter (fn occurrence:A.occurrence => #file occurrence="client.sml") (A.occurrences result)
        fun targets result=List.mapPartial (fn occurrence:A.occurrence =>
          case #definition occurrence of
            SOME (location:A.location) => if #file location="spans.sml" then SOME (#start location) else NONE
          | NONE => NONE) (uses result)
        val ()=check ("a client finds the moved definitions",not (null (targets first))
          andalso List.map (fn start => start+moved) (targets first)=targets second)
    in C.close parent end
  (* Past the first error (docs/language-server.md, Contexts): a unit reports
     each declaration that fails, as a compile does, and what it holds past
     them answers a question; the units after it are not reached; and a kept
     analysis says what a fresh one does. *)
  fun pastFirstError () =
    let val parent=compiler ()
        val context=A.create (parent,{context="past-first-error"})
        val text="val a:int=true\nval b=1\nval c:string=2\nval d=b+1\n"
        val first=input ("one.sml",text,"1")
        val second=input ("two.sml","val e=d\n","1")
        val result=analyze (context,[first,second])
        val errors=A.diagnostics result
        val ()=check ("each independent error of a unit is reported",
          List.map (fn diagnostic:C.diagnostic => (#file diagnostic,#line diagnostic)) errors=[("one.sml",1),("one.sml",3)])
        val one=valOf (A.unitAt (result,{ordinal=0}))
        val two=valOf (A.unitAt (result,{ordinal=1}))
        fun at (snapshot,needle)=
          let val (front,_)=Substring.position needle (Substring.full text) in Substring.size front end
        val ()=check ("a declaration after an error is checked, and answers",
          A.typeAtOccurrence (result,{ordinal=0,offset=at (result,"b+1")})=SOME "int"
          andalso List.exists (fn occurrence:A.occurrence => #name occurrence="d" andalso #isDefinition occurrence)
            (A.occurrencesIn (result,one)))
        val ()=check ("the unit after the one that failed is not reached",null (A.occurrencesIn (result,two))
          andalso null (A.factsIn (result,two)))
        val ()=check ("a question past the error sees what is declared there",
          List.exists (fn candidate:A.candidate => #name candidate="d")
            (A.visibleAt (result,{ordinal=0,offset=size text,path=[]})))
        val fixed=input ("one.sml","val a:int=1\nval b=1\nval c:string=2\nval d=b+1\n","2")
        val edited=analyze (context,[fixed,second])
        val oracle=freshly (parent,[fixed,second])
        val ()=check ("a kept analysis past an error says what a fresh one does",same (edited,oracle)
          andalso List.map #line (A.diagnostics edited)=[3])
        val clean=analyze (context,[input ("one.sml","val d=1\n","3"),second])
        val ()=check ("and once it checks, the units after it are reached",null (A.diagnostics clean)
          andalso not (null (A.occurrencesIn (clean,two))) andalso same (clean,freshly (parent,A.inputs clean)))
        val broken=analyze (context,[input ("one.sml","val = 1\nval x=2\nval = 3\n","4"),second])
        val ()=check ("each syntax error of a unit is reported",length (A.diagnostics broken)>=2
          andalso List.all (fn diagnostic:C.diagnostic => #file diagnostic="one.sml") (A.diagnostics broken))
    in A.close context;C.close parent end
  (* A flexible record no later file of the unit settles (tests/units/flex):
     the unit's error, as a compile reports it, and the check goes on; a
     question about the unit is answered from what was elaborated *)
  fun flexibleRecord () =
    let val parent=compiler ()
        val context=A.create (parent,{context="flexible-record"})
        val first=input ("a.sml","fun getX r = #x r\n","1")
        val second=input ("b.sml","val n = getX {x = 1, y = 2}\n","1")
        val result=analyze (context,[first,second])
        val ()=check ("an unresolved flexible record is the unit's error",
          List.map (fn diagnostic:C.diagnostic => (#file diagnostic,#line diagnostic,#message diagnostic)) (A.diagnostics result)=
            [("a.sml",1,"unresolved flexible record: cannot determine the full set of fields")])
        val ()=check ("and says what a fresh analysis does",same (result,freshly (parent,[first,second])))
        val ()=check ("the unit's own occurrences answer",List.exists (fn occurrence:A.occurrence =>
          #name occurrence="getX" andalso #isDefinition occurrence) (A.occurrencesIn (result,valOf (A.unitAt (result,{ordinal=0})))))
        val settled=analyze (context,[input ("a.sml","fun getX (r : {x : int, y : int}) = #x r\n","2"),second])
        val ()=check ("once settled the units after it are reached",null (A.diagnostics settled)
          andalso same (settled,freshly (parent,A.inputs settled)))
    in A.close context;C.close parent end
  (* Two builds over one library (D26): a context that shares takes the
     library's units from what another checked, and says what a fresh one
     does; one that does not share elaborates them. *)
  fun sharedLibrary () = scopedRoot ("structure:Public",[],fn {dir,...} =>
    let val parent=C.session {lib=SOME dir,flags=["--library","inner"]}
        val pool=A.pool ()
        fun context (name,file,shares)=
          let val made=A.create (parent,{context=name})
          in A.share (made,if shares then SOME pool else NONE);A.focus (made,SOME [file]);made end
        val first=context ("first","one.sml",true)
        val second=context ("second","two.sml",true)
        val alone=context ("alone","two.sml",false)
        val one=analyze (first,[input ("one.sml","val one=Public.y\n","1")])
        val sources=[input ("two.sml","val two=Public.y+1\n","1")]
        val two=analyze (second,sources)
        val fresh=analyze (alone,sources)
        val ()=check ("the first build checks the library",null (A.diagnostics one) andalso #checked (A.work one)=3)
        val ()=check ("a second build over it takes the library's units, and checks its own",
          #checked (A.work two)=1 andalso #loaded (A.route two)=2 andalso #checked (A.work fresh)=3)
        val ()=check ("and says what a fresh one does",same (two,fresh))
        val edited=[input ("two.sml","val two=Public.y+2\n","2")]
    in check ("and goes on as a kept one does",same (analyze (second,edited),analyze (alone,edited)));
       A.close first;A.close second;A.close alone;C.close parent end)
  (* A build's view of the Basis Library (D12), which an analysis selects as a
     compile does: a Basis of one structure, whose view narrow hides a member. *)
  fun basisView () = scopedRoot ("structure:Public",[],fn {dir,settle,...} =>
    let fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name) in TextIO.output (output,text);TextIO.closeOut output end
        val ()=write ("basis/basis.sml","structure Base=struct val one=1 val two=2 end\n")
        val ()=write ("basis/narrow.sml","structure Base:sig val one:int end=Base\n")
        val ()=write ("basis/MANIFEST","basis.sml | always | yes | Base | \nnarrow.sml | seal@narrow | yes | Base | \n")
        val ()=write ("proj/viewed.build","view narrow\nfiles client.sml end\n")
        val ()=write ("proj/whole.build","files client.sml end\n")
        val ()=settle ()
        val parent=C.session {lib=SOME dir,flags=[]}
        fun checked build=
          let val project=C.Project.read (parent,{file=dir ^ "/proj/" ^ build,workspace=NONE,variables=[],overlays=[],windows=false})
              val inputs=List.map (fn source:C.Project.source => {file= #file source,text="val seen=Base.two\n",mode= #mode source,
                annotations= #annotations source,revision="1"}:A.input) (C.Project.sources project)
              val context=A.create (parent,{context=build})
          in A.check (context,{project=SOME project,inputs=inputs,cancelled=fn () => false}) before A.close context end
        val whole=checked "whole.build"
        val viewed=checked "viewed.build"
        val ()=check ("without a view the whole Basis Library is seen",null (A.diagnostics whole))
        val ()=check ("a build's view hides what it hides, as in a compile",
          List.exists (fn diagnostic:C.diagnostic => String.isSubstring "two" (#message diagnostic)) (A.diagnostics viewed))
    in C.close parent end)
end
structure CompilerAnalysisTestMain=Main (struct
  val name="compiler-analysis"
  val tests=Test.describe "compiler-analysis"
    [Test.it "observations" CompilerAnalysisTests.observations,
     Test.it "snapshots-checkpoints-cancellation" CompilerAnalysisTests.snapshots,
     Test.it "kept-units" CompilerAnalysisTests.keptUnits,
     Test.it "printed-paths" CompilerAnalysisTests.printedPaths,
     Test.it "cancelled-walks" CompilerAnalysisTests.cancelledWalks,
     Test.it "closed-units" CompilerAnalysisTests.closedUnits,
     Test.it "captured-syntax-snapshots" CompilerAnalysisTests.syntaxSnapshots,
     Test.it "inferred-pattern-type-hints" CompilerAnalysisTests.typeHints,
     Test.it "lexical-bindings" CompilerAnalysisTests.bindings,
     Test.it "generative-identities" CompilerAnalysisTests.generative,
     Test.it "static-library-replay" CompilerAnalysisTests.libraries,
     Test.it "missing-library-diagnostic" CompilerAnalysisTests.missingLibrary,
     Test.it "changed-prelude-names" CompilerAnalysisTests.changedNames,
     Test.it "changed-library-scope" CompilerAnalysisTests.changedScope,
     Test.it "friend-building" CompilerAnalysisTests.friendBuilding,
     Test.it "frozen-library-query" CompilerAnalysisTests.frozenLibrary,
     Test.it "project-scopes" CompilerAnalysisTests.projects,
     Test.it "batch-compiler-oracle" CompilerAnalysisTests.batchOracle,
     Test.it "repeated-source-contexts" CompilerAnalysisTests.repeatedSources,
     Test.it "lexical-visibility" CompilerAnalysisTests.lexicalVisibility,
     Test.it "call-signatures" CompilerAnalysisTests.signatures,
     Test.it "node-types" CompilerAnalysisTests.nodeTypes,
     Test.it "spans-move-no-identity" CompilerAnalysisTests.spansMoveNoIdentity,
     Test.it "generated-layouts" CompilerAnalysisTests.generatedLayouts,
     Test.it "layouts-in-a-body" CompilerAnalysisTests.layoutsInABody,
     Test.it "past-the-first-error" CompilerAnalysisTests.pastFirstError,
     Test.it "flexible-record" CompilerAnalysisTests.flexibleRecord,
     Test.it "basis-view" CompilerAnalysisTests.basisView,
     Test.it "two-builds-share-a-library" CompilerAnalysisTests.sharedLibrary]
end)
val ()=CompilerAnalysisTestMain.main ()
