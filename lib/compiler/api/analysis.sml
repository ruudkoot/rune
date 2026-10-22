(* Immutable analysis publication around static unit replay. Context ownership
   and cancellation are checked before cache/checkpoint publication. *)
structure CompilerAnalysis =
struct
  structure E=CompilerAnalysisEngine
  structure C=CompilerSession
  type input={file:string,text:string,mode:string,annotations:string list,revision:string}
  type location={file:string,start:int,stop:int}
  type occurrence={file:string,start:int,stop:int,kind:string,name:string,path:string list,
    binding:string option,definition:location option,declaration:location option,isDefinition:bool,derived:bool}
  type typeDefinition={id:string,definition:location option,declaration:location option,implementation:location option}
  type fact=E.fact
  type snapshot={id:string,context:string,project:string option,inputs:input list,dependencies:input list,
    diagnostics:C.diagnostic list,occurrences:occurrence list,types:typeDefinition list,facts:fact list,reused:int,checked:int}
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
  fun freeze (role,(path,name),span:Source.span,origin,derived) : occurrence =
    let val definition=Env.primary origin
        val declaration=Env.declaration origin
        val isDefinition=String.isPrefix "def-" role
        val kind=if isDefinition then String.extract (role,4,NONE) else role
        val kind=case kind of "v" => "value" | "t" => "type" | "s" => "structure"
          | "g" => "signature" | "f" => "functor" | _ => kind
    in {file= #file span,start= #start span,stop= #stop span,kind=kind,name=name,path=path,
      binding=binding definition,definition=location definition,declaration=location declaration,
      isDefinition=isDefinition,derived=derived} end
  fun check (context as Analysis {parent,context=name,namespace,engine,serial,busy,...},
             {inputs:input list,steps,project,libraries,cancelled}) : snapshot =
    let val ()=checked context
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
                reused= #reused result,checked= #checked result}:snapshot
          in serial:=IntInf.+ (!serial,1);snapshot end
        val result=work () handle error => (busy:=false;raise error)
    in busy:=false;result end
  fun typeAt (snapshot:snapshot,{file,offset}) =
    let fun candidate (fact:fact)= #file fact=file andalso #start fact<=offset andalso offset< #stop fact
        fun best (fact:fact,NONE)=SOME fact
          | best (fact:fact,old as SOME previous)=
              if (#derived previous andalso not (#derived fact)) orelse
                 #derived previous= #derived fact andalso #stop fact- #start fact< #stop previous- #start previous
              then SOME fact else old
    in Option.map #ty (List.foldl best NONE (List.filter candidate (#facts snapshot))) end
end
