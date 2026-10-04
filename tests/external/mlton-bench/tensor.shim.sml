(* shim for SML/NJ's and MLton's Unsafe structure, which tensor uses *)
structure Unsafe = struct
  structure Real64Array = struct val sub = Real64Array.sub val update = Real64Array.update end
end
