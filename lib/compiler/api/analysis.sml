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
  type snapshot={id:string,context:string,project:string option,inputs:input list,dependencies:input list,
    diagnostics:C.diagnostic list,occurrences:occurrence list,types:typeDefinition list,facts:fact list,reused:int,checked:int,
    config:C.config,cache:E.entry list,plan:string,steps:CompilerProject.step list,libraries:string list,prelude:CompilerPrelude.plan}
  datatype t=Analysis of {parent:C.session,context:string,namespace:string,engine:E.session,
    token:unit ref,serial:IntInf.int ref,busy:bool ref,closed:bool ref}
  datatype checkpoint=Checkpoint of {token:unit ref,entries:E.entry list,plan:string}
  exception Cancelled=E.Cancelled
  exception Busy
  fun new (parent as C.Session {config,...},context) =
    (C.checked parent;Analysis {parent=parent,context=context,namespace="analysis-" ^ Int.toString (CompilerState.freshIdentity ()),
      engine=E.new config,token=ref (),serial=ref 0,busy=ref false,closed=ref false})
  fun checked (Analysis {parent,busy,closed,...}) =
    (C.checked parent;if !closed then raise C.Closed else if !busy then raise Busy else ())
  fun close (Analysis {engine,busy,closed,...}) =
    if !busy then raise Busy else (closed:=true;E.close engine)
  fun checkpoint (context as Analysis {engine=E.Session {stored,plan,...},token,...}) =
    (checked context;Checkpoint {token=token,entries= !stored,plan= !plan})
  fun restore (context as Analysis {engine=E.Session {stored,plan,...},token,...},Checkpoint saved) =
    (checked context;if token<> #token saved then raise Fail "checkpoint belongs to another analysis context"
     else (stored:= #entries saved;plan:= #plan saved))
  fun location origin = case origin of Env.Named {span,...} => SOME
        {file= #file span,start= #start span,stop= #stop span}:location option
    | _ => NONE
  fun binding origin = case origin of Env.Named {unit,kind,name,span} =>
      let val writer=Pickle.writer ()
          val ()=List.app (fn value => Pickle.string (writer,value)) [unit,kind,name,#file span]
          val ()=(Pickle.nat (writer,#start span);Pickle.nat (writer,#stop span))
      in SOME ("binding-" ^ Pickle.hash (Pickle.contents writer)) end
    | _ => NONE
  fun freeze (unit,(role,(path,name),span:Source.span,origin,derived)) : occurrence =
    let val definition=Env.primary origin
        val declaration=Env.declaration origin
        val isDefinition=String.isPrefix "def-" role
        val kind=if isDefinition then String.extract (role,4,NONE) else role
        val kind=case kind of "v" => "value" | "t" => "type" | "s" => "structure"
          | "g" => "signature" | "f" => "functor" | _ => kind
    in {unit=unit,file= #file span,start= #start span,stop= #stop span,kind=kind,name=name,path=path,
      binding=binding definition,definition=location definition,declaration=location declaration,
      isDefinition=isDefinition,derived=derived} end
  fun check (context as Analysis {parent,context=name,namespace,engine,serial,busy,...},
             {inputs:input list,steps,project,libraries,cancelled}) : snapshot =
    let val ()=checked context
        val C.Session {config,...}=parent
        val ()=if length inputs>10000 then raise Fail "too many analysis inputs" else ()
        val _=List.foldl (fn (input:input,total) =>
          if size (#text input)>128*1024*1024-total then raise Fail "analysis input budget exceeded"
          else total+size (#text input)) 0 inputs
        fun source (input:input):E.source =
          {file= #file input,text= #text input,mode=case Source.modeNamed (#mode input) of
            SOME mode => mode | NONE => raise Fail "unknown analysis source mode"}
        val sources=List.map source inputs
        fun poll ()=let val result=cancelled () in C.checked parent;result end
        val ()=busy:=true
        fun work () =
          let val result=E.checkSteps (engine,sources,steps,libraries,poll)
              fun dependency (source:E.source):input={file= #file source,text= #text source,
                mode=Source.modeName (#mode source),annotations=[],revision=Pickle.hash (#text source)}
              val types=List.map (fn {id,origin}:E.typeDefinition =>
                {id=id,definition=location (Env.declaration origin),declaration=location (Env.declaration origin),
                 implementation=location (Env.primary origin)}:typeDefinition) (#types result)
              val snapshot={id=namespace ^ ":" ^ IntInf.toString (!serial),context=name,project=project,inputs=inputs,
                dependencies=List.map dependency (#dependencies result),diagnostics= #diagnostics result,
                occurrences=List.map freeze (#uses result),types=types,facts= #facts result,
                reused= #reused result,checked= #checked result,config=config,cache= #cache result,plan= #plan result,
                steps=steps,libraries=libraries,prelude= #prelude result}:snapshot
          in serial:=IntInf.+ (!serial,1);snapshot end
        val result=work () handle error => (busy:=false;raise error)
    in busy:=false;result end
  fun typeIn (snapshot:snapshot,{file,unit,offset}) =
    let fun candidate (fact:fact)= #file fact=file andalso (case unit of NONE => true | SOME unit => #unit fact=unit)
          andalso #start fact<=offset andalso offset< #stop fact
        fun best (fact:fact,NONE)=SOME fact
          | best (fact:fact,old as SOME previous)=
              if (#derived previous andalso not (#derived fact)) orelse
                 #derived previous= #derived fact andalso #stop fact- #start fact< #stop previous- #start previous
              then SOME fact else old
    in Option.map #ty (List.foldl best NONE (List.filter candidate (#facts snapshot))) end
  fun typeAt (snapshot:snapshot,{file,offset}) =
    if length (List.filter (fn input:input => #file input=file) (#inputs snapshot))>1 then NONE
    else typeIn (snapshot,{file=file,unit=NONE,offset=offset})
  fun unitAt (snapshot:snapshot,{ordinal}) =
    if ordinal<0 orelse ordinal>=length (#inputs snapshot) then NONE else
      SOME (E.unitName (#file (List.nth (#inputs snapshot,ordinal)),ordinal+1))
  fun typeAtOccurrence (snapshot:snapshot,{ordinal,offset}) =
    if ordinal<0 orelse ordinal>=length (#inputs snapshot) then NONE else
      let val input=List.nth (#inputs snapshot,ordinal)
      in typeIn (snapshot,{file= #file input,unit=unitAt (snapshot,{ordinal=ordinal}),offset=offset}) end
  fun queryAt (snapshot:snapshot,{ordinal,offset,path},accept:E.snapshot->bool) =
    if ordinal<0 orelse ordinal>=length (#inputs snapshot) then NONE else
    let val input=List.nth (#inputs snapshot,ordinal)
        val engine=E.Session {stored=ref (#cache snapshot),plan=ref (#plan snapshot),config= #config snapshot,closed=ref false}
        fun source (input:input):E.source={file= #file input,text= #text input,mode=valOf (Source.modeNamed (#mode input))}
        fun query (sources,at)= E.checkWith
          (engine,sources,#steps snapshot,#libraries snapshot,fn () => false,
           SOME {unit=E.unitName (#file input,ordinal+1),file= #file input,offset=at,path=path},
           List.map source (#dependencies snapshot),SOME (#prelude snapshot))
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
    in {role=role,fields=fields,candidates=List.map (fn candidate:E.candidate =>
      {name= #name candidate,kind= #kind candidate,detail= #detail candidate,
       arguments= #arguments candidate,definition=location (Env.primary (#origin candidate))}:candidate) candidates} end
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
      let val cached=List.find (fn entry:E.entry =>
            let val CompilerSyntax.Syntax {file,...}= #syntax entry in file= #file location end) (#cache snapshot)
          val syntax=case cached of SOME entry => #syntax entry | NONE =>
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
