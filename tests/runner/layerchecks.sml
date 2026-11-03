(* A unit's layers (docs/units.md, Layers): a compile and an analysis of a build
   give the same static layer, byte for byte by its hash, and the same static
   hash of each export at every depth (RUNE_LAYER_DUMP), and an analysis that
   enters nothing of the ABI layer says what one that does says
   (RUNE_STATIC_LOAD). On rune.build in the tier, and on any build given:
   RUNE_LAYER_TREES names MLton's and HOL4's, which are not in the tree. *)
structure LayerChecks =
struct
  open Incremental
  type unitDump = {exports : (string * string * string) list, static : string, identity : string, sizes : string}

  fun readDump dir : (string * unitDump) list =
    List.map (fn file =>
      let
        val ls = lines (read (dir ^ "/" ^ file))
        val exports = List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                                                 [k, s, f] => SOME (k, s, f)
                                               | _ => NONE) ls
        val (static, identity, sizes) =
          case List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                                          ["UNIT", s, i, z] => SOME (s, i, z)
                                        | _ => NONE) ls of
            [x] => x
          | _ => raise Failed ("no UNIT line in the dump " ^ file)
      in (file, {exports = exports, static = static, identity = identity, sizes = sizes}) end)
    (entries dir)

  (* the units both have the same in the static layer, or Failed saying which *)
  fun sameStatic (what, a : (string * unitDump) list, b : (string * unitDump) list) : string =
    let
      val units = ref 0
      val exports = ref 0
      val wrong = ref []
      fun note m = if List.length (!wrong) < 8 then wrong := m :: !wrong else ()
      fun one (file, x : unitDump) =
        case List.find (fn (f, _) => f = file) b of
          NONE => ()
        | SOME (_, y : unitDump) =>
            let
              val () = units := !units + 1
              val () = if #static x = #static y then () else note ("the static layer of " ^ file)
              val () = if List.length (#exports x) = List.length (#exports y) then ()
                       else note ("the exports of " ^ file)
            in
              (* both are in the order of their names *)
              ListPair.app (fn ((k, s, _), (k', t, _)) =>
                              (exports := !exports + 1;
                               if k <> k' then note (k ^ ", not in the other, of " ^ file)
                               else if s = t then () else note (k ^ " of " ^ file))) (#exports x, #exports y)
            end
      val () = List.app one a
      val () = need (!units > 0, what ^ ": no unit in both")
      val () = need (null (!wrong), what ^ ": differ: " ^ String.concatWith "; " (List.rev (!wrong)))
    in what ^ ": " ^ Int.toString (!units) ^ " units, " ^ Int.toString (!exports) ^ " exports, the static layer the same" end

  (* a build, in the directory of its file: batch, analysis, analysis without
     the ABI layer *)
  fun tree (s : state) tool (n : int) (build : string) : unit =
    let
      val dir = OS.Path.dir build
      val file = OS.Path.file build
      val out = !(#directory s) ^ "/" ^ Int.toString n
      val () = (mkdirs (out ^ "/batch"); mkdirs (out ^ "/analysis"); mkdirs (out ^ "/static"))
      (* in the build's directory, its logs in the run's *)
      fun run (name, static, cmd) =
        let
          val log = out ^ "/" ^ name
          val envf = List.foldl (fn ((n, v), f) => setEnv (n, v) o f) (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"])
                                (("RUNE_LAYER_DUMP", out ^ "/" ^ name) :: (if static then [("RUNE_STATIC_LOAD", "1")] else []))
          val status = Children.exec {addressSpace = NONE, cpuTime = SOME 3000, fileSize = SOME (1024 * 1024 * 1024), core = SOME 0}
                                     envf {cmd = cmd, dir = SOME dir, stdin = "", stdout = log ^ ".out", stderr = log ^ ".err",
                                           timeout = 3000}
          val errors = read (log ^ ".err")
          val () = need (status = 0, name ^ " of " ^ build ^ ": exit " ^ Int.toString status ^ ": "
                                     ^ String.substring (errors, 0, Int.min (String.size errors, 400)))
        in read (log ^ ".out") end
      val vm = fromRoot "bin/runevm"
      val heap = ["--heap-size", "67108864", "--heap-limit", "12000000000"]
      val () = ignore (run ("batch", false, [vm] @ heap @ [fromRoot "bin/rune.rbc", "--lib", fromRoot "lib", "--type-work=1000000000",
                                                           "--units", "--no-cache", "--no-warnings", "--build", file, "-o", out ^ "/p.rbc"]))
      val analysis = [vm, "--jit=opt"] @ heap @ [tool, fromRoot "lib", file]
      val full = run ("analysis", false, analysis)
      val static = run ("static", true, analysis)
      val () = need (full = static, "an analysis of the static layer alone says something else of " ^ build ^ ":\n" ^ full ^ "\n" ^ static)
      val batch = readDump (out ^ "/batch")
      val () = say ("PASS " ^ sameStatic ("a compile and an analysis of " ^ file, batch, readDump (out ^ "/analysis")) ^ "\n")
      val () = say ("PASS " ^ sameStatic ("a compile and the static layer alone of " ^ file, batch, readDump (out ^ "/static")) ^ "\n")
    in () end

  (* A client's error that reads how a constructor of another unit lies: the
     one fact of a layout elaboration reads, which is the static layer's *)
  fun flatSize (s : state) tool : unit =
    let
      val () = own s ""
      val () = put s "a.sml" "structure B = struct type e = int * int * int * int * int * int * int * int * int  datatype t = C of e | N end"
      val () = put s "b.sml" "signature P = sig type e  datatype t = C of e | N end\nfunctor F (X : P) = struct fun f (X.C v) = 1 | f _ = 0 end\nstructure R = F (B)"
      val () = put s "p.build" "a.sml b.sml"
      val says = "the argument lays out a constructor of t in 9 fields"
      fun analysis static =
        let
          val () = #environment s := (if static then [("RUNE_STATIC_LOAD", "1")] else [])
          val r = command s "" [fromRoot "bin/runevm", tool, fromRoot "lib", "p.build"]
          val () = #environment s := []
        in r end
      val () = need (String.isSubstring says (#output (analysis false)), "an analysis misses a layout's error")
      val () = need (String.isSubstring says (#output (analysis true)), "an analysis of the static layer alone misses a layout's error")
    in reset s end

  (* The edits that keep the static layer and move the ABI layer (E17's probes):
     each export's static hash holds and something of the unit's whole hash
     moves, and the client is compiled, the bytes those of no cache. A key of
     the static layer alone takes the client across each of them: a known
     function made a closure, an opaque type's realisation under a client's
     datatype, a value that applied a primitive, a body a client copied,
     and an exception that is now another. *)
  val probes =
    [("known", "", "structure A = struct fun f x = x + 1 end",
      "structure A = struct val f = let val c = ref 1 in fn x => x + !c end end",
      "val () = print (Int.toString (A.f 41) ^ \"\\n\")", "42", "42"),
     ("layout", "",
      "structure A :> sig type t val mk : int -> t val get : t -> int end =\nstruct\n  type t = int * int\n  fun mk x = if x > 1000000 then mk (x - 1) else (x, 7)\n  fun get (x, y) = if x > 1000000 then get (x - 1, y) else x + y\nend",
      "structure A :> sig type t val mk : int -> t val get : t -> int end =\nstruct\n  type t = int\n  fun mk x = if x > 1000000 then mk (x - 1) else x\n  fun get x = if x > 1000000 then get (x - 1) else x + 100\nend",
      "datatype d = D of A.t | E of int\nfun use (D t) = A.get t\n  | use (E n) = n\nval () = print (Int.toString (use (D (A.mk 1)) + use (E 2)) ^ \"\\n\")", "10", "103"),
     ("prim", "", "structure A = struct val len = String.size end",
      "structure A = struct fun len s = if s = \"\" then len \"x\" - 1 else String.size s + 1 end",
      "val () = print (Int.toString (A.len \"abc\") ^ \"\\n\")", "3", "4"),
     ("inlv", "inline val A.twice end\n", "structure A = struct fun twice x = x + x end",
      "structure A = struct fun twice x = x + x + 1 end",
      "val () = print (Int.toString (A.twice 20) ^ \"\\n\")", "40", "41"),
     ("exn", "", "structure A = struct exception E  exception F end",
      "structure A = struct exception F  exception E = F end",
      "val () = print ((raise A.E) handle A.F => \"same\\n\" | A.E => \"other\\n\")", "other", "same")]

  fun directed (s : state) (name, marks, a1, a2, b, out1, out2) : unit =
    let
      val () = own s ""
      val () = put s "a.sml" a1
      val () = put s "b.sml" b
      val () = put s "p.build" (marks ^ "files a.sml b.sml end")
      fun dumpOf v =
        let
          val dir = path s ("dump" ^ v)
          val () = (mkdirs dir; #environment s := [("RUNE_LAYER_DUMP", dir)])
        in dir end
      fun unitOf dir =
        case List.filter (fn (file, _) => String.isSuffix "a.sml" file) (readDump dir) of
          [(_, u)] => #exports u
        | _ => raise Failed (name ^ ": no one unit a.sml in the dump")
      val d1 = dumpOf "1"
      val () = IncrementalExtra.buildFile s "p.build" "a.sml b.sml"
      val () = prints s out1
      val () = put s "a.sml" a2
      val d2 = dumpOf "2"
      val () = IncrementalExtra.buildFile s "p.build" "a.sml b.sml"
      val () = prints s out2
      val () = #environment s := []
      val (x, y) = (unitOf d1, unitOf d2)
      fun keys l = List.map #1 l
      val () = need (keys x = keys y, name ^ ": the edit changed the exports")
      val () = need (ListPair.all (fn ((_, s1, _), (_, s2, _)) => s1 = s2) (x, y), name ^ ": the edit moved the static layer")
      (* a copied body is neither layer's: the usage "inlv" holds it *)
      val () = need (name = "inlv" orelse ListPair.exists (fn ((_, _, f1), (_, _, f2)) => f1 <> f2) (x, y),
                     name ^ ": the edit moved neither layer")
    in say ("PASS the edit " ^ name ^ " holds the static layer and rebuilds the client\n") end

  (* the analysis, compiled, kept at keep, where a reset leaves it *)
  fun analysisTool (s : state, keep : string) : unit =
    let
      val tool = path s "layers-analysis.rbc"
      val r = command s "" [#compiler s, "--library", "compiler", "--no-warnings", fromRoot "tests/compiler/layers-analysis.sml", "-o", tool]
      val () = need (#status r = 0, "layers-analysis does not compile: " ^ #errors r)
    in copy tool keep end

  fun main (trees : string list) : unit =
    let
      val s = create "layers" "bin/rune"
      val () = reset s
      val keep = run ^ "/layers-tool.rbc"
      val () = analysisTool (s, keep)
      val () = flatSize s keep
      val () = List.app (directed s) probes
      val () = reset s
      val () = #directory s := run ^ "/incremental/layers"
      val () = ignore (List.foldl (fn (b, n) => (tree s keep n (fromRoot b); n + 1)) 0 trees)
    in () end

  (* a build outside the tree alone (RUNE_LAYER_TREES, a test of its own):
     a compile and two analyses of it, in a directory of its own *)
  fun one (build : string) : unit =
    let
      val name = "layers-" ^ OS.Path.base (OS.Path.file build)
      val s = create name "bin/rune"
      val () = reset s
      val keep = run ^ "/" ^ name ^ "-tool.rbc"
      val () = analysisTool (s, keep)
      val () = reset s
    in tree s keep 0 (fromRoot build) end
end
