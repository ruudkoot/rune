(* rhc's units (the haskell98 roadmap's M21c): a unit's Core compiled to a
   unit file of its own, which names the globals of the units it imports
   and is linked with them, as Rune links its units (Link, UnitFile).

   A value of the top level is an entity, by its Core name: the session
   gives each one stamp, which every unit that names it reads it at
   (MidText.parseWith's named), and Link knows it by its owner's unit and a
   number of its name. An import is in the unit's text as a placeholder of
   its scheme (CoreToMid.unit), dropped once read, its scheme MidLint's,
   and a function among them Lower's known (Lower.knownBefore). *)
structure RhcUnits =
struct
  structure M = Mid

  exception Error of string

  (* the session's stamp of each entity, a value of a unit: two units may
     each define a name (a program's own and the runtime's) *)
  val stamps : int StringMap.map ref = ref StringMap.empty
  fun stampOf (unit : string, x : string) : int =
    let val k = unit ^ "\000" ^ x
    in
      case StringMap.find (!stamps, k) of
        SOME s => s
      | NONE => let val s = Stamp.fresh () in stamps := StringMap.insert (!stamps, k, s); s end
    end

  (* An entity's number in its unit's link: above the places of a unit's
     own globals, from its name's hash, the same in every compile *)
  fun numberOf (x : string) : int =
    65536 + valOf (StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (Pickle.hash x, 0, 6)))

  (* what a unit compiled is: its name, its code, how each of its values is
     made (CoreToMid.abi), and the values it exports, which are all its
     own *)
  type compiled = {name : string, code : Link.unitCode option, abi : (string * CoreToMid.abi) list, exports : string list,
                   iface : Core.program, newtypes : (string * bool) list}

  (* The unit p compiled, named name, against the units compiled before it
     (earlier): each import's owner and making from the latest of them that
     exports it *)
  fun compile ({name, earlier, fault} : {name : string, earlier : compiled list, fault : CoreToMid.fault option})
              (p : Core.program) : compiled =
    let
      (* the first unit, the runtime's, makes the prelude's exceptions, and
         every other imports them (CoreToMid.shared) *)
      val makesShared = null earlier
      val imports = List.mapPartial (fn Core.Import (x, _) => SOME x | _ => NONE) p
                    @ (if makesShared then [] else CoreToMid.shared)
      (* the latest unit before this one that exports x, as the driver takes
         a name from *)
      fun ownerOf x =
        case List.find (fn (u : compiled) => List.exists (fn y => y = x) (#exports u)) (List.rev earlier) of
          SOME u => u
        | NONE => raise Error ("the unit " ^ name ^ " imports " ^ x ^ ", which no unit before it exports")
      val importAbi = List.map (fn x => case List.find (fn (y, _) => y = x) (#abi (ownerOf x)) of
                                          SOME (_, a) => (x, a)
                                        | NONE => raise Error ("no making of " ^ x)) imports
      (* each newtype p copies of another unit, a box where that unit made
         it one: the latest unit before this one that declares it *)
      val copied =
        List.mapPartial (fn Core.Newtype (t, _, _, _) =>
                              List.foldl (fn (u : compiled, found) =>
                                            case List.find (fn (n, _) => n = t) (#newtypes u) of
                                              SOME nb => SOME nb
                                            | NONE => found)
                                         NONE earlier
                          | _ => NONE) p
      val {text, names, abi, boxed} =
        CoreToMid.unit ({fault = fault, imports = importAbi, makesShared = makesShared, newtypes = copied}, p)
      val exports = List.map #1 abi
      (* the text's names of the entities, own and imported *)
      val byText = List.foldl (fn ((x, g), m) => StringMap.insert (m, g, x)) StringMap.empty names
      fun isOwn x = List.exists (fn y => y = x) exports
      fun entity x = if isOwn x then stampOf (name, x) else stampOf (#name (ownerOf x), x)
      fun named g = Option.map entity (StringMap.find (byText, g))
      val importStamps = List.map (fn x => (entity x, x)) imports
      fun isImport s = List.exists (fn (t, _) => t = s) importStamps
      (* the text read, each import's placeholder dropped and its scheme
         MidLint's *)
      fun parse text =
        let
          val prog = MidText.parseWith {stamp = Stamp.fresh, tycon = fn () => #stamp (Types.freshTycon ("", 0, true)),
                                        named = named} text
                     handle MidText.Syntax msg => raise Error.Bug ("Mid's reader refuses what Core to Mid wrote: " ^ msg)
          val schemes = List.foldl (fn (M.Val (g, s, _), m) => if isImport g then IntMap.insert (m, g, s) else m | (_, m) => m)
                                   IntMap.empty prog
          val () = MidLint.importedScheme := (fn g => IntMap.find (schemes, g))
        in List.filter (fn M.Val (g, _, _) => not (isImport g) | _ => true) prog end
      val () = Pass.whole := false
      val () = Lower.knownBefore :=
                 List.foldl (fn (((s, _), (_, CoreToMid.Function)), m) => IntMap.insert (m, s, ()) | (_, m) => m)
                            IntMap.empty (ListPair.zip (importStamps, importAbi))
      val mid = MidPipeline.midStage NONE parse text
      val low = MidPipeline.lowOfMid MidPipeline.standardPasses mid
      val code = MidPipeline.targetStage low
      val sc : Link.sessionCode =
        {code = code, globals = IntMap.listItemsi (!Code.globals), defines = Link.defines low,
         imports = List.map (fn (s, i) => (i, s)) (IntMap.listItemsi (!Lower.imported)),
         exports = IntMap.listItemsi (!Lower.globalFids)}
      (* keys: an import by its owner and its number, an export by its
         number, a private global by its place *)
      val exportStamps = List.map (fn x => (entity x, x)) exports
      val numbers = List.map (numberOf o #2) exportStamps
      val () =
        case List.find (fn n => List.length (List.filter (fn m => m = n) numbers) > 1) numbers of
          SOME n => raise Error ("two values of the unit " ^ name ^ " have the number " ^ Int.toString n)
        | NONE => ()
      val privates : int IntMap.map ref = ref IntMap.empty
      fun key (s : int) : Link.key =
        if s = Link.next then Link.nextKey
        else
          case List.find (fn (t, _) => t = s) importStamps of
            SOME (_, x) => {unit = #name (ownerOf x), number = numberOf x}
          | NONE =>
              case List.find (fn (t, _) => t = s) exportStamps of
                SOME (_, x) => {unit = name, number = numberOf x}
              | NONE =>
                  {unit = name,
                   number = case IntMap.find (!privates, s) of
                              SOME n => n
                            | NONE => let val n = IntMap.numItems (!privates)
                                      in privates := IntMap.insert (!privates, s, n); n end}
      fun byPlace (place : 'a -> int) (l : 'a list) : 'a list =
        IntMap.listItems (List.foldl (fn (x, m) => IntMap.insert (m, place x, x)) IntMap.empty l)
      val u : Link.unitCode =
        {code = #code sc, identity = name, provenance = NONE,
         globals = byPlace #2 (List.map (fn (s, ix) => (key s, ix)) (#globals sc)),
         imports = byPlace #1 (List.map (fn (ix, s) => (ix, key s)) (#imports sc)),
         exports = byPlace #1 (List.map (fn (s, ix) => (#number (key s), ix)) (#exports sc))}
    in
      {name = name, code = SOME u, abi = abi, exports = exports,
       (* its interface: each of its values, and each type it declares *)
       iface = CoreUnits.interface (p, List.mapPartial (fn Core.Val (x, _, _) => SOME x | Core.Data (t, _, _) => SOME t
                                                         | Core.Newtype (t, _, _, _) => SOME t | _ => NONE) p),
       newtypes = boxed}
    end

  (* ---- a unit kept in the store (RhcStore) ---- *)

  fun abiName a = case a of CoreToMid.Function => "Function" | CoreToMid.Suspension => "Suspension" | CoreToMid.Literal => "Literal"
  fun abiOf s =
    case s of
      "Function" => CoreToMid.Function
    | "Suspension" => CoreToMid.Suspension
    | "Literal" => CoreToMid.Literal
    | _ => raise Error ("a unit's entry names no making " ^ s)

  (* its interface's section: each value's making, a line each, then the
     interface's Core *)
  fun ifaceText ({abi, iface, newtypes, ...} : compiled) : string =
    String.concat (List.map (fn (x, a) => "abi " ^ abiName a ^ " " ^ x ^ "\n") abi)
    ^ String.concat (List.map (fn (t, b) => "newtype " ^ (if b then "box" else "bare") ^ " " ^ t ^ "\n") newtypes)
    ^ "---\n" ^ CoreText.show iface

  (* its code's section: its unit file's bytes *)
  fun codeBytes ({code, ...} : compiled) : string = String.concat (UnitFile.chunks (MidPipeline.fingerprint (), valOf code))

  (* the unit an entry keeps, named name *)
  fun fromEntry (name : string, {iface, code} : RhcStore.sections) : compiled =
    let
      fun split (s, i) =
        if i + 5 > String.size s then raise Error ("the entry of " ^ name ^ " has no interface")
        else if String.substring (s, i, 5) = "\n---\n" then (String.substring (s, 0, i + 1), String.extract (s, i + 5, NONE))
        else split (s, i + 1)
      val (head, core) = if String.isPrefix "---\n" iface then ("", String.extract (iface, 4, NONE)) else split (iface, 0)
      val facts = List.map (fn l => String.tokens (fn c => c = #" ") l) (String.tokens (fn c => c = #"\n") head)
      val abi = List.mapPartial (fn ["abi", a, x] => SOME (x, abiOf a)
                                  | ["newtype", _, _] => NONE
                                  | l => raise Error ("the entry of " ^ name ^ " has a line " ^ String.concatWith " " l))
                                facts
      val newtypes = List.mapPartial (fn ["newtype", b, t] => SOME (t, b = "box") | _ => NONE) facts
      val program = CoreText.parse core
                    handle CoreText.Error (_, msg) => raise Error ("the entry of " ^ name ^ ": " ^ msg)
      val (fp, u) = UnitFile.read code handle UnitFile.Bad msg => raise Error ("the entry of " ^ name ^ ": " ^ msg)
      val () = if fp = MidPipeline.fingerprint () then ()
               else raise Error ("the entry of " ^ name ^ " is of another instruction set")
    in {name = name, code = SOME u, abi = abi, exports = List.map #1 abi, iface = program, newtypes = newtypes} end

  (* A unit checked and not compiled, its Core kept for a link that joins
     the units' Core and compiles what main reaches whole (M21's C): its
     interface, and its values' names; no making, no code *)
  fun checked (name : string, p : Core.program) : compiled =
    let val values = List.mapPartial (fn Core.Val (x, _, _) => SOME x | _ => NONE) p
    in
      {name = name, code = NONE, abi = [], exports = values, newtypes = [],
       iface = CoreUnits.interface (p, values @ List.mapPartial (fn Core.Data (t, _, _) => SOME t
                                                                  | Core.Newtype (t, _, _, _) => SOME t | _ => NONE) p)}
    end

  (* Its entry's interface section, as ifaceText gives it, read back *)
  fun ifaceOf (name : string, iface : string) : Core.program =
    let
      fun split (s, i) =
        if i + 5 > String.size s then raise Error ("the entry of " ^ name ^ " has no interface")
        else if String.substring (s, i, 5) = "\n---\n" then String.extract (s, i + 5, NONE)
        else split (s, i + 1)
      val core = if String.isPrefix "---\n" iface then String.extract (iface, 4, NONE) else split (iface, 0)
    in CoreText.parse core handle CoreText.Error (_, msg) => raise Error ("the entry of " ^ name ^ ": " ^ msg) end

  (* the units linked into the program in out, in their order, which is
     dependencies first *)
  fun link (units : compiled list, out : string) : unit =
    let
      val registers = !CompilerSettings.target = "registers"
      val prog = if registers then Link.program (Regs.program, RegCodes.linked, List.map (valOf o #code) units)
                 else Link.program (Stack.program, Opcodes.linked, List.map (valOf o #code) units)
    in Emit.writeFileAs (MidPipeline.fingerprint (), out, prog) end
end
