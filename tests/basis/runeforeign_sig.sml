(* requires: RuneForeign *)
structure TestRuneForeignSig =
struct
  structure F : RUNE_FOREIGN = RuneForeign
  val () = T.check ("RuneForeign:RUNE_FOREIGN/interface", fn () =>
    let val _ : unit -> bool = F.available
        val _ : unit -> {pointerBytes:int,littleEndian:bool,stdcall:bool} = F.target
        val _ : F.resource * F.argument list -> F.result = F.invoke
        val _ : F.resource * F.argument list -> {result:F.result,callbackException:exn option} = F.invokeDeferred
        val _ : {abi:int,result:F.scalar,arguments:F.scalar list,function:F.argument list -> F.argument,failure:F.callbackFailure} -> F.resource = F.callback
        val _ : F.resource -> F.resource = F.aliasHandle
        val _ : {resource:F.resource,call:F.resource,arguments:F.argument list,failure:F.failure} ->
          {disposed:bool,result:F.result} = F.consumeHandle
        val _ : F.resource -> unit = F.release
        val _ : F.resource -> bool = F.isLive
        val _ : F.resource * F.resource -> bool = F.sameAddress
        val _ : {resource:F.resource,call:F.resource,arguments:F.argument list,failure:F.failure} ->
          {disposed:bool,result:F.result} = F.dispose
    in true end)
end
