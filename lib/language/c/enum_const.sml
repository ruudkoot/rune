(* Implements: C_ENUM_CONST *)
structure CEnumConst :> C_ENUM_CONST =
struct
  datatype definition = Zero | Successor of string | Expression of CLex.token list
  type environment = (string * definition * CLex.location) list
  exception Error = CConst.Error
  fun collect declarations =
    let
      val definitions = ref ([] : environment)
      fun add (name, value, location) =
        case List.find (fn (n, _, _) => n = name) (!definitions) of
          NONE => definitions := (name, value, location) :: !definitions
        | SOME (_, old, at) => if old = value andalso at = location then ()
            else raise Error (location, "duplicate enumerator: " ^ name)
      fun ctype location (CParse.Attributed (base, _)) = ctype location base
        | ctype location (CParse.Pointer {target, ...}) = ctype location target
        | ctype location (CParse.Array {element, ...}) = ctype location element
        | ctype location (CParse.Function {result, ...}) = ctype location result
        | ctype location (CParse.Enum {values = SOME values, ...}) =
          let fun go ([], _) = ()
                | go ((name, tokens) :: rest, previous) =
                  (add (name, if not (null tokens) then Expression tokens else
                    case previous of NONE => Zero | SOME p => Successor p, location);
                   go (rest, SOME name))
          in go (values, NONE) end
        | ctype _ (CParse.Record {fields = SOME fields, ...}) =
            List.app (fn CParse.Field {ctype = base, location, ...} => ctype location base) fields
        | ctype _ _ = ()
      val () = List.app (fn CParse.Declaration {ctype = base, location, ...} => ctype location base | _ => ()) declarations
    in rev (!definitions) end
  fun evaluate {environment, width, name} =
    let
      val () = if width >= 8 andalso width <= 128 then () else raise Domain
      val memo = ref ([] : (string * CConst.value) list)
      val missing : CLex.location = {file = "<enum>", line = 1, column = 1}
      fun beforeName name =
        let fun go [] = [] | go ((n, _, _) :: rest) = if n = name then [] else n :: go rest
        in go environment end
      fun lookup visible active name =
        if List.exists (fn n => n = name) active then raise Error (missing, "cyclic enumerator: " ^ name)
        else if not (List.exists (fn n => n = name) visible) then NONE
        else case List.find (fn (n, _) => n = name) (!memo) of SOME (_, v) => SOME v
        | NONE => case List.find (fn (n, _, _) => n = name) environment of NONE => NONE
          | SOME (_, definition, location) =>
            let val value = case definition of Zero => {integer = 0, unsigned = false}
                  | Successor previous =>
                    (case lookup (beforeName name) (name :: active) previous of
                       SOME {integer, unsigned} =>
                         let val first = {kind = CLex.Identifier, text = "__runeffi_previous_enum",
                               space = false, location = location, origins = []} : CLex.token
                             val plus = {kind = CLex.Punctuation, text = "+", space = true, location = location, origins = []} : CLex.token
                             val one = {kind = CLex.Number, text = "1", space = true, location = location, origins = []} : CLex.token
                             val () = if integer < IntInf.- (IntInf.<< (1, Word.fromInt width), 1) then ()
                               else raise Error (location, "enumerator increment out of range")
                         in CConst.evaluate {width = width, lookup = fn n => if n = "__runeffi_previous_enum" then
                              SOME {integer = integer, unsigned = unsigned} else NONE, tokens = [first, plus, one]} end
                     | NONE => raise Error (location, "missing previous enumerator: " ^ previous))
                  | Expression tokens => CConst.evaluate {width = width, lookup = lookup (beforeName name) (name :: active), tokens = tokens}
            in memo := (name, value) :: !memo; SOME value end
    in case lookup (List.map #1 environment) [] name of SOME v => v | NONE => raise Error (missing, "unknown enumerator: " ^ name) end
end
