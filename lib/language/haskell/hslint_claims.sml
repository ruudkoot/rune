(* HsLint's comparison (the haskell98 roadmap's M16, D54): what the second
   inference found held against what a record claims of the same program,
   each difference refused by the rule it breaks, its message starting with
   the rule's name in brackets, as CoreLint's do: `[rule1] ...`.

   A claim is what the dump of `rhc --dump-hslint` prints, a line each: a
   kind, a derived instance with its context, a binding's type, a default
   with its place, predicates and type. The checker's evidence records
   (M13) are to be read as claims of that form; until they are, a claim is
   written by hand, and the faults below are how the rules are held to
   their work. A type is compared as a scheme, its variables renamed in the
   order they first appear and its predicates sorted, so that two texts of
   one type are one.

   RHC_HSLINT_FAULT=RULE reads the first claim that RULE checks corrupted,
   so that RULE, and no other, refuses it (as AstLint's faults do, the
   linting roadmap's M12). *)
structure HsLintClaims =
struct
  structure T = HsLintTypes

  (* ---- types as text, read back ---- *)

  datatype ty = V of string | C of string | A of ty * ty

  exception Bad of string

  fun isIdent c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'" orelse c = #"." orelse c = #"#"

  fun tokens s =
    let
      val n = size s
      fun go (i, acc) =
        if i >= n then List.rev acc
        else
          let val c = String.sub (s, i)
          in
            if Char.isSpace c then go (i + 1, acc)
            else if c = #"-" andalso i + 1 < n andalso String.sub (s, i + 1) = #">" then go (i + 2, "->" :: acc)
            else if c = #"=" andalso i + 1 < n andalso String.sub (s, i + 1) = #">" then go (i + 2, "=>" :: acc)
            else if Char.contains "()[]," c then go (i + 1, str c :: acc)
            else if isIdent c then
              let
                fun stop j = if j < n andalso isIdent (String.sub (s, j)) then stop (j + 1) else j
                val j = stop i
              in
                go (j, String.substring (s, i, j - i) :: acc)
              end
            else raise Bad ("a character the text of a type does not hold: " ^ str c)
          end
    in
      go (0, [])
    end

  fun isVar w = size w > 0 andalso Char.isLower (String.sub (w, 0))

  (* type := btype [-> type]; btype := atype atype*; atype := name | ( ... ) | [ ... ] *)
  fun parseType ts =
    let
      val (b, rest) = btype ts
    in
      case rest of
        "->" :: more => let val (r, rest') = parseType more in (A (A (C "(->)", b), r), rest') end
      | _ => (b, rest)
    end
  and btype ts =
    let
      val (h, rest) = atype ts
      fun more (f, ts) =
        case ts of
          w :: _ => if w = "(" orelse w = "[" orelse (w <> "->" andalso w <> "=>" andalso w <> ")" andalso w <> "]"
                                                    andalso w <> ",")
                    then let val (a, rest) = atype ts in more (A (f, a), rest) end
                    else (f, ts)
        | [] => (f, ts)
    in
      more (h, rest)
    end
  and atype ts =
    case ts of
      "(" :: ")" :: rest => (C "()", rest)
    | "(" :: "->" :: ")" :: rest => (C "(->)", rest)
    | "(" :: "," :: rest =>
        let
          fun commas (k, "," :: r) = commas (k + 1, r)
            | commas (k, ")" :: r) = (C ("(" ^ CharVector.tabulate (k, fn _ => #",") ^ ")"), r)
            | commas _ = raise Bad "a tuple's constructor"
        in
          commas (1, rest)
        end
    | "(" :: rest =>
        let
          fun items (acc, ts) =
            let val (t, rest) = parseType ts
            in
              case rest of
                "," :: more => items (t :: acc, more)
              | ")" :: more => (List.rev (t :: acc), more)
              | _ => raise Bad "a parenthesis not closed"
            end
          val (ts', rest') = items ([], rest)
        in
          case ts' of
            [t] => (t, rest')
          | _ => (List.foldl (fn (t, f) => A (f, t)) (C ("(" ^ CharVector.tabulate (length ts' - 1, fn _ => #",") ^ ")")) ts',
                  rest')
        end
    | "[" :: "]" :: rest => (C "[]", rest)
    | "[" :: rest =>
        (case parseType rest of
           (t, "]" :: more) => (A (C "[]", t), more)
         | _ => raise Bad "a bracket not closed")
    | w :: rest => if w = "->" orelse w = "=>" orelse w = ")" orelse w = "]" orelse w = "," then raise Bad ("`" ^ w ^ "`")
                   else ((if isVar w then V w else C w), rest)
    | [] => raise Bad "a type that ends early"

  (* `ctx => type` or `type` *)
  fun parseScheme s : ty list * ty =
    let
      val ts = tokens s
      fun split (acc, []) = NONE
        | split (acc, "=>" :: rest) = SOME (List.rev acc, rest)
        | split (acc, w :: rest) = split (w :: acc, rest)
      fun context ts =
        case ts of
          "(" :: rest =>
            let
              fun preds (acc, ts) =
                let val (p, rest) = btype ts
                in
                  case rest of
                    "," :: more => preds (p :: acc, more)
                  | [")"] => List.rev (p :: acc)
                  | _ => raise Bad "a context not closed"
                end
            in
              preds ([], rest)
            end
        | _ => (case btype ts of (p, []) => [p] | _ => raise Bad "a context of one predicate")
    in
      case split ([], ts) of
        SOME (c, t) => (context c, case parseType t of (ty, []) => ty | _ => raise Bad "text after a type")
      | NONE => ([], case parseType ts of (ty, []) => ty | _ => raise Bad "text after a type")
    end

  fun spine t = let fun go (A (f, a), args) = go (f, a :: args) | go (h, args) = (h, args) in go (t, []) end

  fun show t =
    let
      fun paren (b, s) = if b then "(" ^ s ^ ")" else s
      fun go (p, t) =
        case spine t of
          (C "(->)", [a, b]) => paren (p > 0, go (1, a) ^ " -> " ^ go (0, b))
        | (C "[]", [a]) => "[" ^ go (0, a) ^ "]"
        | (C n, args as _ :: _) =>
            if String.isPrefix "(," n andalso length args = size n - 1 then
              "(" ^ String.concatWith ", " (List.map (fn a => go (0, a)) args) ^ ")"
            else paren (p > 1, String.concatWith " " (n :: List.map (fn a => go (2, a)) args))
        | (V v, []) => v
        | (C n, []) => n
        | (h, args) => paren (p > 1, String.concatWith " " (go (2, h) :: List.map (fn a => go (2, a)) args))
    in
      go (0, t)
    end

  (* the scheme's text in its canonical form: variables a, b, ... in the
     order they first appear in the type, then in the context; the
     predicates sorted *)
  fun canonical s =
    let
      val (ps, t) = parseScheme s
      val order = ref [] : string list ref
      fun see (V v) = if List.exists (fn w => w = v) (!order) then () else order := !order @ [v]
        | see (A (f, a)) = (see f; see a)
        | see (C _) = ()
      val () = (see t; List.app see ps)
      fun name v =
        let fun find (_, []) = v | find (i, w :: ws) = if w = v then T.genName i else find (i + 1, ws)
        in find (0, !order) end
      fun rename (V v) = V (name v)
        | rename (A (f, a)) = A (rename f, rename a)
        | rename c = c
      val qs = T.sortStrings (List.map (fn p => case spine (rename p) of
                                                 (C c, [a]) => c ^ " " ^ (case a of A _ => "(" ^ show a ^ ")" | _ => show a)
                                               | _ => show (rename p))
                                ps)
    in
      (case qs of [] => "" | [q] => q ^ " => " | _ => "(" ^ String.concatWith ", " qs ^ ") => ") ^ show (rename t)
    end
    handle Bad _ => s

  (* the classes a predicate's text names, and their predicates as text *)
  fun classesOf preds =
    List.mapPartial (fn p => case String.tokens Char.isSpace p of c :: _ => SOME c | [] => NONE)
      (String.tokens (fn c => c = #",") preds)

  fun canonicalPreds preds =
    String.concatWith ", " (T.sortStrings (List.map (fn p => String.concatWith " " (String.tokens Char.isSpace p))
                                              (String.tokens (fn c => c = #",") preds)))

  (* ---- claims ---- *)

  type kind = {module : string, name : string, kind : string}
  type derived = {module : string, instance : string}
  type binding = {module : string, name : string, scheme : string, signed : bool}
  type default = {module : string, place : string, preds : string, choice : string}
  type claims = {kinds : kind list, derived : derived list, bindings : binding list, defaults : default list}

  val none : claims = {kinds = [], derived = [], bindings = [], defaults = []}

  (* the claims of a dump's text; a line of another form is not one *)
  fun read (text : string) : claims =
    let
      fun fields l = String.fields (fn c => c = #"\t") l
      (* the text before and after the first `sep` *)
      fun around sep s =
        let
          val k = size sep
          fun go i = if i + k > size s then NONE else if String.substring (s, i, k) = sep then SOME i else go (i + 1)
        in
          case go 0 of SOME i => SOME (String.substring (s, 0, i), String.extract (s, i + k, NONE)) | NONE => NONE
        end
      val named = around " :: "
      val arrow = around " -> "
      fun one (l, c : claims) =
        case fields l of
          ["KIND", m, rest] =>
            (case named rest of
               SOME (n, k) => {kinds = #kinds c @ [{module = m, name = n, kind = k}], derived = #derived c,
                               bindings = #bindings c, defaults = #defaults c}
             | NONE => c)
        | ["DERIVED", m, inst] =>
            {kinds = #kinds c, derived = #derived c @ [{module = m, instance = inst}], bindings = #bindings c,
             defaults = #defaults c}
        | [tag, m, rest] =>
            if tag = "TYPE" orelse tag = "SIGNED" then
              case named rest of
                SOME (n, sc) => {kinds = #kinds c, derived = #derived c,
                                 bindings = #bindings c @ [{module = m, name = n, scheme = sc, signed = tag = "SIGNED"}],
                                 defaults = #defaults c}
              | NONE => c
            else c
        | ["DEFAULT", m, place, rest] =>
            (case arrow rest of
               SOME (ps, t) => {kinds = #kinds c, derived = #derived c, bindings = #bindings c,
                                defaults = #defaults c @ [{module = m, place = place, preds = ps, choice = t}]}
             | NONE => c)
        | _ => c
    in
      List.foldl one none (String.fields (fn c => c = #"\n") text)
    end

  (* ---- the rules ---- *)

  (* Each rule's name and what it holds. *)
  val rules =
    [("kind", "the kind of a type constructor or a class is the one inferred (4.6)"),
     ("derive", "a derived instance has the least context (4.3.3, 10.1)"),
     ("binding", "every binding of the top level has one claimed type, and nothing else has one"),
     ("rule1", "a binding of a restricted group is not overloaded (4.5.5, Rule 1)"),
     ("type", "a binding's type is the one inferred, its signature's where it has one"),
     ("numeric", "a default resolves an ambiguity with a numeric class (4.3.4, R22)"),
     ("standard", "a default resolves an ambiguity of the Prelude's and the standard libraries' classes (4.3.4, R22)"),
     ("rule2", "a monomorphic variable is defaulted where the module is inferred, as its uses fix it (4.5.5, Rule 2, R20)"),
     ("default", "a default is the first type of the module's list in every class of its ambiguity (4.3.4)")]

  (* the fault asked for, read once *)
  val fault = ref ""
  fun faulty rule = if !fault = rule then (fault := ""; true) else false

  fun breach (span, rule, msg) = raise T.Refuse (span, "[" ^ rule ^ "] " ^ msg)

  fun other "Double" = "Integer"
    | other _ = "Double"

  (* A report's binding: its module, name, scheme as text, whether signed
     and restricted, and where. *)
  type found = {module : string, name : string, scheme : string, signed : bool, restricted : bool,
                span : HsSource.span}

  (* A report's default: its module, place, predicates and choice as text,
     and whether Rule 2 chose it. *)
  type chosen = {module : string, place : string, preds : string, choice : string, ruleTwo : bool,
                 span : HsSource.span}

  (* `compare {kinds, derived, bindings, defaults, classes} claims`: each
     rule held, where `classes n` is whether the classes of that name are
     numeric and standard, and the kinds and derived instances are those
     of the program's modules.

     Raises: `HsLintTypes.Refuse` at the first breach. *)
  fun compare {kinds : kind list, derived : derived list, bindings : found list, defaults : chosen list,
               classes : string -> {numeric : bool, standard : bool} option, fault = f}
              (claims : claims) =
    let
      val () = fault := f
      val here = HsSource.noSpan
      (* kinds *)
      val () =
        List.app
          (fn {module, name, kind} =>
             let val kind = if faulty "kind" then (if kind = "*" then "* -> *" else "*") else kind
             in
               case List.find (fn (k : kind) => #module k = module andalso #name k = name) kinds of
                 SOME k => if #kind k = kind then ()
                           else breach (here, "kind", "the kind of `" ^ name ^ "` is claimed " ^ kind ^ ", and 4.6 infers " ^
                                                      #kind k)
               | NONE => breach (here, "kind", "a kind is claimed of `" ^ name ^ "`, which the program does not declare")
             end)
          (#kinds claims)
      (* derived instances: by their heads *)
      fun head inst = case findArrow inst of SOME i => String.extract (inst, i + 4, NONE) | NONE => inst
      and findArrow s =
        let fun go i = if i + 4 > size s then NONE else if String.substring (s, i, 4) = " => " then SOME i else go (i + 1)
        in go 0 end
      val () =
        List.app
          (fn {module, instance} =>
             let
               val instance = if isSome (findArrow instance) andalso faulty "derive" then head instance else instance
             in
               case List.find (fn (d : derived) => #module d = module andalso head (#instance d) = head instance) derived of
                 SOME d => if canonical (#instance d) = canonical instance then ()
                           else breach (here, "derive", "the derived instance " ^ instance ^ " is claimed, and its least " ^
                                                        "context gives " ^ #instance d)
               | NONE => breach (here, "derive", "a derived instance " ^ instance ^ " is claimed, which the program does " ^
                                                 "not derive")
             end)
          (#derived claims)
      val () =
        List.app (fn d => if List.exists (fn (c : derived) => #module c = #module d
                                                              andalso head (#instance c) = head (#instance d))
                                           (#derived claims)
                          then ()
                          else breach (here, "derive", "no context is claimed for the derived instance " ^ #instance d))
          derived
      (* defaults: by their place and predicates *)
      fun same (c : default, d : chosen) =
        #module c = #module d andalso #place c = #place d andalso canonicalPreds (#preds c) = canonicalPreds (#preds d)
      val claimedDefaults =
        List.map (fn (c : default) =>
                    if faulty "numeric" then {module = #module c, place = #place c, preds = "Show a", choice = #choice c}
                    else if faulty "standard" then
                      {module = #module c, place = #place c, preds = #preds c ^ ", HsLintFault a", choice = #choice c}
                    else c)
          (#defaults claims)
      val () =
        List.app
          (fn (c : default) =>
             let
               val cs = List.map classes (classesOf (#preds c))
             in
               if not (List.exists (fn SOME {numeric = true, ...} => true | _ => false) cs) then
                 breach (here, "numeric", "a default to " ^ #choice c ^ " is claimed at " ^ #place c ^ " for " ^ #preds c ^
                                          ", which has no numeric class")
               else if not (List.all (fn SOME {standard = true, ...} => true | _ => false) cs) then
                 breach (here, "standard", "a default to " ^ #choice c ^ " is claimed at " ^ #place c ^ " for " ^ #preds c ^
                                           ", a class of which is not the Prelude's or a standard library's")
               else ()
             end)
          claimedDefaults
      fun pick (c, [], _) = NONE
        | pick (c, d :: ds, prior) = if same (c, d) then SOME (d, List.rev prior @ ds) else pick (c, ds, d :: prior)
      val rest =
        List.foldl
          (fn (c : default, ds) =>
             case pick (c, ds, []) of
               SOME (d, ds') =>
                 let
                   val choice = if (#ruleTwo d andalso faulty "rule2") orelse (not (#ruleTwo d) andalso faulty "default")
                                then other (#choice c) else #choice c
                 in
                   if choice = #choice d then ds'
                   else if #ruleTwo d then
                     breach (#span d, "rule2", "the claim defaults " ^ #preds c ^ " at " ^ #place c ^ " to " ^ choice ^
                                               ", and Rule 2 at the module's end, where its uses fix it, gives " ^ #choice d)
                   else breach (#span d, "default", "the claim defaults " ^ #preds c ^ " at " ^ #place c ^ " to " ^ choice ^
                                                    ", and the first type of the list in each class is " ^ #choice d)
                 end
             | NONE => breach (here, "default", "a default of " ^ #preds c ^ " at " ^ #place c ^ " is claimed, which the " ^
                                                "program does not need"))
          defaults claimedDefaults
      val () =
        case rest of
          d :: _ => breach (#span d, if #ruleTwo d then "rule2" else "default",
                            "no default is claimed of " ^ #preds d ^ " at " ^ #place d ^ ", which " ^
                            (if #ruleTwo d then "Rule 2 resolves where the module ends" else "no other type resolves"))
        | [] => ()
      (* bindings *)
      val claimed = if faulty "binding" then (case #bindings claims of _ :: rest => rest | [] => []) else #bindings claims
      val () =
        List.app
          (fn (b : found) =>
             case List.find (fn (c : binding) => #module c = #module b andalso #name c = #name b) claimed of
               NONE => breach (#span b, "binding", "no type is claimed of `" ^ #name b ^ "`, which the module binds")
             | SOME c =>
                 let
                   val scheme = if #restricted b andalso faulty "rule1" then "Num a => " ^ #scheme c
                                else if #signed b andalso faulty "type" then #scheme c ^ " -> ()"
                                else #scheme c
                   val overloaded = isSome (findArrow scheme)
                 in
                   if #restricted b andalso overloaded then
                     breach (#span b, "rule1", "`" ^ #name b ^ "` is bound by a restricted group, and the claim gives it " ^
                                               "the overloaded type " ^ scheme ^
                                               ": Rule 1 generalizes no constrained variable (mr.rule1.constrained)")
                   else if canonical scheme = canonical (#scheme b) then ()
                   else breach (#span b, "type", "`" ^ #name b ^ "` is claimed " ^ scheme ^ ", and is " ^ #scheme b)
                 end)
          bindings
      val () =
        List.app (fn (c : binding) =>
                    if List.exists (fn (b : found) => #module b = #module c andalso #name b = #name c) bindings then ()
                    else breach (here, "binding", "a type is claimed of `" ^ #name c ^ "`, which the module does not bind"))
          claimed
    in
      fault := ""
    end
end
