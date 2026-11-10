(* Core in units (the haskell98 roadmap's M21): units joined into one
   program. A type is the same in two units where its declaration prints
   the same, and an import is at its definition's type where the types
   print the same, since an interface gives a client the exporter's
   declaration and type as they are (HsIface). *)
structure CoreUnits :> CORE_UNITS =
struct
  open Core

  exception Error of string

  fun declText d = CoreText.show [d]

  fun join (units : program list) : program =
    let
      val all = List.concat units
      (* the values the units define, with their types *)
      val defined = List.foldl (fn (Val (x, t, _), m) => CoreMap.insert (m, x, t) | (_, m) => m) CoreMap.empty all
      fun keep (d, (types, acc)) =
        case d of
          Import (x, t) =>
            (case CoreMap.find (defined, x) of
               NONE => (types, d :: acc)
             | SOME u =>
                 if CoreText.showTy t = CoreText.showTy u then (types, acc)
                 else raise Error ("the import of " ^ x ^ " is at " ^ CoreText.showTy t ^ ", and its definition at "
                                   ^ CoreText.showTy u))
        | Val _ => (types, d :: acc)
        | _ =>
            let
              val t = case d of Data (t, _, _) => t | Newtype (t, _, _, _) => t | _ => ""
              val text = declText d
            in
              case CoreMap.find (types, t) of
                NONE => (CoreMap.insert (types, t, text), d :: acc)
              | SOME first =>
                  if first = text then (types, acc)
                  else raise Error ("the type " ^ t ^ " is declared apart by two units:\n" ^ first ^ "and\n" ^ text)
            end
    in List.rev (#2 (List.foldl keep (CoreMap.empty, []) all)) end

  fun unresolved (p : program) : string list =
    let val defined = List.foldl (fn (Val (x, _, _), m) => CoreMap.insert (m, x, ()) | (_, m) => m) CoreMap.empty p
    in List.mapPartial (fn Import (x, _) => if CoreMap.member (defined, x) then NONE else SOME x | _ => NONE) p end
end
