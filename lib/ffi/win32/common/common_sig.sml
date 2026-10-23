(* Provider support for the shared Win32 type identities.

   Area: Foreign interfaces *)
signature WIN32_COMMON =
sig
  (* One public type module reused by native, SDL and mock providers. *)
  structure Types : WIN32_TYPES
  (* `freshWindow ()` creates an unregistered window token.

     A token alone grants no capability; every provider validates its registry. *)
  val freshWindow : unit -> Types.window
  (* `freshModule ()` creates an unregistered module token. *)
  val freshModule : unit -> Types.module
  (* `freshAtom ()` creates an unregistered class token. *)
  val freshAtom : unit -> Types.atom
  (* `freshPaint ()` creates an unregistered paint token. *)
  val freshPaint : unit -> Types.paint
  (* `freshObject ()` creates an unregistered object token. *)
  val freshObject : unit -> Types.object
  (* `freshPen ()` creates a pen and its associated object identity. *)
  val freshPen : unit -> Types.pen
  (* `freshBrush ()` creates a brush and its associated object identity. *)
  val freshBrush : unit -> Types.brush
  (* `freshQueued ()` creates an unregistered copied-message token. *)
  val freshQueued : unit -> Types.queued
  (* `penObject pen` returns the pen's shared object identity. *)
  val penObject : Types.pen -> Types.object
  (* `brushObject brush` returns the brush's shared object identity. *)
  val brushObject : Types.brush -> Types.object
  (* `objectBrush object` reinterprets the token without granting ownership.

     The provider must verify that the associated object is a brush. *)
  val objectBrush : Types.object -> Types.brush
  (* `windowKey window` returns its process-local diagnostic identity. *)
  val windowKey : Types.window -> IntInf.int
  (* `moduleKey module` returns its process-local diagnostic identity. *)
  val moduleKey : Types.module -> IntInf.int
  (* `atomKey atom` returns its process-local diagnostic identity. *)
  val atomKey : Types.atom -> IntInf.int
  (* `paintKey paint` returns its process-local diagnostic identity. *)
  val paintKey : Types.paint -> IntInf.int
  (* `objectKey object` returns its process-local diagnostic identity. *)
  val objectKey : Types.object -> IntInf.int
  (* `queuedKey queued` returns its process-local diagnostic identity. *)
  val queuedKey : Types.queued -> IntInf.int
end
