(* Implements: FOREIGN_OWNER *)
structure ForeignOwner :> FOREIGN_OWNER =
struct
  datatype state=Open | Closing | Finished
  type destructor={call:RuneForeign.resource,arguments:RuneForeign.resource->RuneForeign.argument list,failure:RuneForeign.failure}
  datatype owner=Owner of {pointer:RuneForeign.resource,destructor:destructor,state:state ref,borrows:int ref}
  exception Closed
  exception Busy
  exception AlreadyOwned
  exception Failed of RuneForeign.result
  val owners=ref([]:owner list)
  fun raw(Owner{pointer,...})=pointer
  fun forget pointer=owners:=List.filter(fn known=>raw known<>pointer)(!owners)
  fun isClosed(Owner{pointer,state,...})=case !state of Finished=>true
    | _=>if RuneForeign.isLive pointer then false else (state:=Finished;forget pointer;true)
  fun adopt{pointer,destructor}=
    let val ()=if RuneForeign.isLive pointer then () else raise Closed
        val existing=List.filter(fn owner=>not(isClosed owner))(!owners)
        val ()=owners:=existing
        val ()=if List.exists(fn owner=>RuneForeign.sameAddress(pointer,raw owner))existing then raise AlreadyOwned else ()
        val owner=Owner{pointer=pointer,destructor=destructor,state=ref Open,borrows=ref 0}
    in owners:=owner:: !owners;owner end
  fun retain (owner as Owner{state,borrows,...})=
    if isClosed owner then raise Closed else case !state of Closing=>raise Busy | _=>
      let val ()=borrows:= !borrows+1
          val released=ref false
      in fn()=>if !released then () else (released:=true;borrows:= !borrows-1) end
  fun withBorrow (owner as Owner{pointer,...}) body=
    let val release=retain owner
        val answer=body pointer handle e=>(release();raise e)
    in release();answer end
  fun close(owner as Owner{pointer,destructor={call,arguments,failure},state,borrows})=
    if isClosed owner then raise Closed else if !state=Closing orelse !borrows>0 then raise Busy else
    let val ()=state:=Closing
        fun recover e=
          (((if RuneForeign.isLive pointer then state:=Open else (state:=Finished;forget pointer))handle _=>state:=Open);raise e)
        val outcome=(RuneForeign.dispose{resource=pointer,call=call,arguments=arguments pointer,failure=failure}handle e=>recover e)
    in if #disposed outcome then (state:=Finished;forget pointer)
       else (state:=Open;raise Failed(#result outcome)) end
  fun inScope(scope,owner)=ForeignScope.defer(scope,fn()=>if isClosed owner then () else close owner)
end
