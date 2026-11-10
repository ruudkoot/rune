(* Where a compile's store is and how it is kept small (docs/units.md, The
   store; the haskell98 roadmap's M20): the policy of the store (UnitStore)
   that no format of an entry decides, so that a compiler of another
   language takes it as Rune does, from CompilerSettings, and names
   nothing of SML's (UnitCache, which keeps SML's units there).

   The store is the workspace's (the build-system roadmap's D24): .rune in
   the directory of its rune.workspace, which every build, the REPL and the
   memos of a warm build of the workspace share, else beside the build file
   or the first input; RUNE_CACHE names another, and --cache-dir another
   still. It is written there, its overlay, and read after it are its
   read-only layers: the frozen libraries (frozen), which a compile never
   writes. *)
structure StorePolicy =
struct
  structure S = UnitStore

  (* The store in a directory: its .rune *)
  fun storeIn (home : string) : string = OS.Path.joinDirFile {dir = home, file = ".rune"}

  (* The store's overlay, which a compile writes: --cache-dir, else
     RUNE_CACHE, else .rune in the workspace's directory (storeHome, which
     the driver sets: the directory of the nearest rune.workspace above the
     build file or the first input, else of that file), so that every build
     of a workspace, whatever file it begins with, has the one; NONE with
     --no-cache *)
  fun directory () : string option =
    if !CompilerSettings.noCache then NONE
    else
      case !CompilerSettings.cacheDir of
        SOME d => SOME d
      | NONE =>
          case OS.Process.getEnv "RUNE_CACHE" of
            SOME d => if d = "" then NONE else SOME d
          | NONE =>
              case (!CompilerSettings.storeHome, !CompilerSettings.inputs) of
                (SOME home, _) => SOME (storeIn home)
              | (NONE, first :: _) => SOME (storeIn (OS.Path.dir first))
              | (NONE, []) => SOME ".rune"

  (* The frozen libraries (the incremental roadmap's D8): a store that
     every unit of the Basis Library and of the libraries the compiler needs
     was compiled into once, `cache` beside the library's files (make
     basis-cache; installed and shipped with them), which a compile reads
     after its own store and never writes; NONE with --no-cache or where
     there is none *)
  fun frozen () : string option =
    if !CompilerSettings.noCache then NONE
    else
      case !CompilerSettings.libDir of
        NONE => NONE
      | SOME lib =>
          let val d = OS.Path.joinDirFile {dir = lib, file = "cache"}
          in if (OS.FileSys.isDir d handle OS.SysErr _ => false) then SOME d else NONE end

  (* The store's read-only layers, in the order they are read, after its
     overlay: the frozen libraries *)
  fun layers () : string list = case frozen () of SOME f => [f] | NONE => []

  (* whether a directory is where a layer is, there yet or not, however a
     path spells it: lib/cache, which make basis-cache writes as a store of
     its own *)
  fun isLayer (dir : string) : bool =
    let
      fun full d = OS.Path.mkCanonical (OS.Path.mkAbsolute {path = d, relativeTo = OS.FileSys.getDir ()})
                   handle OS.SysErr _ => d | OS.Path.Path => d
    in
      case (!CompilerSettings.noCache, !CompilerSettings.libDir) of
        (false, SOME lib) => full (OS.Path.joinDirFile {dir = lib, file = "cache"}) = full dir
      | _ => false
    end

  (* ---- keeping the store small (UnitStore.trim) ---- *)

  (* the limits of trim: --cache-max-age DAYS, a week unless given, and
     --cache-max-size SIZE, 4 GiB unless given; NONE, none *)
  val week = Time.fromSeconds 604800
  val maxAge : Time.time option ref = ref (SOME week)
  val () = CompilerState.cellRoot ("StorePolicy.maxAge", maxAge)
  val maxSize : LargeInt.int option ref = ref (SOME (LargeInt.* (LargeInt.fromInt 4096, LargeInt.fromInt 1048576)))
  val () = CompilerState.cellRoot ("StorePolicy.maxSize", maxSize)
  fun limits () : S.limits = {age = !maxAge, size = !maxSize}

  (* The overlay dir trimmed after a compile's work is done, where it was
     last trimmed a day ago or more: one stat where it was not. A store
     that is also a layer -- lib/cache, which make basis-cache writes -- is
     never trimmed *)
  fun trimAfter (dir : string) : unit =
    if not (S.trimDue (Time.fromSeconds 86400) dir) orelse isLayer dir then ()
    else (S.markTrimmed dir; ignore (S.trim (limits ()) dir))
end
