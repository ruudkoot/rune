(* A complete syntax traversal. Copies reset every elaboration slot, including
   functor bodies, and give every node a fresh id (Ast.freshId), a node
   after its parts as the parser does; structural events retain constructor
   tags, all scalar fields, list lengths and spans. They are not the
   debugging pretty printer. *)
structure SyntaxAst =
struct
  open Ast
  type event = string * Source.span * string list
  fun transform {offset,observe} program =
    let
      fun note (kind,span:Source.span,values) =
        let val span=if #file span="" then span else
              {file= #file span,start= #start span+offset,stop= #stop span+offset}
        in observe (kind,span,values);span end
      (* a span moved as note moves one, of no event of its own: a
         record label's, a type variable's *)
      fun shift (span:Source.span)=if #file span="" then span else
        {file= #file span,start= #start span+offset,stop= #stop span+offset}
      fun tyvars vs=List.map (fn (v,s) => (v,shift s)) vs
      fun count xs=Int.toString (length xs)
      fun option f NONE=[] | option f (SOME x)=f x
      fun optional f NONE=NONE | optional f (SOME x)=SOME (f x)
      fun lid (path,name)=count path :: path @ [name]
      fun constant value=case value of
        SInt n => ["int",IntInf.toString n] | SWord n => ["word",IntInf.toString n]
      | SReal s => ["real",s] | SString s => ["string",s]
      | SWideString (xs,raw) => "wide" :: count xs :: List.map Int.toString xs @ ["raw"] @ option (fn n => [Int.toString n]) raw
      | SChar (n,raw) => ["char",Int.toString n,"raw"] @ option (fn n => [Int.toString n]) raw
      fun exp e = case e of
        EScon (c,_,s, _) => EScon (c,ref NONE,note ("EScon",s,constant c), freshId ())
      | EVar (id,_,s, _) => EVar (id,ref NONE,note ("EVar",s,lid id), freshId ())
      | ERecord (fs,s, _) => let val s=note ("ERecord",s,List.map #1 fs) in ERecord (List.map (fn (n,e,l) => (n,exp e,shift l)) fs,s, freshId ()) end
      | ETuple (es,s, _) => let val s=note ("ETuple",s,[count es]) in ETuple (List.map exp es,s, freshId ()) end
      | ESelect (n,_,s, _) => ESelect (n,ref NONE,note ("ESelect",s,[n]), freshId ())
      | EList (es,_,s, _) => let val s=note ("EList",s,[count es]) in EList (List.map exp es,ref NONE,s, freshId ()) end
      | ESeq (es,s, _) => let val s=note ("ESeq",s,[count es]) in ESeq (List.map exp es,s, freshId ()) end
      | ELet (ds,e,s, _) => let val s=note ("ELet",s,[count ds]) in ELet (List.map dec ds,exp e,s, freshId ()) end
      | EApp (a,b,s, _) => let val s=note ("EApp",s,[]) in EApp (exp a,exp b,s, freshId ()) end
      | ETyped (e,t,s, _) => let val s=note ("ETyped",s,[]) in ETyped (exp e,ty t,s, freshId ()) end
      | EAndalso (a,b,s, _) => let val s=note ("EAndalso",s,[]) in EAndalso (exp a,exp b,s, freshId ()) end
      | EOrelse (a,b,s, _) => let val s=note ("EOrelse",s,[]) in EOrelse (exp a,exp b,s, freshId ()) end
      | EHandle (e,rs,s, _) => let val s=note ("EHandle",s,[count rs]) in EHandle (exp e,List.map rule rs,s, freshId ()) end
      | ERaise (e,s, _) => let val s=note ("ERaise",s,[]) in ERaise (exp e,s, freshId ()) end
      | EIf (a,b,c,s, _) => let val s=note ("EIf",s,[]) in EIf (exp a,exp b,exp c,s, freshId ()) end
      | EWhile (a,b,s, _) => let val s=note ("EWhile",s,[]) in EWhile (exp a,exp b,s, freshId ()) end
      | ECase (e,rs,s, _) => let val s=note ("ECase",s,[count rs]) in ECase (exp e,List.map rule rs,s, freshId ()) end
      | EFn (rs,_,s, _) => let val s=note ("EFn",s,[count rs]) in EFn (List.map rule rs,ref NONE,s, freshId ()) end
      | EPrim (n,t,_,s, _) => let val s=note ("EPrim",s,[n]) in EPrim (n,ty t,ref NONE,s, freshId ()) end
      and rule (p,e)=(pat p,exp e)
      and pat p = case p of
        PWild (s, _) => PWild (note ("PWild",s,[]), freshId ())
      | PScon (c,_,s, _) => PScon (c,ref NONE,note ("PScon",s,constant c), freshId ())
      | PVar (id,_,s, _) => PVar (id,ref NONE,note ("PVar",s,lid id), freshId ())
      | PRecord (fs,flex,_,s, _) => let val s=note ("PRecord",s,Bool.toString flex :: List.map #1 fs)
          in PRecord (List.map (fn (n,p,l) => (n,pat p,shift l)) fs,flex,ref NONE,s, freshId ()) end
      | PTuple (ps,s, _) => let val s=note ("PTuple",s,[count ps]) in PTuple (List.map pat ps,s, freshId ()) end
      | PList (ps,s, _) => let val s=note ("PList",s,[count ps]) in PList (List.map pat ps,s, freshId ()) end
      | PApp (id,_,p,s, _) => let val s=note ("PApp",s,lid id) in PApp (id,ref NONE,pat p,s, freshId ()) end
      | PTyped (p,t,s, _) => let val s=note ("PTyped",s,[]) in PTyped (pat p,ty t,s, freshId ()) end
      | PLayered (n,t,p,_,s, _) => let val s=note ("PLayered",s,[n,Bool.toString (isSome t)])
          in PLayered (n,optional ty t,pat p,ref NONE,s, freshId ()) end
      | POr (ps,s, _) => let val s=note ("POr",s,[count ps]) in POr (List.map pat ps,s, freshId ()) end
      and ty t = case t of
        TyVar (n,s, _) => TyVar (n,note ("TyVar",s,[n]), freshId ())
      | TyRecord (fs,s, _) => let val s=note ("TyRecord",s,List.map #1 fs) in TyRecord (List.map (fn (n,t,l) => (n,ty t,shift l)) fs,s, freshId ()) end
      | TyTuple (ts,s, _) => let val s=note ("TyTuple",s,[count ts]) in TyTuple (List.map ty ts,s, freshId ()) end
      | TyCon (ts,id,s, _) => let val s=note ("TyCon",s,count ts :: lid id) in TyCon (List.map ty ts,id,s, freshId ()) end
      | TyArrow (a,b,s, _) => let val s=note ("TyArrow",s,[]) in TyArrow (ty a,ty b,s, freshId ()) end
      and dec d = case d of
        DVal (vs,bs,s, _) => let val s=note ("DVal",s,count bs :: List.map #1 vs) in DVal (tyvars vs,List.map rule bs,s, freshId ()) end
      | DValRec (vs,bs,s, _) => let val s=note ("DValRec",s,count bs :: List.map #1 vs) in DValRec (tyvars vs,List.map rule bs,s, freshId ()) end
      | DFun (vs,fs,s, _) => let val s=note ("DFun",s,count fs :: List.map #1 vs) in DFun (tyvars vs,List.map fundef fs,s, freshId ()) end
      | DType (bs,s, _) => let val s=note ("DType",s,[count bs]) in DType (List.map typbind bs,s, freshId ()) end
      | DDatatype (ds,ts,s, _) => let val s=note ("DDatatype",s,[count ds,count ts]) in DDatatype (List.map datbind ds,List.map typbind ts,s, freshId ()) end
      | DDatatypeRepl (n,id,s, _) => DDatatypeRepl (n,id,note ("DDatatypeRepl",s,n :: lid id), freshId ())
      | DAbstype (dbs,tbs,ds,s, _) => let val s=note ("DAbstype",s,[count dbs,count tbs,count ds])
          in DAbstype (List.map datbind dbs,List.map typbind tbs,List.map dec ds,s, freshId ()) end
      | DException (bs,s, _) => let val s=note ("DException",s,[count bs]) in DException (List.map exbind bs,s, freshId ()) end
      | DLocal (a,b,s, _) => let val s=note ("DLocal",s,[count a,count b]) in DLocal (List.map dec a,List.map dec b,s, freshId ()) end
      | DOpen (ids,s, _) => DOpen (ids,note ("DOpen",s,List.concat (List.map lid ids)), freshId ())
      | DInfix (p,ns,s, _) => DInfix (p,ns,note ("DInfix",s,Int.toString p :: ns), freshId ())
      | DInfixr (p,ns,s, _) => DInfixr (p,ns,note ("DInfixr",s,Int.toString p :: ns), freshId ())
      | DNonfix (ns,s, _) => DNonfix (ns,note ("DNonfix",s,ns), freshId ())
      | DOverload {kind,strid,literal,span,...} => DOverload {kind=kind,strid=strid,literal=literal,
          span=note ("DOverload",span,kind :: count strid :: strid @
            (case literal of OvBits n => ["bits",Int.toString n] | OvVia id => "via" :: lid id)),id=freshId ()}
      | DStructure (bs,s, _) => let val s=note ("DStructure",s,[count bs]) in DStructure (List.map strbind bs,s, freshId ()) end
      | DSignature (bs,s, _) => let val s=note ("DSignature",s,[count bs]) in DSignature (List.map sigbind bs,s, freshId ()) end
      | DFunctor (bs,s, _) => let val s=note ("DFunctor",s,[count bs]) in DFunctor (List.map funbind bs,s, freshId ()) end
      and fundef ({name,clauses,span,...}:Ast.fundef) =
        let val cs=List.map clause clauses
            val span=note ("fundef",span,[name,count clauses])
        in {name=name,clauses=cs,info=ref NONE,span=span,id=freshId ()} end
      and clause ({pats,resty,body,span,...}:Ast.clause) =
        let val span=note ("clause",span,[count pats,Bool.toString (isSome resty)])
        in {pats=List.map pat pats,resty=optional ty resty,body=exp body,span=span,id=freshId ()} end
      and typbind ({tyvars=vs,name,ty=t,span,...}:Ast.typbind) =
        let val span=note ("typbind",span,name :: List.map #1 vs) in {tyvars=tyvars vs,name=name,ty=ty t,span=span,id=freshId ()} end
      and datbind ({tyvars=vs,name,cons,span,...}:Ast.datbind) =
        let val span=note ("datbind",span,name :: count cons :: List.map #1 vs)
            fun con (n,t,s)=let val s=note ("constructor",s,[n,Bool.toString (isSome t)]) in (n,optional ty t,s) end
        in {tyvars=tyvars vs,name=name,cons=List.map con cons,span=span,id=freshId ()} end
      and exbind b = case b of
        ExnDecl (n,t,_,s, _) => let val s=note ("ExnDecl",s,[n,Bool.toString (isSome t)]) in ExnDecl (n,optional ty t,ref NONE,s, freshId ()) end
      | ExnRepl (n,id,_,s, _) => ExnRepl (n,id,ref NONE,note ("ExnRepl",s,n :: lid id), freshId ())
      and strbind ({name,strexp,span,...}:Ast.strbind) =
        let val span=note ("strbind",span,[name]) in {name=name,strexp=str strexp,span=span,id=freshId ()} end
      and sigbind ({name,sigexp,span,...}:Ast.sigbind) =
        let val span=note ("sigbind",span,[name]) in {name=name,sigexp=sg sigexp,span=span,id=freshId ()} end
      and funbind ({name,param,paramSig,body,span,...}:Ast.funbind) =
        let val span=note ("funbind",span,name :: option (fn n => [n]) param)
        in {name=name,param=param,paramSig=sg paramSig,body=str body,span=span,id=freshId ()} end
      and str e = case e of
        StrStruct (ds,s, _) => let val s=note ("StrStruct",s,[count ds]) in StrStruct (List.map dec ds,s, freshId ()) end
      | StrId (id,s, _) => StrId (id,note ("StrId",s,lid id), freshId ())
      | StrAscribe (e,g,opaque,s, _) => let val s=note ("StrAscribe",s,[Bool.toString opaque]) in StrAscribe (str e,sg g,opaque,s, freshId ()) end
      | StrApp (n,e,s, _) => let val s=note ("StrApp",s,[n]) in StrApp (n,str e,s, freshId ()) end
      | StrLet (ds,e,s, _) => let val s=note ("StrLet",s,[count ds]) in StrLet (List.map dec ds,str e,s, freshId ()) end
      | StrDynamic (from,g,_,s, _) => let val s=note ("StrDynamic",s,case from of DynamicFile p => ["file",p] | DynamicVirtual n => ["virtual",n])
          in StrDynamic (from,sg g,ref NONE,s, freshId ()) end
      | StrExport (n,g,e,_,s, _) => let val s=note ("StrExport",s,[n]) in StrExport (n,sg g,str e,ref NONE,s, freshId ()) end
      and sg g = case g of
        SigSig (ss,s, _) => let val s=note ("SigSig",s,[count ss]) in SigSig (List.map spec ss,s, freshId ()) end
      | SigId (n,s, _) => SigId (n,note ("SigId",s,[n]), freshId ())
      | SigWhere (g,cs,s, _) => let val s=note ("SigWhere",s,[count cs])
          fun constraint (vs,id,t,s)=let val s=note ("where",s,count vs :: vs @ lid id) in (vs,id,ty t,s) end
          in SigWhere (sg g,List.map constraint cs,s, freshId ()) end
      and spec s = case s of
        SpecVal (bs,s, _) => let val s=note ("SpecVal",s,[count bs])
          fun binding (n,t,s)=let val s=note ("valspec",s,[n]) in (n,ty t,s) end
          in SpecVal (List.map binding bs,s, freshId ()) end
      | SpecType (bs,s, _) => let val s=note ("SpecType",s,[count bs]) in SpecType (List.map typeSpec bs,s, freshId ()) end
      | SpecEqtype (bs,s, _) => let val s=note ("SpecEqtype",s,[count bs]) in SpecEqtype (List.map typeSpec bs,s, freshId ()) end
      | SpecDatatype (bs,s, _) => let val s=note ("SpecDatatype",s,[count bs]) in SpecDatatype (List.map datbind bs,s, freshId ()) end
      | SpecDatatypeRepl (n,id,s, _) => SpecDatatypeRepl (n,id,note ("SpecDatatypeRepl",s,n :: lid id), freshId ())
      | SpecException (bs,s, _) => let val s=note ("SpecException",s,[count bs])
          fun binding (n,t,s)=let val s=note ("exnspec",s,[n,Bool.toString (isSome t)]) in (n,optional ty t,s) end
          in SpecException (List.map binding bs,s, freshId ()) end
      | SpecStructure (bs,s, _) => let val s=note ("SpecStructure",s,[count bs])
          fun binding (n,g,s)=let val s=note ("strspec",s,[n]) in (n,sg g,s) end
          in SpecStructure (List.map binding bs,s, freshId ()) end
      | SpecInclude (g,s, _) => let val s=note ("SpecInclude",s,[]) in SpecInclude (sg g,s, freshId ()) end
      | SpecSharingType (ids,s, _) => SpecSharingType (ids,note ("SpecSharingType",s,List.concat (List.map lid ids)), freshId ())
      | SpecSharing (ids,s, _) => SpecSharing (ids,note ("SpecSharing",s,List.concat (List.map lid ids)), freshId ())
      and typeSpec (vs,n,s)=(vs,n,note ("typespec",s,n :: vs))
    in List.map dec program end
  fun copy (program,offset)=transform {offset=offset,observe=fn _ => ()} program
  fun shape program =
    let val events=ref [] : event list ref
        val _=transform {offset=0,observe=fn event => events:=event :: !events} program
    in List.rev (!events) end
end
