(* Static unit replay, held between checks. A unit stays loaded in the session
   of a world, a compiler state of its own, with the place it was reached at:
   a changed unit is elaborated at that place, and nothing else is touched
   while its identity stands. Where one moves, a walk from the start takes
   each unit after it by its usages, as a build takes an entry of the cache.
   Nothing here decides anything a fresh analysis would not (docs/language-server.md,
   Keeping what is computed): tools/lsp/oracle.sml holds it to one. *)
structure CompilerAnalysisEngine =
struct
  type source={file:string,text:string,mode:Source.mode}
  type candidate={name:string,kind:string,detail:string option,arguments:string list list,origin:Env.origin}
  type application={name:string,path:string list,argument:int,parameter:int}
  type scopeQuery={unit:string,file:string,offset:int,path:string list}
  type fact={unit:string,file:string,start:int,stop:int,ty:string,derived:bool,constructors:string list,arguments:string list list}
  type typeDefinition={id:string,origin:Env.origin}
  type use=string*(string list*string)*Source.span*Env.origin*bool
  (* A unit's results. syntax and typing (what the editor's types are worked
     out from when first asked, CompilerNodeTypes, for a unit of the inputs),
     facts and uses are a unit's that is open. A closed unit holds no syntax,
     no typing and no facts, and of its uses those whose definition is not
     their declaration, which an implementation is looked for among; it can
     be opened at its place (open') *)
  type entry={key:string,name:string,file:string,text:string,allow:bool,mode:Source.mode,pickle:string,facts:fact list,
    types:typeDefinition list,syntax:CompilerSyntax.t option,uses:use list,typing:CompilerNodeTypes.t option}
  (* the place a unit was reached at *)
  type position={env:Env.env,fixity:Fixity.env,sigs:SigMatch.sigma StringMap.map,funs:Elaborate.funinfo StringMap.map,
    binders:string StringMap.map,overloads:Overload.entry IntMap.map}
  (* What a unit declares, by a key of each definition that outlasts its span:
     its kind and the path to it. defined: each definition now, by key, where
     the unit has been elaborated since it was loaded, or worked out from
     what was loaded when first asked. keys: each definition as a client found
     it, by where it was, worked out from what was loaded when first asked. *)
  type kept={entry:entry,result:UnitBasis.result,bindings:UnitBasis.bindings,usages:(string*string) list,index:int,position:position,
    defined:Env.origin StringMap.map option ref,keys:string StringMap.map option ref}
  (* What a check leaves. complete: the last walk went through to the end, so
     that every place stands. stamps: of the files the libraries were read
     from. paths: of the units no longer in a session, which a pickle that
     holds by its usages still names *)
  type state={serial:int,kept:kept StringMap.map,order:string list,opens:string list,complete:bool,planned:(CompilerProject.step list*string list) option,
    prelude:CompilerPrelude.plan option,units:string list,libraryNames:string StringMap.map,
    libraries:(BasisManifest.entry*string) list,stamps:(string*string) list,
    names:(Source.mode*string*unit StringMap.map) StringMap.map,paths:(int*int*string) list StringMap.map}
  val noState:state={serial=0,kept=StringMap.empty,order=[],opens=[],complete=false,planned=NONE,prelude=NONE,units=[],
    libraryNames=StringMap.empty,libraries=[],stamps=[],names=StringMap.empty,paths=StringMap.empty}
  (* How a check went. walked: from the start, in place of a change at its
     place. rebound: units taken as they stood; loaded: taken again from their
     pickles; cutoff: elaborated to the identity they had; broken: a usage
     said no. *)
  type route={walked:bool,rebound:int,loaded:int,cutoff:int,broken:int}
  (* entries: what the check reached, by name, order its names; attempted: the
     syntax of the unit that failed; opened: a unit opened for a question *)
  type snapshot={diagnostics:CompilerSession.diagnostic list,reused:int,checked:int,dependencies:source list,
    candidates:candidate list,role:string,fields:(string*string) list,application:application option,
    state:state,entries:kept StringMap.map,order:string list,attempted:(string*CompilerSyntax.t) option,
    prelude:CompilerPrelude.plan,units:string list,opened:entry option,route:route}
  type observation={phase:string,file:string,checked:int,reused:int,items:int}
  (* a compiler state whose units stay loaded; base: its tables as a walk begins *)
  datatype world=World of {owner:CompilerState.session,
    base:(SigMatch.sigma StringMap.map*Elaborate.funinfo StringMap.map*Overload.entry IntMap.map) option ref}
  (* doomed: an exception left the world's tables half written *)
  datatype session=Session of {state:state ref,world:world option ref,config:CompilerSession.config,closed:bool ref,
    observer:(observation->unit) option ref,focus:unit StringMap.map option ref,doomed:bool ref}
  exception Cancelled
  (* a query has what it asked for once its unit is elaborated *)
  exception Answered
  (* an identity moved where nothing was to walk *)
  exception NeedWalk
  fun new config=Session {state=ref noState,world=ref NONE,config=config,closed=ref false,observer=ref NONE,focus=ref NONE,doomed=ref false}
  fun dropWorld (Session {world,...})=(Option.app (fn World {owner,...} => CompilerState.close owner) (!world);world:=NONE)
  fun close (session as Session {closed,state,...})=(closed:=true;state:=noState;dropWorld session)
  (* a state whose units must load again *)
  fun unplaced (saved:state,serial):state=
    {serial=serial,kept= #kept saved,order= #order saved,opens= #opens saved,complete=false,planned= #planned saved,
     prelude= #prelude saved,units= #units saved,libraryNames= #libraryNames saved,libraries= #libraries saved,
     stamps= #stamps saved,names= #names saved,paths= #paths saved}
  (* a session of its own over a state: what a query of an old snapshot, or
     one whose context has closed, walks through; nothing in it is to be kept open *)
  fun over (state,config)=Session {state=ref (unplaced (state,#serial state)),world=ref NONE,config=config,closed=ref false,
    observer=ref NONE,focus=ref (SOME StringMap.empty),doomed=ref false}
  (* a state taken back: this session's earlier one *)
  fun restore (session as Session {state=current,...},saved:state)=
    (dropWorld session;current:=unplaced (saved,#serial (!current)+1))
  (* which files stay open; NONE, all of them *)
  fun focus (Session {focus,...},files)=
    focus:=Option.map (List.foldl (fn (file,all) => StringMap.insert (all,file,())) StringMap.empty) files
  fun closedEntry (entry:entry):entry=
    {key= #key entry,name= #name entry,file= #file entry,text= #text entry,allow= #allow entry,mode= #mode entry,pickle= #pickle entry,
     facts=[],types= #types entry,syntax=NONE,typing=NONE,
     uses=List.filter (fn (_,_,_,origin,_) => Env.primary origin<>Env.declaration origin) (#uses entry)}
  fun isOpen (entry:entry)=isSome (#syntax entry)
  (* every origin of what a unit declares, by its key *)
  fun definitions (delta:Env.env,sigs:(string*SigMatch.sigma) list,funs:(string*Elaborate.funinfo) list) =
    let val found=ref []
        fun note (key,origin)=case origin of Env.Unknown => () | _ => found:=(key,origin):: !found
        fun walk (prefix,Env.Env {strs,origins,...})=
          (StringMap.appi (fn (key,origin) => note (prefix ^ key,origin)) origins;
           StringMap.appi (fn (name,inner) => walk (prefix ^ name ^ ".",inner)) strs)
        fun sigma (prefix,{env,...}:SigMatch.sigma)=walk (prefix,env)
        val ()=walk ("",delta)
        val ()=List.app (fn (name,sg:SigMatch.sigma) => (note ("g " ^ name,#origin sg);sigma ("sig:" ^ name ^ ".",sg))) sigs
        val ()=List.app (fn (name,Elaborate.FunInfo {binding,paramSig,summary,...}) =>
          (note ("f " ^ name,binding);sigma ("par:" ^ name ^ ".",paramSig);walk ("fun:" ^ name ^ ".",#result summary))) funs
    in !found end
  fun leafKey origin=case origin of
      Env.Named {kind,name,span={file,start,stop},...} =>
        SOME (kind ^ "\000" ^ name ^ "\000" ^ file ^ "\000" ^ Int.toString start ^ "\000" ^ Int.toString stop)
    | _ => NONE
  (* the definitions of a kept unit as they were loaded *)
  fun loadedDefinitions (k:kept)=
    definitions (#delta (#result k),#sigs (#bindings k),#funs (#bindings k))
  fun keysOf (k:kept)=case !(#keys k) of SOME keys => keys | NONE =>
    let fun leaves (key,origin,all)=case origin of
            Env.Constrained (a,b) => leaves (key,b,leaves (key,a,all))
          | _ => case leafKey origin of NONE => all | SOME leaf =>
              if StringMap.member (all,leaf) then all else StringMap.insert (all,leaf,key)
        val keys=List.foldr (fn ((key,origin),all) => leaves (key,origin,all)) StringMap.empty (loadedDefinitions k)
    in #keys k:=SOME keys;keys end
  (* An origin that names another unit, made a reference to that definition.
     find: a unit by its name. *)
  fun hold (find,own:string) origin=case origin of
      Env.Constrained (a,b) => Env.Constrained (hold (find,own) a,hold (find,own) b)
    | Env.Named {unit,...} => if unit=own then origin else
        (case find unit of NONE => origin | SOME k =>
           case Option.mapPartial (fn leaf => StringMap.find (keysOf k,leaf)) (leafKey origin) of
             SOME key => Env.Held {unit=unit,key=key,last=origin} | NONE => origin)
    | _ => origin
  fun definedBy (find,k:kept)=case !(#defined k) of SOME all => all | NONE =>
    let val own= #name (#entry k)
        val all=List.foldl (fn ((key,origin),all) => StringMap.insert (all,key,hold (find,own) origin)) StringMap.empty
          (loadedDefinitions k)
    in #defined k:=SOME all;all end
  (* An origin as it stands in a state, a reference followed to where its
     definition is now: what a fresh analysis would say *)
  fun resolve (find:string->kept option) origin=case origin of
      Env.Constrained (a,b) => Env.Constrained (resolve find a,resolve find b)
    | Env.Held {unit,key,last} =>
        (case find unit of NONE => last | SOME k =>
           case StringMap.find (definedBy (find,k),key) of SOME now => resolve find now | NONE => last)
    | _ => origin
  fun identityOf (k:kept)= #identity (#unit (#result k))
  fun sameSteps (a:CompilerProject.step list,b:CompilerProject.step list)=
    let fun same (CompilerProject.SUnit x,CompilerProject.SUnit y)=x=y
          | same (CompilerProject.SLocal (a,b),CompilerProject.SLocal (c,d))=sameSteps (a,c) andalso sameSteps (b,d)
          | same (CompilerProject.SLibrary (x,a),CompilerProject.SLibrary (y,b))=x=y andalso sameSteps (a,b)
          | same (CompilerProject.SUse (x,a),CompilerProject.SUse (y,b))=x=y andalso sameSteps (a,b)
          | same (CompilerProject.SImplements (x,a),CompilerProject.SImplements (y,b))=x=y andalso sameSteps (a,b)
          | same _=false
        fun all ([],[])=true | all (x::xs,y::ys)=same (x,y) andalso all (xs,ys) | all _=false
    in all (a,b) end
  (* A file's stamp holds where it is older than its time can tell. *)
  fun stampOf file=(Time.toString (OS.FileSys.modTime file) ^ ":" ^ Position.toString (OS.FileSys.fileSize file))
    handle OS.SysErr _ => "absent"
  fun settled file=(Time.< (Time.+ (OS.FileSys.modTime file,Time.fromSeconds 3),Time.now ())) handle OS.SysErr _ => true
  (* the world of a session, entered *)
  fun inWorld (session as Session {world,doomed,...},action) =
    let val current=case !world of SOME current => current | NONE =>
          let val made=World {owner=CompilerState.session (),base=ref NONE}
          in world:=SOME made;made end
        val World {owner,base}=current
        fun work ()=
          (Pass.lintDefault:=1;
           if isSome (!base) then () else
             (UnitBasis.startSession ();base:=SOME (!Elaborate.sigs,!Elaborate.funs,!Overload.table));
           action (valOf (!base)))
        fun left ()=if !doomed then (doomed:=false;dropWorld session) else ()
        val result=CompilerState.withSession (owner,work) handle error => (left ();raise error)
    in left ();result end
  (* units: the logical name of each of sources, as rune gives them
     (Workspace), its libraries' first, so that a unit is the same name in
     analysis and in a build. opening: the unit query names is wanted whole. *)
  fun checkWith (session as Session {state=saved,world,config,closed,observer,focus=focused,doomed},scope:Workspace.scope,sources:source list,steps,extraLibraries,cancelled,query:scopeQuery option,
                 frozen:source list,frozenPlan:CompilerPrelude.plan option,opening:bool) : snapshot = inWorld (session,fn (baseSigs,baseFuns,baseOverloads) =>
    let val {lib,libraries,target,allowPrim,...}=config
        val old= !saved
        val ()=CompilerSettings.target:=target
        val ()=CompilerSettings.libDir:=lib
        val ()=BasisManifest.roots:= #libraries scope
        val ()=CompilerSession.language config
        val scopeEnv=ref NONE : (int*Env.env*SigMatch.sigma StringMap.map*Elaborate.funinfo StringMap.map) option ref
        val application=ref NONE : (int*application) option ref
        val role=ref "unknown"
        val queriedSyntax=ref [] : Ast.program ref
        fun classify (syntax,offset) =
          let fun category kind=if kind="ESelect" then "field" else if String.isPrefix "Ty" kind then "type"
                else if String.isPrefix "P" kind then "pattern"
                else if String.isPrefix "E" kind andalso kind<>"ExnDecl" andalso kind<>"ExnRepl" then "expression"
                else if String.isPrefix "Str" kind orelse kind="DOpen" then "structure"
                else if String.isPrefix "Sig" kind orelse String.isPrefix "Spec" kind then "signature" else "declaration"
              fun choose ((kind,span:Source.span,_),old)=
                if #file span="" orelse offset< #start span orelse offset> #stop span then old else
                  let val width= #stop span- #start span
                  in case old of SOME (prior,_) => if prior<width then old else SOME (width,category kind)
                   | NONE => SOME (width,category kind) end
          in case List.foldl choose NONE (SyntaxAst.shape syntax) of NONE => "unknown" | SOME (_,role) => role end
        val ()=Env.observeExpression:=(fn (expression,_) => case (query,expression) of
          (SOME query,Ast.EApp (function,argument,span, _)) =>
            let val argumentSpan=Ast.spanOfExp argument
                fun head (Ast.EVar ((path,name),_,_, _),n)=SOME (path,name,n)
                  | head (Ast.EApp (function,_,_, _),n)=head (function,n+1)
                  | head (Ast.ETyped (function,_,_, _),n)=head (function,n)
                  | head _=NONE
                fun parameter ([],index)=Int.max (0,index-1)
                  | parameter (value::rest,index)=if #offset query<= #stop (Ast.spanOfExp value) then index
                      else parameter (rest,index+1)
                val width= #stop span- #start span
            in if !Env.currentUnit<> #unit query orelse #file span<> #file query orelse
                  #offset query< #start argumentSpan orelse #offset query> #stop argumentSpan then () else
                 case head (function,0) of NONE => () | SOME (path,name,index) =>
                   (case !application of SOME (prior,_) => if prior<=width then () else
                      application:=SOME (width,{path=path,name=name,argument=index,
                        parameter=case argument of Ast.ETuple (values,_, _) => parameter (values,0) | _ => 0})
                    | NONE => application:=SOME (width,{path=path,name=name,argument=index,
                        parameter=case argument of Ast.ETuple (values,_, _) => parameter (values,0) | _ => 0})) end
        | _ => ())
        val ()=Env.observeScope:=(fn (span:Source.span,env) => case query of NONE => () | SOME query =>
          if !Env.currentUnit<> #unit query orelse #file span<> #file query orelse #start span> #offset query orelse #stop span< #offset query then () else
            let val width= #stop span- #start span
            in case !scopeEnv of SOME (old,_,_,_) => if old<=width then () else scopeEnv:=SOME (width,env,!Elaborate.sigs,!Elaborate.funs)
             | NONE => scopeEnv:=SOME (width,env,!Elaborate.sigs,!Elaborate.funs) end)
        fun poll ()=if !closed then raise CompilerSession.Closed else if cancelled () then raise Cancelled else ()
        val ()=poll ()
        (* an analysis makes no code: no copy of a functor's body (D15) *)
        val ()=(Error.keep:=true;Error.silent:=true;Error.kept:=[];Error.errors:=0;Elaborate.recover:=false;Elaborate.makesCode:=false)
        (* what the editor's types read of each unit, kept (CompilerNodeTypes) *)
        val ()=Elaborate.lintRecords:=true
        val env=ref Env.initial
        val fixity=ref Fixity.initial
        val staged=ref [] : string list ref
        val unitUses=ref []
        val attempted=ref NONE : (string*CompilerSyntax.t) option ref
        val openedEntry=ref NONE : entry option ref
        val ()=Env.tracking:=true
        val ()=Env.observe:=(fn event => unitUses:=event :: !unitUses)
        val reused=ref 0
        val checked=ref 0
        fun observe phase file items=Option.app(fn f=>f {phase=phase,file=file,checked= !checked,reused= !reused,items=items})(!observer)
        val ()=observe "analysis-start" "" (length sources)
        val samePlan=case #planned old of NONE => false
          | SOME (priorSteps,priorLibraries) => priorLibraries=extraLibraries andalso sameSteps (priorSteps,steps)
        val ()=Source.overlays:=StringMap.fromList (List.map (fn source => (#file source,#text source)) (frozen @ sources))
        fun replacement (beforeText,afterText) =
          let val beforeSize=size beforeText
              val afterSize=size afterText
              fun prefix i=if i<beforeSize andalso i<afterSize andalso String.sub (beforeText,i)=String.sub (afterText,i) then prefix (i+1) else i
              val start=prefix 0
              fun suffix k=if k<beforeSize-start andalso k<afterSize-start andalso
                String.sub (beforeText,beforeSize-k-1)=String.sub (afterText,afterSize-k-1) then suffix (k+1) else k
              val suffix=suffix 0
          in {start=start,stop=beforeSize-suffix,text=String.substring (afterText,start,afterSize-suffix-start)} end
        (* what this check has done to the state, each unit at most once *)
        val next=ref StringMap.empty : kept StringMap.map ref
        val paths=ref (#paths old)
        (* an identity moved: the units from here on are out of the session *)
        val dirty=ref false
        val walked=ref 0
        val rebound=ref 0
        val loaded=ref 0
        val cutoff=ref 0
        val broken=ref 0
        (* in a load, where an exception leaves the tables half written *)
        val exposed=ref false
        fun cut index =
          let val gone=StringMap.foldl (fn (k:kept,all) =>
                if #index k>=index andalso UnitBasis.isLoaded (identityOf k) then identityOf k::all else all) [] (#kept old)
              val ()=exposed:=true
              val out=UnitBasis.truncate gone
          in exposed:=false;List.app (fn (identity,kept) => paths:=StringMap.insert (!paths,identity,kept)) out;dirty:=true end
        fun place ():position={env= !env,fixity= !fixity,sigs= !Elaborate.sigs,funs= !Elaborate.funs,binders= !UnitBasis.binders,overloads= !Overload.table}
        fun setPlace ({env=e,fixity=f,sigs,funs,binders,overloads}:position)=
          (env:=e;fixity:=f;Elaborate.sigs:=sigs;Elaborate.funs:=funs;UnitBasis.binders:=binders;Overload.table:=overloads)
        fun isFocused file=case !focused of NONE => true | SOME files => StringMap.member (files,file)
        fun priorOf name=case StringMap.find (!next,name) of SOME k => SOME k | NONE => StringMap.find (#kept old,name)
        (* an elaboration of a unit that is waiting for a walk *)
        val stash=ref NONE : (string*entry*(string*string) list*UnitBasis.exported*Env.origin StringMap.map option) option ref
        (* the unit elaborated where the session is now: its entry, its usages and
           its export, with the tables as they were found *)
        fun elaborate (source:source,name,allow,keepFacts,start:UnitBasis.start,prior:kept option,key,asked) =
          let val {file,text,mode}=source
              val keepOpen=isFocused file orelse (asked andalso opening)
              (* what a function's name is looked for in, and a position's line *)
              val ()=Source.register (Source.fromStringIn (mode,file,text))
              val ()=Elaborate.forgetLintRecords ()
              val firstId= !Ast.nextId
              val ()=(observe "unit-start" file (size text);poll ())
              val ((syntaxTree,syntax,outgoing),usages)=Usage.record (fn () =>
                let val ()=List.app (fn name => Usage.use ("fix",name)) (StringMap.listKeys (#table (!fixity)))
                    val syntaxTree=case Option.mapPartial (fn k:kept => case #syntax (#entry k) of
                          SOME tree => if #mode (#entry k)=mode then SOME (#text (#entry k),tree) else NONE | NONE => NONE) prior of
                        SOME (oldText,tree) =>
                          let val change=replacement (oldText,text)
                          in CompilerSyntax.edit (tree,{start= #start change,stop= #stop change,text= #text change,fixity= !fixity}) end
                      | NONE => CompilerSyntax.parse {file=file,text=text,mode=mode,orPatterns=false,fixity= !fixity}
                    val ()=observe "unit-parsed" file (size text)
                    val ()=if keepFacts then attempted:=SOME (name,syntaxTree) else ()
                    val ()=case CompilerSyntax.problems syntaxTree of [] => () | problem :: _ => raise Error.CompileError problem
                    val syntax=CompilerSyntax.bridge syntaxTree
                    val ()=case query of SOME query => if #unit query=name then
                      (role:=classify (syntax,#offset query);queriedSyntax:=syntax) else () | NONE => ()
                    val outgoing=CompilerSyntax.fixity syntaxTree
                    val ends=IntTable.table 16
                    val ()=List.app (fn stop => IntTable.insert (ends,stop,())) (CompilerSyntax.ends syntaxTree)
                    val ()=Parser.topdecEnds:=StringMap.insert (!Parser.topdecEnds,file,ends)
                    val ()=poll ()
                    val ()=Elaborate.allowPrim:=allow
                    val ()=Elaborate.elabTop (env,syntax)
                    val ()=Elaborate.finish ()
                    val ()=observe "unit-elaborated" file (length(!unitUses))
                    val ()=Env.noteScope ({file=file,start=0,stop=size text+1},!env)
                    val ()=if asked andalso not opening then raise Answered else ()
                    val ()=poll ()
                in (syntaxTree,syntax,outgoing) end)
              val held=UnitBasis.usagesOf usages
              val exported=UnitBasis.export {start=start,name=name,file=file,text=fn () => text,
                mode=mode,delta= !Elaborate.lastDelta,fixity=outgoing,used=usages}
              (* a type by its unit's name and its path there, which last while
                 the unit's identity moves *)
              val ownPaths=UnitBasis.typePaths (!Elaborate.lastDelta,List.mapPartial (fn n =>
                Option.map (fn sigma => (n,sigma)) (StringMap.find (!Elaborate.sigs,n))) (!Elaborate.insertedSigs))
              fun typeId stamp=case IntTable.find (Vector.sub (#own exported,UnitBasis.kTycon),stamp) of
                SOME index => name ^ ":" ^ (case IntTable.find (ownPaths,stamp) of SOME path => path | NONE => "#" ^ Int.toString index)
              | NONE => getOpt (UnitBasis.typeAnchor stamp,
                  name ^ "/local/" ^ key ^ "/" ^ Int.toString (stamp-Vector.sub (#counters start,UnitBasis.kTycon)))
              (* The outgoing environment is fixed while facts are printed.
                 Resolving a tycon's qualified path once per unit avoids
                 walking the entire environment for every occurrence. *)
              val qualified=IntTable.table 64
              fun qualifiedName (c:Types.tycon)=case IntTable.find(qualified,#stamp c) of
                SOME name=>name | NONE=>let val name=Env.qualifiedName(!env,c)
                  in IntTable.insert(qualified,#stamp c,name);name end
              fun frozenType (span:Source.span,ty,derived) =
                let val printer=Types.newPrinter ()
                    fun show ty=Types.toStringNamed (qualifiedName,printer) ty
                    fun domain ty=case Types.prune ty of Types.TRecord fields =>
                      if List.map #1 fields=List.tabulate (length fields,fn i => Int.toString (i+1)) andalso length fields>=2
                      then List.map (show o #2) fields else [show ty] | _ => [show ty]
                    fun arguments ty=case Types.prune ty of Types.TArrow (a,b) => domain a :: arguments b | _ => []
                    val constructors=ref StringMap.empty
                    fun visit ty=case Types.prune ty of Types.TCon (c,args) =>
                        (constructors:=StringMap.insert (!constructors,typeId (#stamp c),());List.app visit args)
                      | Types.TRecord fields => List.app (visit o #2) fields
                      | Types.TArrow (a,b) => (visit a;visit b) | _ => ()
                    val shown=show ty
                    val ()=visit ty
                in {unit=name,file= #file span,start= #start span,stop= #stop span,ty=shown,derived=derived,
                  constructors=StringMap.listKeys (!constructors),arguments=arguments ty}:fact end
              val frozenFacts=if keepOpen then List.map frozenType (CompilerFacts.collect syntax) else []
              val typing=if not (keepFacts andalso keepOpen) then NONE else
                SOME (CompilerNodeTypes.capture {tops=List.rev (!Elaborate.tops),ids=(firstId,!Ast.nextId),
                  stamps=(Vector.sub (#counters start,UnitBasis.kStamp),!Elaborate.stampCounter),env= !env})
              val ()=Elaborate.forgetLintRecords ()
              val holding=hold (priorOf,name)
              val typeDefinitions=IntMap.foldRange (fn (stamp,origin,all) => {id=typeId stamp,origin=holding origin} :: all) []
                (Vector.sub (#counters start,UnitBasis.kTycon),!Types.tyconCounter) (!Env.typeOrigins)
              (* what a client of this unit will find, where the unit is here again *)
              val defined=case prior of NONE => NONE | SOME _ =>
                let fun declared (names,table)=List.mapPartial (fn n => Option.map (fn value => (n,value)) (StringMap.find (table,n))) names
                in SOME (List.foldl (fn ((key,origin),all) => StringMap.insert (all,key,holding origin)) StringMap.empty
                     (definitions (!Elaborate.lastDelta,declared (!Elaborate.insertedSigs,!Elaborate.sigs),declared (!Elaborate.insertedFuns,!Elaborate.funs)))) end
              val uses=List.foldl (fn ((role,id,span,origin,derived),all) => (role,id,span,holding origin,derived)::all) [] (!unitUses)
              val ()=UnitBasis.undo start
              val whole={key=key,name=name,file=file,text=text,allow=allow,mode=mode,pickle= #pickle exported,facts=frozenFacts,
                types=typeDefinitions,syntax=SOME syntaxTree,uses=uses,typing=typing}:entry
          in checked:= !checked+1;(if keepOpen then whole else closedEntry whole,held,exported,defined) end
          handle error => (UnitBasis.undo start;raise error)
        fun unit (source:source,name,allow,keepFacts,fast) =
          let val {file,text,mode}=source
              val ()=poll ()
              val ()=(Env.currentUnit:=name;unitUses:=[])
              val prior=priorOf name
              val index= !walked
              val ()=walked:=index+1
              val here=place ()
              val asked=case query of SOME query => #unit query=name | NONE => false
              val same=case prior of NONE => false | SOME (k:kept) =>
                #allow (#entry k)=allow andalso #mode (#entry k)=mode andalso #text (#entry k)=text
              val known=case prior of NONE => false | SOME k => UnitBasis.isLoaded (identityOf k)
              val ()=if not fast andalso not (!dirty) andalso not known then cut index else ()
              (* a unit that is open wants what a closed one dropped *)
              val whole=case prior of NONE => false | SOME (k:kept) => not (isFocused file) orelse isOpen (#entry k)
              val ()=if isSome (Source.findFile file) then () else Source.register (Source.fromStringIn (mode,file,text))
              val key=case (prior,same) of (SOME (k:kept),true) => #key (#entry k)
                | _ => Pickle.hash (name ^ ":" ^ Bool.toString allow ^ ":" ^ Source.modeName mode ^ ":" ^ text)
              val start=UnitBasis.begin (!env,!fixity)
              val holds=same andalso whole andalso not asked andalso (not (!dirty) orelse
                (case UnitBasis.broken (#usages (valOf prior)) of NONE => true | SOME _ => (broken:= !broken+1;false)))
              fun compile ()=
                let val (entry,usages,exported,defined)=case !stash of
                      SOME (stashed,entry,usages,exported,defined) =>
                        if stashed<>name then raise Fail "an elaboration kept for another unit" else (stash:=NONE;(entry,usages,exported,defined))
                    | NONE => elaborate (source,name,allow,keepFacts,start,prior,key,asked)
                    fun fresh ()=
                      let val ()=exposed:=true
                          val result=UnitBasis.loadKnown ({pickle= #pickle entry,file=file,at= #counters start},SOME (#identity exported),[])
                      in exposed:=false;(entry,result,!UnitBasis.lastBindings,usages,ref NONE,ref NONE) end
                in case prior of
                     SOME (k:kept) =>
                       if asked then (entry,#result k,#bindings k,usages,#defined k,#keys k)
                       else if #identity exported=identityOf k andalso not (!dirty) andalso known then
                         (cutoff:= !cutoff+1;if fast then () else UnitBasis.rebind (#bindings k);
                          (entry,#result k,#bindings k,usages,ref defined,#keys k))
                       else if fast then (stash:=SOME (name,entry,usages,exported,defined);raise NeedWalk)
                       else (if !dirty then () else cut index;fresh ())
                   | NONE => fresh () end
              fun taken (k:kept)=
                let val entry= #entry k
                in if not (!dirty) then
                     (reused:= !reused+1;rebound:= !rebound+1;UnitBasis.rebind (#bindings k);
                      SOME (entry,#result k,#bindings k,#usages k,#defined k,#keys k))
                   else
                     let val at=UnitBasis.counters ()
                         val ()=exposed:=true
                         val tried=(SOME (UnitBasis.loadKnown ({pickle= #pickle entry,file=file,at=at},SOME (identityOf k),
                             UnitBasis.remappingBasis (#pickle entry,fn identity => StringMap.find (!paths,identity)))))
                           handle UnitBasis.Missing _ => (UnitBasis.abandon at;NONE) | Pickle.Bad _ => (UnitBasis.abandon at;NONE)
                     in exposed:=false;case tried of
                          SOME result => (reused:= !reused+1;loaded:= !loaded+1;
                            SOME (entry,result,!UnitBasis.lastBindings,#usages k,#defined k,ref NONE))
                        | NONE => NONE end end
              val (entry,result,bindings,usages,defined,keys)=
                case (if holds then taken (valOf prior) else NONE) of SOME found => found | NONE => compile ()
              val ()=if asked then
                (openedEntry:=SOME entry;raise Answered) else ()
              val ()=if fast then () else
                (exposed:=true;
                 env:=Env.plus (#env start,#delta result);
                 fixity:=Fixity.extend (#fixity start,#directives result);
                 UnitBasis.bind result;
                 exposed:=false)
              val k={entry=entry,result=result,bindings=bindings,usages=usages,index=index,
                position=if fast then #position (valOf prior) else here,defined=defined,keys=keys}:kept
          in next:=StringMap.insert (!next,name,k);staged:=name:: !staged;
             observe "unit-frozen" file (length (#uses entry));poll ();k end
        (* each input's names, scanned where its text is new *)
        val names=ref (#names old)
        val moved=ref false
        fun scan (source:source)=
          let val ()=poll ()
              fun fresh ()=
                let val ()=observe "names-start" (#file source) (size (#text source))
                    val (lexemes,_,_)=CompilerSyntax.lexical
                      {file= #file source,text= #text source,mode= #mode source,previous=NONE,change=NONE}
                    val found=BasisManifest.namesOf (CompilerSyntax.tokens lexemes (#file source),StringMap.empty)
                in names:=StringMap.insert (!names,#file source,(#mode source,#text source,found));found end
          in case StringMap.find (!names,#file source) of
               SOME (mode,text,found) => if mode= #mode source andalso text= #text source then () else
                 let val keys=fresh () in if StringMap.listKeys keys=StringMap.listKeys found then () else moved:=true end
             | NONE => (ignore (fresh ());moved:=true) end
        val ()=if isSome frozenPlan then () else List.app scan sources
        val manifests=case lib of NONE => [] | SOME root =>
          (root ^ "/basis/MANIFEST")::List.map (fn dir => dir ^ "/MANIFEST")
            ((BasisManifest.libraries (root,libraries @ extraLibraries)) handle BasisManifest.Usage _ => [])
        val stampsHold=List.all (fn (file,stamp) => stampOf file=stamp) (#stamps old)
        fun selected ()=CompilerPrelude.select {lib=lib,libraries=libraries @ extraLibraries,mentioned=
          List.foldl (fn (source:source,all) => case StringMap.find (!names,#file source) of NONE => all
            | SOME (_,_,found) => StringMap.foldli (fn (name,(),all) => StringMap.insert (all,name,())) all found) StringMap.empty sources}
        val plan=case (frozenPlan,#prelude old) of
            (SOME plan,_) => plan
          | (NONE,SOME plan) => if samePlan andalso stampsHold andalso not (!moved) then plan else selected ()
          | (NONE,NONE) => selected ()
        val selection=List.map BasisManifest.path (List.concat (#groups plan))
        val priorSelection=List.map (BasisManifest.path o #1) (#libraries old)
        val sameSelection=isSome (#prelude old) andalso selection=priorSelection
        val librarySources=if sameSelection andalso stampsHold then #libraries old else
          List.map (fn entry:BasisManifest.entry =>
            (poll ();(entry,case StringMap.find (!Source.overlays,BasisManifest.path entry) of SOME text => text
              | NONE => #text (Source.readFile (Source.Ascii,BasisManifest.path entry))))) (List.concat (#groups plan))
        val ()=observe "prelude-selected" "" (length librarySources)
        val (libraryNames,inputNames)=if samePlan andalso sameSelection then (#libraryNames old,#units old) else
          let val logical=Workspace.names scope
              val ranks=Workspace.ranks ()
              val libraryNames=List.foldl (fn (entry:BasisManifest.entry,all) =>
                StringMap.insert (all,BasisManifest.path entry,
                  Workspace.fresh (ranks,Workspace.ofEntry (logical,{dir= #dir entry,file= #file entry})))) StringMap.empty (List.concat (#groups plan))
          in (libraryNames,List.map (fn source:source => Workspace.fresh (ranks,Workspace.name (logical,#file source))) sources) end
        val ()=Source.overlays:=List.foldl (fn ((entry,text),overlays) => StringMap.insert
          (overlays,BasisManifest.path entry,text)) (!Source.overlays) librarySources
        val scopes=CompilerBuildContext.new (env,fixity)
        fun library entries =
          let val prior:LibraryScope.basis={env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs}
              val incoming= !fixity
              fun one (entry:BasisManifest.entry)=
                let val k=unit ({file=BasisManifest.path entry,text=valOf (StringMap.find (!Source.overlays,BasisManifest.path entry)),mode=Source.Ascii},
                      valOf (StringMap.find (libraryNames,BasisManifest.path entry)),
                      case lib of SOME lib => #dir entry=lib ^ "/basis" | NONE => false,false,false)
                in CompilerBuildContext.note (scopes,#result k) end
              val ()=List.app one entries
          in case BasisManifest.scopeOf entries of NONE => () | SOME exports =>
            let val current:LibraryScope.basis={env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs}
                val visible=LibraryScope.restrict (prior,current,exports)
            in env:= #env visible;fixity:=incoming;Elaborate.sigs:= #sigs visible;Elaborate.funs:= #funs visible end end
        val implemented=ref [] : string list ref
        val remaining=ref (ListPair.zip (sources,inputNames))
        fun snap ()=CompilerBuildContext.snap scopes
        fun delta (before',after)=CompilerBuildContext.delta (scopes,before',after)
        fun apply (before',change,exports)=CompilerBuildContext.apply (scopes,before',change,exports)
        fun walk steps=List.app step steps
        and step item = case item of
          CompilerProject.SUnit (file,annotations) =>
            (case !remaining of [] => raise Fail "missing ordered project input" | (source,name) :: rest =>
              if #file source<>file then raise Fail "project input order differs" else
                (remaining:=rest;
                 CompilerBuildContext.note (scopes,#result (unit (source,name,
                   allowPrim orelse List.exists (fn value => value="allowPrim") annotations,true,false)))))
        | CompilerProject.SLocal (a,b) =>
            let val before'=snap ()
                val boundary=CompilerBuildContext.enter scopes
                val ()=walk a
                val ()=CompilerBuildContext.pause (scopes,boundary)
                val hidden=snap ()
                val ()=walk b
                val ()=CompilerBuildContext.leave (scopes,boundary,[])
            in apply (before',delta (hidden,snap ()),NONE) end
        | CompilerProject.SLibrary (exports,children) =>
            let val before'=snap ()
                val boundary=CompilerBuildContext.enter scopes
                val ()=walk children
                val change=delta (before',snap ())
                val ()=case CompilerBuildContext.exportProblem (scopes,change,exports) of
                    NONE => ()
                  | SOME message => raise Error.CompileError ({file=case sources of source :: _ => #file source | [] => "",
                                                               start=0,stop=0},message)
                val ()=CompilerBuildContext.leave (scopes,boundary,exports)
            in apply (before',change,SOME exports) end
        | CompilerProject.SUse (file,children) =>
            if CompilerBuildContext.replay (scopes,file) then () else
              let val before'=snap () val ()=walk children
              in CompilerBuildContext.record (scopes,file,delta (before',snap ()),children) end
        | CompilerProject.SImplements (name,children) =>
            if List.exists (fn prior => prior=name) (!implemented) then raise Fail "duplicate virtual implementation" else
              let val before'=snap ()
                  val boundary=CompilerBuildContext.enter scopes
                  val ()=implemented:=name :: !implemented val ()=walk children
                  val ()=CompilerBuildContext.leave (scopes,boundary,[])
              in apply (before',delta (before',snap ()),SOME []) end
        fun sourceError (span,message)=SOME (CompilerSession.sourceError ("error",span,message))
        (* Each changed input at its own place, while no identity moves: the
           plan and the libraries as they were, every place standing. A
           unit that fails leaves the units as they are: what follows it is
           unavailable, as it is after a walk, and its place stands. *)
        val placed= #complete old andalso samePlan andalso sameSelection andalso
          ListPair.allEq (fn ((entry,text),(priorEntry,priorText)) =>
            BasisManifest.path entry=BasisManifest.path priorEntry andalso text=priorText) (librarySources,#libraries old)
        val zipped=ListPair.zip (sources,inputNames)
        fun wanted (source:source,name)=case StringMap.find (#kept old,name) of NONE => true
          | SOME (k:kept) => #mode (#entry k)<> #mode source orelse #text (#entry k)<> #text source
              orelse (isFocused (#file source) andalso not (isOpen (#entry k)))
        fun atPlace (source,name,k:kept)=
          (setPlace (#position k);walked:= #index k;Env.currentUnit:=name;
           ignore (unit (source,name,#allow (#entry k),true,true)))
        val fast : (CompilerSession.diagnostic option * string option) option =
          if not placed then NONE
          else case query of
            SOME q =>
              (case List.find (fn (_,name) => name= #unit q) zipped of
                 SOME (source,name) => (case StringMap.find (#kept old,name) of
                     SOME k => ((atPlace (source,name,k);SOME (NONE,NONE))
                       handle Answered => SOME (NONE,NONE) | Error.CompileError (span,message) => SOME (sourceError (span,message),NONE))
                   | NONE => NONE)
               | NONE => NONE)
          | NONE =>
            let fun go []=SOME (NONE,NONE)
                  | go ((source,name)::rest)=if not (wanted (source,name)) then go rest else
                      (case StringMap.find (#kept old,name) of
                         SOME k => ((atPlace (source,name,k);go rest)
                           handle Error.CompileError (span,message) => SOME (sourceError (span,message),SOME name))
                       | NONE => NONE)
            in go zipped handle NeedWalk => NONE end
        val finished=ref false
        val unsettled=("","unsettled")
        fun commit ()=
          let val merged=StringMap.unionWith #2 (#kept old,!next)
              val opens=StringMap.foldli (fn (name,k:kept,all) => if isOpen (#entry k) then name::all else all) (#opens old) (!next)
              val (opens,merged)=case !focused of NONE => (opens,merged) | SOME _ =>
                List.foldl (fn (name,(all,map)) => case StringMap.find (map,name) of NONE => (all,map)
                  | SOME (k:kept) => if List.exists (fn other => other=name) all then (all,map)
                      else if not (isOpen (#entry k)) then (all,map)
                      else if isFocused (#file (#entry k)) then (name::all,map)
                      else (all,StringMap.insert (map,name,{entry=closedEntry (#entry k),result= #result k,bindings= #bindings k,
                             usages= #usages k,index= #index k,position= #position k,defined= #defined k,keys= #keys k}))) ([],merged) opens
          in saved:=(case query of
              SOME _ => {serial= #serial old,kept=merged,order= #order old,opens=opens,complete= #complete old,planned= #planned old,
                prelude= #prelude old,units= #units old,libraryNames= #libraryNames old,libraries= #libraries old,
                stamps= #stamps old,names= #names old,paths= !paths}
            | NONE => {serial= #serial old+1,kept=merged,order=if isSome fast then #order old else List.rev (!staged),opens=opens,
                complete=isSome fast orelse !finished,
                planned=SOME (steps,extraLibraries),prelude=SOME plan,units=inputNames,libraryNames=libraryNames,
                libraries=librarySources,
                stamps=if sameSelection andalso stampsHold then #stamps old else
                  let val files=manifests @ selection
                  in (if List.all settled files then [] else [unsettled]) @ List.map (fn file => (file,stampOf file)) files end,
                names= !names,paths= !paths}) end
        val walkError=if isSome fast then NONE else
          let val ()=(Env.currentUnit:="";env:=Env.initial;fixity:=Fixity.initial;Elaborate.sigs:=baseSigs;Elaborate.funs:=baseFuns;
                Overload.table:=baseOverloads;UnitBasis.binders:=StringMap.empty;UnitBasis.bindLog:=[];walked:=0)
              val ()=staged:=[]
              val ()=if samePlan andalso sameSelection then () else cut 0
          in (List.app library (#groups plan);walk steps;
              if null (!remaining) then () else raise Fail "extra ordered project input";finished:=true;NONE)
             handle Error.CompileError (span,message) => sourceError (span,message)
                  | Answered => NONE
                  | error => (if !exposed then doomed:=true else ();commit ();raise error) end
        val failedAt=case fast of SOME (_,at) => at | NONE => NONE
        val error=case fast of SOME (error,_) => error | NONE => walkError
        val ()=commit ()
        val current= !saved
        val ()=poll ()
        val ()=observe "analysis-frozen" "" (!checked)
        val (order,entries)=case (fast,failedAt,error) of
            (SOME _,NONE,_) => (#order current,#kept current)
          | (SOME _,SOME at,_) =>
              let val limit= #index (valOf (StringMap.find (#kept current,at)))
                  val order=List.filter (fn name => #index (valOf (StringMap.find (#kept current,name)))<limit) (#order current)
              in (order,List.foldl (fn (name,all) => StringMap.insert (all,name,valOf (StringMap.find (#kept current,name)))) StringMap.empty order) end
          | (NONE,_,NONE) => (#order current,#kept current)
          | (NONE,_,SOME _) => (#order current,List.foldl (fn (name,all) => StringMap.insert (all,name,valOf (StringMap.find (#kept current,name)))) StringMap.empty (#order current))
        val ()=if isSome fast then reused:=length order- !checked else ()
        fun candidates ()=case (!scopeEnv,query) of (SOME (_,env,sigs,funs),SOME query) =>
          let val selected=case Env.findStr' (env,#path query) of SOME selected => SOME selected | NONE => NONE
              val holding=hold (priorOf,#unit query)
              fun value (name,status)=
                let val ty=case status of Env.Val {scheme,...} => scheme | Env.Con {scheme,...} => scheme
                      | Env.ConAsVal {scheme,...} => scheme | Env.Prim {scheme,...} => scheme
                      | Env.Exn {ty,...} => ty | Env.ExnAsVal {ty,...} => ty
                    val kind=case status of Env.Con _ => "constructor" | Env.Exn _ => "exception"
                      | _ => (case Types.prune ty of Types.TArrow _ => "function" | _ => "value")
                    val printer=Types.newPrinter ()
                    fun show ty=Types.toStringNamed (fn c => Env.qualifiedName (env,c),printer) ty
                    fun domain ty=case Types.prune ty of Types.TRecord fields =>
                          if List.map #1 fields=List.tabulate (length fields,fn i => Int.toString (i+1)) andalso length fields>=2
                          then List.map (show o #2) fields else [show ty] | _ => [show ty]
                    fun arguments ty=case Types.prune ty of Types.TArrow (a,b) => domain a::arguments b | _ => []
                    val detail=show ty
                in {name=name,kind=kind,detail=SOME detail,arguments=arguments ty,
                  origin=holding (Env.originOf (env,"v",(#path query,name)))}:candidate end
              fun member (kind,name)={name=name,kind=kind,detail=NONE,arguments=[],
                origin=holding (Env.originOf (env,if kind="type" then "t" else "s",(#path query,name)))}:candidate
          in case selected of NONE => [] | SOME selected =>
            List.map value (StringMap.listItemsi (Env.vals selected)) @
            List.map (fn name => member ("type",name)) (StringMap.listKeys (Env.tys selected)) @
            List.map (fn name => member ("structure",name)) (StringMap.listKeys (Env.strs selected)) @
            (if not (null (#path query)) then [] else
              List.map (fn (name,sigma) => {name=name,kind="signature",detail=NONE,arguments=[],origin=holding (#origin sigma)}:candidate) (StringMap.listItemsi sigs) @
              List.map (fn (name,Elaborate.FunInfo {binding,...}) => {name=name,kind="functor",detail=NONE,arguments=[],origin=holding binding}:candidate) (StringMap.listItemsi funs)) end
          | _ => []
        fun fields ()=case query of NONE => [] | SOME query =>
          case CompilerFacts.recordAt (!queriedSyntax,#file query,#offset query) of NONE => [] | SOME ty =>
            case Types.prune ty of Types.TRecord fields =>
              let val printer=Types.newPrinter ()
                  fun show ty=case !scopeEnv of NONE => Types.toStringNamed (fn _ => NONE,printer) ty
                    | SOME (_,env,_,_) => Types.toStringNamed (fn c => Env.qualifiedName (env,c),printer) ty
              in List.map (fn (name,ty) => (name,show ty)) fields end | _ => []
    in {diagnostics=case error of NONE => [] | SOME error => [error],reused= !reused,checked= !checked,
      dependencies=List.map (fn (entry,text) => {file=BasisManifest.path entry,text=text,mode=Source.Ascii}:source) librarySources,
      candidates=candidates (),role= !role,fields=fields (),application=Option.map #2 (!application),
      state=current,entries=entries,order=order,attempted= !attempted,prelude=plan,units=inputNames,opened= !openedEntry,
      route={walked=not (isSome fast),rebound= !rebound,loaded= !loaded,cutoff= !cutoff,broken= !broken}} end)
  fun checkSteps (session,scope,sources,steps,libraries,cancelled)=checkWith (session,scope,sources,steps,libraries,cancelled,NONE,[],NONE,false)
end
