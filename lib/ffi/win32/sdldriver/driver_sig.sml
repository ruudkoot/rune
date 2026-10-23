(* SDL3 implementation of the shared Win32 GUI driver's drawing and input.

   Area: Foreign interfaces *)
signature WIN32_SDL_DRIVER =
sig
  include WIN32_GUI_DRIVER
  (* `load paths` loads generated SDL libraries and initializes owning-thread video.

     The selected M9 support functions suppress automatic quit on window close. *)
  val load : string list -> unit
  (* `shutdown ()` quits and unloads SDL after every driver window closes. *)
  val shutdown : unit -> unit
end
