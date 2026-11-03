(* UnitStore alone (the build-system roadmap's D24, M6 and M7): the store of
   a compile in units, with a client of its own that is no compiler -- a
   head of numbers and two sections of text -- linked with Pickle and
   nothing of the compiler's. What it must keep: an entry is found by its
   key and its head, the client's holds decides by the head alone which
   stands, a damaged or half-written one is not there, a lookup hashes no
   more than it judges and takes, the bytes are those docs/units.md
   describes, what is kept by a name beside the entries is read back only
   as it was, a time is kept where an overlay's file is taken, and trim
   removes by age and then by size. *)
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

  (* the client: a head of numbers, two sections of text, the second read
     only where wantSecond says, and Pickle's hash, the sites it is asked
     at counted *)
  val asked : string list ref = ref []
  fun hash (site : string, text : string) : string = (asked := site :: !asked; P.hash text)
  val wantSecond = ref true
  val format : (int list, string * string) S.format =
    {magic = "TST", version = 4, hash = hash,
     writeHead = P.list P.nat, readHead = P.rlist P.rnat,
     sections = fn (a, b) => [a, b],
     ofSections = fn section => (section 0, if !wantSecond then section 1 else "")}
  val settings = [("compiler", "c1"), ("hash", P.probe ()), ("level", "2")]
  val config = S.configuration (hash, settings)

  (* a head stands where its numbers are all even, behind where its first is
     odd, and is refused otherwise *)
  fun holds (head : int list) : S.verdict =
    if List.all (fn n => n mod 2 = 0) head then S.Stands
    else case head of n :: _ => if n mod 2 = 1 then S.StandsBehind else S.Refused "no" | [] => S.Refused "empty"

  fun sectionOf (f : (int list, string * string) S.found) : string option =
    case f of S.Found ({sections = (a, _), ...}, _) => SOME a | S.FoundBehind ({sections = (a, _), ...}, _) => SOME ("behind " ^ a)
            | S.Missed _ => NONE
  fun whyOf (f : (int list, string * string) S.found) : string = case f of S.Missed why => why | _ => ""

  fun put (dir, k, head, text) = ignore (S.store (format, settings) (dir, config, k, {head = head, sections = (text, "second")}))

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

  fun writeBytes (p : string, s : string) =
    let val out = BinIO.openOut p in BinIO.output (out, Byte.stringToBytes s); BinIO.closeOut out end

  (* the file: its mark, its version, the hash of its head, the head, the
     number of its sections, the hash of each, each; named by the hash of
     the head's bytes; the hash asked at the sites "store" and "read", and
     the hash of what it holds that of the hashes of its parts *)
  fun bytes () =
    let
      val dir = scratch ()
      val k = "k"
      val () = asked := []
      val () = put (dir, k, [7, 300], "text")
      val head = let val w = P.writer () in P.list P.nat (w, [7, 300]); P.contents w end
      val expected = let val w = P.writer ()
                     in
                       P.bytes (w, "TST"); P.nat (w, 4); P.string (w, P.hash head); P.string (w, head);
                       P.nat (w, 2); P.string (w, P.hash "text"); P.string (w, P.hash "second");
                       P.string (w, "text"); P.string (w, "second"); P.contents w
                     end
      val p = OS.Path.joinDirFile {dir = S.keyDir (dir, config, k), file = P.hash head}
      val () = need ((S.readFile p = expected) handle IO.Io _ => false, "an entry's bytes")
      val () = need (List.exists (fn s => s = "store") (!asked), "the hash asked at store")
      val about = (S.readFile (S.aboutFile (dir, config))) handle IO.Io _ => ""
      val () = need (about = "compiler c1\nhash " ^ P.probe () ^ "\nlevel 2\n", "the configuration's about")
      val () = asked := []
      val () = case S.find (format, fn _ => S.Stands) (dir, config, k) of
                 S.Found (_, sum) => need (sum = P.hash (String.concatWith "\000" [P.hash head, P.hash "text", P.hash "second"]),
                                           "the hash of what it holds")
               | _ => need (false, "found")
      val () = need (List.filter (fn s => s = "read") (!asked) = ["read", "read", "read"], "the hash asked at read, of each part")
    in removeTree dir end

  (* a lookup reads and hashes no more of an entry than it judges: a head
     that is refused is not hashed, nor anything after it; a section the
     client does not ask for is not hashed, nor held to its hash *)
  fun heads () =
    let
      val dir = scratch ()
      val k = "k"
      val () = put (dir, k, [2, 3], "refused")
      val () = asked := []
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "no", "refused")
      val () = need (List.null (!asked), "a refused head is not hashed")
      val () = put (dir, k, [2, 4], "taken")
      val d = S.keyDir (dir, config, k)
      val p = OS.Path.joinDirFile {dir = d, file = P.hash (let val w = P.writer () in P.list P.nat (w, [2, 4]); P.contents w end)}
      val good = S.readFile p
      (* the second section's last byte changed: a miss where the client
         reads it, a hit where it does not *)
      val flipped = String.substring (good, 0, size good - 1) ^ "x"
      val () = writeBytes (p, flipped)
      val () = need (sectionOf (S.find (format, holds) (dir, config, k)) = NONE, "a section read is held to its hash")
      val () = wantSecond := false
      val () = asked := []
      val got = sectionOf (S.find (format, holds) (dir, config, k))
      val () = wantSecond := true
      val () = need (got = SOME "taken", "a section not read is not held to it")
      val () = need (List.length (List.filter (fn s => s = "read") (!asked)) = 2, "nor hashed")
      (* a head damaged so that it stands: held to its hash *)
      val () = writeBytes (p, good)
      val k3 = "k3"
      val () = put (dir, k3, [1], "odd")
      val d3 = S.keyDir (dir, config, k3)
      val p3 = OS.Path.joinDirFile {dir = d3, file = hd (S.listDir d3)}
      val odd = S.readFile p3
      (* the head's bytes are its count (1) and the number 1, after the
         mark, the version, the head's hash and the head's length: make it 2 *)
      val at = 3 + 1 + 1 + size (P.hash "x") + 1 + 1
      val () = need (String.sub (odd, at) = #"\001", "the head's number where it is looked for")
      val even = String.substring (odd, 0, at) ^ "\002" ^ String.extract (odd, at + 1, NONE)
      val () = writeBytes (p3, even)
      val () = need (whyOf (S.find (format, holds) (dir, config, k3)) = "a damaged entry", "a head that stands is held to its hash")
    in removeTree dir end

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
      val () = writeBytes (p, flip (String.size good - 9))
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "a damaged entry", "a byte of its sections changed")
      val () = writeBytes (p, String.substring (good, 0, String.size good - 2))
      val () = need (String.isPrefix "a damaged entry" (whyOf (S.find (format, holds) (dir, config, k))), "cut short")
      val () = writeBytes (p, String.substring (good, 0, 5))
      val () = need (String.isPrefix "a damaged entry" (whyOf (S.find (format, holds) (dir, config, k))), "cut short in its head")
      val () = writeBytes (p, "XYZ" ^ String.extract (good, 3, NONE))
      val () = need (whyOf (S.find (format, holds) (dir, config, k)) = "a damaged entry: not an entry", "another mark")
      val () = writeBytes (p, "TST\005" ^ String.extract (good, 4, NONE))
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
  (* an overlay's entry has its time set to now when it is taken, where it
     is an hour old; a layer's, and one not taken, keep theirs *)
  val dayAgo = fn () => Time.- (Time.now (), Time.fromSeconds 86400)
  fun age (p : string) : Time.time = Time.- (Time.now (), OS.FileSys.modTime p)
  fun times () =
    let
      val dir = scratch ()
      val () = put (dir, "a", [2], "taken")
      val () = put (dir, "b", [2, 3], "refused")
      val pa = OS.Path.joinDirFile {dir = S.keyDir (dir, config, "a"), file = hd (S.listDir (S.keyDir (dir, config, "a")))}
      val pb = OS.Path.joinDirFile {dir = S.keyDir (dir, config, "b"), file = hd (S.listDir (S.keyDir (dir, config, "b")))}
      val () = (OS.FileSys.setTime (pa, SOME (dayAgo ())); OS.FileSys.setTime (pb, SOME (dayAgo ())))
      val _ = S.find (format, holds) (dir, config, "a")
      val () = need (Time.> (age pa, S.hour), "a layer's time is kept")
      val _ = S.findAt (format, holds) {overlay = true} (dir, config, "a")
      val _ = S.findAt (format, holds) {overlay = true} (dir, config, "b")
      val () = need (Time.< (age pa, Time.fromSeconds 60), "an overlay's entry taken is now")
      val () = need (Time.> (age pb, S.hour), "one refused keeps its time")
      val () = S.storeSide side (dir, config, "unit@1", [(1, "x")])
      val ps = S.sideFile (#hash side, dir, config, "unit@1")
      val () = OS.FileSys.setTime (ps, SOME (dayAgo ()))
      val _ = S.sideIn side ([OS.Path.joinDirFile {dir = dir, file = "none"}, dir], config) "unit@1"
      val () = need (Time.> (age ps, S.hour), "a layer's side file keeps its time")
      val _ = S.sideIn side ([dir], config) "unit@1"
      val () = need (Time.< (age ps, Time.fromSeconds 60), "an overlay's is now")
      val () = OS.FileSys.setTime (ps, SOME (dayAgo ()))
      val () = S.touchSide side (dir, config, "unit@1")
      val () = need (Time.< (age ps, Time.fromSeconds 60), "one a client will want, now")
      val () = S.touchSide side (dir, config, "unit@2")
    in removeTree dir end

  (* trim: what no compile took for longer than the age, then the least
     recently taken past the size; a file being written swept where old,
     and left where new; the directories emptied removed, the store's
     own kept; the mark of the last trim *)
  fun trimmed () =
    let
      val dir = scratch ()
      fun entry (k, text, days) =
        let
          val () = put (dir, k, [2], text)
          val d = S.keyDir (dir, config, k)
          val p = OS.Path.joinDirFile {dir = d, file = hd (S.listDir d)}
        in OS.FileSys.setTime (p, SOME (Time.- (Time.now (), Time.fromSeconds (Int.toLarge (days * 86400))))); p end
      val old = entry ("old", "old", 10)
      val mid = entry ("mid", String.implode (List.tabulate (1000, fn _ => #"m")), 3)
      val new = entry ("new", String.implode (List.tabulate (1000, fn _ => #"n")), 1)
      val tmpOld = OS.Path.joinDirFile {dir = S.keyDir (dir, config, "new"), file = "x.tmp-old"}
      val tmpNew = OS.Path.joinDirFile {dir = S.keyDir (dir, config, "new"), file = "x.tmp-new"}
      val () = (writeBytes (tmpOld, "t"); OS.FileSys.setTime (tmpOld, SOME (dayAgo ())); writeBytes (tmpNew, "t"))
      fun there p = OS.FileSys.access (p, [])
      val () = need (S.trimDue S.hour dir, "a store never trimmed is due")
      val () = S.markTrimmed dir
      val () = need (not (S.trimDue S.hour dir), "one just trimmed is not")
      val week = Time.fromSeconds 604800
      val {removed, files, ...} = S.trim {age = SOME week, size = NONE} dir
      val () = need (not (there old) andalso there mid andalso there new, "by age")
      val () = need (removed = 1, "one removed by age")
      val () = need (not (there tmpOld) andalso there tmpNew, "a file being written, an hour old, swept; a new one kept")
      val () = need (not (OS.FileSys.access (S.keyDir (dir, config, "old"), [])), "its key's directory removed")
      val () = need (there (S.trimmedFile dir), "the mark kept")
      val () = need (files = 4, "the files counted: three entries and about, not the mark nor a file being written")
      val total = Position.toInt (OS.FileSys.fileSize mid) + Position.toInt (OS.FileSys.fileSize new)
                  + Position.toInt (OS.FileSys.fileSize (S.aboutFile (dir, config)))
      val {removed, ...} = S.trim {age = SOME week, size = SOME (LargeInt.fromInt (total - 1))} dir
      val () = need (not (there mid) andalso there new andalso removed = 1, "by size, the least recently taken first")
      val {removed, ...} = S.trim {age = NONE, size = NONE} dir
      val () = need (there new andalso removed = 0, "no limit")
      val () = OS.FileSys.setTime (S.aboutFile (dir, config), SOME (dayAgo ()))
      val {removed, ...} = S.trim {age = SOME (Time.fromSeconds 0), size = NONE} dir
      val () = need (not (there new) andalso removed = 2, "an age of nothing: all")
      val () = need (OS.FileSys.isDir dir andalso there (S.trimmedFile dir), "the store's own directory and its mark stay")
    in removeTree dir end

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
                 Test.it "heads" UnitStoreTests.heads, Test.it "damaged" UnitStoreTests.damaged,
                 Test.it "sides" UnitStoreTests.sides, Test.it "times" UnitStoreTests.times,
                 Test.it "trimmed" UnitStoreTests.trimmed]
end)
val () = UnitStoreTestMain.main ()
