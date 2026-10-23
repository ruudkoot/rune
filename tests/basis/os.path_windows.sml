(* requires: OS *)
(* Windows cases from https://smlfamily.github.io/Basis/os-path.html.
   Expected results come from the host syntax, volume rules and canonical
   path rules, not another compiler. UNC shares extend the volume model.
   The Unix tables are in os.path.sml. *)
structure TestOSPathWindows =
struct
  structure P = OS.Path
  val () = if not (OS.Path.validVolume {isAbs=true,vol="C:"}) then () else let
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val isPath = fn P.Path => true | _ => false
  val invalid = fn P.InvalidArc => true | _ => false
  fun parts p expected = T.eq (fn {isAbs,vol,arcs} =>
    Bool.toString isAbs ^ ":" ^ vol ^ ":" ^ T.list T.string arcs)
    ("OS.Path.fromString/windows-" ^ p,expected,fn () => P.fromString p)
  val () = List.app (fn (p,abs,vol,arcs) => parts p {isAbs=abs,vol=vol,arcs=arcs})
    [("",false,"",[]),("C:",false,"C:",[]),("C:a\\b",false,"C:",["a","b"]),
     ("C:\\",true,"C:",[""]),("C:/a\\b/",true,"C:",["a","b",""]),
     ("\\a\\b",true,"",["a","b"]),("/a/b",true,"",["a","b"]),
     ("\\\\server\\share\\a",true,"\\\\server\\share",["a"]),
     ("//server/share/a",true,"//server/share",["a"])]
  val () = List.app (fn (p,e) => eqS ("OS.Path.toString/windows-" ^ p,e,
    fn () => P.toString (P.fromString p)))
    [("C:a/b","C:a\\b"),("C:/a/b","C:\\a\\b"),("/a/b","\\a\\b"),
     ("//server/share/a","\\\\server\\share\\a"),("C:","C:")]
  val () = eqS ("OS.Path.parentArc/windows","..",fn () => P.parentArc)
  val () = eqS ("OS.Path.currentArc/windows",".",fn () => P.currentArc)
  val () = List.app (fn vol => eqB ("OS.Path.validVolume/windows-" ^ vol,true,
    fn () => P.validVolume {isAbs=false,vol=vol})) ["","A:","z:"]
  val () = List.app (fn vol => eqB ("OS.Path.validVolume/windows-invalid-" ^ vol,false,
    fn () => P.validVolume {isAbs=true,vol=vol})) ["1:","AA:","C:x","\\\\server"]
  val () = eqB ("OS.Path.validVolume/windows-UNC-relative",false,
    fn () => P.validVolume {isAbs=false,vol="\\\\server\\share"})
  val () = eqS ("OS.Path.getVolume/windows","C:",fn () => P.getVolume "C:foo")
  val () = List.app (fn (p,e) => eqS ("OS.Path.getParent/windows-" ^ p,e,fn () => P.getParent p))
    [("C:","C:.."),("C:a","C:."),("C:\\a","C:\\"),("c:\\","c:\\"),
     ("C:a\\","C:a\\.."),("C:a\\.","C:a\\.."),("\\\\server\\share","\\\\server\\share\\"),
     ("\\\\server\\share\\a","\\\\server\\share\\")]
  val () = List.app (fn (p,d,f) =>
    (eqS ("OS.Path.dir/windows-" ^ p,d,fn () => P.dir p);
     eqS ("OS.Path.file/windows-" ^ p,f,fn () => P.file p);
     eqB ("OS.Path.splitDirFile/windows-" ^ p,true,fn () => P.splitDirFile p={dir=d,file=f});
     eqS ("OS.Path.joinDirFile/windows-" ^ p,p,fn () => P.joinDirFile {dir=d,file=f})))
    [("C:","C:",""),("C:foo","C:","foo"),("C:\\a.txt","C:\\","a.txt"),
     ("C:\\a\\b","C:\\a","b"),("\\\\s\\share\\f","\\\\s\\share\\","f")]
  val () = List.app (fn arc => T.raises ("OS.Path.toString/windows-invalid-arc-" ^ arc,invalid,
    fn () => P.toString {isAbs=false,vol="",arcs=[arc]})) ["a\\b","a/b","C:","C:x"]
  val () = T.raises ("OS.Path.joinDirFile/windows-volume-file",invalid,
    fn () => P.joinDirFile {dir="a",file="C:x"})
  val () = eqB ("OS.Path.splitBaseExt/windows",true,
    fn () => P.splitBaseExt "C:\\a.b\\f.txt"={base="C:\\a.b\\f",ext=SOME "txt"})
  val () = eqS ("OS.Path.base/windows","C:\\a\\f",fn () => P.base "C:\\a\\f.txt")
  val () = T.eq (T.option T.string) ("OS.Path.ext/windows",SOME "txt",fn () => P.ext "C:\\a\\f.txt")
  val () = eqS ("OS.Path.joinBaseExt/windows","C:\\a\\f.txt",
    fn () => P.joinBaseExt {base="C:\\a\\f",ext=SOME "txt"})
  val () = List.app (fn (p,e) =>
    (eqS ("OS.Path.mkCanonical/windows-" ^ p,e,fn () => P.mkCanonical p);
     eqB ("OS.Path.isCanonical/windows-" ^ p,true,fn () => P.isCanonical e)))
    [("c:/a/../b//","c:\\b"),("c:foo/..","c:."),("c:","c:."),
     ("c:/../..","c:\\"),("a/../../b","..\\b"),
     ("//server/share/a/../..","\\\\server\\share\\")]
  val () = eqS ("OS.Path.mkCanonical/windows-lowercase","c:\\b",fn () => P.mkCanonical "C:/A/../B")
  val () = eqB ("OS.Path.isCanonical/windows-case",false,fn () => P.isCanonical "C:\\A")
  val () = eqS ("OS.Path.concat/windows-matching-drive","C:\\a\\b",
    fn () => P.concat ("C:\\a","c:b"))
  val () = T.raises ("OS.Path.concat/windows-different-drive",isPath,fn () => P.concat ("C:a","D:b"))
  val () = T.raises ("OS.Path.concat/windows-absolute",isPath,fn () => P.concat ("C:a","\\b"))
  val () = eqS ("OS.Path.mkAbsolute/windows","c:\\b",
    fn () => P.mkAbsolute {path="C:..\\b",relativeTo="c:\\a"})
  val () = T.raises ("OS.Path.mkAbsolute/windows-different-drive",isPath,
    fn () => P.mkAbsolute {path="D:b",relativeTo="C:\\a"})
  val () = eqS ("OS.Path.mkRelative/windows-case","..\\B",
    fn () => P.mkRelative {path="C:\\a\\B",relativeTo="c:\\a\\c"})
  val () = eqS ("OS.Path.mkRelative/windows-UNC-separator-case","b",
    fn () => P.mkRelative {path="//SERVER/SHARE/a/b",relativeTo="\\\\server\\share\\a"})
  val () = T.raises ("OS.Path.mkRelative/windows-different-drive",isPath,
    fn () => P.mkRelative {path="D:\\b",relativeTo="C:\\a"})
  val () = List.app (fn (p,abs) =>
    (eqB ("OS.Path.isAbsolute/windows-" ^ p,abs,fn () => P.isAbsolute p);
     eqB ("OS.Path.isRelative/windows-" ^ p,not abs,fn () => P.isRelative p)))
    [("C:x",false),("C:",false),("C:\\x",true),("\\x",true),("//s/share/x",true)]
  val () = List.app (fn (p,root) => eqB ("OS.Path.isRoot/windows-" ^ p,root,fn () => P.isRoot p))
    [("c:\\",true),("c:/",false),("c:",false),("c:\\\\",false),("\\\\s\\share\\",true),("//s/share\\",false)]
  val () = eqB ("OS.Path.isRoot/windows-uppercase",false,fn () => P.isRoot "C:\\")
  val () = eqS ("OS.Path.fromUnixPath/windows","\\a\\b",fn () => P.fromUnixPath "/a/b")
  val () = T.raises ("OS.Path.fromUnixPath/windows-backslash",invalid,fn () => P.fromUnixPath "a\\b")
  val () = eqS ("OS.Path.toUnixPath/windows","/a/b",fn () => P.toUnixPath "\\a\\b")
  val () = T.raises ("OS.Path.toUnixPath/windows-volume",isPath,fn () => P.toUnixPath "C:\\a")
  val odd = "\237\160\128-\206\187"
  val () = eqS ("OS.Path.mkCanonical/windows-WTF8","c:\\" ^ odd,
    fn () => P.mkCanonical ("c:/" ^ odd))
  in () end
end
