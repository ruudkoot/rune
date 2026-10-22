(* An implementation detail.

   Area: Tests *)
signature INTERNAL =
sig
  (* The internal representation. *)
  type t
  (* An internal value. *)
  val value : t
end

structure Hidden : INTERNAL =
struct
  type t = int
  val value = 42
end

(* The public interface.

   Area: Tests *)
signature API =
sig
  (* An abstract value type. *)
  type t
  (* The published value. *)
  val value : t
end

structure Api :> API =
struct
  type t = Hidden.t
  val value = Hidden.value
end
