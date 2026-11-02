(* Project-independent library selection for ordered compiler sessions. *)
structure CompilerPrelude =
struct
  type plan = {groups : BasisManifest.entry list list, final : BasisManifest.entry list, scopes : BasisManifest.scopes}
  fun groups (entries : BasisManifest.entry list) =
    let fun take (_,[],acc) = (List.rev acc,[])
          | take (dir,e :: rest,acc) = if #dir (e : BasisManifest.entry)=dir
              then take (dir,rest,e :: acc) else (List.rev acc,e :: rest)
        fun all [] = []
          | all (e :: rest) = let val (group,rest)=take (#dir e,rest,[e]) in group :: all rest end
    in all entries end
  fun select {lib,libraries,mentioned,building} : plan =
    case lib of
      NONE => if null libraries then {groups=[],final=[],scopes=BasisManifest.noScopes ""} else raise Fail "libraries require a library root"
    | SOME root =>
      let
        val basis=root ^ "/basis"
        val read=List.map (fn dir => (dir,BasisManifest.readManifest dir)) (BasisManifest.libraries (root,libraries))
        val entries=BasisManifest.readManifest basis @ List.concat (List.map #2 read)
        val scopes=BasisManifest.scopes {root=root,building=building,names=libraries,headed=false,libraries=read}
        val initially=BasisManifest.select (scopes,entries,mentioned)
        fun names (e : BasisManifest.entry,mentioned) =
          BasisManifest.namesOf (Lexer.tokenize (Source.load (Source.Ascii,BasisManifest.path e)),mentioned)
        val mentioned=List.foldl names mentioned (List.filter (fn e : BasisManifest.entry => #dir e <> basis) initially)
        val selected=BasisManifest.select (scopes,entries,mentioned)
      in {groups=groups (List.filter (fn e : BasisManifest.entry => #when e <> BasisManifest.Final) selected),
          final=List.filter (fn e : BasisManifest.entry => #when e = BasisManifest.Final) selected,scopes=scopes} end
end
