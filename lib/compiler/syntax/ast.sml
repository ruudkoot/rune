(* A complete syntax traversal. Copies reset every elaboration slot, including
   functor bodies; structural events retain constructor tags, all scalar
   fields, list lengths and spans. They are not the debugging pretty printer. *)
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
        EScon (c,_,s) => EScon (c,ref NONE,note ("EScon",s,constant c))
      | EVar (id,_,s) => EVar (id,ref NONE,note ("EVar",s,lid id))
      | ERecord (fs,s) => let val s=note ("ERecord",s,List.map #1 fs) in ERecord (List.map (fn (n,e) => (n,exp e)) fs,s) end
      | ETuple (es,s) => let val s=note ("ETuple",s,[count es]) in ETuple (List.map exp es,s) end
      | ESelect (n,_,s) => ESelect (n,ref NONE,note ("ESelect",s,[n]))
      | EList (es,_,s) => let val s=note ("EList",s,[count es]) in EList (List.map exp es,ref NONE,s) end
      | ESeq (es,s) => let val s=note ("ESeq",s,[count es]) in ESeq (List.map exp es,s) end
      | ELet (ds,e,s) => let val s=note ("ELet",s,[count ds]) in ELet (List.map dec ds,exp e,s) end
      | EApp (a,b,s) => let val s=note ("EApp",s,[]) in EApp (exp a,exp b,s) end
      | ETyped (e,t,s) => let val s=note ("ETyped",s,[]) in ETyped (exp e,ty t,s) end
      | EAndalso (a,b,s) => let val s=note ("EAndalso",s,[]) in EAndalso (exp a,exp b,s) end
      | EOrelse (a,b,s) => let val s=note ("EOrelse",s,[]) in EOrelse (exp a,exp b,s) end
      | EHandle (e,rs,s) => let val s=note ("EHandle",s,[count rs]) in EHandle (exp e,List.map rule rs,s) end
      | ERaise (e,s) => let val s=note ("ERaise",s,[]) in ERaise (exp e,s) end
      | EIf (a,b,c,s) => let val s=note ("EIf",s,[]) in EIf (exp a,exp b,exp c,s) end
      | EWhile (a,b,s) => let val s=note ("EWhile",s,[]) in EWhile (exp a,exp b,s) end
      | ECase (e,rs,s) => let val s=note ("ECase",s,[count rs]) in ECase (exp e,List.map rule rs,s) end
      | EFn (rs,_,s) => let val s=note ("EFn",s,[count rs]) in EFn (List.map rule rs,ref NONE,s) end
      | EPrim (n,t,_,s) => let val s=note ("EPrim",s,[n]) in EPrim (n,ty t,ref NONE,s) end
      and rule (p,e)=(pat p,exp e)
      and pat p = case p of
        PWild s => PWild (note ("PWild",s,[]))
      | PScon (c,_,s) => PScon (c,ref NONE,note ("PScon",s,constant c))
      | PVar (id,_,s) => PVar (id,ref NONE,note ("PVar",s,lid id))
      | PRecord (fs,flex,_,s) => let val s=note ("PRecord",s,Bool.toString flex :: List.map #1 fs)
          in PRecord (List.map (fn (n,p) => (n,pat p)) fs,flex,ref NONE,s) end
      | PTuple (ps,s) => let val s=note ("PTuple",s,[count ps]) in PTuple (List.map pat ps,s) end
      | PList (ps,s) => let val s=note ("PList",s,[count ps]) in PList (List.map pat ps,s) end
      | PApp (id,_,p,s) => let val s=note ("PApp",s,lid id) in PApp (id,ref NONE,pat p,s) end
      | PTyped (p,t,s) => let val s=note ("PTyped",s,[]) in PTyped (pat p,ty t,s) end
      | PLayered (n,t,p,_,s) => let val s=note ("PLayered",s,[n,Bool.toString (isSome t)])
          in PLayered (n,optional ty t,pat p,ref NONE,s) end
      | POr (ps,s) => let val s=note ("POr",s,[count ps]) in POr (List.map pat ps,s) end
      and ty t = case t of
        TyVar (n,s) => TyVar (n,note ("TyVar",s,[n]))
      | TyRecord (fs,s) => let val s=note ("TyRecord",s,List.map #1 fs) in TyRecord (List.map (fn (n,t) => (n,ty t)) fs,s) end
      | TyTuple (ts,s) => let val s=note ("TyTuple",s,[count ts]) in TyTuple (List.map ty ts,s) end
      | TyCon (ts,id,s) => let val s=note ("TyCon",s,count ts :: lid id) in TyCon (List.map ty ts,id,s) end
      | TyArrow (a,b,s) => let val s=note ("TyArrow",s,[]) in TyArrow (ty a,ty b,s) end
      and dec d = case d of
        DVal (vs,bs,s) => let val s=note ("DVal",s,count bs :: vs) in DVal (vs,List.map rule bs,s) end
      | DValRec (vs,bs,s) => let val s=note ("DValRec",s,count bs :: vs) in DValRec (vs,List.map rule bs,s) end
      | DFun (vs,fs,s) => let val s=note ("DFun",s,count fs :: vs) in DFun (vs,List.map fundef fs,s) end
      | DType (bs,s) => let val s=note ("DType",s,[count bs]) in DType (List.map typbind bs,s) end
      | DDatatype (ds,ts,s) => let val s=note ("DDatatype",s,[count ds,count ts]) in DDatatype (List.map datbind ds,List.map typbind ts,s) end
      | DDatatypeRepl (n,id,s) => DDatatypeRepl (n,id,note ("DDatatypeRepl",s,n :: lid id))
      | DAbstype (dbs,tbs,ds,s) => let val s=note ("DAbstype",s,[count dbs,count tbs,count ds])
          in DAbstype (List.map datbind dbs,List.map typbind tbs,List.map dec ds,s) end
      | DException (bs,s) => let val s=note ("DException",s,[count bs]) in DException (List.map exbind bs,s) end
      | DLocal (a,b,s) => let val s=note ("DLocal",s,[count a,count b]) in DLocal (List.map dec a,List.map dec b,s) end
      | DOpen (ids,s) => DOpen (ids,note ("DOpen",s,List.concat (List.map lid ids)))
      | DInfix (p,ns,s) => DInfix (p,ns,note ("DInfix",s,Int.toString p :: ns))
      | DInfixr (p,ns,s) => DInfixr (p,ns,note ("DInfixr",s,Int.toString p :: ns))
      | DNonfix (ns,s) => DNonfix (ns,note ("DNonfix",s,ns))
      | DOverload {kind,strid,literal,span} => DOverload {kind=kind,strid=strid,literal=literal,
          span=note ("DOverload",span,kind :: count strid :: strid @
            (case literal of OvBits n => ["bits",Int.toString n] | OvVia id => "via" :: lid id))}
      | DStructure (bs,s) => let val s=note ("DStructure",s,[count bs]) in DStructure (List.map strbind bs,s) end
      | DSignature (bs,s) => let val s=note ("DSignature",s,[count bs]) in DSignature (List.map sigbind bs,s) end
      | DFunctor (bs,s) => let val s=note ("DFunctor",s,[count bs]) in DFunctor (List.map funbind bs,s) end
      and fundef ({name,clauses,span,...}:Ast.fundef) =
        {name=name,clauses=List.map clause clauses,info=ref NONE,span=note ("fundef",span,[name,count clauses])}
      and clause ({pats,resty,body}:Ast.clause) =
        let val _=note ("clause",Source.noSpan,[count pats,Bool.toString (isSome resty)])
        in {pats=List.map pat pats,resty=optional ty resty,body=exp body} end
      and typbind ({tyvars,name,ty=t,span}:Ast.typbind) =
        let val span=note ("typbind",span,name :: tyvars) in {tyvars=tyvars,name=name,ty=ty t,span=span} end
      and datbind ({tyvars,name,cons,span}:Ast.datbind) =
        let val span=note ("datbind",span,name :: count cons :: tyvars)
            fun con (n,t,s)=let val s=note ("constructor",s,[n,Bool.toString (isSome t)]) in (n,optional ty t,s) end
        in {tyvars=tyvars,name=name,cons=List.map con cons,span=span} end
      and exbind b = case b of
        ExnDecl (n,t,_,s) => let val s=note ("ExnDecl",s,[n,Bool.toString (isSome t)]) in ExnDecl (n,optional ty t,ref NONE,s) end
      | ExnRepl (n,id,_,s) => ExnRepl (n,id,ref NONE,note ("ExnRepl",s,n :: lid id))
      and strbind ({name,strexp,span}:Ast.strbind) =
        let val span=note ("strbind",span,[name]) in {name=name,strexp=str strexp,span=span} end
      and sigbind ({name,sigexp,span}:Ast.sigbind) =
        let val span=note ("sigbind",span,[name]) in {name=name,sigexp=sg sigexp,span=span} end
      and funbind ({name,param,paramSig,body,span}:Ast.funbind) =
        let val span=note ("funbind",span,name :: option (fn n => [n]) param)
        in {name=name,param=param,paramSig=sg paramSig,body=str body,span=span} end
      and str e = case e of
        StrStruct (ds,s) => let val s=note ("StrStruct",s,[count ds]) in StrStruct (List.map dec ds,s) end
      | StrId (id,s) => StrId (id,note ("StrId",s,lid id))
      | StrAscribe (e,g,opaque,s) => let val s=note ("StrAscribe",s,[Bool.toString opaque]) in StrAscribe (str e,sg g,opaque,s) end
      | StrApp (n,e,_,s) => let val s=note ("StrApp",s,[n]) in StrApp (n,str e,ref NONE,s) end
      | StrLet (ds,e,s) => let val s=note ("StrLet",s,[count ds]) in StrLet (List.map dec ds,str e,s) end
      | StrDynamic (from,g,_,s) => let val s=note ("StrDynamic",s,case from of DynamicFile p => ["file",p] | DynamicVirtual n => ["virtual",n])
          in StrDynamic (from,sg g,ref NONE,s) end
      | StrExport (n,g,e,_,s) => let val s=note ("StrExport",s,[n]) in StrExport (n,sg g,str e,ref NONE,s) end
      and sg g = case g of
        SigSig (ss,s) => let val s=note ("SigSig",s,[count ss]) in SigSig (List.map spec ss,s) end
      | SigId (n,s) => SigId (n,note ("SigId",s,[n]))
      | SigWhere (g,cs,s) => let val s=note ("SigWhere",s,[count cs])
          fun constraint (vs,id,t,s)=let val s=note ("where",s,count vs :: vs @ lid id) in (vs,id,ty t,s) end
          in SigWhere (sg g,List.map constraint cs,s) end
      and spec s = case s of
        SpecVal (bs,s) => let val s=note ("SpecVal",s,[count bs])
          fun binding (n,t,s)=let val s=note ("valspec",s,[n]) in (n,ty t,s) end
          in SpecVal (List.map binding bs,s) end
      | SpecType (bs,s) => let val s=note ("SpecType",s,[count bs]) in SpecType (List.map typeSpec bs,s) end
      | SpecEqtype (bs,s) => let val s=note ("SpecEqtype",s,[count bs]) in SpecEqtype (List.map typeSpec bs,s) end
      | SpecDatatype (bs,s) => let val s=note ("SpecDatatype",s,[count bs]) in SpecDatatype (List.map datbind bs,s) end
      | SpecDatatypeRepl (n,id,s) => SpecDatatypeRepl (n,id,note ("SpecDatatypeRepl",s,n :: lid id))
      | SpecException (bs,s) => let val s=note ("SpecException",s,[count bs])
          fun binding (n,t,s)=let val s=note ("exnspec",s,[n,Bool.toString (isSome t)]) in (n,optional ty t,s) end
          in SpecException (List.map binding bs,s) end
      | SpecStructure (bs,s) => let val s=note ("SpecStructure",s,[count bs])
          fun binding (n,g,s)=let val s=note ("strspec",s,[n]) in (n,sg g,s) end
          in SpecStructure (List.map binding bs,s) end
      | SpecInclude (g,s) => let val s=note ("SpecInclude",s,[]) in SpecInclude (sg g,s) end
      | SpecSharingType (ids,s) => SpecSharingType (ids,note ("SpecSharingType",s,List.concat (List.map lid ids)))
      | SpecSharing (ids,s) => SpecSharing (ids,note ("SpecSharing",s,List.concat (List.map lid ids)))
      and typeSpec (vs,n,s)=(vs,n,note ("typespec",s,n :: vs))
    in List.map dec program end
  fun copy (program,offset)=transform {offset=offset,observe=fn _ => ()} program
  fun shape program =
    let val events=ref [] : event list ref
        val _=transform {offset=0,observe=fn event => events:=event :: !events} program
    in List.rev (!events) end
end
