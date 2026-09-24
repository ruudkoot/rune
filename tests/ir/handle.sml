(* dump: --dump-after=translate *)
(* An exception declared, raised and handled: the handler matches the
   exception's constructor and raises it again when no rule matches. *)
exception E of int
fun f x = (if x = 0 then raise E 7 else x) handle E n => n
