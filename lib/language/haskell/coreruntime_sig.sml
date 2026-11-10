(* rhc's runtime, in Core (the haskell98 roadmap, M17; D24 to D26): what
   the Report's modules name and never define, written in Core over
   CorePrim's primitives, so that the Core interpreter and Core to Mid run
   one text and no SML stands below Haskell (D26's A).

   It holds the built-in syntax, the unit `()` and the list `[]` with its
   constructors `[]` and `:` (ov.prelude.unit, ov.prelude.list), and the
   two modules the Report imports and never defines: PreludeBuiltin, whose
   primitives are those of share/rhc/haskell98's Prelude and PreludeIO, and
   UnicodePrims, Char's. Each `prim*` of the Report is a value of it of the
   same name, whose type is the Report's in Core: `String` is `([] Char)`,
   `IOError` is `Exn` and `IO a` is `World -> (utuple World a)` (D25's
   state token). Beside them it has `primSeq`, `primReturnIO` and
   `primBindIO` (ov.prelude.seq, ov.prelude.io) and `primUnpackString`,
   which makes a string literal, UTF-8 in a `Str`, its list of characters.

   Input and output are UTF-8; a byte that starts no sequence of UTF-8 is
   read as the character of its number. `getContents` and `readFile` read
   a chunk at a time as their list is read, through `interleave`, the one
   interleaving primitive, and end their list at an error of reading
   (21.2.2); standard output is written before standard input is read.
   `getChar` and `getContents` share standard input's buffer.

   The general category and the simple case mappings are lib/unicode's
   (CodePoint, D21), at its version, in tables written from its data:
   `isUpper` is true of every letter that is not lower case (R38).

   Area: Languages *)
signature CORE_RUNTIME =
sig
  (* How a string literal becomes its list (D24).

     `Lazy` makes a cell as the list is read (A, decided); `Whole` makes
     every cell at the first force (B, built for the owner's measurement). *)
  datatype strings = Lazy | Whole

  (* `reportNames` is the `prim*` of the Report's modules, each a value of
     the runtime. *)
  val reportNames : string list

  (* `program strings` is the whole runtime, its literals made as `strings`
     says.

     Raises: `CoreText.Error` where its text does not read, a bug of rhc's. *)
  val program : strings -> Core.program

  (* `link strings p` is `p` after the declarations of the runtime that `p`
     reaches, through the names it mentions and through theirs.

     A declaration `p` makes of a name of the runtime is `p`'s own, and the
     runtime's is left out. *)
  val link : strings -> Core.program -> Core.program
end
