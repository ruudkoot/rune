(* requires: Date Time StringCvt *)
(* uses: spec-sigs/DATE.sml *)
(* Date matches DATE; the datatypes, the date type and the exception seen
   through the signature are those of the structure. *)
structure TestDateSig =
struct
  structure C : SPEC_DATE = Date
  val () = T.check ("Date:DATE/matches", fn () => true)
  val () = T.check ("Date:DATE/weekday-is-Date.weekday",
                    fn () => (C.Mon : Date.weekday) = Date.Mon andalso (Date.Sun : C.weekday) <> C.Sat)
  val () = T.check ("Date:DATE/month-is-Date.month",
                    fn () => (C.Jan : Date.month) = Date.Jan andalso (Date.Dec : C.month) <> C.Nov)
  val () = T.check ("Date:DATE/date-is-Date.date",
                    fn () => let val d : Date.date = C.fromTimeUniv Time.zeroTime
                             in C.year d = Date.year d end)
  val () = T.check ("Date:DATE/same-exception",
                    fn () => (raise C.Date) handle Date.Date => true | _ => false)
end
