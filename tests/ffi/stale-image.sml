(* Keep expired callback wrappers unchecked until after save/restore. Their
   SML liveness cells are still true, although their C identities expired. *)
val [libraryPath,image]=CommandLine.arguments()
fun check(name,condition)=if condition then () else raise Fail name
val library=RuneForeign.openLibrary libraryPath
val symbol=RuneForeign.symbol(library,"rf_cb_apply")
val apply=RuneForeign.prepare{symbol=symbol,abi=0,result=RuneForeign.SInt32,
  arguments=[RuneForeign.Pointer,RuneForeign.Pointer,RuneForeign.SInt32]}
val borrowed=ref(NONE:RuneForeign.resource option)
val borrowedView=ref(NONE:RuneForeign.resource option)
val callback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,
  arguments=[RuneForeign.Pointer,RuneForeign.SInt32],failure=RuneForeign.Default(RuneForeign.Signed ~1),
  function=fn values=>case values of [RuneForeign.Address(SOME p),_]=>
    (borrowed:=SOME p;borrowedView:=SOME(RuneForeign.view(p,0w0,0w4));RuneForeign.Signed 0)
    | _=>raise Fail "callback pointer missing"}
val marker=RuneForeign.allocate 0w4
val _=RuneForeign.invoke(apply,[RuneForeign.Address(SOME callback),RuneForeign.Address(SOME marker),RuneForeign.Signed 0])
val ()=List.app RuneForeign.release[callback,marker,apply,symbol,library]
val ()=check("all native state released",RuneForeign.live()=0w0)
val phase=Runtime.save image
fun readFile path=let val input=BinIO.openIn path
  in Byte.bytesToString(BinIO.inputAll input) before BinIO.closeIn input end
fun writeFile(path,bytes)=let val output=BinIO.openOut path
  in BinIO.output(output,Byte.stringToBytes bytes);BinIO.closeOut output end
fun rejectsRestore path=((Runtime.restore path;false)handle OS.SysErr _=>true)
val ()=case phase of Runtime.Restored=>() | Runtime.Saved=>
  let val bytes=readFile image
      fun magicEnd i=if String.sub(bytes,i)= #"\000" then i+1 else magicEnd(i+1)
      val at=magicEnd 0+4
      fun corrupt(fill,cut)=String.substring(bytes,0,at)^String.implode(List.tabulate(8,fn _=>fill))^
        String.substring(bytes,at+8,size bytes-at-8-cut)
      val zero=image^".zero" val truncated=image^".truncated"
      val ()=writeFile(zero,corrupt(#"\000",0))
      val ()=writeFile(truncated,corrupt(Char.chr 255,1))
      val ()=check("zero identity floor rejected",rejectsRestore zero)
      val ()=check("malformed image cannot exhaust allocator",rejectsRestore truncated)
  in OS.FileSys.remove zero;OS.FileSys.remove truncated end
val fresh=List.tabulate(16,fn _=>let val p=RuneForeign.allocate 0w4
  in RuneForeign.write(p,0w0,"new!");p end)
val expired=valOf(!borrowed)
val expiredView=valOf(!borrowedView)
val ()=check("stale pointer read rejected",((ignore(RuneForeign.read(expired,0w0,1));false)handle RuneForeign.Error _=>true))
val ()=check("stale view read rejected",((ignore(RuneForeign.read(expiredView,0w0,1));false)handle RuneForeign.Error _=>true))
val ()=check("stale callback pointer cannot revive",not(RuneForeign.isLive expired))
val ()=check("stale callback view cannot revive",not(RuneForeign.isLive expiredView))
val ()=List.app RuneForeign.release fresh
val ()=check("restored registry closed",RuneForeign.live()=0w0)
val ()=print(case phase of Runtime.Saved=>"PASS stale foreign image: saved\n" | Runtime.Restored=>"PASS stale foreign image: restored\n")
