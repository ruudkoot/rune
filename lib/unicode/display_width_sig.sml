(* Display widths: how many columns of a terminal a code point takes.

   A terminal gives a character one column, or two for the wide characters
   of East Asian scripts and for emoji, or none for a mark that combines
   with the character before it. The widths come from the Unicode Character
   Database (East Asian Width, the general categories, emoji presentation)
   of the version `version`, by tables that scripts/gen-unicode-tables.py
   makes. Characters of ambiguous East Asian width are one column, as
   terminals outside East Asian locales show them. What is shown of a
   grapheme cluster as a whole -- an emoji joined to another, a flag -- is
   `Grapheme.width`'s.

   Area: Unicode *)
signature DISPLAY_WIDTH =
sig
  (* The version of Unicode the tables are made from.

     Example: `version = "18.0.0"` *)
  val version : string

  (* `codePoint c` is the columns `c` takes on a terminal: 0, 1 or 2.

     It is 0 for a nonspacing, enclosing or format mark and for the medial
     vowels and final consonants of conjoining Hangul; 2 for an East Asian
     wide or fullwidth character and for an emoji shown as one by default;
     1 for the rest. A control character is 0 too: a program shows it its
     own way (`isControl`).

     Example: `codePoint 0x61 = 1 andalso codePoint 0x6F22 = 2 andalso
     codePoint 0x301 = 0 andalso codePoint 0x1F600 = 2` *)
  val codePoint : int -> int

  (* `isControl c` is whether `c` is a control character, of C0 (below
     0x20, and 0x7F) or of C1 (0x80 to 0x9F).

     Example: `isControl 0x1B andalso not (isControl 0x20)` *)
  val isControl : int -> bool

  (* `columns s` is the columns the UTF-8 of `s` takes, the sum of the
     widths of its code points; an ill-formed part counts as the
     replacement character, one column.

     Example: `columns "a\230\188\162" = 3` *)
  val columns : string -> int
end
