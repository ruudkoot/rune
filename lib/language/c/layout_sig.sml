(* Explicit target layouts for reusable C declaration consumers.

   Area: Languages *)
signature C_LAYOUT =
sig
  (* A physical source position in an original declaration. *)
  type source = CLex.location
  (* Size/alignment in bytes; signedness remains explicit where meaningful. *)
  type scalar = {size : int, alignment : int, signed : bool option}
  (* Target facts, independent of the generator host's arithmetic width. *)
  type target = {name : string, pointer : scalar, enumeration : scalar,
    scalars : (string * scalar) list, maximumObject : IntInf.int}
  (* Sized atoms, arrays and aggregates. FieldLayouts retain their own layouts. *)
  datatype layout = Atom of {size : IntInf.int, alignment : int}
    | Sequence of {size : IntInf.int, alignment : int, count : IntInf.int, element : layout}
    | Aggregate of {size : IntInf.int, alignment : int, union : bool, packed : bool, fields : field list}
  (* A named or anonymous member's byte offset and original source. *)
  and field = FieldLayout of {name : string option, offset : IntInf.int, layout : layout, source : source}
  (* An incomplete, invalid, cyclic or oversized selected layout. *)
  exception Error of source * string
  (* A layout/access operation requiring a verified native adapter. *)
  exception Shim of source * string
  (* `size layout` returns its target byte size. *)
  val size : layout -> IntInf.int
  (* `alignment layout` returns its target byte alignment. *)
  val alignment : layout -> int
  (* `compute {target, source, ty, lookup, constant}` lays out a C object.

     The caller resolves aliases/tags and evaluates typed constant bounds.
     Bitfields and unsupported representations require explicit adapters.

     Raises: `Error` or `Shim` rather than guessing an ABI layout. *)
  val compute : {target : target, source : source, ty : CParse.ctype,
    lookup : {namespace : string, name : string} -> CParse.ctype option,
    constant : CLex.token list -> IntInf.int} -> layout
  (* `member (layout, path)` resolves named and anonymous aggregate fields.

     Raises: `Error` for missing or ambiguous members. *)
  val member : layout * string list -> {offset : IntInf.int, layout : layout}
end
