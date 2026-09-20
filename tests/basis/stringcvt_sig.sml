(* requires: StringCvt *)
(* uses: spec-sigs/STRING_CVT.sml *)
(* StringCvt matches STRING_CVT; its datatypes and the reader type are what
   the other structures of the library name in their fmt and scan members. *)
structure TestStringCvtSig =
struct
  structure C : SPEC_STRING_CVT = StringCvt
  val () = T.check ("StringCvt:STRING_CVT/matches", fn () => true)
  val () = T.check ("StringCvt:STRING_CVT/radix-is-StringCvt.radix",
                    fn () => (C.HEX : StringCvt.radix) = StringCvt.HEX andalso (StringCvt.BIN : C.radix) <> C.OCT)
  val () = T.check ("StringCvt:STRING_CVT/realfmt-is-StringCvt.realfmt",
                    fn () => (C.FIX (SOME 2) : StringCvt.realfmt) = StringCvt.FIX (SOME 2)
                             andalso (StringCvt.EXACT : C.realfmt) <> C.GEN NONE)
  (* "type ('a,'b) reader = 'b -> ('a * 'b) option": any function of that type is a reader *)
  val () = T.check ("StringCvt:STRING_CVT/reader-is-a-function-type",
                    fn () =>
                      let
                        val rdr : (char, char list) C.reader = fn [] => NONE | c :: cs => SOME (c, cs)
                        val f : char list -> (char * char list) option = rdr
                      in
                        f [#"a"] = SOME (#"a", []) andalso C.takel Char.isAlpha rdr [#"a", #"1"] = "a"
                      end)
  val () = T.check ("StringCvt:STRING_CVT/cs-is-StringCvt.cs",
                    fn () =>
                      let fun scan (rdr : (char, StringCvt.cs) C.reader) (src : C.cs) = rdr src
                      in C.scanString scan "xy" = SOME #"x" andalso StringCvt.scanString scan "" = NONE end)
  (* the signature can be implemented opaquely: nothing in it depends on the representation of cs *)
  structure O :> SPEC_STRING_CVT = StringCvt
  val () = T.check ("StringCvt:STRING_CVT/opaque-cs",
                    fn () => O.scanString (fn rdr => fn (src : O.cs) => rdr src) "q" = SOME #"q"
                             andalso O.padLeft #"0" 3 "7" = "007" andalso O.DEC <> O.HEX)
end
