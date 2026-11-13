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
                desugar : unit -> HsDesugar.interface, hslint : unit -> HsLint.library option, sum : string,
                indexed : unit -> CoreUnits.unitCore}

  (* An entry's sections: its modules' interfaces (HsIface's), and its
     parts: the desugaring's interface, read only where a unit is
     desugared after it; its fingerprints; HsLint's part of it, made at
     level 2 (ruling 66; empty below), read only where a unit after it is
     made at level 2; its Core's index; and each of its Core's
     declarations, read only where a link reaches it *)
  val desugarPart = 0
  val printsPart = 1
  val hslintPart = 2
  val indexPart = 3
  val declsPart = 4

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

  type options = {roots : string list, out : string, store : string option, layers : string list, show : bool,
                  strings : CoreRuntime.strings, fault : CoreToMid.fault option,
                  compile : Core.program * string -> int}

  fun compile (opts : options) : int =
    let
      (* the instructions run since the last mark, for --show-units *)
      val mark = ref (!Pass.instructions ())
      fun since () = let val n = !Pass.instructions () in (n - !mark) before mark := n end
      fun counted what = if #show opts then what ^ ", " ^ Int.toString (since ()) ^ " instructions" else what
      val fixpoint = HsModules.Least
      val check = SOME HsInfer.PerModule
      val evidence = HsEvidence.empty ()
      fun say (name, what) =
        if #show opts then TextIO.output (TextIO.stdErr, "rhc: unit " ^ name ^ ": " ^ counted what ^ "\n") else ()
      val extra = [("strings", case #strings opts of CoreRuntime.Lazy => "lazy" | CoreRuntime.Whole => "whole"), ("driver", "hs")]
      val config = RhcStoreConfig.configuration extra
      fun lookup (key, holds) =
        case #store opts of
          SOME dir => SOME (RhcStore.find {overlay = dir, layers = #layers opts, config = config, key = key, holds = holds})
        | NONE => if null (#layers opts) then NONE
                  else SOME (RhcStore.find {overlay = hd (#layers opts), layers = tl (#layers opts), config = config,
                                            key = key, holds = holds})
      (* an entry kept, and the sum of what it holds (UnitStore's); with
         no store, the hash of its sections *)
      fun keep (key, usages, sections : RhcStore.sections) : string =
        case #store opts of
          SOME dir =>
            RhcStore.store {dir = dir, settings = RhcStoreConfig.settings extra, config = config, key = key,
                            entry = {head = {usages = usages, exports = Pickle.hash (#iface sections),
                                             level = RhcStoreConfig.level ()},
                                     sections = sections}}
        | NONE => Pickle.hash (String.concatWith "\000" (#iface sections :: List.tabulate (#count sections, #parts sections)))
      (* The graph read by its modules' headers (RhcGraph.scan): a module's
         text hashed by the stat memo where the store has one (UnitStore's),
         its header kept in the store by that hash, so that a module whose
         unit is taken with no usage asked of its modules is never read
         past its stat, and none is parsed but where its unit is made or its
         usages asked *)
      val memo = Option.map (fn dir => UnitStore.memoAt (dir, config)) (#store opts)
      fun headerKey {file, mode, hash} = RhcStore.key ("module:" ^ mode, [(file, hash)])
      (* a header as bytes, and the header of bytes, NONE where they are
         not one *)
      fun headerText ({name, at, imports} : G.header) : string =
        let
          val w = Pickle.writer ()
          fun span (w, {file, start, stop} : HsSource.span) = (Pickle.string (w, file); Pickle.int (w, start); Pickle.int (w, stop))
        in
          Pickle.string (w, name); span (w, at);
          Pickle.list (fn (w, (m, s)) => (Pickle.string (w, m); span (w, s))) (w, imports);
          Pickle.contents w
        end
      fun headerOf (s : string) : G.header option =
        let
          val r = Pickle.reader s
          fun span r = let val f = Pickle.rstring r val a = Pickle.rint r in {file = f, start = a, stop = Pickle.rint r} end
          val name = Pickle.rstring r
          val at = span r
          val imports = Pickle.rlist (fn r => let val m = Pickle.rstring r in (m, span r) end) r
        in
          if Pickle.atEnd r then SOME {name = name, at = at, imports = imports} else NONE
        end
        handle Pickle.Bad _ => NONE | Subscript => NONE | Overflow => NONE
      val reader : G.reader =
        {hash = fn {file, text, ...} =>
                  case memo of
                    SOME m => UnitStore.hashBy m (file, "rhc", text, Pickle.hash)
                  | NONE => Pickle.hash (text ()),
         header = fn k =>
                    case lookup (headerKey k, fn _ => UnitStore.Stands) of
                      SOME (UnitStore.Found ({sections, ...}, _)) => headerOf (#iface sections)
                    | SOME (UnitStore.FoundBehind ({sections, ...}, _)) => headerOf (#iface sections)
                    | _ => NONE,
         keep = fn (k, h) =>
                  if isSome (#store opts) then ignore (keep (headerKey k, [], {iface = headerText h, parts = fn _ => "", count = 0}))
                  else ()}
      val g = G.scan {roots = #roots opts, dotted = false, known = M.empty, library = false, reader = reader}
      val () = case List.filter (fn (d : G.diag) => not (#library d)) (#diags g) of
                 d :: _ => raise Failed (#msg d)
               | [] => ()
      val () = if #show opts then TextIO.output (TextIO.stdErr, "rhc: " ^ counted "the graph read" ^ "\n") else ()
      (* rhc's leaves the program's modules import (RhcNames.leavesOf, of
         the imports found) *)
      val leaves =
        List.filter (fn (l, _) => List.exists (fn (f : G.found) => List.exists (fn t => t = RhcLibrary.identity l) (#imports f))
                                    (List.concat (#groups g)))
          RhcLibrary.leaves
      (* a state with the interfaces of the units before, as F's turns *)
      fun start (ifaces : HsModIface.t list) : N.state =
        let val s = N.install (N.initial leaves, ifaces)
        in
          {defs = #defs s, universe = #universe s, fixities = #fixities s, library = #library s, exports = #exports s,
           scopes = #scopes s, diags = #diags s, modules = #modules s, derived = #derived s, evidence = evidence,
           types = #types s}
        end
      fun step (found : G.found list, (done : unit_ list, prints : string M.map)) : unit_ list * string M.map =
        let
          val ids = List.map #id found
          val name = String.concatWith "+" ids
          val key = RhcStore.key ("hs:" ^ name, List.map (fn (f : G.found) => (#id f, #hash f)) found)
          (* its modules parsed, where they are first asked for *)
          val nodes = once (fn () => List.map (fn (f : G.found) => #node f ()) found)
          val ifaces = List.concat (List.map #mods done)
          fun own home = List.exists (fn i => i = home) ids
          fun answerIn s r = RhcIface.answer {state = s, fingerprint = fn k => M.find (prints, k), own = own} r
          (* what a read gives now: on the state of the units before, the
             unit's modules named and not checked (their scopes are the
             naming's), the same state at a compile and at a hit *)
          val nowCell : N.state option ref = ref NONE
          fun now () =
            case !nowCell of
              SOME s => s
            | NONE => let val s = N.groups (N.extend (start ifaces, nodes ()), [nodes ()], fixpoint, NONE)
                      in nowCell := SOME s; s end
          fun current k = case HsUsage.fromKey k of SOME r => answerIn (now ()) r | NONE => "?"
          val holds = RhcStore.holds {level = RhcStoreConfig.level (), current = current}
          fun made why =
            let
              val ((s, r, (core, desugar)), reads) =
                RhcIface.recording (fn () =>
                  let
                    val s = N.groups (N.extend (start ifaces, nodes ()), [nodes ()], fixpoint, check)
                    val () = case List.filter (fn d => not (#library d)) (#diags s) of
                               [] => ()
                             | d :: _ => raise Failed (#msg d)
                    val r : N.result = {modules = List.rev (#modules s), exports = #exports s, diags = #diags s,
                                        types = SOME (#types s), evidence = evidence, derived = #derived s}
                    (* the graph RhcDesugar.unit reads: the program's roots *)
                    val graph = {groups = [nodes ()], roots = #roots g, diags = []}
                  in (s, r, RhcDesugar.unit (List.map (fn (u : unit_) => #desugar u ()) done, ids, graph, r)) end)
              (* HsLint at level 2 (ruling 66), out of the recording (it
                 reads no interface): the unit's modules inferred after what
                 it found of the units before, each one's part joined (the
                 first unit, the library's with the Prelude, from nothing),
                 their records replayed; what it found of them alone, kept
                 as a part of the entry; and the target check of the unit's
                 Core *)
              val lint =
                if not (Pass.linting' 2) then NONE
                else
                  let
                    val part = ref NONE
                    val modules =
                      List.mapPartial (fn (n : G.node, ast) =>
                                         if own (#id n) then SOME {id = #id n, ast = ast, library = #library n}
                                         else NONE)
                        (#modules r)
                    fun partsBefore () =
                      List.map (fn (u : unit_) =>
                                  case #hslint u () of
                                    SOME l => l
                                  | NONE => raise Failed ("the entry of " ^ #name u ^ " keeps no part of HsLint's"))
                        done
                  in
                    Pass.checkAt ("hslint", 2)
                      (fn () =>
                         let
                           val {target, part = mine, ...} =
                             HsLint.check
                               {groups = [modules],
                                main = List.find (fn m => own m andalso HsModules.moduleName m = "Main") (#roots g),
                                cycleDefault = false,
                                records = Option.map (fn env => {table = #evidence r, env = env, derived = #derived r})
                                            (#types r),
                                claims = Option.map (HsLint.claims o RhcLint.readFile) (!RhcLint.claims),
                                where_ = fn sp => getOpt (RhcLint.lineColumn sp, "0:0"), fault = RhcLint.fault (),
                                library = case partsBefore () of [] => NONE | ls => SOME (HsLint.join ls)}
                             handle HsLint.Refused (span, msg) => raise Error.Bug (RhcLint.place span ^ ": " ^ msg)
                         in
                           RhcLint.kept := SOME target; part := SOME mine
                         end)
                      ();
                    !part
                  end
              val () = if isSome lint then RhcLint.target core else ()
              val mods = RhcIface.ofModules (s, ids)
              (* the first unit reads its own source and rhc's leaves alone,
                 which its key and the configuration hold *)
              val usages = if null done then [] else List.map (fn r => (HsUsage.key r, answerIn (now ()) r)) reads
              val iface = HsIface.encode {modules = mods, unfoldings = []}
              val own = printsFor (mods, prints)
              (* its Core by its declarations, so that a link reads only what
                 it reaches (CoreUnits.index) *)
              val (index, texts) = CoreUnits.index core
              val texts = Vector.fromList texts
              fun part i =
                if i = desugarPart then desugarText desugar
                else if i = printsPart then printsText own
                else if i = hslintPart then (case lint of SOME l => HsLint.encode l | NONE => "")
                else if i = indexPart then index
                else Vector.sub (texts, i - declsPart)
              val sum = keep (key, usages, {iface = iface, parts = part, count = declsPart + Vector.length texts})
            in
              say (name, "compiled" ^ why);
              {name = name, ids = ids, mods = mods, prints = #prints own, desugar = fn () => desugar,
               hslint = fn () => lint, sum = sum, indexed = fn () => CoreUnits.InHand core}
            end
          fun taken ({iface, parts, ...} : RhcStore.sections, sum) =
            let
              val {modules, ...} = HsIface.decode iface handle HsIface.Bad msg => raise Failed ("the entry of " ^ name ^ ": " ^ msg)
              (* its fingerprints as kept, where what it asked of the units
                 before gives what it gave, else made again *)
              val kept = printsOfText (parts printsPart)
              val own = if List.all (fn (k, v) => M.find (prints, k) = v) (#asked kept) then kept else printsFor (modules, prints)
              (* its Core's index read only where the link is compiled, and
                 each declaration's text only where the link reaches it *)
              fun indexed () = CoreUnits.Indexed (parts indexPart, fn i => parts (i + declsPart))
              (* HsLint's part, decoded only where a unit after it is made
                 at level 2; an entry made below level 2 keeps none *)
              fun hslint () =
                case parts hslintPart of
                  "" => NONE
                | bytes => SOME (HsLint.decode bytes handle HsLint.Decode msg => raise Failed ("the entry of " ^ name ^ ": " ^ msg))
            in
              say (name, "taken");
              {name = name, ids = ids, mods = modules, prints = #prints own, desugar = once (fn () => desugarOf (parts desugarPart)),
               hslint = once hslint, sum = sum, indexed = indexed}
            end
          val u =
            case lookup (key, holds) of
              SOME (UnitStore.Found ({sections, ...}, sum)) => taken (sections, sum)
            | SOME (UnitStore.FoundBehind ({sections, ...}, sum)) => taken (sections, sum)
            | SOME (UnitStore.Missed why) => made (" (" ^ why ^ ")")
            | NONE => made ""
        in
          (done @ [u], List.foldl (fn ((k, f), m) => M.insert (m, k, f)) prints (#prints u))
        end
      val (units, _) = List.foldl step ([], M.empty) (#groups g)
      val () = Option.app UnitStore.memoWrite memo
      val () =
        if #show opts then
          let val parsed = List.filter (fn (f : G.found) => #parsed f ()) (List.concat (#groups g))
          in
            TextIO.output (TextIO.stdErr, "rhc: parsed " ^ Int.toString (length parsed) ^ " of " ^
                                          Int.toString (length (List.concat (#groups g))) ^ " modules" ^
                                          String.concat (List.map (fn f => " " ^ #id f) parsed) ^ "\n")
          end
        else ()
      (* the link, the roadmap's C: its memo keyed by the units' entries,
         by the sum of each, which covers its Core, all the back end reads
         (the runtime's is rhc's own, in the configuration), so that a link
         taken reads and hashes no unit's Core *)
      val linkKey = RhcStore.key ("link", List.map (fn (u : unit_) => (#name u, #sum u)) units)
      fun reached () =
        let
          (* what main reaches of the units, each read only for what it
             reaches *)
          val p = CoreUnits.reachIndexed (CoreUnits.InHand (CoreRuntime.program (#strings opts)) :: List.map (fn (u : unit_) => #indexed u ()) units,
                                          ["main"])
                  handle CoreUnits.Error msg => raise Failed msg
          val () = if Pass.linting' 0 then CoreLint.check p handle CoreLint.Error msg => raise Failed msg else ()
        in p end
      fun bytesOf f = (let val i = BinIO.openIn f in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
      fun write (f, b) = let val o' = BinIO.openOut f in BinIO.output (o', Byte.stringToBytes b); BinIO.closeOut o' end
      fun said what = if #show opts then TextIO.output (TextIO.stdErr, "rhc: link: " ^ counted what ^ "\n") else ()
    in
      case lookup (linkKey, RhcStore.holds {level = RhcStoreConfig.level (), current = fn _ => "?"}) of
        SOME (UnitStore.Found ({sections, ...}, _)) => (said "taken"; write (#out opts, #parts sections 0); 0)
      | _ =>
          let
            val p = reached ()
            val () = said "reached"
            val status = #compile opts (p, #out opts)
          in
            if status = 0 then (ignore (keep (linkKey, [], {iface = "", parts = fn _ => bytesOf (#out opts), count = 1})); said "compiled") else ();
            status
          end
    end
end
