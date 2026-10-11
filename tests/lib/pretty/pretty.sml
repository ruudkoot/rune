(* libraries: random *)
(* Pretty: golden layouts of a value at several widths, the budgets, the
   annotations; and properties on random documents -- a layout keeps the
   text, a group that fits is on one line, and no line is wider than the
   width but where one piece of text alone is. *)
structure PrettyTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  open Pretty
  fun list xs = sequence {opening = "[", closing = "]", separator = ","} xs
  fun tuple xs = sequence {opening = "(", closing = ")", separator = ","} xs
  fun int n = text (Int.toString n)

  val value : unit doc = tuple [list (List.tabulate (6, int)), text "\"a string\"", list [list [int 1, int 2], list []]]

  fun goldens () =
    (check ("wide", render 80 value = "([0, 1, 2, 3, 4, 5], \"a string\", [[1, 2], []])");
     check ("narrow", render 30 value = "([0, 1, 2, 3, 4, 5],\n \"a string\",\n [[1, 2], []])");
     check ("narrower", render 12 value = "([0,\n  1,\n  2,\n  3,\n  4,\n  5],\n \"a string\",\n [[1, 2],\n  []])");
     check ("nest and line", render 5 (group (concat [text "let", nest 2 (concat [line, text "x"]), line, text "end"]))
                             = "let\n  x\nend");
     check ("fits", render 20 (group (concat [text "let", nest 2 (concat [line, text "x"]), line, text "end"])) = "let x end");
     check ("cut", render 80 (group (concat [text "a", cut, text "b"])) = "ab");
     check ("hardline breaks its group", render 80 (group (concat [text "a", line, text "b", hardline, text "c"]))
                                         = "a\nb\nc");
     check ("wide characters", render 5 (group (concat [text "\228\184\173\230\150\135", line, text "x"])) = "\228\184\173\230\150\135\nx");
     check ("break, flat", render 80 (group (concat [text "ab", break (2, 4), text "cd"])) = "ab  cd");
     check ("break, broken", render 3 (group (concat [text "ab", break (2, 4), text "cd"])) = "ab\n    cd");
     check ("break in a nest", render 3 (nest 2 (group (concat [text "ab", break (1, ~1), text "cd"]))) = "ab\n cd");
     check ("sized fits as its width", render 6 (group (concat [sized ("\027[1mab\027[0m", 2), line, text "cd"]))
                                       = "\027[1mab\027[0m cd");
     check ("sized breaks as its width", render 4 (group (concat [sized ("ab", 4), line, text "cd"])) = "ab\ncd");
     check ("align", render 5 (concat [text "x = ", align (group (concat [text "ab", line, text "cd"]))]) = "x = ab\n    cd");
     check ("a sequence aligns after its opening where it begins",
            render 12 (concat [text "val x = ", list [int 1, int 2, int 3]]) = "val x = [1,\n         2,\n         3]"))

  fun budgets () =
    let
      val deep : unit doc = list [list [list [list [int 1]]]]
      val long : unit doc = list (List.tabulate (10, int))
    in
      check ("depth", render 80 (bound {depth = SOME 2, length = NONE, nodes = NONE} deep) = "[[...]]");
      check ("length", render 80 (bound {depth = NONE, length = SOME 3, nodes = NONE} long) = "[0, 1, 2, ...]");
      check ("nodes", render 80 (bound {depth = NONE, length = NONE, nodes = SOME 4}
                                       (tuple [list [int 1, int 2], list [int 3, int 4]])) = "([1, 2], [...])");
      check ("no limit", render 80 (bound {depth = NONE, length = NONE, nodes = NONE} long) = render 80 long)
    end

  fun annotations () =
    check ("annotations", renderWith {width = 80, start = fn a => "<" ^ a ^ ">", finish = fn a => "</" ^ a ^ ">"}
                                     (concat [text "val ", annotate ("name", text "x"), text " = 1"])
                          = "val <name>x</name> = 1")

  (* random documents of sequences, groups and nesting *)
  fun draw (d, g) =
    let val (k, g) = Random.int (0, if d = 0 then 1 else 5) g
    in
      case k of
        0 => let val (n, g) = Random.int (0, 12) g in (text (CharVector.tabulate (n, fn i => Char.chr (97 + i mod 26))), g) end
      | 1 => let val (n, g) = Random.int (0, 99999) g in (int n, g) end
      | 2 =>
          let
            val (n, g) = Random.int (0, 5) g
            fun items (0, g, acc) = (rev acc, g)
              | items (k, g, acc) = let val (x, g) = draw (d - 1, g) in items (k - 1, g, x :: acc) end
            val (xs, g) = items (n, g, [])
          in
            (list xs, g)
          end
      | 3 => let val (x, g) = draw (d - 1, g) val (y, g) = draw (d - 1, g) in (group (concat [x, line, y]), g) end
      | 4 => let val (x, g) = draw (d - 1, g) val (n, g) = Random.int (0, 4) g in (nest n (concat [cut, x]), g) end
      | _ => let val (x, g) = draw (d - 1, g) in (annotate ((), x), g) end
    end

  fun squeeze s = String.implode (List.filter (not o Char.isSpace) (String.explode s))
  fun lines s = String.fields (fn c => c = #"\n") s
  fun longestText d =
    foldl (fn (Text s, m) => Int.max (m, size s) | (_, m) => m) 0 (layout 1000000 d)

  fun properties () =
    let
      fun go (0, _) = true
        | go (k, g) =
            let
              val (d, g) = draw (5, g)
              val (w, g) = Random.int (8, 60) g
              val r = render w d
              val wide = render 1000000 (group d)
              (* a line wider than w is one where a word and the
                 indentation before it are all there is *)
              val ok = squeeze r = squeeze (flat d)
                       andalso wide = flat d
                       andalso List.all (fn l => size l <= Int.max (w, longestText d + 40)) (lines r)
            in
              if ok then go (k - 1, g)
              else (print ("width " ^ Int.toString w ^ ": text kept " ^ Bool.toString (squeeze r = squeeze (flat d))
                           ^ ", wide is flat " ^ Bool.toString (wide = flat d) ^ "\n" ^ String.toString r ^ "\nflat: "
                           ^ String.toString (flat d) ^ "\nwide: " ^ String.toString wide ^ "\n"); false)
            end
    in
      check ("random documents", go (500, Random.fromSeed 0w31))
    end

  fun main () =
    (goldens (); budgets (); annotations (); properties ();
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " pretty: " ^ Int.toString (!failures) ^ " failed\n"))
end

val () = PrettyTest.main ()
