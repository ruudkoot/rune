(* rhc's Core simplifier (the haskell98 roadmap's M23): CoreSimplify's
   passes, run at -O2 on the Core of a program, each through Pass.stage, so
   that --dump-after names it, --pass-stats times it and --lint checks it:
   CoreLint at level 2 and HsLint's target check after each pass (the
   check at level 2, RhcLint.targetAfter), Core's text read back at level
   3, and CoreLint again at level 1 on what the last pass leaves, before
   Core to Mid. Each rewrite asks Pass.spend first, so --fuel stops them.
   At -O0 and -O1 no pass runs, and the Core is desugaring's, the Report's
   translation taken literally. *)
structure RhcSimplify =
struct
  (* the level the passes run from: -O2 (rhc's default is -O1, at which
     conformance runs, so that -O0 and -O1 are the Report's translation) *)
  val level = 2

  fun names () = List.map #1 (CoreSimplify.passes ())

  (* Core's text read back, at level 3: print, read, print is the identity *)
  fun roundTrip (p : Core.program) =
    let
      val text = CoreText.show p
      val again = CoreText.parse text
                  handle CoreText.Error (line, msg) =>
                    raise Error.Bug ("Core's text does not read back, at line " ^ Int.toString line ^ ": " ^ msg)
    in
      if again <> p then raise Error.Bug "Core's text reads back as another program"
      else if CoreText.show again <> text then raise Error.Bug "Core's text printed again is other text"
      else ()
    end

  fun enabled () = List.exists (fn (n, _) => Pass.enabled (n, level)) (CoreSimplify.passes ())

  (* the unfoldings a unit gives its clients at -O2, HsIface's section (D44's
     C, M21): the unit's Core through the passes as a unit, not whole, and
     each unfolding the text of Core of its one declaration; and its
     functions' strictness signatures (M24), by name, CoreStrict.show's
     text, of that Core; none below -O2, where nothing reads them *)
  fun sectionsOf (p : Core.program) : string list * (string * string) list =
    if not (enabled ()) then ([], [])
    else
      let
        val opts = {spend = fn () => true, whole = false, eta = !RhcOptions.eta, cheap = !RhcOptions.cheap,
                    library = RhcLibrary.names ()}
        val p' = List.foldl (fn ((_, pass), p) => pass opts p) p (CoreSimplify.passes ())
        val strictness =
          if not (!CoreStrict.enabled) then []
          else
            let val sigs = CoreStrict.signatures p'
            in List.mapPartial (fn Core.Val (f, _, _) => Option.map (fn s => (f, CoreStrict.show s)) (CoreMap.find (sigs, f))
                                 | _ => NONE) p' end
      in (List.map (fn d => CoreText.show [d]) (CoreSimplify.unfoldings p'), strictness) end
      handle Fail msg => raise Error.Bug ("rhc's simplifier fails on a unit, a bug of rhc's: " ^ msg)

  (* the Core p, a program of the files named, through the passes; whole
     where p is the program whole, so that a value main does not reach may
     go *)
  fun run (files : string list, whole : bool, p : Core.program) : Core.program =
    if not (enabled ()) then p
    else
      let
        val opts = {spend = Pass.spend, whole = whole, eta = !RhcOptions.eta, cheap = !RhcOptions.cheap,
                    library = RhcLibrary.names ()}
        fun lint name p =
          (Pass.lintAt name (fn p => CoreLint.check p handle CoreLint.Error msg => raise Error.Bug ("Core after " ^ name ^ ": " ^ msg)) p;
           RhcLint.targetAfter (name, p);
           Pass.checkAt (name, 3) roundTrip p)
        fun one ((name, pass), p) =
          if not (Pass.enabled (name, level)) then p
          else
            Pass.stage {name = name, showIn = NONE, show = CoreText.show, check = lint name, size = List.length}
                       (fn p => pass opts p handle Fail msg => raise Error.Bug ("rhc's " ^ name ^ " fails, a bug of rhc's: " ^ msg)) p
        val () = CoreSimplify.resetCounts ()
        val p' = List.foldl one p (CoreSimplify.passes ())
        (* the crossing into Mid: CoreLint on what the passes leave, at the
           boundary's level *)
        val () = Pass.checkAt ("core-simplify", 1)
                   (fn p => CoreLint.check p handle CoreLint.Error msg => raise Error.Bug ("Core after the simplifier: " ^ msg)) p'
        val () =
          if !RhcOptions.simplifyStats then
            TextIO.output (TextIO.stdErr,
                           String.concat (List.map (fn (w, n) => "simplify " ^ w ^ ": " ^ Int.toString n ^ "\n") (CoreSimplify.counts ()))
                           ^ String.concatWith ", " files ^ ": " ^ Int.toString (List.length p) ^ " declarations, "
                           ^ Int.toString (List.length p') ^ " after\n")
          else ()
      in p' end
end
