(* Normalisation: the canonical forms of Unicode Standard Annex #15.

   Two strings of code points may be the same text: "é" may be U+00E9, or
   "e" and U+0301 COMBINING ACUTE ACCENT; a Hangul syllable may be one
   code point or its two or three jamo; accents on one letter may come in
   either order. Normalisation Form D (NFD) writes every such text one
   way, decomposed: each character replaced by its canonical decomposition,
   then the marks of each letter sorted by their combining class. Form C
   (NFC) composes NFD again wherever a primary composite exists, so that
   most text is shorter in it and is often already in it. Two strings are
   canonically equivalent exactly when their NFCs, or their NFDs, are
   equal. The data is that of the version `version`; the test data of that
   version (NormalizationTest.txt) passes, and a string in NFC stays in NFC
   in every later version (Unicode's normalisation stability policy).

   The functions over strings read UTF-8 by `Utf8.next`: an ill-formed part
   of a string is read as U+FFFD, and such a string is in no form.

   Area: Unicode *)
signature NORMALIZE =
sig
  (* The version of Unicode whose data is followed.

     Example: `version = "18.0.0"` *)
  val version : string

  (* The answer of a quick check: certainly in the form, certainly not, or
     only normalising tells. *)
  datatype answer = Yes | No | Maybe

  (* `combiningClass c` is the Canonical_Combining_Class of the code point
     `c`: 0 for a starter, which is most characters; the marks above a
     letter 230, those below 220.

     Example: `combiningClass 0x301 = 230 andalso combiningClass 0x41 = 0` *)
  val combiningClass : int -> int

  (* `nfd s` is the canonical decomposition of the UTF-8 string `s`,
     Normalisation Form D.

     Law: `nfd (nfd s) = nfd s`

     Example: `nfd "\195\169" = "e\204\129"`, é decomposed *)
  val nfd : string -> string

  (* `nfc s` is the canonical composition of the UTF-8 string `s`,
     Normalisation Form C. A string that the quick check finds in NFC is
     `s` itself, unchanged.

     Law: `nfc (nfd s) = nfc s`

     Example: `nfc "e\204\129" = "\195\169"`, é composed *)
  val nfc : string -> string

  (* `nfdList cs` is the NFD of the code points `cs`.

     Raises: `Chr` if one of `cs` is not a scalar value (`Utf8.isScalar`).

     Example: `nfdList [0xAC01] = [0x1100, 0x1161, 0x11A8]`, a Hangul syllable *)
  val nfdList : int list -> int list

  (* `nfcList cs` is the NFC of the code points `cs`.

     Raises: `Chr` if one of `cs` is not a scalar value.

     Example: `nfcList [0x1100, 0x1161, 0x11A8] = [0xAC01]` *)
  val nfcList : int list -> int list

  (* `quickCheck s` is the NFC quick check of the UTF-8 string `s`: `Yes`
     where `s` is in NFC, `No` where it is not, `Maybe` where only `nfc`
     tells.

     It is the algorithm of UAX #15's section 9 over the property
     NFC_Quick_Check. ASCII is always `Yes` and costs no table; ill-formed
     UTF-8 is `No`.

     Example: `quickCheck "abc" = Yes andalso quickCheck "e\204\129" = Maybe` *)
  val quickCheck : string -> answer

  (* `quickCheckList cs` is the NFC quick check of the code points `cs`.

     Raises: `Chr` if one of `cs` is not a scalar value. *)
  val quickCheckList : int list -> answer

  (* `isNFC s` is whether the UTF-8 string `s` is in NFC: the quick check,
     and `nfc` where it says `Maybe`.

     Law: `isNFC s = (nfc s = s)`

     Example: `isNFC "\195\169" andalso not (isNFC "e\204\129")` *)
  val isNFC : string -> bool

  (* `isNFCList cs` is whether the code points `cs` are in NFC.

     Raises: `Chr` if one of `cs` is not a scalar value. *)
  val isNFCList : int list -> bool
end
