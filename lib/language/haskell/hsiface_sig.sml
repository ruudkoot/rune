(* HsIface, rhc's interface of a unit (the haskell98 roadmap's M21, D44):
   what a store keeps of a unit for a client, written and read back. Each
   of its modules' interfaces as the renamer and the checker make them
   (HsModIface), and the desugaring's part, its Core among it, as text the
   desugaring gives. The unfoldings section is in the format from the
   start and empty until M23 (D44's C).

   Area: Languages *)
signature HS_IFACE =
sig
  (* A unit's interface: its modules', the desugaring's part, and the
     unfoldings, none yet. *)
  type t = {modules : HsModIface.t list, desugar : string, unfoldings : string list}

  (* What makes text no interface: where, and what. *)
  exception Bad of string

  (* `encode t` is `t` as text, which `decode` reads back.

     A kind or a type variable linked is written as what it is linked to;
     one left unsolved, which no interface's generalized types hold, raises
     `Bad`. *)
  val encode : t -> string

  (* `decode s` is the interface `encode` wrote as `s`.

     Raises: `Bad` where `s` is not such text. *)
  val decode : string -> t

  (* `encodeModule m` and `decodeModule s` are one module's interface's
     part of the text, for its tests. *)
  val encodeModule : HsModIface.t -> string
  val decodeModule : string -> HsModIface.t
end
