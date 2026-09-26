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

  (* What the structure at a path has, as elaboration knows it: every name
     with its kind and its type, and the type is the structure's own and not
     the signature's variable -- `Word8Vector.sub` is `vector * int -> word`
     where `MONO_VECTOR` can only say `vector * int -> elem`. This is what a
     structure's page shows and a signature's page cannot.

     One printer serves the whole structure, so that a type variable keeps its
     name across the members and two type names that differ are told apart. *)
  datatype member =
      MVal of string                              (* the type *)
    | MCon of {ty : string, datatypeOf : string}  (* a constructor, and of what *)
    | MExn of string option                       (* what it carries, if anything *)
    | MType of {arity : int, defn : string option}  (* NONE: a type of its own *)
    | MData of {arity : int, cons : string list}
    | MStr

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

  (* Of two paths to one type, the one to show: the shorter, and of two equally
     short the earlier, so that a page does not depend on the order of a walk. *)
  fun better (a : string, b : string) : bool =
    let
      fun parts s = List.length (String.fields (fn c => c = #".") s)
    in
      parts a < parts b
      orelse (parts a = parts b
              andalso (String.size a < String.size b orelse (String.size a = String.size b andalso a < b)))
    end

  fun best ((stamp, name), m : string IntMap.map) : string IntMap.map =
    case IntMap.find (m, stamp) of
      SOME n => if better (name, n) then IntMap.insert (m, stamp, name) else m
    | NONE => IntMap.insert (m, stamp, name)

  (* The types a structure names, as against those it borrows: `Word8.word` is
     a name of the type, where `Word8Vector.elem` and `BinIO.elem` are names of
     a use of it, so only the first is a name to show it under. *)
  fun namedTypes (into : string -> bool) (prefix : string, e : Env.env) : (int * string) list =
    case e of
      Env.Env {tys, strs, ...} =>
        List.mapPartial (fn (name, Env.TyStr {fcn, ...}) =>
                           case tyconOf fcn of
                             SOME c => if #name c = name then SOME (#stamp c, prefix ^ name) else NONE
                           | NONE => NONE)
                        (StringMap.listItemsi tys)
        @ List.concat (List.map (fn (name, sub) =>
                                   if into name then namedTypes into (prefix ^ name ^ ".", sub) else [])
                                (StringMap.listItemsi strs))

  (* Every type of the library by the stamp of the type name it stands for,
     under the shortest path that names it: `word`, not `Word.word`, and
     `Word8.word`, which has no shorter name. Built once, since it walks the
     whole library. *)
  val allNames : string IntMap.map option ref = ref NONE

  fun namesByStamp ({env, ...} : library, public : string -> bool) : string IntMap.map =
    case !allNames of
      SOME m => m
    | NONE =>
        let val m = List.foldl best IntMap.empty (namedTypes public ("", env))
        in allNames := SOME m; m end

  fun membersOf (lib : library, public : string -> bool) (path : string list) : (string * member) list option =
    case Env.findStr (#env lib, path) of
      NONE => NONE
    | SOME (structure' as Env.Env {vals, tys, strs}) =>
        let
          val printer = Types.newPrinter ()
          (* What a type is called on this page: a type that this structure
             names is that name, a type that a structure below it names is the
             path down to it, and any other type is the shortest path that
             reaches it in the library. So `Word8Vector.sub` is
             `vector * int -> Word8.word`: `vector` because the structure names
             it, `Word8.word` because `elem` is not a name of the type but of
             this structure's use of it, and a reader of `word` would think of
             `Word.word`. *)
          val here = List.foldl best IntMap.empty (namedTypes (fn _ => true) ("", structure'))
          fun nameOf (c : Types.tycon) =
            case IntMap.find (here, #stamp c) of
              SOME n => SOME n
            | NONE => IntMap.find (namesByStamp (lib, public), #stamp c)
          fun show t = Types.toStringNamed (nameOf, printer) t
          (* What a type is here: NONE when the structure's own, and otherwise
             the type it stands for, applied to its parameters. A type name
             that is not this member's name is another type -- `elem` of
             `Word8Vector` is `word` -- and one that is, is the structure's
             own, whether the signature made it abstract or the structure did. *)
          fun defnOf (member : string, fcn : Types.tyfcn) : string option =
            let
              fun param k = Types.freshTvar (0, Types.KRigid ("'" ^ String.str (Char.chr (Char.ord #"a" + k))), false)
              val params = List.tabulate (Types.fcnArity fcn, param)
              val shown = show (Types.applyFcn (fcn, params))
            in
              case tyconOf fcn of
                SOME c => if #name c = member then NONE else SOME shown
              | NONE => SOME shown
            end
          (* the constructors a datatype of this structure declares, so that a
             constructor is not listed twice *)
          val consOf =
            List.foldl (fn ((name, Env.TyStr {cons, ...}), m) =>
                          List.foldl (fn ((c, _), m) => StringMap.insert (m, c, name)) m cons)
                       StringMap.empty (StringMap.listItemsi tys)
          val tyMembers =
            List.map (fn (name, Env.TyStr {fcn, cons}) =>
                        (name,
                         if List.null cons
                         then MType {arity = Types.fcnArity fcn, defn = defnOf (name, fcn)}
                         else MData {arity = Types.fcnArity fcn, cons = List.map #1 cons}))
                     (StringMap.listItemsi tys)
          val valMembers =
            List.map (fn (name, v) =>
                        (name,
                         case v of
                           Env.Val {scheme, ...} => MVal (show scheme)
                         | Env.Prim {scheme, ...} => MVal (show scheme)
                         | Env.ConAsVal {scheme, ...} => MVal (show scheme)
                         | Env.ExnAsVal {ty, ...} => MVal (show ty)
                         | Env.Con {scheme, ...} =>
                             (case StringMap.find (consOf, name) of
                                SOME d => MCon {ty = show scheme, datatypeOf = d}
                              | NONE => MVal (show scheme))
                         | Env.Exn {ty, ...} =>
                             MExn (case Types.prune ty of Types.TArrow (a, _) => SOME (show a) | _ => NONE)))
                     (StringMap.listItemsi vals)
          val strMembers = List.map (fn (name, _) => (name, MStr)) (StringMap.listItemsi strs)
        in
          SOME (tyMembers @ valMembers @ strMembers)
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
