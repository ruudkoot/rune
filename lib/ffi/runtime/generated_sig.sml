(* Explicit sessions for generated dynamic foreign declarations.

   Area: Foreign interfaces *)
signature FOREIGN_GENERATED =
sig
  (* A fixed native descriptor; its spelling retains the original declaration. *)
  type descriptor = {name : string, symbol : string, abi : int,
    result : RuneForeign.scalar, arguments : RuneForeign.scalar list}
  (* Measured C object facts, in addition to pointer size and byte order. *)
  type abiFacts = {architecture : string, charBits : int, charSigned : bool,
    scalars : {name : string, size : int, alignment : int} list}
  (* A lazily opened collection of native libraries and prepared calls. *)
  type session
  (* Access after successful close. *)
  exception Closed
  (* `create {libraries, descriptors, target}` creates a session without loading.

     Target facts must agree with the executing VM before any native entry.
     Library names are searched in their declared order for each symbol. *)
  val create : {libraries : string list, descriptors : descriptor list,
    target : {pointerBytes : int, littleEndian : bool, stdcall : bool}} -> session
  (* `createChecked {libraries, descriptors, target, abiFacts}` checks the full ABI.

     Generated code uses this constructor. Every scalar size and alignment,
     architecture and plain-char representation must match before loading. *)
  val createChecked : {libraries : string list, descriptors : descriptor list,
    target : {pointerBytes : int, littleEndian : bool, stdcall : bool},
    abiFacts : abiFacts} -> session
  (* `prepare session name` returns the cached descriptor for a declared name.

     Raises: `Closed`, `Fail` for an undeclared name, or a native bridge error.
     The resource belongs to the session and must not be released separately. *)
  val prepare : session -> string -> RuneForeign.resource
  (* `invoke session name arguments` executes a declared, fixed native call.

     Native status bytes and immediately captured errors remain available. *)
  val invoke : session -> string -> RuneForeign.argument list -> RuneForeign.result
  (* `invokeDeferred session name arguments` exposes ownership before propagation.

     Register cleanup for an owned pointer result, then propagate a saved
     callback exception. The native result and its captured errors survive. *)
  val invokeDeferred : session -> string -> RuneForeign.argument list ->
    {result : RuneForeign.result, callbackException : exn option}
  (* `close session` releases prepared calls, symbols and libraries in order.

     A live native dependent can prevent unloading. Successfully released
     entries are removed, so closing can be retried after dependents close. *)
  val close : session -> unit
end
