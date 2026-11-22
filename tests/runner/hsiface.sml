(* The renamer's and the checker's part of rhc's interfaces and usages
   (the haskell98 roadmap's M21, D44, E13's H1 to H9; src/rhc/iface.sml,
   lib/language/haskell/modiface.sml, usage.sml).

   - `hs/iface/units/accept/K-of-N`, `hs/iface/units/errors/K-of-N`,
     `hs/iface/units/lang/K-of-N`: every program of the directory checked
     group by group from the interfaces of the groups before it, the
     library's among them (`bin/rhc --typecheck-only --by-interface`),
     prints what a whole check prints, standard output and error, and ends
     with its status: an interface holds all a client is named and checked
     by. Nightly, every shard: each program checks the library's groups by
     interface too, about twice a whole check's cost.
   - `hs/iface/fingerprints/CASE`: each case of tests/hs/iface/fingerprints
     a program `before/All.hs` and the same after an edit, `after/All.hs`,
     with `moves`, the items whose fingerprints the edit moves, a key a line
     as `bin/rhc --dump-iface` prints it (its tabs as spaces): an item added
     or gone moves, and every other must stay (H5, H6, a body's edit moving
     nothing, a recursive group as one).
   - `hs/iface/usages/NAME`: each program of tests/hs/iface/usages against
     `NAME.usages`, what `bin/rhc --dump-usages` says of it, a name looked
     up and not found among it (H1), an instance looked up and absent (H2),
     `module M`'s exports (H7), the Prelude's names the translations ask
     for (H9); written again with --accept. *)
