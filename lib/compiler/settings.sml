(* Settings shared by compiler clients. Command-line parsing belongs to
   src/driver/options.sml; library passes never depend on that driver. *)
structure CompilerSettings =
struct
  val inputs : string list ref = ref []
  val libDir : string option ref = ref NONE
  val cacheDir : string option ref = ref NONE
  val noCache = ref false
  val verifyCache = ref false
  val midRoundTrip = ref false
  val target = ref "registers"
end
