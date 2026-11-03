(* Ordered build/dependency scenarios. Commands are argument vectors; fixture
   creation, rebuild sets, diagnostics and byte comparisons are SML values. *)
structure Scenarios =
struct
  open Sh
  exception Failed of string
  type context = {directory : string, compiler : string, vm : string}
  type result = {status : int, output : string, errors : string}
  fun need (ok, why) = if ok then () else raise Failed why
  fun create name compiler : context =
    {directory = run ^ "/scenarios/" ^ name, compiler = fromRoot compiler,
     vm = OS.Path.dir (fromRoot compiler) ^ "/runevm"}
  fun put ({directory, ...} : context) path text =
    let val file = directory ^ "/" ^ path
    in mkdirs (OS.Path.dir file); write (file, text ^ "\n") end
  fun reset (c : context) = (rmTree (#directory c); mkdirs (#directory c))
  fun execute (c : context) name working args : result =
    let val log = #directory c ^ "/logs/" ^ name
        val () = mkdirs (OS.Path.dir log)
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 600,
                                    fileSize = SOME (1024 * 1024 * 1024), core = SOME 0}
          (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"])
          {cmd = args, dir = SOME (if OS.Path.isAbsolute working then working else #directory c ^ (if working = "" then "" else "/" ^ working)),
           stdin = "", stdout = log ^ ".out", stderr = log ^ ".err", timeout = 600}
    in {status = status, output = read (log ^ ".out"), errors = read (log ^ ".err")} end
  fun compiler c name working args = execute c name working (#compiler c :: args)
  fun program c name working args = execute c name working (#vm c :: args)
  fun success (r : result) = need (#status r = 0, "command failed (" ^ Int.toString (#status r) ^ "): " ^ #errors r)
  fun refused (r : result) message = need ((#status r = 1 orelse #status r = 255) andalso String.isSubstring message (#errors r ^ #output r),
                                          "expected refusal: " ^ message ^ "; got " ^ #errors r ^ #output r)
  fun output (r : result) expected = (success r; need (#output r = expected andalso #errors r = "",
           "expected output " ^ String.toString expected ^ ", got " ^ String.toString (#output r ^ #errors r)))
  fun bytecode file = need (exists file andalso OS.FileSys.fileSize file > 0, "compiler produced no bytecode: " ^ file)
  fun rebuilt text = List.mapPartial (fn line => if String.isPrefix "rune: compiled " line then
           SOME (Substring.string (#1 (Substring.position ":" (Substring.full (String.extract (line, 15, NONE)))))) else NONE) (lines text)
  fun depsPrepare c () =
    (reset c;
     List.app (fn (file, text) => put c file text)
      [("order/a.sml", "structure A = struct val x = 1 end"),
       ("order/b.sml", "structure B = struct val y = A.x + 1 end"),
       ("order/c.sml", "signature C = sig val z : int end  functor F (X : C) = struct val w = B.y + X.z end"),
       ("cycle/x.sml", "structure X = struct val a = Y.b end"),
       ("cycle/y.sml", "structure Y = struct val b = 1 val c = X.a end"),
       ("twice/p.sml", "structure P = struct end"), ("twice/q.sml", "structure P = struct val again = 1 end"),
       ("twice/r.sml", "structure R = struct val r = P.again end"),
       ("broken/m.sml", "structure M = struct end\nval top = 1"),
       ("broken/n.sml", "structure N = struct val n = top + 1 end"),
       (* a unit that is not well-formed stays where it is written *)
       ("stays/c.sml", "structure C = struct val z = A.x end"),
       ("stays/m.sml", "val top = 1"),
       ("stays/a.sml", "structure A = struct val x = top end"),
       ("stays/b.sml", "structure B = struct val y = A.x end"),
       (* what breaks no rule: an effect, a local's head, a bare expression *)
       ("relaxed/r0.sml", "structure R0 = struct val v = R1.x end"),
       ("relaxed/r1.sml", "local val hidden = 1 open List in structure R1 = struct val x = hidden end end\nval _ = print \"\"\nval () = ()\n;print \"\""),
       (* a fixity a file before leaves, which a file after needs to parse *)
       ("fixity/p.sml", "infixr 5 :::\ndatatype t = E | ::: of int * t"),
       ("fixity/u.sml", "structure U = struct fun first (x ::: _) = x | first E = 0 end"),
       ("fixity/plain.build", "p.sml u.sml"),
       ("fixity/prelude.build", "annotate \"prelude\" in p.sml end\nu.sml"),
       (* a library's own: strict, and told once *)
       ("lib/lax/library.build", "exports (structure Lax)\nannotate \"demand\" in lax.sml end"),
       ("lib/lax/lax.sml", "structure Lax = struct val v = 1 end\nval leaked = 2"),
       ("lib/strict/library.build", "exports (structure Strict)\nstrict\nannotate \"demand\" in strict.sml end"),
       ("lib/strict/strict.sml", "structure Strict = struct val v = 1 end\nval leaked = 2"),
       ("lib/fine/library.build", "exports (structure Fine)\nstrict\nannotate \"always\" in ops.sml end\nannotate \"demand\" in fine.sml end\nannotate \"final\" in last.sml end"),
       ("lib/fine/ops.sml", "infix 5 <+>\nfun a <+> b = a + b"),
       ("lib/fine/fine.sml", "structure Fine = struct val v = 1 <+> 2 end"),
       ("lib/fine/last.sml", "val () = ()\nval checked = Fine.v"),
       ("entry/main.sml", "val () = print (Int.toString B.y ^ \"\\n\")"),
       ("entry/lib/a.sml", "structure A = struct val x = 40 end"),
       ("entry/lib/b.sml", "structure B = struct val y = A.x + 2 end"),
       ("entry/lib/u.sml", "structure U = struct val nothing = () end"),
       ("entry/lib/z.sml", "structure Z = struct end\nval zero = 0"),
       ("entry/needs-z.sml", "structure Use = Z")];
     Posix.FileSys.symlink {old = fromRoot "lib/basis", new = #directory c ^ "/lib/basis"})
  (* a run of rune --deps that succeeds and finds no unit that is not
     well-formed, whatever else it says *)
  fun wellFormed what (r : result) =
    (success r;
     case List.filter (String.isSubstring "is not well-formed") (lines (#errors r)) of
       [] => ()
     | broken => raise Failed (what ^ ": " ^ String.concatWith "\n" broken))
  (* a command that succeeds, with its output and the warnings that begin so *)
  fun warned (r : result) expected (warnings : string list) =
    (success r;
     need (#output r = expected, "expected output " ^ String.toString expected ^ ", got " ^ String.toString (#output r));
     need (List.length (lines (#errors r)) = List.length warnings
           andalso ListPair.all (fn (line, w) => String.isPrefix w line) (lines (#errors r), warnings),
           "expected the warnings " ^ String.concatWith " | " warnings ^ ", got " ^ #errors r))
  fun deps c which () =
    case which of
      "order" => output (compiler c which "order" ["--deps", "c.sml", "b.sml", "a.sml"]) "a.sml\nb.sml\nc.sml\n"
    | "dot" => let val r = compiler c which "order" ["--deps-dot", "c.sml", "b.sml", "a.sml"]
               in success r; need (String.isSubstring "\"c.sml\" -> \"b.sml\"" (#output r)
                         andalso String.isSubstring "\"b.sml\" -> \"a.sml\"" (#output r), "incorrect dependency graph") end
    | "cycle" => refused (compiler c which "cycle" ["--deps", "x.sml", "y.sml"]) "a cycle: x.sml -> y.sml -> x.sml"
    | "duplicate" =>
        warned (compiler c which "twice" ["--deps", "p.sml", "q.sml", "r.sml"]) "p.sml\nq.sml\nr.sml\n"
          ["q.sml:1:1: warning: this unit is not well-formed, and others depend on it: this is structure P, which p.sml declares too"]
    | "duplicate-unused" => output (compiler c which "twice" ["--deps", "p.sml", "q.sml"]) "p.sml\nq.sml\n"
    | "discipline" =>
        warned (compiler c which "broken" ["--deps", "m.sml", "n.sml"]) "m.sml\nn.sml\n"
          ["m.sml:2:1: warning: this unit is not well-formed, and others depend on it: this is a value (docs/units.md, Well-formed units)"]
    | "entry-unit" =>
        (output (compiler c which "broken" ["--deps", "m.sml"]) "m.sml\n";
         (* nothing after it names what it binds *)
         output (compiler c (which ^ "-after") "broken" ["--deps", "n.sml", "m.sml"]) "n.sml\nm.sml\n")
    | "quiet" => output (compiler c which "broken" ["--deps", "--no-warnings", "m.sml", "n.sml"]) "m.sml\nn.sml\n"
    | "stays" =>
        warned (compiler c which "stays" ["--deps", "c.sml", "m.sml", "b.sml", "a.sml"]) "c.sml\nm.sml\na.sml\nb.sml\n"
          ["m.sml:1:1: warning: this unit is not well-formed"]
    | "relaxed" => output (compiler c which "relaxed" ["--deps", "r0.sml", "r1.sml"]) "r1.sml\nr0.sml\n"
    | "fixity" =>
        warned (compiler c which "fixity" ["--deps", "p.sml", "u.sml"]) "p.sml\nu.sml\n"
          ["p.sml:1:1: warning: this unit is not well-formed, and others depend on it: this is a fixity directive",
           "p.sml:2:1: warning: this unit is not well-formed, and others depend on it: this is a datatype"]
    | "fixity-build" => warned (compiler c which "fixity" ["--deps", "--build", "plain.build"]) "p.sml\nu.sml\n"
                               ["p.sml:1:1: warning: this unit is not well-formed", "p.sml:2:1: warning: this unit is not well-formed"]
    | "prelude" => output (compiler c which "fixity" ["--deps", "--build", "prelude.build"]) "p.sml\nu.sml\n"
    | "library-warned" =>
        let val r = compiler c which "" ["--lib", "lib", "--basis-index", "lib/lax"]
        in success r;
           need (lines (#errors r) = ["lib/lax/library.build: warning: this library has a unit that is not well-formed, at lib/lax/lax.sml:2:1, which is a value (docs/units.md, Well-formed units)"],
                 "a library told once: " ^ #errors r)
        end
    | "library-strict" =>
        refused (compiler c which "" ["--lib", "lib", "--basis-index", "lib/strict"])
          "lib/strict/library.build: a strict library's units are well-formed, and one is not"
    | "library-strict-classes" => output (compiler c which "" ["--lib", "lib", "--basis-index", "lib/fine"]) ""
    | "entry" =>
        let val target = #directory c ^ "/entry/p.rbc"
            val () = rmTree target
            val r = compiler c which "entry" ["--units", "--no-cache", "--explain-rebuild", "-I", "lib", "main.sml", "-o", "p.rbc"]
            val () = success r
            val () = bytecode target
            val compiled = List.filter (fn file => String.isPrefix "lib/" file orelse file = "main.sml") (rebuilt (#errors r))
            val () = need (compiled = ["lib/a.sml", "lib/b.sml", "main.sml"], "incorrect entry-point dependency closure")
        in output (program c "entry-run" "entry" ["p.rbc"]) "42\n" end
    | "broken-required-file" => refused (compiler c which "entry" ["-I", "lib", "needs-z.sml", "-o", "z.rbc"])
          "lib/z.sml declares a module needs-z.sml names, and is not well-formed"
    (* E8's table (the build-system roadmap's M16): Rune's own libraries and
       builds, MLton and HOL4's closure are well-formed but for the preludes
       they declare: no unit breaks a rule. Another warning, a nested
       library's use reaching in (D10) say, is not the row's. MLton and HOL4
       are trees of their own, given by RUNE_WELLFORMED_MLTON and
       RUNE_WELLFORMED_HOL4 (docs/testing.md) *)
    | "wellformed-rune" =>
        let
          fun libraries dir =
            List.concat (List.map (fn n => let val p = dir ^ "/" ^ n
                                           in if n = "cache" andalso dir = "lib" then []
                                              else if isDir (fromRoot p) then libraries p
                                              else if n = "library.build" then [p] else [] end)
                                  (entries (fromRoot dir)))
          val builds = sort (libraries "lib")
                       @ List.filter (fn n => String.isSuffix ".build" n) (sort (entries root))
          val units = List.foldl (fn (build, n) =>
                                    let val r = execute c ("wellformed-" ^ String.translate (fn #"/" => "-" | ch => String.str ch) build) root
                                                        [#compiler c, "--deps", "--build", build]
                                    in wellFormed build r; n + length (lines (#output r)) end)
                                 0 builds
        in say (Int.toString units ^ " units of " ^ Int.toString (length builds) ^ " builds, all well-formed but for their preludes\n") end
    | "wellformed-mlton" =>
        (case env ("RUNE_WELLFORMED_MLTON", "") of
           "" => say "SKIP wellformed-mlton: RUNE_WELLFORMED_MLTON names no MLton tree with its build files\n"
         | dir =>
             let val r = execute c which (dir ^ "/mlton") [#compiler c, "--deps", "--build", "mlton.build"]
             in wellFormed "MLton" r;
                need (length (lines (#output r)) = 606, "MLton has 606 units, not " ^ Int.toString (length (lines (#output r))));
                say ("606 units of MLton, all well-formed; " ^ Int.toString (length (lines (#errors r))) ^ " other lines on stderr\n")
             end)
    | "wellformed-hol4" =>
        (case env ("RUNE_WELLFORMED_HOL4", "") of
           "" => say "SKIP wellformed-hol4: RUNE_WELLFORMED_HOL4 names no directory of HOL4's closure and its boss.build\n"
         | dir =>
             let val r = execute c which dir [#compiler c, "--deps", "--build", "boss.build"]
                 val () = wellFormed "HOL4" r
                 val files = lines (#output r)
                 val () = need (length files = 744, "HOL4's closure has 744 units, not " ^ Int.toString (length files))
                 (* and as a list: Conv.sml parses in the fixity Overlay.sml leaves *)
                 val flat = execute c (which ^ "-list") dir ([#compiler c, "--deps"] @ files)
             in success flat; need (length (lines (#output flat)) = 744, "HOL4's closure as a list") end)
    | _ => raise Failed "unknown dependency scenario"
  val depsCases = ["order", "dot", "cycle", "duplicate", "duplicate-unused", "discipline", "entry-unit", "quiet", "stays",
                   "relaxed", "fixity", "fixity-build", "prelude", "library-warned", "library-strict",
                   "library-strict-classes", "entry", "broken-required-file", "wellformed-rune", "wellformed-mlton",
                   "wellformed-hol4"]
  val factorial = "265252859812191058636308480000000\n~2\n16158687986375067893760000\nequal\n"
  (* what examples/virtual/table prints, with either implementation *)
  val tableOutput = "9 squares: 1 1, 2 4, 3 9, 4 16, 5 25, 6 36, 7 49, 8 64, 9 81\n"
                    ^ "6 words: \"and\" 2, \"bird\" 1, \"cat\" 2, \"dog\" 1, \"saw\" 1, \"the\" 4\n"
                    ^ "the square of 7 is 49\nno square of 10\nno word \"zebra\"\n"
  fun buildPrepare c () =
    let val () = reset c
        val () = List.app (fn (file, text) => put c file text)
          [("a.sml", "structure A = struct val x = 40 end"),
           ("b.sml", "structure B = struct val y = A.x + 2 end"),
           ("main.sml", "val () = print (Int.toString B.y ^ \"\\n\")"),
           ("uses-a.sml", "val () = print (Int.toString A.x ^ \"\\n\")"),
           ("list.build", "a.sml b.sml main.sml"),
           (* a boundary is a library's *)
           ("ab/library.build", "exports (structure B)\n../a.sml ../b.sml"),
           ("boundary-used.build", "use ab/library.build main.sml"),
           ("boundary-hidden.build", "use ab/library.build uses-a.sml"),
           (* what the language had, which a build no longer says *)
           ("no-group.build", "group a.sml b.sml end main.sml"),
           ("no-local.build", "local a.sml in b.sml end main.sml"),
           ("no-cache.build", "cache here\na.sml b.sml main.sml"),
           ("no-boundary.build", "library (structure B) = a.sml b.sml end main.sml"),
           ("outside/library.build", "library (structure B) = ../a.sml ../b.sml end ../main.sml"),
           (* a file the other SML systems have alone, which Rune does not compile *)
           ("hostonly/hosts.sml", "structure P = struct val v = \"hosts\" end"),
           ("hostonly/rune.sml", "structure P = struct val v = \"rune\" end"),
           ("hostonly/main.sml", "val () = print (P.v ^ \"\\n\")"),
           ("hostonly.build", "annotate \"host=only\" in hostonly/hosts.sml end\nannotate \"host=no\" in hostonly/rune.sml end\nhostonly/main.sml"),
           ("counted.sml", "structure C = struct val () = print \"once\\n\" val c = 1 end"),
           ("lib/counted.build", "counted.sml"),
           ("use-twice.build", "use lib/counted.build use lib/counted.build use-c.sml"),
           ("use-c.sml", "val () = print (Int.toString C.c ^ \"\\n\")"),
           ("prim.sml", "val ok = _prim \"rt_version\" : unit -> string"),
           ("prim.build", "prim.sml main.sml"),
           ("prim-allowed.build", "annotate \"allowPrim\" in prim.sml end a.sml b.sml main.sml"),
           ("vars.build", "$(VENDOR)/a.sml $(VENDOR)/b.sml main.sml"),
           ("bad.build", "annotate \"always\" in a.sml"), ("self.build", "use self.build"),
           (* a plan's text: a word a version 1 plan does not have *)
           ("edge.plan", "rune-plan 1\nbasis demand\nprogram\n  edge a.sml b.sml\nend\n"),
           (* one value of a variable serves every build file a build uses *)
           ("nested/part.build", "$(VENDOR)/a.sml"),
           ("vars-nested.build", "use nested/part.build $(VENDOR)/b.sml main.sml"),
           ("libs.build", "libraries json end a.sml b.sml main.sml"),
           ("demnad.build", "annotate \"demnad\" in a.sml end"),
           (* what a boundary hides stays hidden, by any way back to it *)
           ("boundary/x.sml", "structure Pub = struct val v = \"pub\" end\nstructure Priv = struct val v = \"private\" end"),
           ("boundary/x.build", "x.sml"),
           ("boundary/pub/library.build", "exports (structure Pub)\nuse ../x.build"),
           ("boundary/via.build", "use pub/library.build"),
           ("boundary/priv.sml", "val () = print (Priv.v ^ \"\\n\")"),
           ("boundary/pub.sml", "val () = print (Pub.v ^ \"\\n\")"),
           ("boundary/second.build", "use pub/library.build\nuse x.build\npub.sml"),
           ("boundary/second-hidden.build", "use pub/library.build\nuse x.build\npriv.sml"),
           ("boundary/across.build", "use via.build\nuse x.build\npriv.sml"),
           ("boundary/open.build", "use x.build\nuse pub/library.build\npriv.sml"),
           ("boundary/in/library.build", "exports (structure Pub)\nuse ../x.build use ../x.build ../priv.sml"),
           ("boundary/inside.build", "use in/library.build\npub.sml"),
           ("boundary/priv/library.build", "exports (structure Priv)\nuse ../x.build"),
           ("boundary/sibling.build", "use pub/library.build\nuse priv/library.build\npub.sml"),
           (* an export a replay answers: what the first use declared, through what it showed *)
           ("boundary/again/library.build", "exports (structure Pub)\nuse ../x.build"),
           ("boundary/replayed.build", "use pub/library.build\nuse again/library.build\npub.sml"),
           ("boundary/implements.build", "implements Foo = use x.build end\nuse x.build\npriv.sml"),
           ("boundary/nope/library.build", "exports (structure Nope, structure Pub)\nuse ../x.build"),
           ("boundary/nothing.build", "use nope/library.build\npub.sml"),
           ("boundary/nosig/library.build", "exports (signature NOPE, structure Pub)\nuse ../x.build"),
           ("boundary/signature-nothing.build", "use nosig/library.build\npub.sml"),
           (* a build file with a boundary of its own, which two libraries share *)
           ("boundary/shared.sml", "structure Shared = struct val s = \"shared\" end\nstructure Own = struct val v = \"own\" end"),
           ("boundary/shared/library.build", "exports (structure Shared)\n../shared.sml"),
           ("boundary/uses-shared.sml", "structure Other = struct val v = Shared.s end"),
           ("boundary/first.sml", "structure First = struct val v = Shared.s end"),
           ("boundary/shows.sml", "val () = print (First.v ^ \" \" ^ Other.v ^ \"\\n\")"),
           ("boundary/uses-own.sml", "val () = print Own.v"),
           ("boundary/first/library.build", "exports (structure First)\nuse ../shared/library.build ../first.sml"),
           ("boundary/other/library.build", "exports (structure Other)\nuse ../shared/library.build ../uses-shared.sml"),
           ("boundary/diamond.build", "use first/library.build\nuse other/library.build\nshows.sml"),
           ("boundary/diamond-hidden.build", "use first/library.build\nuse shared/library.build\nuses-own.sml"),
           (* a name of the Basis Library is no export, as MLton's build had CharArray, and a source that declares it makes it one *)
           ("boundary/lists.sml", "val () = print (Int.toString (List.length [Pub.v]) ^ \"\\n\")"),
           ("boundary/out/library.build", "exports (structure Pub, structure List)\nuse ../x.build ../lists.sml"),
           ("boundary/outside.build", "use out/library.build"),
           ("boundary/rebind.sml", "structure List = struct open List val mine = 7 end\nstructure Option = Option"),
           ("boundary/bound/library.build", "exports (structure List, structure Option)\n../rebind.sml"),
           ("boundary/rebound.sml", "val () = print (Int.toString List.mine ^ \" \" ^ Bool.toString (Option.isSome (SOME 1)) ^ \"\\n\")"),
           ("boundary/rebound.build", "use bound/library.build\nrebound.sml"),
           ("boundary/datatype.sml", "datatype t = A | B of int\nstructure Show = struct fun show A = \"A\" | show (B n) = \"B\" end"),
           ("boundary/replicate.sml", "datatype u = datatype t\nval () = print (Show.show (B 3) ^ \"\\n\")"),
           ("boundary/dt/library.build", "exports (type t, structure Show)\n../datatype.sml"),
           ("boundary/datatype.build", "use dt/library.build\nreplicate.sml"),
           ("boundary/abbreviation.sml", "type t = int"),
           ("boundary/abbreviated.sml", "val () = print (Int.toString (3 : t) ^ \"\\n\")"),
           ("boundary/abbr/library.build", "exports (type t)\n../abbreviation.sml"),
           ("boundary/abbreviation.build", "use abbr/library.build\nabbreviated.sml"),
           (* --typecheck-only keeps what a boundary exports *)
           ("exports/a.sml", "signature S = sig val x : int end\nfunctor F (X : S) = struct val y = X.x + 1 end\nstructure Z = F (struct val x = 1 end)"),
           ("exports/b.sml", "structure Q : S = struct val x = 2 end\nstructure R = F (Q)\nval () = print (Int.toString (R.y + Z.y) ^ \"\\n\")"),
           ("exports/all/library.build", "exports (signature S, functor F, structure Z)\n../a.sml"),
           ("exports/all.build", "use all/library.build\nb.sml"),
           ("exports/z/library.build", "exports (structure Z)\n../a.sml"),
           ("exports/hidden.build", "use z/library.build\nb.sml"),
           (* reaching into a library from outside it *)
           ("reach/lib/thing/library.build", "annotate \"demand\" in inner.sml end"),
           ("reach/lib/thing/inner.sml", "structure Inner = struct val x = 1 end"),
           ("reach/lib/thing/own.build", "inner.sml"),
           ("reach/uses.sml", "val () = print (Int.toString Inner.x ^ \"\\n\")"),
           ("reach/in.build", "lib/thing/inner.sml uses.sml"),
           ("reach/use.build", "use lib/thing/own.build uses.sml"),
           ("reach/plain.sml", "val () = print \"plain\\n\""),
           ("reach/out.build", "plain.sml"),
           ("reach/lib/gen/current.build", "use sets/abc/set.build"),
           ("reach/lib/gen/sets/abc/library.build", "annotate \"demand\" in set.sml end"),
           ("reach/lib/gen/sets/abc/set.build", "set.sml"),
           ("reach/lib/gen/sets/abc/set.sml", "structure Inner = struct val x = 2 end"),
           ("reach/pointer.build", "use lib/gen/current.build uses.sml"),
           (* selection, by what a file uses *)
           ("select/lib/m/library.build", "annotate \"demand\" in e.sml end"),
           ("select/lib/m/e.sml", "structure E = struct val () = print \"(initialiser of E ran)\\n\" val v = 5 end"),
           ("select/a.sml", "val f = fn F => F + 1 val () = print (Int.toString (f 1) ^ \"\\n\")"),
           ("select/b.sml", "val f = fn E => E + 1 val () = print (Int.toString (f 1) ^ \"\\n\")"),
           ("select/c.sml", "val f = fn x => x + 1 val () = print (Int.toString (f 1) ^ \"\\n\") (* E *)"),
           ("select/d.sml", "val f = fn x => x + 1 val () = print (Int.toString (f 1) ^ \"\\n\") val _ = {E = 1}"),
           ("select/uses.sml", "val () = print (Int.toString E.v ^ \"\\n\")"),
           ("select/a.build", "libraries m end\na.sml"),
           ("select/b.build", "libraries m end\nb.sml"),
           (* a file that does not parse under the initial basis's fixity keeps its tokens as its mentions *)
           ("select/fix.sml", "infix 5 ++\ndatatype t = ++ of int * int"),
           ("select/needs-fix.sml", "fun f (a ++ b) = E.v + a + b\nval () = print (Int.toString (f (1 ++ 2)) ^ \"\\n\")"),
           ("select/fix.build", "libraries m end\nfix.sml\nneeds-fix.sml"),
           (* nor one that parses in the fixity of the file before it: a label is no use *)
           ("select/fix-label.sml", "fun f (a ++ b) = a + b\nval _ = {E = 1}\nval () = print (Int.toString (f (1 ++ 2)) ^ \"\\n\")"),
           ("select/fix-label.build", "libraries m end\nfix.sml\nfix-label.sml"),
           (* but one whose fixity a library with no header gives is read by its tokens *)
           ("select/lib/ops/library.build", "annotate \"always\" in ops.sml end"),
           ("select/lib/ops/ops.sml", "infix 5 +++\ndatatype t = +++ of int * int"),
           ("select/ops-label.sml", "fun f (a +++ b) = a + b\nval _ = {E = 1}\nval () = print (Int.toString (f (1 +++ 2)) ^ \"\\n\")"),
           ("select/ops-label.build", "libraries m ops end\nops-label.sml")]
        val dir = #directory c
        fun copy source destination = write (destination, read source)
        val () = copy (dir ^ "/counted.sml") (dir ^ "/lib/counted.sml")
        val () = mkdirs (dir ^ "/vendor")
        val () = List.app (fn file => copy (dir ^ "/" ^ file) (dir ^ "/vendor/" ^ file)) ["a.sml", "b.sml"]
        val original = fromRoot "examples/virtual/bigint"
        val () = mkdirs (dir ^ "/bigint")
        val () = List.app (fn file => if isDir (original ^ "/" ^ file) then () else copy (original ^ "/" ^ file) (dir ^ "/bigint/" ^ file)) (entries original)
        val () = put c "bigint/none.build" "bigint_sig.sml bigint.sml main.sml"
        val () = put c "bigint/two.build" "bigint_sig.sml implements BigInt = intinf.sml end implements BigInt = digits.sml end bigint.sml main.sml"
        (* the virtual functor's example (the build-system roadmap's M21) *)
        val table = fromRoot "examples/virtual/table"
        val () = mkdirs (dir ^ "/table")
        val () = List.app (fn file => if isDir (table ^ "/" ^ file) then () else copy (table ^ "/" ^ file) (dir ^ "/table/" ^ file)) (entries table)
        val () = put c "table/none.build" "key_sig.sml table_sig.sml table.sml main.sml"
        val () = put c "table/two.build" "key_sig.sml table_sig.sml implements Table = list.sml end implements Table = tree.sml end table.sml main.sml"
        (* an implementation compiled against another KEY, which only it sees *)
        val () = put c "table/other_key.sml" "signature KEY = sig type t val compare : t * t -> order val toString : t -> string val hash : t -> int end"
        val () = put c "table/other.build" "key_sig.sml table_sig.sml implements Table = other_key.sml list.sml end table.sml main.sml"
        val () = put c "table/plugin-list.build" "key_sig.sml table_sig.sml list.sml"
        val () = put c "table/inline.build" "inline functor Table end\nkey_sig.sml table_sig.sml implements Table = list.sml end table.sml main.sml"
        val () = Posix.FileSys.symlink {old = fromRoot "lib/basis", new = dir ^ "/select/lib/basis"}
        val () = success (compiler c "select-index" "select" ["--lib", "lib", "--basis-index", "lib/m"])
        val () = success (compiler c "select-index-ops" "select" ["--lib", "lib", "--no-warnings", "--basis-index", "lib/ops"])
    in () end
  fun builds c label source flags expected =
    let val target = #directory c ^ "/" ^ source ^ ".rbc"
        val () = rmTree target
        val result = compiler c label "" (["--build", source ^ ".build", "--no-cache"] @ flags @ ["-o", source ^ ".rbc"])
        val () = success result
        val () = bytecode target
    in output (program c (label ^ "-run") "" [source ^ ".rbc"]) expected end
  fun buildRefused c source message =
    (rmTree (#directory c ^ "/" ^ source ^ ".rbc");
     refused (compiler c source "" ["--build", source ^ ".build", "--no-cache", "-o", source ^ ".rbc"]) message)
  (* Generated sources (docs/build.md, Generated sources; the build-system
     roadmap's D16), each scenario in a directory of its own: a step, whose
     tool is /bin/sh given tool.sh, which writes made.sml from spec.txt; and
     a preprocessor, which makes a line's @@ val. *)
  val stepTool = "n=$(cat \"$1\")\ncase \"$n\" in fail) exit 1 ;; none) exit 0 ;; esac\n"
                 ^ "printf 'structure Made = struct val n = %s end\\n' \"$n\" > \"$2\""
  fun stepFixture c dir =
    (rmTree (#directory c ^ "/" ^ dir);
     List.app (fn (file, text) => put c (dir ^ "/" ^ file) text)
       [("tool.sh", stepTool), ("spec.txt", "42"), ("main.sml", "val () = print (Int.toString Made.n ^ \"\\n\")"),
        ("gen.build", "generate /bin/sh (tool.sh, spec.txt, made.sml)\n  inputs tool.sh spec.txt end\n  outputs made.sml end\n"
                      ^ "made.sml main.sml")])
  fun stepBuild c dir label flags =
    compiler c label dir (["--build", "gen.build", "--cache-dir", "cache"] @ flags @ ["-o", "gen.rbc"])
  fun stepBuilds c dir label expected =
    (success (stepBuild c dir label []); output (program c (label ^ "-run") dir ["gen.rbc"]) expected)
  fun ppFixture c dir =
    (rmTree (#directory c ^ "/" ^ dir);
     List.app (fn (file, text) => put c (dir ^ "/" ^ file) text)
       [("filter.sh", "sed 's/^@@ /val /' \"$1\" > \"$2\""), ("pp.sml", "@@ n = 42"),
        ("use.sml", "val () = print (Int.toString n ^ \"\\n\")"),
        ("pp.build", "preprocessor at /bin/sh (filter.sh) inputs filter.sh end\nannotate \"preprocess=at\" in pp.sml end\nuse.sml")])
  val stepCases = ["generate", "generate-hand-edited", "generate-fails", "generate-unmade", "generate-plan", "generate-in-library",
                   "generate-plan-v1", "generate-no-outputs", "generate-twice", "generate-no-tool", "preprocess",
                   "preprocess-undeclared", "preprocess-twice", "preprocess-unmade", "preprocess-host",
                   "generate-closure", "generate-stamp", "generate-stamp-fails", "generate-stamp-plan", "generate-up-to-date",
                   "preprocess-up-to-date", "generate-output-dir"]
  (* A step that reads what it does not list as inputs, and says so: a plan
     whose files it reads (closure), and a stamp, a command whose output
     stands for what no file names; here state.txt, which the stamp prints
     and the tool reads. The tool notes each run in runs.txt *)
  fun readingFixture c dir build =
    (rmTree (#directory c ^ "/" ^ dir);
     List.app (fn (file, text) => put c (dir ^ "/" ^ file) text)
       [("tool.sh", "echo run >> runs.txt\nn=$(sed -n 's/.*val n = \\([0-9]*\\).*/\\1/p' spec.sml)\ns=$(cat state.txt)\n"
                    ^ "printf 'structure Made = struct val n = %s val s = \"%s\" end\\n' \"$n\" \"$s\" > \"$1\""),
        ("stamp.sh", "cat state.txt"), ("state.txt", "a"), ("spec.sml", "structure Spec = struct val n = 42 end"),
        ("spec.build", "spec.sml"),
        ("main.sml", "val () = print (Int.toString Made.n ^ Made.s ^ \"\\n\")"), ("gen.build", build)])
  fun readingBuild c dir label flags =
    compiler c label dir (["--units", "--build", "gen.build", "--cache-dir", "cache"] @ flags @ ["-o", "gen.rbc"])
  fun readingBuilds c dir label expected =
    (success (readingBuild c dir label []); output (program c (label ^ "-run") dir ["gen.rbc"]) expected)
  fun runsIn c dir = List.length (List.filter (fn l => l <> "") (lines (read (#directory c ^ "/" ^ dir ^ "/runs.txt"))))
  fun planOf c dir name =
    let val r = compiler c (dir ^ "-" ^ name ^ "-plan") dir ["--plan", name ^ ".build"]
    in success r; put c (dir ^ "/" ^ name ^ ".plan") (#output r) end
  fun pause () = OS.Process.sleep (Time.fromSeconds 3)
  fun generated c which =
    case which of
      "generate-output-dir" =>
        (* an output's directory is made before its step runs, as in a fresh
           checkout, which has no build/ for build/config.sml *)
        (rmTree (#directory c ^ "/outdir");
         List.app (fn (file, text) => put c ("outdir/" ^ file) text)
           [("tool.sh", stepTool), ("spec.txt", "42"), ("main.sml", "val () = print (Int.toString Made.n ^ \"\\n\")"),
            ("gen.build", "generate /bin/sh (tool.sh, spec.txt, out/made.sml)\n  inputs tool.sh spec.txt end\n"
                          ^ "  outputs out/made.sml end\nout/made.sml main.sml")];
         success (stepBuild c "outdir" "outdir" []);
         output (program c "outdir-run" "outdir" ["gen.rbc"]) "42\n")
    | "generate-closure" =>
        (* a file the closure's plan names, not an input, makes the step due;
           so does the plan; nothing else does *)
        let
          val build = "generate /bin/sh (tool.sh, made.sml) inputs tool.sh end closure spec.plan outputs made.sml end\nmade.sml main.sml"
          val () = readingFixture c "closure" build
          val () = planOf c "closure" "spec"
          val () = readingBuilds c "closure" "closure-cold" "42a\n"
          val again = readingBuild c "closure" "closure-again" ["--explain-rebuild"]
          val () = success again
          val () = need (String.isSubstring "is up to date" (#errors again), "a step whose closure did not change ran again: " ^ #errors again)
          val () = put c "closure/spec.sml" "structure Spec = struct val n = 7 end"
          val () = readingBuilds c "closure" "closure-edited" "7a\n"
          val () = put c "closure/spec.plan" (read (#directory c ^ "/closure/spec.plan") ^ "\n")
          val r = readingBuild c "closure" "closure-plan" ["--explain-rebuild"]
        in
          success r; need (String.isSubstring "running the step" (#errors r), "an edit of the closure's plan did not run the step: " ^ #errors r)
        end
    | "generate-stamp" =>
        (* what the stamp prints is in the key: an edit of state.txt, which no
           input names, makes the step due, an up-to-date build's included,
           and a build without the cache agrees *)
        let
          val build = "generate /bin/sh (tool.sh, made.sml) inputs tool.sh spec.sml end stamp /bin/sh (stamp.sh) outputs made.sml end\nmade.sml main.sml"
          val () = readingFixture c "stamp" build
          val () = readingBuilds c "stamp" "stamp-cold" "42a\n"
          val () = pause ()
          val () = readingBuilds c "stamp" "stamp-noop" "42a\n"
          val () = need (runsIn c "stamp" = 1, "an up-to-date build ran its step")
          val () = put c "stamp/state.txt" "b"
          val () = readingBuilds c "stamp" "stamp-edited" "42b\n"
          val () = need (runsIn c "stamp" = 2, "a stamp that answers otherwise did not run its step")
          val () = success (compiler c "stamp-cold2" "stamp" ["--units", "--build", "gen.build", "--no-cache", "-o", "cold.rbc"])
          val dir = #directory c ^ "/stamp/"
        in need (read (dir ^ "gen.rbc") = read (dir ^ "cold.rbc"), "a build after a stamp's answer changed is not the cold build") end
    | "generate-stamp-fails" =>
        (readingFixture c "stampfails" "generate /bin/sh (tool.sh, made.sml) stamp /bin/sh (stamp.sh) outputs made.sml end\nmade.sml main.sml";
         put c "stampfails/stamp.sh" "exit 3";
         refused (readingBuild c "stampfails" "stampfails" []) "the stamp /bin/sh stamp.sh failed")
    | "generate-stamp-plan" =>
        (* --plan prints a closure and a stamp, which read back *)
        let
          val () = readingFixture c "stampplan" ("generate /bin/sh (tool.sh, made.sml) inputs tool.sh end closure spec.plan "
                                                 ^ "stamp /bin/sh (stamp.sh, \"two words\") outputs made.sml end\nmade.sml main.sml")
          val r = compiler c "stampplan" "stampplan" ["--plan", "gen.build"]
          val () = success r
          val step = "\ngenerate /bin/sh .\n  argument tool.sh\n  argument made.sml\n  reads tool.sh\n  closure spec.plan\n"
                     ^ "  stamp /bin/sh stamp.sh two%20words\n  writes made.sml\nend\n"
          val () = need (String.isSubstring step (#output r), "the plan of a step with a closure and a stamp: " ^ #output r)
          val () = write (#directory c ^ "/stampplan/gen.plan", #output r)
          val () = output (compiler c "stampplan-again" "stampplan" ["--plan", "gen.plan"]) (#output r)
          val h = execute c "stampplan-host" "stampplan" ["/bin/sh", fromRoot "scripts/plan-files.sh", "gen.plan"]
        in output h "made.sml\nmain.sml\n" end
    | "generate-up-to-date" =>
        (* an up-to-date build runs no step; one with a step that says
           nothing of what it reads is never up to date, and runs it *)
        let
          val () = readingFixture c "uptodate" "generate /bin/sh (tool.sh, made.sml) inputs tool.sh spec.sml state.txt end outputs made.sml end\nmade.sml main.sml"
          val () = readingBuilds c "uptodate" "uptodate-cold" "42a\n"
          val () = pause ()
          val () = readingBuilds c "uptodate" "uptodate-noop" "42a\n"
          val () = need (runsIn c "uptodate" = 1, "an up-to-date build ran its step")
          val () = readingFixture c "always" "generate /bin/sh (tool.sh, made.sml) outputs made.sml end\nmade.sml main.sml"
          val () = readingBuilds c "always" "always-cold" "42a\n"
          val () = pause ()
          val () = readingBuilds c "always" "always-again" "42a\n"
        in need (runsIn c "always" = 2, "a step that says nothing of what it reads did not run on every build") end
    | "preprocess-up-to-date" =>
        (* a preprocessed build is up to date where nothing changed, and an
           edit of the tool's input, of the file or of the tool is seen, warm
           as cold *)
        let
          val () = ppFixture c "ppup"
          val dir = #directory c ^ "/ppup/"
          fun warm (label, expected) =
            (success (compiler c label "ppup" ["--units", "--build", "pp.build", "--cache-dir", "cache", "-o", "w.rbc"]);
             success (compiler c (label ^ "-cold") "ppup" ["--units", "--build", "pp.build", "--no-cache", "-o", "n.rbc"]);
             need (read (dir ^ "w.rbc") = read (dir ^ "n.rbc"), label ^ ": the warm build is not the cold one");
             output (program c (label ^ "-run") "ppup" ["w.rbc"]) expected)
          val () = warm ("ppup-cold", "42\n")
          val () = pause ()
          val () = warm ("ppup-noop", "42\n")
          val () = put c "ppup/pp.sml" "@@ n = 43"
          val () = warm ("ppup-file", "43\n")
          val () = put c "ppup/filter.sh" "sed 's/^@@ n = \\([0-9]*\\)/val n = 1\\1/' \"$1\" > \"$2\""
          val () = warm ("ppup-tool", "143\n")
          val () = pause ()
        in warm ("ppup-settled", "143\n") end
    | "generate" =>
        (* the step runs before a unit is read, and again when an input changes, and not when none does *)
        (stepFixture c "gen";
         stepBuilds c "gen" "generate-cold" "42\n";
         let val r = stepBuild c "gen" "generate-warm" ["--explain-rebuild"]
         in success r; need (String.isSubstring "is up to date" (#errors r), "a step whose inputs did not change ran again: " ^ #errors r) end;
         put c "gen/spec.txt" "7";
         stepBuilds c "gen" "generate-edited" "7\n")
    | "generate-hand-edited" =>
        (* an output that is not what the step made is refused; removed, it is made again *)
        (stepFixture c "edited";
         stepBuilds c "edited" "edited-cold" "42\n";
         put c "edited/made.sml" "structure Made = struct val n = 0 end";
         refused (stepBuild c "edited" "edited-refused" []) "made.sml is not what the step /bin/sh tool.sh spec.txt made.sml made";
         OS.FileSys.remove (#directory c ^ "/edited/made.sml");
         stepBuilds c "edited" "edited-again" "42\n")
    | "generate-fails" =>
        (* a step that fails stops the build, and the stale output it left is not compiled *)
        (stepFixture c "fails";
         stepBuilds c "fails" "fails-cold" "42\n";
         put c "fails/spec.txt" "fail";
         refused (stepBuild c "fails" "fails-refused" []) "failed, and what it makes is not compiled")
    | "generate-unmade" =>
        (stepFixture c "unmade";
         put c "unmade/spec.txt" "none";
         refused (stepBuild c "unmade" "unmade-refused" []) "did not make made.sml, which it says it makes")
    | "generate-plan" =>
        (* --plan prints a step and runs nothing, as a plan of version 2, which reads back *)
        let
          val () = stepFixture c "plan"
          val r = compiler c "plan" "plan" ["--plan", "gen.build"]
          val () = success r
          val step = "\ngenerate /bin/sh .\n  argument tool.sh\n  argument spec.txt\n  argument made.sml\n  reads tool.sh\n"
                     ^ "  reads spec.txt\n  writes made.sml\nend\n"
          val () = need (String.isPrefix "rune-plan 2\n" (#output r) andalso String.isSubstring step (#output r),
                         "the plan of a step: " ^ #output r)
          val () = need (not (exists (#directory c ^ "/plan/made.sml")), "--plan ran a step")
          val () = write (#directory c ^ "/plan/gen.plan", #output r)
        in output (compiler c "plan-again" "plan" ["--plan", "gen.plan"]) (#output r) end
    | "generate-in-library" =>
        (put c "steplib/library.build" "exports (structure Made)\ngenerate /bin/sh (tool.sh) outputs made.sml end\nmade.sml";
         refused (compiler c which "" ["--plan", "steplib/library.build"]) "a library's build file declares no step")
    | "generate-plan-v1" =>
        (put c "v1.plan" "rune-plan 1\nbasis demand\ngenerate /bin/sh .\n  writes a.sml\nend\nprogram\nend";
         refused (compiler c which "" ["--plan", "v1.plan"]) "a plan of version 1 has no generate")
    | "generate-no-outputs" =>
        (put c "nooutputs.build" "generate /bin/sh (tool.sh) inputs tool.sh end\nmain.sml";
         refused (compiler c which "" ["--plan", "nooutputs.build"]) "expected outputs, found main.sml")
    | "generate-twice" =>
        (* a file is made by one step at most *)
        (put c "twice.build" "generate /bin/sh (a.sh) outputs made.sml end\ngenerate /bin/sh (b.sh) outputs made.sml end\nmain.sml";
         refused (compiler c which "" ["--plan", "twice.build"]) "two steps make made.sml")
    | "generate-no-tool" =>
        (* a tool is a file, whose bytes are in the step's key *)
        (put c "notool/gen.build" "generate no-such-tool (x) outputs made.sml end\nmain.sml";
         put c "notool/main.sml" "val () = ()";
         refused (compiler c which "notool" ["--build", "gen.build", "--no-cache", "-o", "gen.rbc"]) "no tool no-such-tool")
    | "preprocess-twice" =>
        (* a name is one preprocessor's *)
        (put c "pptwice.build" "preprocessor p /bin/sh (a.sh)\npreprocessor p /bin/sh (b.sh)\nmain.sml";
         refused (compiler c which "" ["--plan", "pptwice.build"]) "a second preprocessor p, not the first")
    | "preprocess" =>
        (* a file's preprocessor makes what its unit compiles; a build after an
           edit of the file is the build of what the edit makes of it, warm as
           cold (S41), and a file not edited is not given to the tool again *)
        let
          val () = ppFixture c "pp"
          fun built (label, flags) = success (compiler c label "pp" (["--build", "pp.build"] @ flags @ ["-o", label ^ ".rbc"]))
          val () = built ("warm1", ["--cache-dir", "cache"])
          val () = output (program c "warm1-run" "pp" ["warm1.rbc"]) "42\n"
          val again = compiler c "warm1-again" "pp" ["--build", "pp.build", "--cache-dir", "cache", "--explain-rebuild", "-o", "again.rbc"]
          val () = success again
          val () = need (not (String.isSubstring "preprocessed" (#errors again)), "a file not edited was preprocessed again: " ^ #errors again)
          val () = put c "pp/pp.sml" "@@ n = 43"
          val () = built ("warm2", ["--cache-dir", "cache"])
          val () = built ("cold2", ["--no-cache"])
          (* and -j changes no byte (S58): a child is forked with the outputs *)
          val () = built ("parallel2", ["--cache-dir", "cache-j", "-j", "2"])
          val dir = #directory c ^ "/pp/"
        in
          need (read (dir ^ "warm2.rbc") = read (dir ^ "cold2.rbc"), "a build after an edit of a preprocessed file is not the cold build");
          need (read (dir ^ "parallel2.rbc") = read (dir ^ "cold2.rbc"), "a preprocessed build with -j is not the build without");
          output (program c "warm2-run" "pp" ["warm2.rbc"]) "43\n"
        end
    | "preprocess-undeclared" =>
        (put c "ppnone.build" "annotate \"preprocess=none\" in a.sml end";
         refused (compiler c which "" ["--plan", "ppnone.build"]) "a.sml is put in the preprocessor none, which no build file of it declares")
    | "preprocess-unmade" =>
        (* a tool that writes nothing has made nothing, which is not compiled
           as an empty file *)
        (put c "ppunmade/pp.build" "preprocessor none /bin/sh (true.sh)\nannotate \"preprocess=none\" in a.sml end";
         put c "ppunmade/true.sh" "exit 0";
         put c "ppunmade/a.sml" "val () = ()";
         refused (compiler c which "ppunmade" ["--build", "pp.build", "--no-cache", "-o", "pp.rbc"]) "made nothing of a.sml")
    | "preprocess-host" =>
        (* a host has no preprocessor: what it would read of the plan, it refuses *)
        let
          val () = ppFixture c "pphost"
          val r = compiler c "pphost-plan" "pphost" ["--plan", "pp.build"]
          val () = success r
          val () = write (#directory c ^ "/pphost/pp.plan", #output r)
          val h = execute c "pphost-host" "pphost" ["/bin/sh", fromRoot "scripts/plan-files.sh", "pp.plan"]
        in
          need (#status h <> 0 andalso #output h = "" andalso String.isSubstring "a file a host cannot compile" (#errors h),
                "a host read a plan with a preprocessed file: " ^ #output h ^ #errors h)
        end
    | _ => raise Failed "unknown buildfile scenario"
  fun build c which () =
    case which of
      "list" => builds c which "list" [] "42\n"
    | "boundary" => builds c which "boundary-used" [] "42\n"
    | "boundary-hidden" => buildRefused c which "unbound variable or constructor: A.x"
    | "no-group" => buildRefused c which "the build language has no group"
    | "no-local" => buildRefused c which "the build language has no local"
    | "no-cache" => buildRefused c which "the build language has no cache"
    | "no-program-boundary" => buildRefused c "no-boundary" "a library's boundary belongs in its library.build"
    | "library-outside-boundary" => buildRefused c "outside/library" "all source files belong inside the library export boundary"
    | "host-only" =>
        (builds c which "hostonly" [] "rune\n";
         output (compiler c (which ^ "-deps") "" ["--deps", "--build", "hostonly.build"]) "hostonly/rune.sml\nhostonly/main.sml\n")
    | "use-twice" => builds c which "use-twice" [] "once\n1\n"
    | "prim" => buildRefused c which "_prim"
    | "prim-allowed" => builds c which "prim-allowed" [] "42\n"
    | "path-variable" => builds c which "vars" ["--path", "VENDOR=vendor"] "42\n"
    | "missing-variable" => buildRefused c "vars" "no path variable VENDOR"
    | "path-variable-nested" => builds c which "vars-nested" ["--path", "VENDOR=vendor"] "42\n"
    | "build-list" => output (compiler c which "" ["--build-list", "list.build"]) "a.sml\nb.sml\nmain.sml\n"
    | "include-with-build" =>
        refused (compiler c which "" ["--build", "list.build", "-I", "vendor", "-o", "list.rbc"])
                "-I wants an entry point, and a build file says its own files"
    | "plan-command-line" =>
        (* the command line is a plan too, which --plan prints as a build file's *)
        let val r = compiler c which "" ["--plan", "--library", "json", "a.sml", "b.sml"]
            val () = success r
            val words = List.map (String.tokens Char.isSpace) (lines (#output r))
            fun has l = List.exists (fn w => w = l) words
            val json = List.exists (fn "library" :: "json" :: _ => true | _ => false) words
        in need (json andalso has ["program"] andalso has ["requires", "json"] andalso has ["basis", "demand"]
                 andalso has ["unit", "a.sml", "a.sml", "ascii"] andalso has ["unit", "b.sml", "b.sml", "ascii"],
                 "the plan of a command line: " ^ #output r)
        end
    | "plan-refused" => refused (compiler c which "" ["--plan", "edge.plan"]) "a plan of version 1 has no step edge"
    | "build-list-closure" =>
        let val r = compiler c which "" ["--build-list", "libs.build"]
            val () = success r
        in case List.rev (lines (#output r)) of
             (* json is written on unicode, which comes before it *)
             main :: b :: a :: json :: json_sig :: security :: _ =>
               need (String.isSuffix "lib/json/json_sig.sml" json_sig andalso String.isSuffix "lib/json/json.sml" json
                     andalso String.isSuffix "lib/unicode/security.sml" security
                     andalso [a, b, main] = ["a.sml", "b.sml", "main.sml"], "the closure's files are not those of the build: " ^ #output r)
           | _ => raise Failed ("the closure of a build differs: " ^ #output r)
        end
    | "unknown-annotation" => buildRefused c "demnad" "unknown annotation \"demnad\""
    | "use-through-boundary" => builds c which "boundary/second" [] "pub\n"
    | "use-through-boundary-hidden" => buildRefused c "boundary/second-hidden" "unbound variable or constructor: Priv.v"
    | "use-across-builds" => buildRefused c "boundary/across" "unbound variable or constructor: Priv.v"
    | "use-diamond" => builds c which "boundary/diamond" [] "shared shared\n"
    | "use-diamond-hidden" => buildRefused c "boundary/diamond-hidden" "unbound variable or constructor: Own.v"
    | "use-first-open" => builds c which "boundary/open" [] "private\n"
    | "use-inside-boundary" => builds c which "boundary/inside" [] "private\npub\n"
    | "use-sibling-boundary" => buildRefused c "boundary/sibling" "exports structure Priv, which no source declares"
    | "use-replayed-export" => builds c which "boundary/replayed" [] "pub\n"
    | "use-after-implements" => buildRefused c "boundary/implements" "unbound variable or constructor: Priv.v"
    | "export-nothing" => buildRefused c "boundary/nothing" "exports structure Nope, which no source declares"
    | "export-no-signature" => buildRefused c "boundary/signature-nothing" "exports signature NOPE, which no source declares"
    | "export-from-outside" => buildRefused c "boundary/outside" "exports structure List, which no source declares"
    | "export-rebound" =>
        (* the same, cold and through the cache, where only a unit's own record says it declares Option *)
        let fun twice label =
              (success (compiler c (which ^ "-" ^ label) "boundary" ["--build", "rebound.build", "--cache-dir", "rebound-cache", "-o", "rebound.rbc"]);
               output (program c (which ^ "-run-" ^ label) "boundary" ["rebound.rbc"]) "7 true\n")
        in twice "cold"; twice "warm" end
    | "export-datatype" => buildRefused c "boundary/datatype" "exports type t, which is a datatype"
    | "export-abbreviation" => builds c which "boundary/abbreviation" [] "3\n"
    | "typecheck-exports" =>
        (output (compiler c which "" ["--build", "exports/all.build", "--typecheck-only", "--no-cache", "--no-warnings"]) "";
         refused (compiler c (which ^ "-hidden") "" ["--build", "exports/hidden.build", "--typecheck-only", "--no-cache"])
                 "unbound signature: S")
    | "reach-in" =>
        let fun warns build library files =
              let val r = compiler c (which ^ "-" ^ build) "reach" ["--build", build ^ ".build", "--no-cache", "-o", build ^ ".rbc"]
                  val () = success r
              in need (String.isSubstring (build ^ ".build: warning: this build reaches into the library " ^ library
                                           ^ " (" ^ files ^ ")") (#errors r),
                       "no warning of reaching in: " ^ #errors r) end
            val quiet = compiler c (which ^ "-quiet") "reach"
                                 ["--build", "in.build", "--no-cache", "--no-warnings", "-o", "quiet.rbc"]
        in warns "in" "lib/thing" "1 path";
           warns "use" "lib/thing" "1 path";
           output quiet "";
           output (compiler c (which ^ "-out") "reach" ["--build", "out.build", "--no-cache", "-o", "out.rbc"]) ""
        end
    | "reach-in-pointer" =>
        output (compiler c which "reach" ["--build", "pointer.build", "--no-cache", "-o", "pointer.rbc"]) ""
    | "selection-by-uses" =>
        let fun selected name flags sources expected =
              let val () = success (compiler c ("select-" ^ name) "select" (["--lib", "lib", "--no-warnings"] @ flags @ ["-o", name ^ ".rbc"] @ sources))
              in output (program c ("select-" ^ name ^ "-run") "select" [name ^ ".rbc"]) expected end
            val library = ["--library", "m"]
        in
          (* a name no structure is: not a bound variable, a comment or a label *)
          List.app (fn name => selected name library [name ^ ".sml"] "2\n") ["a", "b", "c", "d"];
          selected "ab" ["--no-cache", "--build", "a.build"] [] "2\n";
          selected "bb" ["--no-cache", "--build", "b.build"] [] "2\n";
          (* a name used is *)
          selected "uses" library ["uses.sml"] "(initialiser of E ran)\n5\n";
          (* a file that needs the fixity of the file before it is read in it *)
          selected "fix" ["--no-cache", "--build", "fix.build"] [] "(initialiser of E ran)\n8\n";
          selected "fix-label" ["--no-cache", "--build", "fix-label.build"] [] "3\n";
          (* and one that needs what a library with no header leaves, by its tokens *)
          selected "ops-label" ["--no-cache", "--build", "ops-label.build"] [] "(initialiser of E ran)\n3\n"
        end
    | "install-no-basis" =>
        let val dir = #directory c ^ "/installroot"
            val () = rmTree dir
            val () = List.app (fn file => (mkdirs (OS.Path.dir (dir ^ "/" ^ file)); write (dir ^ "/" ^ file, "")))
                              ["bin/runevm-stack", "bin/runevm", "bin/rune.rbc", "build/gmp/native-build.json"]
            val () = mkdirs (dir ^ "/scripts")
            val () = write (dir ^ "/scripts/install.sh", read (fromRoot "scripts/install.sh"))
            val r = execute c which "" ["sh", dir ^ "/scripts/install.sh", "--prefix", dir ^ "/prefix"]
        in refused r "lib/basis/MANIFEST"; need (not (exists (dir ^ "/prefix/bin/rune")), "installed with no Basis") end
    | "clean-overlay" =>
        let val dir = #directory c ^ "/cleanroot"
            val () = rmTree dir
            fun plant file = (mkdirs (OS.Path.dir (dir ^ "/" ^ file)); write (dir ^ "/" ^ file, ""))
            val gone = [".rune/x", "src/lsp/.rune/x"]
            val kept = ["lib/cache/made", "corpus/mlton/.rune/x", ".worktrees/other/.rune/x"]
            val () = List.app plant (gone @ kept)
            val () = write (dir ^ "/Makefile", read (fromRoot "Makefile"))
            val r = execute c which "cleanroot" ["make", "--no-print-directory", "clean"]
            val () = success r
        in need (not (List.exists (fn file => exists (dir ^ "/" ^ file)) gone), "make clean left a cache");
           need (List.all (fn file => exists (dir ^ "/" ^ file)) kept, "make clean took what is not its own") end
    | "virtual-intinf" => builds c which "bigint/intinf" [] factorial
    | "virtual-digits" => builds c which "bigint/digits" [] factorial
    | "virtual-cache" =>
        let val dir = #directory c
            val () = rmTree (dir ^ "/vcache")
            val first = compiler c "virtual-cache-first" "" ["--build", "bigint/intinf.build", "--cache-dir", "vcache", "-o", "vcache1.rbc"]
            val () = success first
            val second = compiler c "virtual-cache-second" "" ["--build", "bigint/digits.build", "--cache-dir", "vcache", "--explain-rebuild", "-o", "vcache2.rbc"]
            val () = success second
            val compiled = List.filter (String.isPrefix "bigint/") (rebuilt (#errors second))
            val () = need (compiled = ["bigint/digits.sml"], "switching virtual implementation rebuilt an unrelated unit")
            val () = bytecode (dir ^ "/vcache2.rbc")
        in output (program c "virtual-cache-run" "" ["vcache2.rbc"]) factorial end
    | "virtual-whole" =>
        let val target = #directory c ^ "/vwhole.rbc"
            val () = rmTree target
            val result = compiler c which "" ["--build", "bigint/digits.build", "--whole", "-o", "vwhole.rbc"]
        in success result; bytecode target; output (program c (which ^ "-run") "" ["vwhole.rbc"]) factorial end
    | "virtual-none" =>
        let val target = #directory c ^ "/vnone.rbc"
            val () = rmTree target
            val compiled = compiler c which "" ["--build", "bigint/none.build", "--no-cache", "-o", "vnone.rbc"]
            val () = success compiled
            val () = bytecode target
            val result = program c (which ^ "-run") "" ["vnone.rbc"]
        in need ((#status result = 1 orelse #status result = 2) andalso
                 String.isSubstring "virtual module BigInt has no implementation" (#output result ^ #errors result),
                 "unimplemented virtual module was not rejected") end
    | "virtual-two" => buildRefused c "bigint/two" "two implementations"
    (* a virtual functor (examples/virtual/table; the build-system roadmap's
       M21): each implementation alike *)
    | "virtual-table-list" => builds c which "table/list" [] tableOutput
    | "virtual-table-tree" => builds c which "table/tree" [] tableOutput
    (* the second implementation through the first one's cache compiles it
       alone: nothing of the first reached a client *)
    | "virtual-table-cache" =>
        let val dir = #directory c
            val () = rmTree (dir ^ "/tcache")
            val first = compiler c "virtual-table-cache-first" "" ["--build", "table/list.build", "--cache-dir", "tcache", "-o", "tcache1.rbc"]
            val () = success first
            val second = compiler c "virtual-table-cache-second" "" ["--build", "table/tree.build", "--cache-dir", "tcache", "--explain-rebuild",
                                                                       "-o", "tcache2.rbc"]
            val () = success second
            val compiled = List.filter (String.isPrefix "table/") (rebuilt (#errors second))
            val () = need (compiled = ["table/tree.sml"], "another implementation of the virtual functor compiled more than itself: "
                                                         ^ String.concatWith " " compiled)
            val () = bytecode (dir ^ "/tcache2.rbc")
        in output (program c "virtual-table-cache-run" "" ["tcache2.rbc"]) tableOutput end
    (* each implementation through --units --whole: the bytes of a compile
       of the same files whole (S42), and the same output *)
    | "virtual-table-whole" =>
        List.app (fn b =>
                    let
                      val dir = #directory c
                      val files = List.map (fn f => "table/" ^ f)
                                           (case b of "list" => ["key_sig.sml", "table_sig.sml", "list.sml", "table.sml", "main.sml"]
                                                    | _ => ["key_sig.sml", "table_sig.sml", "tree.sml", "table.sml", "main.sml"])
                      val () = List.app (fn f => rmTree (dir ^ "/" ^ f)) ["twhole.rbc", "tunits.rbc"]
                      val () = success (compiler c (which ^ "-" ^ b) "" ["--build", "table/" ^ b ^ ".build", "--whole", "-o", "tunits.rbc"])
                      val () = success (compiler c (which ^ "-" ^ b ^ "-files") "" (["--no-cache"] @ files @ ["-o", "twhole.rbc"]))
                    in
                      need (same (dir ^ "/tunits.rbc", dir ^ "/twhole.rbc"), "S42: --units --whole differs from whole, with " ^ b);
                      output (program c (which ^ "-" ^ b ^ "-run") "" ["tunits.rbc"]) tableOutput
                    end)
                 ["list", "tree"]
    (* compiled with no implementation, and refused when the declaration runs *)
    | "virtual-table-none" =>
        let val target = #directory c ^ "/tnone.rbc"
            val () = rmTree target
            val () = success (compiler c which "" ["--build", "table/none.build", "--no-cache", "-o", "tnone.rbc"])
            val () = bytecode target
            val result = program c (which ^ "-run") "" ["tnone.rbc"]
        in need (#status result = 1 andalso #output result = ""
                 andalso String.isSubstring "Mismatch \"the virtual functor Table has no implementation" (#errors result),
                 "a virtual functor with no implementation was not refused: " ^ #errors result) end
    | "virtual-table-two" => buildRefused c "table/two" "two implementations"
    (* a virtual functor has no body for its applications to copy *)
    | "virtual-table-inline" => buildRefused c "table/inline" "functor Table is virtual: it has no body for its applications to copy"
    (* an implementation of another parameter's signature, refused at link *)
    | "virtual-table-other" =>
        let val target = #directory c ^ "/tother.rbc"
            val () = rmTree target
            val () = success (compiler c which "" ["--build", "table/other.build", "--no-cache", "-o", "tother.rbc"])
            val result = program c (which ^ "-run") "" ["tother.rbc"]
        in need (#status result = 1 andalso #output result = ""
                 andalso String.isSubstring "the implementation of the virtual functor Table implements another signature" (#errors result),
                 "an implementation of another signature was not refused: " ^ #errors result) end
    (* the _dynamic variant: the client compiled with no implementation, each
       implementation a plugin, its unit emitted on its own *)
    | "virtual-table-plugin" =>
        let
          val dir = #directory c ^ "/table"
          val () = rmTree (dir ^ "/dynamic.rbc")
          val () = success (compiler c (which ^ "-client") "table" ["--build", "dynamic.build", "--no-cache", "-o", "dynamic.rbc"])
          fun plugin (build, unit) =
            let
              val () = rmTree (dir ^ "/plugin")
              val () = success (compiler c (which ^ "-" ^ unit) "table" ["--build", build, "--no-cache", "--emit-units", "plugin",
                                                                          "-o", "plugin.rbc"])
              (* the program's unit of that name, after the Basis's (list.sml) *)
              val file = case List.rev (List.filter (String.isSuffix ("-" ^ unit ^ ".rbu")) (lines (read (dir ^ "/plugin/units")))) of
                           f :: _ => if OS.Path.isAbsolute f then f else dir ^ "/" ^ f
                         | [] => raise Failed ("the plugin's units list has no unit of " ^ unit)
              val input = BinIO.openIn file
              val bytes = BinIO.inputAll input before BinIO.closeIn input
              val out = BinIO.openOut (dir ^ "/table.rbu")
              val () = (BinIO.output (out, bytes); BinIO.closeOut out)
            in output (program c (which ^ "-" ^ unit ^ "-run") "table" ["dynamic.rbc"]) tableOutput end
        in plugin ("plugin.build", "tree"); plugin ("plugin-list.build", "list") end
    | "virtual-table-whole-refused" =>
        refused (compiler c which "table" ["--build", "dynamic.build", "--whole", "-o", "dwhole.rbc"]) "is built in units (rune --units)"
    | "bad" => buildRefused c "bad" "unexpected end of the file"
    | "self" => buildRefused c "self" "uses itself"
    | _ => generated c which
  val buildCases = ["list", "boundary", "boundary-hidden", "no-group", "no-local", "no-cache", "no-program-boundary", "library-outside-boundary", "host-only",
                    "use-twice", "prim", "prim-allowed",
                    "path-variable", "missing-variable", "path-variable-nested", "build-list", "include-with-build", "plan-command-line",
                    "plan-refused", "build-list-closure", "unknown-annotation",
                    "use-through-boundary", "use-through-boundary-hidden", "use-across-builds", "use-diamond", "use-diamond-hidden", "use-first-open", "use-inside-boundary",
                    "use-sibling-boundary", "use-replayed-export", "use-after-implements", "export-nothing",
                    "export-no-signature", "export-from-outside", "export-rebound", "export-datatype", "export-abbreviation", "typecheck-exports", "reach-in", "reach-in-pointer",
                    "selection-by-uses", "install-no-basis", "clean-overlay",
                    "virtual-intinf", "virtual-digits", "virtual-cache", "virtual-whole", "virtual-none", "virtual-two",
                    "virtual-table-list", "virtual-table-tree", "virtual-table-cache", "virtual-table-whole", "virtual-table-none",
                    "virtual-table-two", "virtual-table-inline", "virtual-table-other", "virtual-table-plugin", "virtual-table-whole-refused", "bad", "self"]
                   @ stepCases
  fun copy source destination =
    let val input = BinIO.openIn source
        val output = BinIO.openOut destination
        fun loop () = let val bytes = BinIO.inputN (input, 65536)
                      in if Word8Vector.length bytes = 0 then () else (BinIO.output (output, bytes); loop ()) end
        fun close () = (BinIO.closeIn input; BinIO.closeOut output)
    in (loop (); close ()) handle e => (close (); raise e) end
  fun emit c name sources =
    let val dir = #directory c
        val () = rmTree (dir ^ "/" ^ name ^ ".units")
        val () = rmTree (dir ^ "/" ^ name ^ ".rbu")
        val result = compiler c (name ^ "-module") "" (["--units", "--no-cache", "--emit-units", name ^ ".units"]
                                                    @ sources @ ["-o", name ^ ".whole.rbc"])
        val () = success result
        val unitList = dir ^ "/" ^ name ^ ".units/units"
        val () = need (exists unitList, "module compiler published no unit list")
        val suffix = "-" ^ OS.Path.base (OS.Path.file (List.last sources)) ^ ".rbu"
        val files = List.filter (String.isSuffix suffix) (lines (read unitList))
        val unit = case files of [file] => if OS.Path.isAbsolute file then file else dir ^ "/" ^ file
                             | _ => raise Failed "module compiler published an ambiguous entry unit"
    in bytecode unit; copy unit (dir ^ "/" ^ name ^ ".rbu") end
  val shape = "signature SHAPE =\nsig\n  type t\n  datatype kind = Round | Square of int\n  exception Bad of int\n"
      ^ "  val make : int -> t\n  val area : t -> int\n  val kindOf : t -> kind\n  val name : string\n  val twice : 'a -> 'a * 'a\nend"
  val implementation = "_export structure Impl : SHAPE =\nstruct\n  datatype kind = Square of int | Round\n"
      ^ "  type t = int * kind\n  exception Bad of int\n  fun make n = if n < 0 then raise Bad n else (n, if n > 5 then Round else Square n)\n"
      ^ "  fun area (n, _) = n * n\n  fun kindOf (_, k) = k\n  val name = \"impl\"\n  fun twice x = (x, x)\nend"
  val client = "structure S = _dynamic \"impl.rbu\" : SHAPE\nfun kind k = case k of S.Round => \"round\" | S.Square n => \"square \" ^ Int.toString n\n"
      ^ "val () = print (S.name ^ \" \" ^ Int.toString (S.area (S.make 3)) ^ \" \" ^ kind (S.kindOf (S.make 3)) ^ \" \"\n"
      ^ "                ^ kind (S.kindOf (S.make 7)) ^ \"\\n\")\nval () = print (#1 (S.twice \"poly\") ^ \"\\n\")\n"
      ^ "val () = (ignore (S.make ~4); print \"no raise\\n\") handle S.Bad n => print (\"Bad \" ^ Int.toString n ^ \"\\n\")"
  fun linked c name sources =
    let val target = #directory c ^ "/" ^ name ^ ".rbc"
        val () = rmTree target
        val result = compiler c (name ^ "-client") "" (["--units", "--no-cache"] @ sources @ ["-o", name ^ ".rbc"])
    in success result; bytecode target end
  fun shapeModule c =
    (put c "shape.sml" shape; put c "impl.sml" implementation; emit c "impl" ["shape.sml", "impl.sml"])
  (* a dynamic functor (the build-system roadmap's M21): its parameter with
     values, an exception, a substructure and an open constructor (Point,
     whose argument the parameter's t is, laid flat by P), and its result
     with a datatype a client takes apart and an exception of its own *)
  val functorSigs =
    "signature ARG =\nsig\n  type t\n  datatype shape = Point of t | Pair of t * t | Empty\n  val size : t -> int\n"
    ^ "  exception Bad of t\n  structure Sub : sig val k : int end\nend\n"
    ^ "signature RES =\nsig\n  type a\n  datatype view = One of a | Two of a * a | Nothing | Counted of int * int\n"
    ^ "  val view : a -> view\n  val describe : view -> string\n  val total : a list -> int\n  exception Odd of a\n  val check : a -> a\nend\n"
  val functorImpl =
    "_export functor F (X : ARG) : RES where type a = X.shape =\nstruct\n  type a = X.shape\n"
    ^ "  datatype view = One of a | Two of a * a | Nothing | Counted of int * int\n"
    ^ "  fun view (s as X.Point p) = One s\n    | view (s as X.Pair (p, q)) = Two (s, s)\n    | view X.Empty = Nothing\n"
    ^ "  fun sizeOf (X.Point p) = X.size p\n    | sizeOf (X.Pair (p, q)) = X.size p + X.size q\n    | sizeOf X.Empty = X.Sub.k\n"
    ^ "  fun describe (One s) = \"one \" ^ Int.toString (sizeOf s)\n    | describe (Two (s, _)) = \"two \" ^ Int.toString (sizeOf s)\n"
    ^ "    | describe Nothing = \"nothing\"\n    | describe (Counted (a, b)) = \"counted \" ^ Int.toString (a + b)\n"
    ^ "  fun total l = List.foldl (fn (s, n) => n + sizeOf s) 0 l\n  exception Odd of a\n"
    ^ "  fun check s = if sizeOf s mod 2 = 1 then raise Odd s else s\nend\n"
  val functorClient =
    "functor F = _dynamic \"impl.rbu\" (X : ARG) : RES where type a = X.shape\n"
    ^ "structure P = struct type t = int * int  datatype shape = Point of t | Pair of t * t | Empty\n"
    ^ "  fun size (a, b) = a + b  exception Bad of t  structure Sub = struct val k = 100 end end\n"
    ^ "structure Q = struct type t = string  datatype shape = Point of t | Pair of t * t | Empty\n"
    ^ "  val size = String.size  exception Bad of t  structure Sub = struct val k = 7 end end\n"
    ^ "structure FP = F (P)\nstructure FQ = F (Q)\n"
    ^ "val () = print (FP.describe (FP.view (P.Point (3, 4))) ^ \"\\n\")\n"
    ^ "val () = print (FP.describe (FP.view (P.Pair ((1, 2), (3, 4)))) ^ \"\\n\")\n"
    ^ "val () = print (FP.describe (FP.Counted (5, 6)) ^ \"\\n\")\n"
    ^ "val () = print (case FP.view (P.Pair ((1, 1), (2, 2))) of FP.Two (P.Pair ((a, b), _), _) => \"pair \" ^ Int.toString (a + b) ^ \"\\n\" | _ => \"other\\n\")\n"
    ^ "val () = print (Int.toString (FP.total [P.Point (1, 1), P.Empty, P.Pair ((2, 2), (3, 3))]) ^ \"\\n\")\n"
    ^ "val () = print (FQ.describe (FQ.view (Q.Pair (\"ab\", \"cde\"))) ^ \" \" ^ Int.toString (FQ.total [Q.Point \"x\", Q.Empty]) ^ \"\\n\")\n"
    ^ "val () = (ignore (FP.check (P.Point (1, 2))); print \"even\\n\") handle FP.Odd (P.Point (a, b)) => print (\"odd \" ^ Int.toString a ^ \"\\n\")\n"
    ^ "val () = (ignore (FQ.check (Q.Point \"ab\")); print \"even\\n\") handle FQ.Odd _ => print \"odd\\n\"\n"
  val functorOutput = "one 7\ntwo 10\ncounted 11\npair 2\n112\ntwo 5 8\nodd 1\neven\n"
  fun functorModule c =
    (put c "sigs.sml" functorSigs; put c "impl.sml" functorImpl; emit c "impl" ["sigs.sml", "impl.sml"])
  (* the functor's client, run against an impl.rbu that is another module:
     refused when the declaration runs *)
  fun functorRefused c name =
    (put c "client.sml" functorClient; linked c "client" ["sigs.sml", "client.sml"];
     let val result = program c name "" ["client.rbc"]
     in need (#status result = 1 andalso #output result = ""
              andalso String.isSubstring "Mismatch \"impl.rbu implements another signature" (#errors result),
              "a dynamic functor of another ABI was not refused: " ^ #errors result) end)
  fun replaceIn text from into =
    let val (left, right) = Substring.position from (Substring.full text)
    in need (not (Substring.isEmpty right), "dynamic fixture replacement is missing: " ^ from);
       Substring.string left ^ into ^ Substring.string (Substring.triml (size from) right) end
  fun dynamicReload c jit =
    let val dir = #directory c
        val () = List.app (fn (file, text) => put c file text)
           [("live.sml", "signature LIVE = sig val version : unit -> string val step : int -> int end"),
            ("v1.sml", "_export structure V : LIVE = struct fun version () = \"v1\" fun step n = n + 1 end"),
            ("v2.sml", "_export structure V : LIVE = struct fun version () = \"v2\" fun step n = n * 2 end"),
            ("v3.sml", "signature LIVE = sig val version : unit -> string end\n_export structure V : LIVE = struct fun version () = \"v3\" end"),
            ("reload.sml", "structure L = _dynamic \"live.rbu\" : LIVE\nfun copy (a, b) =\n"
               ^ "  let val i = BinIO.openIn a val v = BinIO.inputAll i val () = BinIO.closeIn i\n"
               ^ "      val out = BinIO.openOut b in BinIO.output (out, v); BinIO.closeOut out end\n"
               ^ "fun loop (0, acc) = acc | loop (n, acc) = loop (n - 1, L.step acc)\nval kept = L.version\n"
               ^ "val () = print (L.version () ^ \" \" ^ Int.toString (loop (10, 0)) ^ \"\\n\")\n"
               ^ "val () = copy (\"v2.rbu\", \"live.rbu\")\nval () = Dynamic.reload \"live.rbu\"\n"
               ^ "val () = print (L.version () ^ \" \" ^ Int.toString (loop (10, 1)) ^ \" \" ^ kept () ^ \"\\n\")\n"
               ^ "val () = copy (\"v3.rbu\", \"live.rbu\")\n"
               ^ "val () = (Dynamic.reload \"live.rbu\"; print \"reloaded\\n\") handle Dynamic.Mismatch _ => print \"mismatch\\n\"\n"
               ^ "val () = print (L.version () ^ \"\\n\")")]
        val () = emit c "v1" ["live.sml", "v1.sml"]
        val () = emit c "v2" ["live.sml", "v2.sml"]
        val () = emit c "v3" ["v3.sml"]
        val () = linked c "reload" ["live.sml", "reload.sml"]
        val () = copy (dir ^ "/v1.rbu") (dir ^ "/live.rbu")
    in output (program c "reload-run" "" ((if jit then ["--jit=all"] else []) @ ["reload.rbc"])) "v1 10\nv2 1024 v1\nmismatch\nv2\n" end
  fun dynamic c which () =
    let val () = reset c
        val dir = #directory c
        fun run name flags expected = output (program c (name ^ "-run") "" (flags @ [name ^ ".rbc"])) expected
        fun replace text from into =
          let val (left, right) = Substring.position from (Substring.full text)
          in need (not (Substring.isEmpty right), "dynamic fixture replacement is missing");
             Substring.string left ^ into ^ Substring.string (Substring.triml (size from) right) end
    in case which of
      "link" => (shapeModule c; put c "client.sml" client; linked c "client" ["shape.sml", "client.sml"];
                   run "client" [] "impl 9 square 3 round\npoly\nBad ~4\n")
    | "link-jit" => (shapeModule c; put c "client.sml" client; linked c "client" ["shape.sml", "client.sml"];
                   run "client" ["--jit=all"] "impl 9 square 3 round\npoly\nBad ~4\n")
    | "mismatch" =>
        (shapeModule c; put c "client.sml" client; linked c "client" ["shape.sml", "client.sml"];
         put c "other.sml" (replace shape "val area : t -> int" "val area : t -> real" ^ "\n"
            ^ "_export structure Other : SHAPE =\nstruct\n  datatype kind = Round | Square of int\n  type t = int\n"
            ^ "  exception Bad of int\n  fun make n = n\n  fun area n = real n\n  fun kindOf _ = Round\n"
            ^ "  val name = \"other\"\n  fun twice x = (x, x)\nend");
         emit c "other" ["other.sml"]; copy (dir ^ "/other.rbu") (dir ^ "/impl.rbu");
         let val result = program c "mismatch" "" ["client.rbc"]
         in need (#status result = 1 andalso String.isSubstring "Mismatch \"impl.rbu implements another signature" (#output result ^ #errors result),
                  "dynamic signature mismatch was not rejected") end)
    | "plugin" =>
        (put c "registry.sml" "structure Registry = struct val plugins : (string * (int -> int)) list ref = ref [] end";
         put c "plugin.sml" "val () = Registry.plugins := (\"double\", fn x => 2 * x) :: !Registry.plugins";
         put c "host.sml" "val () = Dynamic.load \"plugin.rbu\"\nval () = List.app (fn (n, f) => print (n ^ \" \" ^ Int.toString (f 21) ^ \"\\n\")) (!Registry.plugins)";
         emit c "plugin" ["registry.sml", "plugin.sml"]; linked c "host" ["registry.sml", "host.sml"]; run "host" [] "double 42\n")
    | "shared-types" =>
        (List.app (fn (file, text) => put c file text)
           [("lib.sml", "structure Lib = struct datatype pt = P of int * int end"),
            ("maker.sml", "signature MAKER = sig val make : int -> Lib.pt end"),
            ("measurer.sml", "signature MEASURER = sig val norm : Lib.pt -> int end"),
            ("mk.sml", "_export structure Mk : MAKER = struct fun make n = Lib.P (n, n + 1) end"),
            ("ms.sml", "_export structure Ms : MEASURER = struct fun norm (Lib.P (a, b)) = a * a + b * b end"),
            ("both.sml", "structure M = _dynamic \"mk.rbu\" : MAKER\nstructure N = _dynamic \"ms.rbu\" : MEASURER\nval () = print (Int.toString (N.norm (M.make 3)) ^ \"\\n\")")];
         emit c "mk" ["lib.sml", "maker.sml", "mk.sml"]; emit c "ms" ["lib.sml", "measurer.sml", "ms.sml"];
         linked c "both" ["lib.sml", "maker.sml", "measurer.sml", "both.sml"]; run "both" [] "25\n")
    | "whole-refused" => (put c "shape.sml" shape; put c "client.sml" client;
          refused (compiler c which "" ["shape.sml", "client.sml", "-o", "whole.rbc"]) "is built in units (rune --units)")
    | "nested" =>
        (* substructures, each a record of its own in its structure's (D3) *)
        (put c "nest.sml" ("signature NEST = sig val name : string\n  structure Inner : sig val twice : int -> int exception Bad of int\n"
                           ^ "    structure Deep : sig val k : int end end end");
         put c "impl.sml" ("_export structure Impl : NEST = struct val name = \"nest\"\n"
                           ^ "  structure Inner = struct fun twice x = 2 * x exception Bad of int structure Deep = struct val k = 7 end end end");
         emit c "impl" ["nest.sml", "impl.sml"];
         put c "client.sml" ("structure N = _dynamic \"impl.rbu\" : NEST\n"
                             ^ "val () = print (N.name ^ \" \" ^ Int.toString (N.Inner.twice N.Inner.Deep.k) ^ \"\\n\")\n"
                             ^ "val () = (raise N.Inner.Bad 3) handle N.Inner.Bad n => print (\"Bad \" ^ Int.toString n ^ \"\\n\")");
         linked c "client" ["nest.sml", "client.sml"]; run "client" [] "nest 14\nBad 3\n")
    | "reload" => dynamicReload c false
    | "reload-jit" => dynamicReload c true
    | "abstract-reload" =>
        (shapeModule c;
         put c "noreload.sml" ("structure S = _dynamic \"impl.rbu\" : SHAPE\nval kept = S.make 3\n"
          ^ "val () = (Dynamic.reload \"impl.rbu\"; print \"reloaded\\n\")\n"
          ^ "         handle Dynamic.Mismatch m => print (if String.isSubstring \"abstract type\" m then \"refused\\n\" else m ^ \"\\n\")\n"
          ^ "val () = print (Int.toString (S.area kept) ^ \"\\n\")");
         linked c "noreload" ["shape.sml", "noreload.sml"]; run "noreload" [] "refused\n9\n")
    (* a dynamic functor, applied twice, as a plugin *)
    | "functor-link" => (functorModule c; put c "client.sml" functorClient; linked c "client" ["sigs.sml", "client.sml"];
                         run "client" [] functorOutput)
    | "functor-link-jit" => (functorModule c; put c "client.sml" functorClient; linked c "client" ["sigs.sml", "client.sml"];
                             run "client" ["--jit=all"] functorOutput)
    (* a module of another parameter's signature, or another result's, or a
       structure where a functor is wanted: each another ABI *)
    | "functor-param-mismatch" =>
        (put c "sigs.sml" functorSigs;
         put c "other.sml" (replaceIn functorSigs "  val size : t -> int\n" "  val size : t -> int\n  val weight : t -> int\n");
         put c "impl.sml" functorImpl; emit c "impl" ["other.sml", "impl.sml"]; functorRefused c which)
    | "functor-result-mismatch" =>
        (put c "sigs.sml" functorSigs;
         put c "other.sml" (replaceIn functorSigs "  val total : a list -> int\n" "  val total : a list -> IntInf.int\n");
         put c "impl.sml" (replaceIn functorImpl "0 l\n" "0 l\n  val total = IntInf.fromInt o total\n");
         emit c "impl" ["other.sml", "impl.sml"]; functorRefused c which)
    | "functor-structure-mismatch" =>
        (put c "sigs.sml" functorSigs;
         put c "impl.sml" ("_export structure F : RES =\nstruct\n  type a = int\n"
                           ^ "  datatype view = One of a | Two of a * a | Nothing | Counted of int * int\n"
                           ^ "  fun view a = One a  fun describe _ = \"\"  fun total _ = 0  exception Odd of a  fun check a = a\nend\n");
         emit c "impl" ["sigs.sml", "impl.sml"]; functorRefused c which)
    | "functor-whole-refused" =>
        (put c "sigs.sml" functorSigs; put c "client.sml" functorClient;
         refused (compiler c which "" ["sigs.sml", "client.sml", "-o", "whole.rbc"]) "is built in units (rune --units)")
    (* loaded again: an application after it is of the new module, one
       before keeps the old *)
    | "functor-reload" =>
        (List.app (fn (file, text) => put c file text)
           [("io.sml", "signature IN = sig val x : int end\nsignature OUT = sig type t val make : unit -> t val show : t -> string end"),
            ("v1.sml", "_export functor G (A : IN) : OUT = struct type t = int fun make () = A.x + 1 fun show n = \"v1 \" ^ Int.toString n end"),
            ("v2.sml", "_export functor G (A : IN) : OUT = struct type t = string fun make () = Int.toString (A.x * 2) fun show s = \"v2 \" ^ s end"),
            ("g.sml", "functor G = _dynamic \"g.rbu\" (A : IN) : OUT\n"
                      ^ "fun copy (a, b) = let val i = BinIO.openIn a val v = BinIO.inputAll i val () = BinIO.closeIn i\n"
                      ^ "  val out = BinIO.openOut b in BinIO.output (out, v); BinIO.closeOut out end\n"
                      ^ "structure One = G (struct val x = 10 end)\nval kept = One.make ()\nval () = print (One.show kept ^ \"\\n\")\n"
                      ^ "val () = copy (\"v2.rbu\", \"g.rbu\")\nval () = Dynamic.reload \"g.rbu\"\n"
                      ^ "structure Two = G (struct val x = 10 end)\n"
                      ^ "val () = print (One.show kept ^ \" \" ^ Two.show (Two.make ()) ^ \"\\n\")")];
         emit c "v1" ["io.sml", "v1.sml"]; emit c "v2" ["io.sml", "v2.sml"]; linked c "g" ["io.sml", "g.sml"];
         copy (dir ^ "/v1.rbu") (dir ^ "/g.rbu"); run "g" [] "v1 11\nv1 11 v2 20\n")
    (* a module compiled with its files spelt ./, its client without: one
       unit's names and one ABI, whose fingerprints are of logical names
       (E10, and M3 of the build-system roadmap) *)
    | "spelling" =>
        (put c "sigs.sml" functorSigs; put c "impl.sml" functorImpl; emit c "impl" ["./sigs.sml", "./impl.sml"];
         put c "client.sml" functorClient; linked c "client" ["sigs.sml", "client.sml"]; run "client" [] functorOutput;
         put c "shape.sml" shape; put c "shapeclient.sml" client; put c "impl.sml" implementation; emit c "impl" ["./shape.sml", "./impl.sml"];
         linked c "shapeclient" ["shape.sml", "shapeclient.sml"]; run "shapeclient" [] "impl 9 square 3 round\npoly\nBad ~4\n")
    | _ => raise Failed "unknown dynamic module scenario"
    end
  val dynamicCases = ["link", "link-jit", "mismatch", "plugin", "shared-types", "whole-refused", "reload", "reload-jit", "abstract-reload",
                      "nested", "functor-link", "functor-link-jit", "functor-param-mismatch", "functor-result-mismatch",
                      "functor-structure-mismatch", "functor-whole-refused", "functor-reload", "spelling"]
  val targets = ["registers", "stack"]
  fun targetVM "registers" = fromRoot "bin/runevm"
    | targetVM "stack" = fromRoot "bin/runevm-stack"
    | targetVM _ = raise Failed "unknown unit target"
  fun unitNames () = List.filter (fn name => isDir (fromRoot ("tests/units/" ^ name))) (sort (entries (fromRoot "tests/units")))
  fun unitPrefix c name build target = #directory (c : context) ^ "/" ^ name ^ "." ^ build ^ "." ^ target
  fun unitSources name =
    let val dir = "tests/units/" ^ name
        val path = fromRoot (dir ^ "/files")
        val () = need (exists path, "unit fixture has no source list: " ^ name)
    in List.map (fn file => dir ^ "/" ^ file) (lines (read path)) end
  (* the compiler's flags of a fixture, from its `flags` where it has one,
     in every build of it *)
  fun unitFlags name =
    let val path = fromRoot ("tests/units/" ^ name ^ "/flags")
    in if exists path then String.tokens Char.isSpace (read path) else [] end
  fun unitsPrepare c () =
    (reset c; List.app (fn target =>
       let val output = #directory c ^ "/load." ^ target ^ ".rbc"
           val result = compiler c ("loader-" ^ target) root ["--target=" ^ target, "tests/units/load.sml", "-o", output]
           val save = #directory c ^ "/loadsave." ^ target ^ ".rbc"
           val result2 = compiler c ("loadsave-" ^ target) root ["--target=" ^ target, "tests/units/loadsave.sml", "-o", save]
           val inventory = #directory c ^ "/inventory." ^ target ^ ".rbc"
           val result3 = compiler c ("inventory-" ^ target) root ["--target=" ^ target, "tests/units/inventory.sml", "-o", inventory]
       in success result; bytecode output; success result2; bytecode save;success result3;bytecode inventory end) targets)
  fun unitBuild c name build target () =
    let val prefix = unitPrefix c name build target
        val units = build = "units"
        val () = need (units orelse build = "whole", "unknown unit build mode")
        val () = rmTree (prefix ^ ".rbc")
        val () = if units then rmTree (prefix ^ ".files") else ()
        val flags = ["--target=" ^ target] @ (if units then ["--units", "--cache-dir", #directory c ^ "/cache",
                               "--emit-units", prefix ^ ".files"] else [])
        val compiled = compiler c (name ^ "-" ^ build ^ "-" ^ target ^ "-compile") root
                                 (flags @ unitFlags name @ unitSources name @ ["-o", prefix ^ ".rbc"])
        val () = write (prefix ^ ".compile-status", Int.toString (#status compiled) ^ "\n")
        val result = if #status compiled <> 0 then {status = 0, output = "", errors = ""} : result else
                       (bytecode (prefix ^ ".rbc"); execute c (name ^ "-" ^ build ^ "-" ^ target ^ "-run") root
                                                             [targetVM target, prefix ^ ".rbc"])
        val got = #errors compiled ^ "compile: " ^ Int.toString (#status compiled) ^ "\n"
                  ^ (if #status compiled = 0 then #output result ^ #errors result ^ "run: " ^ Int.toString (#status result) ^ "\n" else "")
        val () = write (prefix ^ ".got", got)
        val want = fromRoot ("tests/units/" ^ name ^ "/" ^ (if not units andalso exists (fromRoot ("tests/units/" ^ name ^ "/whole.expected"))
                                  then "whole.expected" else "expected"))
        val () = need (exists want andalso read want = got, "unit fixture differs: " ^ name ^ "/" ^ build ^ "/" ^ target)
        val () = if #status compiled <> 0 then () else
             (write (prefix ^ ".output", #output result); write (prefix ^ ".run-status", Int.toString (#status result) ^ "\n"))
    in () end
  fun unitFiles prefix =
    let val path = prefix ^ ".files/units"
        val () = need (exists path, "unit producer published no file list")
    in List.map fromRoot (lines (read path)) end
  fun unitLoad c name target () =
    let val prefix = unitPrefix c name "units" target
        val result = execute c (name ^ "-loaded-" ^ target) root
                    ([targetVM target, #directory c ^ "/load." ^ target ^ ".rbc"] @ unitFiles prefix)
    in need (#output result = read (prefix ^ ".output") andalso Int.toString (#status result) ^ "\n" = read (prefix ^ ".run-status"),
             "loaded unit output/status differs: " ^ name ^ "/" ^ target) end
  fun unitWarm c name target () =
    let val prefix = unitPrefix c name "units" target
        val () = rmTree (prefix ^ ".warm.rbc")
        val result = compiler c (name ^ "-warm-" ^ target) root
              (["--target=" ^ target, "--units", "--cache-dir", #directory c ^ "/cache", "--explain-rebuild"]
                    @ unitFlags name @ unitSources name @ ["-o", prefix ^ ".warm.rbc"])
    in success result; need (null (rebuilt (#errors result)), "warm unit build recompiled a source: " ^ name);
       need (same (prefix ^ ".rbc", prefix ^ ".warm.rbc"), "warm unit bytecode differs: " ^ name ^ "/" ^ target) end
  val loaderCases = ["twice", "shadowed", "not-a-unit", "cut-short", "not-loaded", "other-compile", "other-set", "inventory", "saved", "restored"]
  fun loader c target which () =
    let val files = unitFiles (unitPrefix c "twice" "units" target)
        fun part ([], _) = raise Failed "unit fixture has no named unit"
          | part (file :: rest, suffix) = if String.isSuffix suffix file then ([], file, rest)
              else let val (prefix, found, suffixes) = part (rest, suffix) in (file :: prefix, found, suffixes) end
        val (basis, a, afterA) = part (files, "-a.rbu")
        val (_, b, last) = part (afterA, "-b.rbu")
        val vm = targetVM target
        val load = #directory c ^ "/load." ^ target ^ ".rbc"
        fun run args = execute c ("loader-" ^ which ^ "-" ^ target) root (vm :: load :: args)
        fun loaded (result : result) expected =
          let val errors = List.filter (fn line => not (String.isPrefix "  in " line)) (lines (#errors result))
              val text = #output result ^ String.concat (List.map (fn line => line ^ "\n") errors)
                         ^ "status " ^ Int.toString (#status result) ^ "\n"
          in need (text = expected, "unit loader differs: " ^ which ^ "/" ^ target ^ ": " ^ text) end
        fun refused (result : result) message = need (#status result = 1 andalso String.isPrefix message (#errors result),
                                                      "unit loader did not refuse " ^ which ^ ": " ^ #errors result)
        val image = #directory c ^ "/loaded." ^ target ^ ".img"
    in case which of
      "twice" => loaded (run (basis @ [a, b, b] @ last)) "1\n2\nstatus 0\n"
    | "shadowed" => loaded (run (basis @ [a, b, a, b] @ last)) "1\n1\nstatus 0\n"
    | "not-a-unit" => loaded (run (basis @ [fromRoot "tests/units/load.sml"]))
                            "runevm: uncaught exception Fail \"Runtime.link: not a unit of Rune bytecode\"\nstatus 1\n"
    | "cut-short" =>
        let val source = BinIO.openIn a
            val bytes = BinIO.inputN (source, 100)
            val () = BinIO.closeIn source
            val path = #directory c ^ "/cut." ^ target ^ ".rbu"
            val stream = BinIO.openOut path
            val () = BinIO.output (stream, bytes)
            val () = BinIO.closeOut stream
        in refused (run (basis @ [path])) "runevm: uncaught exception Fail \"Runtime.link: " end
    | "not-loaded" => refused (run [b]) "runevm: uncaught exception Fail \"Runtime.link: the unit names "
    | "other-compile" =>
        let val others = unitFiles (unitPrefix c "across" "units" target)
            val (_, other, _) = part (others, "-b.rbu")
        in refused (run (basis @ [other])) "runevm: uncaught exception Fail \"Runtime.link: the unit names " end
    | "other-set" =>
        let val other = if target = "stack" then "registers" else "stack"
            val first = hd (unitFiles (unitPrefix c "twice" "units" other))
        in loaded (run [first]) "runevm: uncaught exception Fail \"Runtime.link: a unit of another instruction set\"\nstatus 1\n" end
    | "inventory" =>
        loaded (execute c ("loader-inventory-" ^ target) root
          ([vm,#directory c ^ "/inventory." ^ target ^ ".rbc"] @ basis @ [a,b]))
          "linked before executing\n1\n2\nPASS linked unit inventory\nstatus 0\n"
    | "saved" =>
        let val () = rmTree image
            val result = execute c ("loader-save-" ^ target) root
               ([vm, #directory c ^ "/loadsave." ^ target ^ ".rbc"] @ basis @ [a, "--save", image, b] @ last)
        in loaded result "status 0\n"; bytecode image end
    | "restored" => loaded (execute c ("loader-restore-" ^ target) root [vm, "--restore", image]) "1\nstatus 0\n"
    | _ => raise Failed "unknown unit loader scenario"
    end
end
