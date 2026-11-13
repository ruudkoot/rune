(* rhc's driver over a program of Haskell in units (the haskell98 roadmap's
   M21f): each group of the module graph, an SCC, is a unit, named and
   checked from the interfaces of the units before it (RhcIface, F's),
   desugared alone (RhcDesugar.unit, D's), its interface (HsIface) and its
   Core kept in the store (RhcStore) keyed by its members' texts (H8, H4),
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

  (* a unit made or taken: its name, its members, its modules' interfaces,
     its desugaring's interface, and its Core *)
  type unit_ = {name : string, ids : string list, mods : HsModIface.t list, desugar : unit -> HsDesugar.interface,
                sum : string, indexed : unit -> CoreUnits.unitCore}

  (* f's value, made once and where it is first asked for *)
  fun once (f : unit -> 'a) : unit -> 'a =
    let val cell = ref NONE
    in fn () => case !cell of SOME v => v | NONE => let val v = f () in cell := SOME v; v end end

  (* the fingerprints of the units' entities and instances, by key or
     identity, each module's from the units before it (HsModIface's) *)
  fun printsOf (done : unit_ list) : string M.map =
    List.foldl (fn (u : unit_, m) =>
                  List.foldl (fn (i, m) =>
                                List.foldl (fn ((k, f), m) => M.insert (m, k, f)) m
                                  (HsModIface.fingerprints Pickle.hash (i, fn k => M.find (m, k))))
                             m (#mods u))
               M.empty done

  type options = {roots : string list, out : string, store : string option, layers : string list, show : bool,
                  strings : CoreRuntime.strings, fault : CoreToMid.fault option,
                  compile : Core.program * string -> int}

  fun compile (opts : options) : int =
    let
      (* the instructions run since the last mark, for --show-units *)
      val mark = ref (!Pass.instructions ())
      fun since () = let val n = !Pass.instructions () in (n - !mark) before mark := n end
      fun counted what = if #show opts then what ^ ", " ^ Int.toString (since ()) ^ " instructions" else what
      val g = G.load {roots = #roots opts, dotted = false}
      val () = if #show opts then TextIO.output (TextIO.stdErr, "rhc: " ^ counted "the graph read" ^ "\n") else ()
      val fixpoint = HsModules.Least
      val check = SOME HsInfer.PerModule
      val evidence = HsEvidence.empty ()
      val leaves = N.leavesOf (List.concat (#groups g))
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
      (* a state with the interfaces of the units before, as F's turns *)
      fun start (ifaces : HsModIface.t list) : N.state =
        let val s = N.install (N.initial leaves, ifaces)
        in
          {defs = #defs s, universe = #universe s, fixities = #fixities s, library = #library s, exports = #exports s,
           scopes = #scopes s, diags = #diags s, modules = #modules s, derived = #derived s, evidence = evidence,
           types = #types s}
        end
      fun textOf (n : G.node) = case G.textOf (#file n) of SOME t => HsSource.bytes t | NONE => ""
      fun step (group : G.node list, done : unit_ list) : unit_ list =
        let
          val ids = List.map #id group
          val name = String.concatWith "+" ids
          val key = RhcStore.key ("hs:" ^ name, List.map (fn n => (#id n, Pickle.hash (textOf n))) group)
          val ifaces = List.concat (List.map #mods done)
          val prints = printsOf done
          fun own home = List.exists (fn i => i = home) ids
          fun answerIn s r = RhcIface.answer {state = s, fingerprint = fn k => M.find (prints, k), own = own} r
          (* what a read gives now: on the state of the units before, the
             unit's modules named and not checked (their scopes are the
             naming's), the same state at a compile and at a hit *)
          val nowCell : N.state option ref = ref NONE
          fun now () =
            case !nowCell of
              SOME s => s
            | NONE => let val s = N.groups (N.extend (start ifaces, group), [group], fixpoint, NONE)
                      in nowCell := SOME s; s end
          fun current k = case HsUsage.fromKey k of SOME r => answerIn (now ()) r | NONE => "?"
          val holds = RhcStore.holds {level = RhcStoreConfig.level (), current = current}
          fun made why =
            let
              val ((s, (core, desugar)), reads) =
                RhcIface.recording (fn () =>
                  let
                    val s = N.groups (N.extend (start ifaces, group), [group], fixpoint, check)
                    val () = case List.filter (fn d => not (#library d)) (#diags s) of
                               [] => ()
                             | d :: _ => raise Failed (#msg d)
                    val r : N.result = {modules = List.rev (#modules s), exports = #exports s, diags = #diags s,
                                        types = SOME (#types s), evidence = evidence, derived = #derived s}
                  in (s, RhcDesugar.unit (List.map (fn (u : unit_) => #desugar u ()) done, ids, g, r)) end)
              val mods = RhcIface.ofModules (s, ids)
              (* the first unit reads its own source and rhc's leaves alone,
                 which its key and the configuration hold *)
              val usages = if null done then [] else List.map (fn r => (HsUsage.key r, answerIn (now ()) r)) reads
              val iface = HsIface.encode {modules = mods, desugar = desugarText desugar, unfoldings = []}
              (* its Core by its declarations, so that a link reads only what
                 it reaches (CoreUnits.indexText) *)
              val (index, texts) = CoreUnits.index core
              val texts = Vector.fromList texts
              val sum = keep (key, usages, {iface = iface, parts = fn 0 => index | i => Vector.sub (texts, i - 1),
                                            count = 1 + Vector.length texts})
            in
              say (name, "compiled" ^ why);
              {name = name, ids = ids, mods = mods, desugar = fn () => desugar, sum = sum, indexed = fn () => CoreUnits.InHand core}
            end
          fun taken ({iface, parts, ...} : RhcStore.sections, sum) =
            let
              val {modules, desugar, ...} = HsIface.decode iface handle HsIface.Bad msg => raise Failed ("the entry of " ^ name ^ ": " ^ msg)
              (* its Core's index read only where the link is compiled, and
                 each declaration's text only where the link reaches it *)
              fun indexed () = CoreUnits.Indexed (parts 0, fn i => parts (i + 1))
            in
              say (name, "taken");
              {name = name, ids = ids, mods = modules, desugar = once (fn () => desugarOf desugar), sum = sum, indexed = indexed}
            end
        in
          done @ [case lookup (key, holds) of
                    SOME (UnitStore.Found ({sections, ...}, sum)) => taken (sections, sum)
                  | SOME (UnitStore.FoundBehind ({sections, ...}, sum)) => taken (sections, sum)
                  | SOME (UnitStore.Missed why) => made (" (" ^ why ^ ")")
                  | NONE => made ""]
        end
      val units = List.foldl step [] (#groups g)
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
