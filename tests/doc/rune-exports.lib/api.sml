(* A private implementation module. *)
structure RunePrivate = struct val factor=2 end

(* An explicitly exported Rune-prefixed interface.

   Area: Tests *)
signature RUNE_API =
sig
  (* `twice n` doubles n.

     Example: `twice 3 = 6` *)
  val twice : int -> int
end

(* The public implementation.

   Implements: RUNE_API *)
structure RuneApi :> RUNE_API =
struct
  structure Hidden = struct val factor=RunePrivate.factor end
  fun twice n = n * Hidden.factor
end
