(* The dependency graph of a group of files (the incremental roadmap's M8;
   D15): for each file, the module-level names it declares and the ones it
   uses that it does not declare, found in its syntax; the rules of a
   well-formed unit (the build-system roadmap's D17, CM's word), which make
   those names say the order: a file's top-level declarations declare
   structures, signatures, functors and type abbreviations, or overloading
   and effects, which name nothing, and none opens a structure or binds a
   value, an exception, a datatype or a fixity, which a use names without a
   structure, and no two units of a scope declare one module; and the order
   of the group, where only a cycle is refused. Nothing needs more: what a
   `local` head binds is private, and a unit that keeps a signature from a
   structure costs a firewall, which is another matter.

   The rules cost a unit that breaks them speed, never its meaning. It is
   a shared unit if others depend on it, and an entry unit, with all of
   Standard ML, if nothing does; a prelude is one a build says defines the
   language for what follows. One that breaks a rule stays where it is
   written, so that what it binds is in scope as the text says.

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

  (* what a file is to the graph; free is uses with what the file declares
     left in, a name it uses before it declares it, or outside what declares
     it: what it needs of the files before it, as the graph's uses are what
     it needs of the others. breaks is where it breaks the rules, values
     what those declarations bind that a use names without a structure, and
     hides whether they bind more than the syntax shows (an `open`, a
     replication); mentions, of analyseUnit alone, the identifiers it names
     without a structure, any of which may be another file's value; prelude
     whether a build declares it one (declared) *)
  type file = {path : string, declares : name list, uses : name list, free : name list, breaks : (span * string) list,
               values : string list, hides : bool, mentions : string list, prelude : bool}

  (* ---- the names of a file ---- *)

  (* the names in scope, by kind *)
  type scope = {strs : unit StringMap.map, tys : unit StringMap.map}
  val empty : scope = {strs = StringMap.empty, tys = StringMap.empty}
  fun bindStr ({strs, tys} : scope, n) : scope = {strs = StringMap.insert (strs, n, ()), tys = tys}
  fun bindTy ({strs, tys} : scope, n) : scope = {strs = strs, tys = StringMap.insert (tys, n, ())}

  (* the identifiers a pattern binds. A lone identifier may be a constructor,
     which the syntax does not show, and a bare expression is a binding of
     `it` (Parser), which names nothing *)
  fun patNames (p : pat) : string list =
    let fun all ps = List.concat (List.map patNames ps)
    in
      case p of
        PVar (([], "it"), _, _, _) => []
      | PVar (([], n), _, _, _) => [n]
      | PRecord (fs, _, _, _, _) => all (List.map #2 fs)
      | PTuple (ps, _, _) => all ps
      | PList (ps, _, _) => all ps
      | PApp (_, _, p, _, _) => patNames p
      | PTyped (p, _, _, _) => patNames p
      | PLayered (n, _, p, _, _, _) => n :: patNames p
      | POr (ps, _, _) => all ps
      | _ => []
    end

  fun analysing (noting : bool) (path : string, prog : program) : file =
    let
      val uses : unit StringMap.map ref = ref StringMap.empty
      val mentioned : unit StringMap.map ref = ref StringMap.empty
      fun use (k, n) = uses := StringMap.insert (!uses, key (k, n), ())
      fun longStr (sc : scope, (p, n) : longid) =
        case p of
          s :: _ => if StringMap.member (#strs sc, s) then () else use (Str, s)
        | [] => if noting then mentioned := StringMap.insert (!mentioned, n, ()) else ()
      fun longTy (sc : scope, id as (p, n) : longid) =
        case p of
          [] => if StringMap.member (#tys sc, n) then () else use (Tycon, n)
        | _ => longStr (sc, id)
      fun ty (sc, t) =
        case t of
          TyVar _ => ()
        | TyRecord (fs, _, _) => List.app (fn (_, t, _) => ty (sc, t)) fs
        | TyTuple (ts, _, _) => List.app (fn t => ty (sc, t)) ts
        | TyCon (args, id, _, _) => (List.app (fn t => ty (sc, t)) args; longTy (sc, id))
        | TyArrow (a, b, _, _) => (ty (sc, a); ty (sc, b))
      fun pat (sc, p) =
        case p of
          PVar (id, _, _, _) => longStr (sc, id)
        | PRecord (fs, _, _, _, _) => List.app (fn (_, p, _) => pat (sc, p)) fs
        | PTuple (ps, _, _) => List.app (fn p => pat (sc, p)) ps
        | PList (ps, _, _) => List.app (fn p => pat (sc, p)) ps
        | PApp (id, _, p, _, _) => (longStr (sc, id); pat (sc, p))
        | PTyped (p, t, _, _) => (pat (sc, p); ty (sc, t))
        | PLayered (_, t, p, _, _, _) => (Option.app (fn t => ty (sc, t)) t; pat (sc, p))
        | POr (ps, _, _) => List.app (fn p => pat (sc, p)) ps
        | _ => ()
      (* what a declaration binds, in the scope after it *)
      fun binds (d : dec, sc : scope) : scope =
        case d of
          DType (tbs, _, _) => List.foldl (fn (b : typbind, sc) => bindTy (sc, #name b)) sc tbs
        | DDatatype (dbs, tbs, _, _) =>
            List.foldl (fn (b : typbind, sc) => bindTy (sc, #name b))
                       (List.foldl (fn (b : datbind, sc) => bindTy (sc, #name b)) sc dbs) tbs
        | DDatatypeRepl (n, _, _, _) => bindTy (sc, n)
        | DAbstype (dbs, tbs, ds, sp, n) => List.foldl binds (binds (DDatatype (dbs, tbs, sp, n), sc)) ds
        | DLocal (_, b, _, _) => List.foldl binds sc b
        | DStructure (bs, _, _) => List.foldl (fn (b : strbind, sc) => bindStr (sc, #name b)) sc bs
        | _ => sc
      (* the scope after `local a in b end`, from before it and from the end
         of b: what a alone bound is out of scope again *)
      fun afterLocal (sc : scope, inner : scope, b : dec list) : scope =
        let
          val bound = List.foldl binds empty b
          fun keep (old, new) m = StringMap.filteri (fn (n, _) => StringMap.member (old, n) orelse StringMap.member (new, n)) m
        in
          {strs = keep (#strs sc, #strs bound) (#strs inner), tys = keep (#tys sc, #tys bound) (#tys inner)}
        end
      fun exp (sc, e) =
        case e of
          EVar (id, _, _, _) => longStr (sc, id)
        | ERecord (fs, _, _) => List.app (fn (_, e, _) => exp (sc, e)) fs
        | ETuple (es, _, _) => List.app (fn e => exp (sc, e)) es
        | EList (es, _, _, _) => List.app (fn e => exp (sc, e)) es
        | ESeq (es, _, _) => List.app (fn e => exp (sc, e)) es
        | ELet (ds, e, _, _) => exp (decs (sc, ds), e)
        | EApp (f, a, _, _) => (exp (sc, f); exp (sc, a))
        | ETyped (e, t, _, _) => (exp (sc, e); ty (sc, t))
        | EAndalso (a, b, _, _) => (exp (sc, a); exp (sc, b))
        | EOrelse (a, b, _, _) => (exp (sc, a); exp (sc, b))
        | EHandle (e, rs, _, _) => (exp (sc, e); rules (sc, rs))
        | ERaise (e, _, _) => exp (sc, e)
        | EIf (a, b, c, _, _) => (exp (sc, a); exp (sc, b); exp (sc, c))
        | EWhile (a, b, _, _) => (exp (sc, a); exp (sc, b))
        | ECase (e, rs, _, _) => (exp (sc, e); rules (sc, rs))
        | EFn (rs, _, _, _) => rules (sc, rs)
        | EPrim (_, t, _, _, _) => ty (sc, t)
        | _ => ()
      and rules (sc, rs) = List.app (fn (p, e) => (pat (sc, p); exp (sc, e))) rs
      (* a declaration's uses, and the scope after it *)
      and dec (sc : scope, d : dec) : scope =
        case d of
          DVal (_, bs, _, _) => (List.app (fn (p, e) => (pat (sc, p); exp (sc, e))) bs; sc)
        | DValRec (_, bs, _, _) => (List.app (fn (p, e) => (pat (sc, p); exp (sc, e))) bs; sc)
        | DFun (_, fs, _, _) =>
            (List.app (fn (f : fundef) =>
                         List.app (fn {pats, resty, body, ...} =>
                                     (List.app (fn p => pat (sc, p)) pats; Option.app (fn t => ty (sc, t)) resty;
                                      exp (sc, body)))
                                  (#clauses f)) fs;
             sc)
        | DType (tbs, _, _) =>
            (List.app (fn (b : typbind) => ty (sc, #ty b)) tbs; List.foldl (fn (b : typbind, sc) => bindTy (sc, #name b)) sc tbs)
        | DDatatype (dbs, tbs, _, _) =>
            let val sc' = List.foldl (fn (b : datbind, sc) => bindTy (sc, #name b)) sc dbs
            in
              List.app (fn (b : datbind) => List.app (fn (_, t, _) => Option.app (fn t => ty (sc', t)) t) (#cons b)) dbs;
              List.app (fn (b : typbind) => ty (sc', #ty b)) tbs;
              List.foldl (fn (b : typbind, sc) => bindTy (sc, #name b)) sc' tbs
            end
        | DDatatypeRepl (n, id, _, _) => (longTy (sc, id); bindTy (sc, n))
        | DAbstype (dbs, tbs, ds, sp, n) =>
            let val sc' = dec (sc, DDatatype (dbs, tbs, sp, n)) in decs (sc', ds) end
        | DException (bs, _, _) =>
            (List.app (fn ExnDecl (_, t, _, _, _) => Option.app (fn t => ty (sc, t)) t | ExnRepl (_, id, _, _, _) => longStr (sc, id)) bs;
             sc)
        | DLocal (a, b, _, _) => afterLocal (sc, decs (decs (sc, a), b), b)
        | DOpen (ids, _, _) => (List.app (fn (p, n) => longStr (sc, (p @ [n], ""))) ids; sc)
        | DOverload {strid, ...} => (case strid of s :: _ => longStr (sc, ([s], "")) | [] => (); sc)
        | DStructure (bs, _, _) =>
            (List.app (fn (b : strbind) => strexp (sc, #strexp b)) bs; List.foldl (fn (b : strbind, sc) => bindStr (sc, #name b)) sc bs)
        | DSignature (bs, _, _) => (List.app (fn (b : sigbind) => ignore (sigexp (sc, #sigexp b))) bs; sc)
        | DFunctor (bs, _, _) =>
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
          StrStruct (ds, _, _) => ignore (decs (sc, ds))
        | StrId ((p, n), _, _) => longStr (sc, (p @ [n], ""))
        | StrAscribe (se, sg, _, _, _) => (strexp (sc, se); ignore (sigexp (sc, sg)))
        | StrApp (f, arg, _, _) => (use (Fun, f); strexp (sc, arg))
        | StrLet (ds, se, _, _) => strexp (decs (sc, ds), se)
        | StrDynamic (_, sg, _, _, _) => ignore (sigexp (sc, sg))
        | StrExport (_, sg, se, _, _, _) => (ignore (sigexp (sc, sg)); strexp (sc, se))
      (* a signature's uses, and the names its specifications bind *)
      and sigexp (sc, sg) : scope =
        case sg of
          SigSig (specs, _, _) => List.foldl (fn (s, inner) => spec (sc, inner, s)) empty specs
        | SigId (n, _, _) => (use (Sig, n); empty)
        | SigWhere (sg, clauses, _, _) =>
            let val inner = sigexp (sc, sg)
            in List.app (fn (_, _, t, _) => ty (sc, t)) clauses; inner end
      and spec (sc : scope, inner : scope, s : spec) : scope =
        let
          (* a specification sees the outer scope and the specifications before it *)
          val here = {strs = StringMap.unionWith #1 (#strs inner, #strs sc), tys = StringMap.unionWith #1 (#tys inner, #tys sc)}
        in
          case s of
            SpecVal (ds, _, _) => (List.app (fn (_, t, _) => ty (here, t)) ds; inner)
          | SpecType (ds, _, _) => List.foldl (fn ((_, n, _), i) => bindTy (i, n)) inner ds
          | SpecEqtype (ds, _, _) => List.foldl (fn ((_, n, _), i) => bindTy (i, n)) inner ds
          | SpecDatatype (dbs, _, _) =>
              let val inner' = List.foldl (fn (b : datbind, i) => bindTy (i, #name b)) inner dbs
                  val here' = List.foldl (fn (b : datbind, h) => bindTy (h, #name b)) here dbs
              in List.app (fn (b : datbind) => List.app (fn (_, t, _) => Option.app (fn t => ty (here', t)) t) (#cons b)) dbs;
                 inner'
              end
          | SpecDatatypeRepl (n, id, _, _) => (longTy (here, id); bindTy (inner, n))
          | SpecException (ds, _, _) => (List.app (fn (_, t, _) => Option.app (fn t => ty (here, t)) t) ds; inner)
          | SpecStructure (ds, _, _) => List.foldl (fn ((n, sg, _), i) => (ignore (sigexp (here, sg)); bindStr (i, n))) inner ds
          | SpecInclude (sg, _, _) =>
              let val i' = sigexp (here, sg)
              in {strs = StringMap.unionWith #1 (#strs i', #strs inner), tys = StringMap.unionWith #1 (#tys i', #tys inner)} end
          | SpecSharingType _ => inner
          | SpecSharing _ => inner
        end
      (* the top level: what the file declares, and where it breaks the
         rules *)
      val declares : name list ref = ref []
      val declared : unit StringMap.map ref = ref StringMap.empty
      val breaks : (span * string) list ref = ref []
      val values : string list ref = ref []
      val hides = ref false
      fun declare (k, n) =
        if StringMap.member (!declared, key (k, n)) then ()
        else (declared := StringMap.insert (!declared, key (k, n), ()); declares := (k, n) :: !declares)
      fun broken (d, what) = breaks := (spanOfDec d, what) :: !breaks
      (* a declaration that binds no name is no one's to use *)
      fun binding (d, what, names) =
        case names of
          [] => ()
        | _ => (broken (d, what); values := names @ !values)
      fun hiding (d, what) = (broken (d, what); hides := true)
      fun datatypeNames (dbs : datbind list) =
        List.concat (List.map (fn (b : datbind) => #name b :: List.map #1 (#cons b)) dbs)
      fun patsOf bs = List.concat (List.map (patNames o #1) bs)
      fun top (sc, d, exported) =
        case d of
          DStructure (bs, _, _) => (if exported then List.app (fn (b : strbind) => declare (Str, #name b)) bs else (); dec (sc, d))
        | DSignature (bs, _, _) => (if exported then List.app (fn (b : sigbind) => declare (Sig, #name b)) bs else (); dec (sc, d))
        | DFunctor (bs, _, _) => (if exported then List.app (fn (b : funbind) => declare (Fun, #name b)) bs else (); dec (sc, d))
        | DType (bs, _, _) => (if exported then List.app (fn (b : typbind) => declare (Tycon, #name b)) bs else (); dec (sc, d))
        | DOverload _ => dec (sc, d)
        | DLocal (a, b, _, _) => afterLocal (sc, List.foldl (fn (d, sc) => top (sc, d, exported)) (decs (sc, a)) b, b)
        | DVal (_, bs, _, _) => (binding (d, "a value", patsOf bs); dec (sc, d))
        | DValRec (_, bs, _, _) => (binding (d, "a value", patsOf bs); dec (sc, d))
        | DFun (_, fs, _, _) => (binding (d, "a function", List.map (fn (f : fundef) => #name f) fs); dec (sc, d))
        | DDatatype (dbs, _, _, _) => (binding (d, "a datatype, whose constructors are values", datatypeNames dbs); dec (sc, d))
        | DDatatypeRepl _ => (hiding (d, "a datatype, whose constructors are values"); dec (sc, d))
        | DAbstype _ => (hiding (d, "an abstype"); dec (sc, d))
        | DException (bs, _, _) =>
            (binding (d, "an exception", List.map (fn ExnDecl (n, _, _, _, _) => n | ExnRepl (n, _, _, _, _) => n) bs); dec (sc, d))
        | DOpen _ => (hiding (d, "an open"); dec (sc, d))
        | DInfix (_, ns, _, _) => (binding (d, "a fixity directive", ns); dec (sc, d))
        | DInfixr (_, ns, _, _) => (binding (d, "a fixity directive", ns); dec (sc, d))
        | DNonfix (ns, _, _) => (binding (d, "a fixity directive", ns); dec (sc, d))
      val _ = List.foldl (fn (d, sc) => top (sc, d, true)) empty prog
      fun parse k = case String.fields (fn c => c = #" ") k of
                      [kn, n] => (case kn of "structure" => (Str, n) | "signature" => (Sig, n) | "functor" => (Fun, n)
                                             | _ => (Tycon, n))
                    | _ => (Str, k)
    in
      {path = path, declares = List.rev (!declares),
       uses = List.map parse (List.filter (fn k => not (StringMap.member (!declared, k))) (StringMap.listKeys (!uses))),
       free = List.map parse (StringMap.listKeys (!uses)),
       breaks = List.rev (!breaks), values = !values, hides = !hides, mentions = StringMap.listKeys (!mentioned),
       prelude = false}
    end

  fun analyse (file : string * program) : file = analysing false file
  (* with the identifiers it mentions, which only the rules want *)
  fun analyseUnit (file : string * program) : file = analysing true file

  (* a file a build declares a prelude *)
  fun declared ({path, declares, uses, free, breaks, values, hides, mentions, ...} : file) : file =
    {path = path, declares = declares, uses = uses, free = free, breaks = breaks, values = values, hides = hides,
     mentions = mentions, prelude = true}

  (* a file with no syntax here, whose parse needs a fixity the graph does not
     know (a library's with no header). Its compile will say what it means;
     until then it is what all the rest of it may depend on *)
  fun unread (path : string, sp : span) : file =
    {path = path, declares = [], uses = [], free = [], breaks = [(sp, "a file that does not parse in the fixity known here")],
     values = [], hides = true, mentions = [], prelude = false}

  (* ---- the graph ---- *)

  exception Graph of string

  (* The names two files of a group declare, each with the first and the
     second; in the order of the second *)
  fun twice (fs : file list) : (name * string * string) list =
    List.rev (#2 (List.foldl
      (fn (f : file, seen) =>
         List.foldl (fn (nm, (first, acc)) =>
                       case StringMap.find (first, key nm) of
                         SOME p => (first, if p = #path f then acc else (nm, p, #path f) :: acc)
                       | NONE => (StringMap.insert (first, key nm, #path f), acc))
                    seen (#declares f))
      (StringMap.empty, []) fs))

  (* The group's order: each file after the files that declare the names it
     uses, the given order kept wherever it allows; Graph where the files'
     uses make a cycle. A file that breaks a rule, a prelude, and a file that
     declares what another does stay where they are written: all that is
     before stays before, and all that is after stays after, so a use across
     one is what the text says, the binder before it or none. A use of a
     name no file of the group declares is the Basis Library's, or nobody's,
     and no edge. The edges, each file to the files it needs, come with
     it. *)
  fun order (fs : file list) : file list * (string * string list) list =
    let
      val files = Vector.fromList fs
      val n = Vector.length files
      val declarers =
        Vector.foldli
          (fn (i, f : file, m) =>
             List.foldl (fn (nm, m) => StringMap.insert (m, key nm, i :: getOpt (StringMap.find (m, key nm), []))) m (#declares f))
          StringMap.empty files
      val repeated = Array.array (n, false)
      val () = StringMap.app (fn is => case is of
                                         [_] => ()
                                       | _ => List.app (fn i => Array.update (repeated, i, true)) is) declarers
      fun stays i = let val f = Vector.sub (files, i)
                    in #prelude f orelse not (List.null (#breaks f)) orelse Array.sub (repeated, i) end
      (* for each file, the last that stays at or before it *)
      val anchor = Array.array (n, ~1)
      val _ = Vector.foldli (fn (i, _, last) => let val here = if stays i then i else last
                                                in Array.update (anchor, i, here); here end) ~1 files
      (* the binder a use in i means: the last before it, or else the first
         after it that nothing stands between it and, where it can move *)
      fun binder (i, is) =
        case List.find (fn j => j < i) is of
          SOME j => SOME j
        | NONE =>
            if stays i then NONE
            else List.find (fn j => j <> i andalso Array.sub (anchor, j) = Array.sub (anchor, i)) (List.rev is)
      val needs = Vector.mapi (fn (i, f : file) =>
                                List.foldl (fn (nm, acc) =>
                                              case Option.mapPartial (fn is => binder (i, is)) (StringMap.find (declarers, key nm)) of
                                                SOME j => if List.exists (fn x => x = j) acc then acc else acc @ [j]
                                              | NONE => acc)
                                           [] (#uses f))
                             files
      val placed = Array.array (n, false)
      val count = ref 0
      fun ready i =
        not (Array.sub (placed, i))
        andalso List.all (fn j => j = i orelse Array.sub (placed, j)) (Vector.sub (needs, i))
        andalso (if stays i then !count = i
                 else let val a = Array.sub (anchor, i) in a < 0 orelse Array.sub (placed, a) end)
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
            SOME i => (Array.update (placed, i, true); count := !count + 1; go (i :: acc))
          | NONE => raise Graph ("a cycle: " ^ cycle ())
      val ordered = go []
    in
      (List.map (fn i => Vector.sub (files, i)) ordered,
       List.map (fn i => (#path (Vector.sub (files, i)), List.map (fn j => #path (Vector.sub (files, j))) (Vector.sub (needs, i))))
                ordered)
    end

  (* The files of a group that a program's uses reach: those that declare
     a name it uses, and the files those need, in the group's order. The
     group is files found, with no order written for a name two declare to
     stand on: Graph *)
  fun closure (group : file list, uses : name list) : file list =
    let
      val () = case twice group of
                 (nm, p, q) :: _ => raise Graph (key nm ^ " is declared by " ^ p ^ " and by " ^ q)
               | [] => ()
      val (ordered, edges) = order group
      val declarer = List.foldl (fn (f : file, m) => List.foldl (fn (nm, m) => StringMap.insert (m, key nm, #path f)) m (#declares f))
                                StringMap.empty ordered
      fun reach (p, seen) =
        if List.exists (fn x => x = p) seen then seen
        else List.foldl reach (p :: seen) (case List.find (fn (q, _) => q = p) edges of SOME (_, ns) => ns | NONE => [])
      val roots = List.mapPartial (fn nm => StringMap.find (declarer, key nm)) uses
      val reached = List.foldl reach [] roots
    in List.filter (fn (f : file) => List.exists (fn p => p = #path f) reached) ordered end

  (* ---- well-formed units ---- *)

  (* What a unit is to the rules (D17). Only a shared unit is held to them *)
  datatype class = Shared | Entry | Prelude

  (* A build as the rules read it: its units in order, each with its class
     where the build says it, or for the units after it to say; and its
     scopes: what a boundary holds is a scope. What it lets out meets what
     another lets out as a clash of imports, a library's matter
     (docs/build.md, Clashes), not two units' *)
  datatype layout = Unit of file * class option
                  | Scope of layout list

  (* A unit by what a build says of it, the annotations in force (docs/build.md):
     a prelude where it is declared one, and an `always` file of a library is
     one; a `final` file comes after all that could depend on it; and a file
     of a library is its clients' to depend on, whose uses are not to hand.
     A seal binds again what its library declares, by design, so it is a
     scope of its own *)
  fun unitOf (library : bool, annotations : string list, f : file) : layout =
    let
      val load = List.filter (fn a => List.exists (fn c => c = a) ["always", "demand", "seal", "final"]) annotations
      val last = case List.rev load of [] => "" | a :: _ => a
      val class = if #prelude f orelse List.exists (fn a => a = "prelude") annotations orelse last = "always" then SOME Prelude
                  else if last = "final" then SOME Entry
                  else if library orelse last <> "" then SOME Shared
                  else NONE
    in if last = "seal" then Scope [Unit (f, class)] else Unit (f, class) end

  fun module (Tycon, _) = false
    | module _ = true

  (* Where a build breaks the rules, each with what breaks one, for a shared
     unit. A unit none of whose names a unit after it mentions is an entry
     unit: a name of its in another's text is a dependence the syntax cannot
     rule out, and one that hides what it binds may be needed by any. *)
  fun illFormed (layout : layout list) : (span * string) list =
    let
      fun unitsOf (Unit u) = [u]
        | unitsOf (Scope ls) = List.concat (List.map unitsOf ls)
      val units = List.concat (List.map unitsOf layout)
      fun dependedOn (f : file, later) =
        #hides f orelse List.exists (fn n => StringMap.member (later, n)) (#values f @ List.map #2 (#declares f))
      val (classes, _, _) =
        List.foldr
          (fn ((f, given), (classes, later, any)) =>
             let val class = case given of
                               SOME c => c
                             | NONE => if #prelude f then Prelude
                                       else if any andalso dependedOn (f, later) then Shared else Entry
                 val later = List.foldl (fn (n, m) => StringMap.insert (m, n, ())) later (#mentions f @ List.map #2 (#uses f))
             in (StringMap.insert (classes, #path f, class), later, true) end)
          (StringMap.empty, StringMap.empty, false) units
      fun shared p = StringMap.find (classes, p) = SOME Shared
      val own = List.concat (List.map (fn (f : file, _) => if shared (#path f) then #breaks f else []) units)
      (* one module, per scope: a file given twice is one binder *)
      val repeats : (span * string) list ref = ref []
      fun bind ((nm, p), seen) =
        case StringMap.find (seen, key nm) of
          SOME q =>
            (if p <> q andalso shared p andalso shared q
             then repeats := ({file = p, start = 0, stop = 0}, key nm ^ ", which " ^ q ^ " declares too") :: !repeats
             else ();
             StringMap.insert (seen, key nm, p))
        | NONE => StringMap.insert (seen, key nm, p)
      fun scope (ls : layout list, seen) =
        List.foldl (fn (Unit (f, _), seen) =>
                         List.foldl (fn (nm, seen) => bind ((nm, #path f), seen)) seen (List.filter module (#declares f))
                     | (Scope inner, seen) => (ignore (scope (inner, StringMap.empty)); seen))
                   seen ls
      val _ = scope (layout, StringMap.empty)
    in own @ List.rev (!repeats) end

  (* what a warning or an error says of one *)
  fun notWellFormed (what : string) : string =
    "this unit is not well-formed, and others depend on it: this is " ^ what ^ " (docs/units.md, Well-formed units)"

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
