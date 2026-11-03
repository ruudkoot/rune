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
   that makes a unit another library's -- each is seen. *)
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

  val cases = List.map (fn p => prefix ^ "unit-" ^ p) projects @ [prefix ^ "racy", prefix ^ "uptodate"]
  fun handles name = String.isPrefix prefix name
  fun one (s : state) =
    let val n = #name s
    in
      if n = prefix ^ "racy" then racy s
      else if n = prefix ^ "uptodate" then upToDate s
      else if String.isPrefix (prefix ^ "unit-") n then unitByUnit s (String.extract (n, size (prefix ^ "unit-"), NONE))
      else raise Failed ("no check " ^ n)
    end
end
