(* Project-independent library selection for ordered compiler sessions. *)
structure CompilerPrelude =
struct
  type plan = {groups : BasisManifest.entry list list, final : BasisManifest.entry list}
  fun groups (entries : BasisManifest.entry list) =
    let fun take (_,[],acc) = (List.rev acc,[])
          | take (dir,e :: rest,acc) = if #dir (e : BasisManifest.entry)=dir
              then take (dir,rest,e :: acc) else (List.rev acc,e :: rest)
        fun all [] = []
          | all (e :: rest) = let val (group,rest)=take (#dir e,rest,[e]) in group :: all rest end
    in all entries end
  fun select {lib,libraries,mentioned} : plan =
    case lib of
      NONE => if null libraries then {groups=[],final=[]} else raise Fail "libraries require a library root"
    | SOME root =>
      let
        val basis=root ^ "/basis"
        val entries=BasisManifest.readManifest basis @ List.concat (List.map BasisManifest.readManifest
          (BasisManifest.libraries (root,libraries)))
        val initially=BasisManifest.select (entries,mentioned)
        fun names (e : BasisManifest.entry,mentioned) =
          BasisManifest.namesOf (Lexer.tokenize (Source.load (Source.Ascii,BasisManifest.path e)),mentioned)
        val mentioned=List.foldl names mentioned (List.filter (fn e : BasisManifest.entry => #dir e <> basis) initially)
        val selected=BasisManifest.select (entries,mentioned)
      in {groups=groups (List.filter (fn e : BasisManifest.entry => #when e <> BasisManifest.Final) selected),
          final=List.filter (fn e : BasisManifest.entry => #when e = BasisManifest.Final) selected} end
end
