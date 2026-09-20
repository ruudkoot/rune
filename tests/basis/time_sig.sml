(* requires: Time LargeInt StringCvt *)
(* uses: spec-sigs/TIME.sml *)
(* Time matches TIME; the type and the exception seen through the signature
   are those of the structure. *)
structure TestTimeSig =
struct
  structure C : SPEC_TIME = Time
  val () = T.check ("Time:TIME/matches", fn () => true)
  val () = T.check ("Time:TIME/time-is-Time.time",
                    fn () => (C.zeroTime : Time.time) = Time.zeroTime
                             andalso C.fromSeconds (LargeInt.fromInt 2) = Time.fromMilliseconds (LargeInt.fromInt 2000))
  val () = T.check ("Time:TIME/same-exception",
                    fn () => (raise C.Time) handle Time.Time => true | _ => false)
  (* "eqtype time": the signature can be implemented opaquely and the type
     still admits equality *)
  structure O :> SPEC_TIME = Time
  val large = LargeInt.fromInt
  val () = T.check ("Time:TIME/opaque-time-is-an-eqtype",
                    fn () => O.fromSeconds (large 3) = O.fromMilliseconds (large 3000) andalso O.zeroTime <> O.fromSeconds (large 1)
                             andalso O.toSeconds (O.+ (O.fromSeconds (large 1), O.fromSeconds (large 2))) = large 3)
end
