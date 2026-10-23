(* libraries: test/unit *)
structure LspUriTests =
struct
  structure U=LspUri
  val check=Expect.that
  fun path platform uri=Option.map #path (U.native (platform,U.parse uri))
  fun key platform uri=Option.map #key (U.native (platform,U.parse uri))
  fun invalid action = (action ();false) handle U.Invalid => true
  fun files () =
    (check ("percent decoding",path U.Posix "file:///tmp/a%20b%23%25%2B.sml"=SOME "/tmp/a b#%+.sml");
     check ("localhost",path U.Posix "FILE://LOCALHOST/tmp/a"=SOME "/tmp/a");
     check ("remote POSIX view",path U.Posix "file://server/share/a"=NONE);
     check ("drive mapping",path U.Windows "file:///c%3A/a%20b"=SOME "c:/a b");
     check ("drive and dot policy",key U.Windows "file:///c:/Dir/./Name.sml"=SOME "C:/Dir/Name.sml");
     check ("parent arcs preserved",key U.Posix "file:///a/link/../b"=SOME "/a/link/../b");
     check ("UNC mapping",path U.Windows "file://Server/Share/a"=SOME "//Server/Share/a");
     check ("UNC hostname only normalized",key U.Windows "file://Server/Share/A"=SOME "//server/Share/A");
     check ("client identity preserved",U.original (U.parse "FILE:///tmp/a%2bb")="FILE:///tmp/a%2bb");
     check ("POSIX filename bytes",path U.Posix "file:///tmp/%FF"=SOME "/tmp/\255");
     check ("lone surrogate preserved",path U.Windows "file:///C:/bad%ED%A0%80.sml"=SOME "C:/bad\237\160\128.sml");
     check ("WTF8 round trip",U.original (U.fromPath (U.Windows,"C:\\bad\237\160\128.sml"))="file:///C:/bad%ED%A0%80.sml");
     check ("native Windows drive path",U.original (U.fromPath (U.Windows,"c:\\a b.sml"))="file:///c:/a%20b.sml");
     check ("POSIX URI round trip",path U.Posix (U.original (U.fromPath (U.Posix,"/tmp/a b#%+.sml")))=SOME "/tmp/a b#%+.sml"))
  fun virtualAndInvalid () =
    (check ("unsaved URI",path U.Posix "untitled:Untitled-1"=NONE);
     check ("cell URI",path U.Posix "vscode-notebook-cell:/tmp/a.ipynb#cell1"=NONE);
     check ("file view fragment",path U.Posix "file:///tmp/a.sml#view"=NONE);
     check ("bad percent escape",invalid (fn () => ignore (U.parse "file:///bad%GG")));
     check ("short percent escape",invalid (fn () => ignore (U.parse "file:///bad%2")));
     check ("raw space",invalid (fn () => ignore (U.parse "file:///bad name")));
     check ("relative URI",invalid (fn () => ignore (U.parse "relative.sml")));
     check ("decoded NUL",invalid (fn () => ignore (U.native (U.Posix,U.parse "file:///a%00b"))));
     check ("bad Windows bytes",invalid (fn () => ignore (U.native (U.Windows,U.parse "file:///C:/bad%FF"))));
     check ("relative native path",invalid (fn () => ignore (U.fromPath (U.Posix,"relative.sml"))));
     check ("old synthetic drive path is refused",invalid (fn () => ignore (U.fromPath (U.Windows,"/C:/a"))));
     check ("drive relative alias is refused",invalid (fn () => ignore (U.fromPath (U.Windows,"/C:relative"))));
     check ("ambiguous Windows rooted path is refused",invalid (fn () => ignore (U.fromPath (U.Windows,"/tmp/a")))) )
end
structure LspUriTestMain = Main (struct
  val name="lsp-uri"
  val tests=Test.describe "lsp-uri"
    [Test.it "files" LspUriTests.files,Test.it "virtual-and-invalid" LspUriTests.virtualAndInvalid]
end)
val ()=LspUriTestMain.main ()
