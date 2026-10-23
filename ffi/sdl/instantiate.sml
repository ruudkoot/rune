(* The public projection is compiled once against generated target modules. *)
structure SDL = SDLFn (structure Raw = SDLGeneratedRaw
                      structure Layout = SDLGeneratedLayout)
