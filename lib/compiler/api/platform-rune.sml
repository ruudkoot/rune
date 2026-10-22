(* The Rune host adapter contains execution, not compiler semantics. *)
structure CompilerApiPlatform =
struct
  (* Captured before client code can link more units. Ordinary unit builds
     initialize the compiler's library dependencies before this adapter.
     Runtime's inventory itself makes no initialization guarantee. *)
  val inherited =
    let val sources=RuneRuntime.linkedUnitSources ()
    in List.map (fn identity => (identity,Option.map #2 (List.find (fn (id,_) => id=identity) sources)))
         (Runtime.linkedUnits ()) end
  fun link bytes = Runtime.link (Byte.stringToBytes bytes)
  val current = RuneRuntime.linkedUnitSources
  fun prepare usesLibraries =
    if usesLibraries andalso null inherited then
      raise Fail "compiler-library execution with libraries requires a host built with --units"
    else ()
end
