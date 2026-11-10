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
  type compiled = {name : string, code : Link.unitCode, abi : (string * CoreToMid.abi) list, exports : string list}

  (* The unit p compiled, named name, against the units compiled before it
     (earlier): each import's owner and making from the first of them that
     exports it *)
  fun compile ({name, earlier, fault} : {name : string, earlier : compiled list, fault : CoreToMid.fault option})
              (p : Core.program) : compiled =
    let
      (* the first unit, the runtime's, makes the prelude's exceptions, and
         every other imports them (CoreToMid.shared) *)
      val makesShared = null earlier
      val imports = List.mapPartial (fn Core.Import (x, _) => SOME x | _ => NONE) p
                    @ (if makesShared then [] else CoreToMid.shared)
      fun ownerOf x =
        case List.find (fn (u : compiled) => List.exists (fn y => y = x) (#exports u)) earlier of
          SOME u => u
        | NONE => raise Error ("the unit " ^ name ^ " imports " ^ x ^ ", which no unit before it exports")
      val importAbi = List.map (fn x => case List.find (fn (y, _) => y = x) (#abi (ownerOf x)) of
                                          SOME (_, a) => (x, a)
                                        | NONE => raise Error ("no making of " ^ x)) imports
      val {text, names, abi} = CoreToMid.unit ({fault = fault, imports = importAbi, makesShared = makesShared}, p)
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
    in {name = name, code = u, abi = abi, exports = exports} end

  (* the units linked into the program in out, in their order, which is
     dependencies first *)
  fun link (units : compiled list, out : string) : unit =
    let
      val registers = !CompilerSettings.target = "registers"
      val prog = if registers then Link.program (Regs.program, RegCodes.linked, List.map #code units)
                 else Link.program (Stack.program, Opcodes.linked, List.map #code units)
    in Emit.writeFileAs (MidPipeline.fingerprint (), out, prog) end
end
