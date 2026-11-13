(* The suspensions of a lazy front end through the engines (docs/ir.md,
   Suspensions; docs/plans/language/haskell98.md, M9): the kernels of
   tests/thunks, SML programs over the primitives (--allow-prim) in
   Haskell's reading, each a job `thunks/NAME`, which prints a line FAIL for
   what it finds.

   Each kernel is compiled to the register bytecode at -O0, -O1, -O2 and
   with --check-casts, and to the stack bytecode at -O0, -O1 and -O2, all
   with the lint; each register build runs on runevm interpreted and in
   every mode of the JIT the oracle jit runs, under --checked, --gc-verify
   with a small heap and nursery, a collection at every few allocations,
   the low-pause collector and the compacting one, on the VM whose
   collector sets the header's bits (runevm-gcbits) and on the census VM,
   which interprets and counts as runevm does; each stack build on
   runevm-stack, under --checked and --gc-verify, and as runeopt's native
   code (runevm-native) where the machine makes it. Every run prints the
   kernel's `.expected` with the arguments of its `.args`; every run of a
   build counts the same instructions, bytes and objects; and the two
   bytecodes at -O1 allocate the same.

   Beside that: reenter ends with Loop uncaught, status 1, on each engine,
   and loopcatch's handler takes Loop at every force; image saves
   from inside a suspension and goes on there when restored; last and leak
   keep nothing an element, the most live with a collection at every
   allocation the same at n = 1000 and 2000 on the register VM, interpreted
   and at tier 2, under the copier and the low-pause collector (the stack
   VM keeps every local of a waiting frame, so it is not asked); a chain
   of 10^7 suspensions fits the default stack (D18); and wrongslot's
   suspensions where a type says a list or a function stop the interpreter
   and tier 1, a suspension read as a ref stops every tier, and MidLint
   refuses each; cast's casts print the same with --check-casts, and
   forget's force forgotten behind a cast stops every engine under it, and
   the lint refuses it at -O2; results' suspensions, read back from where
   a function's results return a datatype, are forced at every level; and
   castin's values cast into suspensions and forced in a suspension's code,
   cast there or where the closure is made, pass RegVerify at every level;
   and caf's top-level list, which no code reads once it is walked, is let
   go (the CAF tables, runtime/gc/caf.c: the haskell98 roadmap's D19): the
   live at the end the same at n = 1000 and 2000 on both VMs, interpreted
   and at tier 2, under every collector -- the full collection, the copier
   and the low-pause collector's cycle, a collection at every allocation --
   and greater at 2000 with every global a root (--caf-tables off).

   And the kernels of lazy ML's reading (the haskell98 roadmap's D57, M26),
   whose suspension never goes under evaluation: k_outlive, k_outlive_int,
   k_outlive_raise, k_outlive_three and outlive_nullary, a body that outlives
   its own update, which the collector's pin keeps written (gc_pin_running),
   and k_nested, a suspension of a suspension, which its guard keeps apart
   (ind_may_shortcut); ordinary kernels, every build and every way. *)
