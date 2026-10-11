(* libraries: json *)
(* Markdown against CommonMark's examples (tests/lib/markdown/spec.json,
   the 652 of CommonMark 0.31.2): the HTML of each must be the spec's.
   The examples of tests/lib/markdown/known.txt, which the library does
   not read as CommonMark does, are left out, each with its reason, and
   must still differ, so that the list shrinks when the library learns. *)
structure SpecTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  fun readFile path =
    let val i = TextIO.openIn path in TextIO.inputAll i before TextIO.closeIn i end

  (* known.txt: lines `NUMBER | reason` *)
  val known =
    List.mapPartial (fn l => case String.fields (fn c => c = #"|") l of
                               n :: _ => Int.fromString n
                             | [] => NONE)
                    (List.filter (fn l => l <> "" andalso String.sub (l, 0) <> #"#")
                                 (String.fields (fn c => c = #"\n") (readFile "tests/lib/markdown/known.txt")))

  fun main () =
    let
      val examples = case Json.decode (readFile "tests/lib/markdown/spec.json") of Json.Array xs => xs | _ => []
      val verbose = List.exists (fn a => a = "-v") (CommandLine.arguments ())
      fun field (name, x) = case Json.member (name, x) of SOME (Json.String s) => s | _ => ""
      val passed = ref 0
      fun one x =
        let
          val n = valOf (Json.toInt (valOf (Json.member ("example", x))))
          val got = Markdown.toHtml (Markdown.parse (field ("markdown", x)))
                    handle e => "raised " ^ General.exnMessage e
          val ok = got = field ("html", x)
          val isKnown = List.exists (fn k => k = n) known
        in
          if ok then passed := !passed + 1 else ();
          if verbose andalso not ok then
            print ("example " ^ Int.toString n ^ " (" ^ field ("section", x) ^ "):\n" ^ field ("markdown", x)
                   ^ "--- want\n" ^ field ("html", x) ^ "--- got\n" ^ got ^ "\n")
          else ();
          if isKnown then check ("example " ^ Int.toString n ^ " is known not to pass but does", not ok)
          else check ("example " ^ Int.toString n ^ " (" ^ field ("section", x) ^ ")", ok)
        end
    in
      List.app one examples;
      print ("markdown: " ^ Int.toString (!passed) ^ " of " ^ Int.toString (List.length examples)
             ^ " CommonMark examples, " ^ Int.toString (List.length known) ^ " known not to pass\n");
      print ((if !failures = 0 then "PASS" else "FAIL") ^ " markdown spec: " ^ Int.toString (!failures) ^ " failed\n")
    end
end

val () = SpecTest.main ()
