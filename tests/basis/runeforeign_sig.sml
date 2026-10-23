(* requires: RuneForeign *)
structure TestRuneForeignSig =
struct
  structure F : RUNE_FOREIGN = RuneForeign
  val () = T.check ("RuneForeign:RUNE_FOREIGN/interface", fn () =>
    let val _ : unit -> bool = F.available
        val _ : unit -> {pointerBytes:int,littleEndian:bool,stdcall:bool} = F.target
        val _ : F.resource * F.argument list -> F.result = F.invoke
        val _ : F.resource -> unit = F.release
    in true end)
end
