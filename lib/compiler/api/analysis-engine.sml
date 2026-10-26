(* Static unit replay. A failed or cancelled attempt never publishes mutable
   annotations. Cache reuse requires the exact unchanged input prefix. *)
structure CompilerAnalysisEngine =
struct
  type source={file:string,text:string,mode:Source.mode}
  type candidate={name:string,kind:string,detail:string option,arguments:string list list,origin:Env.origin}
  type application={name:string,path:string list,argument:int,parameter:int}
  type scopeQuery={unit:string,file:string,offset:int,path:string list}
  fun unitName (file,rank) = file ^ "#" ^ Int.toString rank
  type fact={unit:string,file:string,start:int,stop:int,ty:string,derived:bool,constructors:string list,arguments:string list list}
  type typeDefinition={id:string,origin:Env.origin}
  type entry={key:string,name:string,allow:bool,mode:Source.mode,pickle:string,facts:fact list,types:typeDefinition list,syntax:CompilerSyntax.t,uses:(string*(string list*string)*Source.span*Env.origin*bool) list}
  type snapshot={facts:fact list,diagnostics:CompilerSession.diagnostic list,reused:int,checked:int,types:typeDefinition list,dependencies:source list,
    uses:(string*(string*(string list*string)*Source.span*Env.origin*bool)) list,
    candidates:candidate list,role:string,fields:(string*string) list,application:application option,
    cache:entry list,syntaxes:(string*CompilerSyntax.t) list,plan:string,prelude:CompilerPrelude.plan}
  type observation={phase:string,file:string,checked:int,reused:int,items:int}
  datatype session=Session of {stored:entry list ref,plan:string ref,config:CompilerSession.config,closed:bool ref,
    observer:(observation->unit) option ref,names:(Source.mode*string*unit StringMap.map) StringMap.map ref}
  exception Cancelled
  fun new config=Session {stored=ref [],plan=ref "",config=config,closed=ref false,observer=ref NONE,names=ref StringMap.empty}
  fun close (Session {closed,stored,names,...})=(closed:=true;stored:=[];names:=StringMap.empty)
  fun checkWith (Session {stored,plan=savedPlan,config,closed,observer,names=savedNames},sources:source list,steps,extraLibraries,cancelled,query:scopeQuery option,
                 frozen:source list,frozenPlan:CompilerPrelude.plan option) : snapshot = CompilerSession.owned (fn () =>
    let val {lib,libraries,target,allowPrim,...}=config
        val ()=CompilerSettings.target:=target
        val ()=CompilerSettings.libDir:=lib
        val ()=CompilerSession.language config
        val ()=UnitBasis.startSession ()
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
          (SOME query,Ast.EApp (function,argument,span)) =>
            let val argumentSpan=Ast.spanOfExp argument
                fun head (Ast.EVar ((path,name),_,_),n)=SOME (path,name,n)
                  | head (Ast.EApp (function,_,_),n)=head (function,n+1)
                  | head (Ast.ETyped (function,_,_),n)=head (function,n)
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
                        parameter=case argument of Ast.ETuple (values,_) => parameter (values,0) | _ => 0})
                    | NONE => application:=SOME (width,{path=path,name=name,argument=index,
                        parameter=case argument of Ast.ETuple (values,_) => parameter (values,0) | _ => 0})) end
        | _ => ())
        val ()=Env.observeScope:=(fn (span:Source.span,env) => case query of NONE => () | SOME query =>
          if !Env.currentUnit<> #unit query orelse #file span<> #file query orelse #start span> #offset query orelse #stop span< #offset query then () else
            let val width= #stop span- #start span
            in case !scopeEnv of SOME (old,_,_,_) => if old<=width then () else scopeEnv:=SOME (width,env,!Elaborate.sigs,!Elaborate.funs)
             | NONE => scopeEnv:=SOME (width,env,!Elaborate.sigs,!Elaborate.funs) end)
        fun poll ()=if !closed then raise CompilerSession.Closed else if cancelled () then raise Cancelled else ()
        val ()=poll ()
        (* an analysis makes no code: no copy of a functor's body (D15) *)
        val ()=(Error.keep:=true;Error.silent:=true;Elaborate.recover:=false;Elaborate.makesCode:=false)
        val env=ref Env.initial
        val fixity=ref Fixity.initial
        val scopes=CompilerBuildContext.new (env,fixity)
        val staged=ref [] : entry list ref
        val facts=ref [] : fact list list ref
        val types=ref [] : typeDefinition list list ref
        val uses=ref []
        val unitUses=ref []
        val syntaxes=ref [] : (string*CompilerSyntax.t) list ref
        val ()=Env.tracking:=true
        val ()=Env.observe:=(fn event => unitUses:=event :: !unitUses)
        val reused=ref 0
        val checked=ref 0
        fun observe phase file items=Option.app(fn f=>f {phase=phase,file=file,checked= !checked,reused= !reused,items=items})(!observer)
        val ()=observe "analysis-start" "" (length sources)
        val planBytes=Pickle.writer ()
        fun encode (w,item)=case item of
          CompilerProject.SUnit (file,annotations) => (Pickle.byte (w,0);Pickle.string (w,file);Pickle.list Pickle.string (w,annotations))
        | CompilerProject.SLocal (a,b) => (Pickle.byte (w,1);Pickle.list encode (w,a);Pickle.list encode (w,b))
        | CompilerProject.SLibrary (exports,children) => (Pickle.byte (w,2);
            Pickle.list (fn (w,(kind,name)) => (Pickle.byte (w,case kind of BuildFile.Str => 0 | BuildFile.Sig => 1 | BuildFile.Fun => 2 | BuildFile.Ty => 3);
              Pickle.string (w,name))) (w,exports);Pickle.list encode (w,children))
        | CompilerProject.SUse (file,children) => (Pickle.byte (w,3);Pickle.string (w,file);Pickle.list encode (w,children))
        | CompilerProject.SImplements (name,children) => (Pickle.byte (w,4);Pickle.string (w,name);Pickle.list encode (w,children))
        val ()=Pickle.list encode (planBytes,steps)
        val ()=Pickle.list Pickle.string (planBytes,extraLibraries)
        val planKey=Pickle.contents planBytes
        val prefix=ref (!savedPlan=planKey)
        val cursor=ref (!stored)
        val oldSyntax=StringMap.fromList (List.map (fn entry:entry => (#name entry,entry)) (!stored))
        val chain=ref (Config.identity ^ Pickle.hash planKey)
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
        fun unit (source:source,name,allow,keepFacts) =
          let val {file,text,mode}=source
              val ()=poll ()
              val ()=observe "unit-start" file (size text)
              val ()=(Env.currentUnit:=name;unitUses:=[])
              val ()=Source.register (Source.fromStringIn (mode,file,text))
              val key=Pickle.hash (!chain ^ ":" ^ name ^ ":" ^ Bool.toString allow ^ ":" ^ Source.modeName mode ^ ":" ^ text)
              val start=UnitBasis.begin (!env,!fixity)
              val previous=case !cursor of [] => NONE | entry :: rest => (cursor:=rest;SOME entry)
              val cached=case previous of SOME entry =>
                if !prefix andalso not (case query of SOME query => #unit query=name | NONE => false) andalso #name entry=name andalso #allow entry=allow andalso #mode entry=mode
                  andalso CompilerSyntax.text (#syntax entry)=text then SOME entry else NONE | NONE => NONE
              fun remember syntax=if keepFacts then syntaxes:=(name,syntax):: !syntaxes else ()
              val entry=case cached of SOME entry => (remember (#syntax entry);reused:= !reused+1;entry)
              | NONE => (prefix:=false;
                let val ((syntaxTree,syntax,outgoing),usages)=Usage.record (fn () =>
                    let val ()=List.app (fn name => Usage.use ("fix",name)) (StringMap.listKeys (#table (!fixity)))
                      val syntaxTree=case StringMap.find (oldSyntax,name) of
                      SOME entry =>
                        let val CompilerSyntax.Syntax {mode=oldMode,...}= #syntax entry
                            val change=replacement (CompilerSyntax.text (#syntax entry),text)
                        in if mode=oldMode then CompilerSyntax.edit (#syntax entry,
                             {start= #start change,stop= #stop change,text= #text change,fixity= !fixity})
                           else CompilerSyntax.parse {file=file,text=text,mode=mode,orPatterns=false,fixity= !fixity} end
                    | NONE => CompilerSyntax.parse {file=file,text=text,mode=mode,orPatterns=false,fixity= !fixity}
                    val ()=observe "unit-parsed" file (size text)
                    val ()=remember syntaxTree
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
                    val ()=poll ()
                    in (syntaxTree,syntax,outgoing) end)
                    val exported=UnitBasis.export {start=start,name=name,file=file,text=fn () => text,
                      mode=mode,delta= !Elaborate.lastDelta,fixity=outgoing,used=usages}
                    fun typeId stamp=case IntTable.find (Vector.sub (#own exported,UnitBasis.kTycon),stamp) of
                      SOME index => #identity exported ^ "#" ^ Int.toString index
                    | NONE => getOpt (UnitBasis.stableName (UnitBasis.kTycon,stamp),
                        #identity exported ^ "/local/" ^ key ^ "/" ^ Int.toString (stamp-Vector.sub (#counters start,UnitBasis.kTycon)))
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
                    val frozen=List.map frozenType (CompilerFacts.collect syntax)
                    val typeDefinitions=IntMap.foldli (fn (stamp,origin,all) =>
                      if stamp<Vector.sub (#counters start,UnitBasis.kTycon) then all else
                        {id=typeId stamp,origin=origin} :: all) [] (!Env.typeOrigins)
                    val ()=UnitBasis.undo start
                in checked:= !checked+1;{key=key,name=name,allow=allow,mode=mode,pickle= #pickle exported,facts=frozen,types=typeDefinitions,
                  syntax=syntaxTree,uses=List.rev (!unitUses)}:entry end)
              val loaded=UnitBasis.load {pickle= #pickle entry,file=file,at= #counters start}
              val ()=env:=Env.plus (#env start,#delta loaded)
              val ()=fixity:=Fixity.extend (#fixity start,#directives loaded)
              val ()=UnitBasis.bind loaded
              val ()=CompilerBuildContext.note (scopes,loaded)
          in observe "unit-frozen" file (length(#uses entry));poll ();chain:=key;staged:=entry :: !staged;types:= #types entry :: !types;
             facts:= #facts entry :: !facts;uses:=List.map (fn event => (name,event)) (#uses entry) :: !uses end
        val sourceNames=ref StringMap.empty
        fun names (source:source,mentioned)=
          let val ()=poll()
              val ()=observe "names-start" (#file source) (size(#text source))
              fun scan ()=let val (lexemes,_,_)=CompilerSyntax.lexical
                    {file= #file source,text= #text source,mode= #mode source,previous=NONE,change=NONE}
                in BasisManifest.namesOf(CompilerSyntax.tokens lexemes (#file source),StringMap.empty) end
              val found=case StringMap.find(!savedNames,#file source) of SOME(mode,text,names)=>
                  if mode= #mode source andalso text= #text source then names else scan() | NONE=>scan()
              val ()=sourceNames:=StringMap.insert(!sourceNames,#file source,(#mode source,#text source,found))
          in StringMap.foldli(fn (name,(),all)=>StringMap.insert(all,name,()))mentioned found end
        val plan=case frozenPlan of SOME plan => plan | NONE =>
          CompilerPrelude.select {lib=lib,libraries=libraries @ extraLibraries,mentioned=List.foldl names StringMap.empty sources}
        val librarySources=List.map (fn entry:BasisManifest.entry =>
          (poll ();(entry,#text (Source.readFile (Source.Ascii,BasisManifest.path entry))))) (List.concat (#groups plan))
        val ()=observe "prelude-selected" "" (length librarySources)
        val ()=Source.overlays:=List.foldl (fn ((entry,text),overlays) => StringMap.insert
          (overlays,BasisManifest.path entry,text)) (!Source.overlays) librarySources
        fun library entries =
          let val prior:LibraryScope.basis={env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs}
              val incoming= !fixity
              fun one (entry:BasisManifest.entry)=
                unit ({file=BasisManifest.path entry,text=valOf (StringMap.find (!Source.overlays,BasisManifest.path entry)),mode=Source.Ascii},BasisManifest.path entry,
                  case lib of SOME lib => #dir entry=lib ^ "/basis" | NONE => false,false)
              val ()=List.app one entries
          in case BasisManifest.scopeOf entries of NONE => () | SOME exports =>
            let val current:LibraryScope.basis={env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs}
                val visible=LibraryScope.restrict (prior,current,exports)
            in env:= #env visible;fixity:=incoming;Elaborate.sigs:= #sigs visible;Elaborate.funs:= #funs visible end end
        val used=ref [] : (string*CompilerBuildContext.delta) list ref
        val implemented=ref [] : string list ref
        val remaining=ref sources
        val ordinal=ref 0
        fun snap ()=CompilerBuildContext.snap scopes
        fun delta (before',after)=CompilerBuildContext.delta (scopes,before',after)
        fun apply (before',change,exports)=CompilerBuildContext.apply (scopes,before',change,exports)
        fun walk steps=List.app step steps
        and step item = case item of
          CompilerProject.SUnit (file,annotations) =>
            (case !remaining of [] => raise Fail "missing ordered project input" | source :: rest =>
              if #file source<>file then raise Fail "project input order differs" else
                (remaining:=rest;ordinal:= !ordinal+1;
                 unit (source,unitName (file,!ordinal),allowPrim orelse List.exists (fn value => value="allowPrim") annotations,true)))
        | CompilerProject.SLocal (a,b) =>
            let val before'=snap ()
                val ()=walk a
                val hidden=snap ()
                val ()=walk b
            in apply (before',delta (hidden,snap ()),NONE) end
        | CompilerProject.SLibrary (exports,children) =>
            let val before'=snap () val ()=walk children in apply (before',delta (before',snap ()),SOME exports) end
        | CompilerProject.SUse (file,children) =>
            (case List.find (fn (name,_) => name=file) (!used) of SOME (_,change) => apply (snap (),change,NONE)
             | NONE => let val before'=snap () val ()=walk children in used:=(file,delta (before',snap ())) :: !used end)
        | CompilerProject.SImplements (name,children) =>
            if List.exists (fn prior => prior=name) (!implemented) then raise Fail "duplicate virtual implementation" else
              let val before'=snap () val ()=implemented:=name :: !implemented val ()=walk children
              in apply (before',delta (before',snap ()),SOME []) end
        val error=(List.app library (#groups plan);walk steps;
          if null (!remaining) then () else raise Fail "extra ordered project input";NONE) handle Error.CompileError (span,message) =>
          SOME (CompilerSession.sourceError ("error",span,message))
        val ()=poll ()
        val ()=observe "analysis-frozen" "" (List.foldl(fn(xs,n)=>n+length xs)0(!uses))
        val ()=(stored:=List.rev (!staged);savedPlan:=planKey;
          case frozenPlan of NONE=>savedNames:= !sourceNames | SOME _=>())
        fun candidates ()=case (!scopeEnv,query) of (SOME (_,env,sigs,funs),SOME query) =>
          let val selected=case Env.findStr' (env,#path query) of SOME selected => SOME selected | NONE => NONE
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
                  origin=Env.originOf (env,"v",(#path query,name))}:candidate end
              fun member (kind,name)={name=name,kind=kind,detail=NONE,arguments=[],
                origin=Env.originOf (env,if kind="type" then "t" else "s",(#path query,name))}:candidate
          in case selected of NONE => [] | SOME selected =>
            List.map value (StringMap.listItemsi (Env.vals selected)) @
            List.map (fn name => member ("type",name)) (StringMap.listKeys (Env.tys selected)) @
            List.map (fn name => member ("structure",name)) (StringMap.listKeys (Env.strs selected)) @
            (if not (null (#path query)) then [] else
              List.map (fn (name,sigma) => {name=name,kind="signature",detail=NONE,arguments=[],origin= #origin sigma}:candidate) (StringMap.listItemsi sigs) @
              List.map (fn (name,Elaborate.FunInfo {binding,...}) => {name=name,kind="functor",detail=NONE,arguments=[],origin=binding}:candidate) (StringMap.listItemsi funs)) end
          | _ => []
        fun fields ()=case query of NONE => [] | SOME query =>
          case CompilerFacts.recordAt (!queriedSyntax,#file query,#offset query) of NONE => [] | SOME ty =>
            case Types.prune ty of Types.TRecord fields =>
              let val printer=Types.newPrinter ()
                  fun show ty=case !scopeEnv of NONE => Types.toStringNamed (fn _ => NONE,printer) ty
                    | SOME (_,env,_,_) => Types.toStringNamed (fn c => Env.qualifiedName (env,c),printer) ty
              in List.map (fn (name,ty) => (name,show ty)) fields end | _ => []
    in {facts=List.concat (List.rev (!facts)),diagnostics=case error of NONE => [] | SOME error => [error],
      reused= !reused,checked= !checked,types=List.concat (List.rev (!types)),
      dependencies=List.map (fn (entry,text) => {file=BasisManifest.path entry,text=text,mode=Source.Ascii}:source) librarySources,
      uses=List.concat (List.rev (!uses)),candidates=candidates (),role= !role,fields=fields (),application=Option.map #2 (!application),
      cache= !stored,syntaxes=List.rev (!syntaxes),plan=planKey,prelude=plan} end)
  fun checkSteps (session,sources,steps,libraries,cancelled)=checkWith (session,sources,steps,libraries,cancelled,NONE,[],NONE)
end
