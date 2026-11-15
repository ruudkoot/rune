(* HsIface, rhc's interface of a unit (the haskell98 roadmap's M21, D44):
   what a store keeps of a unit for a client, written and read back. Each
   of its modules' interfaces as the renamer and the checker make them
   (HsModIface). The unfoldings section is in the format from the start
   and empty until M23 (D44's C). The desugaring's part, its Core among
   it, is the desugaring's own text, which a client keeps beside this one:
   rhc's driver keeps it as a section of its own, read only where a unit
   is desugared after it.

   Area: Languages *)
signature HS_IFACE =
sig
  (* A unit's interface: its modules', and the unfoldings, none yet. *)
  type t = {modules : HsModIface.t list, unfoldings : string list}

  (* What makes bytes no interface: where, and what. *)
  exception Bad of string

  (* `encode t` is `t` as bytes, which `decode` reads back: each string
     once, in a table, and every place it is named a number.

     A kind or a type variable linked is written as what it is linked to;
     one left unsolved, which no interface's generalized types hold, raises
     `Bad`. *)
  val encode : t -> string

  (* `decode s` is the interface `encode` wrote as `s`.

     Raises: `Bad` where `s` is not such bytes. *)
  val decode : string -> t

  (* `encodeModule m` and `decodeModule s` are one module's interface
     alone, for its tests. *)
  val encodeModule : HsModIface.t -> string
  val decodeModule : string -> HsModIface.t
end
