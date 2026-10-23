(* Settings shared by compiler clients. Command-line parsing belongs to
   src/driver/options.sml; library passes never depend on that driver. *)
structure CompilerSettings =
struct
  val inputs : string list ref = ref []
  val () = CompilerState.cellRoot ("CompilerSettings.inputs", inputs)
  val libDir : string option ref = ref NONE
  val () = CompilerState.cellRoot ("CompilerSettings.libDir", libDir)
  val cacheDir : string option ref = ref NONE
  val () = CompilerState.cellRoot ("CompilerSettings.cacheDir", cacheDir)
  val noCache = ref false
  val () = CompilerState.cellRoot ("CompilerSettings.noCache", noCache)
  val verifyCache = ref false
  val () = CompilerState.cellRoot ("CompilerSettings.verifyCache", verifyCache)
  val midRoundTrip = ref false
  val () = CompilerState.cellRoot ("CompilerSettings.midRoundTrip", midRoundTrip)
  val target = ref "registers"
  val () = CompilerState.cellRoot ("CompilerSettings.target", target)
end
