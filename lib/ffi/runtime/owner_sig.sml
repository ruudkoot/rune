(* Explicit ownership and borrowed-use scopes for native pointers.

   Area: Foreign interfaces *)
signature FOREIGN_OWNER =
sig
  (* A shared owner identity; copies observe the same closing/closed state. *)
  type owner
  (* A prepared native destructor and its argument projection. *)
  type destructor = {call : RuneForeign.resource,
    arguments : RuneForeign.resource -> RuneForeign.argument list, failure : RuneForeign.failure}
  (* An operation on an already retired native identity. *)
  exception Closed
  (* An attempt to close an active borrower or a destructor in progress. *)
  exception Busy
  (* A second owner for the same live native address. *)
  exception AlreadyOwned
  (* A native destructor returned its annotated failure status. *)
  exception Failed of RuneForeign.result
  (* `adopt {pointer, destructor}` takes ownership of a native-owned pointer.

     The pointer must come from an ownership-annotated foreign result.
     Failure leaves responsibility with the caller. Destruction also checks
     native provenance and rejects Rune-owned storage before native entry. *)
  val adopt : {pointer : RuneForeign.resource, destructor : destructor} -> owner
  (* `isClosed owner` refreshes its shared state from the native registry. *)
  val isClosed : owner -> bool
  (* `withBorrow owner body` guards one synchronous use of its raw identity.

     The borrowed identity must not outlive this use without an explicit raw
     retention contract. Native views additionally retain their source.

     Raises: `Closed` or `Busy` when the owner cannot be borrowed. *)
  val withBorrow : owner -> (RuneForeign.resource -> 'a) -> 'a
  (* `close owner` invokes its destructor and retires its native identity.

     A failed native destructor preserves ownership for retry and raises
     `Failed` with the raw status/error. Native bridge failures propagate.

     Raises: `Closed`, `Busy` or `Failed`. *)
  val close : owner -> unit
  (* `inScope (scope, owner)` registers at-most-once scoped destruction.

     An already closed owner needs no second destructor call. Cancel the
     returned cleanup ticket to transfer responsibility beyond this scope. *)
  val inScope : ForeignScope.scope * owner -> ForeignScope.ticket
end