structure HsIfaceJobs =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")

  val dir = "tests/hs/iface"
  fun rhc () = fromRoot "bin/rhc"

  val compareOne = HsSnapshotJobs.compareWith {family = "hs/iface/units", way = "by interface", flags = ["--by-interface"]}

  fun compareShard (kind, k, n) = List.app (fn p => compareOne (kind, p)) (HsSnapshotJobs.shardOf (kind, k, n))

  (* ---- fingerprints ---- *)

  fun detab s = String.translate (fn #"\t" => " " | c => str c) s

  (* the FP lines of a dump: each key (tabs as spaces) and its fingerprint *)
  fun fingerprintsOf file =
    List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                               "FP" :: rest =>
                                 (case List.rev rest of
                                    fp :: keyParts => SOME (detab (String.concatWith "\t" (List.rev keyParts)), fp)
                                  | [] => NONE)
                             | _ => NONE)
      (lines (read file))

  fun fingerprintCases () =
    let val d = fromRoot (dir ^ "/fingerprints")
    in if isDir d then List.filter (fn c => isDir (d ^ "/" ^ c)) (sort (entries d)) else [] end

  fun fingerprintOne name =
    let
      val d = fromRoot (dir ^ "/fingerprints/" ^ name)
      val out = run ^ "/hs-iface/fingerprints/" ^ name
      val () = mkdirs out
      fun dump side =
        let
          val file = out ^ "/" ^ side ^ ".iface"
          val status = exec {cmd = [rhc (), "--dump-iface", d ^ "/" ^ side ^ "/All.hs"], dir = SOME root, stdin = "",
                             stdout = file, stderr = file ^ ".err", timeout = 600}
        in
          if status <> 0 orelse read (file ^ ".err") <> "" then
            (fail ("hs/iface/fingerprints/" ^ name ^ ": " ^ side ^ ": " ^ firstLine (file ^ ".err")); NONE)
          else SOME (fingerprintsOf file)
        end
    in
      case (dump "before", dump "after") of
        (SOME a, SOME b) =>
          let
            fun find (xs, k) = Option.map #2 (List.find (fn (k', _) => k' = k) xs)
            val keys = sort (List.foldl (fn ((k, _), ks) => if List.exists (fn x => x = k) ks then ks else k :: ks) []
                                         (a @ b))
            val moved = List.filter (fn k => find (a, k) <> find (b, k)) keys
            val want = sort (List.map detab (lines (read (d ^ "/moves"))))
            val extra = List.filter (fn k => not (List.exists (fn w => w = k) want)) moved
            val stayed = List.filter (fn w => not (List.exists (fn k => k = w) moved)) want
          in
            List.app (fn k => fail ("hs/iface/fingerprints/" ^ name ^ ": `" ^ k ^ "` moves, which `moves` does not list")) extra;
            List.app (fn k => fail ("hs/iface/fingerprints/" ^ name ^ ": `" ^ k ^ "` stays, which `moves` says moves")) stayed
          end
      | _ => ()
    end

  (* ---- usages ---- *)

  fun usageCases () =
    let val d = fromRoot (dir ^ "/usages")
    in if isDir d then List.filter (fn c => isDir (d ^ "/" ^ c)) (sort (entries d)) else [] end

  fun usageOne name =
    let
      val d = fromRoot (dir ^ "/usages/" ^ name)
      val out = run ^ "/hs-iface/usages/" ^ name
      val () = mkdirs out
      val file = out ^ "/usages"
      val status = exec {cmd = [rhc (), "--dump-usages", d ^ "/All.hs"], dir = SOME root, stdin = "", stdout = file,
                         stderr = file ^ ".err", timeout = 600}
      val expected = d ^ ".usages"
    in
      if status <> 0 orelse read (file ^ ".err") <> "" then
        fail ("hs/iface/usages/" ^ name ^ ": " ^ firstLine (file ^ ".err"))
      else if accepting then write (expected, read file)
      else if read file = read expected then ()
      else fail ("hs/iface/usages/" ^ name ^ ": the reads differ from " ^ dir ^ "/usages/" ^ name ^ ".usages: " ^
                 HsSnapshotJobs.firstDifferenceBy "now" (read file, read expected))
    end

  (* ---- the tree ---- *)

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*", "covers:tests/hs/accept/*",
                "covers:tests/hs/lang/*", "covers:tests/hs/errors/*", "covers:tests/hs/iface/*",
                "covers:tests/runner/hsiface.sml", "covers:rhc.build", "covers:rhc.plan"]

  fun tree () =
    let
      val cmd = "\"$RUNE_TEST_ROOT\"/bin/rune-test "
      val job = HsSnapshotJobs.job
      fun shardJobs kind =
        List.tabulate (HsSnapshotJobs.shards, fn i =>
                                 let val k = Int.toString (i + 1) ^ "-of-" ^ Int.toString HsSnapshotJobs.shards
                                 in Test.tag "nightly"
                                      (job ("units/" ^ kind ^ "/" ^ k, cmd ^ "hs-iface-shard " ^ kind ^ " " ^ k, 3600)) end)
    in
      Test.describe "hs/iface"
        [HsSnapshotJobs.tagged (["hs"] @ covers)
           (Test.requires ["rhc"]
              (Test.describe ""
                 (List.map (fn c => Test.tag "check" (job ("fingerprints/" ^ c, cmd ^ "hs-iface-fingerprints " ^ quote c, 600)))
                     (fingerprintCases ())
                  @ List.map (fn c => Test.tag "check" (job ("usages/" ^ c, cmd ^ "hs-iface-usages " ^ quote c, 600)))
                      (usageCases ())
                  @ List.concat (List.map shardJobs HsSnapshotJobs.kinds))))]
    end

  fun command args =
    case args of
      ["hs-iface-fingerprints", name] => SOME (fn () => fingerprintOne name)
    | ["hs-iface-usages", name] => SOME (fn () => usageOne name)
    | ["hs-iface-shard", kind, kn] =>
        (case String.fields (fn c => c = #"-") kn of
           [k, "of", n] =>
             (case (Int.fromString k, Int.fromString n) of
                (SOME k, SOME n) => SOME (fn () => compareShard (kind, k, n))
              | _ => NONE)
         | _ => NONE)
    | _ => NONE
end
