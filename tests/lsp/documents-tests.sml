structure RuneLspDocumentTests =
struct
  structure D=RuneLspDocuments
  structure P=LspProtocol
  structure M=LspPosition
  val check=Expect.that
  val limits={maxDocuments=2,maxDocumentBytes=2000,maxTotalBytes=3000,maxDocumentLines=100,maxTotalLines=150}
  fun pos (line,column) : P.position={line=IntInf.fromInt line,character=IntInf.fromInt column}
  fun change (a,b,text)=D.Change {range={start=pos a,stop=pos b},text=text,rangeLength=NONE}
  fun rejected action=(action ();false) handle D.Rejected _ => true
  val uri="file:///a.sml"
  fun lifecycle () =
    let val store=D.new (P.Utf16,limits)
        val first=D.openDocument (store,{uri=uri,languageId="sml",version=1,text="a\240\144\144\128b\r\n"})
        val second=D.changeDocument (store,{uri=uri,version=2,changes=
          [change ((0,1),(0,3),"xy"),change ((0,2),(0,3),"z")]})
        val ()=check ("changes use intermediate texts",M.text (#content second)="axzb\r\n")
        val ()=check ("old revision invalidated",not (D.current (store,first)) andalso D.current (store,second))
        val ()=check ("duplicate open rejected",rejected (fn () => ignore (D.openDocument
          (store,{uri=uri,languageId="sml",version=3,text="duplicate"}))))
        val ()=check ("stale version rejected",rejected (fn () => ignore (D.changeDocument
          (store,{uri=uri,version=2,changes=[D.Replace "stale"]}))))
        val ()=check ("stale event preserves valid snapshot",D.current (store,second))
        val ()=D.closeDocument (store,uri)
        val ()=check ("close invalidates held snapshot",not (D.current (store,second)))
        val reopened=D.openDocument (store,{uri=uri,languageId="sml",version=1,text="again"})
    in check ("reopen has a fresh revision",#revision reopened<> #revision first andalso D.current (store,reopened)) end
  fun atomicRecovery () =
    let val store=D.new (P.Utf16,limits)
        val first=D.openDocument (store,{uri=uri,languageId="sml",version=1,text="last valid"})
        val ()=check ("malformed batch rejected",rejected (fn () => ignore (D.changeDocument
          (store,{uri=uri,version=3,changes=[D.Replace "\240\144\144\128",change ((0,1),(0,2),"x")]}))))
        val ()=check ("batch has no partial effect",M.text (#content (valOf (D.snapshot (store,uri))))="last valid")
        val ()=check ("desynchronized data cannot serve queries",not (D.healthy (store,uri)) andalso not (D.current (store,first)))
        val ()=check ("highest seen version retained",rejected (fn () => ignore (D.changeDocument
          (store,{uri=uri,version=2,changes=[D.Replace "out of order"]}))))
        val ()=check ("incremental resync rejected",rejected (fn () => ignore (D.changeDocument
          (store,{uri=uri,version=4,changes=[change ((0,0),(0,1),"x")]}))))
        val fresh=D.changeDocument (store,{uri=uri,version=5,changes=[D.Replace "fresh",change ((0,5),(0,5),"!")]})
        val ()=check ("full replacement restores synchronization",D.current (store,fresh) andalso M.text (#content fresh)="fresh!")
        val ()=D.quarantine (store,{uri=uri,version=SOME 4})
        val ()=check ("stale malformed event cannot quarantine newer data",D.current (store,fresh))
        val ()=D.quarantine (store,{uri=uri,version=NONE})
    in check ("malformed unversioned transition quarantines",not (D.current (store,fresh))) end
  fun resources () =
    let val limits={maxDocuments=2,maxDocumentBytes=20,maxTotalBytes=25,maxDocumentLines=3,maxTotalLines=4}
        val store=D.new (P.Utf8,limits)
        val first=D.openDocument (store,{uri=uri,languageId="",version=P.minInteger,text="a\nb\n"})
        val _=D.openDocument (store,{uri="untitled:second",languageId="sml",version=0,text="other"})
        val ()=check ("document count bounded",rejected (fn () => ignore (D.openDocument
          (store,{uri="untitled:third",languageId="sml",version=0,text=""}))))
        val ()=check ("line count bounded",rejected (fn () => ignore (D.changeDocument
          (store,{uri=uri,version=0,changes=[change ((0,1),(0,1),"\n")]}))))
        val ()=check ("line-limit failure preserves text",M.text (#content (valOf (D.snapshot (store,uri))))=M.text (#content first))
        val _=D.changeDocument (store,{uri=uri,version=1,changes=[D.Replace "a"]})
        val ()=check ("byte count bounded",rejected (fn () => ignore (D.changeDocument
          (store,{uri=uri,version=2,changes=[D.Replace "012345678901234567890"]}))))
        val ()=check ("URI validated",rejected (fn () => ignore (D.openDocument
          (D.new (P.Utf8,limits),{uri="relative.sml",languageId="sml",version=1,text=""}))))
    in () end
  fun saves () =
    let val store=D.new (P.Utf16,limits)
        val first=D.openDocument (store,{uri=uri,languageId="sml",version=1,text="old"})
        val ()=D.willSave (store,uri)
        val second=D.changeDocument (store,{uri=uri,version=2,changes=[D.Replace "new"]})
        val result=D.saved (store,{uri=uri,text=SOME "old"})
        val ()=check ("old save payload does not replace overlay",#agrees result=SOME false andalso
          D.current (store,second) andalso M.text (#content (#snapshot result))="new")
        val ()=check ("save does not resurrect old revision",not (D.current (store,first)))
        val result=D.saved (store,{uri=uri,text=SOME "new"})
    in check ("matching save payload observed",#agrees result=SOME true andalso D.current (store,second)) end
  fun wire () =
    let val store=D.new (P.Utf16,limits)
        fun notify method text=RuneLspSync.handleNotification (store,{method=method,params=SOME (Json.decode text)})
        fun invalid action=(action ();false) handle RuneLspSync.Invalid _ => true
        val _=notify "textDocument/didOpen"
          "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"languageId\":\"sml\",\"version\":1,\"text\":\"old\"}}"
        val first=valOf (D.snapshot (store,uri))
        val ()=check ("malformed wire batch rejected",invalid (fn () => ignore (notify "textDocument/didChange"
          "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"version\":2},\"contentChanges\":[{\"text\":\"partial\"},{\"text\":7}]}")))
        val ()=check ("decode has no partial side effects",M.text (#content (valOf (D.snapshot (store,uri))))="old"
          andalso not (D.current (store,first)))
        val _=notify "textDocument/didChange"
          "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"version\":3},\"contentChanges\":[{\"text\":\"fresh\"}]}"
        val ()=check ("duplicate known field rejected",invalid (fn () => ignore (notify "textDocument/didChange"
          "{\"textDocument\":{\"uri\":\"file:///a.sml\",\"version\":4},\"contentChanges\":[{\"text\":\"one\",\"text\":\"two\"}]}")))
        val ()=check ("duplicate field quarantines",not (D.healthy (store,uri)))
        val _=notify "textDocument/didClose" "{\"textDocument\":{\"uri\":\"file:///a.sml\"}}"
    in check ("wire close releases document",not (isSome (D.snapshot (store,uri)))) end
end
structure RuneLspDocumentTestMain = Main (struct
  val name="lsp-documents"
  val tests=Test.describe "lsp-documents"
    [Test.it "lifecycle" RuneLspDocumentTests.lifecycle,
     Test.it "atomic-recovery" RuneLspDocumentTests.atomicRecovery,
     Test.it "resources" RuneLspDocumentTests.resources,
     Test.it "saves" RuneLspDocumentTests.saves,
     Test.it "wire" RuneLspDocumentTests.wire,
     Test.it "independent-edit-traces" RuneLspEditTraces.main]
end)
val ()=RuneLspDocumentTestMain.main ()
