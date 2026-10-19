(* Identifiers: which code points may make a name, by Unicode Standard
   Annex #31, and the profile of it that Rune takes for Standard ML.

   UAX #31 gives XID_Start, the code points that may begin an identifier
   (letters), and XID_Continue, those that may follow them (letters,
   digits, combining marks, connector punctuation); a string of them stays
   one in every later version of Unicode. The profile of this structure
   adds `'` to the code points that may follow, as Standard ML has it, and
   leaves out two sets that are written down and frozen at Unicode 18.0.0,
   so that a name valid today stays valid:

   - the default ignorable code points that XID_Continue holds, which are
     invisible: the joiners U+200C and U+200D, the variation selectors,
     the Hangul fillers;
   - the lookalikes of Standard ML's punctuation and digits, such as U+01C3
     for `!`, U+02BC for `'`, U+00B7 for `.` and U+01C0 for `|`.

   Whether a name is in Normalization Form C is for `Normalize.isNFC` to
   say.

   Area: Unicode *)
signature IDENTIFIER =
sig
  (* The version of Unicode whose properties are followed.

     Example: `version = "18.0.0"` *)
  val version : string

  (* `isXIDStart c` is whether the code point `c` has the property
     XID_Start.

     Example: `isXIDStart 0x3BB andalso not (isXIDStart 0x30)` *)
  val isXIDStart : int -> bool

  (* `isXIDContinue c` is whether the code point `c` has the property
     XID_Continue.

     Example: `isXIDContinue 0x30 andalso isXIDContinue 0x200D andalso not (isXIDContinue 0x27)` *)
  val isXIDContinue : int -> bool

  (* `isDefaultIgnorable c` is whether the code point `c` has the property
     Default_Ignorable_Code_Point.

     Example: `isDefaultIgnorable 0x200D andalso isDefaultIgnorable 0x3164 andalso not (isDefaultIgnorable 0x41)` *)
  val isDefaultIgnorable : int -> bool

  (* Why the profile leaves out a code point of XID_Continue. *)
  datatype exclusion =
      Ignorable           (* a default ignorable code point, which shows nothing *)
    | Lookalike of char   (* it looks like this character of ASCII *)

  (* `exclusion c` is why the profile leaves out the code point `c`, and
     `NONE` where it does not or where `c` is not XID_Continue.

     Example: `exclusion 0x2BC = SOME (Lookalike #"'") andalso exclusion 0x200D = SOME Ignorable`

     Example: `exclusion 0x1C0 = SOME (Lookalike #"|") andalso exclusion 0x3BB = NONE` *)
  val exclusion : int -> exclusion option

  (* `isStart c` is whether the code point `c` may begin an alphanumeric
     identifier: an ASCII letter, or XID_Start where the profile does not
     leave it out.

     Example: `isStart 0x3BB andalso not (isStart 0x3164) andalso not (isStart 0x5F)` *)
  val isStart : int -> bool

  (* `isContinue c` is whether the code point `c` may follow in an
     alphanumeric identifier.

     It may where it is an ASCII letter or digit, `_` or `'`, or
     XID_Continue where the profile does not leave it out.

     Example: `isContinue 0x27 andalso isContinue 0x301 andalso not (isContinue 0x200D)` *)
  val isContinue : int -> bool

  (* `isAlphanumeric s` is whether the UTF-8 string `s` is an alphanumeric
     identifier of the profile: well-formed, an `isStart` and then
     `isContinue`s. ASCII costs no table.

     Example: `isAlphanumeric "x\206\187'" andalso not (isAlphanumeric "a\226\128\141b")`, λ and a joiner *)
  val isAlphanumeric : string -> bool
end
