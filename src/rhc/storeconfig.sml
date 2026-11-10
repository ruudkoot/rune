(* What a configuration of rhc's in the store is made of (the haskell98
   roadmap's M21, D43), and the level of the lint its entries are checked
   at: RhcStore's, from the compiler's settings, apart so that RhcStore is
   tested with no compiler. *)
structure RhcStoreConfig =
struct
  (* The level of the lint a compile's entries are checked at, as Rune's
     (UnitCache.level): at most 2, and 0 where RegVerify does not run *)
  fun level () : int =
    let val l = Int.min (Pass.lintLevel (), 2)
    in if l >= 1 andalso not (isSome (RegVerify.level ())) then 0 else l end

  (* rhc's identity (its own Config, M8, over its plan and closure), the
     formats it writes, the code's instruction set, the level and passes of
     Mid's pipeline, the width of int, the probe of the hash (hosts whose
     hash differs take none of each other's entries), the checks of casts,
     and what of rhc's front end changes a unit's code, which its driver
     gives (extra: the strings' form, the match's order, the names'
     reading) *)
  fun settings (extra : (string * string) list) : (string * string) list =
    [("tool", "rhc"), ("identity", Config.identity), ("store", Int.toString RhcStore.version),
     ("unitfile", Int.toString UnitFile.version), ("isa", Int.toString (MidPipeline.fingerprint ())),
     ("level", Int.toString (!Pass.level)), ("passes", case !Pass.only of NONE => "-" | SOME ps => String.concatWith "," ps),
     ("intbits", Int.toString (!Target.intBits)), ("hash", Pickle.probe ())]
    @ (if !Lower.checkCasts then [("check-casts", "1")] else [])
    @ extra

  fun configuration (extra : (string * string) list) : string = UnitStore.configuration (RhcStore.hash, settings extra)
end
