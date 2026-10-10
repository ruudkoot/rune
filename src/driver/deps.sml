(* The dependency graph of a group of files (the incremental roadmap's M8;
   D15): for each file, the module-level names it declares and the ones it
   uses that it does not declare, found in its syntax; the discipline that
   makes those names say the order (CM's: a file's top-level declarations
   declare structures, signatures, functors -- and, for the Basis Library,
   type abbreviations and overloading -- and none opens a structure or
   declares a value, an exception or a fixity, which a use names without a
   structure); and the order of the group, where a name declared twice or
   a cycle is refused.

   A name is of one of four kinds: a structure, a signature, a functor, or
   a type -- a type at the top level, named without a structure. A use is
   the first structure of a long name (A in A.B.x), a signature's or a
   functor's name, or a type's without a structure, where no declaration in
   scope binds it: a structure, a functor's parameter, a specification of a
   signature, a type of a let. After an `open` inside a structure, a name
   may be one of what was opened: the analysis does not know, and counts it
   as a use where a file of the group declares it. *)
structure Deps =
struct
  open Ast

  datatype kind = Str | Sig | Fun | Tycon
  type name = kind * string

  fun kindName k = case k of Str => "structure" | Sig => "signature" | Fun => "functor" | Tycon => "type"
  fun key ((k, n) : name) = kindName k ^ " " ^ n

  (* what a file is to the graph *)
  type file = {path : string, declares : name list, uses : name list, breaks : (span * string) list}

  (* ---- the names of a file ---- *)

  (* the names in scope, by kind *)
  type scope = {strs : unit StringMap.map, tys : unit StringMap.map}
  val empty : scope = {strs = StringMap.empty, tys = StringMap.empty}
  fun bindStr ({strs, tys} : scope, n) : scope = {strs = StringMap.insert (strs, n, ()), tys = tys}
  fun bindTy ({strs, tys} : scope, n) : scope = {strs = strs, tys = StringMap.insert (tys, n, ())}

  fun analyse (path : string, prog : program) : file =
    let
      val uses : unit StringMap.map ref = ref StringMap.empty
      fun use (k, n) = uses := StringMap.insert (!uses, key (k, n), ())
      fun longStr (sc : scope, (p, _) : longid) =
        case p of
          s :: _ => if StringMap.member (#strs sc, s) then () else use (Str, s)
        | [] => ()
      fun longTy (sc : scope, id as (p, n) : longid) =
        case p of
          [] => if StringMap.member (#tys sc, n) then () else use (Tycon, n)
        | _ => longStr (sc, id)
      fun ty (sc, t) =
        case t of
          TyVar _ => ()
        | TyRecord (fs, _) => List.app (fn (_, t) => ty (sc, t)) fs
        | TyTuple (ts, _) => List.app (fn t => ty (sc, t)) ts
        | TyCon (args, id, _) => (List.app (fn t => ty (sc, t)) args; longTy (sc, id))
        | TyArrow (a, b, _) => (ty (sc, a); ty (sc, b))
      fun pat (sc, p) =
        case p of
          PVar (id, _, _) => longStr (sc, id)
        | PRecord (fs, _, _, _) => List.app (fn (_, p) => pat (sc, p)) fs
        | PTuple (ps, _) => List.app (fn p => pat (sc, p)) ps
        | PList (ps, _) => List.app (fn p => pat (sc, p)) ps
        | PApp (id, _, p, _) => (longStr (sc, id); pat (sc, p))
        | PTyped (p, t, _) => (pat (sc, p); ty (sc, t))
        | PLayered (_, t, p, _, _) => (Option.app (fn t => ty (sc, t)) t; pat (sc, p))
        | _ => ()
      fun exp (sc, e) =
        case e of
          EVar (id, _, _) => longStr (sc, id)
        | ERecord (fs, _) => List.app (fn (_, e) => exp (sc, e)) fs
        | ETuple (es, _) => List.app (fn e => exp (sc, e)) es
        | EList (es, _, _) => List.app (fn e => exp (sc, e)) es
        | ESeq (es, _) => List.app (fn e => exp (sc, e)) es
        | ELet (ds, e, _) => exp (decs (sc, ds), e)
        | EApp (f, a, _) => (exp (sc, f); exp (sc, a))
        | ETyped (e, t, _) => (exp (sc, e); ty (sc, t))
        | EAndalso (a, b, _) => (exp (sc, a); exp (sc, b))
        | EOrelse (a, b, _) => (exp (sc, a); exp (sc, b))
        | EHandle (e, rs, _) => (exp (sc, e); rules (sc, rs))
        | ERaise (e, _) => exp (sc, e)
        | EIf (a, b, c, _) => (exp (sc, a); exp (sc, b); exp (sc, c))
        | EWhile (a, b, _) => (exp (sc, a); exp (sc, b))
        | ECase (e, rs, _) => (exp (sc, e); rules (sc, rs))
        | EFn (rs, _, _) => rules (sc, rs)
        | EPrim (_, t, _, _) => ty (sc, t)
        | _ => ()
      and rules (sc, rs) = List.app (fn (p, e) => (pat (sc, p); exp (sc, e))) rs
      (* a declaration's uses, and the scope after it *)
      and dec (sc : scope, d : dec) : scope =
        case d of
          DVal (_, bs, _) => (List.app (fn (p, e) => (pat (sc, p); exp (sc, e))) bs; sc)
        | DValRec (_, bs, _) => (List.app (fn (p, e) => (pat (sc, p); exp (sc, e))) bs; sc)
        | DFun (_, fs, _) =>
            (List.app (fn (f : fundef) =>
                         List.app (fn {pats, resty, body} =>
                                     (List.app (fn p => pat (sc, p)) pats; Option.app (fn t => ty (sc, t)) resty;
                                      exp (sc, body)))
                                  (#clauses f)) fs;
             sc)
        | DType (tbs, _) =>
            (List.app (fn (b : typbind) => ty (sc, #ty b)) tbs; List.foldl (fn (b : typbind, sc) => bindTy (sc, #name b)) sc tbs)
        | DDatatype (dbs, tbs, _) =>
            let val sc' = List.foldl (fn (b : datbind, sc) => bindTy (sc, #name b)) sc dbs
            in
              List.app (fn (b : datbind) => List.app (fn (_, t, _) => Option.app (fn t => ty (sc', t)) t) (#cons b)) dbs;
              List.app (fn (b : typbind) => ty (sc', #ty b)) tbs;
              List.foldl (fn (b : typbind, sc) => bindTy (sc, #name b)) sc' tbs
            end
        | DDatatypeRepl (n, id, _) => (longTy (sc, id); bindTy (sc, n))
        | DAbstype (dbs, tbs, ds, sp) =>
            let val sc' = dec (sc, DDatatype (dbs, tbs, sp)) in decs (sc', ds) end
        | DException (bs, _) =>
            (List.app (fn ExnDecl (_, t, _, _) => Option.app (fn t => ty (sc, t)) t | ExnRepl (_, id, _, _) => longStr (sc, id)) bs;
             sc)
        | DLocal (a, b, _) => decs (decs (sc, a), b)
        | DOpen (ids, _) => (List.app (fn (p, n) => longStr (sc, (p @ [n], ""))) ids; sc)
        | DOverload {strid, ...} => (case strid of s :: _ => longStr (sc, ([s], "")) | [] => (); sc)
        | DStructure (bs, _) =>
            (List.app (fn (b : strbind) => strexp (sc, #strexp b)) bs; List.foldl (fn (b : strbind, sc) => bindStr (sc, #name b)) sc bs)
        | DSignature (bs, _) => (List.app (fn (b : sigbind) => ignore (sigexp (sc, #sigexp b))) bs; sc)
        | DFunctor (bs, _) =>
            (List.app (fn (b : funbind) =>
                         let
                           val inner = sigexp (sc, #paramSig b)
                           val sc' = case #param b of
                                       SOME x => bindStr (sc, x)
                                     | NONE => {strs = StringMap.unionWith #1 (#strs inner, #strs sc),
                                                tys = StringMap.unionWith #1 (#tys inner, #tys sc)}
                         in strexp (sc', #body b) end) bs;
             sc)
        | _ => sc
      and decs (sc, ds) = List.foldl (fn (d, sc) => dec (sc, d)) sc ds
      and strexp (sc, se) =
        case se of
          StrStruct (ds, _) => ignore (decs (sc, ds))
        | StrId ((p, n), _) => longStr (sc, (p @ [n], ""))
        | StrAscribe (se, sg, _, _) => (strexp (sc, se); ignore (sigexp (sc, sg)))
        | StrApp (f, arg, _, _) => (use (Fun, f); strexp (sc, arg))
        | StrLet (ds, se, _) => strexp (decs (sc, ds), se)
        | StrDynamic (_, sg, _, _) => ignore (sigexp (sc, sg))
        | StrExport (sg, se, _, _) => (ignore (sigexp (sc, sg)); strexp (sc, se))
      (* a signature's uses, and the names its specifications bind *)
      and sigexp (sc, sg) : scope =
        case sg of
          SigSig (specs, _) => List.foldl (fn (s, inner) => spec (sc, inner, s)) empty specs
        | SigId (n, _) => (use (Sig, n); empty)
        | SigWhere (sg, clauses, _) =>
            let val inner = sigexp (sc, sg)
            in List.app (fn (_, _, t, _) => ty (sc, t)) clauses; inner end
      and spec (sc : scope, inner : scope, s : spec) : scope =
        let
          (* a specification sees the outer scope and the specifications before it *)
          val here = {strs = StringMap.unionWith #1 (#strs inner, #strs sc), tys = StringMap.unionWith #1 (#tys inner, #tys sc)}
        in
          case s of
            SpecVal (ds, _) => (List.app (fn (_, t, _) => ty (here, t)) ds; inner)
          | SpecType (ds, _) => List.foldl (fn ((_, n, _), i) => bindTy (i, n)) inner ds
          | SpecEqtype (ds, _) => List.foldl (fn ((_, n, _), i) => bindTy (i, n)) inner ds
          | SpecDatatype (dbs, _) =>
              let val inner' = List.foldl (fn (b : datbind, i) => bindTy (i, #name b)) inner dbs
                  val here' = List.foldl (fn (b : datbind, h) => bindTy (h, #name b)) here dbs
              in List.app (fn (b : datbind) => List.app (fn (_, t, _) => Option.app (fn t => ty (here', t)) t) (#cons b)) dbs;
                 inner'
              end
          | SpecDatatypeRepl (n, id, _) => (longTy (here, id); bindTy (inner, n))
          | SpecException (ds, _) => (List.app (fn (_, t, _) => Option.app (fn t => ty (here, t)) t) ds; inner)
          | SpecStructure (ds, _) => List.foldl (fn ((n, sg, _), i) => (ignore (sigexp (here, sg)); bindStr (i, n))) inner ds
          | SpecInclude (sg, _) =>
              let val i' = sigexp (here, sg)
              in {strs = StringMap.unionWith #1 (#strs i', #strs inner), tys = StringMap.unionWith #1 (#tys i', #tys inner)} end
          | SpecSharingType _ => inner
          | SpecSharing _ => inner
        end
      (* the top level: what the file declares, and where it breaks the
         discipline *)
      val declares : name list ref = ref []
      val breaks : (span * string) list ref = ref []
      fun declare (k, n) = if List.exists (fn x => x = (k, n)) (!declares) then () else declares := (k, n) :: !declares
      fun broken (d, what) = breaks := (spanOfDec d, what) :: !breaks
      fun top (sc, d, exported) =
        case d of
          DStructure (bs, _) => (if exported then List.app (fn (b : strbind) => declare (Str, #name b)) bs else (); dec (sc, d))
        | DSignature (bs, _) => (if exported then List.app (fn (b : sigbind) => declare (Sig, #name b)) bs else (); dec (sc, d))
        | DFunctor (bs, _) => (if exported then List.app (fn (b : funbind) => declare (Fun, #name b)) bs else (); dec (sc, d))
        | DType (bs, _) => (if exported then List.app (fn (b : typbind) => declare (Tycon, #name b)) bs else (); dec (sc, d))
        | DOverload _ => dec (sc, d)
        | DLocal (a, b, _) =>
            let val sc' = List.foldl (fn (d, sc) => top (sc, d, false)) sc a
            in List.foldl (fn (d, sc) => top (sc, d, exported)) sc' b end
        | DVal _ => (broken (d, "a value"); dec (sc, d))
        | DValRec _ => (broken (d, "a value"); dec (sc, d))
        | DFun _ => (broken (d, "a function"); dec (sc, d))
        | DDatatype _ => (broken (d, "a datatype, whose constructors are values"); dec (sc, d))
        | DDatatypeRepl _ => (broken (d, "a datatype, whose constructors are values"); dec (sc, d))
        | DAbstype _ => (broken (d, "an abstype"); dec (sc, d))
        | DException _ => (broken (d, "an exception"); dec (sc, d))
        | DOpen _ => (broken (d, "an open"); dec (sc, d))
        | DInfix _ => (broken (d, "a fixity directive"); dec (sc, d))
        | DInfixr _ => (broken (d, "a fixity directive"); dec (sc, d))
        | DNonfix _ => (broken (d, "a fixity directive"); dec (sc, d))
      val _ = List.foldl (fn (d, sc) => top (sc, d, true)) empty prog
      val declared = List.map key (!declares)
      fun parse k = case String.fields (fn c => c = #" ") k of
                      [kn, n] => (case kn of "structure" => (Str, n) | "signature" => (Sig, n) | "functor" => (Fun, n)
                                             | _ => (Tycon, n))
                    | _ => (Str, k)
    in
      {path = path, declares = List.rev (!declares),
       uses = List.map parse (List.filter (fn k => not (List.exists (fn d => d = k) declared)) (StringMap.listKeys (!uses))),
       breaks = List.rev (!breaks)}
    end

  (* ---- the graph ---- *)

  exception Graph of string

  (* The group's order: each file after the files that declare the names it
     uses, the given order kept wherever it allows; Graph where a name is
     declared by two files or the files' uses make a cycle. A use of a name
     no file of the group declares is the Basis Library's, or nobody's, and
     no edge. The edges, each file to the files it needs, come with it. *)
  fun order (fs : file list) : file list * (string * string list) list =
    let
      val files = Vector.fromList fs
      val n = Vector.length files
      val declarer =
        Vector.foldli
          (fn (i, f : file, m) =>
             List.foldl (fn (nm, m) =>
                           case StringMap.find (m, key nm) of
                             SOME j => raise Graph (key nm ^ " is declared by " ^ #path (Vector.sub (files, j)) ^ " and by " ^ #path f)
                           | NONE => StringMap.insert (m, key nm, i))
                        m (#declares f))
          StringMap.empty files
      val needs = Vector.map (fn (f : file) =>
                                List.foldl (fn (nm, acc) =>
                                              case StringMap.find (declarer, key nm) of
                                                SOME j => if List.exists (fn x => x = j) acc then acc else acc @ [j]
                                              | NONE => acc)
                                           [] (#uses f))
                             files
      val placed = Array.array (n, false)
      fun ready i = not (Array.sub (placed, i)) andalso List.all (fn j => j = i orelse Array.sub (placed, j)) (Vector.sub (needs, i))
      fun pick i = if i >= n then NONE else if ready i then SOME i else pick (i + 1)
      (* a cycle among the files not placed, for the message *)
      fun cycle () =
        let
          (* along needs among the files not placed -- each has one, or it
             would be ready -- from one of them until a file comes again:
             the files from its first time to its second *)
          fun walk (i, path) =
            case List.find (fn j => not (Array.sub (placed, j)) andalso j <> i) (Vector.sub (needs, i)) of
              NONE => path
            | SOME j =>
                if List.exists (fn x => x = j) path
                then let fun from [] = [] | from (x :: rest) = if x = j then x :: rest else from rest
                     in from path @ [j] end
                else walk (j, path @ [j])
          val start = case List.find (fn i => not (Array.sub (placed, i))) (List.tabulate (n, fn i => i)) of
                        SOME i => i | NONE => 0
        in String.concatWith " -> " (List.map (fn i => #path (Vector.sub (files, i))) (walk (start, [start]))) end
      fun go acc =
        if List.length acc = n then List.rev acc
        else
          case pick 0 of
            SOME i => (Array.update (placed, i, true); go (i :: acc))
          | NONE => raise Graph ("a cycle: " ^ cycle ())
      val ordered = go []
    in
      (List.map (fn i => Vector.sub (files, i)) ordered,
       List.map (fn i => (#path (Vector.sub (files, i)), List.map (fn j => #path (Vector.sub (files, j))) (Vector.sub (needs, i))))
                ordered)
    end

  (* The files of a group that a program's uses reach: those that declare
     a name it uses, and the files those need, in the group's order *)
  fun closure (group : file list, uses : name list) : file list =
    let
      val (ordered, edges) = order group
      val declarer = List.foldl (fn (f : file, m) => List.foldl (fn (nm, m) => StringMap.insert (m, key nm, #path f)) m (#declares f))
                                StringMap.empty ordered
      fun reach (p, seen) =
        if List.exists (fn x => x = p) seen then seen
        else List.foldl reach (p :: seen) (case List.find (fn (q, _) => q = p) edges of SOME (_, ns) => ns | NONE => [])
      val roots = List.mapPartial (fn nm => StringMap.find (declarer, key nm)) uses
      val reached = List.foldl reach [] roots
    in List.filter (fn (f : file) => List.exists (fn p => p = #path f) reached) ordered end

  (* the graph in DOT, each file to the files it needs *)
  fun dot (edges : (string * string list) list) : string =
    let fun q s = "\"" ^ String.translate (fn #"\"" => "\\\"" | c => String.str c) s ^ "\""
    in
      "digraph deps {\n"
      ^ String.concat (List.map (fn (p, ns) => "  " ^ q p ^ ";\n" ^ String.concat (List.map (fn m => "  " ^ q p ^ " -> " ^ q m ^ ";\n") ns))
                                edges)
      ^ "}\n"
    end
end
