(* A unit's Mid text naming another unit's global (the haskell98 roadmap's
   M21): MidText.parseWith's named gives a name of the text a stamp of the
   client's, as a front end that compiles in units names another unit's
   global, and every other name a fresh one, as before. Unit A defines gf;
   unit B's text uses gf, which named gives A's stamp, and a gf of its own
   would be another. *)
structure NamedTests =
struct
  structure M = Mid

  fun need (ok, message) = Expect.that (message, ok)

  val counter = ref 1000
  fun fresh () = !counter before counter := !counter + 1
  fun tycon () = #stamp (Types.freshTycon ("", 0, true))

  val unitA = "(funs (fn gf ((vx : int)) : int (return vx)))\n"
  val unitB = "(val gy : int (return (app gf 41)))\n(val gz : int (return (app gh 1)))\n"
  val unitH = "(funs (fn gh ((vx : int)) : int (return vx)))\n"

  (* the stamps of the globals a program defines, by its text's order *)
  fun defined (p : M.program) : int list =
    List.concat (List.map (fn M.Funs fs => List.map #name fs | M.Val (g, _, _) => [g] | _ => []) p)
  (* the global each Val of p applies *)
  fun applied (p : M.program) : int list =
    List.mapPartial (fn M.Val (_, _, M.Return (M.App (M.Global (g, _), _))) => SOME g | _ => NONE) p

  fun named () =
    let
      val a = MidText.parseWith {stamp = fresh, tycon = tycon, named = fn _ => NONE} unitA
      val gf = case defined a of [g] => g | _ => ~1
      val () = need (gf >= 1000, "unit A defines gf")
      val asked = ref ([] : string list)
      fun names s = (asked := s :: !asked; if s = "gf" then SOME gf else NONE)
      val b = MidText.parseWith {stamp = fresh, tycon = tycon, named = names} unitB
      val () =
        case applied b of
          [f, h] =>
            (need (f = gf, "unit B's gf is unit A's: " ^ Int.toString f ^ " and " ^ Int.toString gf);
             need (h <> gf andalso h >= 1000, "a name named gives none of is a fresh stamp"))
        | _ => need (false, "unit B applies two globals")
      val () = need (List.exists (fn s => s = "gf") (!asked), "named is asked of the name")
      val () = need (List.length (List.filter (fn s => s = "gf") (!asked)) = 1, "once, the name kept after")
      val again = MidText.parseWith {stamp = fresh, tycon = tycon, named = fn _ => NONE} unitB
      val () =
        case applied again of
          [f, _] => need (f <> gf, "without named, gf is the text's own")
        | _ => need (false, "unit B applies two globals")
      val h = MidText.parseWith {stamp = fresh, tycon = tycon, named = fn _ => NONE} unitH
      val () = need (defined h <> [gf], "another unit's gf of its own is another stamp")
    in () end
end

structure NamedTestMain = Main (struct
  val name = "rhc-named"
  val tests = Test.describe "rhc-named" [Test.it "named" NamedTests.named]
end)
val () = NamedTestMain.main ()
