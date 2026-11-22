(* mid-client.sml on Rune's list (Pipeline.midPasses), Expand first, edited
   in place as a client of the compiler edits it before it compiles *)
structure PipelineClient =
struct
  fun main () : unit =
    let
      val (e, out) = MidClient.arguments ()
      val () = Pipeline.midPasses := MidClient.edit e (!Pipeline.midPasses)
    in MidClient.compile ({names = Pipeline.passNames (), lowOfMid = Pipeline.lowOfMid}, e, out) end
end
val () = PipelineClient.main ()
