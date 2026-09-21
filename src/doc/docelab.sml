(* The library through the compiler's elaborator (docs/plans/docgen.md, D7,
   D12). Extraction works on syntax; what only the static semantics knows is
   asked here: whether a structure matches the signature it claims to
   implement. The library is elaborated as the compiler's driver elaborates
   it, every file of the MANIFEST in order with the fixity threaded through,
   and a claim `Implements: SIG where type ...` of a structure S is checked by
   elaborating `structure Claim : SIG where type ... = S` on top of that: what
   the compiler says against it is the diagnostic. A library other than the
   Basis Library is elaborated on top of it. *)
structure DocElab =
struct
  type library = {env : Env.env, fixity : Fixity.env}

  (* NONE when the library does not elaborate; the compiler's error is
     reported, and the documentation is still made. prelude: the directory of
     a library that this one is written on, the Basis Library for every other
     one; it is elaborated first, whole. *)
  fun library (dir : string, prelude : string option) : library option =
    let
      val fixity = ref Fixity.initial
      fun parse d (e : BasisManifest.entry) =
        let val (prog, fx) = Parser.parseTokensWith (Lexer.tokenize (Source.load (d ^ "/" ^ #file e)), !fixity)
        in fixity := fx; prog end
      fun programOf d = List.concat (List.map (parse d) (BasisManifest.readManifest d))
      val before' = case prelude of SOME d => programOf d | NONE => []
      val prog = before' @ programOf dir
      val env = ref Env.initial
    in
      Elaborate.allowPrim := true;
      Elaborate.elabTop (env, prog);
      Elaborate.finish ();
      Error.warnings := [];
      SOME {env = !env, fixity = !fixity}
    end
    handle Error.CompileError (sp, msg) =>
      (DocDiag.error (sp, "the library does not elaborate, so that no claim is checked: " ^ msg); NONE)

  (* How many arguments a value of this type takes one after another, with
     type abbreviations expanded, as elaboration has done. *)
  fun arrows (ty : Types.ty) : int =
    case ty of
      Types.TArrow (_, result) => 1 + arrows result
    | Types.TVar (ref (Types.Bound t)) => arrows t
    | _ => 0

  (* The usage head of a value of a signature against its elaborated type:
     extraction let a head have more arguments than the written type shows
     arrows where the result might abbreviate a function type; now we know. *)
  fun checkHead (signat : string, name : string, head : DocHead.head, span : Source.span) : unit =
    case StringMap.find (!Elaborate.sigs, signat) of
      SOME {env = Env.Env {vals, ...}, ...} =>
        (case StringMap.find (vals, name) of
           SOME (Env.Val {scheme, ...}) =>
             if #arity head > arrows scheme then
               DocDiag.error (span, "the usage `" ^ #code head ^ "` has " ^ Int.toString (#arity head)
                                    ^ " arguments, and " ^ name ^ " takes " ^ Int.toString (arrows scheme)
                                    ^ ": its type is " ^ Types.toString scheme)
             else ()
         | _ => ())
    | NONE => ()

  (* A structure against the signature it claims. *)
  fun checkClaim ({env, fixity} : library) (c : DocClaims.claim) : unit =
    if #isFunctor c then ()
    else
      let
        val text = "structure DocgenClaim : " ^ #signat c
                   ^ (if #realisations c = "" then "" else " " ^ #realisations c) ^ " = " ^ #name c
        val (prog, _) = Parser.parseTokensWith (Lexer.tokenize (Source.fromString ("<claim>", text)), fixity)
      in
        Elaborate.elabTop (ref env, prog);
        Elaborate.finish ();
        Error.warnings := []
      end
      handle Error.CompileError (_, msg) =>
        DocDiag.error (#span c, #name c ^ " does not implement " ^ #signat c
                                ^ (if #realisations c = "" then "" else " " ^ #realisations c)
                                ^ ", as its comment claims: " ^ msg)

  fun namesIn (Env.Env {vals, tys, strs}) : string list =
    StringMap.listKeys (List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty
                                   (StringMap.listKeys vals @ StringMap.listKeys tys @ StringMap.listKeys strs))

  (* What the structure at a path declares: its values, constructors and
     exceptions, its types and its substructures, as elaboration knows them,
     each name once and in the order of the alphabet. This is also known of a
     structure that is another one by name or an application of a functor,
     where the syntax shows no body. *)
  fun namesOf ({env, ...} : library) (path : string list) : string list option =
    Option.map namesIn (Env.findStr (env, path))

  (* What a signature of the library specifies, or what it specifies for the
     substructure at a path in it: with what it includes, and with the
     constructors of a datatype that it only replicates, which the syntax does
     not show. After `library`. *)
  fun specifiedBy (signat : string, sub : string list) : string list option =
    case StringMap.find (!Elaborate.sigs, signat) of
      SOME {env, ...} => Option.map namesIn (Env.findStr (env, sub))
    | NONE => NONE

  (* The type name that a type function stands for, if it is one: a type
     name itself, or an abbreviation that only gives one another name, as
     `type elem = char` and `type 'a vector = 'a Vector.vector` do. *)
  fun tyconOf (fcn : Types.tyfcn) : Types.tycon option =
    case fcn of
      Types.TName c => SOME c
    | Types.TAbbrev (ids, body) =>
        (case Types.prune body of
           Types.TCon (c, args) =>
             if List.length args = List.length ids
                andalso ListPair.all (fn (id, a) =>
                                        case Types.prune a of
                                          Types.TVar (ref (Types.Unbound {id = id', ...})) => id = id'
                                        | _ => false) (ids, args)
             then SOME c else NONE
         | _ => NONE)

  (* Every type of the top level and of the structures that `public` lets
     through, with their substructures: its name as a program writes it, the
     stamp of the type name it stands for, and its arity. Types with one
     stamp are one type (D7). *)
  fun typeNames ({env, ...} : library, public : string -> bool) : (string * int * int) list =
    let
      fun walk (prefix : string, Env.Env {tys, strs, ...}) =
        List.mapPartial (fn (name, Env.TyStr {fcn, ...}) =>
                           Option.map (fn c : Types.tycon => (prefix ^ name, #stamp c, #arity c)) (tyconOf fcn))
                        (StringMap.listItemsi tys)
        @ List.concat (List.map (fn (name, sub) => if public name then walk (prefix ^ name ^ ".", sub) else [])
                                (StringMap.listItemsi strs))
    in
      walk ("", env)
    end

  (* What a signature expression, a signature's name with its `where type`s,
     says of the type at a path in it: that it is some type that only the
     structure decides (Abstract), or which type it is (Determined): by a
     `where type`, by a definition in the signature, by sharing. NONE when the
     expression does not elaborate or has no such type. After `library`. *)
  datatype typeSpec = Abstract | Determined

  val probed : SigMatch.sigma option StringMap.map ref = ref StringMap.empty

  fun typeSpecOf ({env, fixity} : library) (sigexp : string, sub : string list, ty : string) : typeSpec option =
    let
      val sigma =
        case StringMap.find (!probed, sigexp) of
          SOME s => s
        | NONE =>
            let
              val saved = !Elaborate.sigs
              val (prog, _) = Parser.parseTokensWith (Lexer.tokenize (Source.fromString ("<probe>", "signature DocgenProbe = " ^ sigexp)), fixity)
              val found =
                (Elaborate.elabTop (ref env, prog); Elaborate.finish (); Error.warnings := [];
                 StringMap.find (!Elaborate.sigs, "DocgenProbe"))
                handle Error.CompileError _ => NONE
            in
              Elaborate.sigs := saved;
              probed := StringMap.insert (!probed, sigexp, found);
              found
            end
    in
      case sigma of
        NONE => NONE
      | SOME {bound, env = sigEnv} =>
          (case Env.findStr (sigEnv, sub) of
             SOME (Env.Env {tys, ...}) =>
               (case StringMap.find (tys, ty) of
                  SOME (Env.TyStr {fcn = Types.TName c, ...}) =>
                    SOME (if SigMatch.isBound (bound, c) then Abstract else Determined)
                | SOME _ => SOME Determined
                | NONE => NONE)
           | NONE => NONE)
    end

  (* The types that a signature expression leaves abstract, each with the
     substructures on the way to it. *)
  fun abstractTypesOf (lib : library) (sigexp : string) : (string list * string) list =
    (ignore (typeSpecOf lib (sigexp, [], ""));
     case StringMap.find (!probed, sigexp) of
       SOME (SOME {bound, env = sigEnv}) =>
         let
           fun walk (path, Env.Env {tys, strs, ...}) =
             List.mapPartial (fn (name, Env.TyStr {fcn = Types.TName c, ...}) =>
                                   if SigMatch.isBound (bound, c) then SOME (path, name) else NONE
                               | _ => NONE)
                             (StringMap.listItemsi tys)
             @ List.concat (List.map (fn (name, sub) => walk (path @ [name], sub)) (StringMap.listItemsi strs))
         in
           walk ([], sigEnv)
         end
     | _ => [])

  (* Whether the type at a path of the library, as a program sees it, shows
     what it is made of: it abbreviates a record, a tuple, a function or an
     application of a type, and is no type name of its own. *)
  fun showsItsMaking ({env, ...} : library) (path : string list, ty : string) : bool =
    case Env.findStr (env, path) of
      SOME (Env.Env {tys, ...}) =>
        (case StringMap.find (tys, ty) of
           SOME (Env.TyStr {fcn, ...}) => not (isSome (tyconOf fcn))
         | NONE => false)
    | NONE => false

  (* An example against the library: `val it : bool = ...` has to elaborate. *)
  fun checkExample ({env, fixity} : library) (what : string, expression : string, span : Source.span) : unit =
    let
      val (prog, _) = Parser.parseTokensWith (Lexer.tokenize (Source.fromString ("<example>", "val it : bool = " ^ expression)), fixity)
    in
      Elaborate.elabTop (ref env, prog);
      Elaborate.finish ();
      Error.warnings := []
    end
    handle Error.CompileError (_, msg) => DocDiag.error (span, "the example `" ^ what ^ "` is not one that can be run: " ^ msg)
end
