(* UnitStore alone (the build-system roadmap's D24 and M6): the store of a
   compile in units, with a client of its own that is no compiler -- a head
   of numbers and a section of text -- linked with Pickle and nothing of
   the compiler's. What it must keep: an entry is found by its key and its
   head, the client's holds decides which stands, a damaged or half-written
   one is not there, the bytes are those docs/units.md describes, and what
   is kept by a name beside the entries is read back only as it was. *)
structure UnitStoreTests =
struct
  structure S = UnitStore
  structure P = Pickle

  fun need (ok, message) = Expect.that (message, ok)

  (* a store of its own, under the system's temporary directory *)
  fun scratch () : string =
    let
      val t = OS.FileSys.tmpName ()
      val d = t ^ ".store"
    in OS.FileSys.remove t handle OS.SysErr _ => (); S.mkdirs d; d end

  fun removeTree (d : string) : unit =
    (List.app (fn n => let val p = OS.Path.joinDirFile {dir = d, file = n}
                       in if (OS.FileSys.isDir p handle OS.SysErr _ => false) then removeTree p
                          else OS.FileSys.remove p handle OS.SysErr _ => () end) (S.listDir d);
     OS.FileSys.rmDir d handle OS.SysErr _ => ())

  (* the client: a head of numbers, a section of text, and Pickle's hash,
     the sites it is asked at counted *)
  val asked : string list ref = ref []
  fun hash (site : string, text : string) : string = (asked := site :: !asked; P.hash text)
  val format : (int list, string) S.format =
    {magic = "TST", version = 3, hash = hash,
     writeHead = P.list P.nat, readHead = P.rlist P.rnat,
     writeSections = P.string, readSections = P.rstring}
  val settings = [("compiler", "c1"), ("hash", P.probe ()), ("level", "2")]
  val config = S.configuration (hash, settings)

  (* a head stands where its numbers are all even, behind where its first is
     odd, and is refused otherwise *)
  fun holds ({head, ...} : (int list, string) S.entry) : S.verdict =
    if List.all (fn n => n mod 2 = 0) head then S.Stands
    else case head of n :: _ => if n mod 2 = 1 then S.StandsBehind else S.Refused "no" | [] => S.Refused "empty"

  fun sectionOf (f : (int list, string) S.found) : string option =
    case f of S.Found {sections, ...} => SOME sections | S.FoundBehind {sections, ...} => SOME ("behind " ^ sections) | S.Missed _ => NONE
  fun whyOf (f : (int list, string) S.found) : string = case f of S.Missed why => why | _ => ""

  fun put (dir, k, head, text) = S.store (format, settings) (dir, config, k, {head = head, sections = text})

  fun found () =
    let
      val dir = scratch ()
      val k = S.key (hash, ["unit", "source", "1"])
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "no entry", "an empty store has no entry")
      val () = need (not (S.hasEntry (dir, config, k)), "hasEntry of none")
      val () = put (dir, k, [1, 2], "odd first")
      val () = need (sectionOf (S.find (format, holds) (dir, config, k)) = SOME "behind odd first", "one that stands behind, alone")
      val () = put (dir, k, [2, 4], "even")
      val () = need (sectionOf (S.find (format, holds) (dir, config, k)) = SOME "even", "one that stands before one behind")
      val () = need (S.hasEntry (dir, config, k), "hasEntry")
      val () = put (dir, k, [2, 4], "even again")
      val () = need (List.length (S.listDir (S.keyDir (dir, config, k))) = 2, "the same head writes over its entry")
      val () = need (sectionOf (S.find (format, holds) (dir, config, k)) = SOME "even again", "the last written")
      val k2 = S.key (hash, ["unit", "source", "0"])
      val () = put (dir, k2, [2, 3], "refused")
      val () = need (whyOf (S.find (format, holds) (dir, config, k2)) = "no", "the client's reason")
      val () = need (whyOf (S.find (format, holds) (dir, config, S.key (hash, ["other"]))) = "no entry", "another key")
      val () = need (S.otherBut "hash" (settings, dir, config) = NONE, "no other configuration where its own is there")
      val other = S.configuration (hash, [("compiler", "c1"), ("hash", "other"), ("level", "2")])
      val () = need (S.otherBut "hash" (List.map (fn ("hash", _) => ("hash", "mine") | s => s) settings, dir,
                                       S.configuration (hash, [("compiler", "c1"), ("hash", "mine"), ("level", "2")]))
                     = SOME (P.probe ()), "a configuration that differs in the hash alone")
      val () = need (S.otherBut "level" ([("compiler", "c1"), ("hash", "other"), ("level", "3")], dir, other) = NONE,
                     "one that differs in another setting")
      val () = need (S.otherBut "level" ([("compiler", "c1"), ("hash", P.probe ()), ("level", "3")], dir, other) = SOME "2",
                     "one that differs in that setting alone")
    in removeTree dir end

  (* the file: its mark, its version, the hash of its body, the head, the
     sections; named by the hash of the head's bytes; and the hash asked at
     the sites "store" and "read" *)
  fun bytes () =
    let
      val dir = scratch ()
      val k = "k"
      val () = asked := []
      val () = put (dir, k, [7, 300], "text")
      val head = let val w = P.writer () in P.list P.nat (w, [7, 300]); P.contents w end
      val body = let val w = P.writer () in P.list P.nat (w, [7, 300]); P.string (w, "text"); P.contents w end
      val expected = let val w = P.writer ()
                     in P.bytes (w, "TST"); P.nat (w, 3); P.string (w, P.hash body); P.bytes (w, body); P.contents w end
      val p = OS.Path.joinDirFile {dir = S.keyDir (dir, config, k), file = P.hash head}
      val () = need ((S.readFile p = expected) handle IO.Io _ => false, "an entry's bytes")
      val () = need (List.exists (fn s => s = "store") (!asked), "the hash asked at store")
      val about = (S.readFile (S.aboutFile (dir, config))) handle IO.Io _ => ""
      val () = need (about = "compiler c1\nhash " ^ P.probe () ^ "\nlevel 2\n", "the configuration's about")
      val () = asked := []
      val _ = S.find (format, holds) (dir, config, k)
      val () = need (!asked = ["read"], "the hash asked at read")
    in removeTree dir end

  fun writeBytes (p : string, s : string) =
    let val out = BinIO.openOut p in BinIO.output (out, Byte.stringToBytes s); BinIO.closeOut out end

  (* an entry not whole, of another version or another mark, or one being
     written, is not there, and why is said *)
  fun damaged () =
    let
      val dir = scratch ()
      val k = "k"
      val () = put (dir, k, [2], "good")
      val d = S.keyDir (dir, config, k)
      val p = OS.Path.joinDirFile {dir = d, file = hd (S.listDir d)}
      val good = S.readFile p
      fun flip i = String.substring (good, 0, i) ^ String.str (Char.chr ((Char.ord (String.sub (good, i)) + 1) mod 256))
                   ^ String.extract (good, i + 1, NONE)
      val () = writeBytes (p, flip (String.size good - 1))
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "a damaged entry", "a byte of its sections changed")
      val () = writeBytes (p, String.substring (good, 0, String.size good - 2))
      val () = need (String.isPrefix "a damaged entry" (whyOf (S.find (format, holds) (dir, config, k))), "cut short")
      val () = writeBytes (p, "XYZ" ^ String.extract (good, 3, NONE))
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "a damaged entry: not an entry", "another mark")
      val () = writeBytes (p, "TST\004" ^ String.extract (good, 4, NONE))
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "a damaged entry: an entry of another version", "another version")
      val () = writeBytes (p, good)
      val () = need (sectionOf (S.find (format, holds) (dir, config, k)) = SOME "good", "whole again")
      (* one being written beside it, which find and hasEntry pass over *)
      val () = OS.FileSys.remove p
      val () = writeBytes (p ^ ".tmp-x", good)
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "no entry", "a file being written is not an entry")
      val () = need (not (S.hasEntry (dir, config, k)), "nor for hasEntry")
    in removeTree dir end

  (* what is kept by a name: read back as written, in the first directory
     of a list that has it, and not where its name or bytes say otherwise *)
  val side : (int * string) list S.side =
    {magic = "TSP", version = 3, hash = fn (_, text) => hash ("paths", text),
     write = P.list (fn (w, (n, s)) => (P.nat (w, n); P.string (w, s))),
     read = P.rlist (fn r => let val n = P.rnat r in (n, P.rstring r) end)}
  fun sides () =
    let
      val a = scratch ()
      val b = scratch ()
      val () = S.storeSide side (a, config, "unit@1", [(1, "x"), (2, "y.z")])
      val () = S.storeSide side (b, config, "unit@2", [(3, "w")])
      val () = need (S.readSide side (a, config, "unit@1") = SOME [(1, "x"), (2, "y.z")], "read back")
      val () = need (S.readSide side (a, config, "unit@2") = NONE, "another name")
      val () = need (S.sideIn side ([a, b], config) "unit@2" = SOME [(3, "w")], "the second directory")
      val () = need (S.sideIn side ([a, b], config) "unit@3" = NONE, "in neither")
      val p = S.sideFile (#hash side, a, config, "unit@1")
      val () = need (OS.Path.file p = P.hash "unit@1", "named by the hash of its name")
      val s = S.readFile p
      val () = writeBytes (p, String.substring (s, 0, String.size s - 1) ^ "q")
      val () = need (S.readSide side (a, config, "unit@1") = NONE, "a byte changed")
    in removeTree a; removeTree b end
end

structure UnitStoreTestMain = Main (struct
  val name = "compiler-store"
  val tests = Test.describe "compiler-store"
                [Test.it "found" UnitStoreTests.found, Test.it "bytes" UnitStoreTests.bytes,
                 Test.it "damaged" UnitStoreTests.damaged, Test.it "sides" UnitStoreTests.sides]
end)
val () = UnitStoreTestMain.main ()
