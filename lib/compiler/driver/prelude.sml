(* The files of the libraries that a compile takes: the one choice, for a
   program compiled and for the sessions, queries and analyses of the
   compiler's API, so that each selects as the others do (D7; BasisManifest,
   the choice itself). *)
structure CompilerPrelude =
struct
  type entry = BasisManifest.entry
  type names = BasisManifest.names
  type plan = {groups : entry list list, final : entry list, scopes : BasisManifest.scopes}

  (* the entries of one library, which come together, in order; the seals of
     a view of the Basis Library are a group of their own, after the
     libraries (D12) *)
  fun groups (entries : entry list) =
    let fun same (e : entry) (e' : entry) = #dir e = #dir e' andalso isSome (#view e) = isSome (#view e')
        fun take (_,[],acc) = (List.rev acc,[])
          | take (first,e :: rest,acc) = if same first e
              then take (first,rest,e :: acc) else (List.rev acc,e :: rest)
        fun all [] = []
          | all (e :: rest) = let val (group,rest)=take (e,rest,[e]) in group :: all rest end
    in all entries end

  (* What a file of the program names of the libraries: the names it uses
     (Deps), and not every identifier, or alpha-renaming a bound variable
     could change what links and what runs (D7). A file that does not parse
     under the initial basis's fixity, which a file may not be read in, has
     no syntax until the compile's own parse: its tokens. *)
  fun usedBy (path : string, toks : Lexer.item vector, names : names) : names =
    let val f = Deps.analyse (path, #1 (Parser.parseTokensWith (toks, Fixity.initial)))
    in BasisManifest.boundaryNames (toks, List.foldl (fn ((_, n), m) => StringMap.insert (m, n, ())) names (#free f)) end
    handle Error.CompileError _ => BasisManifest.namesOf (toks, names)

  (* What the files of a program name of the libraries that provide names to
     mention (entries). A name a file uses is one of its tokens, so a file none
     of whose tokens is a name to mention that the files before it did not
     mention cannot change the selection, and is not parsed: in a large
     program most are not, which is most of what this costs a warm build. A
     small program is parsed: the table of the names costs more than that. *)
  fun usedByAll (scopes : BasisManifest.scopes, entries : entry list, inputs : string list, toks : Lexer.item vector list) : names =
    if List.foldl (fn (t, n) => n + Vector.length t) 0 toks < 4096
    then ListPair.foldl usedBy StringMap.empty (inputs, toks)
    else
        let
          val provided = List.foldl (fn (e : entry, m) => List.foldl (fn (n, m) => StringMap.insert (m, n, ())) m (BasisManifest.forProgram (scopes, e)))
                                    StringMap.empty entries
          fun usable names n = StringMap.member (provided, n) andalso not (StringMap.member (names, n))
          fun anything names =
            fn (Token.ID s, _) => usable names s
             | (Token.LONGID (s :: _, _), _) => usable names s
             | (Token.DYNAMIC, _) => usable names "RuneDynamic"
             | (Token.EXPORT, _) => usable names "RuneDynamic"
             | (Token.VIRTUAL, _) => usable names "RuneDynamic"
             | _ => false
        in
          ListPair.foldl (fn (path, tokens, names) => if Vector.exists (anything names) tokens then usedBy (path, tokens, names) else names)
                         StringMap.empty (inputs, toks)
        end

  (* What a compile chooses from: the Basis Library and the named libraries
     with those they are written on, in the order they are compiled, each
     with its entries, and what each scope sees. *)
  type candidates = {libraries : (string * entry list) list, entries : entry list, scopes : BasisManifest.scopes}
  fun candidates {root : string, libraries : string list, building : string option, view : string option} : candidates =
    let
      val read = List.map (fn dir => (dir,BasisManifest.readManifest dir)) (BasisManifest.libraries (root,libraries))
    in
      {libraries=read,entries=BasisManifest.readManifest (root ^ "/basis") @ List.concat (List.map #2 read),
       scopes=BasisManifest.scopes {root=root,building=building,names=libraries,headed=false,libraries=read,view=view}}
    end

  (* What a program that mentions these names loads. A library beside the
     Basis Library sees it as a program does, through its seals: what the
     chosen files of the libraries name counts as mentioned, and the choice is
     made again with it. tokens reads such a file. *)
  fun choose ({entries,scopes,...} : candidates, mentioned : names, tokens : entry -> Lexer.item vector) : entry list =
    let
      fun beside (e : entry) = #dir e <> #basis scopes
      val initially = BasisManifest.select (scopes,entries,mentioned)
      val mentioned = List.foldl (fn (e,m) => BasisManifest.namesOf (tokens e,m)) mentioned (List.filter beside initially)
    in BasisManifest.select (scopes,entries,mentioned) end

  fun planOf (selected : entry list, scopes : BasisManifest.scopes) : plan =
    let val (final,before') = List.partition (fn e : entry => #when e = BasisManifest.Final) selected
    in {groups=groups before',final=final,scopes=scopes} end

  fun select {lib,libraries,mentioned,building} : plan =
    case lib of
      NONE => if null libraries then {groups=[],final=[],scopes=BasisManifest.noScopes ""} else raise Fail "libraries require a library root"
    | SOME root =>
        let
          val found = candidates {root=root,libraries=libraries,building=building,view=NONE}
          val scopes = #scopes found
          (* a clash is an error here as in a compile (D9) *)
          val () = if not (#scoped scopes) then ()
                   else case BasisManifest.clashes (#program scopes,#entries found,root ^ "/basis") of
                          [] => ()
                        | clash :: _ => raise BasisManifest.Usage (LibraryIndex.clashText root clash)
          fun tokens (e : entry) = Lexer.tokenize (Source.load (Source.Ascii,BasisManifest.path e))
        in planOf (choose (found,mentioned,tokens),scopes) end
end
