(* The tools' times as JSON (tools/lsp/seconds.sml): every time a check can
   take writes as a JSON number that reads back as itself, to the
   microsecond. Real.toString wrote a whole millisecond under 10 ms as 3E~3,
   which Json.write refuses with Domain: the oracle died so, now and then,
   at a check that took 3 ms to the microsecond. *)
structure RuneLspSecondsTests =
struct
  val check=Expect.that
  fun written seconds=(SOME (Json.encode (RuneLspSeconds.json seconds))) handle Domain => NONE
  fun readBack text=case Json.decode text of Json.Number digits => Real.fromString digits | _ => NONE
  fun times ()=
    List.app (fn seconds =>
      case written seconds of
        NONE => check ("a time of " ^ Real.toString seconds ^ " s writes as a JSON number",false)
      | SOME text => check ("a time of " ^ Real.toString seconds ^ " s writes as " ^ text ^ " and reads back",
          case readBack text of SOME back => Real.abs (back-seconds)<0.0000005 | NONE => false))
      [0.003,0.002,0.001,0.0005,0.00009,0.000001,0.0,0.003261,0.012,1.0,12.5,557.5,~0.001,~0.000004]
end
structure RuneLspSecondsTestMain=Main (struct
  val name="lsp-seconds"
  val tests=Test.describe "lsp-seconds" [Test.it "times-as-json" RuneLspSecondsTests.times]
end)
val ()=RuneLspSecondsTestMain.main ()
