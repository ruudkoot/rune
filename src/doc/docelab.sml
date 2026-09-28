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

  (* What a library is written on: the Basis Library, for every library but
     itself, and the libraries its MANIFEST names (docs/plans/quickcheck.md,
     D1), in the order they are elaborated. *)
  type prelude = {basis : string option, libraries : string list}

  (* NONE when the library does not elaborate; the compiler's error is
     reported, and the documentation is still made. The prelude is elaborated
     first, whole. The Basis Library may use _prim, and so may a library that
     is written on nothing; a library written on the Basis Library may not,
     as the compiler has it. *)
  fun library (dir : string, prelude : prelude) : library option =
    let
      val fixity = ref Fixity.initial
      fun parse d (e : BasisManifest.entry) =
        let val (prog, fx) = Parser.parseTokensWith (Lexer.tokenize (Source.load (d ^ "/" ^ #file e)), !fixity)
        in fixity := fx; prog end
      fun programOf d = List.concat (List.map (parse d) (BasisManifest.readManifest d))
      val basisProg = case #basis prelude of SOME d => programOf d | NONE => []
      val prog = List.concat (List.map programOf (#libraries prelude)) @ programOf dir
      val env = ref Env.initial
    in
      Elaborate.allowPrim := true;
      Elaborate.elabTop (env, basisProg);
      Elaborate.allowPrim := not (isSome (#basis prelude));
      Elaborate.elabTop (env, prog);
      Elaborate.allowPrim := true;
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

     A type the structure names has no other name here (`MType` with no
     definition); one that stands for another shows what it stands for. *)
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
  fun namedTypes (into : string -> bool) (prefix : string, e : Env.env) : (int * string * bool) list =
    case e of
      Env.Env {tys, strs, ...} =>
        List.mapPartial (fn (name, Env.TyStr {fcn, ...}) =>
                           case tyconOf fcn of
                             SOME c => if #name c = name
                                       then SOME (#stamp c, prefix ^ name,
                                                  case fcn of Types.TName _ => true | _ => false)
                                       else NONE
                           | NONE => NONE)
                        (StringMap.listItemsi tys)
        @ List.concat (List.map (fn (name, sub) =>
                                   if into name then namedTypes into (prefix ^ name ^ ".", sub) else [])
                                (StringMap.listItemsi strs))

  (* Of the names of one type, the one that declares it: where the type is a
     type name and not an abbreviation of one. The byte vector is
     `Word8Vector.vector`, which declares it, and not `BinIO.vector`, which is
     shorter and only says which vector `BinIO` reads; a type that nothing
     public declares -- `BinIO.instream`, made in a structure the seal hides --
     has the shortest of its names. *)
  fun owner ((stamp, name, declared), m : (string * bool) IntMap.map) : (string * bool) IntMap.map =
    case IntMap.find (m, stamp) of
      SOME (n, d) =>
        if (declared andalso not d) orelse (declared = d andalso better (name, n))
        then IntMap.insert (m, stamp, (name, declared)) else m
    | NONE => IntMap.insert (m, stamp, (name, declared))

  (* Every type of the library by the stamp of the type name it stands for,
     under the shortest path that names it: `word`, not `Word.word`, and
     `Word8.word`, which has no shorter name. Built once, since it walks the
     whole library. *)
  val allNames : string IntMap.map option ref = ref NONE

  fun namesByStamp ({env, ...} : library, public : string -> bool) : string IntMap.map =
    case !allNames of
      SOME m => m
    | NONE =>
        let val m = IntMap.map #1 (List.foldl owner IntMap.empty (namedTypes public ("", env)))
        in allNames := SOME m; m end

  fun membersOf (lib : library, public : string -> bool) (path : string list) : (string * member) list option =
    case Env.findStr (#env lib, path) of
      NONE => NONE
    | SOME (structure' as Env.Env {vals, tys, strs}) =>
        let
          (* What a type is called on this page: a type that this structure
             names is that name, a type that a structure below it names is the
             path down to it, and any other type is the shortest path that
             reaches it in the library. So `Word8Vector.sub` is
             `vector * int -> Word8.word`: `vector` because the structure names
             it, `Word8.word` because `elem` is not a name of the type but of
             this structure's use of it, and a reader of `word` would think of
             `Word.word`. *)
          val here = List.foldl (fn ((stamp, name, _), m) => best ((stamp, name), m)) IntMap.empty
                                (namedTypes (fn _ => true) ("", structure'))
          val self = String.concatWith "." path ^ "."
          (* a type this structure owns has its name here; any other, the name
             of the structure that declares it *)
          fun ownedHere (c : Types.tycon) =
            case IntMap.find (namesByStamp (lib, public), #stamp c) of
              SOME n => String.isPrefix self n
            | NONE => true
          (* the name another type is shown under everywhere: `int` is the top
             level's, so `Int64`'s own `int` must be shown as `Int64.int`, or
             `toInt : int -> int` would read as the identity *)
          val takenNames =
            IntMap.foldli (fn (stamp, name, m) => StringMap.insert (m, name, stamp))
                          StringMap.empty (namesByStamp (lib, public))
          fun nameOf (c : Types.tycon) =
            if ownedHere c then
              case IntMap.find (here, #stamp c) of
                SOME n =>
                  (case StringMap.find (takenNames, n) of
                     SOME other => if other <> #stamp c then SOME (String.concatWith "." path ^ "." ^ n) else SOME n
                   | NONE => SOME n)
              | NONE => NONE
            else IntMap.find (namesByStamp (lib, public), #stamp c)
          (* Elaboration expands an abbreviation, so a type the source writes
             `'a region` reaches here as the record it stands for. The
             abbreviations of this structure and of the structures below it
             that are not merely another name for a type constructor are
             folded back: a part of a type that is an instance of one is shown
             under its name, as the signature shows it. Only these: the
             library's `StringCvt.reader` would match every function that
             returns an option of a pair, `input1` among them. *)
          val abbreviations =
            let
              fun walk (prefix, Env.Env {tys, strs, ...}) =
                List.mapPartial (fn (name, Env.TyStr {fcn = fcn as Types.TAbbrev (ids, body), ...}) =>
                                      if isSome (tyconOf fcn) then NONE
                                      else SOME (ids, body, Types.freshTycon (prefix ^ name, List.length ids, false))
                                  | _ => NONE)
                                (StringMap.listItemsi tys)
                @ List.concat (List.map (fn (name, sub) => walk (prefix ^ name ^ ".", sub)) (StringMap.listItemsi strs))
              (* the shortest name first, as for the names of types *)
              fun sortBy [] = []
                | sortBy (x :: xs) =
                    let fun name (_, _, c : Types.tycon) = #name c
                    in sortBy (List.filter (fn y => better (name y, name x)) xs) @ [x]
                       @ sortBy (List.filter (fn y => not (better (name y, name x))) xs)
                    end
            in
              sortBy (walk ("", structure'))
            end
          (* the parameters of an abbreviation that make its body the type *)
          fun instance (ids : int list, pat : Types.ty, t : Types.ty) : Types.ty list option =
            let
              fun same (a, b) =
                case (Types.prune a, Types.prune b) of
                  (Types.TVar r, Types.TVar r') => r = r'
                | (Types.TCon (c, xs), Types.TCon (c', ys)) =>
                    #stamp c = #stamp c' andalso List.length xs = List.length ys andalso ListPair.all same (xs, ys)
                | (Types.TRecord fs, Types.TRecord gs) =>
                    List.length fs = List.length gs
                    andalso ListPair.all (fn ((l, x), (l', y)) => l = l' andalso same (x, y)) (fs, gs)
                | (Types.TArrow (a, b), Types.TArrow (a', b')) => same (a, a') andalso same (b, b')
                | _ => false
              fun go (pat, t, binds) =
                case (Types.prune pat, Types.prune t) of
                  (Types.TVar (ref (Types.Unbound {id, ...})), _) =>
                    if not (List.exists (fn i => i = id) ids) then NONE
                    else
                      (case List.find (fn (i, _) => i = id) binds of
                         SOME (_, bound) => if same (bound, t) then SOME binds else NONE
                       | NONE => SOME ((id, t) :: binds))
                | (Types.TCon (c, ps), Types.TCon (c', ts)) =>
                    if #stamp c = #stamp c' andalso List.length ps = List.length ts then all (ps, ts, binds) else NONE
                | (Types.TRecord fs, Types.TRecord gs) =>
                    if List.length fs = List.length gs andalso ListPair.all (fn ((l, _), (l', _)) => l = l') (fs, gs)
                    then all (List.map #2 fs, List.map #2 gs, binds) else NONE
                | (Types.TArrow (a, b), Types.TArrow (a', b')) => all ([a, b], [a', b'], binds)
                | _ => NONE
              and all ([], [], binds) = SOME binds
                | all (p :: ps, x :: xs, binds) = (case go (p, x, binds) of SOME b => all (ps, xs, b) | NONE => NONE)
                | all _ = NONE
            in
              case go (pat, t, []) of
                SOME binds => SOME (List.map (fn i => case List.find (fn (i', _) => i' = i) binds of
                                                         SOME (_, x) => x
                                                       | NONE => Types.TRecord [])
                                             ids)
              | NONE => NONE
            end
          fun fold (t : Types.ty) : Types.ty =
            let
              fun first [] = NONE
                | first ((ids, body, c) :: rest) =
                    (case instance (ids, body, t) of
                       SOME args => SOME (Types.TCon (c, List.map fold args))
                     | NONE => first rest)
            in
              case first abbreviations of
                SOME t' => t'
              | NONE => inside t
            end
          and inside (t : Types.ty) : Types.ty =
            case Types.prune t of
              Types.TCon (c, args) => Types.TCon (c, List.map fold args)
            | Types.TRecord fs => Types.TRecord (List.map (fn (l, x) => (l, fold x)) fs)
            | Types.TArrow (a, b) => Types.TArrow (fold a, fold b)
            | other => other
          (* a printer for each member, so that the variables of every type
             begin at `'a` as the signature writes them; the names of the type
             constructors come from nameOf and need no state *)
          fun print' t = Types.toStringNamed (nameOf, Types.newPrinter ()) t
          fun show t = print' (fold t)
          (* What a type is here: a type the structure names has no other name
             (NONE), whether a signature made it abstract or the structure
             declared it; one that stands for another shows what it stands for,
             applied to its parameters, as `Word8Vector.elem` is `Word8.word`
             and `Array.array` is `'a array`, the type of the top level. *)
          fun defnOf (member : string, fcn : Types.tyfcn) : string option =
            case (fcn, tyconOf fcn) of
              (Types.TName _, _) => NONE
            | (_, SOME c) =>
                (* `Array.array` is the top level's, which is also written
                   `array`: only a type this structure owns is its own *)
                if ownedHere c andalso nameOf c = SOME member then NONE
                else
                  let
                    fun param k = Types.freshTvar (0, Types.KRigid ("'" ^ String.str (Char.chr (Char.ord #"a" + k))), false)
                  in
                    SOME (print' (inside (Types.applyFcn (fcn, List.tabulate (Types.fcnArity fcn, param)))))
                  end
            | (Types.TAbbrev _, NONE) =>
                let
                  fun param k = Types.freshTvar (0, Types.KRigid ("'" ^ String.str (Char.chr (Char.ord #"a" + k))), false)
                in
                  SOME (print' (inside (Types.applyFcn (fcn, List.tabulate (Types.fcnArity fcn, param)))))
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

  (* ---- laws (docs/plans/quickcheck.md, D7 and M7) ---- *)

  (* The two sides of a law that is an equation at its top, as the law's
     text before and after its `=`; NONE for any other law. *)
  fun sides (fixity : Fixity.env) (code : string) : (string * string) option =
    let
      val prefix = "val it = "
      val (prog, _) = Parser.parseTokensWith (Lexer.tokenize (Source.fromString ("<law>", prefix ^ code)), fixity)
      val n = String.size prefix
      fun balanced (t : string) =
        let
          fun go (i, depth) =
            if i >= String.size t then depth = 0
            else case String.sub (t, i) of
                   #"(" => go (i + 1, depth + 1) | #"[" => go (i + 1, depth + 1) | #"{" => go (i + 1, depth + 1)
                 | #")" => depth > 0 andalso go (i + 1, depth - 1) | #"]" => depth > 0 andalso go (i + 1, depth - 1)
                 | #"}" => depth > 0 andalso go (i + 1, depth - 1)
                 | _ => go (i + 1, depth)
        in go (0, 0) end
      fun trim t = Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full t)))
    in
      case prog of
        [Ast.DVal (_, [(_, Ast.EApp (Ast.EVar (([], "="), _, {start, ...}), Ast.ETuple ([_, _], _), _))], _)] =>
          let
            val l = trim (String.substring (code, 0, start - n))
            val r = trim (String.extract (code, start - n + 1, NONE))
          in
            if String.sub (code, start - n) = #"=" andalso balanced l andalso balanced r then SOME (l, r) else NONE
          end
      | _ => NONE
    end
    handle _ => NONE

  (* What elaborating a law found: its variables with their types, as the
     documentation writes them, or why it is no Standard ML. *)
  type variable = {name : string, ty : string, instance : string option}
  datatype law = Quantified of variable list | NotSml of string

  (* The structures of lib/test/property that are arbitraries (`XArb`, read
     from its MANIFEST), where that library is there: an instance is then
     resolved for every variable of a law, and a variable with none is an
     error at its comment. NONE: the library is not there, and nothing is
     resolved. *)
  val instanceStructures : string list option ref = ref NONE

  (* every name of every type of the library, by the stamp of its type name *)
  val allTypeNames : string list IntMap.map option ref = ref NONE
  fun namesOf' (lib : library) (stamp : int) : string list =
    let
      val m = case !allTypeNames of
                SOME m => m
              | NONE =>
                  let val m = List.foldl (fn ((name, st, _), m) =>
                                            IntMap.insert (m, st, name :: (case IntMap.find (m, st) of SOME l => l | NONE => [])))
                                         IntMap.empty (typeNames (lib, fn _ => true))
                  in allTypeNames := SOME m; m end
    in
      case IntMap.find (m, stamp) of SOME l => List.rev l | NONE => []
    end

  (* The arbitraries of the types of the Basis Library whose name alone does
     not say it (`X.t` is `XArb.arb` otherwise), by name and arity, as an
     expression with its arguments' in order. *)
  val instanceTable : (string * string) list =
    [("int", "IntArb.arb"), ("word", "WordArb.arb"), ("real", "RealArb.arb"), ("char", "CharArb.arb"),
     ("string", "StringArb.arb"), ("bool", "Arb.bool"), ("order", "Arb.order"), ("exn", "Arb.exn"),
     ("list", "Arb.list"), ("option", "Arb.option"), ("ref", "Arb.reference"), ("vector", "Arb.vector"),
     ("array", "Arb.array"), ("VectorSlice.slice", "Arb.vectorSlice"), ("ArraySlice.slice", "Arb.arraySlice"),
     ("Array2.array", "Arb.array2"),
     ("Date.date", "DateArb.arb"), ("Date.month", "DateArb.month"), ("Date.weekday", "DateArb.weekday"),
     ("Time.time", "TimeArb.arb"), ("IEEEReal.rounding_mode", "IEEERealArb.roundingMode"),
     ("IEEEReal.float_class", "IEEERealArb.floatClass"), ("IO.buffer_mode", "BasisDataArb.bufferMode"),
     ("StringCvt.radix", "BasisDataArb.radix"), ("Array2.traversal", "BasisDataArb.traversal"),
     ("BinIO.instream", "SystemArb.binInstream"), ("BinIO.StreamIO.instream", "SystemArb.binStreamInstream"),
     ("BinIO.StreamIO.writer", "SystemArb.binWriter"), ("BinIO.StreamIO.outstream", "SystemArb.binOutstream"),
     ("OS.IO.iodesc", "SystemArb.iodesc"), ("OS.IO.poll_desc", "SystemArb.pollDesc"),
     ("OS.FileSys.file_id", "SystemArb.fileId"), ("OS.syserror", "SystemArb.syserror"),
     ("Posix.FileSys.file_desc", "SystemArb.fileDesc"), ("Posix.Process.pid", "SystemArb.pid"),
     ("Posix.Signal.signal", "SystemArb.signal"), ("Posix.ProcEnv.uid", "SystemArb.uid"),
     ("Posix.ProcEnv.gid", "SystemArb.gid"), ("Posix.TTY.speed", "SystemArb.speed"),
     ("Posix.TTY.termios", "SystemArb.termios"), ("Posix.IO.whence", "SystemArb.whence"),
     ("Posix.IO.lock_type", "SystemArb.lockType"), ("Socket.AF.addr_family", "SystemArb.addrFamily"),
     ("Socket.SOCK.sock_type", "SystemArb.sockType"), ("NetHostDB.in_addr", "SystemArb.inAddr"),
     ("NetHostDB.entry", "SystemArb.hostEntry"), ("SML90.instream", "SML90Arb.instream"),
     ("INet6Sock.in6_addr", "INet6SockArb.inAddr"), ("Random.gen", "RandomArb.arb")]

  (* The arbitrary of a type, as an expression: a type variable at `int`
     (D8), a function type by `Arb.function` (`Arb.pureFunction` for a
     variable that has no effects), tuples by `Arb.pair` and `Arb.triple`, a
     reader of characters by `BasisDataArb.reader`, the records of `Date.date`
     and `Posix.TTY.termios` fields by their arbitraries, and every other type
     by the table or as `XArb.arb` for a type `X.t`. NONE: it has none. *)
  (* The type that `XArb.arb` is the arbitrary of, by the name of `X`: its
     own type, and not another it names (`Word8Array.vector` is a vector). *)
  fun mainType (x : string) : string =
    let fun ends suffix = String.isSuffix suffix x
    in
      if ends "Slice" then "slice"
      else if ends "Array2" orelse ends "Array" then "array"
      else if ends "Vector" then "vector"
      else if ends "Substring" then "substring"
      else if ends "String" then "string"
      else if ends "Char" then "char"
      else if String.isPrefix "Real" x orelse String.isPrefix "LargeReal" x then "real"
      else if String.isPrefix "Word" x orelse String.isPrefix "LargeWord" x orelse String.isPrefix "SysWord" x then "word"
      else "int"
    end

  fun instanceOf (lib : library) (pure : bool) (ty : Types.ty) : string option =
    let
      val known = case !instanceStructures of SOME l => l | NONE => []
      fun all xs = if List.all isSome xs then SOME (List.map valOf xs) else NONE
      fun apply (f, []) = f
        | apply (f, args) = f ^ " (" ^ String.concatWith ", " args ^ ")"
      (* the name the pages print first, then the others *)
      fun names (c : Types.tycon) =
        case IntMap.find (namesByStamp (lib, fn _ => true), #stamp c) of
          SOME best => best :: List.filter (fn n => n <> best) (namesOf' lib (#stamp c))
        | NONE => namesOf' lib (#stamp c)
      fun named (c : Types.tycon, n) = List.exists (fn m => m = n) (names c)
      fun isVar t = case Types.prune t of Types.TVar _ => true | _ => false
      fun labels (fs : (string * Types.ty) list) = List.map #1 fs
      fun inst t =
        case Types.prune t of
          Types.TVar _ => SOME "IntArb.arb"
        | Types.TArrow (a, b) =>
            (* a reader of characters over a stream of a type variable *)
            (case (Types.prune a, Types.prune b) of
               (Types.TVar _, Types.TCon (opt, [pr])) =>
                 (case Types.prune pr of
                    Types.TRecord [("1", ch), ("2", st)] =>
                      (case Types.prune ch of
                         Types.TCon (c, []) =>
                           if named (opt, "option") andalso named (c, "char") andalso isVar st
                           then SOME "BasisDataArb.reader" else function (a, b)
                       | _ => function (a, b))
                  | _ => function (a, b))
             | _ => function (a, b))
        | Types.TRecord [] => SOME "Arb.unit"
        | Types.TRecord fs =>
            if labels fs = ["1", "2"] then Option.map (fn xs => apply ("Arb.pair", xs)) (all (List.map (inst o #2) fs))
            else if labels fs = ["1", "2", "3"] then Option.map (fn xs => apply ("Arb.triple", xs)) (all (List.map (inst o #2) fs))
            else if labels fs = ["day", "hour", "minute", "month", "offset", "second", "year"] then SOME "DateArb.fields"
            else if labels fs = ["cc", "cflag", "iflag", "ispeed", "lflag", "oflag", "ospeed"] then SOME "SystemArb.termiosFields"
            else if labels fs = ["class", "digits", "exp", "sign"] then SOME "IEEERealArb.decimalApprox"
            else NONE
        | Types.TCon (c, args) =>
            let
              val ns = names c
              fun sock () =
                (* ('af, 'mode Socket.stream) Socket.sock of an address family *)
                case args of
                  [af, _] =>
                    (case Types.prune af of
                       Types.TCon (a, []) =>
                         if named (a, "INetSock.inet") then SOME "SystemArb.inetStreamSock ()"
                         else if named (a, "INet6Sock.inet6") then SOME "INet6SockArb.streamSock ()"
                         else NONE
                     | _ => NONE)
                | _ => NONE
            in
              if List.exists (fn n => n = "Socket.sock") ns then sock ()
              else
                case List.find (fn (n, _) => List.exists (fn m => m = n) ns) instanceTable of
                  SOME (_, e) => Option.map (fn xs => apply (e, xs)) (all (List.map inst args))
                | NONE =>
                    if not (List.null args) then NONE
                    else
                      List.foldl (fn (n, SOME e) => SOME e
                                   | (n, NONE) =>
                                       case String.fields (fn ch => ch = #".") n of
                                         [x, t] => if List.exists (fn k => k = x ^ "Arb") known andalso t = mainType x
                                                   then SOME (x ^ "Arb.arb") else NONE
                                       | _ => NONE)
                                 NONE ns
            end
      and function (a, b) =
        Option.map (fn (x, y) => (if pure then "Arb.pureFunction (" else "Arb.function (") ^ x ^ ", " ^ y ^ ")")
                   (case (inst a, inst b) of (SOME x, SOME y) => SOME (x, y) | _ => NONE)
    in
      inst ty
    end

  (* The expression a law and its conditions are elaborated as, under the
     structure's names: an equation's two sides as a list, so that they have
     one type and need not have equality; any other law as a `bool`. *)
  fun lawExpression (fixity : Fixity.env) (opens : string, code : string, conditions : string list) : string =
    let
      val claim = case sides fixity code of
                    SOME (l, r) => "[" ^ l ^ ", " ^ r ^ "]"
                  | NONE => "(" ^ code ^ ") : bool"
    in
      (if opens = "" then "(" else "let open " ^ opens ^ " in (")
      ^ claim ^ ", [" ^ String.concatWith ", " conditions ^ "] : bool list)" ^ (if opens = "" then "" else " end")
    end

  (* The variables of a law: the names it leaves unbound, found one at a time
     by elaborating `fn (x1, ..., xk) => ...` until nothing is unbound, and
     their types. A name the structure or the top level binds is not a
     variable: a misspelt member shows as a variable on the page. *)
  fun elabLaw (lib as {env, fixity} : library) (opens : string, code : string, conditions : string list, pure : string list)
      : law =
    case elabLaw' lib (opens, code, [], pure) of
      NotSml msg => NotSml msg
    | Quantified vars =>
        if List.null conditions then Quantified vars
        else
          case elabLaw' lib (opens, code, conditions, pure) of
            NotSml msg =>
              NotSml ("a condition of it (" ^ String.concatWith ", " (List.map (fn c => "`" ^ c ^ "`") conditions)
                      ^ ") is not a bool: " ^ msg)
          | q => q

  and elabLaw' (lib as {env, fixity} : library) (opens : string, code : string, conditions : string list, pure : string list)
      : law =
    let
      val expression = lawExpression fixity (opens, code, conditions)
      val unbound = "unbound variable or constructor: "
      fun attempt vars =
        if List.length vars > 16 then NotSml "it has more than 16 variables"
        else
          let
            (* what an attempt that failed left pending is not this one's *)
            val () = (Elaborate.pendingFlex := []; Elaborate.pendingChecks := [];
                      Elaborate.pendingOverloads := []; Elaborate.pendingLiterals := [])
            val source = "val it = fn (" ^ String.concatWith ", " vars ^ ") => " ^ expression
            val (prog, _) = Parser.parseTokensWith (Lexer.tokenize (Source.fromString ("<law>", source)), fixity)
            val envRef = ref env
            val () = Elaborate.elabTop (envRef, prog)
            val () = Elaborate.finish ()
            val () = Error.warnings := []
            val names = namesByStamp (lib, fn _ => true)
            fun nameOf (c : Types.tycon) = IntMap.find (names, #stamp c)
            val printer = Types.newPrinter ()
            fun show t = Types.toStringNamed (nameOf, printer) t
            val types =
              case Env.findVal (!envRef, ([], "it")) of
                SOME (Env.Val {scheme, ...}) =>
                  (case Types.prune scheme of
                     Types.TArrow (dom, _) =>
                       (case (vars, Types.prune dom) of
                          ([], _) => []
                        | ([_], t) => [t]
                        | (_, Types.TRecord fs) => List.map #2 fs
                        | (_, t) => [t])
                   | _ => [])
              | _ => []
          in
            Quantified (ListPair.map (fn (v, t) => {name = v, ty = show t,
                                                     instance = instanceOf lib (List.exists (fn f => f = v) pure) t})
                                     (vars, types))
          end
          handle Error.CompileError (_, msg) =>
            if String.isPrefix unbound msg then
              let val name = String.extract (msg, String.size unbound, NONE)
              in
                if CharVector.exists (fn c => c = #".") name orelse List.exists (fn v => v = name) vars
                then NotSml msg
                else attempt (vars @ [name])
              end
            else NotSml msg
    in
      attempt []
    end
end
