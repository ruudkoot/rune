(* mid-client.sml on the layer from Mid on: the passes any front end may
   run (MidPipeline.standardPasses), edited *)
structure MidClientMain =
struct
  fun main () : unit =
    let
      val (e, out) = MidClient.arguments ()
      val passes = MidClient.edit e MidPipeline.standardPasses
    in MidClient.compile ({names = MidPipeline.passNames passes, lowOfMid = MidPipeline.lowOfMid passes}, e, out) end
end
val () = MidClientMain.main ()
