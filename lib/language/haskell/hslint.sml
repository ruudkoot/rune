(* Implements: HS_LINT *)
structure HsLint :> HS_LINT =
struct
  structure T = HsLintTypes

  type module = {id : string, ast : HsAst.module, library : bool}
  type binding = {module : string, name : string, scheme : string, signed : bool, span : HsSource.span}
  type default = {module : string, span : HsSource.span, preds : string, choice : string}
  type kind = {module : string, name : string, kind : string}
  type derived = {module : string, instance : string}
  type report = {bindings : binding list, defaults : default list, kinds : kind list, derived : derived list}

  exception Refused of HsSource.span * string

  (* what the inference kept, let go once it is done *)
  fun clear () = (HsLintInfer.reset (); HsLintEnv.reset (); T.names := [])

  fun zonkScheme (T.Forall (ks, (ps, t))) = T.Forall (ks, (List.map T.zonkPred ps, T.zonk t))

  fun infer {groups : module list list, main, cycleDefault} : report =
    let
      val () = (T.counter := 0; T.names := [])
      val () = HsLintInfer.reset ()
      val () = HsLintEnv.build (List.concat groups)
      val () = List.app (fn g => HsLintInfer.modules {group = g, main = main, cycleDefault = cycleDefault}) groups
      val bindings =
        List.map (fn {module, id, scheme, signed, span} =>
                    {module = module, name = #name id, scheme = T.showScheme (zonkScheme scheme), signed = signed,
                     span = span})
          (!HsLintInfer.bindings)
      val defaults =
        List.map (fn {module, span, preds, choice} =>
                    {module = module, span = span,
                     preds = String.concatWith ", " (T.sortStrings (List.map (T.showPred o T.zonkPred) preds)),
                     choice = T.showTy (T.zonk choice)})
          (!HsLintInfer.chosen)
      (* an entity's identity from its key, `QUAL NAME` *)
      fun ofKey k =
        case CharVector.findi (fn (_, c) => c = #" ") k of
          SOME (i, _) => {qual = String.substring (k, 0, i), name = String.extract (k, i + 1, NONE)}
        | NONE => {qual = "", name = k}
      val kinds =
        HsStringMap.foldl
          (fn (k, HsLintEnv.Data {kind, ...}, acc) => {module = #qual (ofKey k), name = #name (ofKey k), kind = T.showKind kind} :: acc
            | (k, HsLintEnv.Synonym {kind, ...}, acc) => {module = #qual (ofKey k), name = #name (ofKey k), kind = T.showKind kind} :: acc)
          [] (!HsLintEnv.tydefs)
        @ HsStringMap.foldl (fn (_, {id, kind, ...} : HsLintClasses.class, acc) =>
                               {module = #qual id, name = #name id, kind = T.showKind kind} :: acc)
            [] (!HsLintClasses.classes)
      fun instanceText (c, h, context) =
        (case T.sortStrings (List.map T.showPred context) of
           [] => ""
         | [p] => p ^ " => "
         | ps => "(" ^ String.concatWith ", " ps ^ ") => ")
        ^ T.showPred (T.IsIn (c, h))
      val derived =
        HsStringMap.foldl
          (fn (_, is, acc) =>
             List.mapPartial
               (fn {head = T.IsIn (c, h), context, derived = true, ...} : HsLintClasses.inst =>
                     (case T.spine h of
                        (T.TCon {id = {qual, ...}, ...}, _) =>
                          if qual = "" then NONE else SOME {module = qual, instance = instanceText (c, h, context)}
                      | _ => NONE)
                 | _ => NONE)
               is @ acc)
          [] (!HsLintClasses.insts)
    in
      clear ();
      {bindings = bindings, defaults = defaults, kinds = List.rev kinds, derived = List.rev derived}
    end
    handle T.Refuse (span, msg) => (clear (); raise Refused (span, msg))
         | e => (clear (); raise e)

  fun dump ({bindings, defaults, kinds, derived} : report, where_, library) =
    let
      fun shown m = library orelse not (String.isPrefix "haskell98:" m)
      fun lib m = String.isPrefix "haskell98:" m
      val ks =
        List.mapPartial (fn {module, name, kind} =>
                           if shown module andalso not (lib module) then SOME ("KIND\t" ^ module ^ "\t" ^ name ^ " :: " ^ kind ^ "\n")
                           else NONE)
          kinds
      val ds =
        List.mapPartial (fn {module, instance} =>
                           if shown module andalso not (lib module) then SOME ("DERIVED\t" ^ module ^ "\t" ^ instance ^ "\n")
                           else NONE)
          derived
      val bs =
        List.mapPartial (fn {module, name, scheme, signed, ...} =>
                           if not (shown module) orelse lib module andalso signed then NONE
                           else SOME ((if signed then "SIGNED\t" else "TYPE\t") ^ module ^ "\t" ^ name ^ " :: " ^ scheme ^ "\n"))
          bindings
      val fs =
        List.mapPartial (fn {module, span, preds, choice} =>
                           if not (shown module) then NONE
                           else SOME ("DEFAULT\t" ^ module ^ "\t" ^ where_ span ^ "\t" ^ preds ^ " -> " ^ choice ^ "\n"))
          defaults
    in
      String.concat (ks @ ds @ bs @ fs)
    end
end
