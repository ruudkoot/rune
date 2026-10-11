(* The printers of the REPL (docs/repl.md, Printing; the incremental roadmap's
   D10): for each value a declaration binds, SML text that shows it, made
   from the type the elaborator gave it and compiled with the declaration,
   so that the back end represents the printer's values as it represents the
   value's own and the printer never reads a value's bits.

   A printer is an expression of type `int -> t -> RuneCompiler.pretty`, the
   depth left and the value to a document with the roles of its parts,
   built from the pieces of RuneShow (lib/basis/compiler.sml), which the
   REPL lays out (docs/plans/repl.md, D16).
   A datatype gets a function per type it is shown at, all of them one
   recursive group, which matches its constructors by names of their own:
   `rune'c<stamp>'<tag>`, bound in the environment the printer is elaborated
   in to the constructors the elaborator registered (Elaborate.dataCons), so
   that a datatype whose constructors are out of scope still shows them. An
   abstract type, a type variable and a function show as `?`, `?` and `fn`.
   A type is named by the shortest path that names it in the session, and
   `?.t` where none does, as SML/NJ names one a later declaration hid. *)
structure ReplShow =
struct
  open Types

  (* What the printers of one declaration need beyond its environment: the
     constructors they name, and the functions of the datatypes they made,
     by datatype and type, in the order they were made. *)
  type gen = {env : Env.env,                           (* the session, which names types *)
              cons : Env.valstatus StringMap.map ref,
              funs : (string * string) list ref,      (* name, text of its clause *)
              made : string StringMap.map ref,         (* the datatype at its arguments -> name *)
              count : int ref}

  fun newGen (env : Env.env) : gen =
    {env = env, cons = ref StringMap.empty, funs = ref [], made = ref StringMap.empty, count = ref 0}

  fun isTuple (fields : (string * ty) list) =
    List.length fields >= 2
    andalso #2 (List.foldl (fn ((l, _), (i, ok)) => (i + 1, ok andalso l = Int.toString i)) (1, true) fields)

  (* the type with the generic variables of a scheme replaced *)
  fun subst (m : ty IntMap.map) (t : ty) : ty =
    case prune t of
      TVar (r as ref (Unbound {id, ...})) => (case IntMap.find (m, id) of SOME u => u | NONE => TVar r)
    | TVar r => TVar r
    | TCon (c, args) => TCon (c, List.map (subst m) args)
    | TRecord fs => TRecord (List.map (fn (l, a) => (l, subst m a)) fs)
    | TArrow (a, b) => TArrow (subst m a, subst m b)

  (* a constructor's argument at the datatype's arguments *)
  fun argAt (scheme : ty, args : ty list) : ty option =
    case prune scheme of
      TArrow (a, res) =>
        (case prune res of
           TCon (_, ps) =>
             let
               val m = ListPair.foldl (fn (p, u, m) => case prune p of
                                                         TVar (ref (Unbound {id, ...})) => IntMap.insert (m, id, u)
                                                       | _ => m) IntMap.empty (ps, args)
             in SOME (subst m a) end
         | _ => SOME a)
    | _ => NONE

  fun quote s = "\"" ^ String.toString s ^ "\""

  (* ---- the names of types in the session ---- *)

  (* the type constructor a type structure is, or abbreviates with its
     parameters in order *)
  fun tyconOf (Env.TyStr {fcn, ...}) = Option.map #stamp (fcnIsName fcn)

  (* the environment of the structure at a path *)
  fun structureAt (env : Env.env, path : string list) : Env.env option =
    case path of
      [] => SOME env
    | p :: rest => (case StringMap.find (Env.strs env, p) of SOME e => structureAt (e, rest) | NONE => NONE)

  (* the shortest path that names the type constructor in the session: its
     own name at the top where that is it, else the structures breadth
     first, a path that ends in its own name before one that does not, then
     the first in order; NONE where none does *)
  fun pathOf (env : Env.env, c : tycon) : string option =
    let
      val stamp = #stamp c
      fun named e n = case StringMap.find (Env.tys e, n) of SOME ts => tyconOf ts = SOME stamp | NONE => false
      fun search ([], _) = NONE
        | search (_, 0) = NONE
        | search (level : (string * Env.env) list, depth : int) =
            let
              fun own (p, e) = if named e (#name c) then SOME (p ^ #name c) else NONE
              fun other (p, e) =
                StringMap.foldli (fn (n, ts, found) => case found of
                                                         SOME _ => found
                                                       | NONE => if tyconOf ts = SOME stamp then SOME (p ^ n) else NONE)
                                 NONE (Env.tys e)
              (* the library's own structures (Rune...) after the others *)
              fun private p = String.isPrefix "Rune" p orelse String.isPrefix "RUNE" p
              fun firstOf f =
                case List.mapPartial f level of
                  [] => NONE
                | found => SOME (case List.filter (not o private) found of p :: _ => p | [] => hd found)
            in
              case firstOf own of
                SOME p => SOME p
              | NONE =>
                  case firstOf other of
                    SOME p => SOME p
                  | NONE =>
                      search (List.concat (List.map (fn (p, e) => StringMap.foldri (fn (n, s, acc) => (p ^ n ^ ".", s) :: acc)
                                                                                    [] (Env.strs e)) level),
                              depth - 1)
            end
    in
      if named env (#name c) then SOME (#name c) else search ([("", env)], 5)
    end

  (* a type as the session names it *)
  fun typeIn (env : Env.env) (t : ty) : string =
    let
      val memo : string IntMap.map ref = ref IntMap.empty
      fun nameOf (c : tycon) =
        case IntMap.find (!memo, #stamp c) of
          SOME n => SOME n
        | NONE =>
            let val n = case pathOf (env, c) of SOME p => p | NONE => "?." ^ #name c
            in memo := IntMap.insert (!memo, #stamp c, n); SOME n end
    in toStringNamed (nameOf, newPrinter ()) t end

  (* ---- signatures, as the REPL shows a structure's ---- *)

  fun params (k : int) : string =
    case k of
      0 => ""
    | 1 => "'a "
    | _ => "(" ^ String.concatWith ", " (List.tabulate (k, fn i => "'" ^ String.str (Char.chr (97 + i)))) ^ ") "

  (* a type's specification: a datatype with its constructors, an
     abbreviation with what it stands for, else the type alone *)
  fun typeSpec (env : Env.env) (name : string, ts as Env.TyStr {fcn, cons}) : string =
    case (fcn, cons) of
      (_, _ :: _) =>
        "datatype " ^ params (fcnArity fcn) ^ name ^ " = "
        ^ String.concatWith " | "
            (List.map (fn (n, Env.Con {scheme, info}) =>
                            if #hasArg info then
                              (case prune scheme of TArrow (a, _) => n ^ " of " ^ typeIn env a | _ => n)
                            else n
                        | (n, _) => n) cons)
    | (TAbbrev (ps, body), []) =>
        (case fcnIsName fcn of
           SOME c => if #name c = name then "type " ^ params (List.length ps) ^ name
                     else "type " ^ params (List.length ps) ^ name ^ " = " ^ typeIn env body
         | NONE => "type " ^ params (List.length ps) ^ name ^ " = " ^ typeIn env body)
    | (TName c, []) => (if #eq c then "eqtype " else "type ") ^ params (#arity c) ^ name

  (* the specifications of a structure's environment, each line indented *)
  fun signatureLines (env : Env.env, e : Env.env, indent : string) : string list =
    let
      val tys = StringMap.foldri (fn (n, ts, acc) => (indent ^ typeSpec env (n, ts)) :: acc) [] (Env.tys e)
      val vals =
        StringMap.foldri
          (fn (n, Env.Val {scheme, ...}, acc) => (indent ^ "val " ^ n ^ " : " ^ typeIn env scheme) :: acc
            | (n, Env.Prim {scheme, ...}, acc) => (indent ^ "val " ^ n ^ " : " ^ typeIn env scheme) :: acc
            | (n, Env.ConAsVal {scheme, ...}, acc) => (indent ^ "val " ^ n ^ " : " ^ typeIn env scheme) :: acc
            | (n, Env.Exn {ty, info}, acc) =>
                (indent ^ "exception " ^ n
                 ^ (if #hasArg info then case prune ty of TArrow (a, _) => " of " ^ typeIn env a | _ => "" else "")) :: acc
            | (n, Env.ExnAsVal {ty, ...}, acc) => (indent ^ "val " ^ n ^ " : " ^ typeIn env ty) :: acc
            | (_, Env.Con _, acc) => acc)
          [] (Env.vals e)
      val strs =
        StringMap.foldri (fn (n, s, acc) => (indent ^ "structure " ^ n ^ " :") :: (indent ^ "  sig")
                                            :: signatureLines (env, s, indent ^ "    ") @ [indent ^ "  end"] @ acc)
                         [] (Env.strs e)
    in tys @ vals @ strs end

  (* A type the session names S.t, of no arguments, whose structure has
     S.toString : t -> string, prints by it: Word8.word, IntInf.int,
     Time.time; a word with 0wx before it, as a word prints *)
  fun shownBy (env : Env.env, c : tycon, args : ty list) : string option =
    case (args, pathOf (env, c)) of
      ([], SOME path) =>
        let
          val parts = String.fields (fn ch => ch = #".") path
          val structure' = List.take (parts, List.length parts - 1)
        in
          if List.null structure' then NONE
          else
            case Option.mapPartial (fn e => StringMap.find (Env.vals e, "toString"))
                                   (structureAt (env, structure')) of
              SOME (Env.Val {scheme, ...}) =>
                (case prune scheme of
                   TArrow (a, r) =>
                     (case (prune a, prune r) of
                        (TCon (c', []), TCon (s, [])) =>
                          if #stamp c' = #stamp c andalso #stamp s = #stamp stringTycon then
                            let
                              val name = String.concatWith "." structure' ^ ".toString"
                              val word = String.isPrefix "Word" (List.last structure') orelse List.last structure' = "LargeWord"
                                         orelse List.last structure' = "SysWord"
                              val numeric = word orelse String.isPrefix "Int" (List.last structure')
                                            orelse List.last structure' = "LargeInt" orelse String.isPrefix "Real" (List.last structure')
                                            orelse List.last structure' = "LargeReal"
                            in
                              SOME ("(fn _ => fn x => RuneShow.role (" ^ (if numeric then "\"syn.number\"" else "\"text\"")
                                    ^ ", " ^ (if word then "\"0wx\" ^ " else "") ^ name ^ " x))")
                            end
                          else NONE
                      | _ => NONE)
                 | _ => NONE)
            | _ => NONE
        end
    | _ => NONE

  (* SML text of an `int -> t -> RuneCompiler.pretty` printer for t *)
  fun printer (g : gen, t : ty) : string =
    case prune t of
      TVar _ => "RuneShow.hidden"
    | TArrow _ => "RuneShow.function"
    | TRecord [] => "RuneShow.unit"
    | TRecord fields =>
        if isTuple fields then
          "(fn d => fn v => RuneShow.tuple d ["
          ^ String.concatWith ", " (List.map (fn (l, a) => "fn d => " ^ printer (g, a) ^ " d (#" ^ l ^ " v)") fields)
          ^ "])"
        else
          "(fn d => fn v => RuneShow.record d ["
          ^ String.concatWith ", "
              (List.map (fn (l, a) => "(" ^ quote l ^ ", fn d => " ^ printer (g, a) ^ " d (#" ^ l ^ " v))") fields)
          ^ "])"
    | TCon (c, args) =>
        let val s = #stamp c
        in
          case Option.mapPartial (fn k => (Usage.use ("p", k); if RuneShow.hasPrinter k then SOME k else NONE))
                                 (UnitBasis.stableName (UnitBasis.kTycon, s)) of
            SOME key => installed (g, key, args)
          | NONE =>
          if s = #stamp intTycon then "RuneShow.int"
          else if s = #stamp wordTycon then "RuneShow.word"
          else if s = #stamp realTycon then "RuneShow.real"
          else if s = #stamp charTycon then "RuneShow.char"
          else if s = #stamp stringTycon then "RuneShow.string"
          else if s = #stamp exnTycon then "RuneShow.exn"
          else if s = #stamp boolTycon then "(fn _ => fn b => RuneShow.con0 (if b then \"true\" else \"false\"))"
          else
            case (s = #stamp listTycon, s = #stamp refTycon, s = #stamp arrayTycon, s = #stamp vectorTycon, args) of
              (true, _, _, _, [a]) => "(RuneShow.list " ^ printer (g, a) ^ ")"
            | (_, true, _, _, [a]) => "(RuneShow.reference " ^ printer (g, a) ^ ")"
            | (_, _, true, _, [a]) => "(RuneShow.array " ^ printer (g, a) ^ ")"
            | (_, _, _, true, [a]) => "(RuneShow.vector " ^ printer (g, a) ^ ")"
            | _ =>
                case IntMap.find (!Elaborate.dataCons, s) of
                  SOME cons => datatypeAt (g, c, cons, args)
                | NONE => case shownBy (#env g, c, args) of SOME p => p | NONE => "RuneShow.hidden"
        end

  (* the printer Compiler.addPrettyPrinter installed for the type key
     names, given how to show the type's arguments: () for none, a function
     for one, a tuple of them for more *)
  and installed (g : gen, key : string, args : ty list) : string =
    let
      fun one a = "RuneShow.argument " ^ printer (g, a)
      val shown =
        case args of
          [] => "()"
        | [a] => one a
        | _ => "(" ^ String.concatWith ", " (List.map one args) ^ ")"
    in "(RuneShow.installed (" ^ quote key ^ ", " ^ shown ^ "))" end

  (* the function that shows the datatype c at args, made once *)
  and datatypeAt (g : gen, c : tycon, cons : (string * Env.valstatus) list, args : ty list) : string =
    let val key = Int.toString (#stamp c) ^ ":" ^ String.concatWith "," (List.map toString args)
    in
      case StringMap.find (!(#made g), key) of
        SOME name => name
      | NONE =>
          if !(#count g) >= 64 then "RuneShow.hidden"    (* a datatype nested without end at ever larger types *)
          else
            let
              val name = "rune's" ^ Int.toString (!(#count g))
              val () = #count g := !(#count g) + 1
              val () = #made g := StringMap.insert (!(#made g), key, name)
              fun clause (cname, v) =
                case v of
                  Env.Con {scheme, info} =>
                    let
                      val synth = "rune'c" ^ Int.toString (#stamp c) ^ "'" ^ Int.toString (#tag info)
                      val () = #cons g := StringMap.insert (!(#cons g), synth, v)
                    in
                      if #hasArg info then
                        case argAt (scheme, args) of
                          SOME a => synth ^ " a => RuneShow.con1 d (" ^ quote cname ^ ", fn d => " ^ printer (g, a) ^ " d a)"
                        | NONE => synth ^ " _ => " ^ quote cname
                      else synth ^ " => RuneShow.con0 " ^ quote cname
                    end
                | _ => "_ => \"?\""
              val body = "fn d => fn v => case v of " ^ String.concatWith " | " (List.map clause cons)
            in
              #funs g := (name, body) :: !(#funs g);
              name
            end
    end

  fun valueName n = if CharVector.all (fn c => Char.isAlphaNum c orelse c = #"_" orelse c = #"'") n then n
                    else "(op " ^ n ^ ")"

  (* the exception constructors with an argument a declaration declared, at
     their paths, with the argument's type *)
  fun exceptions (delta : Env.env) : (string * string * ty) list =
    let
      fun go (prefix, e) =
        StringMap.foldri (fn (n, Env.Exn {ty, info}, acc) =>
                              if #hasArg info then
                                case prune ty of TArrow (a, _) => (prefix ^ valueName n, n, a) :: acc | _ => acc
                              else acc
                            | (_, _, acc) => acc) [] (Env.vals e)
        @ List.concat (StringMap.foldri (fn (n, s, acc) => go (prefix ^ n ^ ".", s) :: acc) [] (Env.strs e))
    in go ("", delta) end

  (* The text of the declaration that echoes the values bound and registers
     the printers of the exceptions declared, and the environment it is
     elaborated in beside the session's: the constructors it names. NONE
     where there is nothing to do. echo says whether the values are shown;
     env is the session after the declaration, which names the types. *)
  fun echoes (env : Env.env, bound : (string * ty) list, delta : Env.env, echo : bool) : (string * Env.env) option =
    case (if echo then bound else [], exceptions delta) of
      ([], []) => NONE
    | (bound, exns) =>
        let
          val g = newGen env
          val lines =
            List.map (fn (n, t) =>
                        "val () = RuneShow.echo (" ^ quote n ^ ", fn () => " ^ printer (g, t) ^ " (!RuneCompiler.printDepth) "
                        ^ valueName n ^ ", " ^ quote (typeIn env t) ^ ")") bound
            @ List.map (fn (path, n, a) =>
                          "val () = RuneShow.addExn (fn d => fn e => case e of " ^ path ^ " a => SOME (RuneShow.con1 d ("
                          ^ quote n ^ ", fn d => " ^ printer (g, a) ^ " d a)) | _ => NONE)") exns
          val funs = List.rev (!(#funs g))
          val group =
            case funs of
              [] => ""
            | _ => "val rec " ^ String.concatWith " and " (List.map (fn (n, b) => n ^ " = " ^ b) funs) ^ " "
          val text = "local " ^ group ^ "in " ^ String.concatWith " " lines ^ " end"
          val env = StringMap.foldli (fn (n, v, e) => Env.bindVal (e, n, v)) Env.empty (!(#cons g))
        in SOME (text, env) end
end
