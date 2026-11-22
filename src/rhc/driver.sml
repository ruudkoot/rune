(* rhc's driver over a program of Haskell in units (the haskell98 roadmap's
   M21f): each group of the module graph, an SCC, is a unit, named and
   checked from the interfaces of the units before it (RhcIface, F's),
   desugared alone (RhcDesugar.unit, D's), at level 2 checked by HsLint
   after what it found of the units before (HsLint.check and join, H's; ruling
   66), its interface (HsIface), HsLint's part and its Core kept in the
   store (RhcStore) keyed by its members' texts (H8, H4),
   and taken from there where every read its compile made (HsUsage) gives
   now what it gave (H1, H2, H7, H9; H3: from the units of this compile,
   never the entry); and the link of the roadmap's C: the units' Core
   joined, what main reaches compiled whole, its bytecode kept by that
   Core's hash. Without a store it is the cold compile, which a warm one
   equals byte for byte. *)
structure RhcDriver =
struct
  structure N = RhcNames
  structure G = RhcGraph
  structure M = HsStringMap

  exception Failed of string

  (* ---- the desugaring's interface as text (D's HsDesugar.interface) ---- *)

  fun put (w : string list ref, s : string) = w := (Int.toString (size s) ^ ":" ^ s ^ " ") :: !w
  fun putList f (w, xs) = (w := (Int.toString (length xs) ^ " ") :: !w; List.app (fn x => f (w, x)) xs)
  fun putPair (w, (a, b)) = (put (w, a); put (w, b))
  fun putNamed (w, (a, bs)) = (put (w, a); putList put (w, bs))
  fun putForced (w, (a, bs)) = (put (w, a); putList (fn (w, b) => put (w, if b then "1" else "0")) (w, bs))

  fun desugarText ({core, primTypes, builtinCons, fields, constructors, leaves, defaults, forced} : HsDesugar.interface) : string =
    let val w = ref []
    in
      put (w, CoreText.show core); putList putPair (w, primTypes); putList putPair (w, builtinCons);
      putList putNamed (w, fields); putList putNamed (w, constructors); putList put (w, leaves); putList put (w, defaults);
      putList putForced (w, forced);
      String.concat (List.rev (!w))
    end

  (* a reader of put's text: a string, a number (a list's length), and
     whether it is all read *)
  fun readerOf (what : string, s : string) =
    let
      val pos = ref 0
      fun bad w = raise Failed (what ^ ": " ^ w ^ " at " ^ Int.toString (!pos))
      fun upTo c =
        let fun go i = if i < size s andalso String.sub (s, i) <> c then go (i + 1) else i
        in go (!pos) end
      fun number () =
        let val j = upTo #" "
        in case Int.fromString (String.substring (s, !pos, j - !pos)) of
             SOME n => (pos := j + 1; n)
           | NONE => bad "a number"
        end
      fun get () =
        let
          val c = upTo #":"
          val n = case Int.fromString (String.substring (s, !pos, c - !pos)) of SOME n => n | NONE => bad "a length"
          val v = String.substring (s, c + 1, n) handle Subscript => bad "a string"
        in pos := c + 1 + n + 1; v end
      fun atEnd () = !pos = size s
    in
      {get = get, number = number, atEnd = atEnd}
    end

  fun desugarOf (s : string) : HsDesugar.interface =
    let
      val pos = ref 0
      fun bad what = raise Failed ("a unit's desugaring interface: " ^ what ^ " at " ^ Int.toString (!pos))
      fun upTo c =
        let fun go i = if i < size s andalso String.sub (s, i) <> c then go (i + 1) else i
        in go (!pos) end
      fun number () =
        let val j = upTo #" "
        in case Int.fromString (String.substring (s, !pos, j - !pos)) of
             SOME n => (pos := j + 1; n)
           | NONE => bad "a number"
        end
      fun get () =
        let
          val c = upTo #":"
          val n = case Int.fromString (String.substring (s, !pos, c - !pos)) of SOME n => n | NONE => bad "a length"
          val v = String.substring (s, c + 1, n) handle Subscript => bad "a string"
        in pos := c + 1 + n + 1; v end
      fun getList f = List.tabulate (number (), fn _ => f ())
      fun getPair () = let val a = get () in (a, get ()) end
      fun getNamed () = let val a = get () in (a, getList get) end
      fun getBool () = case get () of "1" => true | "0" => false | _ => bad "a flag"
      fun getForced () = let val a = get () in (a, getList getBool) end
      val core = CoreText.parse (get ()) handle CoreText.Error (_, msg) => bad msg
      val primTypes = getList getPair
      val builtinCons = getList getPair
      val fields = getList getNamed
      val constructors = getList getNamed
      val leaves = getList get
      val defaults = getList get
      val forced = getList getForced
    in
      {core = core, primTypes = primTypes, builtinCons = builtinCons, fields = fields, constructors = constructors,
       leaves = leaves, defaults = defaults, forced = forced}
    end

  (* ---- the units ---- *)

  (* a unit made or taken: its name, its members, its modules' interfaces
     and their fingerprints, its desugaring's interface, what HsLint found
     of its modules alone where it was made at level 2, and its Core *)
  type unit_ = {name : string, ids : string list, mods : HsModIface.t list, prints : (string * string) list,
                desugar : unit -> HsDesugar.interface, hslint : unit -> HsLint.library option, sum : unit -> string,
                indexed : unit -> CoreUnits.unitCore, key : string, entry : string option ref}

  (* An entry's sections: its modules' interfaces (HsIface's), and its
     parts: the desugaring's interface, read only where a unit is
     desugared after it; its fingerprints; HsLint's part of it, made at
     level 2 (ruling 66; empty below), read only where a unit after it is
     made at level 2; its Core's index; the hash of its Core, the index's
     text and every declaration's, which the link's memo is keyed by; and
     each of its Core's declarations, read only where a link reaches it *)
  val desugarPart = 0
  val printsPart = 1
  val hslintPart = 2
  val indexPart = 3
  val coreSumPart = 4
  val declsPart = 5

  (* f's value, made once and where it is first asked for *)
  fun once (f : unit -> 'a) : unit -> 'a =
    let val cell = ref NONE
    in fn () => case !cell of SOME v => v | NONE => let val v = f () in cell := SOME v; v end end

  (* The fingerprints of a unit's entities and instances, by key or
     identity, by recursive group over all its modules (HsModIface's: a
     group that spans the members of a cycle is one, H8), those of the
     units before it `earlier`'s; and what it asked of those, each key with
     what it gave, which are all its fingerprints read of anything but its
     modules' interfaces *)
  type prints = {prints : (string * string) list, asked : (string * string option) list}

  fun printsFor (mods : HsModIface.t list, earlier : string M.map) : prints =
    let
      val asked : string option M.map ref = ref M.empty
      fun external k = let val v = M.find (earlier, k) in asked := M.insert (!asked, k, v); v end
      val prints = HsModIface.fingerprints Pickle.hash (mods, external)
    in
      {prints = prints, asked = M.listItems (!asked)}
    end

  (* a unit's fingerprints kept with it, and read back: where every key it
     asked gives now what it gave, they are what printsFor gives, of the
     same interfaces (its entry's) and the same answers *)
  fun printsText ({prints, asked} : prints) : string =
    let val w = ref []
    in
      putList putPair (w, prints);
      putList (fn (w, (k, v)) => (put (w, k); case v of SOME f => put (w, "s" ^ f) | NONE => put (w, "n"))) (w, asked);
      String.concat (List.rev (!w))
    end

  fun printsOfText (s : string) : prints =
    let
      fun bad what = raise Failed ("a unit's fingerprints: " ^ what)
      val {get, number, atEnd} = readerOf ("a unit's fingerprints", s)
      val prints = List.tabulate (number (), fn _ => let val k = get () in (k, get ()) end)
      fun answer v = if v = "n" then NONE else if String.isPrefix "s" v then SOME (String.extract (v, 1, NONE)) else bad "s or n"
      val asked = List.tabulate (number (), fn _ => let val k = get () in (k, answer (get ())) end)
    in
      if atEnd () then {prints = prints, asked = asked} else bad "the end"
    end

  (* ---- what a compile in units shares: the store's settings, the graph
     read by headers, a state of the units before, a unit taken ---- *)

  (* what of rhc's front end changes a unit's interface or Core: the
     strings' form, the match's order, the driver (RhcStoreConfig) *)
  fun extraOf (strings : CoreRuntime.strings) : (string * string) list =
    [("strings", case strings of CoreRuntime.Lazy => "lazy" | CoreRuntime.Whole => "whole"),
     ("match", case !HsMatch.order of HsMatch.Report => "report" | HsMatch.Sestoft => "sestoft"), ("driver", "hs")]
    (* the interface's unfoldings and strictness signatures, which only
       --unfoldings at -O2 writes: an entry with them shares with none
       without *)
    @ (if !RhcOptions.unfoldings then [("sections", "unfoldings")] else [])
    (* a generalised binding's tuple form (--selectors=generalised), which
       changes a unit's Core: likewise *)
    @ (if !HsDesugar.generalisedSelectors then [("selectors", "generalised")] else [])

  (* A module's header kept in the store: by the name it is read for, the
     way it is read and its text's hash, not by its file (ruling 67), so a
     snapshot made where rhc is built serves where it is installed *)
  type headerAt = {file : string, name : string, mode : string, hash : string}
  fun headerKey ({name, mode, hash, ...} : headerAt) : string = RhcStore.key ("module:" ^ mode, [(name, hash)])

  (* a header as bytes, and the header of bytes, its spans in `file`, the
     file read now; NONE where they are not one *)
  fun headerText ({name, at, imports} : G.header) : string =
    let
      val w = Pickle.writer ()
      fun span (w, {start, stop, ...} : HsSource.span) = (Pickle.int (w, start); Pickle.int (w, stop))
    in
      Pickle.string (w, name); span (w, at);
      Pickle.list (fn (w, (m, s)) => (Pickle.string (w, m); span (w, s))) (w, imports);
      Pickle.contents w
    end

  fun headerOf (s : string, file : string) : G.header option =
    let
      val r = Pickle.reader s
      fun span r = let val a = Pickle.rint r in {file = file, start = a, stop = Pickle.rint r} end
      val name = Pickle.rstring r
      val at = span r
      val imports = Pickle.rlist (fn r => let val m = Pickle.rstring r in (m, span r) end) r
    in
      if Pickle.atEnd r then SOME {name = name, at = at, imports = imports} else NONE
    end
    handle Pickle.Bad _ => NONE | Subscript => NONE | Overflow => NONE

  (* The graph's reader (RhcGraph.scan): a module's text hashed by the stat
     memo where the store has one (UnitStore's), its header taken from the
     store by that hash, else made and kept where `keep` keeps, so that a
     module whose unit is taken with no usage asked of its modules is never
     read past its stat, and none is parsed but where its unit is made or
     its usages asked *)
  fun readerOf ({memo, lookup, keep}
                : {memo : UnitStore.memo option,
                   lookup : string * (RhcStore.head -> UnitStore.verdict) -> (RhcStore.head, RhcStore.sections) UnitStore.found option,
                   keep : string * RhcStore.sections -> unit}) : G.reader =
    {hash = fn ({file, text, ...} : {file : string, mode : string, text : unit -> string}) =>
              case memo of
                SOME m => UnitStore.hashBy m (file, "rhc", text, Pickle.hash)
              | NONE => Pickle.hash (text ()),
     header = fn (k as {file, ...} : headerAt) =>
                case lookup (headerKey k, fn _ => UnitStore.Stands) of
                  SOME (UnitStore.Found ({sections, ...}, _)) => headerOf (#iface sections, file)
                | SOME (UnitStore.FoundBehind ({sections, ...}, _)) => headerOf (#iface sections, file)
                | _ => NONE,
     keep = fn (k : headerAt, h) => keep (headerKey k, {iface = headerText h, parts = fn _ => "", count = 0})}

  (* A unit's key: its name, and each member with the hash of its text and
     whether the text is literate, which reads it as another program
     (build-cache-issues.md, issue 27), over every member of an SCC (H8), a
     module's `default` in its text (H4) *)
  fun unitKey (name : string, found : G.found list) : string =
    RhcStore.key ("hs:" ^ name,
                  List.map (fn (f : G.found) => (#id f ^ (if HsLiterate.isLiterate (#file f) then " literate" else ""), #hash f))
                    found)

  (* rhc's leaves the program's modules import (RhcNames.leavesOf, of the
     imports found) *)
  fun leavesOf (groups : G.found list list) =
    List.filter (fn (l, _) => List.exists (fn (f : G.found) => List.exists (fn t => t = RhcLibrary.identity l) (#imports f))
                                (List.concat groups))
      RhcLibrary.leaves

  (* a state with the interfaces of the units before installed, as F's
     turns, and an evidence table of its own *)
  fun startOf evidence (s : N.state) : N.state =
    {defs = #defs s, universe = #universe s, fixities = #fixities s, library = #library s, exports = #exports s,
     scopes = #scopes s, diags = #diags s, modules = #modules s, derived = #derived s, evidence = evidence,
     types = #types s}

  (* A module's interface with each definition's place in `file`: an
     entry keeps its places by their module, not by the path the module was
     read from (""), and a unit taken has them put back where that module is
     now, as Rune's units name a functor's file by the unit it is the source
     of (build-cache-issues.md, issues 9 and 31): so that an entry is the
     bytes a compile anywhere gives, the snapshot make wrote read by a bin/rhc
     elsewhere *)
  fun placed (file : string) ({id, exports, defs, fixities, checked} : HsModIface.t) : HsModIface.t =
    {id = id, exports = exports, fixities = fixities, checked = checked,
     defs = List.map (fn {entity, sort, parent, arity, span = {start, stop, ...}} : HsModules.def =>
                        {entity = entity, sort = sort, parent = parent, arity = arity,
                         span = {file = file, start = start, stop = stop}})
              defs}

  (* A unit taken from its entry: its modules' interfaces; its
     fingerprints as kept, where what they asked of the units before gives
     what it gave, else made again; its desugaring's interface and HsLint's
     part, read where a unit after it is made; its Core's index, read only
     where the link is compiled, and each declaration's text only where the
     link reaches it *)
  fun takenUnit ({name, key, ids, files, prints}
                 : {name : string, key : string, ids : string list, files : string M.map, prints : string M.map})
                ({iface, parts, ...} : RhcStore.sections, sum : string) : unit_ =
    let
      val {modules, ...} = HsIface.decode iface handle HsIface.Bad msg => raise Failed ("the entry of " ^ name ^ ": " ^ msg)
      val modules = List.map (fn m => placed (getOpt (M.find (files, #id m), "")) m) modules
      val kept = printsOfText (parts printsPart)
      val own = if List.all (fn (k, v) => M.find (prints, k) = v) (#asked kept) then kept else printsFor (modules, prints)
      fun indexed () = CoreUnits.Indexed (parts indexPart, fn i => parts (i + declsPart))
      (* HsLint's part, decoded only where a unit after it is made at level
         2; an entry made below level 2 keeps none *)
      fun hslint () =
        case parts hslintPart of
          "" => NONE
        | bytes => SOME (HsLint.decode bytes handle HsLint.Decode msg => raise Failed ("the entry of " ^ name ^ ": " ^ msg))
    in
      {name = name, ids = ids, mods = modules, prints = #prints own, desugar = once (fn () => desugarOf (parts desugarPart)),
       hslint = once hslint, sum = fn () => parts coreSumPart, indexed = indexed, key = key, entry = ref (SOME sum)}
    end

  (* HsLint at level 2 (ruling 66) on a unit made: its modules inferred
     after what it found of the units before, each one's part joined (the
     first unit, the library's with the Prelude, from nothing), their
     records replayed; what it found of them alone, kept as a part of the
     entry, and what the target check reads (RhcLint.kept); NONE below
     level 2 *)
  fun hslintOf {modules : HsLint.module list, main : string option, r : N.result, library : unit -> HsLint.library option}
      : HsLint.library option =
    if not (Pass.linting' 2) then NONE
    else
      let
        val part = ref NONE
      in
        Pass.checkAt ("hslint", 2)
          (fn () =>
             let
               val {target, part = mine, ...} =
                 HsLint.check
                   {groups = [modules], main = main, cycleDefault = false,
                    records = Option.map (fn env => {table = #evidence r, env = env, derived = #derived r}) (#types r),
                    claims = Option.map (HsLint.claims o RhcLint.readFile) (!RhcLint.claims),
                    where_ = fn sp => getOpt (RhcLint.lineColumn sp, "0:0"), fault = RhcLint.fault (),
                    library = library ()}
                 handle HsLint.Refused (span, msg) => raise Error.Bug (RhcLint.place span ^ ": " ^ msg)
             in
               RhcLint.kept := SOME target; part := SOME mine
             end)
          ();
        !part
      end

  (* the modules of a unit's state as HsLint reads them *)
  fun lintModules (own : string -> bool, r : N.result) : HsLint.module list =
    List.mapPartial (fn (n : G.node, ast) => if own (#id n) then SOME {id = #id n, ast = ast, library = #library n} else NONE)
      (#modules r)

  (* the program's main in a unit, where the unit holds the root named Main *)
  fun mainIn (own : string -> bool, roots : string list) : string option =
    List.find (fn m => own m andalso HsModules.moduleName m = "Main") roots

  (* ---- bin/rhc's compile in units, its store and its snapshot ---- *)

  (* A program as bin/rhc reads it (rulings 66 and 67, D58): each group of
     its graph a unit, taken from the store where its entry stands (the
     overlay, `store`, which a compile keeps its units in by default:
     RhcStoreConfig.storeFor) or from a layer after it (`--layer`, then the
     snapshot, bin/rhc.layer, made at make time), read only; the rest read
     and named and checked from the interfaces of the units before it, as
     a whole check names and checks them (a group after one with an error
     named and not checked). What it gives: the graph of the groups made
     (their nodes, and the diagnostics of finding them), the diagnostics of
     their names and checking, the exports of the modules after the last
     unit, and, for a program that checks, `lint`, HsLint on each unit made
     after the parts of the units before it, at level 2; `keep`, each unit
     made desugared after the interfaces of those before it and kept in the
     store (its entry: its interfaces, its desugaring's, its fingerprints,
     HsLint's part, its Core, and its usages, what its naming, checking and
     desugaring read of the units before it, each with what it gave, against
     which the entry is judged where it is found again); `link`, after
     `keep`, what main reaches of all the units, the program's Core, which
     a whole compile gives byte for byte once compiled; and the link's memo
     where there is a store, the program's bytecode kept by the units'
     entries. Without a store (`--no-store`) nothing is kept, and the units
     are taken from the layers alone. *)
  type memo = {find : unit -> string option, keep : string -> unit}
  type front = {graph : G.graph, diags : G.diag list, exports : HsModules.entity list M.map,
                lint : unit -> unit, keep : unit -> unit, link : unit -> Core.program, memo : memo option,
                finish : unit -> unit}

  (* a unit made by `front`: its key, its nodes, its checking and what that
     read, the answer a read gives now (its usage), the units before it,
     its interfaces and fingerprints, and its desugaring, HsLint's part and
     its entry's sum, made by `keep` and `lint` in the units' order *)
  type made = {name : string, key : string, ids : string list, nodes : G.node list, r : N.result, reads : HsUsage.read list,
               answer : HsUsage.read -> string, earlier : unit_ list, mods : HsModIface.t list, prints : prints,
               desugared : (Core.program * HsDesugar.interface * HsUsage.read list) option ref,
               linted : HsLint.library option ref, sum : string option ref, stored : (RhcStore.entry * string) option,
               index : int, scopes : RhcStore.usage list}

  (* --verify-store: each unit an entry stands for made too, and its entry
     held to what the unit made gives, byte for byte, as Rune's
     --verify-cache holds its own (build-cache-issues.md, issue 6 and its
     rhc's), and the link's taken the same way (RhcMain) *)
  val verify = ref false

  (* the parts of an entry read, each held to its hash, until there are no
     more *)
  fun partsOf ({parts, ...} : RhcStore.sections) : string list =
    let fun go (i, acc) = (case (SOME (parts i) handle Pickle.Bad _ => NONE) of
                             SOME b => go (i + 1, b :: acc)
                           | NONE => List.rev acc)
    in go (0, []) end

  (* how an entry differs from what its unit's compile gives now: its
     usages, its interface, or a part (HsLint's only where both have one:
     an entry made at a higher level of the lint stands at a lower);
     NONE where it does not. Not its digest of the units before it, which
     names the entries it was made after, nor its scope's usages, digests
     of its imports' exports that an entry that stands by its usages keeps
     as they were (issue 37): neither is what it is made of *)
  fun differs ({head = {usages, ...}, sections} : RhcStore.entry,
               (usages' : RhcStore.usage list, sections' as {iface = iface', parts = parts', count = count'} : RhcStore.sections))
      : string option =
    let
      val ps = partsOf sections
      fun part i = if i = hslintPart andalso (List.nth (ps, i) = "" orelse parts' i = "") then NONE
                   else if List.nth (ps, i) = parts' i then NONE
                   else SOME ("its part " ^ Int.toString i ^ (if i = desugarPart then " (its desugaring's interface)"
                                                              else if i = printsPart then " (its fingerprints)"
                                                              else if i = hslintPart then " (HsLint's)"
                                                              else if i = indexPart then " (its Core's index)"
                                                              else if i = coreSumPart then " (its Core's hash)"
                                                              else " (a declaration of its Core)"))
      fun firstPart i = if i >= count' then NONE else case part i of NONE => firstPart (i + 1) | some => some
      fun reads us = List.filter (fn (k, _) => not (String.isPrefix "scope " k)) us
    in
      if reads usages <> reads usages' then SOME "its usages"
      else if #iface sections <> iface' then SOME "its interface"
      else if length ps <> count' then SOME "its number of parts"
      else firstPart 0
    end

  (* ---- a hit in two phases (build-cache-issues.md, issue 37's A) ---- *)

  (* A module's scope is a function of its text, which its unit's key
     holds, and of what each module it imports exports (5.3, 5.5): the
     entities, and of each the def its import's list and its `T(..)` read,
     its parent and its sort (HsModules.solve). So an entry keeps, beside
     its usages, a digest of the exports of each module its unit's modules
     import, the scope's usages (`scope M`); where each is what it was, and
     the modules imported are those it names, every name a usage asked
     stands for the entities it stood for, and only their fingerprints can
     have moved, which the units before give without the unit's modules
     read or named. Where one moved, the unit is named and each usage
     asked, as before. Not under the greatest fixpoint of exports, whose
     start is every entity of the program. *)
  val scopePrefix = "scope "
  fun isScope (k : string) = String.isPrefix scopePrefix k

  fun sortText s =
    case s of
      HsModules.Var => "var" | HsModules.Con => "con" | HsModules.Field => "field" | HsModules.Method => "method"
    | HsModules.TyCon => "tycon" | HsModules.Synonym => "synonym" | HsModules.Class => "class"

  (* the digest of what the module m exports in the state s, of the units
     before the one that imports it *)
  fun scopeDigest (s : N.state, m : string) : string =
    case M.find (#exports s, m) of
      NONE => "none"
    | SOME es =>
        Pickle.hash
          (String.concatWith "\n"
             (List.map (fn e =>
                          let val k = HsModules.key e
                          in
                            case M.find (#defs s, k) of
                              SOME {sort, parent, ...} =>
                                k ^ " " ^ sortText sort ^ " " ^ (case parent of SOME p => HsModules.key p | NONE => "")
                            | NONE => k
                          end)
                es))

  (* the modules a unit's members import, but its own, in order *)
  fun importTargets (found : G.found list) : string list =
    let
      val own = List.map #id found
      val all = List.foldl (fn (m, s) => if List.exists (fn i => i = m) own then s else M.insert (s, m, ()))
                  M.empty (List.concat (List.map #imports found))
    in
      List.map #1 (M.listItems all)
    end

  (* a usage's answer as the units before give it now, where the unit's
     scopes are what they were: an entity of a unit before has its
     fingerprint now, one of the unit's own its key (RhcIface.answer) *)
  fun refreshed (own : string -> bool, fingerprint : string -> string option) (v : string) : string =
    if v = "(no scope)" then v
    else
      let
        fun homeOf el = case CharVector.findi (fn (_, c) => c = #"\t") el of
                          SOME (i, _) => if i > 1 then String.substring (el, 1, i - 1) else ""
                        | NONE => ""
        fun one el =
          if own (homeOf el) then el
          else
            case CharVector.foldli (fn (i, #"=", _) => SOME i | (_, _, acc) => acc) NONE el of
              SOME i => let val k = String.substring (el, 0, i) in k ^ "=" ^ getOpt (fingerprint k, "?") end
            | NONE => el
      in
        String.concatWith " " (RhcIface.sortStrings (List.map one (String.tokens (fn c => c = #" ") v)))
      end

  fun front {roots : string list, dotted : bool, fixpoint : HsModules.fixpoint, check : HsInfer.cycleDefault option,
             store : string option, layers : string list, strings : CoreRuntime.strings, show : bool} : front =
    let
      val mark = ref (!Pass.instructions ())
      fun since () = let val n = !Pass.instructions () in (n - !mark) before mark := n end
      fun counted what = if show then what ^ ", " ^ Int.toString (since ()) ^ " instructions" else what
      fun say (name, what) = if show then TextIO.output (TextIO.stdErr, "rhc: unit " ^ name ^ ": " ^ counted what ^ "\n") else ()
      fun said what = if show then TextIO.output (TextIO.stdErr, "rhc: link: " ^ counted what ^ "\n") else ()
      (* and --dotted-names, by which a module's text is read otherwise *)
      val extra = extraOf strings @ (if dotted then [("names", "dotted")] else [])
      (* a unit's entries in the configuration of units, which no back end's
         setting divides; the link's in the whole one, made where the link
         is looked up or kept: after the compile's own options have set the
         level and the instruction set, which a front made before them
         would not see (build-cache-issues.md, issue 29) *)
      val config = RhcStoreConfig.unitConfiguration extra
      fun linkConfig () = RhcStoreConfig.configuration extra
      fun lookupIn config (key, holds) =
        case store of
          SOME dir => SOME (RhcStore.find {overlay = dir, layers = layers, config = config, key = key, holds = holds})
        | NONE => if null layers then NONE else SOME (RhcStore.findIn {layers = layers, config = config, key = key, holds = holds})
      val lookup = lookupIn config
      (* an entry kept, and the sum of what it holds (UnitStore's); with no
         store, the hash of its sections *)
      fun keepIn (config, settings) (key, usages, prior, sections : RhcStore.sections) : string =
        case store of
          SOME dir =>
            RhcStore.store {dir = dir, settings = settings, config = config, key = key,
                            entry = {head = {usages = usages, exports = Pickle.hash (#iface sections),
                                             level = RhcStoreConfig.level (), prior = prior},
                                     sections = sections}}
        | NONE => Pickle.hash (String.concatWith "\000" (#iface sections :: List.tabulate (#count sections, #parts sections)))
      val keepUnit = keepIn (config, RhcStoreConfig.unitSettings extra)
      val statMemo = Option.map (fn dir => UnitStore.memoAt (dir, config)) store
      (* what f reads of the units before, where there is a store to keep
         it in *)
      fun recorded f = if isSome store then RhcIface.recording f else (f (), [])
      val reader = readerOf {memo = statMemo, lookup = lookup,
                             keep = fn (k, sections) => if isSome store then ignore (keepUnit (k, [], "", sections)) else ()}
      val plan = G.scan {roots = roots, dotted = dotted, known = M.empty, library = false, reader = reader}
      val () = if show then TextIO.output (TextIO.stdErr, "rhc: " ^ counted "the graph read" ^ "\n") else ()
      (* the interfaces of the units before a unit installed once, as each
         is done, and not again from all of them for each unit, which made
         a build of n modules cost as n * n installs, a warm build's too
         (build-cache-issues.md, issue 36): installing is a fold, so the
         state is the one installing them all at once gives *)
      (* each unit checked with a table of evidence of its own, which its
         desugaring and HsLint read: of its modules alone, as at a unit made
         after units taken, and not one of the whole compile's that HsLint's
         replay read every record of for each unit (build-cache-issues.md,
         issue 39) *)
      fun start s = startOf (HsEvidence.empty ()) s
      (* each module's digest, once a compile: what a module exports does
         not move once its unit is done *)
      val digests : string M.map ref = ref M.empty
      fun digestIn (s : N.state) (m : string) =
        case M.find (!digests, m) of
          SOME d => d
        | NONE => let val d = scopeDigest (s, m) in digests := M.insert (!digests, m, d); d end
      val twoPhase = case fixpoint of HsModules.Least => true | HsModules.Greatest => false
      (* RHC_HIT=asked: each usage of an entry asked, as a hit was judged
         before issue 37's A and B, what they keep kept alike: so that a
         test holds a hit to where it stood (hs/units/holes) *)
      val askAll = OS.Process.getEnv "RHC_HIT" = SOME "asked"
      (* the digest of the units before a unit, each on the digest before
         it, where each has an entry: a unit taken, or made and kept (keep),
         in order; NONE after one that has none, a unit made by this
         compile not yet kept *)
      val namesSetting = "names " ^ (case fixpoint of HsModules.Least => "least" | HsModules.Greatest => "greatest")
      fun priorAfter (p : string option, u : unit_) : string option =
        case (p, !(#entry u)) of
          (SOME p, SOME s) => SOME (RhcStore.priorNext (p, (#name u, #key u, s)))
        | _ => NONE
      fun step (found : G.found list, (done : unit_ list, installed : N.state, prints : string M.map, failed : bool,
                                       made : made list, diags : G.diag list, exports, prior : string option)) =
        let
          val ids = List.map #id found
          val name = String.concatWith "+" ids
          val key = unitKey (name, found)
          val nodes = once (fn () => List.map (fn (f : G.found) => #node f ()) found)
          fun own home = List.exists (fn i => i = home) ids
          fun answerIn s r = RhcIface.answer {state = s, fingerprint = fn k => M.find (prints, k), own = own} r
          (* what a read gives now: on the state of the units before, the
             unit's modules named and not checked (their scopes are the
             naming's), the same state at a compile and at a hit *)
          val nowCell : N.state option ref = ref NONE
          fun now () =
            case !nowCell of
              SOME s => s
            | NONE => let val s = N.groups (N.extend (start installed, nodes ()), [nodes ()], fixpoint, NONE)
                      in nowCell := SOME s; s end
          fun current k = case HsUsage.fromKey k of SOME r => answerIn (now ()) r | NONE => "?"
          (* the modules the unit imports, and the digest of each now *)
          val targets = importTargets found
          val scopes = once (fn () => List.map (fn m => (scopePrefix ^ m, digestIn installed m)) targets)
          (* a usage's answer where the scopes are what they were: a name's
             entities, and those of an import's item or exports of a module
             of the unit's own, as they were, with the fingerprints of now;
             any other read answered on the units before, which give it as
             the unit's modules named give it, as nothing they read is the
             unit's *)
          fun cheap (k, v) =
            case HsUsage.fromKey k of
              SOME (HsUsage.Name _) => refreshed (own, fn k => M.find (prints, k)) v
            | SOME (r as HsUsage.Item {from, ...}) =>
                if own from then refreshed (own, fn k => M.find (prints, k)) v else answerIn installed r
            | SOME (r as HsUsage.Exports m) => if own m then v else answerIn installed r
            | SOME r => answerIn installed r
            | NONE => "?"
          (* how the entry taken stood, which --show-units says *)
          val how = ref ""
          fun judge usages =
            let
              val (kept, reads) = List.partition (fn (k, _) => isScope k) usages
              val same = twoPhase andalso not askAll andalso kept = scopes ()
            in
              if same then
                case RhcStore.differing cheap reads of
                  NONE => (how := " (its scopes as they were)"; NONE)
                | moved => moved
              else RhcStore.differing (fn (k, _) => current k) reads
            end
          (* where every unit before is the entry it was, the entry stands
             asking none of its usages (issue 37's B) *)
          val priorNow = fn () => if askAll then NONE else prior
          fun holds (h : RhcStore.head) =
            let
              val () = how := ""
              val v = RhcStore.holdsBy {level = RhcStoreConfig.level (), prior = priorNow, judge = judge} h
            in
              if v = UnitStore.Stands andalso #prior h <> "" andalso priorNow () = SOME (#prior h) then
                how := " (its units before as they were)"
              else ();
              v
            end
          fun make (why, stored) =
            let
              val (s, reads) =
                recorded (fn () => N.groups (N.extend (start installed, nodes ()), [nodes ()], fixpoint,
                                             if failed then NONE else check))
              val r : N.result = {modules = List.rev (#modules s), exports = #exports s, diags = #diags s,
                                  types = if failed orelse not (isSome check) then NONE else SOME (#types s),
                                  evidence = #evidence s, derived = #derived s}
              val ds = List.filter (fn d => not (#library d)) (#diags s)
              val mods = RhcIface.ofModules (s, ids)
              val own' = printsFor (mods, prints)
              val desugared = ref NONE
              val linted = ref NONE
              val sum = ref NONE
              fun mine what f = fn () => case !desugared of SOME x => f x | NONE => raise Fail ("RhcDriver: " ^ name ^ "'s " ^ what)
              val u : unit_ =
                {name = name, ids = ids, mods = mods, prints = #prints own', desugar = mine "desugaring" #2,
                 hslint = fn () => !linted,
                 sum = fn () => case !sum of SOME x => x | NONE => raise Fail ("RhcDriver: " ^ name ^ "'s entry"),
                 indexed = mine "Core" (fn (c, _, _) => CoreUnits.InHand c), key = key, entry = ref NONE}
            in
              say (name, if failed then "named" else "compiled" ^ why);
              (u, SOME {name = name, key = key, ids = ids, nodes = nodes (), r = r, reads = reads, answer = fn x => answerIn (now ()) x,
                        earlier = done, mods = mods, prints = own', desugared = desugared, linted = linted, sum = sum,
                        stored = stored, index = length done,
                        scopes = if twoPhase andalso isSome store then scopes () else []},
               ds, #exports s)
            end
          (* a unit taken: its modules' exports those its entry keeps *)
          fun taken (sections, sum) =
            let
              val files = List.foldl (fn (f : G.found, m) => M.insert (m, #id f, #file f)) M.empty found
              val u = takenUnit {name = name, key = key, ids = ids, files = files, prints = prints} (sections, sum)
            in
              say (name, "taken" ^ !how);
              (u, NONE, [], List.foldl (fn (m : HsModIface.t, e) => M.insert (e, #id m, #exports m)) exports (#mods u))
            end
          val (u, m, ds, ex) =
            if failed then make ("", NONE)
            else
              (* a layer's entry whose fingerprints do not hold their hash
                 is not taken, the unit made (RhcStore.guarded); with
                 --verify-store an entry that stands is not taken either,
                 but held to what the unit made gives (keep) *)
              case lookup (key, holds) of
                SOME (UnitStore.Found (e as {sections, ...}, sum)) =>
                  if !verify then make (" (its entry verified)", SOME (e, sum))
                  else (taken (sections, sum) handle RhcStore.Damaged _ => make (" (a damaged entry)", NONE))
              | SOME (UnitStore.FoundBehind (e as {sections, ...}, sum)) =>
                  if !verify then make (" (its entry verified)", SOME (e, sum))
                  else (taken (sections, sum) handle RhcStore.Damaged _ => make (" (a damaged entry)", NONE))
              | SOME (UnitStore.Missed why) => make (if isSome store then " (" ^ why ^ ")" else "", NONE)
              | NONE => make ("", NONE)
        in
          (done @ [u], N.install (installed, #mods u), List.foldl (fn ((k, f), m) => M.insert (m, k, f)) prints (#prints u), failed orelse not (null ds),
           (case m of SOME x => made @ [x] | NONE => made), diags @ ds, ex, priorAfter (prior, u))
        end
      val (units, _, _, _, made, diags, exports, _) =
        List.foldl step ([], N.initial (leavesOf (#groups plan)), M.empty, false, [], [], M.empty,
                         SOME (RhcStore.priorStart namesSetting))
          (#groups plan)
      val () =
        if show then
          let val parsed = List.filter (fn (f : G.found) => #parsed f ()) (List.concat (#groups plan))
          in
            TextIO.output (TextIO.stdErr, "rhc: parsed " ^ Int.toString (length parsed) ^ " of " ^
                                          Int.toString (length (List.concat (#groups plan))) ^ " modules" ^
                                          String.concat (List.map (fn f => " " ^ #id f) parsed) ^ "\n")
          end
        else ()
      (* What the units before a unit leave its desugaring and HsLint,
         made once for each unit as the units are made in order -- each
         unit's interface learned once (HsDesugar.learnMore), each unit's
         part of HsLint's joined once onto those before it (HsLint.join) --
         and not again from every unit before it for each, which made a
         build of n units cost as n * n (build-cache-issues.md, issue 39) *)
      val unitsAt = once (fn () => Vector.fromList units)
      val dsLearned : (int * HsDesugar.learned) option ref = ref NONE
      fun learnedBefore k =
        let
          fun go (j, l) = if j >= k then (j, l)
                          else go (j + 1, RhcDesugar.learnMore (l, #desugar (Vector.sub (unitsAt (), j)) ()))
          val (j, l) = go (case !dsLearned of SOME x => x | NONE => (0, RhcDesugar.learnedNone ()))
        in
          dsLearned := SOME (j, l); l
        end
      (* the digest of the units before the k-th, made as the units are
         kept in order, each taken one's entry as it was found, each made
         one's as keep keeps it (issue 37's B) *)
      val priorCursor : (int * string option) ref = ref (0, SOME (RhcStore.priorStart namesSetting))
      fun priorBefore k =
        let
          fun go (j, p) = if j >= k then (j, p) else go (j + 1, priorAfter (p, Vector.sub (unitsAt (), j)))
          val (j, p) = go (!priorCursor)
        in
          priorCursor := (j, p); p
        end
      val lintJoined : (int * HsLint.library option) ref = ref (0, NONE)
      fun joinedBefore k =
        let
          fun part j =
            let val u = Vector.sub (unitsAt (), j)
            in
              case #hslint u () of
                SOME l => l
              | NONE => raise Failed ("the entry of " ^ #name u ^ " keeps no part of HsLint's")
            end
          fun go (j, l) = if j >= k then (j, l)
                          else go (j + 1, SOME (case l of NONE => HsLint.join [part j] | SOME a => HsLint.join [a, part j]))
          val (j, l) = go (!lintJoined)
        in
          lintJoined := (j, l); l
        end
      (* where the first unit's inference ended, the library's *)
      val firstCounter = once (fn () => case #hslint (Vector.sub (unitsAt (), 0)) () of
                                          SOME l => HsLint.counterOf l
                                        | NONE => 0)
      fun lint () =
        List.app (fn ({ids, r, index, linted, ...} : made) =>
                    let fun own home = List.exists (fn i => i = home) ids
                    in linted := hslintOf {modules = lintModules (own, r), main = mainIn (own, #roots plan), r = r,
                                           (* its inference numbered from where the
                                              first unit's ended, whatever entries
                                              of the units between a compile took
                                              (issue 40) *)
                                           library = fn () => Option.map (fn l => HsLint.counterFrom (l, firstCounter ()))
                                                                         (joinedBefore index)}
                    end)
          made
      (* each unit made desugared, in order, and kept: the first unit reads
         its own source and rhc's leaves alone, which its key and the
         configuration hold, so it keeps no usage; once *)
      val kept = ref false
      (* the units whose entries --verify-store found otherwise than their
         compiles, and how *)
      val unverified : string list ref = ref []
      fun keep () =
        if !kept then ()
        else
          (kept := true;
           List.app
             (fn ({name, key, ids, nodes, r, reads, answer, earlier, mods, prints, desugared, linted, sum, stored, index, scopes,
                   ...} : made) =>
                let
                  val learned = learnedBefore index
                  val ((core, desugar), reads') =
                    recorded (fn () =>
                      RhcDesugar.unitFrom (learned, index = 0, ids, {groups = [nodes], roots = #roots plan, diags = []}, r))
                  val () = desugared := SOME (core, desugar, reads')
                  fun distinct (seen, [], acc) = List.rev acc
                    | distinct (seen, x :: xs, acc) =
                        let val k = HsUsage.key x
                        in if M.member (seen, k) then distinct (seen, xs, acc) else distinct (M.insert (seen, k, ()), xs, x :: acc) end
                  (* its entry's usages and sections *)
                  fun made () =
                    let
                      val usages = if null earlier then []
                                   else scopes @ List.map (fn x => (HsUsage.key x, answer x)) (distinct (M.empty, reads @ reads', []))
                      val (index, texts) = CoreUnits.index core
                      val coreSum = Pickle.hash (String.concatWith "\000" (index :: texts))
                      val texts = Vector.fromList texts
                      fun part i =
                        if i = desugarPart then desugarText desugar
                        else if i = printsPart then printsText prints
                        else if i = hslintPart then (case !linted of SOME l => HsLint.encode l | NONE => "")
                        else if i = indexPart then index
                        else if i = coreSumPart then coreSum
                        else Vector.sub (texts, i - declsPart)
                      (* with --unfoldings at -O2, what a client may inline
                         or specialise of it (M23) and its functions'
                         strictness signatures (M24); none by default, since
                         no client reads them yet and the store is on by
                         default (D58), so that the simplifier would run on
                         each unit made for nothing *)
                      val (unfoldings, strictness) = if !RhcOptions.unfoldings then RhcSimplify.sectionsOf core else ([], [])
                      val iface = HsIface.encode {modules = List.map (placed "") mods, unfoldings = unfoldings,
                                                  strictness = strictness}
                    in
                      (usages, {iface = iface, parts = part, count = declsPart + Vector.length texts}, coreSum)
                    end
                  (* the digest of the units before it, each kept or taken
                     by now (issue 37's B); and where its entry is, once
                     it has one *)
                  val prior = getOpt (priorBefore index, "")
                  val entry = #entry (Vector.sub (unitsAt (), index))
                in
                  case stored of
                    (* --verify-store: the entry that stood, held to what the
                       unit made gives, and kept as it is; its sum what the
                       link's memo is keyed by *)
                    SOME (e, s) =>
                      let val (usages, sections, coreSum) = made ()
                      in
                        case differs (e, (usages, sections)) of
                          NONE => (sum := SOME coreSum; entry := SOME s)
                        | SOME what => unverified := !unverified @ [name ^ ": " ^ what]
                      end
                  | NONE =>
                      if isSome store then
                        let val (usages, sections, coreSum) = made ()
                        in entry := SOME (keepUnit (key, usages, prior, sections)); sum := SOME coreSum end
                      else ()
                end)
             made;
           if null (!unverified) then ()
           else raise Failed ("--verify-store: the store's entry of a unit is not what compiling it gives: "
                              ^ String.concatWith "; " (!unverified));
           Option.app UnitStore.memoWrite statMemo)
      (* what main reaches of every unit, the program's Core: once *)
      val link =
        once (fn () =>
          let
            val () = keep ()
            val p = CoreUnits.reachIndexed (CoreUnits.InHand (CoreRuntime.program strings) :: List.map (fn (u : unit_) => #indexed u ()) units,
                                            ["main"])
                    handle CoreUnits.Error msg => raise Failed msg
          in
            said "reached"; p
          end)
      (* The link's memo, keyed by the hash of each unit's Core, which
         its entry keeps (its part coreSumPart), so that a link taken reads
         and hashes no unit's Core; with the runtime's, which is rhc's own
         and in the configuration, that is all the back end reads. Not by
         the sums of the units' entries, which hold their definitions'
         places as well, so that a comment or a line moved, an entry of
         other bytes with the same Core, took a link compiled again
         (build-cache-issues.md, issue 35) *)
      fun linkKey () = (keep (); RhcStore.key ("link", List.map (fn (u : unit_) => (#name u, #sum u ())) units))
      val memo =
        case store of
          NONE => NONE
        | SOME _ =>
            SOME {find = fn () =>
                           (case lookupIn (linkConfig ()) (linkKey (), RhcStore.holds {level = RhcStoreConfig.level (), current = fn _ => "?"}) of
                              SOME (UnitStore.Found ({sections, ...}, _)) =>
                                (let val bytes = #parts sections 0 in said (if !verify then "found" else "taken"); SOME bytes end
                                 handle RhcStore.Damaged _ => NONE)
                            | _ => NONE),
                  keep = fn bytes =>
                           (ignore (keepIn (linkConfig (), RhcStoreConfig.settings extra)
                                      (linkKey (), [], "", {iface = "", parts = fn _ => bytes, count = 1}));
                            said "compiled")}
    in
      (* the store trimmed as Rune's is, where it is due (StorePolicy),
         once the compile is done: after the link's memo is looked up and
         kept, never between the units and the link, where it would drop
         a link a week old that this compile was about to take
         (build-cache-issues.md, issue 34) *)
      {graph = {groups = List.map #nodes made, roots = #roots plan, diags = #diags plan}, diags = diags, exports = exports,
       lint = lint, keep = keep, link = link, memo = memo, finish = fn () => Option.app StorePolicy.trimAfter store}
    end
end
