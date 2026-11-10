(* Implements: HS_EVIDENCE *)
structure HsEvidence :> HS_EVIDENCE =
struct
  structure T = HsTypes
  structure M = HsStringMap

  datatype dict =
      DParam of string
    | DInst of {inst : string, tys : T.ty list, args : dict list}
    | DSuper of {dict : dict, cls : string, super : string}

  type scheme = {vars : string list, ctx : T.pred list, ty : T.ty}

  datatype record =
      Use of {tys : T.ty list, dicts : dict list}
    | Overloaded of {ty : T.ty, dicts : (string * dict) list}
    | Binding of {scheme : scheme, params : string list}
    | Mono of T.ty
    | Instance of {inst : string, vars : string list, params : string list, supers : dict list}
    | Class of {param : string}
    | Defaulted of {var : string, preds : T.pred list, candidates : T.ty list, module_ : string, choice : T.ty}

  fun node (kind, {file, start, stop} : HsSource.span) =
    kind ^ "@" ^ file ^ ":" ^ Int.toString start ^ "-" ^ Int.toString stop

  type table = record list M.map ref

  fun empty () = ref M.empty
  fun add (t, k, r) = t := M.insert (!t, k, getOpt (M.find (!t, k), []) @ [r])
  fun find (t, k) = getOpt (M.find (!t, k), [])
  fun all t = M.listItems (!t)

  fun showDict d =
    case d of
      DParam p => p
    | DInst {inst, tys, args} =>
        "(" ^ HsClasses.showInstance inst ^ String.concat (List.map (fn t => " @(" ^ T.show t ^ ")") tys) ^
        String.concat (List.map (fn a => " " ^ showDict a) args) ^ ")"
    | DSuper {dict, cls, super} => "(" ^ T.nameOfKey super ^ " of " ^ T.nameOfKey cls ^ " " ^ showDict dict ^ ")"

  fun showScheme ({vars, ctx, ty} : scheme) =
    (if null vars then "" else "forall " ^ String.concatWith " " vars ^ ". ") ^
    (case ctx of [] => "" | _ => "(" ^ String.concatWith ", " (List.map T.showPred ctx) ^ ") => ") ^ T.show ty

  fun showRecord r =
    case r of
      Use {tys, dicts} =>
        "use" ^ String.concat (List.map (fn t => " @(" ^ T.show t ^ ")") tys) ^ String.concat (List.map (fn d => " " ^ showDict d) dicts)
    | Overloaded {ty, dicts} =>
        "overloaded at " ^ T.show ty ^ String.concat (List.map (fn (c, d) => " " ^ T.nameOfKey c ^ "=" ^ showDict d) dicts)
    | Binding {scheme, params} => "binding " ^ showScheme scheme ^ (if null params then "" else " params " ^ String.concatWith " " params)
    | Mono t => "mono " ^ T.show t
    | Instance {inst, vars, params, supers} =>
        "instance " ^ HsClasses.showInstance inst ^ " vars " ^ String.concatWith " " vars ^ " params " ^ String.concatWith " " params ^
        " supers" ^ String.concat (List.map (fn d => " " ^ showDict d) supers)
    | Class {param} => "class param " ^ param
    | Defaulted {var, preds, candidates, module_, choice} =>
        "defaulted " ^ var ^ " (" ^ String.concatWith ", " (List.map T.showPred preds) ^ ") from " ^ module_ ^ " [" ^
        String.concatWith ", " (List.map T.show candidates) ^ "] to " ^ T.show choice
end
