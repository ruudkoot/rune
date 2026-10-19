(* requires: WideStringCvt StringCvt WideString WideChar *)
(* uses: spec-sigs/scr/STRING_CVT.sml *)
(* StringCvt and WideStringCvt match one STRING_CVT, the signature of the
   change request of docs/unicode.md (the deviation `STRING_CVT/generic`),
   where the character and the string are types of the signature:
     structure StringCvt :> STRING_CVT
       where type char = Char.char where type string = String.string
     structure WideStringCvt :> STRING_CVT
       where type char = WideChar.char where type string = WideString.string
       where type radix = StringCvt.radix where type realfmt = StringCvt.realfmt
   No host has a WideStringCvt, so only Rune runs these checks. *)
functor TestWideStringCvtPad (C : SCR_STRING_CVT) = struct fun pad c s = C.padRight c 4 s end
structure TestWideStringCvtSig =
struct
  structure N : SCR_STRING_CVT
    where type char = Char.char
    where type string = String.string = StringCvt
  val () = T.check ("StringCvt:STRING_CVT/generic",
                    fn () => N.padLeft #"0" 3 "7" = "007" andalso N.takel Char.isDigit Substring.getc (Substring.full "12a") = "12")
  structure W : SCR_STRING_CVT
    where type char = WideChar.char
    where type string = WideString.string
    where type radix = StringCvt.radix
    where type realfmt = StringCvt.realfmt = WideStringCvt
  val () = T.check ("WideStringCvt:STRING_CVT/generic",
                    fn () => WideString.size (W.padLeft (WideChar.chr 0x3BB) 3 (WideString.str (WideChar.chr 65))) = 3)
  val () = T.check ("WideStringCvt:STRING_CVT/radix-is-StringCvt.radix",
                    fn () => (W.HEX : StringCvt.radix) = StringCvt.HEX andalso Int.fmt W.BIN 5 = "101")
  val () = T.check ("WideStringCvt:STRING_CVT/realfmt-is-StringCvt.realfmt",
                    fn () => (W.FIX (SOME 2) : StringCvt.realfmt) = StringCvt.FIX (SOME 2))
  (* one functor, at either kind of text *)
  structure P8 = TestWideStringCvtPad (StringCvt)
  structure PW = TestWideStringCvtPad (WideStringCvt)
  val () = T.check ("WideStringCvt:STRING_CVT/one-functor-for-both",
                    fn () => P8.pad #"." "ab" = "ab.."
                             andalso WideString.size (PW.pad (WideChar.chr 0x2026) (WideString.str (WideChar.chr 97))) = 4)
  (* the signature can be implemented opaquely: an empty string of its own,
     from takel, scans to nothing *)
  structure O :> SCR_STRING_CVT = WideStringCvt
  val () = T.check ("WideStringCvt:STRING_CVT/opaque-cs",
                    fn () => O.scanString (fn rdr => fn (src : O.cs) => rdr src)
                                          (O.takel (fn _ => true) (fn () => NONE) ()) = NONE)
end
