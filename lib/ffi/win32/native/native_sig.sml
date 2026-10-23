(* Native Windows implementation and its explicit session shutdown.

   Area: Foreign interfaces *)
signature WIN32_NATIVE =
sig
  include WIN32
  (* `close ()` releases unused messages, borrowed identities and libraries.

     Windows, classes, paint leases and owned GDI objects must be closed
     first. The provider rejects use after successful close.

     Rejects live dependents or callback reentry with the public error. *)
  val close : unit -> unit
end
