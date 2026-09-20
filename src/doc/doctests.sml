(* The checks of a test suite, found in its sources (docs/plans/docgen.md,
   D6). The convention, which tests/basis/README.md states for the suite of
   the basis library: a check is a call whose argument is a tuple that begins
   with the check's label, `Structure.member/case`; the first literal of the
   label has the structure, the member and the slash, and what follows may be
   computed (`"List.rev/involution-" ^ n`); a check of a signature is labelled
   `Structure:SIG/case`; a test functor builds its labels with
   `lab "member/case"`, where `lab` puts the `name` that the functor is given
   in front, and is applied to `val name = "Int"`, a literal. A helper or a
   table that makes several checks of one member is given the beginning of
   their labels, `"Structure.member/"`, as the first component of its argument
   or of each row. A check of a functor of the library is labelled
   `Functor/case`.

   The sources are read with the compiler's parser, so a label in a comment
   or a string that merely looks like one is not taken for a check, and what
   calls the check tells its kind: T.eq, T.raises (with the exception it
   expects), and so on, through the aliases a file defines (`val eqI = T.eq
   T.int`). A check that goes through another helper is a plain check. *)
structure DocTests =
struct
  (* label: with a * where a part is computed. scope: the structure and
     member, `List.take`, or structure and signature, `List:LIST`. via: the
     file of the test functor that the check is written in, for a check that
     an application of the functor makes. *)
  type site = {label : string, scope : string, case' : string, computed : bool,
               kind : string, exn : string option, file : string, via : string option}

  (* ---- labels ---- *)
  datatype label = Literal of string | Prefix of string     (* Prefix s: s, then something computed *)

  fun text (Literal s) = s
    | text (Prefix s) = s

  (* A label as its scope and its case: they are divided by the first slash,
     or by the second when the member is `/` itself (`Real.//basic`). *)
  fun split (s : string) : (string * string) option =
    let
      val n = String.size s
      fun find i = if i >= n then NONE else if String.sub (s, i) = #"/" then SOME i else find (i + 1)
    in
      case find 0 of
        NONE => NONE
      | SOME i =>
          let val i = if (i = 0 orelse String.sub (s, i - 1) = #".") andalso i + 1 < n andalso String.sub (s, i + 1) = #"/"
                      then i + 1 else i
          in SOME (String.substring (s, 0, i), String.extract (s, i + 1, NONE)) end
    end

  (* a string that has the shape of a label: no blanks, a scope that names a
     structure (unless a functor's `lab` will put one in front) *)
  fun isLabel (s : string, relative : bool) : bool =
    case split s of
      NONE => false
    | SOME (scope, _) =>
        scope <> "" andalso not (CharVector.exists Char.isSpace s)
        andalso (relative
                 orelse (Char.isAlpha (String.sub (scope, 0))
                         andalso CharVector.exists (fn c => c = #"." orelse c = #":") scope)
                 (* a check of a functor of the library: PrimIO/nullRd-is-empty *)
                 orelse (Char.isUpper (String.sub (scope, 0)) andalso CharVector.all Char.isAlphaNum scope))

  (* The label that an expression is: a literal, a literal with something
     appended, or `lab` applied to one of those. SOME (label, relative). *)
  fun labelOf (e : Ast.exp) : (label * bool) option =
    case e of
      Ast.EScon (Ast.SString s, _, _) => SOME (Literal s, false)
    | Ast.EApp (Ast.EVar (([], "^"), _, _), Ast.ETuple ([a, _], _), _) =>
        (case labelOf a of
           SOME (l, relative) => SOME (Prefix (text l), relative)
         | NONE => NONE)
    | Ast.EApp (Ast.EVar (([], "lab"), _, _), arg, _) =>
        (case labelOf arg of
           SOME (l, _) => SOME (l, true)
         | NONE => NONE)
    | Ast.ESeq ([e'], _) => labelOf e'
    | _ => NONE

  (* ---- what a check is called with ---- *)
  fun headOf (e : Ast.exp) : string option =
    case e of
      Ast.EApp (f, _, _) => headOf f
    | Ast.EVar (longid, _, _) => SOME (Ast.longidToString longid)
    | _ => NONE

  fun kindOfChecker (name : string) : string option =
    case name of
      "T.eq" => SOME "eq" | "T.eqReal" => SOME "eqReal" | "T.approx" => SOME "approx"
    | "T.check" => SOME "check" | "T.raises" => SOME "raises"
    | _ => NONE

  (* the exception that a predicate of the harness expects: T.isSubscript *)
  fun exnOf (e : Ast.exp) : string option =
    case e of
      Ast.EVar ((["T"], p), _, _) =>
        if String.isPrefix "is" p then SOME (String.extract (p, 2, NONE)) else if p = "anyExn" then SOME "any" else NONE
    | _ => NONE

  (* ---- walking the syntax ---- *)
  (* found (f, args, label, relative): a call f args whose first argument is a label *)
  fun walkExp found (e : Ast.exp) : unit =
    let
      val w = walkExp found
      fun rules ms = List.app (fn (_, body) => w body) ms
    in
      case e of
        Ast.EApp (f, arg, _) =>
          ((case (f, arg) of
              (Ast.EVar (([], "^"), _, _), _) => ()      (* a label being put together, not a check *)
            | (_, Ast.ETuple (first :: rest, _)) =>
                (case labelOf first of
                   SOME (l, relative) => found (f, rest, l, relative)
                 | NONE => ())
            | _ => ());
           w f; w arg)
      | Ast.ERecord (fields, _) => List.app (fn (_, x) => w x) fields
      | Ast.ETuple (es, _) => List.app w es
        (* a table of checks: every row begins with the beginning of its
           labels, "Structure.member/" *)
      | Ast.EList (es, _) =>
          List.app (fn row =>
                      ((case row of
                          Ast.ETuple (first :: _, _) =>
                            (case labelOf first of
                               SOME (l as Literal s, relative) =>
                                 if String.isSuffix "/" s then found (Ast.ETuple ([], Source.noSpan), [], l, relative) else ()
                             | _ => ())
                        | _ => ());
                       w row)) es
      | Ast.ESeq (es, _) => List.app w es
      | Ast.ELet (decs, body, _) => (List.app (walkDec found) decs; w body)
      | Ast.ETyped (x, _, _) => w x
      | Ast.EAndalso (a, b, _) => (w a; w b)
      | Ast.EOrelse (a, b, _) => (w a; w b)
      | Ast.EHandle (x, ms, _) => (w x; rules ms)
      | Ast.ERaise (x, _) => w x
      | Ast.EIf (a, b, c, _) => (w a; w b; w c)
      | Ast.EWhile (a, b, _) => (w a; w b)
      | Ast.ECase (x, ms, _) => (w x; rules ms)
      | Ast.EFn (ms, _) => rules ms
      | _ => ()
    end

  and walkDec found (d : Ast.dec) : unit =
    case d of
      Ast.DVal (_, binds, _) => List.app (fn (_, e) => walkExp found e) binds
    | Ast.DValRec (_, binds, _) => List.app (fn (_, e) => walkExp found e) binds
    | Ast.DFun (_, defs, _) => List.app (fn {clauses, ...} => List.app (fn {body, ...} => walkExp found body) clauses) defs
    | Ast.DAbstype (_, _, decs, _) => List.app (walkDec found) decs
    | Ast.DLocal (a, b, _) => (List.app (walkDec found) a; List.app (walkDec found) b)
    | Ast.DStructure (binds, _) => List.app (fn {strexp, ...} => walkStrexp found strexp) binds
    | _ => ()

  and walkStrexp found (e : Ast.strexp) : unit =
    case e of
      Ast.StrStruct (decs, _) => List.app (walkDec found) decs
    | Ast.StrAscribe (e', _, _, _) => walkStrexp found e'
    | Ast.StrLet (decs, e', _) => (List.app (walkDec found) decs; walkStrexp found e')
    | _ => ()

  (* The aliases of the checkers that some declarations define: `val eqI =
     T.eq T.int`. *)
  fun aliases (decs : Ast.dec list) : (string * string) list =
    List.concat
      (List.map (fn Ast.DVal (_, binds, _) =>
                      List.mapPartial (fn (Ast.PVar (([], x), _, _), rhs) =>
                                            Option.map (fn k => (x, k)) (Option.mapPartial kindOfChecker (headOf rhs))
                                        | _ => NONE) binds
                  | Ast.DLocal (a, b, _) => aliases a @ aliases b
                  | Ast.DStructure (binds, _) =>
                      List.concat (List.map (fn {strexp = Ast.StrStruct (ds, _), ...} => aliases ds | _ => []) binds)
                  | _ => [])
                decs)

  (* The check sites of some declarations. relativeTo: NONE in a test file,
     where a label names its structure; SOME "" in a functor, where `lab`
     leaves the name open. *)
  fun sitesOf (file : string, decs : Ast.dec list) : (site * bool) list =
    let
      val known = aliases decs
      val sites = ref []
      fun found (f, rest, l, relative) =
        if not (isLabel (text l, relative)) then ()
        else
          let
            val head = headOf f
            val kind = case Option.mapPartial kindOfChecker head of
                         SOME k => k
                       | NONE => (case head of
                                    SOME h => (case List.find (fn (x, _) => x = h) known of SOME (_, k) => k | NONE => "check")
                                  | NONE => "check")
            val s = text l
            val (scope, rest') = Option.getOpt (split s, (s, ""))
            (* a label that stops at its slash is the beginning of the labels
               that a helper or a table makes *)
            val computed = (case l of Prefix _ => true | Literal _ => false) orelse rest' = ""
          in
            sites := ({label = s ^ (if computed then "*" else ""), scope = scope, case' = rest' ^ (if computed then "*" else ""),
                       computed = computed, kind = kind,
                       exn = (if kind = "raises" then (case rest of p :: _ => exnOf p | [] => NONE) else NONE),
                       file = file, via = NONE}, relative) :: !sites
          end
    in
      List.app (walkDec found) decs;
      List.rev (!sites)
    end

  (* ---- a suite ---- *)
  fun parse (path : string) : Ast.program =
    #1 (Parser.parseTokensWith (Lexer.tokenize (Source.load path), Fixity.initial))

  fun filesOf (dir : string) : string list =
    let
      val d = OS.FileSys.openDir dir
      fun entries acc = case OS.FileSys.readDir d of SOME n => entries (n :: acc) | NONE => (OS.FileSys.closeDir d; acc)
      fun insert (x : string, []) = [x]
        | insert (x, y :: ys) = if x < y then x :: y :: ys else y :: insert (x, ys)
    in
      List.foldl insert [] (List.filter (fn n => String.isSuffix ".sml" n) (entries []))
    end
    handle OS.SysErr _ => []

  (* The name that a functor application gives: `val name = "Int"` among the
     declarations of its argument. *)
  fun nameOf (arg : Ast.strexp) : string option =
    case arg of
      Ast.StrStruct (decs, _) =>
        List.foldl (fn (Ast.DVal (_, binds, _), acc) =>
                        List.foldl (fn ((Ast.PVar (([], "name"), _, _), Ast.EScon (Ast.SString s, _, _)), _) => SOME s
                                     | (_, acc) => acc) acc binds
                     | (_, acc) => acc)
                   NONE decs
    | _ => NONE

  (* Every check site of the suite in dir: those of its test programs, and
     for every application of a test functor of dir/fn those of the functor,
     under the name the application gives. *)
  fun suite (dir : string) : site list =
    let
      val functors : (string * string * site list) list ref = ref []     (* functor, file, its relative sites *)
      val () =
        List.app (fn n =>
                    let val file = dir ^ "/fn/" ^ n
                    in
                      List.app (fn Ast.DFunctor (binds, _) =>
                                     List.app (fn {name, body, ...} =>
                                                 let
                                                   val decs = case body of
                                                                Ast.StrStruct (ds, _) => ds
                                                              | Ast.StrAscribe (Ast.StrStruct (ds, _), _, _, _) => ds
                                                              | _ => []
                                                 in
                                                   functors := (name, file,
                                                                List.mapPartial (fn (s, relative) => if relative then SOME s else NONE)
                                                                                (sitesOf (file, decs))) :: !functors
                                                 end) binds
                                 | _ => ()) (parse file)
                    end)
                 (filesOf (dir ^ "/fn"))
      fun applications (file, decs) : site list =
        List.concat
          (List.map (fn Ast.DStructure (binds, _) =>
                          List.concat
                            (List.map (fn {strexp, ...} =>
                                         (case strexp of
                                            Ast.StrApp (f, arg, _, _) =>
                                              (case (List.find (fn (n, _, _) => n = f) (!functors), nameOf arg) of
                                                 (SOME (_, ffile, sites), SOME name) =>
                                                   List.map (fn s : site =>
                                                               {label = name ^ "." ^ #label s, scope = name ^ "." ^ #scope s,
                                                                case' = #case' s, computed = #computed s, kind = #kind s,
                                                                exn = #exn s, file = file, via = SOME ffile}) sites
                                               | _ => [])
                                          | Ast.StrStruct (ds, _) => applications (file, ds)
                                          | _ => []))
                                      binds)
                      | Ast.DLocal (a, b, _) => applications (file, a) @ applications (file, b)
                      | _ => [])
                    decs)
    in
      List.concat
        (List.map (fn n =>
                     let
                       val file = dir ^ "/" ^ n
                       val decs = parse file
                     in
                       List.mapPartial (fn (s, relative) => if relative then NONE else SOME s) (sitesOf (file, decs))
                       @ applications (file, decs)
                     end)
                  (List.filter (fn n => n <> "harness.sml" andalso n <> "finish.sml") (filesOf dir)))
    end

  (* label, kind, exception, file, functor file *)
  fun tsv (sites : site list) : string =
    String.concat
      ("label\tkind\texception\tfile\tfunctor\n"
       :: List.map (fn s : site =>
                      String.concatWith "\t" [#label s, #kind s, Option.getOpt (#exn s, ""), #file s, Option.getOpt (#via s, "")] ^ "\n")
                   sites)
end
