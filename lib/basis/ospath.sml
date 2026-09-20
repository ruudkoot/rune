(* OS.Path: paths as text. Nothing here looks at a file system.

   The separator is "/" and the only volume is "", as on Unix, which is what
   the VM runs on. *)
structure RunePath =
struct
  exception Path
  exception InvalidArc

  val parentArc = ".."
  val currentArc = "."
  val separator = #"/"

  fun isSeparator c = c = separator

  (* An arc holds no separator. *)
  fun validArc a = not (List.exists isSeparator (explode a))
  fun checkArc a = if validArc a then a else raise InvalidArc

  fun validVolume {isAbs, vol} = vol = ""
  fun getVolume (_ : string) = ""

  (* "/" gives arcs [""], "//" gives ["", ""], "a/" gives ["a", ""]. *)
  fun fromString path =
    let
      val isAbs = String.size path > 0 andalso isSeparator (String.sub (path, 0))
      val body = if isAbs then String.extract (path, 1, NONE) else path
      val arcs = if path = "" then [] else String.fields isSeparator body
    in {isAbs = isAbs, vol = "", arcs = arcs} end

  fun toString {isAbs, vol, arcs} =
    if not (validVolume {isAbs = isAbs, vol = vol}) then raise Path
    else if not isAbs andalso (case arcs of "" :: _ => true | _ => false) then raise Path
    else
      let val body = String.concatWith "/" (List.map checkArc arcs)
      in if isAbs then "/" ^ body else body end

  fun isAbsolute path = #isAbs (fromString path)
  fun isRelative path = not (isAbsolute path)
  (* "true if path is a canonical specification of a root directory": "/",
     and not "//", whose last arc is the empty one. *)
  fun isRoot path =
    case fromString path of
      {isAbs = true, arcs = [""], ...} => true
    | _ => false

  (* "the file part is the last arc" *)
  fun splitDirFile path =
    let
      val {isAbs, vol, arcs} = fromString path
      fun split ([], before') = (List.rev before', "")
        | split ([a], before') = (List.rev before', a)
        | split (a :: rest, before') = split (rest, a :: before')
      val (dirArcs, file) = split (arcs, [])
      val dir =
        case (isAbs, dirArcs) of
          (false, []) => ""
        | (true, []) => "/"
        | _ => toString {isAbs = isAbs, vol = vol, arcs = dirArcs}
    in {dir = dir, file = file} end

  fun dir path = #dir (splitDirFile path)
  fun file path = #file (splitDirFile path)

  (* The inverse of splitDirFile: the empty arc that ends dir ("/" or "a/")
     is dropped, so that "/" and "b" join to "/b", and "/" and "" to "/". *)
  fun joinDirFile {dir, file} =
    let
      val _ = checkArc file
      val {isAbs, vol, arcs} = fromString dir
      val arcs = case List.rev arcs of "" :: rest => List.rev rest | _ => arcs
    in
      if dir = "" then file else toString {isAbs = isAbs, vol = vol, arcs = arcs @ [file]}
    end

  (* "the extension is a non-empty sequence of characters following the
     right-most, non-initial, occurrence of "." in the last arc" *)
  fun splitBaseExt path =
    let
      val {dir, file} = splitDirFile path
      fun lastDot (i, found) =
        if i >= size file then found
        else lastDot (i + 1, if String.sub (file, i) = #"." then SOME i else found)
    in
      case lastDot (1, NONE) of
        NONE => {base = path, ext = NONE}
      | SOME i =>
          if i = size file - 1 then {base = path, ext = NONE}
          else {base = String.substring (path, 0, size path - (size file - i)),
                ext = SOME (String.extract (file, i + 1, NONE))}
    end

  fun base path = #base (splitBaseExt path)
  fun ext path = #ext (splitBaseExt path)

  fun joinBaseExt {base, ext} =
    case ext of
      NONE => base
    | SOME "" => base
    | SOME e => base ^ "." ^ e

  (* "Redundant occurrences of the parent arc, the current arc, and the empty
     arc are removed"; the empty path becomes the current one. *)
  fun mkCanonical path =
    let
      val {isAbs, vol, arcs} = fromString path
      fun go ([], kept) = List.rev kept
        | go (a :: rest, kept) =
          if a = "" orelse a = currentArc then go (rest, kept)
          else if a = parentArc then
            (case kept of
               [] => if isAbs then go (rest, []) else go (rest, [parentArc])
             | k :: above => if k = parentArc then go (rest, parentArc :: kept) else go (rest, above))
          else go (rest, a :: kept)
      val arcs = go (arcs, [])
    in
      case (isAbs, arcs) of
        (true, _) => toString {isAbs = true, vol = vol, arcs = arcs}
      | (false, []) => currentArc
      | (false, _) => toString {isAbs = false, vol = vol, arcs = arcs}
    end

  fun isCanonical path = path = mkCanonical path

  (* "extends the path p with the arcs of q"; a path that ends in the parent
     arc keeps it. *)
  fun concat (p, q) =
    if isAbsolute q then raise Path
    else
      let
        val {isAbs, vol, arcs = pArcs} = fromString p
        val {arcs = qArcs, ...} = fromString q
        fun drop [] = []
          | drop [""] = []                 (* a trailing empty arc joins *)
          | drop (a :: rest) = a :: drop rest
        val arcs = case (p, drop pArcs) of ("", _) => qArcs | (_, kept) => kept @ qArcs
      in toString {isAbs = isAbs, vol = vol, arcs = arcs} end

  (* "If relativeTo is not absolute ... the Path exception is raised", also
     when path is absolute (or, for mkRelative, relative) already. *)
  fun mkAbsolute {path, relativeTo} =
    if isRelative relativeTo then raise Path
    else if isAbsolute path then path
    else mkCanonical (concat (relativeTo, path))

  (* The common prefix is stripped and a parent arc is put for each arc of
     relativeTo left. relativeTo is reduced first; the arcs of path are kept as
     they are, trailing empty arc included ("/a/b/" relative to "/a/c" is
     "../b/", "/a/b/../c" relative to "/a/d" is "../b/../c"), except that the
     root alone has none. *)
  fun mkRelative {path, relativeTo} =
    if isRelative relativeTo then raise Path
    else if isRelative path then path
    else
      let
        val {vol = pVol, arcs = pArcs, ...} = fromString path
        val {vol = aVol, arcs = aArcs, ...} = fromString (mkCanonical relativeTo)
        val () = if pVol = aVol then () else raise Path
        val pArcs = case pArcs of [""] => [] | l => l
        val aArcs = List.filter (fn a => a <> "") aArcs
        fun parents l = List.map (fn _ => parentArc) l
        fun h ([], []) = [currentArc]
          | h (p, []) = p
          | h ([], a) = parents a
          | h (p as x :: xs, a as y :: ys) = if x = y then h (xs, ys) else parents a @ p
      in
        case h (pArcs, aArcs) of
          [""] => currentArc
        | arcs => toString {isAbs = false, vol = "", arcs = arcs}
      end

  (* The VM runs on Unix, so these are the identity. *)
  fun fromUnixPath p = p
  fun toUnixPath p = p

  (* "getParent path = path if and only if path is a root" *)
  fun getParent path =
    let
      val {isAbs, vol, arcs} = fromString path
      fun lastOf [] = NONE
        | lastOf [a] = SOME a
        | lastOf (_ :: rest) = lastOf rest
      fun allButLast [] = []
        | allButLast [_] = []
        | allButLast (a :: rest) = a :: allButLast rest
    in
      if isRoot path then path
      else
        case lastOf arcs of
          NONE => parentArc                                  (* "" *)
        | SOME a =>
            (* "a/" gives "a/..", "a///" gives "a///..": the path already ends
               with a separator, so the parent arc is written after it. *)
            if a = "" then path ^ parentArc
            else if a = currentArc then
              toString {isAbs = isAbs, vol = vol, arcs = allButLast arcs @ [parentArc]}
            else if a = parentArc then
              toString {isAbs = isAbs, vol = vol, arcs = arcs @ [parentArc]}
            else
              let val kept = allButLast arcs
              in
                case (isAbs, kept) of
                  (false, []) => currentArc
                | (true, []) => "/"
                | _ => toString {isAbs = isAbs, vol = vol, arcs = kept}
              end
    end
end
