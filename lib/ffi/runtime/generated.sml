(* Implements: FOREIGN_GENERATED *)
structure ForeignGenerated :> FOREIGN_GENERATED =
struct
  type descriptor = {name : string, symbol : string, abi : int,
    result : RuneForeign.scalar, arguments : RuneForeign.scalar list}
  type abiFacts = {architecture : string, charBits : int, charSigned : bool,
    scalars : {name : string, size : int, alignment : int} list}
  datatype session = Session of {libraries : string list, descriptors : descriptor list,
    opened : (string * RuneForeign.resource) list ref,
    symbols : RuneForeign.resource list ref,
    calls : (string * RuneForeign.resource) list ref, closed : bool ref,
    target : {pointerBytes : int, littleEndian : bool, stdcall : bool},
    abiFacts : abiFacts option}
  exception Closed
  fun make {libraries, descriptors, target, abiFacts} =
    let fun unique [] = () | unique (name :: rest) =
          if List.exists (fn other => other = name) rest then
            raise Fail ("duplicate generated descriptor: " ^ name) else unique rest
        val () = unique (List.map #name descriptors)
    in Session {libraries=libraries, descriptors=descriptors, target=target, abiFacts=abiFacts,
      opened=ref [], symbols=ref [], calls=ref [], closed=ref false} end
  fun create {libraries,descriptors,target} =
    make {libraries=libraries,descriptors=descriptors,target=target,abiFacts=NONE}
  fun createChecked {libraries,descriptors,target,abiFacts} =
    make {libraries=libraries,descriptors=descriptors,target=target,abiFacts=SOME abiFacts}
  fun prepare (Session {libraries, descriptors, target, abiFacts, opened, symbols, calls, closed}) name =
    let val () = if !closed then raise Closed else ()
        val () = if RuneForeign.target () = target then ()
          else raise Fail "generated foreign target does not match the executing VM"
        val () = case abiFacts of NONE=>() | SOME expected=>
          if RuneForeign.abiFacts()=expected then ()
          else raise Fail "generated foreign C ABI facts do not match the executing VM"
        fun library path = case List.find (fn (other, _) => other = path) (!opened) of
            SOME (_, resource) => resource
          | NONE => let val resource = RuneForeign.openLibrary path
                    in opened := (path, resource) :: !opened; resource end
        fun findSymbol spelling [] NONE = raise Fail ("no foreign libraries for symbol: " ^ spelling)
          | findSymbol spelling [] (SOME error) = raise RuneForeign.Error error
          | findSymbol spelling (path :: rest) previous =
              (RuneForeign.symbol (library path, spelling)
               handle RuneForeign.Error error => findSymbol spelling rest (SOME error))
    in case List.find (fn (other, _) => other = name) (!calls) of
        SOME (_, resource) => resource
      | NONE =>
          (case List.find (fn d : descriptor => #name d = name) descriptors of
             NONE => raise Fail ("undeclared generated foreign function: " ^ name)
           | SOME d =>
               let val symbol = findSymbol (#symbol d) libraries NONE
                   val () = symbols := symbol :: !symbols
                   val call = RuneForeign.prepare {symbol=symbol, abi= #abi d,
                     result= #result d, arguments= #arguments d}
                   val () = calls := (name, call) :: !calls
               in call end)
    end
  fun invoke session name arguments = RuneForeign.invoke (prepare session name, arguments)
  fun invokeDeferred session name arguments = RuneForeign.invokeDeferred (prepare session name, arguments)
  fun close (Session {calls, symbols, opened, closed, ...}) =
    let fun releaseList entries resource =
          let fun loop [] = entries := []
                | loop (entry :: rest) =
                    (RuneForeign.release (resource entry); entries := rest; loop rest)
          in loop (!entries) end
    in if !closed then raise Closed else
      (releaseList calls #2; releaseList symbols (fn x => x);
       releaseList opened #2; closed := true) end
end
