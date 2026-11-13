(* Implements: HS_LINT *)
structure HsLint :> HS_LINT =
struct
  structure T = HsLintTypes

  type module = {id : string, ast : HsAst.module, library : bool}
  type binding = {module : string, name : string, scheme : string, signed : bool, restricted : bool,
                  span : HsSource.span}
  type default = {module : string, span : HsSource.span, preds : string, choice : string, ruleTwo : bool}
  type class_ = {name : string, numeric : bool, standard : bool}
  type kind = {module : string, name : string, kind : string}
  type derived = {module : string, instance : string}
  type report = {bindings : binding list, defaults : default list, kinds : kind list, derived : derived list,
                 classes : class_ list}
  type claims = HsLintClaims.claims
  type target = HsLintTarget.target

  exception Refused of HsSource.span * string

  (* what the inference kept, let go once it is done *)
  fun clear () = (HsLintInfer.reset (); HsLintEnv.reset (); T.names := [])

  fun zonkScheme (T.Forall (ks, (ps, t))) = T.Forall (ks, (List.map T.zonkPred ps, T.zonk t))

  (* the inference of a library's modules, as a saved world keeps it for
     its programs (D45): the modules', their environment and what their
     inference found *)
  type library = HsLintCodec.part

  (* the second inference, its state kept for the report and replay: from
     nothing, or after `library`, whose groups of modules it does not infer
     again; the groups it inferred *)
  fun run {groups : module list list, main, cycleDefault, derived, library} : module list list =
    let
      fun infer gs =
        List.app (fn g => HsLintInfer.modules {group = g, main = main, cycleDefault = cycleDefault, derived = derived}) gs
    in
      case library of
        NONE =>
          (T.counter := 0;
           T.names := [];
           HsLintInfer.reset ();
           HsLintEnv.build (List.concat groups);
           infer groups;
           groups)
      | SOME ({modules = known, env, infer = inferred, counter, ...} : library) =>
          let
            fun kept g = List.all (fn {id, ...} : module => List.exists (fn k => k = id) known) g
            val rest = List.filter (not o kept) groups
          in
            T.counter := counter;
            T.names := [];
            HsLintEnv.restore env;
            HsLintInfer.restore inferred;
            HsLintEnv.more (List.concat rest);
            infer rest;
            rest
          end
    end

  (* what the inference found, while its state is kept, of the modules
     `mine` holds *)
  fun report (mine : string -> bool) : report =
    let
      val bindings =
        List.mapPartial (fn {module, id, scheme, signed, restricted, span} =>
                           if not (mine module) then NONE
                           else SOME {module = module, name = #name id, scheme = T.showScheme (zonkScheme scheme),
                                      signed = signed, restricted = restricted, span = span})
          (!HsLintInfer.bindings)
      val defaults =
        List.mapPartial (fn {module, span, preds, choice, ruleTwo} =>
                           if not (mine module) then NONE
                           else SOME {module = module, span = span,
                                      preds = String.concatWith ", " (T.sortStrings (List.map (T.showPred o T.zonkPred) preds)),
                                      choice = T.showTy (T.zonk choice), ruleTwo = ruleTwo})
          (!HsLintInfer.chosen)
      (* an entity's identity from its key, `QUAL NAME` *)
      fun ofKey k =
        case CharVector.findi (fn (_, c) => c = #" ") k of
          SOME (i, _) => {qual = String.substring (k, 0, i), name = String.extract (k, i + 1, NONE)}
        | NONE => {qual = "", name = k}
      val kinds =
        HsStringMap.foldl
          (fn (k, d, acc) =>
             if not (mine (#qual (ofKey k))) then acc
             else
               let val kind = case d of HsLintEnv.Data {kind, ...} => kind | HsLintEnv.Synonym {kind, ...} => kind
               in {module = #qual (ofKey k), name = #name (ofKey k), kind = T.showKind kind} :: acc end)
          [] (!HsLintEnv.tydefs)
        @ HsStringMap.foldl (fn (_, {id, kind, ...} : HsLintClasses.class, acc) =>
                               if not (mine (#qual id)) then acc
                               else {module = #qual id, name = #name id, kind = T.showKind kind} :: acc)
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
                          if qual = "" orelse not (mine qual) then NONE
                          else SOME {module = qual, instance = instanceText (c, h, context)}
                      | _ => NONE)
                 | _ => NONE)
               is @ acc)
          [] (!HsLintClasses.insts)
      val classes =
        HsStringMap.foldl (fn (_, {id, std, ...} : HsLintClasses.class, acc) =>
                             {name = #name id, numeric = HsLintClasses.isNumeric id, standard = std} :: acc)
          [] (!HsLintClasses.classes)
    in
      {bindings = bindings, defaults = defaults, kinds = List.rev kinds, derived = List.rev derived,
       classes = List.rev classes}
    end

  fun infer {groups, main, cycleDefault} : report =
    (ignore (run {groups = groups, main = main, cycleDefault = cycleDefault, derived = [], library = NONE});
     report (fn _ => true) before clear ())
    handle T.Refuse (span, msg) => (clear (); raise Refused (span, msg))
         | e => (clear (); raise e)

  val claims = HsLintClaims.read
  val rules = HsLintClaims.rules

  fun library m = String.isPrefix "haskell98:" m

  fun compare ({bindings, defaults, kinds, derived, classes} : report, claims, where_, fault) =
    HsLintClaims.compare
      {kinds = List.filter (fn {module, ...} => not (library module)) kinds,
       derived = List.filter (fn {module, ...} => not (library module)) derived,
       bindings = List.mapPartial (fn {module, name, scheme, signed, restricted, span} =>
                                     if library module then NONE
                                     else SOME {module = module, name = name, scheme = scheme, signed = signed,
                                                restricted = restricted, span = span})
                    bindings,
       defaults = List.mapPartial (fn {module, span, preds, choice, ruleTwo} =>
                                     if library module then NONE
                                     else SOME {module = module, place = where_ span, preds = preds, choice = choice,
                                                ruleTwo = ruleTwo, span = span})
                    defaults,
       classes = fn n =>
                   case List.filter (fn (c : class_) => #name c = n) classes of
                     [] => NONE
                   | cs => SOME {numeric = List.exists #numeric cs, standard = List.all #standard cs},
       fault = fault}
      claims
    handle T.Refuse (span, msg) => raise Refused (span, msg)

  val replayRules = HsLintReplay.rules

  (* `check {groups, main, cycleDefault, records, claims, where_, fault,
     library}`: the second inference, after `library`'s where it is given,
     then replay of the checker's records of the modules it inferred and
     those records held to the inference as claims, then the claims given;
     what the target check reads, kept; and, where every module is the
     library's, the inference of them for a saved world *)
  fun check {groups : module list list, main, cycleDefault, records, claims, where_, fault, library}
            : {report : report, target : target, part : library} =
    let
      val derived = case records of SOME {derived, ...} => derived | NONE => []
      val inferred = run {groups = groups, main = main, cycleDefault = cycleDefault, derived = derived, library = library}
      val modules = List.concat inferred
      fun mine m = List.exists (fn {id, ...} : module => id = m) modules
      val files = List.map (fn {ast = HsAst.Module ({span, ...}, _), ...} : module => #file span) modules
      (* what the target check reads: of the modules inferred, after a
         library's where it was given *)
      val t =
        HsLintTarget.collect
          {bindings = List.mapPartial (fn {id, scheme, module, ...} => if mine module then SOME {id = id, scheme = scheme}
                                                                      else NONE)
                        (!HsLintInfer.bindings),
           classes = fn {id = {qual, ...}, ...} : HsLintClasses.class => mine qual,
           insts = fn {span = {file, ...}, ...} : HsLintClasses.inst =>
                     if file = "" then not (isSome library) else List.exists (fn f => f = file) files}
      (* what this check inferred alone, a unit's part (D45) *)
      val ids = List.map (fn {id, ...} : module => id) modules
      val part = {modules = ids, env = HsLintEnv.part (ids, files, not (isSome library)),
                  infer = HsLintInfer.part ids, counter = !T.counter, target = t}
      val t = case library of SOME l => HsLintTarget.join (#target l, t) | NONE => t
      val r = report mine
      val () =
        case records of
          SOME {table, env, derived} =>
            (HsLintReplay.replay {modules = modules, groups = inferred, records = table, env = env, derived = derived,
                                  cycleDefault = cycleDefault, fault = fault}
             handle T.Refuse (span, msg) => raise Refused (span, msg);
             compare (r, HsLintReplay.claimsOf {modules = modules, records = table, derived = derived}, where_, fault))
        | NONE => ()
      val () = case claims of SOME c => compare (r, c, where_, fault) | NONE => ()
    in
      clear (); {report = r, target = t, part = part}
    end
    handle T.Refuse (span, msg) => (clear (); raise Refused (span, msg))
         | e => (clear (); raise e)

  val targetRules = HsLintTarget.rules

  (* parts put together, in order: a saved world's or the units' before a
     unit *)
  fun join (parts : library list) : library =
    {modules = List.concat (List.map #modules parts), env = HsLintEnv.join (List.map #env parts),
     infer = HsLintInfer.join (List.map #infer parts),
     counter = List.foldl (fn (p, n) => Int.max (#counter p, n)) 0 parts,
     target = List.foldl (fn (p, t) => HsLintTarget.join (t, #target p)) {values = [], classes = [], dfuns = []} parts}

  exception Decode of string
  val encode = HsLintCodec.encode
  fun decode s = HsLintCodec.decode s handle HsLintCodec.Bad msg => raise Decode msg

  fun target (t, p, fault) =
    HsLintTarget.check (t, p, fault)
    handle T.Refuse (span, msg) => raise Refused (span, msg)

  (* lines in a canonical order, by their keys, so that only a change of
     what they say moves the dump, not one of the order the inference met
     the bindings in (a library's edit that moves a definition) *)
  fun sortBy (key : 'a -> string) (xs : 'a list) : 'a list =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if String.<= (key x, key y) then x :: merge (xs, y :: ys) else y :: merge (x :: xs, ys)
      fun go [] = []
        | go [x] = [x]
        | go xs = let val n = length xs div 2 in merge (go (List.take (xs, n)), go (List.drop (xs, n))) end
    in
      go xs
    end

  (* a place, `LINE:COLUMN`, as a key in its numbers' order *)
  fun placeKey p =
    String.concatWith ":" (List.map (fn f => StringCvt.padLeft #"0" 9 f) (String.fields (fn c => c = #":") p))

  fun dump ({bindings, defaults, kinds, derived, ...} : report, where_, library) =
    let
      fun shown m = library orelse not (String.isPrefix "haskell98:" m)
      fun lib m = String.isPrefix "haskell98:" m
      val ks =
        List.mapPartial (fn {module, name, kind} =>
                           if shown module andalso not (lib module)
                           then SOME (module ^ "\t" ^ name, "KIND\t" ^ module ^ "\t" ^ name ^ " :: " ^ kind ^ "\n")
                           else NONE)
          kinds
      val ds =
        List.mapPartial (fn {module, instance} =>
                           if shown module andalso not (lib module)
                           then SOME (module ^ "\t" ^ instance, "DERIVED\t" ^ module ^ "\t" ^ instance ^ "\n")
                           else NONE)
          derived
      val bs =
        List.mapPartial (fn {module, name, scheme, signed, ...} : binding =>
                           if not (shown module) orelse lib module andalso signed then NONE
                           else SOME (module ^ "\t" ^ name,
                                      (if signed then "SIGNED\t" else "TYPE\t") ^ module ^ "\t" ^ name ^ " :: " ^ scheme ^ "\n"))
          bindings
      (* a default of the library's at no place: its line moves with any
         edit of the library above it *)
      val fs =
        List.mapPartial (fn {module, span, preds, choice, ...} : default =>
                           if not (shown module) then NONE
                           else
                             let val place = if lib module then "*" else where_ span
                             in SOME (module ^ "\t" ^ placeKey place ^ "\t" ^ preds ^ "\t" ^ choice,
                                      "DEFAULT\t" ^ module ^ "\t" ^ place ^ "\t" ^ preds ^ " -> " ^ choice ^ "\n")
                             end)
          defaults
      fun sorted xs = List.map #2 (sortBy #1 xs)
    in
      String.concat (sorted ks @ sorted ds @ sorted bs @ sorted fs)
    end
end
