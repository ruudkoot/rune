(* libraries: test/unit unicode *)
(* rhc's runtime (CoreRuntime) against lib/unicode's CodePoint (D21): one
   Core program, run on the Core interpreter, gives for each code point of
   a list its general category by the runtime's tables, its four classes
   by primUnicodeIsUpper, IsLower, IsAlphaNum and IsPrint, and its
   mappings by primUnicodeToUpper and ToLower; each is held to what
   CodePoint says, the classes by their definitions (R38): upper a letter
   not lower case, lower Ll, alphanumeric a letter or a number, printable
   neither Zl, Zp nor of class C. The code points: every one below 0x100,
   every 499th, and the first and the last of each range of categories and
   of each run of mappings in lib/unicode's data. The Core interpreter and
   the VM agree on the same text (tests/hs/core/runtime-unicode.core). Run
   from the top of the tree. *)
structure CoreRuntimeTest =
struct
  structure C = CodePoint
  structure D = UnicodeCodePointData

  val top = 0x10FFFF

  (* the code points tried, each once, in order *)
  val points =
    let
      fun edges (v : int vector, width) =
        List.concat (List.tabulate (Vector.length v div width, fn i =>
          [Vector.sub (v, width * i), Vector.sub (v, width * i + 1)]))
      val all = List.tabulate (0x100, fn c => c) @ List.tabulate (top div 499 + 1, fn i => 499 * i)
                @ [top] @ edges (D.category (), 3) @ edges (D.upper (), 4) @ edges (D.lower (), 4)
      val seen = Array.array (top + 1, false)
      val () = List.app (fn c => if c >= 0 andalso c <= top then Array.update (seen, c, true) else ()) all
    in
      Array.foldri (fn (c, true, acc) => c :: acc | (_, false, acc) => acc) [] seen
    end

  (* four digits of base 64 from "0" *)
  fun digits n = String.implode (List.tabulate (4, fn i => Char.chr (48 + (n div (case i of 0 => 262144 | 1 => 4096 | 2 => 64 | _ => 1)) mod 64)))

  (* a line for each code point: its category's number, the classes as U,
     L, A, P or a dot, the upper and the lower case *)
  val text = String.concatWith "\n"
    ["(val flag (-> Bool !Str Str) (\\ ((b Bool) (s !Str)) (case b v ((True) s) ((False) \".\"))))",
     "(val num (-> !Int Str) (\\ ((n !Int))",
     "  (case (prim int_lt n 10) small",
     "    ((True) (case (prim int_add n 48) c (_ (case (prim char_chr c) ch (_ (prim str_from_char ch))))))",
     "    ((False) (case (prim int_quot n 10) q (_ (case (prim int_rem n 10) r",
     "      (_ (case (num q) a (_ (case (num r) b (_ (prim str_concat a b)))))))))))))",
     "(val say (-> !Str World (utuple World `()`))",
     "  (\\ ((s !Str) (w World)) (case (prim print_str s w) w1 (_ (let (u `()` (con `()`)) (utuple w1 u))))))",
     "(val one (-> !Int World (utuple World `()`))",
     "  (\\ ((i !Int) (w World))",
     "    (let (c Char (primIntToChar i))",
     "    (case (rtCategory i) g (_ (case (num g) gs",
     "    (_ (let (u Bool (primUnicodeIsUpper c)) (let (l Bool (primUnicodeIsLower c))",
     "       (let (a Bool (primUnicodeIsAlphaNum c)) (let (p Bool (primUnicodeIsPrint c))",
     "       (case (flag u \"U\") fu (_ (case (flag l \"L\") fl (_ (case (flag a \"A\") fa (_ (case (flag p \"P\") fp",
     "       (_ (case (primUnicodeToUpper c) up (_ (case (primUnicodeToLower c) lo",
     "       (_ (case (prim char_ord up) ui (_ (case (prim char_ord lo) li",
     "       (_ (case (num ui) us (_ (case (num li) ls",
     "       (_ (case (prim str_concat gs \" \") t1 (_ (case (prim str_concat t1 fu) t2 (_ (case (prim str_concat t2 fl) t3",
     "       (_ (case (prim str_concat t3 fa) t4 (_ (case (prim str_concat t4 fp) t5 (_ (case (prim str_concat t5 \" \") t6",
     "       (_ (case (prim str_concat t6 us) t7 (_ (case (prim str_concat t7 \" \") t8 (_ (case (prim str_concat t8 ls) t9",
     "       (_ (case (prim str_concat t9 \"\\n\") t10 (_ (say t10 w))))))))))))))))))))))))))))))))))))))))))))))))))))",
     "(val go (-> !Int World (utuple World `()`))",
     "  (\\ ((j !Int) (w World))",
     "    (case points ps (_ (case (prim str_size ps) n",
     "      (_ (case (prim int_ge j n) done",
     "           ((True) (let (u `()` (con `()`)) (utuple w u)))",
     "           ((False) (case (rtNum4 ps j) i (_ (case (one i w) o ((utuple w1 _) (case (prim int_add j 4) k (_ (go k w1)))))))))))))))",
     "(val main (-> World (utuple World `()`)) (\\ ((w World)) (go 0 w)))"]

  (* the lines the program prints *)
  val printed =
    let
      val buf = ref []
      val p = Core.Val ("points", Core.TCon "Str", Core.Atom (Core.Lit (Core.LStr (String.concat (List.map digits points)))))
              :: CoreText.parse text
      val prog = CoreRuntime.link CoreRuntime.Lazy p
      val () = CoreLint.check prog
      val {outcome, ...} = CoreInterp.run {program = prog, steps = NONE, depth = 10000000,
                                           out = fn s => buf := s :: !buf, err = fn _ => ()}
    in
      case outcome of
        CoreInterp.Exit 0 => String.tokens (fn c => c = #"\n") (String.concat (List.rev (!buf)))
      | _ => []
    end

  val abbreviations =
    ["Lu", "Ll", "Lt", "Lm", "Lo", "Mn", "Mc", "Me", "Nd", "Nl", "No", "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po",
     "Sm", "Sc", "Sk", "So", "Zs", "Zl", "Zp", "Cc", "Cf", "Cs", "Co", "Cn"]

  (* what the line of c should be, by CodePoint *)
  fun wanted c =
    let
      val g = C.category c
      val a = C.abbreviation g
      val n = #1 (valOf (List.find (fn (_, x) => x = a) (ListPair.zip (List.tabulate (30, fn i => i), abbreviations))))
      fun flag (b, s) = if b then s else "."
      val upper = C.major g = C.Letter andalso g <> C.LowercaseLetter
      val lower = g = C.LowercaseLetter
      val alnum = C.major g = C.Letter orelse C.major g = C.Number
      val print = not (C.major g = C.Other orelse g = C.LineSeparator orelse g = C.ParagraphSeparator)
    in
      Int.toString n ^ " " ^ flag (upper, "U") ^ flag (lower, "L") ^ flag (alnum, "A") ^ flag (print, "P") ^ " "
      ^ Int.toString (C.toUpper c) ^ " " ^ Int.toString (C.toLower c)
    end

  fun agree () =
    let
      val () = Expect.that ("a line for each code point", length printed = length points)
      val wrong = List.filter (fn (c, l) => l <> wanted c) (ListPair.zip (points, printed))
    in
      case wrong of
        [] => Expect.that ("every code point as CodePoint has it", true)
      | (c, l) :: _ => Expect.that ("U+" ^ Int.fmt StringCvt.HEX c ^ ": the runtime gives " ^ l ^ ", CodePoint " ^ wanted c
                                    ^ " (" ^ Int.toString (length wrong) ^ " differ)", false)
    end

  val tests =
    Test.describe "language/haskell/coreruntime"
      [Test.it "many code points tried" (fn () => Expect.that ("more than 4000", length points > 4000)),
       Test.it "the runtime agrees with CodePoint" agree,
       Test.it "every prim of the Report is the runtime's" (fn () =>
         let val made = List.mapPartial (fn Core.Val (x, _, _) => SOME x | _ => NONE) (CoreRuntime.program CoreRuntime.Lazy)
         in List.app (fn n => Expect.that (n, List.exists (fn x => x = n) made)) CoreRuntime.reportNames end)]
end

structure CoreRuntimeMain = Main (struct val name = "language/haskell/coreruntime" val tests = CoreRuntimeTest.tests end)
val () = CoreRuntimeMain.main ()
