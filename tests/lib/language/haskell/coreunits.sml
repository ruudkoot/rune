(* libraries: test/unit *)
(* CoreUnits (the haskell98 roadmap's M21, D44): a unit's interface as Core,
   what a client needs of its exports, and the fingerprints a client's
   usages read: a body's edit moves none, a type's edit moves its own, its
   users' and the values' whose types mention it, and nothing else, and a
   recursive group of types hashes as one. The hash is the text itself, so
   that two fingerprints are equal exactly where what they hash is. *)
structure CoreUnitsTests =
struct
  open Core

  fun need (ok, message) = Expect.that (message, ok)

  fun nameOf d = case d of Data (t, _, _) => t | Newtype (t, _, _, _) => t | Val (x, _, _) => x | Import (x, _) => x
  fun kindOf d = case d of Data _ => "data" | Newtype _ => "newtype" | Val _ => "val" | Import _ => "import"

  fun program text = CoreText.parse text

  val decls =
    ["(data T () (A) (B))", "(data U () (U T))", "(data V () (V))", "(data R () (R S))", "(data S () (S R) (E))",
     "(newtype N () N U)", "(val f (-> U Int) (\\ ((u U)) 1))", "(val g Int 2)", "(val h (-> R Int) (\\ ((r R)) 3))",
     "(val k (-> N Int) (\\ ((n N)) 4))"]
  fun unit (edit : string -> string) = program (String.concatWith "\n" (List.map edit decls))
  val exports = ["f", "g", "h", "k", "V"]
  fun prints edit = CoreUnits.fingerprints (fn s => s) (CoreUnits.interface (unit edit, exports))
  fun printOf (fps, x) = case List.find (fn (n, _) => n = x) fps of SOME (_, f) => f | NONE => "absent " ^ x
  fun same (a, b, x) = printOf (a, x) = printOf (b, x)

  fun interface () =
    let
      val i = CoreUnits.interface (unit (fn d => d), ["f", "V"])
      val () = need (List.map (fn d => kindOf d ^ " " ^ nameOf d) i = ["data T", "data U", "data V", "import f"],
                     "the exported value imported, the types its type reaches and the exported type declared, in order: "
                     ^ String.concatWith ", " (List.map nameOf i))
      val () =
        case List.find (fn d => nameOf d = "f") i of
          SOME (Import (_, t)) => need (CoreText.showTy t = "(-> U Int)", "the value at its type")
        | _ => need (false, "f is an import")
      val all = CoreUnits.interface (unit (fn d => d), exports)
      val () = need (List.exists (fn d => nameOf d = "R") all andalso List.exists (fn d => nameOf d = "S") all,
                     "a type reached through another type's field")
      val () = need (not (List.exists (fn d => nameOf d = "T") (CoreUnits.interface (unit (fn d => d), ["g"]))),
                     "a type no export mentions is not there")
    in () end

  fun fingerprints () =
    let
      val earlier = prints (fn d => d)
      val body = prints (fn d => if String.isPrefix "(val f" d then "(val f (-> U Int) (\\ ((u U)) 99))" else d)
      val () = need (List.all (fn (x, _) => same (earlier, body, x)) earlier, "a body's edit moves no fingerprint")
      val t = prints (fn d => if d = "(data T () (A) (B))" then "(data T () (A) (B) (C))" else d)
      val () = need (not (same (earlier, t, "T")), "a type's edit moves its fingerprint")
      val () = need (not (same (earlier, t, "U")), "and that of a type whose field mentions it")
      val () = need (not (same (earlier, t, "f")), "and that of a value whose type mentions it")
      val () = need (not (same (earlier, t, "N")) andalso not (same (earlier, t, "k")), "through a newtype too")
      val () = need (same (earlier, t, "V") andalso same (earlier, t, "g") andalso same (earlier, t, "h")
                     andalso same (earlier, t, "R"), "and nothing else's")
      val () = need (printOf (earlier, "R") = printOf (earlier, "S"), "a recursive group hashes as one")
      val s = prints (fn d => if String.isPrefix "(data S" d then "(data S () (S R))" else d)
      val () = need (not (same (earlier, s, "R")) andalso not (same (earlier, s, "h")),
                     "an edit of one of a group moves the group's and its users'")
      val g = prints (fn d => if String.isPrefix "(val g" d then "(val g Char 'x')" else d)
      val () = need (not (same (earlier, g, "g")) andalso same (earlier, g, "f"), "a value's type in its own fingerprint alone")
    in () end

  (* what main reaches: values through their bodies, a constructor its
     type, a type its fields' types; nothing else *)
  fun reach () =
    let
      val p = program (String.concatWith "\n"
                ["(data T () (A) (B))", "(data U () (U T))", "(data V () (V))", "(data W () (W U))",
                 "(val f (-> Int U) (\\ ((n Int)) (case (con A) a (_ (con U a)))))", "(val g Int 2)",
                 "(val h (-> Int Int) (\\ ((n Int)) (f n)))", "(val main (-> World (utuple World Int)) (\\ ((w World)) (case (h 1) r (_ (utuple w 0)))))"])
      val kept = List.map nameOf (CoreUnits.reach (p, ["main"]))
      val () = need (kept = ["T", "U", "f", "h", "main"], "main reaches h, f, U and T, in the program's order: "
                                                           ^ String.concatWith ", " kept)
    in () end
end

structure CoreUnitsTestMain = Main (struct
  val name = "language-haskell-coreunits"
  val tests = Test.describe "coreunits"
                [Test.it "interface" CoreUnitsTests.interface, Test.it "fingerprints" CoreUnitsTests.fingerprints,
                 Test.it "reach" CoreUnitsTests.reach]
end)
val () = CoreUnitsTestMain.main ()
