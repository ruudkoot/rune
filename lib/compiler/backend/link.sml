(* The units of a program, linked into one (docs/units.md;
   docs/plans/incremental-compilation.md, D7 and M2). A unit is compiled on
   its own, after the units before it, into code numbered from 0: its own
   functions, its top level the first of them, then the functions of
   earlier units it calls by name; the globals it names, its own and theirs,
   in the order it first names them; its constants, labels, files and
   inlined frames. Linking gives each unit a base for each of these and
   renumbers every operand that names one, by the kind the instruction set
   gives it (RegCodes.linked, Opcodes.linked): an own function or
   constant by the unit's base, a function or global of another unit by
   its name, through the unit that defines it. A unit names what it
   declared, and what earlier units did, by a key: a unit's identity and a
   number there (UnitBasis, which gives the numbers), so that a unit's code
   does not depend on what was compiled before it.

   A unit's top level ends in a tail call of the next unit's (Lower, the
   import `next`), so that the program's function 0 is the first unit's
   top level and one top level is running at a time, as in a program
   compiled whole: a trace shows the same frames. The last unit's goes to
   a function that returns. *)
structure Link =
struct
  open Code

  (* A unit as the compile made it, its names the session's stamps: the
     stamp of every global it names, by its index here; the stamps of the
     globals it sets (its own); the functions of earlier units it calls by
     name, and the next unit's top level (stamp `next`), by their index here;
     and its own functions that other units may call by name, by stamp. Its
     own functions are those of code. *)
  type sessionCode = {code : Code.program,
                      globals : (int * int) list,      (* stamp, index here *)
                      defines : int list,              (* stamps *)
                      imports : (int * int) list,      (* index here, stamp *)
                      exports : (int * int) list}      (* stamp, index here *)

  (* A name a unit's code has of a unit: that unit's identity and its number
     there; the next unit's top level is {unit = "", number = ~1} *)
  type key = {unit : string, number : int}

  (* A unit as it is linked, written and loaded: its identity; each global
     it names, by its index here; the functions of earlier units it calls by
     name, and the next unit's top level, by their index here; and its own
     functions that other units may call by name, by number. The globals
     whose key is the unit's own are those it sets. *)
  type unitCode = {code : Code.program,
                   identity : string,
                   globals : (key * int) list,         (* key, index here *)
                   imports : (int * key) list,         (* index here, key *)
                   exports : (int * int) list}         (* number, index here *)

  (* the stamp a unit's top level names the next unit's by, and its key *)
  val next = Lower.nextUnit
  val nextKey : key = {unit = "", number = ~1}

  (* The globals a unit's code sets, by stamp, each once: its own. *)
  fun defines (p : Low.program) : int list =
    IntMap.listKeys
      (List.foldl (fn ({blocks, ...} : Low.func, acc) =>
                     List.foldl (fn ({instrs, ...} : Low.block, acc) =>
                                   List.foldl (fn (Low.Def (_, Low.SetGlobal (g, _)), acc) => IntMap.insert (acc, g, ())
                                                | (_, acc) => acc)
                                              acc instrs)
                                acc blocks)
                  IntMap.empty p)

  fun bug msg = Error.bug ("link: " ^ msg)

  (* The function the last unit's top level goes to, made by the target
     from Low as every other function is: it returns its argument. *)
  fun endFunction (target : Low.program -> Code.program) : Code.program =
    target [{id = 0, name = "<toplevel>", params = [0], ncaptured = 0, nvars = 1,
             blocks = [{label = 0, params = [], instrs = [], transfer = Low.Return 0}], pos = NONE,
             reps = Vector.fromList [Low.RUnit]}]

  (* What each unit of the last program linked exports, by its numbers, as
     the program has it -- a function (0) or a global (1), its number in the
     unit, its index in the program -- for a unit loaded into the program
     later to name (docs/units.md, Dynamic modules) *)
  val lastExports : (string * (int * int * int) list) list ref = ref []
  val () = CompilerState.cellRoot ("Link.lastExports", lastExports)

  fun program (target : Low.program -> Code.program, linked : (int * int) list vector, units : unitCode list)
      : Code.program =
    let
      val units = units @ [{code = endFunction target, identity = "", globals = [], imports = [], exports = []}]
      (* every key a number of the link's own: next is next *)
      val keyIds : int StringMap.map ref = ref StringMap.empty
      fun keyId ({unit, number} : key) : int =
        if unit = "" andalso number = ~1 then next
        else
          let val k = unit ^ "\000" ^ Int.toString number
          in
            case StringMap.find (!keyIds, k) of
              SOME i => i
            | NONE => let val i = StringMap.numItems (!keyIds) in keyIds := StringMap.insert (!keyIds, k, i); i end
          end
      (* the bases of each unit's functions *)
      val nunits = List.length units
      val fbases =
        Vector.fromList (List.rev (#2 (List.foldl (fn (u : unitCode, (b, acc)) => (b + List.length (#funcs (#code u)), b :: acc))
                                                  (0, []) units)))
      (* every function another unit may call by name, by stamp *)
      val exported =
        #2 (List.foldl (fn (u : unitCode, (i, m)) =>
                          (i + 1, List.foldl (fn ((n, f), m) =>
                                                IntMap.insert (m, keyId {unit = #identity u, number = n},
                                                               Vector.sub (fbases, i) + f)) m
                                             (#exports u)))
                       (0, IntMap.empty) units)
      (* the files and inlined frames of the whole, in order *)
      val files : string list ref = ref []
      val nfiles = ref 0
      val fileIndex : int StringMap.map ref = ref StringMap.empty
      fun fileIdx name =
        case StringMap.find (!fileIndex, name) of
          SOME i => i
        | NONE => let val i = !nfiles in files := name :: !files; nfiles := i + 1; fileIndex := StringMap.insert (!fileIndex, name, i); i end
      val inlines : (string * int * int * int * int) list ref = ref []
      val ninlines = ref 0
      val consts : Lambda.const list ref = ref []
      val nconsts = ref 0
      val nglobals = ref 0
      val globalOf : int IntMap.map ref = ref IntMap.empty
      val nlabels = ref 0
      fun linkUnit (i, u : unitCode) : Code.func list =
        let
          val code = #code u
          val fbase = Vector.sub (fbases, i)
          val nown = List.length (#funcs code)
          val cbase = !nconsts
          val lbase = !nlabels
          val ibase = !ninlines
          (* the stamp of each global it names, by its index here *)
          val stamps = Array.array (#nglobals code, ~1)
          val () = List.app (fn (k, ix) => Array.update (stamps, ix, keyId k)) (#globals u)
          (* the globals it sets, its own, get the next numbers, in the order
             of their index here; the others are another unit's *)
          val own = List.foldl (fn (({unit, ...} : key, ix), m) =>
                                  if unit = #identity u then IntMap.insert (m, Array.sub (stamps, ix), ()) else m)
                               IntMap.empty (#globals u)
          val () =
            Array.app (fn st =>
                         if IntMap.member (own, st) andalso not (IntMap.member (!globalOf, st))
                         then (globalOf := IntMap.insert (!globalOf, st, !nglobals); nglobals := !nglobals + 1)
                         else ())
                      stamps
          val globalMap =
            Array.tabulate (Array.length stamps,
                            fn ix => let val st = Array.sub (stamps, ix)
                                     in case IntMap.find (!globalOf, st) of
                                          SOME g => g
                                        | NONE => bug ("a global is set by no unit before (" ^ Int.toString st ^ ")")
                                     end)
          val importMap = List.foldl (fn ((ix, k), m) => IntMap.insert (m, ix, keyId k)) IntMap.empty (#imports u)
          fun func f =
            if f < nown then fbase + f
            else case IntMap.find (importMap, f) of
                   SOME s =>
                     if s = next then Vector.sub (fbases, i + 1)
                     else (case IntMap.find (exported, s) of
                             SOME g => g
                           | NONE => bug ("a function is exported by no unit before (" ^ Int.toString s ^ ")"))
                 | NONE => bug ("function " ^ Int.toString f ^ " of a unit is neither its own nor imported")
          fun global g = Array.sub (globalMap, g)
          fun renumber (kind, v) =
            case kind of
              0 => func v
            | 1 => global v
            | _ => cbase + v
          fun operands (opc, args : 'a list, get : 'a -> int option, put : 'a * int -> 'a) : 'a list =
            let
              val ks = Vector.sub (linked, opc)
              fun go (_, []) = []
                | go (n, a :: rest) =
                    (case (List.find (fn (p, _) => p = n) ks, get a) of
                       (SOME (_, k), SOME v) => put (a, renumber (k, v))
                     | _ => a) :: go (n + 1, rest)
            in go (0, args) end
          val files = Vector.fromList (#files code)
          val fileMap = Vector.map fileIdx files
          fun file f = if f >= 0 andalso f < Vector.length fileMap then Vector.sub (fileMap, f) else f
          fun inline j = if j = 0 then 0 else ibase + j
          fun item it =
            case it of
              Op (opc, args) => Op (opc, operands (opc, args, SOME, fn (_, v) => v))
            | Ops (opc, args) =>
                Ops (opc, List.map (fn I v => I v | L l => L (lbase + l))
                                   (operands (opc, args, fn I v => SOME v | L _ => NONE, fn (_, v) => I v)))
            | OpLab (opc, l) => OpLab (opc, lbase + l)
            | OpLabImm (opc, l, x) => OpLabImm (opc, lbase + l, x)
            | Lab l => Lab (lbase + l)
            | Pos (f, line, col, j) => Pos (file f, line, col, inline j)
          fun meta NONE = NONE
            | meta (SOME {arity, reps, blocks, loops} : meta option) =
                SOME {arity = arity, reps = reps, blocks = List.map (fn (l, ps) => (lbase + l, ps)) blocks,
                      loops = List.map (fn l => lbase + l) loops}
          val () =
            List.app (fn (name, f, line, col, parent) =>
                        (inlines := (name, if line = 0 then f else file f, line, col, inline parent) :: !inlines;
                         ninlines := !ninlines + 1))
                     (#inlines code)
          val () = List.app (fn c => (consts := c :: !consts; nconsts := !nconsts + 1)) (#consts code)
          val () = nlabels := lbase + #nlabels code
        in
          List.map (fn ({id, nlocals, code, name, meta = m} : func) =>
                      {id = fbase + id, nlocals = nlocals, code = List.map item code, name = name, meta = meta m})
                   (#funcs code)
        end
      val funcs = List.concat (List.rev (#2 (List.foldl (fn (u, (i, acc)) => (i + 1, linkUnit (i, u) :: acc)) (0, []) units)))
      val () =
        lastExports :=
          List.mapPartial
            (fn (i, u : unitCode) =>
               if #identity u = "" then NONE
               else
                 (* by kind and number: a unit read from the cache lists its
                    globals in another order than its compile did *)
                 SOME (#identity u,
                       List.foldl (fn (x as (k, n, _), acc) =>
                                     let fun ins [] = [x]
                                           | ins ((y as (k', n', _)) :: rest) =
                                               if k < k' orelse (k = k' andalso n < n') then x :: y :: rest
                                               else if k = k' andalso n = n' then y :: rest
                                               else y :: ins rest
                                     in ins acc end) []
                                  (List.map (fn (n, f) => (0, n, Vector.sub (fbases, i) + f)) (#exports u)
                                   @ List.mapPartial (fn (k : key, _) =>
                                                        if #unit k = #identity u
                                                        then Option.map (fn g => (1, #number k, g)) (IntMap.find (!globalOf, keyId k))
                                                        else NONE)
                                                     (#globals u))))
            (ListPair.zip (List.tabulate (nunits, fn i => i), units))
    in
      {consts = List.rev (!consts), nglobals = !nglobals, funcs = funcs, files = List.rev (!files),
       inlines = List.rev (!inlines), nlabels = !nlabels}
    end
end
