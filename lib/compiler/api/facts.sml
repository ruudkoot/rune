(* Typed occurrences are collected inside an owner, then frozen before its
   unit basis is replaced. No elaboration slot is published. *)
structure CompilerFacts =
struct
  open Ast
  fun infoType info =
    case info of VLocal (_,t) => t | VGlobal (_,t) => t | VCon (_,t) => t
    | VExn (_,t) => t | VBuiltin (_,t) => t | VConVal (_,t) => t | VExnVal (_,t) => t
  fun collectWith record decs =
    let
      val matches=ref [] : (Source.span * Types.ty * bool) list ref
      (* the flag is whether an occurrence is derived, of an elaborated
         copy of a functor's body: none since functors are compiled once *)
      fun add (span : Source.span,ty) =
        Option.app (fn t => matches:=(span,t,false) :: !matches) ty
      fun pat p =
        (case p of
           PVar (_,slot,span, _) => (case !slot of SOME (PIVar (stamp,_)) => add (span,IntTable.find (Ty.binders,stamp)) | _ => ())
         | PScon (_,slot,span, _) => add (span,!slot)
         | PRecord (fields,_,slot,span, _) => (add (span,!slot);record (span,!slot);List.app (pat o #2) fields)
         | PTuple (ps,_, _) => List.app pat ps | PList (ps,_, _) => List.app pat ps
         | PApp (_,_,p,_, _) => pat p | PTyped (p,_,_, _) => pat p
         | PLayered (_,_,p,slot,span, _) =>
             ((case !slot of SOME (PIVar (stamp,_)) => add (span,IntTable.find (Ty.binders,stamp)) | _ => ());pat p)
         | POr (ps,_, _) => List.app pat ps | _ => ())
      fun rule (p,e) = (pat p;exp e)
      and typeOf e=case e of EVar (_,slot,_, _) => Option.map infoType (!slot)
        | ETyped (e,_,_, _) => typeOf e | _ => NONE
      and exp e =
        case e of
          EScon (_,slot,span, _) => add (span,!slot)
        | EVar (_,slot,span, _) => add (span,Option.map infoType (!slot))
        | ERecord (fields,_, _) => List.app (exp o #2) fields
        | ETuple (es,_, _) => List.app exp es
        | EList (es,slot,span, _) => (add (span,!slot);List.app exp es)
        | ESeq (es,_, _) => List.app exp es
        | ELet (ds,e,_, _) => (List.app dec ds;exp e)
        | ESelect (_,slot,span, _) => record (span,!slot)
        | EApp (a,b,_, _) => ((case a of ESelect (_,_,span, _) => record (span,typeOf b) | _ => ());exp a;exp b)
        | ETyped (e,_,_, _) => exp e
        | EAndalso (a,b,_, _) => (exp a;exp b) | EOrelse (a,b,_, _) => (exp a;exp b)
        | EHandle (e,rs,_, _) => (exp e;List.app rule rs)
        | ERaise (e,_, _) => exp e | EIf (a,b,c,_, _) => (exp a;exp b;exp c)
        | EWhile (a,b,_, _) => (exp a;exp b)
        | ECase (e,rs,_, _) => (exp e;List.app rule rs)
        | EFn (rs,slot,span, _) => (add (span,!slot);List.app rule rs)
        | EPrim (_,_,slot,span, _) => add (span,!slot)
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
    in List.rev (!matches) end
  fun collect decs=collectWith (fn _ => ()) decs
  fun recordAt (decs,file,offset) =
    let val found=ref NONE : (int*Types.ty) option ref
        fun observe (span:Source.span,ty)=case ty of NONE => () | SOME ty =>
          if #file span<>file orelse offset< #start span orelse offset> #stop span then () else
            case Types.prune ty of Types.TRecord _ =>
              let val width= #stop span- #start span
              in case !found of SOME (old,_) => if old<=width then () else found:=SOME (width,ty)
               | NONE => found:=SOME (width,ty) end
            | _ => ()
        val _=collectWith observe decs
    in Option.map #2 (!found) end
end
