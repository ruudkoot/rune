structure RuneLspWorkerWireTests =
struct
  structure W=RuneLspWorkerWire
  val check=Expect.that
  fun fails text=(ignore (W.decode text);false) handle W.Invalid _ => true
  fun values () =
    let val value=W.Object [("raw",W.Bytes "\000\255\237\160\128"),("number",W.Integer (valOf (IntInf.fromString "~99999999999999999999999999999999999999"))),
          ("array",W.Array [W.Null,W.Bool true,W.Bool false,W.Bytes "\206\187"])]
        val encoded=W.encode value
        val ()=check ("native bytes and large integers round trip",W.decode encoded=value)
        val ()=List.app (fn count => check ("every truncation rejected",fails (String.substring (encoded,0,count))))
          (List.tabulate (size encoded,fn i => i))
        val ()=check ("oversized counts rejected",fails "RW1s\255\255\255\255")
        val ()=check ("trailing data rejected",fails (encoded ^ "n"))
        val duplicate=W.Object [("key",W.Null),("key",W.Bool true)]
    in check ("duplicate schema fields rejected",(ignore (W.field (duplicate,"key"));false) handle W.Invalid _ => true) end
  fun framing () =
    let val body=W.encode (W.Bytes "\000\255\r\n\237\160\128")
        val framed=Framing.frame (Framing.ContentLength,body)
        fun loop (i,reader,all)=if i=size framed then all else
          let val (messages,reader)=Framing.feed (reader,String.substring (framed,i,1))
          in loop (i+1,reader,all @ messages) end
        val result=loop (0,Framing.bounded {framing=Framing.ContentLength,maxHeaderBytes=8192,maxBodyBytes=1000},[])
    in check ("fragmented binary frames preserve bytes",result=[body] andalso W.decode (hd result)=W.Bytes "\000\255\r\n\237\160\128") end
end
structure RuneLspWorkerWireTestMain=Main (struct
  val name="lsp-worker-wire"
  val tests=Test.describe "lsp-worker-wire" [Test.it "values" RuneLspWorkerWireTests.values,Test.it "framing" RuneLspWorkerWireTests.framing]
end)
val ()=RuneLspWorkerWireTestMain.main ()
