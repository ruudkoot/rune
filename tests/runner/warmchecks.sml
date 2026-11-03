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

   warm-config: the step that writes a Config, as rune.build's first writes
   build/config.sml (docs/build.md, Generated sources): in a git repository
   of its own, each thing the step reads is changed -- a file of its plan's
   closure, a commit, a tracked file outside the closure and its edit undone,
   a file git does not track, a git add, a tag, a checkout, a branch, the
   repository gone -- and the Config must say what the tool run by hand says
   (as a host's make runs it), the build must be the build without the
   cache, and the step must run where something it reads changed and not
   where nothing did, an up-to-date build's included. *)
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

  (* ---- the config step ---- *)

  fun config (s : state) =
    let
      val () = reset s
      (* git as no one's configuration has it, and no repository above the tree *)
      val () = #environment s := [("GIT_CONFIG_GLOBAL", "/dev/null"), ("GIT_CONFIG_NOSYSTEM", "1"),
                                  ("GIT_CEILING_DIRECTORIES", OS.Path.dir (!(#directory s))),
                                  ("GIT_AUTHOR_NAME", "Rune"), ("GIT_AUTHOR_EMAIL", "rune@example.org"),
                                  ("GIT_COMMITTER_NAME", "Rune"), ("GIT_COMMITTER_EMAIL", "rune@example.org")]
      fun trim t = Substring.string (Substring.dropr Char.isSpace (Substring.full t))
      fun run args =
        let val r = command s "" args
        in check s (String.concatWith " " args ^ " failed: " ^ #errors r) (#status r = 0); trim (#output r) end
      fun git args = ignore (run ("git" :: args))
      (* the checkout's tool, and a line of sh before it and before its stamp
         that notes each run *)
      val () = List.app (fn f => copy (fromRoot ("scripts/" ^ f)) (path s ("scripts/" ^ f))) ["gen-version.sh", "plan-files.sh"]
      val () = put s "scripts/config.sh" "echo run >> runs.log\nexec sh scripts/gen-version.sh \"$@\""
      val () = put s "scripts/stamp.sh" "exec sh scripts/gen-version.sh --stamp"
      val () = ignore (run ["chmod", "+x", "scripts/config.sh", "scripts/stamp.sh"])
      val () = put s "toy.build" (String.concatWith "\n"
                 ["generate scripts/config.sh (--config, toy.plan, toy/config.sml)",
                  "  inputs scripts/gen-version.sh scripts/plan-files.sh end",
                  "  closure toy.plan",
                  "  stamp scripts/stamp.sh",
                  "  outputs toy/config.sml end",
                  "toy/config.sml toy/a.sml toy/main.sml"])
      val () = put s "toy/a.sml" "structure A = struct val n = 1 end"
      val () = put s "toy/main.sml" "val () = print (Config.version ^ \" \" ^ Config.identity ^ \" \" ^ Int.toString A.n ^ \"\\n\")"
      val () = put s "README" "the tree of warm-config"
      val () = put s ".gitignore" (String.concatWith "\n" ["logs/", "cache/", "*.rbc", "*.log", "toy/config.sml"])
      val () = write (path s "toy.plan", run [#compiler s, "--plan", "toy.build"] ^ "\n")
      val () = (git ["init", "-q"]; git ["add", "-A"]; git ["commit", "-q", "-m", "one"])
      fun short () = run ["git", "rev-parse", "--short", "HEAD"]
      fun runs () = if exists (path s "runs.log") then List.length (lines (read (path s "runs.log"))) else 0
      fun config () = read (path s "toy/config.sml")
      val vm = OS.Path.dir (#compiler s) ^ "/runevm"
      (* a warm build: the step ran or not, its Config says the version, the
         build is the build without the cache, and the tool run by hand
         makes what the step made; what the program prints *)
      fun warm (label, version, ran) =
        let
          val ran0 = runs ()
          val w = command s "" [#compiler s, "--units", "--cache-dir", "cache", "--build", "toy.build", "-o", "w.rbc"]
          val () = check s (label ^ ": the build failed: " ^ #errors w) (#status w = 0)
          val () = check s (label ^ (if ran then ": the step did not run" else ": the step ran, where nothing it reads changed"))
                         ((runs () > ran0) = ran)
          val made = config ()
          val () = check s (label ^ ": the Config is not of version " ^ version ^ ": " ^ made)
                         (String.isSubstring ("  val version = \"" ^ version ^ "\"\n") made)
          val n = command s "" [#compiler s, "--units", "--no-cache", "--build", "toy.build", "-o", "n.rbc"]
          val () = check s (label ^ ": the build without the cache failed: " ^ #errors n) (#status n = 0)
          val () = check s (label ^ ": the build without the cache made another Config: " ^ config ()) (config () = made)
          val () = check s (label ^ ": the build differs from the build without the cache") (same (path s "w.rbc", path s "n.rbc"))
          val () = ignore (run ["sh", "scripts/gen-version.sh", "--config", "toy.plan", "toy/config.sml"])
          val () = check s (label ^ ": the tool run by hand made another Config: " ^ config ()) (config () = made)
          val printed = run [vm, "w.rbc"]
          val () = check s (label ^ ": the program printed " ^ printed) (String.isPrefix (version ^ " ") printed)
        in printed end
      fun identity printed = List.nth (String.tokens Char.isSpace printed, 1)
      fun n printed = List.nth (String.tokens Char.isSpace printed, 2)
      val v1 = short ()
      val first = warm ("the first build", v1, true)
      val () = sleep 3
      val _ = warm ("nothing changed", v1, false)
      (* a file of the plan's closure, which git tracks *)
      val () = edit s "toy/a.sml" "val n = 1" "val n = 2"
      val edited = warm ("an edit of a file the plan names", v1 ^ "-dirty", true)
      val () = check s "an edit of a file the plan names left the identity as it was" (identity edited <> identity first)
      val () = check s "an edit of a file the plan names is not in the program" (n edited = "2")
      val () = sleep 3
      (* the tree dirty already, so that the stamp answers as it did: an edit
         of a file of the closure, and of an input, each run the step *)
      val () = edit s "toy/a.sml" "val n = 2" "val n = 3"
      val again = warm ("a second edit of a file the plan names, the tree dirty already", v1 ^ "-dirty", true)
      val () = check s "a second edit of a file the plan names left the identity as it was" (identity again <> identity edited)
      (* a build that keeps the edited file's stat racily clean, so that what
         the next sees changed is the input alone *)
      val () = sleep 3
      val _ = warm ("settled after the second edit", v1 ^ "-dirty", false)
      val () = sleep 3
      val () = write (path s "scripts/plan-files.sh", read (path s "scripts/plan-files.sh") ^ "# an edit\n")
      val _ = warm ("an edit of an input, the tree dirty already", v1 ^ "-dirty", true)
      val () = sleep 3
      (* a commit: the step runs, and at once after, though it wrote the
         Config within the second, the build is up to date *)
      val () = git ["commit", "-q", "-a", "-m", "two"]
      val v2 = short ()
      val _ = warm ("a commit", v2, true)
      val _ = warm ("nothing changed, at once after the step wrote", v2, false)
      (* a tracked file outside the closure, and its edit undone *)
      val () = put s "README" "edited"
      val _ = warm ("an edit of a tracked file the plan does not name", v2 ^ "-dirty", true)
      val () = git ["checkout", "-q", "--", "README"]
      val _ = warm ("the edit undone", v2, true)
      (* a file git does not track, and then git add *)
      val () = put s "notes.txt" "untracked"
      val _ = warm ("a file git does not track", v2, false)
      val () = git ["add", "notes.txt"]
      val _ = warm ("git add", v2 ^ "-dirty", true)
      val () = git ["commit", "-q", "-m", "three"]
      val v3 = short ()
      val _ = warm ("a commit of what was added", v3, true)
      (* a release's tag at HEAD *)
      val () = git ["tag", "v9.8.7"]
      val _ = warm ("a tag", "9.8.7", true)
      (* a checkout of the first commit, whose a.sml is the first's *)
      val () = git ["checkout", "-q", v1]
      val back = warm ("a checkout", v1, true)
      val () = check s "a checkout of the first commit did not give its identity" (identity back = identity first)
      val () = check s "a checkout of the first commit is not in the program" (n back = "1")
      val () = sleep 3
      (* a branch at HEAD: the version is HEAD's, and nothing changed *)
      val () = git ["checkout", "-q", "-b", "other"]
      val _ = warm ("a branch at HEAD", v1, false)
      (* the Config edited by hand: refused while nothing the step reads
         changed, and made again once removed *)
      val () = put s "toy/config.sml" "structure Config = struct val version = \"x\" val identity = \"y\" end"
      val r = command s "" [#compiler s, "--units", "--cache-dir", "cache", "--build", "toy.build", "-o", "w.rbc"]
      val () = check s ("a Config edited by hand was not refused: " ^ #errors r)
                     (#status r <> 0 andalso String.isSubstring "is not what the step" (#errors r))
      val () = OS.FileSys.remove (path s "toy/config.sml")
      val _ = warm ("the Config removed", v1, true)
      (* no repository: the version is the one there was, or unknown *)
      val () = rmTree (path s ".git")
      val _ = warm ("the repository gone", "unknown", true)
    in () end

  val cases = List.map (fn p => prefix ^ "unit-" ^ p) projects @ [prefix ^ "racy", prefix ^ "uptodate", prefix ^ "config"]
  fun handles name = String.isPrefix prefix name
  fun one (s : state) =
    let val n = #name s
    in
      if n = prefix ^ "racy" then racy s
      else if n = prefix ^ "uptodate" then upToDate s
      else if n = prefix ^ "config" then config s
      else if String.isPrefix (prefix ^ "unit-") n then unitByUnit s (String.extract (n, size (prefix ^ "unit-"), NONE))
      else raise Failed ("no check " ^ n)
    end
end
