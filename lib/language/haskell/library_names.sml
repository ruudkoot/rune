(* Implements: HS_LIBRARY_NAMES *)
structure HsLibraryNames :> HS_LIBRARY_NAMES =
struct
  type t = {prefix : string, prelude : string, text : string, ix : string, ratio : string, builtin : string}

  val haskell98 : t =
    {prefix = "haskell98", prelude = "Prelude", text = "PreludeText", ix = "Ix", ratio = "Ratio", builtin = "PreludeBuiltin"}

  fun identity ({prefix, ...} : t, m) = prefix ^ ":" ^ m

  fun isLibrary ({prefix, ...} : t, id) = String.isPrefix (prefix ^ ":") id

  fun entity (t : t, role : t -> string, name) = identity (t, role t) ^ "." ^ name
end