structure Thunks =
struct
  open Sh

  val kernels = ["chain", "tailchain", "knot", "share", "reenter", "barrier", "image", "last", "leak", "wrongslot", "cast", "forget",
                 "results", "castin", "loopcatch", "caf",
                 (* lazy ML's reading (D57, M26): a body that outlives its own
                    update, and a suspension of a suspension *)
                 "k_outlive", "k_outlive_int", "k_outlive_raise", "k_outlive_three", "outlive_nullary", "k_nested"]
  fun source k = "tests/thunks/" ^ k ^ ".sml"
  fun args k = words (fromRoot ("tests/thunks/" ^ k ^ ".args"))

  (* the builds: name, compiler options *)
  val registerBuilds = [("O0", ["-O0"]), ("O1", []), ("O2", ["-O2"]), ("C1", ["--check-casts"])]
  val stackBuilds = [("S0", ["--target=stack", "-O0"]), ("S1", ["--target=stack"]), ("S2", ["--target=stack", "-O2"])]

  (* the ways of runevm: name, VM, options; the JIT's as the oracle jit
     has them (tests/runner/oracles.sml) *)
  val registerWays =
    List.map (fn (name, jit, _) => (name, "bin/runevm", jit)) Oracles.jitModes
    @ [("checked", "bin/runevm", ["--checked"]),
       ("verify", "bin/runevm", ["--gc-verify", "--heap-size", "65536", "--nursery", "4096"]),
       ("stress", "bin/runevm", ["--gc-stress", "3"]),
       ("stress2", "bin/runevm", ["--gc-stress", "3", "--jit=all", "--jit-tier=2"]),
       ("lowpause", "bin/runevm", ["--gc", "low-pause", "--gc-stress", "2", "--gc-stress-cycles"]),
       ("compact", "bin/runevm", ["--gc-compact", "--gc-stress", "5"]),
       ("gcbits", "bin/runevm-gcbits", ["--gc-verify", "--heap-size", "65536", "--nursery", "4096"]),
       ("gcbits2", "bin/runevm-gcbits", ["--jit=all", "--jit-tier=2", "--gc-stress", "7"]),
       ("census", "bin/runevm-census", ["--census-dir", "census", "--census-summary"])]
  val stackWays =
    [("stack", "bin/runevm-stack", []), ("checked", "bin/runevm-stack", ["--checked"]),
     ("verify", "bin/runevm-stack", ["--gc-verify", "--heap-size", "65536", "--nursery", "4096"]),
     ("stress", "bin/runevm-stack", ["--gc-stress", "3"])]
    @ (if exists (fromRoot "bin/runevm-native") then [("native", "bin/runevm-native", [])] else [])

  fun fail (k, what) = say ("FAIL thunks." ^ k ^ ": " ^ what ^ "\n")

  (* a build of kernel k into dir: the bytecode's file, or NONE where it
     does not compile *)
  fun compile (k, dir, (b, opts), lint) =
    let
      val rbc = dir ^ "/" ^ b ^ ".rbc"
      val err = dir ^ "/" ^ b ^ ".cerr"
      val envf = if lint then (fn e => e) else setEnv ("RUNE_LINT", "")
      val status = execEnv envf {cmd = ["bin/rune", "--allow-prim"] @ (if lint then ["--lint"] else []) @ opts @ [source k, "-o", rbc],
                                 dir = NONE, stdin = "", stdout = err, stderr = err, timeout = 600}
    in
      if status = 0 then SOME rbc else (fail (k, b ^ " does not compile: " ^ firstLine err); NONE)
    end

  (* one run, in a directory of its own of a name of one length, so that
     the counts do not differ by its path (docs/testing.md, What the input
     is): its exit status, and the files of its outputs *)
  fun runIn (dir, name, vm, opts, rbc, argv) =
    let
      val d = dir ^ "/run-" ^ name
      val () = scratch d
      val code = exec {cmd = [fromRoot vm] @ opts @ ["--count", rbc] @ argv, dir = SOME d, stdin = "",
                       stdout = d ^ "/stdout", stderr = d ^ "/stderr", timeout = 900}
    in (code, d ^ "/stdout", d ^ "/stderr") end
  fun countIn file = countOf file

  (* every way of a build: the output the kernel's .expected, and the counts of each the same *)
  fun ways (k, dir, b, rbc, ws) =
    let
      val expected = fromRoot ("tests/thunks/" ^ k ^ ".expected")
      val runs = List.map (fn (w, vm, opts) => (w, runIn (dir, b ^ "-" ^ w, vm, opts, rbc, args k))) ws
      fun check (w, (code, out, err)) =
        if code <> 0 then fail (k, b ^ " " ^ w ^ ": exit " ^ Int.toString code ^ ": " ^ firstNonEmpty err)
        else if not (same (out, expected)) then fail (k, b ^ " " ^ w ^ ": prints otherwise: " ^ difference (expected, out))
        else ()
      val () = List.app check runs
      val counts = List.map (fn (w, (_, _, err)) => (w, countIn err)) runs
    in
      case counts of
        (w0, c0) :: rest =>
          (List.app (fn (w, c) => if c = c0 then () else fail (k, b ^ ": counts " ^ c0 ^ " " ^ w0 ^ ", " ^ c ^ " " ^ w)) rest;
           c0)
      | [] => ""
    end

  (* the bytes and objects of a count, without its instructions *)
  fun allocation c = case String.fields (fn ch => ch = #",") c of _ :: rest => String.concatWith "," rest | [] => ""

  fun ordinary k =
    let
      val dir = run ^ "/thunks/" ^ k
      val () = scratch dir
      fun build ws bs = List.mapPartial (fn b => Option.map (fn rbc => (#1 b, ways (k, dir, #1 b, rbc, ws))) (compile (k, dir, b, true))) bs
      val r = build registerWays registerBuilds
      val s = build stackWays stackBuilds
    in
      case (List.find (fn (b, _) => b = "O1") r, List.find (fn (b, _) => b = "S1") s) of
        (SOME (_, c), SOME (_, c')) =>
          if allocation c = allocation c' then ()
          else fail (k, "the two bytecodes allocate differently at -O1: " ^ allocation c' ^ " stack, " ^ allocation c ^ " registers")
      | _ => ()
    end

  (* a run that must stop with a fatal error saying `what`, its standard
     output `out` before it *)
  (* a run that ends as an uncaught exception ends it: status 1, what err says *)
  fun uncaught (k, w, (code, out, err), what, printed) =
    if code <> 1 then fail (k, w ^ ": exit " ^ Int.toString code ^ " where an uncaught exception's 1 is wanted")
    else if not (String.isSubstring what (read err)) then fail (k, w ^ ": ends otherwise: " ^ firstNonEmpty err)
    else if read out <> printed then fail (k, w ^ ": prints " ^ String.toString (read out) ^ " before it ends")
    else ()
  fun stops (k, w, (code, out, err), what, printed) =
    if code <> 2 then fail (k, w ^ ": exit " ^ Int.toString code ^ " where a fatal error is wanted")
    else if not (String.isSubstring what (read err)) then fail (k, w ^ ": stops otherwise: " ^ firstNonEmpty err)
    else if read out <> printed then fail (k, w ^ ": prints " ^ String.toString (read out) ^ " before it stops")
    else ()

  fun reenter () =
    let
      val k = "reenter"
      val dir = run ^ "/thunks/" ^ k
      val () = scratch dir
      fun build ws bs =
        List.app (fn b => case compile (k, dir, b, true) of
                            SOME rbc => List.app (fn (w, vm, opts) =>
                                                    uncaught (k, #1 b ^ " " ^ w, runIn (dir, #1 b ^ "-" ^ w, vm, opts, rbc, []),
                                                              "uncaught exception Loop", read (fromRoot "tests/thunks/reenter.expected")))
                                                 ws
                          | NONE => ()) bs
    in build registerWays registerBuilds; build stackWays stackBuilds end

  (* saved from inside a suspension, on each VM, and restored there *)
  fun image () =
    let
      val k = "image"
      val dir = run ^ "/thunks/" ^ k
      val () = scratch dir
      val restored = fromRoot "tests/thunks/image.restored"
      fun one (b, rbc, (w, vm, opts)) =
        let
          val name = b ^ "-" ^ w
          val d = dir ^ "/run-" ^ name
          val () = scratch d
          val saved = exec {cmd = [fromRoot vm] @ opts @ [rbc, "saved.img"], dir = SOME d, stdin = "",
                            stdout = d ^ "/save.out", stderr = d ^ "/save.err", timeout = 600}
          val back = if saved <> 0 then ~1
                     else exec {cmd = [fromRoot vm] @ opts @ ["--restore", "saved.img"], dir = SOME d, stdin = "",
                                stdout = d ^ "/restore.out", stderr = d ^ "/restore.err", timeout = 600}
        in
          if saved <> 0 then fail (k, name ^ ": the save exits " ^ Int.toString saved ^ ": " ^ firstNonEmpty (d ^ "/save.err"))
          else if not (same (d ^ "/save.out", fromRoot "tests/thunks/image.expected")) then
            fail (k, name ^ ": the save prints otherwise: " ^ difference (fromRoot "tests/thunks/image.expected", d ^ "/save.out"))
          else if back <> 0 then fail (k, name ^ ": the restore exits " ^ Int.toString back ^ ": " ^ firstNonEmpty (d ^ "/restore.err"))
          else if not (same (d ^ "/restore.out", restored)) then
            fail (k, name ^ ": the restore prints otherwise: " ^ difference (restored, d ^ "/restore.out"))
          else ()
        end
      val rways = [("off", "bin/runevm", ["--jit=off"]), ("opt", "bin/runevm", ["--jit=all", "--jit-tier=2"]),
                   ("verify", "bin/runevm", ["--gc-verify"]), ("gcbits", "bin/runevm-gcbits", [])]
      val sways = [("stack", "bin/runevm-stack", []), ("verify", "bin/runevm-stack", ["--gc-verify"])]
    in
      List.app (fn b => case compile (k, dir, b, true) of SOME rbc => List.app (fn w => one (#1 b, rbc, w)) rways | NONE => ())
               [("O0", ["-O0"]), ("O2", ["-O2"])];
      List.app (fn b => case compile (k, dir, b, true) of SOME rbc => List.app (fn w => one (#1 b, rbc, w)) sways | NONE => ())
               [("S0", ["--target=stack", "-O0"]), ("S2", ["--target=stack", "-O2"])]
    end

  (* the most live, with a collection at every allocation: each a full one
     of the copier (with a nursery the old space keeps what minor
     collections promoted until a full one), or a step of the low-pause
     collector's cycle, which shades what a suspension lets go while it
     marks *)
  val collectors = [("copy", ["--nursery", "0", "--old-space", "copy", "--gc-stress", "1"]),
                    ("lowpause", ["--gc", "low-pause", "--gc-stress", "1", "--gc-stress-cycles"])]
  fun maxLive (dir, name, vm, opts, rbc, n) =
    let
      val d = dir ^ "/live-" ^ name
      val () = scratch d
      val _ = exec {cmd = [fromRoot vm] @ opts @ ["--stats", rbc, n],
                    dir = SOME d, stdin = "", stdout = d ^ "/stdout", stderr = d ^ "/stderr", timeout = 600}
      val key = "max live "
      val at = #2 (Substring.position key (Substring.full (read (d ^ "/stderr"))))
    in if Substring.isEmpty at then NONE else Int.fromString (Substring.string (Substring.triml (size key) at)) end

  fun retains k =
    let
      val () = ordinary k
      val dir = run ^ "/thunks/" ^ k ^ "/live"
      val () = scratch dir
    in
      List.app (fn b =>
                  case compile (k, dir, b, true) of
                    SOME rbc =>
                      List.app (fn (w, opts) =>
                                  let
                                    val a = maxLive (dir, #1 b ^ "-" ^ w ^ "-1000", "bin/runevm", opts, rbc, "1000")
                                    val c = maxLive (dir, #1 b ^ "-" ^ w ^ "-2000", "bin/runevm", opts, rbc, "2000")
                                  in
                                    case (a, c) of
                                      (SOME x, SOME y) =>
                                        if x = y then ()
                                        else fail (k, #1 b ^ " " ^ w ^ ": keeps " ^ Int.toString ((y - x) div 1000)
                                                      ^ " bytes an element (most live " ^ Int.toString x ^ " at 1000, "
                                                      ^ Int.toString y ^ " at 2000)")
                                    | _ => fail (k, #1 b ^ " " ^ w ^ ": no most live in --stats")
                                  end)
                               (List.concat (List.map (fn (c, copts) =>
                                                          [("off-" ^ c, "--jit=off" :: copts),
                                                           ("opt-" ^ c, ["--jit=all", "--jit-tier=2"] @ copts)]) collectors))
                  | NONE => ())
               [("O0", ["-O0"]), ("O2", ["-O2"])]
    end

  (* caf's top-level list let go: the live at the end (--stats), a
     collection at every allocation, the same at 1000 and 2000 under each
     collector where the tables are taken, and more at 2000 where every
     global is a root *)
  fun cafLive (dir, name, vm, opts, rbc, n) =
    let
      val d = dir ^ "/live-" ^ name
      val () = scratch d
      val _ = exec {cmd = [fromRoot vm] @ opts @ ["--stats", rbc, n],
                    dir = SOME d, stdin = "", stdout = d ^ "/stdout", stderr = d ^ "/stderr", timeout = 600}
      (* runevm's line: "... semispace N bytes, L live, ..." *)
      val (prefix, at) = Substring.position " live," (Substring.full (read (d ^ "/stderr")))
    in if Substring.isEmpty at then NONE else Int.fromString (Substring.string (Substring.taker Char.isDigit prefix)) end
  fun caf () =
    let
      val k = "caf"
      val () = ordinary k
      val dir = run ^ "/thunks/" ^ k ^ "/live"
      val () = scratch dir
      val cafCollectors = [("full", ["--gc-stress", "1", "--gc-stress-full"]),
                           ("copy", ["--nursery", "0", "--old-space", "copy", "--gc-stress", "1"]),
                           ("lowpause", ["--gc", "low-pause", "--gc-stress", "1", "--gc-stress-cycles"])]
      fun check (b, vm, rbc) (w, opts) =
        let
          fun live tag mode n = cafLive (dir, b ^ "-" ^ w ^ "-" ^ tag ^ "-" ^ n, vm, ["--caf-tables", mode] @ opts, rbc, n)
        in
          case (live "on" "auto" "1000", live "on" "auto" "2000", live "off" "off" "1000", live "off" "off" "2000") of
            (SOME x, SOME y, SOME u, SOME v) =>
              (if x = y then ()
               else fail (k, b ^ " " ^ w ^ ": keeps " ^ Int.toString ((y - x) div 1000) ^ " bytes an element of the CAF (live at the end "
                             ^ Int.toString x ^ " at 1000, " ^ Int.toString y ^ " at 2000)");
               if v > u then () else fail (k, b ^ " " ^ w ^ ": with every global a root, the live at the end grows no more ("
                                               ^ Int.toString u ^ " at 1000, " ^ Int.toString v ^ " at 2000): the test sees nothing"))
          | _ => fail (k, b ^ " " ^ w ^ ": no live in --stats")
        end
      val rways = List.concat (List.map (fn (c, copts) => [("off-" ^ c, "--jit=off" :: copts), ("opt-" ^ c, ["--jit=all", "--jit-tier=2"] @ copts)])
                                        cafCollectors)
    in
      List.app (fn b => case compile (k, dir, b, true) of SOME rbc => List.app (check (#1 b, "bin/runevm", rbc)) rways | NONE => ())
               [("O0", ["-O0"]), ("O2", ["-O2"])];
      List.app (fn b => case compile (k, dir, b, true) of SOME rbc => List.app (check (#1 b, "bin/runevm-stack", rbc)) cafCollectors | NONE => ())
               [("S0", ["--target=stack", "-O0"]), ("S2", ["--target=stack", "-O2"])]
    end

  (* D18: a chain of 10^7 suspensions forced from its head fits the default stack *)
  fun chain () =
    let
      val () = ordinary "chain"
      val dir = run ^ "/thunks/chain/deep"
      val () = scratch dir
    in
      case compile ("chain", dir, ("O1", []), false) of
        SOME rbc =>
          List.app (fn (w, opts) =>
                      let val (code, out, err) = runIn (dir, w, "bin/runevm", opts, rbc, ["10000000"])
                      in
                        if code <> 0 then fail ("chain", "10^7 " ^ w ^ ": exit " ^ Int.toString code ^ ": " ^ firstNonEmpty err)
                        else if read out <> "chain 50000005000000\n" then fail ("chain", "10^7 " ^ w ^ ": prints " ^ String.toString (read out))
                        else ()
                      end)
                   [("off", ["--jit=off"]), ("opt", ["--jit=all", "--jit-tier=2"])]
      | NONE => ()
    end

  (* what a forgotten force makes, compiled without the lint, and refused
     with it *)
  fun wrongslot () =
    let
      val k = "wrongslot"
      val dir = run ^ "/thunks/" ^ k
      val () = scratch dir
      val err = dir ^ "/lint.cerr"
      val linted = exec {cmd = ["bin/rune", "--allow-prim", "--lint", source k, "-o", dir ^ "/lint.rbc"], dir = NONE, stdin = "",
                         stdout = err, stderr = err, timeout = 600}
      val () = if linted <> 0 andalso String.isSubstring "which is no instance of its description" (read err) then ()
               else fail (k, "the lint does not refuse a suspension where its type says what is none")
      val tier1 = [("off", ["--jit=off"]), ("all", ["--jit=all"])]
      val tier2 = [("opt", ["--jit=all", "--jit-tier=2"])]
      fun modes rbc =
        (* the suspension where a list is: a test of its tag stops it; tier 2 trusts con *)
        (List.app (fn (w, opts) => stops (k, "list " ^ w, runIn (dir, "list-" ^ w, "bin/runevm", opts, rbc, ["list", "100"]),
                                          "JUMPIFNOTTAG on non-constructor", "")) tier1;
         List.app (fn (w, opts) => let val (code, _, e) = runIn (dir, "list-" ^ w, "bin/runevm", opts, rbc, ["list", "100"])
                                   in if code = 0 then () else fail (k, "list " ^ w ^ ": exit " ^ Int.toString code ^ ": " ^ firstNonEmpty e) end)
                  tier2;
         (* where a function is: CALL stops a K_THUNK; tier 2 trusts ptr *)
         List.app (fn (w, opts) => stops (k, "fun " ^ w, runIn (dir, "fun-" ^ w, "bin/runevm", opts, rbc, ["fun", "100"]),
                                          "expected closure in call", "")) tier1;
         (* the suspension's own type, any: every tier tests it *)
         List.app (fn (w, opts) => stops (k, "susp " ^ w, runIn (dir, "susp-" ^ w, "bin/runevm", opts, rbc, ["susp", "100"]),
                                          "primitive ref_get: wrong argument type", "")) (tier1 @ tier2))
    in
      case compile (k, dir, ("O1", []), false) of SOME rbc => modes rbc | NONE => ()
    end

  (* a force forgotten behind a cast: any_check stops it on every engine
     with --check-casts, and the lint refuses it at -O2 *)
  fun forget () =
    let
      val k = "forget"
      val dir = run ^ "/thunks/" ^ k
      val () = scratch dir
      val err = dir ^ "/lint.cerr"
      val linted = exec {cmd = ["bin/rune", "--allow-prim", "--lint", "-O2", source k, "-o", dir ^ "/lint.rbc"], dir = NONE,
                         stdin = "", stdout = err, stderr = err, timeout = 600}
      val () = if linted <> 0 andalso String.isSubstring "a force forgotten" (read err) then ()
               else fail (k, "the lint does not refuse a cast of a suspension at -O2")
      val what = "a suspension where a cast says the value is evaluated (any_check)"
      fun build (b as (name, _), ws) =
        case compile (k, dir, b, false) of
          SOME rbc => List.app (fn (w, vm, opts) => stops (k, name ^ " " ^ w, runIn (dir, name ^ "-" ^ w, vm, opts, rbc, []), what, "")) ws
        | NONE => ()
      val rways = [("off", "bin/runevm", ["--jit=off"]), ("all", "bin/runevm", ["--jit=all"]),
                   ("opt", "bin/runevm", ["--jit=all", "--jit-tier=2"])]
    in
      List.app (fn b => build (b, rways)) [("O0", ["-O0", "--check-casts"]), ("O2", ["-O2", "--check-casts"])];
      List.app (fn b => build (b, stackWays)) [("S0", ["--target=stack", "-O0", "--check-casts"])]
    end

  fun one k =
    case k of
      "forget" => forget ()
    | "reenter" => reenter ()
    | "image" => image ()
    | "last" => retains k
    | "leak" => retains k
    | "chain" => chain ()
    | "caf" => caf ()
    | "wrongslot" => wrongslot ()
    | _ => ordinary k

  fun command ["thunks-one", k] = SOME (fn () => one k)
    | command _ = NONE

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  val tree =
    tagged ["check", "test-register-jit", "covers:tests/thunks/*", "covers:tests/runner/thunks.sml"]
      (Test.describe "thunks" (List.map (fn k => Oracles.job (k, ["thunks-one", k], [], 1, 1000, 3600)) kernels))
end
