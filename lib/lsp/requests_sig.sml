(* Bounded request ownership for an LSP connection.

   Area: Protocols *)
signature LSP_REQUESTS =
sig
  (* Pending requests, each owning caller-supplied data. *)
  type 'a t

  (* A request would exceed the configured number of pending requests. *)
  exception Full

  (* `new {prefix, maxPending}` is an empty connection's request table.

     Raises: `Domain` for an invalid prefix or nonpositive bound. *)
  val new : {prefix : string, maxPending : int} -> 'a t

  (* `reserve (table, id, data)` registers a peer-supplied id; false when
     that id is already pending, leaving its existing data intact.

     Raises: `Full` when the bound is reached.

     Raises: `Domain` for an invalid LSP id. *)
  val reserve : 'a t * JsonRpc.id * 'a -> bool

  (* `issue (table, request)` registers data and returns a validated
     request with a fresh string id derived from the table's prefix.

     Raises: `Full` when the bound is reached.

     Raises: `Domain` for invalid message data. *)
  val issue : 'a t * {method : string, params : Json.value option, data : 'a} -> JsonRpc.message

  (* `resolve (table, response)` consumes the matching request once.
     Stray responses and messages that are not responses give NONE. *)
  val resolve : 'a t * JsonRpc.message -> ('a * JsonRpc.outcome) option

  (* `cancel (table, id)` consumes the request and returns its cancellation
     notification and owned data, when the id was pending. *)
  val cancel : 'a t * JsonRpc.id -> (JsonRpc.message * 'a) option

  (* `clear table` releases all pending entries and returns their data. *)
  val clear : 'a t -> 'a list

  (* `size table` is the number of pending requests. *)
  val size : 'a t -> int
end
