(* Provider controls remain available beside its shared GUI driver signature. *)
structure Win32SdlDriver = Win32SdlDriverFn(structure Sdl = SDL)
