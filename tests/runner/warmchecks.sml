(* The checks of the warm path (docs/testing.md, The checks of the cache;
   docs/units.md, A warm build; the build-system roadmap's M6 and E15). Each
   is a scenario of bin/rune-incremental.

   warm-unit-*: E15's verification unit by unit. A project is built, and then
   each of its units -- the Basis Library's it takes, and its own -- is
   compiled alone (RUNE_VERIFY_UNIT) while every other is taken from the cache
   without its basis: once under its view, what its text names loaded by need,
   and once under the mask of its entry's usages (RUNE_VERIFY_MASK), each
   structure cut to the paths they name (D20). Each must be what its entry
   holds: a read the view or the mask did not hold is what a lazy load would
   miss, silently, in a build.

   warm-racy: the stat memo's guard (UnitStore.clean) and the memos against
   the edits that could fool them: an edit of the same size within the second
   of a build, edits and builds in one second, touch, the old text put back
   with its old times (cp -p), an edit with its time put back (touch -r), the
   output overwritten, a new name that changes what is selected of the Basis
   Library. Each build is held to one without the cache.

   warm-uptodate: a compile that is up to date (UnitMemo): it compiles
   nothing, links nothing and gives its warnings again; a file touched, the
   output removed or overwritten, an edit, a build file's edit, a library.build
   that makes a unit another library's -- each is seen.

   warm-uptodate-index: an edit of a Basis Library file under an index of the
   frozen layer, and under one of the overlay, makes the next build not up to
   date, the index being held by its record (the build-system roadmap's M12).

   warm-plan: what each file is to the plan (LibraryIndex.programFacts), kept
   by its text and the fixity before it: an edit reads the file edited, and
   an edit of a fixity directive -- changed, put in a local that keeps it or
   drops it, nonfix, added, removed -- the files after it whose fixity before
   them it changed, by the tokens the build lexed (--pass-stats); each build
   held to one without the cache, and to --verify-cache, which reads every
   file and holds what the store kept to it.

   warm-index-roots: two copies of the Basis Library under two roots, built
   through one store, each keep their index's record there, which a build
   from the other root does not displace; and in units, what each file is
   to the plan, which each root keeps apart too (warm-plan-roots). *)
structure WarmChecks =
struct
  open Incremental

  val prefix = "warm-"

  (* the projects verified unit by unit *)
  val projects = ["project", "functors"]

  fun copyProject (s : state) dir =
    let val d = fromRoot dir
    in reset s; List.app (fn f => copy (d ^ "/" ^ f) (path s f)) (words (d ^ "/files") @ ["files"]) end

  (* ---- unit by unit ---- *)

  fun unitByUnit (s : state) project =
    let
      val () = copyProject s ("tests/incremental/" ^ project)
      val () = build s []
      val () = check s ("the project does not build: " ^ #errors (!(#result s))) (#status (!(#result s)) = 0)
      val () = build s []
      val units = List.mapPartial (fn l => if String.isPrefix "rune: from the cache " l
                                           then SOME (String.extract (l, size "rune: from the cache ", NONE)) else NONE)
                                  (lines (#errors (!(#result s))))
      val () = check s "no unit was taken from the cache" (not (List.null units))
      val old = !(#environment s)
      fun verify (unit, mode) =
        let
          val () = #environment s := ("RUNE_VERIFY_UNIT", unit) :: (if mode = "mask" then [("RUNE_VERIFY_MASK", "1")] else []) @ old
          val r = compile s ["--units", "--cache-dir", "cache", "--explain-rebuild"] "v.rbc"
          val () = #environment s := old
        in
          check s (unit ^ " under its " ^ mode ^ " is not what its entry holds: " ^ #errors r)
                (#status r = 0 andalso String.isSubstring ("compiled under its " ^ mode) (#errors r))
        end
    in
      List.app (fn u => (verify (u, "view"); verify (u, "mask"))) units
    end

  (* ---- the racy cases ---- *)

  fun sleep seconds = OS.Process.sleep (Time.fromSeconds seconds)

  fun racy (s : state) =
    let
      val () = own s "a.sml b.sml"
      val () = put s "a.sml" "structure A = struct val x = 1 fun f y = y + x end"
      val () = put s "b.sml" "val () = print (Int.toString (A.f 1) ^ \"\\n\")"
      fun warm label =
        let
          val w = compile s ["--units", "--cache-dir", "cache"] "w.rbc"
          val n = compile s ["--units", "--no-cache"] "n.rbc"
        in
          check s (label ^ ": the build failed: " ^ #errors w) (#status w = 0);
          check s (label ^ ": the build differs from one without the cache") (same (path s "w.rbc", path s "n.rbc"))
        end
      fun set (old, new) = edit s "a.sml" old new
    in
      warm "first";
      sleep 3; warm "nothing changed";
      set ("val x = 1", "val x = 2"); warm "an edit of the same size, right after a build";
      set ("val x = 2", "val x = 3"); warm "another at once";
      set ("val x = 3", "val x = 4"); warm "two edits and builds in one second, the first";
      set ("val x = 4", "val x = 5"); warm "two edits and builds in one second, the second";
      sleep 3; warm "settled";
      write (path s "a.sml", read (path s "a.sml")); warm "written again, the same text";
      sleep 3; warm "settled after that";
      ignore (command s "" ["cp", "-p", path s "a.sml", path s "a.keep"]);
      sleep 3; set ("val x = 5", "val x = 6"); warm "an edit";
      sleep 3; warm "settled";
      ignore (command s "" ["cp", "-p", path s "a.keep", path s "a.sml"]);
      warm "the old text back with its old times (cp -p)";
      sleep 3; warm "settled";
      set ("val x = 5", "val x = 7"); ignore (command s "" ["touch", "-r", path s "a.keep", path s "a.sml"]);
      warm "an edit, its time put back (touch -r)";
      sleep 3; warm "settled";
      write (path s "w.rbc", "garbage"); warm "the output overwritten";
      sleep 3; warm "settled";
      put s "b.sml" "val () = print (Int.toString (A.f 1) ^ \"\\n\")\nval () = print (Real.toString 1.5 ^ \"\\n\")";
      warm "a new name, Real, which the selection takes";
      sleep 3; warm "settled"
    end

  (* ---- up to date ---- *)

  fun upToDate (s : state) =
    let
      val () = own s "a.sml b.sml"
      val () = put s "a.sml" "structure A = struct val x = 1 fun f y = case y of 0 => x end"
      val () = put s "b.sml" "val () = print (Int.toString (A.f 0) ^ \"\\n\")"
      fun warm label =
        let
          val w = compile s ["--units", "--cache-dir", "cache"] "w.rbc"
          val n = compile s ["--units", "--no-cache"] "n.rbc"
        in
          check s (label ^ ": the build failed: " ^ #errors w) (#status w = 0);
          check s (label ^ ": the build differs from one without the cache") (same (path s "w.rbc", path s "n.rbc"));
          check s (label ^ ": the warnings differ from a build without the cache: " ^ #errors w ^ " against " ^ #errors n)
                (#errors w = #errors n)
        end
      fun modified () = OS.FileSys.modTime (path s "w.rbc")
      val () = warm "first"
      val () = sleep 3
      val () = warm "nothing changed, which links nothing"
      val t = modified ()
      val () = warm "nothing changed again"
      val () = check s "an up-to-date build wrote its output" (Time.compare (t, modified ()) = EQUAL)
      val () = check s "an up-to-date build kept no record"
                     (List.exists (fn f => String.isSubstring "/memo/" f) (entriesBelow (path s "cache")))
      val () = ignore (command s "" ["touch", path s "a.sml"])
      val () = warm "a source touched"
      val () = OS.FileSys.remove (path s "w.rbc")
      val () = warm "the output removed"
      val () = check s "the output was not made again" (exists (path s "w.rbc"))
      val () = sleep 3
      val () = write (path s "w.rbc", "garbage")
      val () = warm "the output overwritten"
      val () = edit s "a.sml" "val x = 1" "val x = 2"
      val () = warm "an edit"
      val () = sleep 3
      val () = warm "settled"
      (* a library.build above a unit makes it another library's: its name,
         and so its key, are others *)
      val () = put s "lib/c.sml" "structure C = struct val y = 3 end"
      val () = put s "files" "a.sml lib/c.sml b.sml"
      val () = warm "a unit added"
      val () = sleep 3
      val () = warm "settled"
      val () = put s "lib/library.build" "files c.sml end"
      val () = warm "a library.build above a unit"
    in () end

  (* ---- up to date, through a library's index ---- *)

  (* A compile that is up to date holds each library's index it took by the
     index's record and the hash of what the index rests on, not by a copy
     of its files (LibraryIndex.stillRests): an edit of a file of the Basis
     Library, which leaves its index as it was, makes the next build not up
     to date -- under an index the frozen layer holds, written by a compile
     whose store that layer was, and under one the overlay holds, made by the
     first build and taken by the next. First a file the program does not take, array2.sml, which
     only the index rests on: a build that is not up to date writes its
     record again, as one that is does not (the files of memo/, by their
     inodes). Then one it takes, so that Bool.toString gives another text,
     which a build that took itself to be up to date would not print. Each
     Basis is a copy, written three seconds before its index is made, so
     that the index's record holds its files by their stats *)
  fun upToDateIndex (s : state) =
    let
      val () = own s "p.sml"
      val () = put s "p.sml" "val () = print (Bool.toString true ^ \"\\n\")"
      val () = List.app (fn root => copyTree (fromRoot "lib/basis") (path s (root ^ "/lib/basis"))) ["frozen", "overlay"]
      val vm = OS.Path.dir (#compiler s) ^ "/runevm"
      fun indexes store = entriesBelow (path s (store ^ "/index"))
      fun modified out = OS.FileSys.modTime (path s out)
      (* what a build writes again where it is not up to date: its record *)
      fun memo store =
        List.map (fn f => (f, Posix.FileSys.inoToWord (Posix.FileSys.ST.ino (Posix.FileSys.stat f))))
                 (List.filter (String.isSubstring "/memo/") (entriesBelow (path s store)))
      fun case' (root, store, (whose, taken)) =
        let
          val lib = path s (root ^ "/lib")
          val out = root ^ ".rbc"
          fun warm label printed =
            let
              val w = compile s ["--lib", lib, "--units", "--cache-dir", store] out
              val n = compile s ["--lib", lib, "--units", "--no-cache"] (root ^ "-n.rbc")
              val r = command s "" [vm, out]
            in
              check s (root ^ ", " ^ label ^ ": the build failed: " ^ #errors w) (#status w = 0);
              check s (root ^ ", " ^ label ^ ": the build differs from one without the cache") (same (path s out, path s (root ^ "-n.rbc")));
              check s (root ^ ", " ^ label ^ ": the program printed " ^ String.toString (#output r ^ #errors r))
                    (#output r ^ #errors r = printed ^ "\n")
            end
          fun upToDate label =
            let val t = modified out val m = memo store
            in
              warm label "true";
              check s (root ^ ", " ^ label ^ ": an up-to-date build wrote its output") (Time.compare (t, modified out) = EQUAL);
              check s (root ^ ", " ^ label ^ ": an up-to-date build wrote its record") (m = memo store)
            end
          val unused = root ^ "/lib/basis/array2.sml"
        in
          warm "first" "true";
          check s (root ^ ": the index taken was not " ^ whose) (taken ());
          (* a build that takes the index from the store, where the first
             may have made it and so read its files *)
          ignore (command s "" ["touch", path s "p.sml"]);
          warm "the program touched" "true";
          sleep 3; warm "nothing changed, which links nothing" "true";
          upToDate "nothing changed again";
          let val m = memo store
          in
            write (path s unused, read (path s unused) ^ "(* edited *)\n");
            warm "a Basis file the program does not take edited" "true";
            check s (root ^ ": the build after an edit of a file only the index rests on was up to date") (m <> memo store)
          end;
          sleep 3; warm "settled" "true";
          upToDate "settled, nothing changed";
          edit s (root ^ "/lib/basis/bool.sml") "fun toString true = \"true\"" "fun toString true = \"TRUE\"";
          warm "a Basis file edited, its index the same" "TRUE";
          sleep 3; warm "settled" "TRUE"
        end
      val () = sleep 3
      (* the frozen layer's record, written by a compile whose store it is *)
      val made = compile s ["--lib", path s "frozen/lib", "--cache-dir", path s "frozen/lib/cache"] "made.rbc"
      val () = check s ("the frozen layer's index was not made: " ^ #errors made)
                     (#status made = 0 andalso not (List.null (indexes "frozen/lib/cache")))
      val () = sleep 3
    in
      case' ("frozen", "fcache", ("the frozen layer's", fn () => List.null (indexes "fcache")));
      case' ("overlay", "ocache", ("the overlay's", fn () => not (List.null (indexes "ocache"))))
    end

  (* ---- what each file is to the plan ---- *)

  fun plan (s : state) =
    let
      val files = ["ops.sml", "use.sml", "mid.sml", "last.sml"]
      val () = own s (String.concatWith " " files)
      val () = put s "ops.sml" "fun ++ (a, b) = a * 10 + b\ninfix 6 ++"
      val () = put s "use.sml" "structure U = struct val v = 1 ++ 2 ++ 3 end"
      val () = put s "mid.sml" "structure M = struct val w = U.v + 1 end"
      val () = put s "last.sml" "val () = print (Int.toString (U.v ++ M.w) ^ \"\\n\")"
      fun tokens file = List.length (lines (#output (command s "" [#compiler s, "--dump-tokens", file])))
      (* the tokens a build in units lexed for its plan *)
      fun lexed errors =
        case List.mapPartial (fn l => if String.isPrefix "pass lex: " l
                                      then Int.fromString (String.extract (l, size "pass lex: ", NONE)) else NONE)
                             (lines errors) of
          [n] => n
        | _ => ~1
      fun warm label (read, ok) =
        let
          val wanted = List.foldl (fn (f, n) => n + tokens f) 0 read
          val w = compile s ["--units", "--cache-dir", "cache", "--pass-stats"] "w.rbc"
          val n = compile s ["--units", "--no-cache"] "n.rbc"
          val v = compile s ["--units", "--cache-dir", "cache", "--verify-cache"] "v.rbc"
        in
          check s (label ^ ": the build " ^ (if ok then "failed: " else "did not fail: ") ^ #errors w)
                ((#status w = 0) = ok andalso (#status n = 0) = ok);
          check s (label ^ ": the build differs from one without the cache") (not ok orelse same (path s "w.rbc", path s "n.rbc"));
          check s (label ^ ": the plan read " ^ Int.toString (lexed (#errors w)) ^ " tokens, wanted " ^ Int.toString wanted
                   ^ ", those of " ^ String.concatWith " " read)
                (lexed (#errors w) = wanted);
          check s (label ^ ": --verify-cache found what the store keeps is not what reading gives: " ^ #errors v)
                (not ok orelse #status v = 0)
        end
      fun set file (old, new) = edit s file old new
    in
      warm "first" (files, true);
      set "mid.sml" ("+ 1 end", "+ 1 end (* edited *)"); warm "a comment in mid.sml" (["mid.sml"], true);
      set "ops.sml" ("infix 6", "infixr 6"); warm "infix made infixr in the first file" (files, true);
      set "ops.sml" ("infixr 6 ++", "local in infixr 6 ++ end"); warm "the directive in a local that keeps it" (["ops.sml"], true);
      set "ops.sml" ("local in infixr 6 ++ end", "local infixr 6 ++ in end");
      warm "the directive in a local that drops it" (files, false);
      set "ops.sml" ("local infixr 6 ++ in end", "infix 6 ++"); warm "the directive back" (files, true);
      set "last.sml" ("^ \"\\n\")", "^ \"\\n\")\nnonfix ++"); warm "nonfix in the last file" (["last.sml"], true);
      set "mid.sml" ("(* edited *)", "infix 3 ++"); warm "a directive added in mid.sml" (["mid.sml", "last.sml"], true);
      set "ops.sml" ("\ninfix 6 ++", ""); warm "the first file's directive removed" (files, false)
    end

  (* ---- two roots, one store ---- *)

  (* Two copies of the Basis Library, under the roots a/lib and b/lib, built
     in turn through one store: the index of each has a record of its own
     there (LibraryIndex.namesOf), where one record of the library's place
     would hold the stats of the last copy built, and a build from the other
     root read every file of its copy again to hold it, and write the record
     again. Each copy is three seconds older than its index's record, so
     that the record holds its files by their stats; a record that holds is
     not written again (the files of index/, by their inodes). *)
  fun indexRoots (s : state) =
    let
      val () = own s "p.sml"
      val () = put s "p.sml" "val () = print (Bool.toString true ^ \"\\n\")"
      val () = List.app (fn root => copyTree (fromRoot "lib/basis") (path s (root ^ "/lib/basis"))) ["a", "b"]
      fun records () =
        List.map (fn f => (f, Posix.FileSys.inoToWord (Posix.FileSys.ST.ino (Posix.FileSys.stat f))))
                 (entriesBelow (path s "cache/index"))
      fun build root =
        let val r = compile s ["--lib", path s (root ^ "/lib"), "--cache-dir", "cache"] (root ^ ".rbc")
        in check s (root ^ ": the build failed: " ^ #errors r) (#status r = 0) end
      val () = sleep 3
      val () = (build "a"; build "b")
      val made = records ()
      val () = check s ("the store holds " ^ Int.toString (List.length made) ^ " files of index records, not a record and"
                        ^ " its facts for each root") (List.length made = 4)
      val () = sleep 3
      val () = (build "a"; build "b"; build "a")
    in
      check s "a build from one root wrote again the record of its index, which the other's had displaced"
            (records () = made)
    end

  (* ---- two roots, one store, in units: the plan ---- *)

  (* The same, built in units: what each file is to the plan is kept by the
     program's place and its root of libraries (LibraryIndex.programFacts),
     so that each root's plan has a file of its own in plan/, which a build
     from the other root does not write again *)
  fun planRoots (s : state) =
    let
      val () = own s "p.sml"
      val () = put s "p.sml" "val () = print (Bool.toString true ^ \"\\n\")"
      val () = List.app (fn root => copyTree (fromRoot "lib/basis") (path s (root ^ "/lib/basis"))) ["a", "b"]
      fun plans () =
        List.map (fn f => (f, Posix.FileSys.inoToWord (Posix.FileSys.ST.ino (Posix.FileSys.stat f))))
                 (entriesBelow (path s "cache/plan"))
      fun build root =
        let val r = compile s ["--lib", path s (root ^ "/lib"), "--units", "--cache-dir", "cache"] (root ^ ".rbc")
        in check s (root ^ ": the build failed: " ^ #errors r) (#status r = 0) end
      val () = sleep 3
      val () = (build "a"; build "b")
      val made = plans ()
      val () = check s ("the store holds " ^ Int.toString (List.length made) ^ " plans, not one for each root")
                     (List.length made = 2)
      val () = sleep 3
      val () = (build "a"; build "b"; build "a")
    in
      check s "a build from one root wrote its plan again, which the other's had displaced" (plans () = made)
    end

  val cases = List.map (fn p => prefix ^ "unit-" ^ p) projects
              @ [prefix ^ "racy", prefix ^ "uptodate", prefix ^ "uptodate-index", prefix ^ "plan", prefix ^ "index-roots",
                 prefix ^ "plan-roots"]
  fun handles name = String.isPrefix prefix name
  fun one (s : state) =
    let val n = #name s
    in
      if n = prefix ^ "racy" then racy s
      else if n = prefix ^ "uptodate" then upToDate s
      else if n = prefix ^ "uptodate-index" then upToDateIndex s
      else if n = prefix ^ "plan" then plan s
      else if n = prefix ^ "index-roots" then indexRoots s
      else if n = prefix ^ "plan-roots" then planRoots s
      else if String.isPrefix (prefix ^ "unit-") n then unitByUnit s (String.extract (n, size (prefix ^ "unit-"), NONE))
      else raise Failed ("no check " ^ n)
    end
end
