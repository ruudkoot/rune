(* libraries: test/unit *)
(* Json.decode against JSONTestSuite's parsing tests (tests/lib/json/parsing,
   README there), one test for each file: a file named y_ must be read, one
   named n_ refused with Json.Syntax, and one named i_ either, but with no
   other exception. Run from the top of the tree. *)
structure JsonSuite =
struct
  val dir = "tests/lib/json/parsing"

  fun read path =
    let
      val f = BinIO.openIn path
      val s = Byte.bytesToString (BinIO.inputAll f)
    in
      BinIO.closeIn f; s
    end

  (* the files in the order of their names *)
  fun files () =
    let
      val d = OS.FileSys.openDir dir
      fun insert (f, []) = [f]
        | insert (f, g :: gs) = if f <= g then f :: g :: gs else g :: insert (f, gs)
      fun go acc =
        case OS.FileSys.readDir d of
          NONE => (OS.FileSys.closeDir d; acc)
        | SOME f => go (if String.isSuffix ".json" f then insert (f, acc) else acc)
    in
      go []
    end

  datatype outcome = Accepted | Refused | Raised of string

  fun outcome text =
    (ignore (Json.decode text); Accepted)
    handle Json.Syntax _ => Refused
         | e => Raised (exnName e)

  fun judge name () =
    let
      val got = outcome (read (dir ^ "/" ^ name))
      val ok =
        case (String.sub (name, 0), got) of
          (#"y", Accepted) => true
        | (#"n", Refused) => true
        | (#"i", Accepted) => true
        | (#"i", Refused) => true
        | _ => false
    in
      Expect.that (name ^ ": " ^ (case got of Accepted => "accepted" | Refused => "refused" | Raised e => "raised " ^ e), ok)
    end

  val tests =
    Test.describe "json/suite" (map (fn name => Test.it (String.substring (name, 0, size name - 5)) (judge name)) (files ()))
end

structure JsonSuiteMain = Main (struct val name = "json/suite" val tests = JsonSuite.tests end)
val () = JsonSuiteMain.main ()
