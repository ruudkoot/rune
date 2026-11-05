(* Immutable analysis publication around static unit replay. Context ownership
   and cancellation are checked before cache/checkpoint publication. *)
structure CompilerAnalysis =
struct
  structure E=CompilerAnalysisEngine
  structure C=CompilerSession
  type input={file:string,text:string,mode:string,annotations:string list,revision:string}
  type location={file:string,start:int,stop:int}
  type occurrence={unit:string,file:string,start:int,stop:int,kind:string,name:string,path:string list,
    binding:string option,definition:location option,declaration:location option,isDefinition:bool,derived:bool}
  type typeDefinition={id:string,definition:location option,declaration:location option,implementation:location option}
  type fact=E.fact
  type candidate={name:string,kind:string,detail:string option,arguments:string list list,definition:location option}
  type call={name:string,path:string list,detail:string,arguments:string list list,argument:int,parameter:int}
  type typeHint={name:string,position:int,ty:string,binding:string,location:location}
  (* engine, state: what the check left, which a query of the latest snapshot
     stands on. entries: what it reached, by name, and order their names. opened:
     closed units opened for a question, the latest first. projections: a
     unit's occurrences once asked for. flat: every unit's, in the units' order,
     once asked for. files: by each file a unit of it. *)
  type snapshot={id:string,context:string,project:string option,inputs:input list,ordered:input vector,dependencies:input list,
    diagnostics:C.diagnostic list,reused:int,checked:int,route:E.route,config:C.config,engine:E.session,state:E.state,
    entries:E.kept StringMap.map,order:string list,attempted:(string*CompilerSyntax.t) option,
    steps:CompilerProject.step list,libraries:string list,prelude:CompilerPrelude.plan,
    scope:Workspace.scope,units:string vector,opened:E.entry list ref,projections:occurrence list StringMap.map ref,
    flat:{occurrences:occurrence list,facts:fact list,types:typeDefinition list} option ref,
    files:E.entry StringMap.map option ref}
  datatype t=Analysis of {parent:C.session,context:string,namespace:string,engine:E.session,
    token:unit ref,serial:IntInf.int ref,busy:bool ref,closed:bool ref,dependencies:input list ref}
  datatype checkpoint=Checkpoint of {token:unit ref,state:E.state}
  exception Cancelled=E.Cancelled
  exception Busy
  type observation=E.observation
  fun new (parent as C.Session {config,...},context) =
    (C.checked parent;Analysis {parent=parent,context=context,namespace="analysis-" ^ Int.toString (CompilerState.freshIdentity ()),
      engine=E.new config,token=ref (),serial=ref 0,busy=ref false,closed=ref false,dependencies=ref []})
  fun checked (Analysis {parent,busy,closed,...}) =
    (C.checked parent;if !closed then raise C.Closed else if !busy then raise Busy else ())
  fun close (Analysis {engine,busy,closed,...}) =
    if !busy then raise Busy else (closed:=true;E.close engine)
  fun observe (context as Analysis {engine=E.Session{observer,...},...},value)=
    (checked context;observer:=value)
  (* which files keep what a question about them needs; NONE, every file *)
  fun focus (context as Analysis {engine,...},files)=(checked context;E.focus (engine,files))
  (* whether a library's units are taken from what other contexts checked *)
  type pool=E.pool
  val pool=E.pool
  fun share (context as Analysis {engine=E.Session {shares,...},...},value)=(checked context;shares:=value)
  (* the store a context takes a compile's entries and the sidecars from,
     and writes sidecars to; NONE, none *)
  fun store (context as Analysis {engine=E.Session {store,...},...},value)=(checked context;store:=value)
  (* whether units are loaded by need (docs/compiler-analysis.md); on at first *)
  fun lazy (context as Analysis {engine,...},on)=(checked context;E.setLazy (engine,on))
  fun compact (context as Analysis {engine,...})=(checked context;E.compact engine)
  fun checkpoint (context as Analysis {engine=E.Session {state,...},token,...}) =
    (checked context;Checkpoint {token=token,state= !state})
  fun restore (context as Analysis {engine,token,...},Checkpoint saved) =
    (checked context;if token<> #token saved then raise Fail "checkpoint belongs to another analysis context"
     else E.restore (engine,#state saved))
  fun location origin = case origin of Env.Named {span,...} => SOME
        {file= #file span,start= #start span,stop= #stop span}:location option
    | _ => NONE
  fun binding origin = case origin of Env.Named {unit,kind,name,span} =>
      let val writer=Pickle.writer ()
          val ()=List.app (fn value => Pickle.string (writer,value)) [unit,kind,name,#file span]
          val ()=(Pickle.nat (writer,#start span);Pickle.nat (writer,#stop span))
      in SOME ("binding-" ^ Pickle.hash (Pickle.contents writer)) end
    | _ => NONE
  fun freeze (found,unit,(role,(path,name),span:Source.span,origin,derived)) : occurrence =
    let val origin=E.resolve found origin
        val definition=Env.primary origin
        val declaration=Env.declaration origin
        val isDefinition=String.isPrefix "def-" role
        val kind=if isDefinition then String.extract (role,4,NONE) else role
        val kind=case kind of "v" => "value" | "t" => "type" | "s" => "structure"
          | "g" => "signature" | "f" => "functor" | _ => kind
    in {unit=unit,file= #file span,start= #start span,stop= #stop span,kind=kind,name=name,path=path,
      binding=binding definition,definition=location definition,declaration=location declaration,
      isDefinition=isDefinition,derived=derived} end
  fun check (context as Analysis {parent,context=name,namespace,engine,serial,busy,dependencies=lastDependencies,...},
             {inputs:input list,steps,project,libraries,scope,building,view,cancelled}) : snapshot =
    let val ()=checked context
        val C.Session {config,...}=parent
        fun source (input:input):E.source =
          {file= #file input,text= #text input,mode=case Source.modeNamed (#mode input) of
            SOME mode => mode | NONE => raise Fail "unknown analysis source mode"}
        val sources=List.map source inputs
        fun poll ()=let val result=cancelled () in C.checked parent;result end
        val ()=busy:=true
        fun work () =
          let val result=E.checkSteps (engine,scope,sources,steps,libraries,poll,building,view)
              val E.Session{observer,...}=engine
              fun phase name items=Option.app(fn f=>f {phase=name,file="",checked= #checked result,reused= #reused result,items=items})(!observer)
              fun dependency (source:E.source):input={file= #file source,text= #text source,
                mode=Source.modeName (#mode source),annotations=[],revision=Pickle.hash (#text source)}
              val dependencies=if ListPair.allEq (fn (source:E.source,prior:input) => #file source= #file prior andalso
                  #text source= #text prior) (#dependencies result,!lastDependencies) then !lastDependencies
                else List.map dependency (#dependencies result)
              val ()=lastDependencies:=dependencies
              val snapshot={id=namespace ^ ":" ^ IntInf.toString (!serial),context=name,project=project,inputs=inputs,
                ordered=Vector.fromList inputs,dependencies=dependencies,
                diagnostics= #diagnostics result,reused= #reused result,checked= #checked result,route= #route result,config=config,
                engine=engine,state= #state result,entries= #entries result,order= #order result,attempted= #attempted result,
                steps=steps,libraries=libraries,prelude= #prelude result,scope=scope,units=Vector.fromList (#units result),
                opened=ref [],projections=ref StringMap.empty,flat=ref NONE,files=ref NONE}:snapshot
              val ()=phase "snapshot-published" (length (#order result))
          in serial:=IntInf.+ (!serial,1);snapshot end
        val result=work () handle error => (busy:=false;raise error)
    in busy:=false;result end
  (* a unit of what a snapshot holds, by name: what its references go to *)
  fun finder (snapshot:snapshot) name=StringMap.find (#kept (#state snapshot),name)
  fun projection (snapshot,entry:E.entry)=
    List.rev (List.foldl (fn (use,all) => freeze (finder snapshot,#name entry,use)::all) [] (#uses entry))
  fun typeDefinition (snapshot,{id,origin}:E.typeDefinition):typeDefinition=
    let val origin=E.resolve (finder snapshot) origin
    in {id=id,definition=location (Env.declaration origin),declaration=location (Env.declaration origin),
        implementation=location (Env.primary origin)} end
  fun source (input:input):E.source={file= #file input,text= #text input,mode=valOf (Source.modeNamed (#mode input))}
  (* The engine a question of a snapshot goes to: the context's, where this is
     its latest; else one of its own, over what the snapshot holds, which
     loads the units again and is closed after. *)
  fun answering (snapshot:snapshot,action) =
    let val live=case #engine snapshot of E.Session {state,closed,...} =>
          not (!closed) andalso #serial (!state)= #serial (#state snapshot)
    in if live then action (#engine snapshot) else
         let val engine=E.over (#state snapshot,#config snapshot)
             val result=action engine handle error => (E.close engine;raise error)
         in E.close engine;result end end
  fun ordinalOf (snapshot:snapshot,unit)=
    let fun find i=if i=Vector.length (#units snapshot) then NONE
          else if Vector.sub (#units snapshot,i)=unit then SOME i else find (i+1)
    in find 0 end
  (* A closed unit opened: from its notes, where they hold (D27), else at its
     place; whole, with its syntax and typing, at its place. The few asked for
     last are kept. *)
  fun openUnit (snapshot:snapshot,unit,whole) =
    case List.find (fn entry:E.entry => #name entry=unit andalso (not whole orelse E.isOpen entry)) (!(#opened snapshot)) of
      SOME entry => SOME entry | NONE =>
    (* from its notes, with no check, where the snapshot is its context's latest *)
    case (if whole then NONE else case #engine snapshot of engine as E.Session {state,closed,...} =>
            if not (!closed) andalso #serial (!state)= #serial (#state snapshot) then E.opened (engine,unit) else NONE) of
      SOME entry => (#opened snapshot:=List.take (entry:: !(#opened snapshot),Int.min (16,1+length (!(#opened snapshot))));SOME entry)
    | NONE =>
    case ordinalOf (snapshot,unit) of NONE => NONE | SOME ordinal =>
      let val input=Vector.sub (#ordered snapshot,ordinal)
          val result=answering (snapshot,fn engine => E.checkWith (engine,#scope snapshot,List.map source (#inputs snapshot),
            #steps snapshot,#libraries snapshot,fn () => false,SOME {unit=unit,file= #file input,offset= ~1,path=[]},
            List.map source (#dependencies snapshot),SOME (#prelude snapshot),NONE,NONE,if whole then E.Whole else E.Open))
      in case #opened result of NONE => NONE | SOME entry =>
          let val all=entry:: !(#opened snapshot)
          in #opened snapshot:=List.take (all,Int.min (16,length all));SOME entry end end
  fun entryOf (snapshot:snapshot,unit)=case StringMap.find (#entries snapshot,unit) of NONE => NONE
    | SOME (k:E.kept) => if E.isOpen (#entry k) then SOME (#entry k) else openUnit (snapshot,unit,false)
  (* the same with its syntax and typing *)
  fun wholeOf (snapshot:snapshot,unit)=case StringMap.find (#entries snapshot,unit) of NONE => NONE
    | SOME (k:E.kept) => if E.isOpen (#entry k) then SOME (#entry k) else openUnit (snapshot,unit,true)
  (* what a unit holds, by its name, without a walk of the others *)
  fun occurrencesIn (snapshot:snapshot,unit)=case StringMap.find (!(#projections snapshot),unit) of SOME uses => uses
    | NONE => case entryOf (snapshot,unit) of NONE => [] | SOME entry =>
        let val uses=projection (snapshot,entry)
            val kept=case StringMap.find (#entries snapshot,unit) of SOME (k:E.kept) => E.isOpen (#entry k) | NONE => false
        in if kept then #projections snapshot:=StringMap.insert (!(#projections snapshot),unit,uses) else ();uses end
  fun factsIn (snapshot:snapshot,unit)=case entryOf (snapshot,unit) of NONE => [] | SOME entry => #facts entry
  (* what says that a unit gives the same answers: its text, and what it declares *)
  fun versionOf (snapshot:snapshot,unit)=Option.map (fn k:E.kept => #key (#entry k) ^ ":" ^ E.identityOf k)
    (StringMap.find (#entries snapshot,unit))
  fun entries (snapshot:snapshot)=List.map (fn name => #entry (valOf (StringMap.find (#entries snapshot,name)) : E.kept)) (#order snapshot)
  fun flat (snapshot:snapshot)=case !(#flat snapshot) of SOME all => all | NONE =>
    let val kept=entries snapshot
        val all={occurrences=List.concat (List.map (fn entry:E.entry => case StringMap.find (!(#projections snapshot),#name entry) of
                SOME uses => uses
              | NONE => if E.isOpen entry then occurrencesIn (snapshot,#name entry) else projection (snapshot,entry)) kept),
          facts=List.concat (List.map #facts kept),
          types=List.map (fn definition => typeDefinition (snapshot,definition)) (List.concat (List.map #types kept))}
    in #flat snapshot:=SOME all;all end
  (* the occurrences of every unit whose declaration is one, and whose
     definition is another: which a closed unit keeps *)
  fun implementationsOf (snapshot:snapshot,declared:location) =
    let val found=finder snapshot
        fun within (entry:E.entry)=List.mapPartial (fn use as (_,_,_,origin,_) =>
          let val origin=E.resolve found origin
          in if location (Env.declaration origin)=SOME declared andalso location (Env.primary origin)<>SOME declared
             then SOME (freeze (found,#name entry,use)) else NONE end) (#uses entry)
    in List.concat (List.map within (entries snapshot)) end
  fun occurrences snapshot= #occurrences (flat snapshot)
  fun facts snapshot= #facts (flat snapshot)
  fun types snapshot= #types (flat snapshot)
  (* the type at a position from its unit's node types (CompilerNodeTypes),
     worked out in a compiler state of its own; NONE where the unit has
     none (a library's, a cached analysis's before them) or no node is
     there *)
  fun typedAt (snapshot:snapshot,{file,unit,offset}) =
    let fun mine (entry:E.entry)=isSome (#typing entry) andalso #file entry=file
        val found=case unit of SOME unit => wholeOf (snapshot,unit) | NONE => List.find mine (entries snapshot)
    in case found of
         SOME entry => (case #typing entry of
                          SOME typing => C.owned (fn () => CompilerNodeTypes.typeAt (typing,file,offset))
                        | NONE => NONE)
       | NONE => NONE end
  fun typeIn (snapshot:snapshot,position as {file,unit,offset}) =
    case typedAt (snapshot,position) of SOME ty => SOME ty | NONE =>
    let fun candidate (fact:fact)= #file fact=file andalso (case unit of NONE => true | SOME unit => #unit fact=unit)
          andalso #start fact<=offset andalso offset< #stop fact
        fun best (fact:fact,NONE)=SOME fact
          | best (fact:fact,old as SOME previous)=
              if (#derived previous andalso not (#derived fact)) orelse
                 #derived previous= #derived fact andalso #stop fact- #start fact< #stop previous- #start previous
              then SOME fact else old
        val all=case unit of SOME unit => factsIn (snapshot,unit) | NONE => facts snapshot
    in Option.map #ty (List.foldl best NONE (List.filter candidate all)) end
  fun typeAt (snapshot:snapshot,{file,offset}) =
    if length (List.filter (fn input:input => #file input=file) (#inputs snapshot))>1 then NONE
    else typeIn (snapshot,{file=file,unit=NONE,offset=offset})
  fun unitAt (snapshot:snapshot,{ordinal}) =
    if ordinal<0 orelse ordinal>=Vector.length (#units snapshot) then NONE else
      SOME (Vector.sub (#units snapshot,ordinal))
  fun syntaxAt (snapshot:snapshot,position) = Option.mapPartial (fn unit =>
    case #attempted snapshot of
      SOME (name,syntax) => if name=unit andalso not (StringMap.member (#entries snapshot,unit)) then SOME syntax
        else Option.mapPartial #syntax (wholeOf (snapshot,unit))
    | NONE => Option.mapPartial #syntax (wholeOf (snapshot,unit))) (unitAt (snapshot,position))
  fun typeAtOccurrence (snapshot:snapshot,{ordinal,offset}) =
    if ordinal<0 orelse ordinal>=Vector.length (#ordered snapshot) then NONE else
      let val input=Vector.sub (#ordered snapshot,ordinal)
      in typeIn (snapshot,{file= #file input,unit=unitAt (snapshot,{ordinal=ordinal}),offset=offset}) end
  (* Only checked variable patterns supply hints. Exact frozen facts and
     lexical identities exclude constructors, copied bodies and guessed types. *)
  fun typeHints (snapshot:snapshot,{ordinal,start,stop}) : typeHint list =
    case (unitAt (snapshot,{ordinal=ordinal}),syntaxAt (snapshot,{ordinal=ordinal})) of
      (SOME unit,SOME syntax) =>
        let val input=Vector.sub (#ordered snapshot,ordinal)
            fun localFact (fact:fact,map)=if #unit fact=unit andalso #file fact= #file input andalso not (#derived fact) then
                  IntMap.insert (map,#start fact,fact::getOpt (IntMap.find (map,#start fact),[])) else map
            val facts=List.foldl localFact IntMap.empty (factsIn (snapshot,unit))
            fun localDefinition (occurrence:occurrence,map)=
              if #unit occurrence=unit andalso #file occurrence= #file input andalso #isDefinition occurrence andalso #kind occurrence="value"
                andalso not (#derived occurrence) andalso isSome (#binding occurrence) then
                IntMap.insert (map,#start occurrence,occurrence::getOpt (IntMap.find (map,#start occurrence),[])) else map
            val definitions=List.foldl localDefinition IntMap.empty (occurrencesIn (snapshot,unit))
            fun event ((kind,span:Source.span,values),(patterns,typed)) =
              let val start= #start span val stop= #stop span
              in if kind="PTyped" orelse kind="PLayered" andalso
                 (case values of [_,"true"] => true | _ => false) then
                (patterns,IntMap.insert (typed,start,Int.max (stop,getOpt (IntMap.find (typed,start),0))))
              else case (kind,values) of ("PVar",["0",name]) =>
                (IntMap.insert (patterns,start,(stop,name)),typed)
              | ("PLayered",[name,"false"]) => (IntMap.insert (patterns,start,(stop,name)),typed)
              | _ => (patterns,typed) end
            val (patterns,typed)=List.foldl event (IntMap.empty,IntMap.empty) (SyntaxAst.shape (CompilerSyntax.bridge syntax))
            val pieces=Vector.fromList (CompilerSyntax.pieces syntax)
            val count=Vector.length pieces
            fun lower (at,lo,hi)=if lo>=hi then lo else
              let val mid=lo+(hi-lo) div 2
              in if #start (Vector.sub (pieces,mid))<at then lower (at,mid+1,hi) else lower (at,lo,mid) end
            fun token (from,until,name) =
              let fun find (at,found)=if at=count then found else
                    let val piece=Vector.sub (pieces,at)
                    in if #start piece>=until then found else
                       if #stop piece<=until andalso #text piece=name andalso
                         (#kind piece="identifier" orelse #kind piece="operator") then
                         (case found of NONE => find (at+1,SOME piece) | SOME _ => NONE)
                       else find (at+1,found) end
              in find (lower (from,0,count),NONE) end
            fun advance (from,(at,until)::rest,covered)=if at<=from then advance (from,rest,Int.max (covered,until))
                  else ((at,until)::rest,covered)
              | advance (_,[],covered)=([],covered)
            fun collect ([],_,_,kept)=List.rev kept
              | collect ((from,(until,name))::rest,typed,covered,kept)=
                let val (typed,covered)=advance (from,typed,covered)
                    val definition=List.find (fn occurrence:occurrence => #stop occurrence=until andalso #name occurrence=name)
                      (getOpt (IntMap.find (definitions,from),[]))
                    val fact=List.find (fn fact:fact => #stop fact=until) (getOpt (IntMap.find (facts,from),[]))
                    val hint=if covered>=until orelse until<start orelse from>stop then NONE else
                      case (definition,fact,token (from,until,name)) of (SOME definition,SOME fact,SOME piece) =>
                        if #stop piece<start orelse #stop piece>stop then NONE else
                        SOME {name=name,position= #stop piece,ty= #ty fact,binding=valOf (#binding definition),
                          location={file= #file input,start= #start piece,stop= #stop piece}}:typeHint option
                      | _ => NONE
                in collect (rest,typed,covered,case hint of NONE => kept | SOME hint => hint::kept) end
        in if start<0 orelse stop<start then [] else collect (IntMap.listItemsi patterns,IntMap.listItemsi typed,~1,[]) end
    | _ => []
  fun queryAt (snapshot:snapshot,{ordinal,offset,path},accept:E.snapshot->bool) =
    if ordinal<0 orelse ordinal>=Vector.length (#ordered snapshot) then NONE else
    let val input=Vector.sub (#ordered snapshot,ordinal)
        fun query (sources,at)=answering (snapshot,fn engine => E.checkWith
          (engine,#scope snapshot,sources,#steps snapshot,#libraries snapshot,fn () => false,
           SOME {unit=Vector.sub (#units snapshot,ordinal),file= #file input,offset=at,path=path},
           List.map source (#dependencies snapshot),SOME (#prelude snapshot),NONE,NONE,E.Probe))
        val original=List.map source (#inputs snapshot)
        fun retry []=NONE
          | retry ((text,at)::rest)=
              let fun replace ([],_) = []
                    | replace ((item:E.source)::rest,index)=
                        (if index=ordinal then {file= #file item,text=text,mode= #mode item}:E.source else item)
                        :: replace (rest,index+1)
                  val sources=replace (original,0)
                  val result=query (sources,at)
              in if accept result then SOME result else retry rest end
        val result=query (original,offset)
    in if accept result then SOME result else
       retry (CompilerScopeProbe.texts {file= #file input,text= #text input,
         mode=valOf (Source.modeNamed (#mode input)),offset=offset}) end
  fun completionAt (snapshot,position) =
    let val result=queryAt (snapshot,position,fn result => not (null (#candidates result)))
        val (candidates,role,fields)=case result of NONE => ([],"unknown",[]) | SOME result => (#candidates result,#role result,#fields result)
        val found=finder snapshot
    in {role=role,fields=fields,candidates=List.map (fn candidate:E.candidate =>
      {name= #name candidate,kind= #kind candidate,detail= #detail candidate,
       arguments= #arguments candidate,definition=location (Env.primary (E.resolve found (#origin candidate)))}:candidate) candidates} end
  fun visibleAt (snapshot,position)= #candidates (completionAt (snapshot,position))
  fun signatureAt (snapshot,{ordinal,offset}) =
    case queryAt (snapshot,{ordinal=ordinal,offset=offset,path=[]},fn result => isSome (#application result)) of NONE => NONE
    | SOME result => case #application result of NONE => NONE | SOME application =>
        let val candidates=visibleAt (snapshot,{ordinal=ordinal,offset=offset,path= #path application})
        in case List.find (fn candidate:candidate => #name candidate= #name application andalso
             #argument application<length (#arguments candidate)) candidates of NONE => NONE
         | SOME candidate => case #detail candidate of NONE => NONE | SOME detail =>
             SOME {name= #name candidate,path= #path application,detail=detail,arguments= #arguments candidate,
               argument= #argument application,parameter= #parameter application}:call option end
  fun documentationAt (snapshot:snapshot,location:location) = C.owned (fn () =>
    let val source=List.find (fn input:input => #file input= #file location) (#inputs snapshot @ #dependencies snapshot)
    in case source of NONE => NONE | SOME source =>
      let val files=case !(#files snapshot) of SOME files => files | NONE =>
            let val files=List.foldl (fn (entry:E.entry,all) => StringMap.insert (all,#file entry,entry)) StringMap.empty (entries snapshot)
            in #files snapshot:=SOME files;files end
          val syntax=case Option.mapPartial #syntax (StringMap.find (files,#file location)) of SOME syntax => syntax | NONE =>
            CompilerSyntax.parse {file= #file source,text= #text source,mode=valOf (Source.modeNamed (#mode source)),
              orPatterns=false,fixity=Fixity.initial}
          type piece={kind:string,start:int,stop:int,text:string}
          val pieces=CompilerSyntax.pieces syntax
          fun declaration (kind,span:Source.span,_)=
            if #start span<= #start location andalso #start location<= #stop span andalso
              (String.isPrefix "D" kind orelse String.isPrefix "Spec" kind orelse
               List.exists (fn value => value=kind) ["constructor","typbind","valspec","exnspec","strspec"])
            then SOME span else NONE
          fun insert (span:Source.span,[])= [span]
            | insert (span:Source.span,(first:Source.span)::rest)=if #stop span- #start span< #stop first- #start first
                then span::first::rest else first::insert (span,rest)
          val spans=List.foldl insert [] (List.mapPartial declaration (SyntaxAst.shape (CompilerSyntax.bridge syntax)))
          fun comment (span:Source.span)=
            let val beforePieces=List.filter (fn piece:piece => #stop piece<= #start span) pieces
                fun find []=NONE
                  | find ((piece:piece)::rest)=case #kind piece of
                      "whitespace" => find rest | "bom" => find rest
                    | "comment" => if size (#text piece)>=4 andalso String.isSuffix "*)" (#text piece) then
                        let val text=BasisManifest.trim (String.substring (#text piece,2,size (#text piece)-4))
                        in if text="" then NONE else SOME text end else NONE
                    | _ => if #text piece="|" then find rest else NONE
            in find (List.rev beforePieces) end
          fun first []=NONE | first (span::rest)=case comment span of NONE => first rest | found => found
      in first spans end end)
end
