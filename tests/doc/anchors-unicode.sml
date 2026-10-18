(* Anchors of names in Unicode, read under runedoc --unicode: a code point
   above 127 is spelt u and its number, so that the anchor of a value
   λ is val-u3bb. *)
signature UNICODE_NAMES =
sig
  (* `λ x` is `x`; see `τ` and `Σ.α`. *)
  val λ : int -> int
  (* A type. *)
  type τ
  (* A structure of Greek names. *)
  structure Σ : sig val α : int end
  (* A name in Devanagari. *)
  val संख्या : int
end
