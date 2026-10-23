structure ForeignOwnerTests =
struct
  val checks=ref 0
  fun check(name,condition)=(checks:= !checks+1;if condition then () else raise Fail name)
  val library=RuneForeign.openLibrary(hd(CommandLine.arguments()))
  val little= #littleEndian(RuneForeign.target())
  val sizeType=if #pointerBytes(RuneForeign.target())=4 then RuneForeign.UInt32 else RuneForeign.UInt64
  val calls=ref([]:(RuneForeign.resource*RuneForeign.resource)list)
  fun prepare name result arguments=
    let val symbol=RuneForeign.symbol(library,name)
        val call=RuneForeign.prepare{symbol=symbol,abi=0,result=result,arguments=arguments}
    in calls:=(call,symbol):: !calls;call end
  val copyCall=prepare "rf_copy" RuneForeign.Pointer [RuneForeign.Pointer]
  val freeCall=prepare "rf_checked_free" RuneForeign.SInt32 [RuneForeign.Pointer,RuneForeign.SInt32]
  val countCall=prepare "rf_allocations" sizeType []
  val offsetCall=prepare "rf_offset" RuneForeign.Pointer [RuneForeign.Pointer,sizeType]
  fun count()=ForeignBytes.value{signed=false,littleEndian=true,bytes= #bytes(RuneForeign.invoke(countCall,[]))}
  val input=ForeignMemory.fromBytes "owned\000"
  fun copy()=valOf(#pointer(RuneForeign.invoke(copyCall,[RuneForeign.Address(SOME(ForeignMemory.raw input))])))
  fun descriptor fail : ForeignOwner.destructor={call=freeCall,failure=RuneForeign.Zero,
    arguments=fn pointer=>[RuneForeign.Address(SOME pointer),RuneForeign.Signed(if !fail then 1 else 0)]}
  fun adopt()=ForeignOwner.adopt{pointer=copy(),destructor=descriptor(ref false)}
  fun closed action=((action();false)handle ForeignOwner.Closed=>true)
  fun busy action=((action();false)handle ForeignOwner.Busy=>true)
  val owner=adopt()
  val ()=check("adoption retains native object",count()=1 andalso not(ForeignOwner.isClosed owner))
  val ()=ForeignOwner.withBorrow owner(fn pointer=>
    (check("borrowed bytes",RuneForeign.read(pointer,0w0,6)="owned\000");
     check("borrow blocks destruction",busy(fn()=>ForeignOwner.close owner));
     check("second owner rejected",((ignore(ForeignOwner.adopt{pointer=pointer,destructor=descriptor(ref false)});false)handle ForeignOwner.AlreadyOwned=>true))))
  val alias=ForeignOwner.withBorrow owner(fn pointer=>valOf(#pointer(RuneForeign.invoke(offsetCall,
    [RuneForeign.Address(SOME pointer),RuneForeign.Unsigned 0w0]))))
  val ()=check("distinct identities cannot own one address",((ignore(ForeignOwner.adopt{pointer=alias,destructor=descriptor(ref false)});false)handle ForeignOwner.AlreadyOwned=>true))
  val ()=RuneForeign.release alias
  val view=ForeignOwner.withBorrow owner(fn pointer=>RuneForeign.view(pointer,0w0,0w6))
  val ()=check("native views prevent destruction",((ForeignOwner.close owner;false)handle RuneForeign.Error _=>true))
  val ()=check("failed preflight preserves owner",not(ForeignOwner.isClosed owner) andalso count()=1)
  val ()=RuneForeign.release view
  val ()=ForeignOwner.close owner
  val ()=check("close releases native allocation",ForeignOwner.isClosed owner andalso count()=0)
  val ()=check("second close rejected",closed(fn()=>ForeignOwner.close owner))
  val ()=check("closed borrow rejected",closed(fn()=>ForeignOwner.withBorrow owner(fn _=>())))
  val fail=ref true
  val failed=ForeignOwner.adopt{pointer=copy(),destructor=descriptor fail}
  val ()=check("foreign failure retains raw status",((ForeignOwner.close failed;false)handle ForeignOwner.Failed result=>
    ForeignBytes.value{signed=true,littleEndian=true,bytes= #bytes result}=0 andalso #number(#error result)=13))
  val ()=check("foreign failure retains ownership",not(ForeignOwner.isClosed failed) andalso count()=1)
  val ()=ForeignOwner.withBorrow failed(fn pointer=>check("failed object remains readable",RuneForeign.read(pointer,0w0,5)="owned"))
  val ()=fail:=false
  val ()=ForeignOwner.close failed
  val ()=check("foreign failure can retry",count()=0 andalso ForeignOwner.isClosed failed)
  val bodyFailed=((ForeignScope.withScope(fn scope=>
    let val owner=adopt() val _=ForeignOwner.inScope(scope,owner)
    in raise Fail "body" end);false)handle Fail message=>message="body")
  val ()=check("exceptional scope cleans native owner",bodyFailed andalso count()=0)
  val ()=ForeignScope.withScope(fn scope=>
    let val owner=adopt() val _=ForeignOwner.inScope(scope,owner) in ForeignOwner.close owner end)
  val ()=check("scoped early close occurs once",count()=0)
  val retained=ForeignScope.withScope(fn scope=>
    let val owner=adopt() val ticket=ForeignOwner.inScope(scope,owner)
    in ForeignScope.cancel ticket;owner end)
  val ()=check("scope cancellation transfers responsibility",count()=1 andalso not(ForeignOwner.isClosed retained))
  val ()=ForeignOwner.close retained
  val owner=adopt()
  val ()=((ForeignOwner.withBorrow owner(fn _=>raise Fail "borrow"))handle Fail _=>())
  val ()=ForeignOwner.close owner
  val ()=check("exceptional borrow releases guard",count()=0)
  val ()=ForeignMemory.release input
  val ()=List.app(fn(call,symbol)=>(RuneForeign.release call;RuneForeign.release symbol))(!calls)
  val ()=RuneForeign.release library
  val ()=check("registry empty",RuneForeign.live()=0w0)
  val ()=print("PASS explicit native owners: " ^ Int.toString(!checks) ^ " checks\n")
end
