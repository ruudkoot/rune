(* libraries: test/unit *)
structure LspPositionTests =
struct
  structure M=LspPosition
  structure P=LspProtocol
  val check=Expect.that
  fun pos (line,character) : P.position={line=IntInf.fromInt line,character=IntInf.fromInt character}
  fun invalid action = (action ();false) handle M.Invalid => true
  fun limited action = (action ();false) handle M.Limit => true
  fun coordinates () =
    let val text="\239\187\191a\240\144\144\128b\r\nc\rd\n"
        val index=M.make text
    in
      check ("mixed line endings",M.lineCount index=4);
      List.app (fn (encoding,column) =>
        check ("supplementary scalar",M.offset (index,encoding,pos (0,column))=SOME 8))
        [(P.Utf8,8),(P.Utf16,4),(P.Utf32,3)];
      check ("split surrogate rejected",M.offset (index,P.Utf16,pos (0,3))=NONE);
      check ("split UTF8 rejected",M.offset (index,P.Utf8,pos (0,5))=NONE);
      check ("split byte offset rejected",M.position (index,P.Utf16,5)=NONE);
      check ("EOL clamp",M.offset (index,P.Utf16,pos (0,999))=SOME 9);
      check ("EOF clamp",M.offset (index,P.Utf32,{line=P.maxInteger,character=P.maxInteger})=SOME (size text));
      check ("CRLF interior clamps",M.position (index,P.Utf16,10)=SOME (pos (0,5)));
      check ("negative coordinate rejected",M.offset (index,P.Utf16,pos (~1,0))=NONE);
      check ("malformed UTF8 rejected",invalid (fn () => ignore (M.make "\255")));
      check ("source surrogates rejected",invalid (fn () => ignore (M.make "\237\160\128")));
      check ("empty document",M.lineCount (M.make "")=1)
    end
  fun editing () =
    let val original=M.make "a\rX\nb\n"
        val joined=M.edit (original,2,3,"")
        val inserted=M.edit (joined,1,1,"\n")
    in
      check ("CR and LF join across deletion",M.text joined="a\r\nb\n" andalso M.lineCount joined=3);
      check ("input snapshot preserved",M.text original="a\rX\nb\n" andalso M.lineCount original=4);
      check ("newline insertion",M.text inserted="a\n\r\nb\n" andalso M.lineCount inserted=4);
      check ("byte edit cannot split scalar",invalid (fn () => ignore (M.edit (M.make "\240\144\144\128",1,2,"x"))));
      check ("bad inserted bytes",invalid (fn () => ignore (M.edit (joined,0,0,"\255"))));
      check ("line bound on construction",limited (fn () => ignore (M.bounded {text="a\nb\n",maxLines=2})));
      check ("line bound on editing",limited (fn () => ignore (M.editBounded
        {document=M.make "a\nb\n",start=1,stop=1,text="\n",maxLines=3})));
      check ("suffix empty line not duplicated",M.lineCount (M.editBounded
        {document=M.make "a\nb\n",start=1,stop=1,text="\n",maxLines=4})=4);
      check ("edit may reduce an existing index to its bound",M.lineCount (M.editBounded
        {document=M.make "a\nb\n",start=1,stop=4,text="",maxLines=1})=1)
    end
  fun sparse () =
    let val text=String.concat (List.tabulate (500,fn _ => "a\240\144\144\128"))
        val original=M.make text
        val edited=M.edit (original,1250,1251,"\195\169")
        val fresh=M.make (String.substring (text,0,1250) ^ "\195\169" ^ String.extract (text,1251,NONE))
    in List.app (fn n =>
      let val offset=if n<=250 then n*5 else n*5+1
      in check ("sparse position equals fresh index",M.position (edited,P.Utf16,offset)=M.position (fresh,P.Utf16,offset));
         check ("sparse offset round trip",M.offset (edited,P.Utf16,pos (0,n*3))=SOME offset) end)
      (List.tabulate (501,fn n => n)) end
end
structure LspPositionTestMain = Main (struct
  val name="lsp-position"
  val tests=Test.describe "lsp-position"
    [Test.it "coordinates" LspPositionTests.coordinates,
     Test.it "editing" LspPositionTests.editing,
     Test.it "sparse" LspPositionTests.sparse]
end)
val ()=LspPositionTestMain.main ()
