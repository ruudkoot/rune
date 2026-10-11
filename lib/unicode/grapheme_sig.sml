(* Grapheme clusters: the characters a reader sees, by the rules of Unicode
   Standard Annex #29.

   A user-perceived character may be several code points: a letter and the
   accents on it, a Hangul syllable of conjoining jamo, an Indic conjunct,
   an emoji with a skin tone or joined to others by U+200D, a flag of two
   regional indicators. An editor moves its cursor and deletes by extended
   grapheme cluster, and a terminal draws one cluster in one cell or two.
   The rules are those of the Annex for the version `version` of Unicode;
   the test data of that version (GraphemeBreakTest.txt) passes.

   Area: Unicode *)
signature GRAPHEME =
sig
  (* The version of Unicode whose rules and properties are followed.

     Example: `version = "18.0.0"` *)
  val version : string

  (* `next (s, i)` is the offset just past the extended grapheme cluster
     that begins at byte `i` of `s`. An ill-formed part of the UTF-8 is a
     cluster of its own.

     Raises: `Subscript` unless `0 <= i` and `i < size s`.

     Example: `next ("e\204\129x", 0) = 3` *)
  val next : string * int -> int

  (* `clusters s` is the clusters of `s`, in order.

     Example: `clusters "e\204\129x" = ["e\204\129", "x"]` *)
  val clusters : string -> string list

  (* `count s` is how many clusters `s` has.

     Example: `count "\240\159\135\179\240\159\135\177" = 1`, a flag *)
  val count : string -> int

  (* How a terminal measures a cluster: as one, or as its code points.

     Windows Terminal and kitty measure a cluster as one, as Unicode
     recommends; xterm, and VS Code's terminal by report, add up its code
     points. *)
  datatype policy =
      ByCluster     (* a cluster as wide as its widest code point, an emoji presentation sequence two *)
    | ByCodePoint   (* the sum of `DisplayWidth.codePoint` over its code points *)

  (* `width policy s` is the columns `s` takes on a terminal that measures
     by `policy`.

     Example: `width ByCluster "\240\159\145\169\226\128\141\240\159\145\167" = 2`

     Example: `width ByCodePoint "\240\159\145\169\226\128\141\240\159\145\167" = 4` *)
  val width : policy -> string -> int
end
