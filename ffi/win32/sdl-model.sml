(* The same Win32 state machine is used by SDL and deterministic mocks. *)
structure Win32Sdl=Win32ModelFn(Win32SdlDriver)
