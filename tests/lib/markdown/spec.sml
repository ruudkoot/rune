(* libraries: test/unit json *)
(* Markdown against CommonMark's examples (tests/lib/markdown/spec.json,
   the 652 of CommonMark 0.31.2), one test for each: the HTML of each must
   be the spec's.
   The examples of tests/lib/markdown/known.txt, which the library does
   not read as CommonMark does, are left out, each with its reason, and
   must still differ, so that the list shrinks when the library learns. *)
structure SpecTest =
struct
  val check = Expect.that

  fun readFile path =
    let val i = TextIO.openIn path in TextIO.inputAll i before TextIO.closeIn i end

  (* known.txt: lines `NUMBER | reason` *)
  val known =
    List.mapPartial (fn l => case String.fields (fn c => c = #"|") l of
                               n :: _ => Int.fromString n
                             | [] => NONE)
                    (List.filter (fn l => l <> "" andalso String.sub (l, 0) <> #"#")
                                 (String.fields (fn c => c = #"\n") (readFile "tests/lib/markdown/known.txt")))

  val examples = case Json.decode (readFile "tests/lib/markdown/spec.json") of Json.Array xs => xs | _ => []
  (* -v prints what an example that fails gave *)
  val verbose = List.exists (fn a => a = "-v") (CommandLine.arguments ())
  fun field (name, x) = case Json.member (name, x) of SOME (Json.String s) => s | _ => ""
  fun number x = valOf (Json.toInt (valOf (Json.member ("example", x))))

  fun one x () =
    let
      val n = number x
      val got = Markdown.toHtml (Markdown.parse (field ("markdown", x)))
                handle e => "raised " ^ General.exnMessage e
      val ok = got = field ("html", x)
      val isKnown = List.exists (fn k => k = n) known
    in
      if verbose andalso not ok then
        print ("example " ^ Int.toString n ^ " (" ^ field ("section", x) ^ "):\n" ^ field ("markdown", x)
               ^ "--- want\n" ^ field ("html", x) ^ "--- got\n" ^ got ^ "\n")
      else ();
      if isKnown then check ("example " ^ Int.toString n ^ " is known not to pass but does", not ok)
      else check ("example " ^ Int.toString n ^ " (" ^ field ("section", x) ^ ")", ok)
    end

  val tests =
    Test.describe "markdown/spec" (map (fn x => Test.it ("example-" ^ Int.toString (number x)) (one x)) examples)
end

structure SpecMain = Main (struct val name = "markdown/spec" val tests = SpecTest.tests end)
val () = SpecMain.main ()
