(* The arbitrary of one type of a structure: what the functors of the
   library make of a structure of the Basis Library, and what the structures
   `Int8Arb`, `Word8Arb`, `CharArraySliceArb` and the rest are.

   The instance of the type of a structure of the Basis Library is the `arb`
   of the structure of the same name with Arb after it: `Int8Arb.arb` for
   `Int8.int` (docs/plans/quickcheck.md, D4 and M6).

   Area: Property testing *)
signature ARB_OF =
sig
  (* The type. *)
  type t

  (* The arbitrary of `t`. *)
  val arb : t Arb.arb
end
