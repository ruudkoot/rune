(* Host adapters execute already-decided commands and expose finite waits.
   All build, dependency, archive and publication decisions belong to SML models. *)
signature BUILD_IO =
sig
  exception Interrupted
  exception TimedOut of string list * real
  val initialize : unit -> unit
  val execute : {args:string list, directory:string, input:string, output:string,
                 errors:string, environment:string list, timeout:real} -> {status:int,seconds:real}
end
