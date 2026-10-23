(* Implements: FOREIGN_SCOPE *)
structure ForeignScope :> FOREIGN_SCOPE =
struct
  datatype ticket=Ticket of bool ref * (unit -> unit)
  datatype phase=Open | Closing | Finished
  datatype scope=Scope of phase ref * ticket list ref
  datatype 'a outcome=Returned of 'a | Raised of exn
  exception Closed
  fun defer(Scope(phase,pending),action)=case !phase of
      Open=>let val ticket=Ticket(ref true,action) in pending:=ticket:: !pending;ticket end
    | _=>raise Closed
  fun run(Ticket(armed,action))=if !armed then (armed:=false;action()) else ()
  fun cancel(Ticket(armed,_))=armed:=false
  fun withScope body=
    let val phase=ref Open val pending=ref []
        val answer=(Returned(body(Scope(phase,pending)))handle e=>Raised e)
        val ()=phase:=Closing
        fun clean([],first)=first
          | clean(ticket::rest,first)=
              let val next=(run ticket;first)handle e=>case first of NONE=>SOME e | _=>first
              in clean(rest,next) end
        val failure=clean(!pending,NONE)
        val ()=(pending:=[];phase:=Finished)
    in case answer of Raised e=>raise e | Returned value=>case failure of NONE=>value | SOME e=>raise e end
end
