(* rhc's entries in the store alone (the haskell98 roadmap's M21a, D43):
   RhcStore over UnitStore, linked with Pickle and nothing of a compiler,
   its sections two texts. What it must keep: an entry is found by its key
   and stands by its usages judged against what is given now, never by
   what it says (H3); one checked at a lower level of the lint is refused;
   a key is over every member and its text, in the graph's order (H8); the
   overlay is read before the layers, a layer is read and never written,
   and one configuration's entries are not another's; a damaged code
   section is refused where it is read, which is where it is asked for; a
   head is read back as it was written. *)
structure RhcStoreTests =
struct
  structure R = RhcStore
  structure S = UnitStore

  fun need (ok, message) = Expect.that (message, ok)

  fun scratch () : string =
    let
      val t = OS.FileSys.tmpName ()
      val d = t ^ ".rhcstore"
    in OS.FileSys.remove t handle OS.SysErr _ => (); S.mkdirs d; d end

  fun removeTree (d : string) : unit =
    (List.app (fn n => let val p = OS.Path.joinDirFile {dir = d, file = n}
                       in if (OS.FileSys.isDir p handle OS.SysErr _ => false) then removeTree p
                          else OS.FileSys.remove p handle OS.SysErr _ => () end) (S.listDir d);
     OS.FileSys.rmDir d handle OS.SysErr _ => ())

  (* the files under a directory, each with its bytes *)
  fun files (d : string) : (string * string) list =
    List.concat (List.map (fn n =>
                             let val p = OS.Path.joinDirFile {dir = d, file = n}
                             in if (OS.FileSys.isDir p handle OS.SysErr _ => false) then files p else [(p, S.readFile p)] end)
                          (S.sorted (S.listDir d)))

  val settings = [("tool", "rhc"), ("identity", "test"), ("hash", Pickle.probe ())]
  val config = S.configuration (R.hash, settings)

  (* what a usage gives now, from a table of the test's; an absent name
     gives "-", as the driver's does *)
  fun now (table : (string * string) list) (k : string) : string =
    case List.find (fn (n, _) => n = k) table of SOME (_, v) => v | NONE => "-"
  fun judge (level, table) = R.holds {level = level, current = now table}

  fun entry (usages, iface, level) : R.entry =
    {head = {usages = usages, exports = "exports of " ^ iface, level = level}, sections = {iface = iface, code = fn () => "code"}}

  fun put (dir, k, e) = ignore (R.store {dir = dir, settings = settings, config = config, key = k, entry = e})

  fun ifaceOf (f : (R.head, R.sections) S.found) : string option =
    case f of S.Found ({sections = {iface, ...}, ...}, _) => SOME iface | _ => NONE
  fun whyOf (f : (R.head, R.sections) S.found) : string = case f of S.Missed why => why | _ => ""

  fun look (overlay, layers, k, holds) = R.find {overlay = overlay, layers = layers, config = config, key = k, holds = holds}

  (* found by its key, standing where every usage gives what it gave *)
  fun usages () =
    let
      val dir = scratch ()
      val k = R.key ("Main", [("Main", "h1")])
      val us = [("v Prelude.map", "Prelude 3"), ("v Data.absent", "-"), ("i Show Int", "Prelude 7")]
      val () = put (dir, k, entry (us, "main", 2))
      val table = [("v Prelude.map", "Prelude 3"), ("i Show Int", "Prelude 7")]
      val () = need (ifaceOf (look (dir, [], k, judge (2, table))) = SOME "main", "an entry whose usages hold now is found")
      (* a name absent then and present now (H1), an instance absent then and present now (H2) *)
      val f = look (dir, [], k, judge (2, ("v Data.absent", "Data 1") :: table))
      val () = need (ifaceOf f = NONE, "a name absent then, present now, refuses the entry")
      val () = need (String.isSubstring "v Data.absent as -, which is Data 1 now" (whyOf f), "and says why: " ^ whyOf f)
      val () = need (ifaceOf (look (dir, [], k, judge (2, [("v Prelude.map", "Prelude 4"), ("i Show Int", "Prelude 7")])))
                     = NONE, "a name whose fingerprint moved refuses the entry")
      val () = need (ifaceOf (look (dir, [], k, judge (2, [("v Prelude.map", "Prelude 3")]))) = NONE,
                     "an instance present then, absent now, refuses the entry")
      (* the lint's level *)
      val () = need (ifaceOf (look (dir, [], k, judge (1, table))) = SOME "main", "an entry checked at 2 serves a compile at 1")
      val f3 = look (dir, [], k, judge (3, table))
      val () = need (ifaceOf f3 = NONE andalso String.isSubstring "lower level" (whyOf f3),
                     "an entry checked at 2 is refused by a compile at 3: " ^ whyOf f3)
      (* two entries under one key, the one that stands taken *)
      val () = put (dir, k, entry ([("v Prelude.map", "Prelude 4")], "main after", 2))
      val () = need (ifaceOf (look (dir, [], k, judge (2, [("v Prelude.map", "Prelude 4")]))) = SOME "main after",
                     "of two entries of a key, the one whose usages hold")
      val () = need (ifaceOf (look (dir, [], k, judge (2, table))) = SOME "main", "and the other, for the other graph")
    in removeTree dir end

  (* a key over every member and its text, in the order given *)
  fun keys () =
    let
      val ab = R.key ("A+B", [("A", "ha"), ("B", "hb")])
      val () = need (ab <> R.key ("A+B", [("A", "ha"), ("B", "hb2")]), "a member's text is in the key, the second's too")
      val () = need (ab <> R.key ("A+B", [("A", "ha2"), ("B", "hb")]), "and the first's")
      val () = need (ab <> R.key ("A+B", [("A", "ha")]), "every member is in the key")
      val () = need (ab <> R.key ("A", [("A", "ha"), ("B", "hb")]), "the unit's name is in the key")
      val () = need (ab = R.key ("A+B", [("A", "ha"), ("B", "hb")]), "the same unit, the same key")
    in () end

  (* the overlay before the layers; a layer read, never written; one
     configuration apart from another *)
  fun layers () =
    let
      val overlay = scratch ()
      val layer = scratch ()
      val k = R.key ("Prelude", [("Prelude", "hp")])
      val () = put (layer, k, entry ([], "from the layer", 2))
      val earlier = files layer
      val f = look (overlay, [layer], k, judge (2, []))
      val () = need (ifaceOf f = SOME "from the layer", "an entry in a layer alone is found there")
      val () = need (files layer = earlier, "a layer is left as it was")
      val () = need (files overlay = [], "and nothing is written to the overlay by a lookup")
      val () = put (overlay, k, entry ([], "from the overlay", 2))
      val () = need (ifaceOf (look (overlay, [layer], k, judge (2, []))) = SOME "from the overlay",
                     "an entry in the overlay is taken before a layer's")
      val other = S.configuration (R.hash, ("level", "1") :: settings)
      val () = need (other <> config, "another setting, another configuration")
      val () = need (ifaceOf (R.find {overlay = overlay, layers = [layer], config = other, key = k, holds = judge (2, [])})
                     = NONE, "one configuration's entries are not another's")
    in removeTree overlay; removeTree layer end

  (* a damaged entry is a miss; a head read back as written *)
  fun damaged () =
    let
      val dir = scratch ()
      val k = R.key ("M", [("M", "hm")])
      val us = [("v A.x", "A \000 1"), ("e B", ""), ("n C y", "C 2")]
      val () = put (dir, k, entry (us, "m", 2))
      val () =
        case look (dir, [], k, judge (2, us)) of
          S.Found ({head = {usages, exports, level}, sections = {iface, code = codeOf}}, _) =>
            need (usages = us andalso exports = "exports of m" andalso level = 2 andalso iface = "m" andalso codeOf () = "code",
                  "a head and its sections are read back as written")
        | _ => need (false, "the entry is found")
      val entries = List.filter (fn (p, _) => not (String.isSubstring "/units/" p)) (files dir)
      val () = need (length entries = 1, "one entry")
      val (p, bytes) = hd entries
      val last = String.size bytes - 1
      val bad = String.substring (bytes, 0, last) ^ String.str (Char.chr ((Char.ord (String.sub (bytes, last)) + 1) mod 256))
      val out = BinIO.openOut p
      val () = (BinIO.output (out, Byte.stringToBytes bad); BinIO.closeOut out)
      (* the last byte is the code's, a section read only where it is
         asked for: refused there *)
      val () =
        case look (dir, [], k, judge (2, us)) of
          S.Found ({sections = {code = codeOf, ...}, ...}, _) =>
            need ((ignore (codeOf ()); false) handle _ => true, "a damaged code section is refused where it is read")
        | _ => need (false, "an entry whose code alone is damaged is found, its code not yet read")
    in removeTree dir end
end

structure RhcStoreTestMain = Main (struct
  val name = "rhc-store"
  val tests = Test.describe "rhc-store"
                [Test.it "usages" RhcStoreTests.usages, Test.it "keys" RhcStoreTests.keys,
                 Test.it "layers" RhcStoreTests.layers, Test.it "damaged" RhcStoreTests.damaged]
end)
val () = RhcStoreTestMain.main ()
