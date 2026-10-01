(* The runnable catalogue is separate from the upstream source inventory. *)
structure BenchCatalog =
struct
  type entry = {name: string, profile: string, upstream: string, sourcePath: string,
                args: string list, expected: string, sources: string list,
                seconds: int, memory: int, tags: string list}
  val root = "examples/benchmarks/"

  fun lines path =
    let
      val stream = TextIO.openIn path
      fun loop acc =
        case TextIO.inputLine stream of
          NONE => List.rev acc
        | SOME text => loop (text :: acc)
      val result = loop [] handle e => (TextIO.closeIn stream; raise e)
    in TextIO.closeIn stream; result end

  fun strip text =
    if String.size text > 0 andalso String.sub (text, String.size text - 1) = #"\n"
    then String.substring (text, 0, String.size text - 1) else text

  fun relative path =
    path <> "" andalso
    List.all (fn part => part <> "" andalso part <> "." andalso part <> "..")
      (String.fields (fn c => c = #"/") path) andalso
    List.all (fn c => Char.isAlphaNum c orelse List.exists (fn x => c = x) [#"/", #".", #"_", #"-"])
      (String.explode path)

  fun exists path = if OS.FileSys.access (path, [OS.FileSys.A_READ]) then () else raise Fail ("missing " ^ path)
  fun localFile path = if relative path then exists (root ^ path) else raise Fail "invalid relative benchmark path"
  fun integer text =
    case Int.fromString text of
      SOME n => if n > 0 andalso Int.toString n = text then n else raise Fail "invalid resource limit"
    | NONE => raise Fail "invalid resource limit"

  fun load path =
    let
      fun row text : entry =
        case String.fields (fn c => c = #"\t") (strip text) of
          [name, profile, upstream, sourcePath, args, expected, sources, seconds, memory, tags] =>
            {name=name, profile=profile, upstream=upstream, sourcePath=sourcePath,
             args=String.tokens Char.isSpace args, expected=expected,
             sources=String.fields (fn c => c = #",") sources,
             seconds=integer seconds, memory=integer memory,
             tags=String.fields (fn c => c = #",") tags}
        | _ => raise Fail "invalid benchmark manifest row"
    in
      case lines path of
        [] => raise Fail "empty benchmark manifest"
      | header :: rows =>
          if strip header <> "benchmark\tprofile\tupstream\tsource_path\targs\texpected\tsources\ttimeout\tmemory_kib\ttags"
          then raise Fail "invalid benchmark manifest header"
          else List.map row rows
    end

  fun validate entries =
    let
      val inventory = List.map (fn line =>
        case String.fields (fn c => c = #"\t") line of
          source :: path :: _ => (source, path)
        | _ => raise Fail "invalid source inventory") (lines (root ^ "inventory.tsv"))
      fun check (entry : entry) =
        let
          val {name, profile, upstream, sourcePath, args, expected, sources, seconds, memory, tags} = entry
          val _ = if relative name andalso not (String.isSubstring "/" name) then () else raise Fail "invalid benchmark name"
          val _ = if List.exists (fn p => p = profile) ["smoke", "normal", "large"] then () else raise Fail "invalid benchmark profile"
          val _ = if List.exists (fn key => key = (upstream, sourcePath)) inventory then () else raise Fail "unknown benchmark source"
          val _ = if List.null args orelse List.null sources orelse List.null tags then raise Fail "incomplete benchmark entry" else ()
          val _ = List.app localFile sources
          val _ = localFile expected
          val _ = case lines (root ^ expected) of
                    [_] => () | _ => raise Fail "expected result must have one line"
          val _ = if seconds > 0 andalso memory > 0 then () else raise Fail "invalid benchmark limits"
        in () end
      fun keys [] _ = ()
        | keys ((entry : entry) :: rest) seen =
            let val key = (#name entry, #profile entry)
            in if List.exists (fn k => k = key) seen then raise Fail "duplicate benchmark profile"
               else keys rest (key :: seen) end
      val _ = if List.null entries then raise Fail "no runnable benchmarks" else ()
      val _ = List.app check entries
      val _ = keys entries []
      val names = List.foldl (fn (entry : entry, acc) =>
        if List.exists (fn n => n = #name entry) acc then acc else #name entry :: acc) [] entries
      fun complete name =
        List.app (fn profile =>
          if List.exists (fn (entry : entry) => #name entry = name andalso #profile entry = profile) entries
          then () else raise Fail "missing benchmark profile") ["smoke", "normal", "large"]
    in List.app complete names end

  fun selected entries profile filter =
    if List.exists (fn p => p = profile) ["smoke", "normal", "large"] then
      List.filter (fn (entry : entry) => #profile entry = profile andalso String.isSubstring filter (#name entry)) entries
    else raise Fail "invalid benchmark profile"

  fun emit (entry : entry) =
    print (String.concatWith "\t" [#name entry, Int.toString (#seconds entry),
      Int.toString (#memory entry), String.concatWith " " (#sources entry),
      String.concatWith " " (#args entry), #expected entry] ^ "\n")
end
