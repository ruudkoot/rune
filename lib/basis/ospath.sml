(* OS.Path uses the host's path syntax, without filesystem access. Windows
   accepts either separator, writes backslashes, and distinguishes drive-relative
   paths from rooted paths. UNC server/share pairs are absolute volumes. *)
structure RunePath =
struct
  exception Path
  exception InvalidArc

  (* A saved image can resume on another operating system. Runtime.save
     refreshes this host property after restoration; path operations remain
     pure string operations and need no system query per call. *)
  val windows = ref false
  fun refresh () = windows := (case (_prim "posix_uname" : unit -> string list) () of
      "Windows" :: _ => true | _ => false)
  val () = refresh ()
  val parentArc = ".."
  val currentArc = "."
  fun sep () = if !windows then "\\" else "/"
  fun isSeparator c = c = #"/" orelse (!windows andalso c = #"\\")
  fun drive p = !windows andalso size p >= 2 andalso
    Char.isAlpha (String.sub (p,0)) andalso Char.ord (String.sub (p,0)) < 128 andalso
    String.sub (p,1) = #":"
  fun fold p = if !windows then
    String.map (fn #"/" => #"\\" | c => Char.toLower c) p else p
  fun same (a,b) = fold a = fold b

  (* A UNC volume has exactly a server and a share, both nonempty. *)
  fun uncEnd p =
    let val n=size p
        fun next i = if i=n orelse isSeparator (String.sub (p,i)) then i else next (i+1)
    in if !windows andalso n>2 andalso isSeparator (String.sub (p,0)) andalso
          isSeparator (String.sub (p,1)) then
         let val server=next 2
             val share=if server<n then next (server+1) else server
         in if server>2 andalso server<n andalso share>server+1 then SOME share else NONE end
       else NONE
    end
  fun validVolume {isAbs,vol} = vol="" orelse drive vol andalso size vol=2 orelse
    (isAbs andalso (case uncEnd vol of SOME n => n=size vol | NONE => false))
  fun fromString path =
    let val n=size path
        val volumeEnd=if drive path then 2 else case uncEnd path of SOME n => n | NONE => 0
        val vol=String.substring (path,0,volumeEnd)
        val unc=volumeEnd>2
        val rooted=volumeEnd<n andalso isSeparator (String.sub (path,volumeEnd))
        val offset=volumeEnd+(if rooted then 1 else 0)
        val body=String.extract (path,offset,NONE)
        val arcs=if offset=n andalso not rooted then [] else String.fields isSeparator body
    in {isAbs=rooted orelse unc,vol=vol,arcs=arcs} end
  fun getVolume path = #vol (fromString path)
  fun validArc a = not (drive a) andalso not (List.exists isSeparator (explode a))
  fun checkArc a = if validArc a then a else raise InvalidArc
  fun toString {isAbs,vol,arcs} =
    if not (validVolume {isAbs=isAbs,vol=vol}) then raise Path
    else if not isAbs andalso (case arcs of ""::_ => true | _ => false) then raise Path
    else let val body=String.concatWith (sep ()) (List.map checkArc arcs)
             val vol=if !windows then String.map (fn #"/" => #"\\" | c => c) vol else vol
             val root=if isAbs andalso not (size vol>2 andalso null arcs) then sep () else ""
         in vol ^ root ^ body end

  fun isAbsolute path = #isAbs (fromString path)
  fun isRelative path = not (isAbsolute path)
  (* "true if path is a canonical specification of a root directory": "/",
     and not "//", whose last arc is the empty one. *)
  fun isRoot path =
    case fromString path of
      {isAbs = true, vol, arcs = [""], ...} => path = fold (vol ^ sep ())
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
          (false, []) => vol
        | (true, []) => vol ^ sep ()
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
      if dir = "" then file
      else if not isAbs andalso null arcs andalso file="" then vol
      else toString {isAbs = isAbs, vol = vol, arcs = arcs @ [file]}
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
      fun render arcs = fold (toString {isAbs=isAbs,vol=vol,arcs=arcs})
    in
      case (isAbs, arcs) of
        (true, []) => render [""]
      | (false, []) => render [currentArc]
      | _ => render arcs
    end

  fun isCanonical path = path = mkCanonical path

  (* "extends the path p with the arcs of q"; a path that ends in the parent
     arc keeps it. *)
  fun concat (p, q) =
    if isAbsolute q then raise Path
    else
      let
        val {isAbs, vol, arcs = pArcs} = fromString p
        val {vol=qVol,arcs=qArcs,...} = fromString q
        val ()=if qVol="" orelse same (vol,qVol) then () else raise Path
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
        val () = if same (pVol,aVol) then () else raise Path
        val pArcs = case pArcs of [""] => [] | l => l
        val aArcs = List.filter (fn a => a <> "") aArcs
        fun parents l = List.map (fn _ => parentArc) l
        fun h ([], []) = [currentArc]
          | h (p, []) = p
          | h ([], a) = parents a
          | h (p as x :: xs, a as y :: ys) = if same (x,y) then h (xs, ys) else parents a @ p
      in
        case h (pArcs, aArcs) of
          [""] => currentArc
        | arcs => toString {isAbs = false, vol = "", arcs = arcs}
      end

  (* Translate separators only after checking the arcs, so a Unix backslash
     does not silently become a Windows directory boundary. *)
  fun fromUnixPath p = if not (!windows) then p else
    let val rooted=String.isPrefix "/" p
        val body=if rooted then String.extract (p,1,NONE) else p
        val arcs=if p="" then [] else String.fields (fn c => c = #"/") body
    in toString {isAbs=rooted,vol="",arcs=arcs} end
  fun toUnixPath p = if not (!windows) then p else
    let val {isAbs,vol,arcs}=fromString p
    in if vol<>"" then raise Path else
       (if isAbs then "/" else "") ^ String.concatWith "/" arcs end

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
          NONE => if isAbs then vol ^ sep () else vol ^ parentArc                                  (* "" *)
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
                  (false, []) => vol ^ currentArc
                | (true, []) => vol ^ sep ()
                | _ => toString {isAbs = isAbs, vol = vol, arcs = kept}
              end
    end
end
