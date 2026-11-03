(* The library model (docs/build.md, A library's header; the build-system
   roadmap's M8): headers, what each scope sees, fixity across a boundary,
   views, friends, clashes, a library with no header, and the holes E3 found,
   each compiled whole, in units and as a whole of units. *)
structure LibraryModel =
struct
  open Sh
  val dir = run ^ "/library-model"
  val lib = dir ^ "/lib"
  fun need (ok, message) = if ok then () else raise Fail ("library model: " ^ message)
  fun has text log = String.isSubstring text log
  val count = ref 0
  fun runeEnv envf args =
    let
      val () = count := !count + 1
      val log = dir ^ "/log-" ^ Int.toString (!count)
      val status = execEnv envf {cmd = fromRoot (env ("RUNE", "bin/rune")) :: args, dir = SOME dir, stdin = "",
                                 stdout = log, stderr = log, timeout = 300}
    in (status, read log) end
  val runeWith = runeEnv (fn e => e)
  fun rune args = runeWith (["--lib", lib] @ args)
  fun runProgram rbc =
    let
      val log = rbc ^ ".out"
      val status = exec {cmd = [fromRoot (env ("RUNEVM", "bin/runevm")), rbc], dir = SOME dir, stdin = "",
                         stdout = log, stderr = log, timeout = 60}
    in (status, read log) end
  fun put (path, text) =
    (mkdirs (OS.Path.dir (dir ^ "/" ^ path)); write (dir ^ "/" ^ path, text))
  fun index name =
    let val (status, log) = rune ["--basis-index", "lib/" ^ name]
    in need (status = 0, "cannot index " ^ name ^ ": " ^ log); log end
  fun indexRefused name reason =
    let val (status, log) = rune ["--basis-index", "lib/" ^ name]
    in need (status <> 0 andalso has reason log, "the index of " ^ name ^ " did not say " ^ reason ^ ": " ^ log) end
  val modes = [("whole", ["--no-cache"]), ("units", ["--units", "--no-cache"]), ("units-whole", ["--units", "--whole", "--no-cache"])]
  val libraries = List.concat o List.map (fn l => ["--library", l])
  (* a program of the given libraries prints expected, each way *)
  fun prints label libs source expected =
    let
      val () = put ("p/" ^ label ^ ".sml", source)
      fun mode (name, flags) =
        let
          val rbc = dir ^ "/" ^ label ^ "-" ^ name ^ ".rbc"
          val (status, log) = rune (flags @ libraries libs @ ["p/" ^ label ^ ".sml", "-o", rbc])
          val () = need (status = 0, label ^ " does not compile " ^ name ^ ": " ^ log)
          val (status, output) = runProgram rbc
        in need (status = 0 andalso output = expected, label ^ " " ^ name ^ " prints " ^ output) end
    in List.app mode modes end
  (* and this one is refused, saying reason *)
  fun refused label libs source reason =
    let
      val () = put ("p/" ^ label ^ ".sml", source)
      fun mode (name, flags) =
        let val (status, log) = rune (flags @ libraries libs @ ["p/" ^ label ^ ".sml", "-o", dir ^ "/refused.rbc"])
        in need (status <> 0 andalso has reason log, label ^ " " ^ name ^ " was not refused for " ^ reason ^ ": " ^ log) end
    in List.app mode modes end

  fun tree () =
    (rmTree dir; mkdirs lib;
     Posix.FileSys.symlink {old = fromRoot "lib/basis", new = lib ^ "/basis"};
     Posix.FileSys.symlink {old = fromRoot "lib/cache", new = lib ^ "/cache"};
     (* a library with a header: its fixity, in an always file, one private *)
     put ("lib/lower/library.build",
          "(* its header comes first *)\n\
          \exports (structure Lower, signature LOWER, fixity +++)\n\
          \view small (structure Lower)\n\
          \friends ../../p/friend.build ../../p/sealed.build end\n\
          \annotate \"always\" in ops.sml end\n\
          \annotate \"demand\" in\n  lower_sig.sml\n  private.sml\n  lower.sml\nend\n");
     put ("lib/lower/ops.sml", "infix 6 +++\ninfix 7 ***\n");
     put ("lib/lower/lower_sig.sml",
          "signature LOWER = sig type t val make : int -> t val show : t -> int\n\
          \  val +++ : int * int -> int val *** : int * int -> int end\n");
     put ("lib/lower/private.sml", "structure LowerPrivate = struct val n = 40 end\n");
     put ("lib/lower/lower.sml",
          "structure Lower :> LOWER = struct type t = int fun make n = n + LowerPrivate.n fun show x = x\n\
          \  fun a +++ b = a + b fun a *** b = a * b end\n");
     (* one that requires it, and sees its fixity *)
     put ("lib/upper/library.build", "requires lower end\nexports (structure Upper)\nannotate \"demand\" in upper.sml end\n");
     put ("lib/upper/upper.sml", "structure Upper = struct local open Lower in val value = show (make 1) +++ 2 * 3 end end\n");
     (* with no header, written on another with none *)
     put ("lib/deep/library.build", "annotate \"demand\" in deep.sml end\n");
     put ("lib/deep/deep.sml", "structure Deep = struct val v = 7 end\n");
     put ("lib/plain/library.build", "libraries deep end\nannotate \"demand\" in plain.sml end\n");
     put ("lib/plain/plain.sml", "structure Plain = struct val v = Deep.v + 1 end\n");
     (* a header over one with none: transitive through that one *)
     put ("lib/mixed/library.build", "requires plain end\nexports (structure Mixed)\nannotate \"demand\" in mixed.sml end\n");
     put ("lib/mixed/mixed.sml", "structure Mixed = struct val v = Plain.v + Deep.v end\n");
     (* with no header, seeing what comes before it, as it always has *)
     put ("lib/loose/library.build", "annotate \"demand\" in loose.sml end\n");
     put ("lib/loose/loose.sml", "structure Loose = struct val v = Deep.v * 2 end\n");
     (* the same with a header, which requires nothing *)
     put ("lib/isolated/library.build", "exports (structure Isolated)\nannotate \"demand\" in isolated.sml end\n");
     put ("lib/isolated/isolated.sml", "structure Isolated = struct val v = Deep.v * 2 end\n");
     (* private names of one name, in two libraries *)
     put ("lib/twin1/library.build", "exports (structure Twin1)\nannotate \"demand\" in twin.sml end\n");
     put ("lib/twin1/twin.sml", "structure Shared = struct val v = \"one\" end\nstructure Twin1 = struct val v = Shared.v end\n");
     put ("lib/twin2/library.build", "exports (structure Twin2)\nannotate \"demand\" in twin.sml end\n");
     put ("lib/twin2/twin.sml", "structure Shared = struct val v = \"two\" end\nstructure Twin2 = struct val v = Shared.v end\n");
     (* a name two libraries export, one the Basis Library has, and one two
        libraries with no header share *)
     put ("lib/same1/library.build", "exports (structure Same)\nannotate \"demand\" in same.sml end\n");
     put ("lib/same1/same.sml", "structure Same = struct val v = 1 end\n");
     put ("lib/same2/library.build", "exports (structure Same)\nannotate \"demand\" in same.sml end\n");
     put ("lib/same2/same.sml", "structure Same = struct val v = 2 end\n");
     put ("lib/mathy/library.build", "exports (structure Math)\nannotate \"demand\" in math.sml end\n");
     put ("lib/mathy/math.sml", "structure Math = struct val pi = 3 end\n");
     put ("lib/both1/library.build", "annotate \"demand\" in both.sml end\n");
     put ("lib/both1/both.sml", "structure Both = struct val v = 1 end\n");
     put ("lib/both2/library.build", "annotate \"demand\" in both.sml end\n");
     put ("lib/both2/both.sml", "structure Both = struct val v = 2 end\n");
     (* a private type through an exported signature *)
     put ("lib/h1/library.build", "exports (structure Api, signature API)\nannotate \"demand\" in hidden.sml api_sig.sml api.sml end\n");
     put ("lib/h1/hidden.sml", "structure Hidden = struct datatype d = D of int fun mk n = D n fun get (D n) = n end\n");
     put ("lib/h1/api_sig.sml", "signature API = sig val mk : int -> Hidden.d val get : Hidden.d -> int end\n");
     put ("lib/h1/api.sml", "structure Api : API = struct val mk = Hidden.mk val get = Hidden.get end\n");
     (* constructors behind a boundary *)
     put ("lib/h2/library.build",
          "exports (structure Api, structure Op, structure Alias, type t)\nannotate \"demand\" in impl.sml api.sml end\n");
     put ("lib/h2/impl.sml",
          "structure Impl = struct datatype t = A | B of int fun show A = \"A\" | show (B n) = \"B\" ^ Int.toString n end\n\
          \type t = Impl.t\n");
     put ("lib/h2/api.sml",
          "structure Api : sig type t val a : t val show : t -> string end = struct open Impl val a = A end\n\
          \structure Op :> sig type t val a : t val show : t -> string end = struct open Impl val a = A end\n\
          \structure Alias = struct type t = Impl.t val a = Impl.A val show = Impl.show end\n");
     List.app (fn n => ignore (index n))
              ["lower", "upper", "deep", "plain", "mixed", "loose", "isolated", "twin1", "twin2", "same1", "same2", "mathy",
               "both1", "both2", "h1", "h2"])

  (* the header in the manifest: no sixth column *)
  fun manifests () =
    let
      val text = read (lib ^ "/lower/MANIFEST")
    in
      need (has "# exports: structure:Lower signature:LOWER fixity:+++\n" text, "no exports in the header: " ^ text);
      need (has "# friends: ../../p/friend.build ../../p/sealed.build\n" text, "no friends in the header");
      need (has "# view: small structure:Lower\n" text, "no view in the header");
      need (has "# fixity: infix 6 +++\n" text andalso not (has "***" text), "the exported fixity alone: " ^ text);
      need (not (has "| structure:Lower" text), "a sixth column beside a header");
      need (has "# library: lower\n" (read (lib ^ "/upper/MANIFEST")), "requires is not what readers read");
      let val (status, log) = rune (libraries ["upper", "mixed"] @ ["--basis-check"])
      in need (status = 0, "--basis-check: " ^ log) end
    end

  (* D7: declared, not transitive; a library alone with its imports *)
  fun requires () =
    (prints "upper" ["upper"] "val () = print (Int.toString Upper.value ^ \"\\n\")\n" "47\n";
     refused "transitive" ["upper"] "val () = print (Int.toString (Lower.show (Lower.make 1)) ^ \"\\n\")\n" "Lower";
     (* undeclared, by its index, where another library has the name *)
     put ("lib/undeclared/library.build", "requires upper end\nexports (structure Undeclared)\nannotate \"demand\" in undeclared.sml end\n");
     put ("lib/undeclared/undeclared.sml", "structure Undeclared = struct val v = Lower.show (Lower.make 1) end\n");
     indexRefused "undeclared" "undeclared.sml uses Lower, of the library lib/lower, which its header does not require";
     (* and by its compile, whatever the index said *)
     put ("lib/undeclared/MANIFEST", "# library: upper\n# exports: structure:Undeclared\nundeclared.sml | demand | yes | Undeclared | \n");
     refused "undeclared" ["undeclared"] "val () = print (Int.toString Undeclared.v ^ \"\\n\")\n" "Lower";
     (* a library's name that nothing it requires leads to, in a program that
        has that library: the header sees nothing of it *)
     refused "isolated" ["deep", "isolated"] "val () = print (Int.toString Isolated.v ^ \"\\n\")\n" "Deep";
     (* a program's names of a library: all of these at once *)
     prints "mixed" ["mixed"] "val () = print (Int.toString Mixed.v ^ \"\\n\")\n" "15\n";
     prints "private-names" ["twin1", "twin2"] "val () = print (Twin1.v ^ Twin2.v ^ \"\\n\")\n" "onetwo\n")

  (* D15: no header, today's meaning *)
  fun noHeader () =
    (prints "transitive-plain" ["plain"] "val () = print (Int.toString (Plain.v + Deep.v) ^ \"\\n\")\n" "15\n";
     prints "before-it" ["deep", "loose"] "val () = print (Int.toString Loose.v ^ \"\\n\")\n" "14\n";
     (* beside a library with a header *)
     prints "beside" ["plain", "upper"] "val () = print (Int.toString (Plain.v + Deep.v + Upper.value) ^ \"\\n\")\n" "62\n";
     refused "beside-hidden" ["plain", "upper"] "val () = print (Int.toString (Lower.show (Lower.make 1)) ^ \"\\n\")\n" "Lower";
     (* its warning: at the index, once a library, and never at a compile *)
     let
       val log = index "deep"
       val (status, quiet) = rune ["--no-warnings", "--basis-index", "lib/deep"]
       val () = need (status = 0 andalso quiet = "", "--no-warnings: " ^ quiet)
       val () = need (has "lib/deep/library.build: warning: this library has no header" log, "no warning of no header: " ^ log)
       val () = need (not (has "no header" (index "lower")), "a warning of no header on a header")
       val (status, log) = rune (libraries ["plain"] @ ["--no-cache", "p/transitive-plain.sml", "-o", dir ^ "/quiet.rbc"])
     in need (status = 0 andalso log = "", "a client's compile warned: " ^ log) end)

  (* a boundary in the header, and fixity across it *)
  fun boundary () =
    (refused "private" ["lower"] "val v = LowerPrivate.n\n" "LowerPrivate";
     prints "fixity" ["lower"] "open Lower\nval () = print (Int.toString (1 +++ 2 * 3) ^ \"\\n\")\n" "7\n";
     (* a private fixity stays inside *)
     refused "private-fixity" ["lower"] "open Lower\nval () = print (Int.toString (2 *** 3) ^ \"\\n\")\n" "";
     (* and an exported one goes as far as the import *)
     refused "transitive-fixity" ["upper"]
             "fun a +++ b = a + b\nval () = print (Int.toString (1 +++ 2 * 3) ^ \"\\n\")\n" "";
     prints "own-fixity" ["upper"] "infix 1 +++\nfun a +++ b = a + b\nval () = print (Int.toString (1 +++ 2 * 3) ^ \"\\n\")\n" "7\n";
     put ("p/build.sml", "val () = print (Int.toString (Lower.show (Lower.make 2) +++ 1) ^ \"\\n\")\n");
     put ("p/built.build", "libraries lower end\nbuild.sml\n");
     let
       val (status, log) = rune ["--no-cache", "--typecheck-only", "--build", "p/built.build"]
       val () = need (status <> 0 andalso has "+++" log, "+++ is not Lower's unless opened: " ^ log)
       val () = put ("p/build.sml", "open Lower\nval () = print (Int.toString (show (make 2) +++ 1) ^ \"\\n\")\n")
       val (status, log) = rune ["--no-cache", "--typecheck-only", "--build", "p/built.build"]
     in need (status = 0, "--typecheck-only lost a header's exports: " ^ log) end)

  (* D8, named subsets *)
  fun views () =
    (prints "view" ["lower#small"] "val () = print (Int.toString (Lower.show (Lower.make 2)) ^ \"\\n\")\n" "42\n";
     refused "outside-view" ["lower#small"] "functor F (X : LOWER) = struct end\n" "unbound signature: LOWER";
     refused "no-such-view" ["lower#none"] "val x = 1\n" "the library lower has no view none";
     refused "view-no-header" ["deep#some"] "val x = 1\n" "a view needs a header";
     put ("lib/viewer/library.build", "requires lower#small end\nexports (structure Viewer)\nannotate \"demand\" in viewer.sml end\n");
     put ("lib/viewer/viewer.sml", "structure Viewer = struct val v = Lower.show (Lower.make 3) end\n");
     ignore (index "viewer");
     prints "through-view" ["viewer"] "val () = print (Int.toString Viewer.v ^ \"\\n\")\n" "43\n";
     put ("lib/viewer/viewer.sml", "structure Viewer : LOWER = Lower\n");
     indexRefused "viewer" "uses LOWER, of the library lib/lower";
     put ("lib/badview/library.build", "exports (structure B)\nview v (structure C)\nannotate \"demand\" in b.sml end\n");
     put ("lib/badview/b.sml", "structure B = struct end\nstructure C = struct end\n");
     indexRefused "badview" "the view v has structure C, which the library does not export")

  (* D11: a friend names, and does not see through an ascription *)
  fun friends () =
    let
      fun build label file =
        (put ("p/" ^ label ^ ".build", "libraries lower end\n" ^ file ^ "\n");
         rune ["--units", "--cache-dir", dir ^ "/friend-cache", "--build", "p/" ^ label ^ ".build", "-o", dir ^ "/" ^ label ^ ".rbc"])
      val () = put ("p/uses-private.sml", "val () = print (Int.toString (LowerPrivate.n + 1) ^ \"\\n\")\n")
      val (status, log) = build "friend" "uses-private.sml"
      val () = need (status = 0, "a friend is refused: " ^ log)
      val (status, output) = runProgram (dir ^ "/friend.rbc")
      val () = need (status = 0 andalso output = "41\n", "the friend prints " ^ output)
      (* the same file, in the same cache, in a build that is no friend *)
      val (status, log) = build "stranger" "uses-private.sml"
      val () = need (status <> 0 andalso has "LowerPrivate" log, "a stranger saw a private name: " ^ log)
      fun whole label =
        let val (status, log) = rune ["--no-cache", "--build", "p/" ^ label ^ ".build", "-o", dir ^ "/" ^ label ^ ".rbc"]
        in (status, log) end
      val (status, log) = whole "friend"
      val () = need (status = 0, "a friend is refused whole: " ^ log)
      val (status, log) = whole "stranger"
      val () = need (status <> 0, "a stranger saw a private name whole: " ^ log)
      val () = put ("p/sees-through.sml", "val x : Lower.t = 3\n")
      val (status, log) = build "sealed" "sees-through.sml"
    in need (status <> 0, "a friend saw through an ascription: " ^ log) end

  (* D9: two imports of one name in one scope are an error, which a rename at
     import answers; a library takes a name of the Basis Library only where
     its header says it shadows it *)
  fun clashes () =
    let
      val source = "val () = print (Int.toString Same.v ^ \"\\n\")\n"
      val () = refused "clash" ["same1", "same2"] source "error: this scope has Same from both the library lib/same1 and the library lib/same2"
      val (status, log) = rune (libraries ["same1", "same2"] @ ["--no-warnings", "--no-cache", "p/clash.sml", "-o", dir ^ "/clash.rbc"])
      val () = need (status <> 0 andalso has "this scope has Same" log, "--no-warnings silenced a clash: " ^ log)
      (* a rename at import answers it, on the command line as in a build *)
      val () = prints "renamed" ["same1", "same2 (structure Same as Two)"]
                      "val () = print (Int.toString Same.v ^ Int.toString Two.v ^ \"\\n\")\n" "12\n"
      val () = put ("p/renamed.build", "libraries same1 (structure Same as One) same2 (structure Same as Two) end\nrenamed-build.sml\n")
      val () = put ("p/renamed-build.sml", "val () = print (Int.toString One.v ^ Int.toString Two.v ^ \"\\n\")\n")
      val (status, log) = rune ["--no-cache", "--build", "p/renamed.build", "-o", dir ^ "/renamed-build.rbc"]
      val () = need (status = 0, "renamed in a build: " ^ log)
      val (status, output) = runProgram (dir ^ "/renamed-build.rbc")
      val () = need (status = 0 andalso output = "12\n", "renamed in a build prints " ^ output)
      (* a name renamed away is gone *)
      val () = refused "renamed-away" ["same1 (structure Same as One)"] source "Same"
      (* with the Basis Library *)
      val () = refused "basis-clash" ["mathy"] "val () = print (Int.toString Math.pi ^ \"\\n\")\n"
                       "this scope has Math from both the Basis Library and the library lib/mathy"
      val () = prints "basis-renamed" ["mathy (structure Math as Mathy)"]
                      "val () = print (Int.toString Mathy.pi ^ \" \" ^ Int.toString (Real.round (Math.sqrt 4.0)) ^ \"\\n\")\n" "3 2\n"
      (* a rename onto a name of the Basis Library is a clash too *)
      val () = refused "renamed-onto-basis" ["same1 (structure Same as List)"] source
                       "this scope has List from both the Basis Library and the library lib/same1"
      (* or where its header says it shadows the Basis Library's *)
      val () = put ("lib/shadowing/library.build", "exports (structure Math)\nshadows (structure Math)\nannotate \"demand\" in math.sml end\n")
      val () = put ("lib/shadowing/math.sml", "structure Math = struct val pi = 3 end\n")
      val () = ignore (index "shadowing")
      val () = need (has "# shadows: structure:Math\n" (read (lib ^ "/shadowing/MANIFEST")), "no shadows in the manifest")
      val () = prints "shadowed" ["shadowing"] "val () = print (Int.toString Math.pi ^ \"\\n\")\n" "3\n"
      val () = prints "shadowed-renamed" ["shadowing (structure Math as Mine)"]
                      "val () = print (Int.toString Mine.pi ^ \" \" ^ Int.toString (Real.round (Math.sqrt 4.0)) ^ \"\\n\")\n" "3 2\n"
      (* where the library requires both: at its index, and a rename there *)
      val () = put ("lib/both/library.build", "requires same1 same2 end\nexports (structure Uses)\nannotate \"demand\" in uses.sml end\n")
      val () = put ("lib/both/uses.sml", "structure Uses = struct val v = Same.v end\n")
      val () = indexRefused "both" "this scope has Same from both"
      val () = put ("lib/both/library.build",
                    "requires same1 (structure Same as One) same2 end\nexports (structure Uses)\nannotate \"demand\" in uses.sml end\n")
      val () = put ("lib/both/uses.sml", "structure Uses = struct val v = One.v * 10 + Same.v end\n")
      val () = ignore (index "both")
      val () = need (has "# library: same1(structure:Same=One)\n# library: same2\n" (read (lib ^ "/both/MANIFEST")),
                     "the renames are not in the manifest: " ^ read (lib ^ "/both/MANIFEST"))
      val () = prints "scoped-clash" ["both"] "val () = print (Int.toString Uses.v ^ \"\\n\")\n" "12\n"
      val (status, log) = rune (libraries ["both"] @ ["--no-cache", "p/scoped-clash.sml", "-o", dir ^ "/clash.rbc"])
      val () = need (status = 0 andalso log = "", "a client was told of its library's imports: " ^ log)
      (* two with no header, as they always have, unless a rename says *)
      val () = prints "no-header-clash" ["both1", "both2"] "val () = print (Int.toString Both.v ^ \"\\n\")\n" "2\n"
      val (status, log) = rune (libraries ["both1", "both2"] @ ["--no-cache", "p/no-header-clash.sml", "-o", dir ^ "/clash.rbc"])
      val () = need (status = 0 andalso log = "", "two libraries with no header: " ^ log)
      val () = prints "no-header-renamed" ["both1", "both2 (structure Both as Second)"]
                      "val () = print (Int.toString Both.v ^ Int.toString Second.v ^ \"\\n\")\n" "12\n"
      val () = refused "no-header-onto" ["both1", "both2 (structure Both as Deep)", "deep"]
                       "val () = print (Int.toString Deep.v ^ \"\\n\")\n" "this scope has Deep from both"
    in () end

  (* what a header may not be *)
  fun malformed () =
    let
      fun bad (name, text, reason) =
        (put ("lib/bad/library.build", text);
         put ("lib/bad/a.sml", "structure A = struct end\n");
         indexRefused "bad" reason;
         ignore name)
      val () = put ("lib/bad/t.sml", "datatype t = A\n")
      val () = List.app bad
        [("no exports", "requires deep end\nannotate \"demand\" in a.sml end\n", "a library's header says what it exports"),
         ("after a file", "annotate \"demand\" in a.sml end\nrequires deep end\n", "unexpected requires"),
         ("libraries", "exports (structure A)\nlibraries deep end\nannotate \"demand\" in a.sml end\n", "says what it is written on with requires"),
         ("twice", "exports (structure A)\nexports (structure A)\nannotate \"demand\" in a.sml end\n", "a header says exports once"),
         ("requires twice", "requires deep end\nrequires deep end\nexports (structure A)\nannotate \"demand\" in a.sml end\n", "a header says requires once"),
         ("two views", "exports (structure A)\nview v (structure A)\nview v (structure A)\nannotate \"demand\" in a.sml end\n", "a header has two views v"),
         ("no source", "exports (structure Missing)\nannotate \"demand\" in a.sml end\n", "exports structure Missing, which no source declares"),
         ("no directive", "exports (structure A, fixity ++)\nannotate \"demand\" in a.sml end\n", "exports fixity ++, which no source declares"),
         ("kind", "exports (value A)\nannotate \"demand\" in a.sml end\n", "an export is structure, signature, functor, type or fixity NAME"),
         ("friend", "exports (structure A)\nfriends /etc/x.build end\nannotate \"demand\" in a.sml end\n", "a friend is a path from the library"),
         ("block", "exports (structure A)\nlibrary (structure A) = annotate \"demand\" in a.sml end end\n", "a library has one outer export boundary"),
         ("datatype", "exports (type t)\nannotate \"demand\" in t.sml end\n", "exports type t, which no source declares")]
      val () = put ("lib/bad/sub.build", "exports (structure A)\nannotate \"demand\" in a.sml end\n")
      val () = put ("lib/bad/library.build", "use sub.build\n")
      val () = indexRefused "bad" "a header belongs to a library's library.build"
      val () = put ("p/header.build", "exports (structure A)\nheader.sml\n")
      val () = put ("p/header.sml", "structure A = struct end\n")
      val (status, log) = rune ["--no-cache", "--build", "p/header.build", "-o", dir ^ "/header.rbc"]
    in need (status <> 0 andalso has "a header belongs to a library's library.build" log, "a header in a program: " ^ log) end

  (* E3's holes, through a header *)
  fun holes () =
    (prints "h1-unnamed" ["h1"] "val x = Api.mk 1\nval () = print (Int.toString (Api.get x) ^ \"\\n\")\n" "1\n";
     prints "h1-ascribe" ["h1"]
            "structure M : API = struct val mk = Api.mk val get = Api.get end\nval () = print (Int.toString (M.get (M.mk 2)) ^ \"\\n\")\n" "2\n";
     prints "h1-equality" ["h1"] "val () = print (Bool.toString (Api.mk 1 = Api.mk 1) ^ \"\\n\")\n" "true\n";
     refused "h1-named" ["h1"] "val y : Hidden.d = Api.mk 1\n" "Hidden";
     refused "h1-own" ["h1"] "structure Hidden = struct datatype d = D end\nval y : Hidden.d = Api.mk 1\n" "";
     refused "h2-transparent" ["h2"] "datatype u = datatype Api.t\nval x = A\n" "A";
     refused "h2-opaque" ["h2"] "datatype u = datatype Op.t\nval x = A\n" "A";
     refused "h2-abbreviation" ["h2"] "datatype u = datatype t\nval x = A\n" "A";
     refused "h2-alias" ["h2"] "datatype u = datatype Alias.t\nval x = B 7\n" "B";
     prints "h2-no-constructor" ["h2"] "datatype u = datatype Api.t\nval () = print (Api.show Api.a ^ \"\\n\")\n" "A\n";
     (* a first `use` of a library's sub-build is a reach into it, which warns;
        M1's second use stays through its boundary (reach-in, boundary/ of
        tests/runner/scenarios.sml) *)
     put ("lib/subbed/library.build", "exports (structure Pub)\nannotate \"demand\" in use x.build end\n");
     put ("lib/subbed/x.build", "x.sml\n");
     put ("lib/subbed/x.sml", "structure Pub = struct val v = 1 end\nstructure Priv = struct val v = 2 end\n");
     ignore (index "subbed");
     put ("p/first.build", "use ../lib/subbed/x.build\nfirst.sml\n");
     put ("p/first.sml", "val () = print (Int.toString Priv.v ^ \"\\n\")\n");
     let val (status, log) = rune ["--no-cache", "--build", "p/first.build", "-o", dir ^ "/first.rbc"]
     in need (status = 0 andalso has "this build reaches into the library" log, "a first use: " ^ log) end;
     put ("p/second/library.build", "exports (structure Pub)\nuse ../../lib/subbed/x.build\n");
     put ("p/second.build", "use second/library.build\nuse ../lib/subbed/x.build\nfirst.sml\n");
     let val (status, log) = rune ["--no-cache", "--build", "p/second.build", "-o", dir ^ "/second.rbc"]
     in need (status <> 0 andalso has "Priv" log, "a second use: " ^ log) end)

  (* the compiler library's ways through a library: a session's compile, and
     an analysis of a project, whose friends it knows from its build file *)
  fun library () =
    let
      val () = put ("p/analysed.sml", "val () = print (Int.toString (Lower.show (Lower.make 2) + LowerPrivate.n) ^ \"\\n\")\n")
      val () = put ("p/friend.build", "libraries lower end\nanalysed.sml\n")
      val () = put ("p/stranger.build", "libraries lower end\nanalysed.sml\n")
      val () = put ("p/transitive.build", "libraries upper end\nanalysed.sml\n")
      val () = put ("p/api.sml",
        "structure C = RuneCompiler\n\
        \structure A = C.Analysis\n\
        \fun read f = let val i = TextIO.openIn f in TextIO.inputAll i before TextIO.closeIn i end\n\
        \fun diagnosed file =\n\
        \  let val parent = C.session {lib = SOME \"lib\", flags = []}\n\
        \      val context = A.create (parent, {context = \"scoped\"})\n\
        \      val project = C.Project.read (parent, {file = file, workspace = NONE, variables = [], overlays = [], windows = false})\n\
        \      val inputs = List.map (fn source : C.Project.source =>\n\
        \        {file = #file source, text = read (#file source), mode = #mode source,\n\
        \         annotations = #annotations source, revision = \"1\"} : A.input) (C.Project.sources project)\n\
        \      val result = A.check (context, {project = SOME project, inputs = inputs, cancelled = fn () => false})\n\
        \  in null (A.diagnostics result) before (A.close context; C.close parent) end\n\
        \fun compiled text =\n\
        \  let val session = C.session {lib = SOME \"lib\", flags = [\"--library\", \"upper\"]}\n\
        \      val ok = (ignore (C.compileText (session, {file = \"t.sml\", text = text})); true) handle C.Failed _ => false\n\
        \  in ok before C.close session end\n\
        \fun show b = if b then \"yes\" else \"no\"\n\
        \val () = print (show (diagnosed \"p/friend.build\") ^ \" \" ^ show (diagnosed \"p/stranger.build\") ^ \" \"\n\
        \                ^ show (diagnosed \"p/transitive.build\") ^ \" \" ^ show (compiled \"val x = Upper.value\\n\") ^ \" \"\n\
        \                ^ show (compiled \"val x = Lower.make 1\\n\") ^ \"\\n\")\n")
      val (status, log) = runeWith (libraries ["compiler"] @ ["--no-warnings", "p/api.sml", "-o", dir ^ "/api.rbc"])
      val () = need (status = 0, "the API's program: " ^ log)
      val (status, output) = runProgram (dir ^ "/api.rbc")
    in need (status = 0 andalso output = "yes no no yes no\n", "the compiler library's scopes: " ^ output) end

  (* S41, S42, S58, --verify-cache, through scopes *)
  val everything = ["upper", "mixed", "twin1", "twin2", "deep", "plain"]
  val everyName = "open Lower\nval () = print (Int.toString (Upper.value + Mixed.v + Plain.v + Deep.v + (1 +++ 2)) ^ Twin1.v ^ Twin2.v ^ \"\\n\")\n"
  fun together () =
    let
      val all = libraries ("lower" :: everything)
      val () = prints "together" ("lower" :: everything) everyName "80onetwo\n"
      fun compile label flags =
        let
          val rbc = dir ^ "/" ^ label ^ ".rbc"
          (* units this small get a child only when told to *)
          val (status, log) = runeEnv (setEnv ("RUNE_PARALLEL_MIN", "0")) (["--lib", lib] @ flags @ all @ ["p/together.sml", "-o", rbc])
        in need (status = 0, label ^ ": " ^ log); rbc end
      val cache = ["--units", "--cache-dir", dir ^ "/together-cache"]
      val cold = compile "cold" cache
      val warm = compile "warm" cache
      val verified = compile "verified" ("--verify-cache" :: cache)
      val none = compile "none" ["--units", "--no-cache"]
      val parallel = compile "parallel" ["--units", "--cache-dir", dir ^ "/parallel-cache", "-j", "4"]
      val whole = compile "plain-whole" ["--no-cache"]
      val fromUnits = compile "from-units" ["--units", "--whole", "--no-cache"]
    in
      need (same (cold, warm), "S41: warm differs from cold");
      need (same (cold, verified), "--verify-cache differs");
      need (same (cold, none), "the cache changes the program");
      need (same (cold, parallel), "S58: -j changes the program");
      need (same (whole, fromUnits), "S42: --units --whole differs from whole")
    end

  (* What a filter does to a client's cache entry: an edit behind the boundary
     compiles no client, whichever unit it is in; one that a client can see
     does. Usages are by name, of the fingerprint of the name as the filter
     shows it, so that a client depends on what it named of what it could
     see (docs/units.md, The cache). *)
  fun keys () =
    let
      val cache = ["--units", "--cache-dir", dir ^ "/keys-cache", "--explain-rebuild"]
      val () = put ("p/client.sml", "val () = print (Int.toString (Lower.show (Lower.make 2)) ^ \"\\n\")\n")
      fun build () = rune (cache @ libraries ["lower"] @ ["p/client.sml", "-o", dir ^ "/client.rbc"])
      val (status, log) = build ()
      val () = need (status = 0, "client: " ^ log)
      fun clientCompiled log = has "rune: compiled p/client.sml" log
      fun edit (file, text) = (put ("lib/lower/" ^ file, text); ignore (index "lower"))
      val () = edit ("private.sml", "structure LowerPrivate = struct val n = 40 val more = 1 end\nstructure Another = struct end\n")
      val (status, log) = build ()
      val () = need (status = 0 andalso not (clientCompiled log), "an edit behind the boundary compiled a client: " ^ log)
      val (status, output) = runProgram (dir ^ "/client.rbc")
      val () = need (status = 0 andalso output = "42\n", "client prints " ^ output)
      (* and in the unit of what it names *)
      val () = put ("p/twin-client.sml", "val () = print (Twin1.v ^ \"\\n\")\n")
      fun twin () = rune (cache @ libraries ["twin1"] @ ["p/twin-client.sml", "-o", dir ^ "/twin-client.rbc"])
      val (status, log) = twin ()
      val () = need (status = 0, "client: " ^ log)
      val () = put ("lib/twin1/twin.sml", "structure Shared = struct val v = \"one\" val more = 1 end\nstructure Twin1 = struct val v = Shared.v end\n")
      val (status, log) = twin ()
      val () = need (status = 0 andalso not (has "rune: compiled p/twin-client.sml" log), "an edit in the unit of what it names compiled a client: " ^ log)
      (* a new export it does not name *)
      val () = put ("lib/lower/library.build",
                    "exports (structure Lower, signature LOWER, structure Another, fixity +++)\n\
                    \annotate \"always\" in ops.sml end\n\
                    \annotate \"demand\" in\n  lower_sig.sml\n  private.sml\n  lower.sml\nend\n")
      val () = ignore (index "lower")
      val (status, log) = build ()
      val () = need (status = 0 andalso not (clientCompiled log), "an export it does not name compiled a client: " ^ log)
      (* one it does name, gone *)
      val () = put ("lib/lower/library.build",
                    "exports (signature LOWER, fixity +++)\n\
                    \annotate \"always\" in ops.sml end\n\
                    \annotate \"demand\" in\n  lower_sig.sml\n  private.sml\n  lower.sml\nend\n")
      val () = ignore (index "lower")
      val (status, log) = build ()
      val () = need (status <> 0 andalso has "Lower" log, "a client kept what the boundary hid: " ^ log)
      (* its signature, which it sees *)
      val () = put ("lib/lower/library.build",
                    "exports (structure Lower, signature LOWER, fixity +++)\n\
                    \annotate \"always\" in ops.sml end\n\
                    \annotate \"demand\" in\n  lower_sig.sml\n  private.sml\n  lower.sml\nend\n")
      val () = edit ("lower_sig.sml", read (lib ^ "/lower/lower_sig.sml") ^ "\n")
      val (status, log) = build ()
      val () = need (status = 0, "client: " ^ log)
      val () = edit ("lower_sig.sml",
                     "signature LOWER = sig type t val make : int -> t val show : t -> int val more : int\n\
                     \  val +++ : int * int -> int val *** : int * int -> int end\n")
      val () = edit ("lower.sml",
                     "structure Lower :> LOWER = struct type t = int fun make n = n + LowerPrivate.n fun show x = x val more = 1\n\
                     \  fun a +++ b = a + b fun a *** b = a * b end\n")
      val (status, log) = build ()
    in need (status = 0, "client: " ^ log) end

  (* H3's check of a filter: random edits of libraries behind boundaries and
     of what they export, each built through one cache and with none, which
     must agree as bytes or both fail. *)
  fun edits () =
    let
      val cache = dir ^ "/edits-cache"
      val all = libraries ["upper", "twin1"]
      fun text path = read (dir ^ "/" ^ path)
      val () = put ("p/edited.sml", "val () = print (Int.toString Upper.value ^ Twin1.v ^ \"\\n\")\n")
      val baseUpper = text "lib/upper/library.build"
      val baseTwin = text "lib/twin1/library.build"
      (* each edit, and which library's index it needs *)
      val choices =
        Vector.fromList
          [("lower", "lib/lower/private.sml", fn () => "structure LowerPrivate = struct val n = 41 end\n"),
           ("lower", "lib/lower/private.sml", fn () => "structure LowerPrivate = struct val n = 40 val other = 1 end\n"),
           ("lower", "lib/lower/ops.sml", fn () => "infix 2 +++\ninfix 7 ***\n"),
           ("lower", "lib/lower/ops.sml", fn () => "infixr 6 +++\ninfix 7 ***\n"),
           ("lower", "lib/lower/ops.sml", fn () => "infix 6 +++\ninfix 7 ***\n"),
           ("upper", "lib/upper/upper.sml", fn () => "structure Upper = struct local open Lower in val value = show (make 2) +++ 2 * 3 end end\n"),
           ("upper", "lib/upper/upper.sml", fn () => "structure Upper = struct local open Lower in val value = show (make 1) +++ 2 * 3 end end\n"),
           ("upper", "lib/upper/library.build", fn () => "exports (structure Upper)\nannotate \"demand\" in upper.sml end\n"),
           ("upper", "lib/upper/library.build", fn () => baseUpper),
           ("twin1", "lib/twin1/twin.sml", fn () => "structure Shared = struct val v = \"uno\" end\nstructure Twin1 = struct val v = Shared.v end\n"),
           ("twin1", "lib/twin1/twin.sml", fn () => "structure Shared = struct val v = \"one\" end\nstructure Twin1 = struct val v = Shared.v end\n"),
           ("twin1", "lib/twin1/library.build", fn () => "exports (structure Twin1, structure Shared)\nannotate \"demand\" in twin.sml end\n"),
           ("twin1", "lib/twin1/library.build", fn () => baseTwin),
           ("twin1", "lib/twin1/library.build", fn () => "exports (structure Shared)\nannotate \"demand\" in twin.sml end\n")]
      val seed = ref 7
      fun next n = (seed := (!seed * 1103 + 12345) mod 65536; !seed mod n)
      val agreed = ref 0
      val built = ref 0
      fun step 0 = ()
        | step k =
            let
              val (library, file, make) = Vector.sub (choices, next (Vector.length choices))
              val () = put (file, make ())
              val _ = rune ["--basis-index", "lib/" ^ library]
              val (s1, log) = rune (["--units", "--cache-dir", cache] @ all @ ["p/edited.sml", "-o", dir ^ "/edited.rbc"])
              val (s2, _) = rune (["--units", "--no-cache"] @ all @ ["p/edited.sml", "-o", dir ^ "/edited-plain.rbc"])
              val agree = (s1 = 0) = (s2 = 0) andalso (s1 <> 0 orelse same (dir ^ "/edited.rbc", dir ^ "/edited-plain.rbc"))
            in
              need (agree, "the cache disagrees after an edit of " ^ file ^ " with " ^ Int.toString k ^ " to go: " ^ log);
              agreed := !agreed + 1; if s2 = 0 then built := !built + 1 else (); step (k - 1)
            end
    in
      step 40;
      need (!built >= 10 andalso !built < !agreed, "the edits do not exercise both outcomes");
      say ("library model: " ^ Int.toString (!agreed) ^ " edits agree with no cache, " ^ Int.toString (!built) ^ " of them a program\n")
    end

  fun run' () =
    (tree (); manifests (); requires (); noHeader (); boundary (); views (); friends (); clashes (); malformed (); holes ();
     library (); together (); keys (); tree (); edits ())
end

(* Namespaces and views of the Basis Library (docs/build.md, Clashes, and
   Views of the Basis Library; the build-system roadmap's M10, D9 and D12):
   renames at import of each kind, what they do to the cache, what a rename
   may not be, a program with both of this tree's History structures, and a
   view of a Basis Library that has one, which hides a member. *)
structure Namespaces =
struct
  open Sh
  val dir = run ^ "/namespaces"
  val lib = dir ^ "/lib"
  fun need (ok, message) = if ok then () else raise Fail ("namespaces: " ^ message)
  fun has text log = String.isSubstring text log
  val count = ref 0
  fun runeEnv envf args =
    let
      val () = count := !count + 1
      val log = dir ^ "/log-" ^ Int.toString (!count)
      val status = execEnv envf {cmd = fromRoot (env ("RUNE", "bin/rune")) :: args, dir = SOME dir, stdin = "",
                                 stdout = log, stderr = log, timeout = 600}
    in (status, read log) end
  val runeWith = runeEnv (fn e => e)
  fun rune args = runeWith (["--lib", lib] @ args)
  fun runProgram rbc =
    let
      val log = rbc ^ ".out"
      val status = exec {cmd = [fromRoot (env ("RUNEVM", "bin/runevm")), rbc], dir = SOME dir, stdin = "",
                         stdout = log, stderr = log, timeout = 60}
    in (status, read log) end
  fun put (path, text) =
    (mkdirs (OS.Path.dir (dir ^ "/" ^ path)); write (dir ^ "/" ^ path, text))
  fun index name =
    let val (status, log) = rune ["--basis-index", "lib/" ^ name]
    in need (status = 0, "cannot index " ^ name ^ ": " ^ log); log end
  fun indexRefused name reason =
    let val (status, log) = rune ["--basis-index", "lib/" ^ name]
    in need (status <> 0 andalso has reason log, "the index of " ^ name ^ " did not say " ^ reason ^ ": " ^ log) end
  val modes = [("whole", ["--no-cache"]), ("units", ["--units", "--no-cache"]), ("units-whole", ["--units", "--whole", "--no-cache"])]
  val libraries = List.concat o List.map (fn l => ["--library", l])
  (* a program prints expected, each way, with these arguments before it *)
  fun printsWith (runner, label, args, source, expected) =
    let
      val () = put ("p/" ^ label ^ ".sml", source)
      fun mode (name, flags) =
        let
          val rbc = dir ^ "/" ^ label ^ "-" ^ name ^ ".rbc"
          val (status, log) = runner (flags @ args @ ["p/" ^ label ^ ".sml", "-o", rbc])
          val () = need (status = 0, label ^ " does not compile " ^ name ^ ": " ^ log)
          val (status, output) = runProgram rbc
        in need (status = 0 andalso output = expected, label ^ " " ^ name ^ " prints " ^ output) end
    in List.app mode modes end
  fun prints label libs source expected = printsWith (rune, label, libraries libs, source, expected)
  (* and this one is refused, saying reason *)
  fun refusedWith (runner, label, args, source, reason) =
    let
      val () = put ("p/" ^ label ^ ".sml", source)
      fun mode (name, flags) =
        let val (status, log) = runner (flags @ args @ ["p/" ^ label ^ ".sml", "-o", dir ^ "/refused.rbc"])
        in need (status <> 0 andalso has reason log, label ^ " " ^ name ^ " was not refused for " ^ reason ^ ": " ^ log) end
    in List.app mode modes end
  fun refused label libs source reason = refusedWith (rune, label, libraries libs, source, reason)

  fun tree () =
    (rmTree dir; mkdirs lib;
     Posix.FileSys.symlink {old = fromRoot "lib/basis", new = lib ^ "/basis"};
     put ("lib/one/library.build", "exports (structure Same, structure Left, structure Right)\nannotate \"demand\" in one.sml end\n");
     put ("lib/one/one.sml", "structure Same = struct val v = 1 end\nstructure Left = struct val v = \"l\" end\nstructure Right = struct val v = \"r\" end\n");
     put ("lib/two/library.build", "exports (structure Same)\nannotate \"demand\" in two.sml end\n");
     put ("lib/two/two.sml", "structure Same = struct val v = 2 end\n");
     (* a module and a type of each kind *)
     put ("lib/kinds/library.build",
          "exports (structure K, signature K_SIG, functor KFn, type kt)\nannotate \"demand\" in kinds.sml end\n");
     put ("lib/kinds/kinds.sml",
          "signature K_SIG = sig val v : int end\nstructure K : K_SIG = struct val v = 5 end\n\
          \functor KFn (X : K_SIG) = struct val w = X.v + 1 end\ntype kt = int\n");
     put ("lib/plainlib/library.build", "annotate \"demand\" in plain.sml end\n");
     put ("lib/plainlib/plain.sml", "structure Plain = struct val v = 3 end\n");
     put ("lib/loose/library.build", "libraries one (structure Same as One) end\nannotate \"demand\" in loose.sml end\n");
     put ("lib/loose/loose.sml", "structure Loose = struct end\n");
     List.app (fn n => ignore (index n)) ["one", "two", "kinds", "plainlib"])

  (* renames of each kind, and two names changing places *)
  fun kinds () =
    (prints "kinds" ["kinds (structure K as Kay, signature K_SIG as KAY, functor KFn as KayFn, type kt as kay)"]
            "structure L : KAY = Kay\nstructure M = KayFn (L)\nval x : kay = M.w\nval () = print (Int.toString x ^ \"\\n\")\n" "6\n";
     refused "kinds-gone" ["kinds (structure K as Kay)"] "val () = print (Int.toString K.v ^ \"\\n\")\n" "K.v";
     refused "kinds-type-gone" ["kinds (type kt as kay)"] "val x : kt = 1\n" "kt";
     prints "swap" ["one (structure Left as Right, structure Right as Left)"]
            "val () = print (Left.v ^ Right.v ^ \"\\n\")\n" "rl\n")

  (* what a rename may not be *)
  fun refusals () =
    let
      val source = "val () = ()\n"
      fun no (label, libs, reason) = refused label libs source reason
    in
      no ("unknown", ["one (structure Nope as Yes)"], "renames structure Nope, which it does not export");
      no ("kind", ["kinds (signature K as Kay)"], "renames signature K, which it does not export");
      no ("twice", ["one (structure Same as A, structure Same as B)"], "renames structure Same twice");
      no ("two-to-one", ["one (structure Left as A, structure Right as A)"], "renames two names to A");
      no ("onto-own", ["one (structure Left as Right)"], "renames Left to Right, which it has already");
      no ("value", ["one (val x as y)"], "a rename is of a structure, signature, functor or type");
      no ("no-as", ["one (structure Same Two)"], "expected as");
      no ("twice-imported", ["one (structure Same as A)", "one (structure Same as B)"], "imported twice in one scope, renamed otherwise");
      (* a library with no header says its names and not their kinds: the
         compile finds a kind it does not have *)
      refused "no-header-kind" ["plainlib (signature Plain as P)"] "val () = print (Int.toString Plain.v)\n"
              "renames signature Plain, which it does not declare as a signature";
      prints "no-header-renamed" ["plainlib (structure Plain as P)"] "val () = print (Int.toString P.v ^ \"\\n\")\n" "3\n";
      indexRefused "loose" "a library with no header renames nothing it is written on"
    end

  (* a rename in a cache: two that change places compile the client again,
     and the cache agrees with none; S41, S42, S58 and --verify-cache *)
  fun cache () =
    let
      val () = put ("p/client.sml", "val () = print (Int.toString One.v ^ Int.toString Two.v ^ \"\\n\")\n")
      val cacheDir = ["--units", "--cache-dir", dir ^ "/cache"]
      fun compile (label, flags, libs) =
        let
          val rbc = dir ^ "/" ^ label ^ ".rbc"
          val (status, log) = runeEnv (setEnv ("RUNE_PARALLEL_MIN", "0"))
                                      (["--lib", lib] @ flags @ libraries libs @ ["p/client.sml", "-o", rbc])
        in need (status = 0, label ^ ": " ^ log); rbc end
      fun output rbc = let val (status, out) = runProgram rbc in need (status = 0, rbc ^ " fails: " ^ out); out end
      val ab = ["one (structure Same as One)", "two (structure Same as Two)"]
      val ba = ["one (structure Same as Two)", "two (structure Same as One)"]
      val cold = compile ("cold", cacheDir, ab)
      val warm = compile ("warm", cacheDir, ab)
      val verified = compile ("verified", "--verify-cache" :: cacheDir, ab)
      val parallel = compile ("parallel", ["--units", "--cache-dir", dir ^ "/parallel-cache", "-j", "4"], ab)
      val whole = compile ("whole", ["--no-cache"], ab)
      val fromUnits = compile ("from-units", ["--units", "--whole", "--no-cache"], ab)
      val () = need (output cold = "12\n", "the renamed client prints " ^ output cold)
      val () = need (same (cold, warm), "S41: warm differs from cold")
      val () = need (same (cold, verified), "--verify-cache differs")
      val () = need (same (cold, parallel), "S58: -j changes the program")
      val () = need (same (whole, fromUnits), "S42: --units --whole differs from whole")
      val swapped = compile ("swapped", cacheDir, ba)
      val plain = compile ("swapped-plain", ["--units", "--no-cache"], ba)
    in
      need (output swapped = "21\n", "the cache kept a rename's old binding: " ^ output swapped);
      need (same (swapped, plain), "the cache disagrees with none after renames change places")
    end

  (* the plan says what is renamed, and reads back *)
  fun plan () =
    let
      val () = put ("p/planned.build", "libraries one (structure Same as One) two end\nview planned\nplanned.sml\n")
      val () = put ("p/planned.sml", "val () = ()\n")
      val (status, log) = rune ["--plan", "p/planned.build"]
      val () = need (status = 0 andalso has "\nview planned\n" log andalso has "  requires one(structure:Same=One)\n" log,
                     "the plan of renames and a view: " ^ log)
      val () = put ("p/planned.plan", log)
      val (status, again) = rune ["--plan", "p/planned.plan"]
    in need (status = 0 andalso again = log, "a plan with renames does not read back: " ^ again) end

  (* D9's first rename: this tree's two History structures, terminal's and
     test/runner's, in one program, which no order of the libraries gave *)
  fun history () =
    let
      fun real args = runeWith (["--lib", fromRoot "lib"] @ args)
      val source =
        "val t = History.load {file = NONE, limit = 10}\n\
        \val () = History.add (t, \"one\")\n\
        \structure R : RUNNER_HISTORY = RunnerHistory\n\
        \val r = R.record (R.empty, {path = \"p\", wall = 1.0, passed = true})\n\
        \val () = print (Int.toString (Vector.length (History.entries t)) ^ \" \" ^ Int.toString (length (R.entries r)) ^ \"\\n\")\n"
      val () = put ("p/histories.build",
                    "libraries terminal test/runner (structure History as RunnerHistory, signature HISTORY as RUNNER_HISTORY) end\n\
                    \histories.sml\n")
      val () = put ("p/histories.sml", source)
      fun build (label, flags) =
        let
          val rbc = dir ^ "/" ^ label ^ ".rbc"
          val (status, log) = real (flags @ ["--build", "p/histories.build", "-o", rbc])
          val () = need (status = 0, "both Historys, " ^ label ^ ": " ^ log)
          val (status, output) = runProgram rbc
        in need (status = 0 andalso output = "1 1\n", "both Historys, " ^ label ^ ", print " ^ output) end
    in
      build ("histories-whole", ["--no-cache", "--whole"]);
      build ("histories-units", ["--cache-dir", dir ^ "/histories-cache"]);
      (* without the rename, test/runner's shadows terminal's, as it did *)
      refusedWith (real, "histories-shadowed", libraries ["terminal", "test/runner"],
                   "val t = History.load {file = NONE, limit = 10}\n", "History.load")
    end

  (* D12: a Basis Library with a view, its seals after the libraries: the
     whole Basis Library, each file linked, and a build file with the view *)
  val vlib = dir ^ "/vlib"
  fun viewTree () =
    let
      val basis = fromRoot "lib/basis"
      val () = mkdirs (vlib ^ "/basis")
      val () = List.app (fn f => if String.isSuffix ".sml" f then Posix.FileSys.symlink {old = basis ^ "/" ^ f, new = vlib ^ "/basis/" ^ f} else ())
                        (entries basis)
      val build = read (basis ^ "/library.build")
      (* the view's seals go before the final file, after the seals *)
      val final = "annotate \"final\""
      fun before' (text, mark) =
        let fun find i = if String.isPrefix mark (String.extract (text, i, NONE)) then i else find (i + 1)
        in find 0 end
      val i = before' (build, final)
      val () = write (vlib ^ "/basis/library.build",
                      String.substring (build, 0, i) ^
                      "annotate \"seal\" \"view=narrow\" \"host=no\" in\n  view_narrow_list.sml\nend\n" ^
                      String.extract (build, i, NONE))
      val () = write (vlib ^ "/basis/view_narrow_list.sml",
                      "(* a test's view of List: no getItem *)\n\
                      \signature LIST_NARROW =\nsig\n  datatype list = datatype list\n  exception Empty\n\
                      \  val null : 'a list -> bool\n  val length : 'a list -> int\n  val hd : 'a list -> 'a\n\
                      \  val map : ('a -> 'b) -> 'a list -> 'b list\n  val foldl : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b\nend\n\
                      \signature LIST = LIST_NARROW\nstructure List : LIST = List\n")
      (* a library that uses what the view hides, which it sees whole *)
      val () = put ("vlib/getter/library.build", "exports (structure Getter)\nannotate \"demand\" in getter.sml end\n")
      val () = put ("vlib/getter/getter.sml",
                    "structure Getter = struct fun first l = case List.getItem l of SOME (x, _) => x | NONE => 0 end\n")
      fun vindex name =
        let val (status, log) = runeWith ["--lib", vlib, "--basis-index", vlib ^ "/" ^ name]
        in need (status = 0, "cannot index " ^ name ^ ": " ^ log) end
    in vindex "basis"; vindex "getter" end
  fun inView args = runeWith (["--lib", vlib] @ args)

  fun views () =
    let
      val () = viewTree ()
      val () = need (has "| seal@narrow |" (read (vlib ^ "/basis/MANIFEST")), "no view in the manifest")
      val getItem = "val () = print (case List.getItem [1, 2] of SOME (x, _) => Int.toString x ^ \"\\n\" | NONE => \"\\n\")\n"
      val mapped = "val () = print (Int.toString (List.foldl op+ 0 (List.map (fn x => x * 2) [1, 2, 3])) ^ \"\\n\")\n"
      (* the default sees all; the view hides a member *)
      val () = printsWith (inView, "default", [], getItem, "1\n")
      val () = refusedWith (inView, "hidden", ["--basis-view", "narrow"], getItem, "List.getItem")
      val () = printsWith (inView, "narrow", ["--basis-view", "narrow"], mapped, "12\n")
      val () = refusedWith (inView, "hidden-all", ["--basis", "all", "--basis-view", "narrow"], getItem, "List.getItem")
      (* a library sees the Basis Library whole; the client in the view *)
      val () = printsWith (inView, "library-whole", ["--basis-view", "narrow", "--library", "getter"],
                           "val () = print (Int.toString (Getter.first [3, 4]) ^ \"\\n\")\n", "3\n")
      (* a build file's view *)
      val () = put ("p/viewed.build", "view narrow\nviewed.sml\n")
      val () = put ("p/viewed.sml", getItem)
      val (status, log) = inView ["--no-cache", "--build", "p/viewed.build", "-o", dir ^ "/viewed.rbc"]
      val () = need (status <> 0 andalso has "List.getItem" log, "a build's view did not hide: " ^ log)
      val (status, log) = inView ["--no-cache", "--basis-view", "other", "--build", "p/viewed.build", "-o", dir ^ "/viewed.rbc"]
      val () = need (status <> 0 andalso has "the build's view of the Basis Library is narrow, and the command line's other" log,
                     "two views: " ^ log)
      (* what a view may not be *)
      val () = refusedWith (inView, "unknown-view", ["--basis-view", "nope"], mapped, "the Basis Library has no view nope")
      val (status, log) = inView ["--no-prelude", "--basis-view", "narrow", "p/narrow.sml", "-o", dir ^ "/x.rbc"]
      val () = need (status <> 0 andalso has "needs the Basis Library" log, "a view with no Basis Library: " ^ log)
      val () = put ("vlib/viewing/library.build", "exports (structure V)\nview narrow\nannotate \"demand\" in v.sml end\n")
      val () = put ("vlib/viewing/v.sml", "structure V = struct end\n")
      val (status, log) = runeWith ["--lib", vlib, "--basis-index", vlib ^ "/viewing"]
      val () = need (status <> 0 andalso has "a view of the Basis Library is a program's" log, "a library's view: " ^ log)
      val () = put ("vlib/viewing/library.build", "exports (structure V)\nannotate \"seal\" \"view=narrow\" in v.sml end\n")
      val (status, log) = runeWith ["--lib", vlib, "--basis-index", vlib ^ "/viewing"]
      val () = need (status <> 0 andalso has "a view is the Basis Library's" log, "a library's seal of a view: " ^ log)
      (* S41, S42 and --verify-cache in the view, and one cache for both,
         each order: the usage of List names its binder, which the view's
         seal is *)
      val () = put ("p/both.sml", mapped)
      val cache = ["--units", "--cache-dir", dir ^ "/view-cache"]
      fun compile (label, flags) =
        let
          val rbc = dir ^ "/" ^ label ^ ".rbc"
          val (status, log) = inView (flags @ ["p/both.sml", "-o", rbc])
        in (status, log, rbc) end
      fun ok (label, flags) = let val (status, log, rbc) = compile (label, flags) in need (status = 0, label ^ ": " ^ log); rbc end
      val narrow = ["--basis-view", "narrow"]
      val cold = ok ("view-cold", cache @ narrow)
      val warm = ok ("view-warm", cache @ narrow)
      val verified = ok ("view-verified", "--verify-cache" :: cache @ narrow)
      val whole = ok ("view-whole", "--no-cache" :: narrow)
      val fromUnits = ok ("view-from-units", ["--units", "--whole", "--no-cache"] @ narrow)
      val parallel =
        let val rbc = dir ^ "/view-parallel.rbc"
            val (status, log) = runeEnv (setEnv ("RUNE_PARALLEL_MIN", "0"))
                                        (["--lib", vlib, "--units", "--cache-dir", dir ^ "/view-parallel-cache", "-j", "4"]
                                         @ narrow @ ["p/both.sml", "-o", rbc])
        in need (status = 0, "view-parallel: " ^ log); rbc end
      val () = need (same (cold, parallel), "S58 in a view: -j changes the program")
      val () = need (same (cold, warm), "S41 in a view: warm differs from cold")
      val () = need (same (cold, verified), "--verify-cache in a view differs")
      val () = need (same (whole, fromUnits), "S42 in a view: --units --whole differs from whole")
      val plain = ok ("view-default", cache)
      val plainNone = ok ("view-default-none", ["--units", "--no-cache"])
      val () = need (same (plain, plainNone), "the default after the view, through one cache, differs")
      val () = need (not (same (plain, cold)), "the view's program is the default's")
      val () = put ("p/both.sml", getItem)
      val (status, log, _) = compile ("view-hidden-cached", cache @ narrow)
      val () = need (status <> 0 andalso has "List.getItem" log, "the cache let the view see a hidden member: " ^ log)
      val again = ok ("view-default-again", cache)
      val (status, output) = runProgram again
      val () = need (status = 0 andalso output = "1\n", "the default after the view prints " ^ output)
      val (status, log) = inView ["--plan", "--basis-view", "narrow", "p/both.sml"]
    in need (status = 0 andalso has "\nview narrow\n" log, "--plan's view: " ^ log) end

  fun run' () =
    (tree (); kinds (); refusals (); cache (); plan (); history (); views ())
end
