(* The security mechanisms of Unicode Technical Standard #39 for
   identifiers: which code points the standard allows in identifiers and
   of what type they are, the scripts of a string and how far they mix,
   and the skeletons by which two strings are confusable.

   Unlike the properties of UAX #31 that `Identifier` follows, these data
   change between versions of Unicode: a code point may stop being allowed,
   and two strings may become confusable or stop being so. They suit
   warnings rather than the rules of a language. The data are those of the
   version `version`.

   Area: Unicode *)
signature UNICODE_SECURITY =
sig
  (* The version of Unicode and of UTS #39 whose data are followed.

     Example: `version = "18.0.0"` *)
  val version : string

  (* ---- Identifier status and type ---- *)

  (* The Identifier_Status of a code point. *)
  datatype status =
      Allowed      (* its Identifier_Type is Recommended or Inclusion: the General Security Profile allows it *)
    | Restricted   (* any other *)

  (* `status c` is the Identifier_Status of the code point `c`.

     Example: `status 0x61 = Allowed andalso status 0x1D44E = Restricted`, a and a mathematical italic a *)
  val status : int -> status

  (* An Identifier_Type: why a code point is allowed in identifiers, or why
     it is restricted. *)
  datatype identifierType =
      Recommended        (* in widespread modern use *)
    | Inclusion          (* not a letter, but used in the words of some languages, as U+00B7 is in Catalan's *)
    | LimitedUse         (* of a script in use by a limited community *)
    | Technical          (* for technical notation, such as phonetics *)
    | UncommonUse        (* of uncommon use *)
    | Obsolete           (* no longer in modern use *)
    | Exclusion          (* of a script no longer in use *)
    | NotXID             (* not XID_Continue *)
    | NotNFKC            (* changed by NFKC *)
    | DefaultIgnorable   (* a default ignorable code point *)
    | Deprecated         (* deprecated *)
    | NotCharacter       (* not assigned, of private use, a surrogate or a noncharacter *)

  (* `types c` is the Identifier_Type of the code point `c`, a set of one
     or more types, in the order of the datatype.

     Example: `types 0x61 = [Recommended] andalso types 0x1C0 = [Technical]` *)
  val types : int -> identifierType list

  (* ---- Scripts ---- *)

  (* `scripts c` is the augmented script set of the code point `c` (UTS #39,
     section 5.1), its scripts as ISO 15924 codes in order, or `NONE` for
     every script.

     The scripts are those of its Script_Extensions, with the writing
     systems that hold them: Hanb, Hntl, Jpan and Kore for Han, Jpan for
     Hiragana and Katakana, Kore for Hangul, Hanb for Bopomofo and Hntl for
     Latin. A code point of Common or Inherited has every script.

     Example: `scripts 0x3BB = SOME ["Grek"] andalso scripts 0x30 = NONE`

     Example: `scripts 0x61 = SOME ["Hntl", "Latn"]` *)
  val scripts : int -> string list option

  (* `resolvedScripts s` is the resolved script set of the UTF-8 string
     `s`, the scripts that every code point of `s` has, or `NONE` for every
     script.

     Example: `resolvedScripts "x\206\187" = SOME [] andalso resolvedScripts "\206\187" = SOME ["Grek"]`, x and λ *)
  val resolvedScripts : string -> string list option

  (* `isSingleScript s` is whether the resolved script set of the UTF-8
     string `s` is not empty.

     Example: `isSingleScript "\206\177\206\187" andalso not (isSingleScript "x\206\187")` *)
  val isSingleScript : string -> bool

  (* The restriction levels of UTS #39, section 5.2, the strictest first. *)
  datatype restriction =
      ASCIIOnly               (* ASCII alone *)
    | SingleScript            (* one script, as `isSingleScript` says *)
    | HighlyRestrictive       (* Latin with Japanese, with Han and Bopomofo, or with Korean *)
    | ModeratelyRestrictive   (* Latin with one other Recommended script, not Cyrillic or Greek *)
    | MinimallyRestrictive    (* any mixture of scripts *)
    | Unrestricted            (* a code point that `status` does not allow *)

  (* `restriction s` is the strictest restriction level that the UTF-8
     string `s` meets, by the algorithm of UTS #39, section 5.2, with
     `status` as the identifier profile.

     Example: `restriction "abc" = ASCIIOnly andalso restriction "\206\177\206\187" = SingleScript`

     Example: `restriction "x\206\187" = MinimallyRestrictive`, Latin and Greek *)
  val restriction : string -> restriction

  (* ---- Confusables ---- *)

  (* `skeleton s` is the skeleton of the UTF-8 string `s` (UTS #39, section
     4), by which strings that look alike are found.

     It is the NFD of `s` without its default ignorable code points, each
     code point replaced by its prototype in confusables.txt, and the NFD of
     that.

     Example: `skeleton "\208\176" = "a"`, a Cyrillic а *)
  val skeleton : string -> string

  (* `isConfusable (s, t)` is whether the UTF-8 strings `s` and `t` have the
     same skeleton.

     Example: `isConfusable ("paypal", "p\208\176yp\208\176l")`, with two Cyrillic а *)
  val isConfusable : string * string -> bool
end
