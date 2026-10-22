(* Typed occurrences are collected inside an owner, then frozen before its
   unit basis is replaced. No elaboration slot is published. *)
structure CompilerFacts =
struct
  open Ast
  fun infoType info =
    case info of VLocal (_,t) => t | VGlobal (_,t) => t | VCon (_,t) => t
    | VExn (_,t) => t | VBuiltin (_,t) => t | VConVal (_,t) => t | VExnVal (_,t) => t
  fun collect decs =
    let
      val matches=ref [] : (Source.span * Types.ty * bool) list ref
      val derived=ref false
      fun add (span : Source.span,ty) =
        Option.app (fn t => matches:=(span,t,!derived) :: !matches) ty
      fun pat p =
        (case p of
           PVar (_,slot,span) => (case !slot of SOME (PIVar (stamp,_)) => add (span,IntTable.find (Ty.binders,stamp)) | _ => ())
         | PScon (_,slot,span) => add (span,!slot)
         | PRecord (fields,_,slot,span) => (add (span,!slot);List.app (pat o #2) fields)
         | PTuple (ps,_) => List.app pat ps | PList (ps,_) => List.app pat ps
         | PApp (_,_,p,_) => pat p | PTyped (p,_,_) => pat p
         | PLayered (_,_,p,slot,span) =>
             ((case !slot of SOME (PIVar (stamp,_)) => add (span,IntTable.find (Ty.binders,stamp)) | _ => ());pat p)
         | POr (ps,_) => List.app pat ps | _ => ())
      fun rule (p,e) = (pat p;exp e)
      and exp e =
        case e of
          EScon (_,slot,span) => add (span,!slot)
        | EVar (_,slot,span) => add (span,Option.map infoType (!slot))
        | ERecord (fields,_) => List.app (exp o #2) fields
        | ETuple (es,_) => List.app exp es
        | EList (es,slot,span) => (add (span,!slot);List.app exp es)
        | ESeq (es,_) => List.app exp es
        | ELet (ds,e,_) => (List.app dec ds;exp e)
        | EApp (a,b,_) => (exp a;exp b)
        | ETyped (e,_,_) => exp e
        | EAndalso (a,b,_) => (exp a;exp b) | EOrelse (a,b,_) => (exp a;exp b)
        | EHandle (e,rs,_) => (exp e;List.app rule rs)
        | ERaise (e,_) => exp e | EIf (a,b,c,_) => (exp a;exp b;exp c)
        | EWhile (a,b,_) => (exp a;exp b)
        | ECase (e,rs,_) => (exp e;List.app rule rs)
        | EFn (rs,slot,span) => (add (span,!slot);List.app rule rs)
        | EPrim (_,_,slot,span) => add (span,!slot)
        | _ => ()
      and dec d =
        case d of
          DVal (_,bs,_) => List.app rule bs | DValRec (_,bs,_) => List.app rule bs
        | DFun (_,fs,_) => List.app (fn f =>
            ((case !(#info f) of SOME (PIVar (stamp,_)) => add (#span f,IntTable.find (Ty.binders,stamp)) | _ => ());
             List.app (fn {pats,body,...} => (List.app pat pats;exp body)) (#clauses f))) fs
        | DLocal (a,b,_) => List.app dec (a@b) | DAbstype (_,_,ds,_) => List.app dec ds
        | DStructure (bs,_) => List.app (str o #strexp) bs
        | DFunctor (bs,_) => List.app (str o #body) bs | _ => ()
      and str e =
        case e of
          StrStruct (ds,_) => List.app dec ds | StrAscribe (e,_,_,_) => str e
        | StrApp (_,arg,body,_) => (str arg;Option.app (fn body =>
            let val before'= !derived in derived:=true;str body;derived:=before' end) (!body))
        | StrLet (ds,e,_) => (List.app dec ds;str e) | StrExport (_,_,e,_,_) => str e | _ => ()
      val ()=List.app dec decs
    in List.rev (!matches) end
end
