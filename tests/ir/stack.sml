(* dump: --dump-after=stack *)
(* Low made stack code: a value used once stays on the stack (the
   arguments of +, the call's argument), and only what is used twice or
   across blocks gets a local; locals are shared once their values are
   dead; the block that follows falls through, and the value of the if is
   moved into the local of the parameter it goes to. *)
fun f (a, b) =
  let
    val s = a + b
    val t = if s > 10 then s * 2 else s - 1
  in
    t + s
  end
