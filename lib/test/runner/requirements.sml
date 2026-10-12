(* Requirements: capabilities, each probed once. *)
structure Requirements :> REQUIREMENTS =
struct
  type capability = {name : string, probe : string, hint : string}

  val without =
    case OS.Process.getEnv "RUNE_TEST_WITHOUT" of
      SOME s => String.tokens (fn c => c = #",") s
    | NONE => []

  (* what each probe found *)
  val known : (string * bool) list ref = ref []

  fun present (cs : capability list, name) =
    case List.find (fn (n, _) => n = name) (!known) of
      SOME (_, ok) => ok
    | NONE =>
        let
          val ok =
            not (List.exists (fn w => w = name) without)
            andalso (case List.find (fn c => #name c = name) cs of
                       SOME c => OS.Process.isSuccess (OS.Process.system ("{ " ^ #probe c ^ "; } > /dev/null 2>&1"))
                     | NONE => false)
        in known := (name, ok) :: !known; ok end

  fun missing (cs, names) =
    List.mapPartial (fn n => if present (cs, n) then NONE
                             else SOME (n, case List.find (fn c => #name c = n) cs of
                                             SOME c => #hint c
                                           | NONE => "no probe says what it is"))
                    names
end
