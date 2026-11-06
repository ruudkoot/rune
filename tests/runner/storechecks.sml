(* The checks of the store (docs/units.md, The store; the build-system
   roadmap's D24 and M7). Each is a scenario of bin/rune-incremental.

   store-place: where a compile keeps its store. In a workspace, .rune beside
   its rune.workspace, whatever file a build begins with and wherever the
   compile is run from, so that two builds of one workspace whose first
   lines differ share their units, and nothing beside a build's first input
   or in its sources, nor where the REPL's use reads a file; RUNE_CACHE
   above that, --cache-dir above both; with no workspace, beside the build
   file. The workspace moved, its store with it, takes every unit and is the
   build without the store, an edit there too.

   store-trim: what trimming removes is a miss, never a wrong hit. A project
   built, edited and built again, so that its store holds stale entries, is
   trimmed to sizes from the whole store down to a byte, its times put a
   month back and trimmed by age, by hand and after a build, and every other
   file and every third removed as another compile's trimming might; after
   each, a build must be the build without a store, bytes and warnings. A
   frozen layer is never trimmed nor written, and a limit that is not one is
   refused.

   store-damage: an entry damaged where it still reads, its hashes kept --
   in its head, so that it stands, or in its first section -- is compiled
   again, not taken (the mutants C5 and C14).

   store-heads: a warm build's cost does not grow with stale entries (E13).
   A project's units are looked up through a store that holds their entries
   alone, and through one where edits since undone left three more under
   most keys: the bytes hashed reading the store are the same, since a
   lookup reads the heads of the entries it refuses and hashes nothing of
   them. *)
structure StoreChecks =
struct
  open Incremental

  val prefix = "store-"

  (* a compile as it is run by hand, RUNE_CACHE unset unless given *)
  fun rune (s : state) env args = command s "" (["env", "-u", "RUNE_CACHE"] @ env @ (#compiler s :: args))

  fun ok (s : state) label (r : Scenarios.result) =
    check s (label ^ ": failed: " ^ #errors r) (#status r = 0)

  fun compiledBy (r : Scenarios.result) : string list = Scenarios.rebuilt (#errors r)

  fun filesBelow (s : state) dir = entriesBelow (path s dir)

  (* ---- where ---- *)

  fun place (s : state) =
    let
      val () = reset s
      val () = put s "rune.workspace" "(* the root of store-place *)"
      val () = put s "build/config.sml" "structure Config = struct val n = 1 end"
      val () = put s "src/a.sml" "structure A = struct val x = Config.n + 1 end"
      val () = put s "src/main.sml" "val () = print (Int.toString A.x ^ \"\\n\")"
      val () = put s "src/z.sml" "structure Z = struct val z = 0 end"
      val () = put s "p.build" "build/config.sml src/a.sml src/main.sml"
      val () = put s "q.build" "src/z.sml build/config.sml src/a.sml src/main.sml"
      val first = rune s [] ["--units", "--explain-rebuild", "--build", "p.build", "-o", "p.rbc"]
      val () = ok s "a build in a workspace" first
      val () = check s "the store is not the workspace's .rune" (not (List.null (filesBelow s ".rune")))
      val () = check s "a store beside the build's first input" (not (exists (path s "build/.rune")))
      val () = check s "a store among the sources" (not (exists (path s "src/.rune")))
      (* another first line: the same store, whose units it takes *)
      val other = rune s [] ["--units", "--explain-rebuild", "--build", "q.build", "-o", "q.rbc"]
      val () = ok s "a build that begins with another file" other
      val () = check s ("a build that begins with another file did not share the store: compiled "
                        ^ String.concatWith " " (compiledBy other))
                     (compiledBy other = ["src/z.sml"])
      (* from below the root *)
      val below = command s "" ["sh", "-c", "cd src && exec env -u RUNE_CACHE \"$0\" --units --explain-rebuild --build ../p.build -o ../b.rbc",
                                #compiler s]
      val () = ok s "a build run from below the root" below
      val () = check s ("a build run from below the root did not find the store: compiled " ^ String.concatWith " " (compiledBy below))
                     (List.null (compiledBy below))
      val () = check s "a store where the build was run from" (not (exists (path s "src/.rune")))
      (* a file given by itself, below the root *)
      val already = List.length (filesBelow s ".rune")
      val loose = command s "" ["sh", "-c", "cd src && exec env -u RUNE_CACHE \"$0\" --units z.sml -o ../z.rbc", #compiler s]
      val () = ok s "a file given by itself" loose
      val () = check s "a file given by itself kept nothing in the workspace's store"
                     (List.length (filesBelow s ".rune") > already andalso not (exists (path s "src/.rune")))
      (* the REPL's use of a file below the root *)
      val () = put s "src/r.sml" "val r = 41 + 1;"
      val () = write (path s "use.in", "use \"src/r.sml\";\n")
      val already = List.length (filesBelow s ".rune")
      val used = command s (path s "use.in") ["env", "-u", "RUNE_CACHE", OS.Path.dir (#compiler s) ^ "/rune-repl", "--no-init"]
      val () = check s ("the REPL's use: " ^ #output used ^ #errors used) (String.isSubstring "42" (#output used))
      val () = check s "the REPL's use kept nothing in the workspace's store"
                     (List.length (filesBelow s ".rune") > already andalso not (exists (path s "src/.rune")))
      (* RUNE_CACHE, then --cache-dir *)
      val r = rune s ["RUNE_CACHE=" ^ path s "elsewhere"] ["--units", "--build", "p.build", "-o", "e.rbc"]
      val () = ok s "RUNE_CACHE" r
      val () = check s "RUNE_CACHE is not where the store is" (not (List.null (filesBelow s "elsewhere")))
      val r = rune s ["RUNE_CACHE=" ^ path s "elsewhere"] ["--units", "--cache-dir", "given", "--build", "p.build", "-o", "g.rbc"]
      val () = ok s "--cache-dir" r
      val () = check s "--cache-dir is not where the store is" (not (List.null (filesBelow s "given")))
      (* no workspace above: beside the build file *)
      val t = OS.FileSys.tmpName ()
      val () = OS.FileSys.remove t handle OS.SysErr _ => ()
      val outside = t ^ ".store-place"
      val () = mkdirs outside
      val () = write (outside ^ "/a.sml", "val () = print \"outside\\n\"\n")
      val () = write (outside ^ "/o.build", "a.sml\n")
      val r = rune s [] ["--units", "--build", outside ^ "/o.build", "-o", "o.rbc"]
      val there = exists (outside ^ "/.rune")
      val () = rmTree outside
      val () = ok s "a build with no workspace" r
      val () = check s "a build with no workspace keeps no store beside its build file" there
      val ran = command s "" [OS.Path.dir (#compiler s) ^ "/runevm", "q.rbc"]
      val () = check s ("the program of the shared store: " ^ #output ran) (#output ran = "2\n")
      (* the workspace moved, its store with it: every unit taken where it is
         now, nothing stale, and an edit there seen *)
      val moved = !(#directory s) ^ "-moved"
      val () = rmTree moved
      val () = ok s "the workspace moved" (command s "" ["cp", "-a", !(#directory s), moved])
      fun there args =
        command s "" (["sh", "-c", "cd \"$0\" && exec env -u RUNE_CACHE \"$@\"", moved, #compiler s] @ args)
      fun agreesThere label =
        let
          val w = there ["--units", "--explain-rebuild", "--build", "p.build", "-o", "w.rbc"]
          val n = there ["--units", "--no-cache", "--build", "p.build", "-o", "n.rbc"]
        in
          ok s label w; ok s (label ^ ", without the store") n;
          check s (label ^ ": the build differs from one without the store") (same (moved ^ "/w.rbc", moved ^ "/n.rbc"));
          compiledBy w
        end
      val first = agreesThere "a build of the workspace moved"
      val () = check s ("a build of the workspace moved compiled " ^ String.concatWith " " first) (List.null first)
      val () = write (moved ^ "/src/a.sml", "structure A = struct val x = Config.n + 2 end\n")
      val edited = agreesThere "an edit in the workspace moved"
      val () = check s ("an edit in the workspace moved compiled " ^ String.concatWith " " edited)
                     (List.exists (fn u => u = "src/a.sml") edited)
    in rmTree moved end

  (* ---- trimming ---- *)

  fun sizeOf (s : state) dir =
    List.foldl (fn (f, n) => if String.isSuffix "/memo/units/trimmed" f then n else n + Position.toInt (OS.FileSys.fileSize f))
               0 (filesBelow s dir)

  fun trim (s : state) args = rune s [] (["--cache-trim", "--cache-dir", "cache"] @ args)

  (* a build through the store, the same as one without it *)
  fun agrees (s : state) label =
    let
      val w = rune s [] (["--units", "--cache-dir", "cache"] @ words (path s "files") @ ["-o", "w.rbc"])
      val n = rune s [] (["--units", "--no-cache"] @ words (path s "files") @ ["-o", "n.rbc"])
    in
      ok s label w;
      check s (label ^ ": the build differs from one without the store") (same (path s "w.rbc", path s "n.rbc"));
      check s (label ^ ": the warnings differ from a build without the store") (#errors w = #errors n)
    end

  (* the project, built, edited and built again, each edit undone: a
     constructor added to A.shape, which the units after a.sml use, so that
     each edit leaves entries of theirs under their keys *)
  fun stale (s : state) =
    let
      val () = fresh s
      val () = agrees s "first"
      val anchor = "Rect of int * int"
      fun round n =
        let val new = anchor ^ " | Stale" ^ Int.toString n
        in edit s "a.sml" anchor new; agrees s ("edited: " ^ new); edit s "a.sml" new anchor; agrees s ("undone: " ^ new) end
    in
      List.app round [1, 2, 3]
    end

  fun old (s : state) days =
    ok s "times put back" (command s "" ["sh", "-c", "find cache -type f -exec touch -d '" ^ Int.toString days ^ " days ago' {} +"])

  fun trims (s : state) =
    let
      val () = stale s
      val whole = sizeOf s "cache"
      val () = check s "the store is empty" (whole > 0)
      fun bySize n =
        let val r = trim s ["--cache-max-size", Int.toString n]
        in
          ok s ("trimmed to " ^ Int.toString n) r;
          check s ("trimmed to " ^ Int.toString n ^ ", the store is " ^ Int.toString (sizeOf s "cache")) (sizeOf s "cache" <= n);
          agrees s ("after a trim to " ^ Int.toString n ^ " bytes")
        end
      val () = List.app bySize [whole - 1, whole div 2, whole div 8, 1]
      (* by age, by hand *)
      val () = stale s
      val () = old s 30
      val r = trim s []
      val () = ok s "trimmed by age" r
      val () = check s "a store a month old trimmed by age kept something" (sizeOf s "cache" = 0)
      val () = agrees s "after a trim by age"
      (* by age, after a build, which keeps what it took *)
      val () = stale s
      val many = List.length (cache s)
      val () = old s 30
      (* not up to date, so that the build looks each unit up *)
      val () = ok s "a source touched" (command s "" ["touch", path s "a.sml"])
      val () = agrees s "a build that trims after it"
      val () = check s "a build whose store was last trimmed a month ago did not trim it" (List.length (cache s) < many)
      val r = rune s [] (["--units", "--cache-dir", "cache", "--explain-rebuild"] @ words (path s "files") @ ["-o", "w.rbc"])
      val () = check s ("a build after it compiled what the build that trimmed took: " ^ String.concatWith " " (compiledBy r))
                     (#status r = 0 andalso List.null (compiledBy r))
      val () = agrees s "after a build that trimmed"
      (* what another compile's trim might leave *)
      fun every k label =
        let
          val () = stale s
          val files = filesBelow s "cache"
          val () = List.app (fn (i, f) => if i mod k = 0 then OS.FileSys.remove f else ()) (ListPair.zip (List.tabulate (length files, fn i => i), files))
        in agrees s label end
      val () = every 2 "every other file of the store removed"
      val () = every 3 "every third file of the store removed"
      (* a layer is neither written nor trimmed *)
      val lib = OS.Path.dir (OS.Path.dir (#compiler s)) ^ "/lib/cache"
      val r = rune s [] ["--cache-trim", "--cache-dir", lib]
      val () = check s ("a trim of the frozen layer was not refused: " ^ #errors r)
                     (#status r <> 0 andalso String.isSubstring "is a layer" (#errors r))
      (* limits that are none *)
      fun refused (args, says) =
        let val r = rune s [] (["--cache-trim", "--cache-dir", "cache"] @ args)
        in check s (String.concatWith " " args ^ " was not refused: " ^ #errors r) (#status r <> 0 andalso String.isSubstring says (#errors r)) end
    in
      List.app refused
        [(["--cache-max-age", "x"], "--cache-max-age requires"), (["--cache-max-age", "-1"], "--cache-max-age requires"),
         (["--cache-max-age", "36501"], "--cache-max-age requires"), (["--cache-max-size", "12Q"], "--cache-max-size requires"),
         (["--cache-max-size", "G"], "--cache-max-size requires"), (["--cache-max-size", "2000T"], "--cache-max-size requires"),
         (["--cache-max-size"], "--cache-max-size requires"), (["--no-cache"], "there is no store")];
      ok s "limits that are none" (trim s ["--cache-max-age", "none", "--cache-max-size", "none"])
    end

  (* ---- stale entries ---- *)

  fun hashedReading (r : Scenarios.result) : int =
    case List.mapPartial (fn l => if String.isPrefix "hash cache:read: " l
                                  then Int.fromString (String.extract (l, size "hash cache:read: ", NONE)) else NONE)
                         (lines (#errors r)) of
      [n] => n
    | _ => ~1

  fun heads (s : state) =
    let
      val () = fresh s
      val () = agrees s "first"
      fun looked label =
        let val r = rune s [] (["--units", "--cache-dir", "cache", "--pass-stats=hash"] @ words (path s "files") @ ["-o", "w.rbc"])
        in ok s label r; hashedReading r end
      val clean = looked "through a store of its entries alone"
      val () = check s "no hash of the store's entries counted" (clean > 0)
      val entries = List.length (cache s)
      val () = stale s
      val () = check s "the edits left no stale entry" (List.length (cache s) > entries)
      val staled = looked "through a store of stale entries"
    in
      check s ("reading a store with stale entries hashed " ^ Int.toString staled ^ " bytes, and one without "
               ^ Int.toString clean) (staled = clean)
    end

  (* ---- damage ---- *)

  (* Every entry of a project damaged where it still reads, its hashes kept:
     in its head, so that it still stands, or in its first section; each
     unit then compiled, not taken, and the build the build without the
     store; and a damaged Mid, which a build of the units' code does not
     read, taken by one and not by --whole *)
  fun damage (s : state) =
    let
      fun damaged (what, says) =
        let
          val () = fresh s
          val () = agrees s "first"
          val hit = List.filter (fn f => CachePlant.damage f what) (cache s)
          val () = check s ("no entry to damage in its " ^ what) (not (List.null hit))
          val r = rune s [] (["--units", "--cache-dir", "cache", "--explain-rebuild"] @ words (path s "files") @ ["-o", "w.rbc"])
          val taken = List.filter (String.isPrefix "rune: from the cache ") (lines (#errors r))
        in
          ok s ("a build over damaged entries (" ^ what ^ ")") r;
          check s (says ^ ": " ^ String.concatWith "; " taken ^ " (" ^ Int.toString (List.length hit) ^ " damaged)")
                (List.length (compiledBy r) >= List.length hit);
          agrees s ("after damaged entries (" ^ what ^ ")")
        end
      fun whole label =
        let
          val w = rune s [] (["--units", "--cache-dir", "cache", "--whole", "--explain-rebuild"] @ words (path s "files") @ ["-o", "w.rbc"])
          val n = rune s [] (["--units", "--no-cache", "--whole"] @ words (path s "files") @ ["-o", "n.rbc"])
        in
          ok s label w;
          check s (label ^ ": the build differs from one without the store") (same (path s "w.rbc", path s "n.rbc"));
          w
        end
    in
      damaged ("head", "a damaged head was taken");
      damaged ("file", "a damaged section was taken");
      (* a damaged Mid: taken where the units' code is linked, which reads
         none; compiled again for one program of the units' Mid *)
      fresh s;
      agrees s "first";
      let
        val hit = List.filter (fn f => CachePlant.damage f "mid") (cache s)
        val r = rune s [] (["--units", "--cache-dir", "cache", "--explain-rebuild"] @ words (path s "files") @ ["-o", "w.rbc"])
        val () = check s "no entry with a Mid to damage" (not (List.null hit))
        val () = ok s "a build over damaged Mids" r
        val () = check s ("a build of the units' code read a Mid: compiled " ^ String.concatWith " " (compiledBy r))
                       (List.null (compiledBy r))
        val () = agrees s "after damaged Mids"
        val w = whole "--whole over damaged Mids"
      in
        check s ("--whole took a damaged Mid: compiled " ^ String.concatWith " " (compiledBy w))
              (List.length (compiledBy w) >= List.length hit)
      end
    end

  val cases = [prefix ^ "place", prefix ^ "trim", prefix ^ "heads", prefix ^ "damage"]
  fun handles name = String.isPrefix prefix name
  fun one (s : state) =
    let val n = #name s
    in
      if n = prefix ^ "place" then place s
      else if n = prefix ^ "trim" then trims s
      else if n = prefix ^ "heads" then heads s
      else if n = prefix ^ "damage" then damage s
      else raise Failed ("no check " ^ n)
    end
end
