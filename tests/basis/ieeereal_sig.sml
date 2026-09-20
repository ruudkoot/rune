(* requires: IEEEReal StringCvt *)
(* uses: spec-sigs/IEEE_REAL.sml *)
(* IEEEReal matches IEEE_REAL. *)
structure TestIEEERealSig =
struct
  structure C : SPEC_IEEE_REAL = IEEEReal
  val () = T.check ("IEEEReal:IEEE_REAL/matches", fn () => true)
  val () = T.check ("IEEEReal:IEEE_REAL/constructors-are-shared",
                    fn () => (case C.TO_ZERO of IEEEReal.TO_ZERO => true | _ => false)
                             andalso (case C.SUBNORMAL of IEEEReal.SUBNORMAL => true | _ => false)
                             andalso (case C.UNORDERED of IEEEReal.UNORDERED => true | _ => false))
end
