(* Fresh semantic queries for ordered compiler sessions. It keeps one
   elaboration graph through the complete source order, so later weak-type
   constraints are visible when an earlier occurrence is queried. *)
structure CompilerQuery =
struct
  open Ast
  fun infoType info =
    case info of VLocal (_,t) => t | VGlobal (_,t) => t | VCon (_,t) => t
    | VExn (_,t) => t | VBuiltin (_,t) => t | VConVal (_,t) => t | VExnVal (_,t) => t
  fun at (decs,file,offset) =
    let
      val matches=ref [] : (int * Types.ty) list ref
      fun add (span : Source.span,ty) =
        if #file span=file andalso #start span<=offset andalso offset < #stop span
        then Option.app (fn t => matches:=(#stop span- #start span,t) :: !matches) ty else ()
      fun pat p =
        (case p of
           PVar (_,slot,span, _) => (case !slot of SOME (PIVar (stamp,_)) => add (span,IntTable.find (Ty.binders,stamp)) | _ => ())
         | PScon (_,slot,span, _) => add (span,!slot)
         | PRecord (fields,_,slot,span, _) => (add (span,!slot);List.app (pat o #2) fields)
         | PTuple (ps,_, _) => List.app pat ps | PList (ps,_, _) => List.app pat ps
         | PApp (_,_,p,_, _) => pat p | PTyped (p,_,_, _) => pat p
         | PLayered (_,_,p,slot,span, _) =>
             ((case !slot of SOME (PIVar (stamp,_)) => add (span,IntTable.find (Ty.binders,stamp)) | _ => ());pat p)
         | POr (ps,_, _) => List.app pat ps | _ => ())
      fun rule (p,e) = (pat p;exp e)
      and exp e =
        case e of
          EScon (_,slot,span, _) => add (span,!slot)
        | EVar (_,slot,span, _) => add (span,Option.map infoType (!slot))
        | ERecord (fields,_, _) => List.app (exp o #2) fields
        | ETuple (es,_, _) => List.app exp es
        | EList (es,slot,span, _) => (add (span,!slot);List.app exp es)
        | ESeq (es,_, _) => List.app exp es
        | ELet (ds,e,_, _) => (List.app dec ds;exp e)
        | EApp (a,b,_, _) => (exp a;exp b)
        | ETyped (e,_,_, _) => exp e
        | EAndalso (a,b,_, _) => (exp a;exp b) | EOrelse (a,b,_, _) => (exp a;exp b)
        | EHandle (e,rs,_, _) => (exp e;List.app rule rs)
        | ERaise (e,_, _) => exp e | EIf (a,b,c,_, _) => (exp a;exp b;exp c)
        | EWhile (a,b,_, _) => (exp a;exp b)
        | ECase (e,rs,_, _) => (exp e;List.app rule rs)
        | EFn (rs,slot,span, _) => (add (span,!slot);List.app rule rs)
        | EPrim (_,_,slot,span, _) => add (span,!slot)
        | _ => ()
      and dec d =
        case d of
          DVal (_,bs,_, _) => List.app rule bs | DValRec (_,bs,_, _) => List.app rule bs
        | DFun (_,fs,_, _) => List.app (fn f =>
            ((case !(#info f) of SOME (PIVar (stamp,_)) => add (#span f,IntTable.find (Ty.binders,stamp)) | _ => ());
             List.app (fn {pats,body,...} => (List.app pat pats;exp body)) (#clauses f))) fs
        | DLocal (a,b,_, _) => List.app dec (a@b) | DAbstype (_,_,ds,_, _) => List.app dec ds
        | DStructure (bs,_, _) => List.app (str o #strexp) bs
        | DFunctor (bs,_, _) => List.app (str o #body) bs | _ => ()
      and str e =
        case e of
          StrStruct (ds,_, _) => List.app dec ds | StrAscribe (e,_,_,_, _) => str e
        | StrApp (_,arg,_, _) => str arg
        | StrLet (ds,e,_, _) => (List.app dec ds;str e) | StrExport (_,_,e,_,_, _) => str e | _ => ()
      val ()=List.app dec decs
      fun best ((width,ty),NONE) = SOME (width,ty)
        | best ((width,ty),prior as SOME (size,_)) = if width<size then SOME (width,ty) else prior
    in Option.map #2 (List.foldl best NONE (!matches)) end

  fun typeAt (session as CompilerSession.Session {config,sources,...},{file,offset}) =
    CompilerSession.owned (fn () =>
      let
        val ()=CompilerSession.checked session
        (* types only: no copy of a functor's body (D15) *)
        val ()=(Error.silent:=true;Error.keep:=true;Elaborate.recover:=true;Elaborate.makesCode:=false)
        val ()=CompilerSession.language config
        val env=ref Env.initial
        val fixity=ref Fixity.initial
        val syntax=ref [] : Ast.program list ref
        fun parse (source : CompilerSession.source) =
          let val input=Source.fromStringIn (#mode source,#file source,#text source)
              val ()=Source.register input
              val (ds,fx)=Parser.parseTokensWith (Lexer.tokenize input,!fixity)
          in fixity:=fx;ds end
        fun source (input,mentioned) =
          let val source=case input of CompilerSession.Text source => source
                | CompilerSession.Loaded a => #source a
                | CompilerSession.MidInput {source,...} => source
          in (source,BasisManifest.namesOf (Lexer.tokenize (Source.fromStringIn (#mode source,#file source,#text source)),mentioned)) end
        val inputs=List.map (fn input => #1 (source (input,StringMap.empty))) (!sources)
        val mentioned=List.foldl (fn (input,m) => #2 (source (input,m))) StringMap.empty (!sources)
        val plan=CompilerPrelude.select {lib= #lib config,libraries= #libraries config,mentioned=mentioned}
        fun library entries =
          let val prior : LibraryScope.basis={env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs}
              val incoming= !fixity
              fun unit (e : BasisManifest.entry) =
                let val text= #text (Source.readFile (Source.Ascii,BasisManifest.path e))
                    val ds=parse {file=BasisManifest.path e,text=text,mode=Source.Ascii}
                    val ()=Elaborate.allowPrim:=(case #lib config of SOME root => #dir e=root ^ "/basis" | NONE => false)
                in Elaborate.elabTop (env,ds) end
              val ()=List.app unit entries
          in case BasisManifest.scopeOf entries of NONE => () | SOME exports =>
            let val current : LibraryScope.basis={env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs}
                val narrowed=LibraryScope.restrict (prior,current,exports)
            in env:= #env narrowed;Elaborate.sigs:= #sigs narrowed;Elaborate.funs:= #funs narrowed;fixity:=incoming end end
        val ()=List.app library (#groups plan)
        (* the user's declarations recorded for their node types (CompilerNodeTypes) *)
        val ()=(Elaborate.forgetLintRecords ();Elaborate.lintRecords:=true)
        fun user input =
          let val ds=parse input
              val ()=Elaborate.allowPrim:= #allowPrim config
              val ()=Elaborate.elabTop (env,ds)
          in syntax:=ds :: !syntax end
        val ()=List.app user inputs
        val ()=Elaborate.finish ()
        val ()=if !Error.errors=0 then () else raise CompilerSession.Failed
          (List.map CompilerSession.sourceError (List.rev (!Error.kept)))
        val tops=List.rev (!Elaborate.tops)
        val () = Elaborate.lintRecords:=false
      in case CompilerNodeTypes.typeAtNow (tops,!env,file,offset) of SOME ty => SOME ty | NONE =>
         case List.mapPartial (fn ds => at (ds,file,offset)) (!syntax) of [] => NONE | ty :: _ =>
           SOME (Types.toStringNamed (fn c => Env.qualifiedName (!env,c),Types.newPrinter ()) ty) end)
end
