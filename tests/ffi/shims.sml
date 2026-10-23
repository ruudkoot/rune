structure ForeignShimCalls =
struct
  val args=CommandLine.arguments()
  val library=RuneForeign.openLibrary(hd args)
  val pairSize=valOf(Int.fromString(List.nth(args,1)))
  val fraction=valOf(Int.fromString(List.nth(args,2)))
  val bitsSize=valOf(Int.fromString(List.nth(args,3)))
  val unionSize=valOf(Int.fromString(List.nth(args,4)))
  val pointerSize=valOf(Int.fromString(List.nth(args,5)))
  val packedSize=valOf(Int.fromString(List.nth(args,6)))
  val little= #littleEndian(RuneForeign.target())
  val checks=ref 0
  fun check(label,condition)=(checks:= !checks+1;if condition then () else raise Fail label)
  fun invoke name result types arguments=ForeignScope.withScope(fn scope=>
    let val symbol=RuneForeign.symbol(library,name)
        val ()=ignore(ForeignScope.defer(scope,fn()=>RuneForeign.release symbol))
        val call=RuneForeign.prepare{symbol=symbol,abi=0,result=result,arguments=types}
        val ()=ignore(ForeignScope.defer(scope,fn()=>RuneForeign.release call))
    in RuneForeign.invoke(call,arguments) end)
  fun integer(result:RuneForeign.result)=ForeignBytes.value{signed=false,littleEndian=true,bytes= #bytes result}
  fun realValue(result:RuneForeign.result)=ForeignBytes.real64Value{littleEndian=true,bytes= #bytes result}
  fun address buffer=RuneForeign.Address(SOME(ForeignMemory.raw buffer))
  fun owned scope n=let val buffer=ForeignMemory.allocate n
    in ignore(ForeignScope.defer(scope,fn()=>ForeignMemory.release buffer));buffer end
  val ()=ForeignScope.withScope(fn scope=>
    let val pair=owned scope pairSize
        val ()=ignore(invoke "runeffi_pair_make" RuneForeign.Void [RuneForeign.Pointer,RuneForeign.SInt32,RuneForeign.Float64]
          [address pair,RuneForeign.Signed 42,RuneForeign.Real 0.25])
        val ()=check("aggregate result integer",ForeignBytes.value{signed=true,littleEndian=little,bytes=ForeignMemory.read(pair,0,4)}=42)
        val ()=check("aggregate result double",Real.==(ForeignBytes.real64Value{littleEndian=little,bytes=ForeignMemory.read(pair,fraction,8)},0.25))
        val ()=check("aggregate argument",Real.==(realValue(invoke "runeffi_pair_total" RuneForeign.Float64 [RuneForeign.Pointer][address pair]),42.25))
        val ()=ForeignMemory.write(pair,0,ForeignBytes.integer{width=4,signed=true,littleEndian=little,value= ~7})
        val ()=check("mutated aggregate argument",Real.==(realValue(invoke "runeffi_pair_total" RuneForeign.Float64 [RuneForeign.Pointer][address pair]),~6.75))
        val bits=owned scope bitsSize
        fun set name n=ignore(invoke name RuneForeign.Void [RuneForeign.Pointer,RuneForeign.UInt32][address bits,RuneForeign.Unsigned n])
        fun get name=integer(invoke name RuneForeign.UInt32 [RuneForeign.Pointer][address bits])
        val ()=(set "runeffi_bits_low_set" 0w7;set "runeffi_bits_high_set" 0w31)
        val ()=check("bitfield reads",get "runeffi_bits_low_get"=7 andalso get "runeffi_bits_high_get"=31)
        val ()=(set "runeffi_bits_low_set" 0w1;check("bitfield writes preserve neighbor",get "runeffi_bits_low_get"=1 andalso get "runeffi_bits_high_get"=31))
        val variant=owned scope unionSize
        val ()=ignore(invoke "runeffi_value_real_set" RuneForeign.Void [RuneForeign.Pointer,RuneForeign.Float64][address variant,RuneForeign.Real 1.0])
        val ()=check("union representation",integer(invoke "runeffi_value_bits_get" RuneForeign.UInt64 [RuneForeign.Pointer][address variant])=4607182418800017408)
        val ()=ignore(invoke "runeffi_value_bits_set" RuneForeign.Void [RuneForeign.Pointer,RuneForeign.UInt64][address variant,RuneForeign.Unsigned 0wx4000000000000000])
        val ()=check("union round trip",Real.==(realValue(invoke "runeffi_value_real_get" RuneForeign.Float64 [RuneForeign.Pointer][address variant]),2.0))
        val record=owned scope pointerSize
        val data=owned scope 6
        val ()=ForeignMemory.write(data,0,"hello\000")
        val ()=ignore(invoke "runeffi_pointer_value_set" RuneForeign.Void [RuneForeign.Pointer,RuneForeign.Pointer][address record,address data])
        val pointer=valOf(#pointer(invoke "runeffi_pointer_value_get" RuneForeign.Pointer [RuneForeign.Pointer][address record]))
        val ()=check("pointer member identity",RuneForeign.read(pointer,0w0,5)="hello")
        val ()=ForeignMemory.write(data,0,"j")
        val ()=check("pointer member alias",RuneForeign.read(pointer,0w0,5)="jello")
        val ()=RuneForeign.release pointer
        val ()=ignore(invoke "runeffi_pointer_callback_set" RuneForeign.Void [RuneForeign.Pointer,RuneForeign.Pointer][address record,RuneForeign.Address NONE])
        val ()=check("function pointer member null",not(isSome(#pointer(invoke "runeffi_pointer_callback_get" RuneForeign.Pointer [RuneForeign.Pointer][address record]))))
        val packed=owned scope packedSize
        val ()=List.app(fn(name,ty,n)=>ignore(invoke("runeffi_packed_" ^ name ^ "_set")RuneForeign.Void
          [RuneForeign.Pointer,ty][address packed,RuneForeign.Unsigned n]))
          [("prefix",RuneForeign.UInt8,0w165),("tail",RuneForeign.UInt8,0w90),("low",RuneForeign.UInt32,0w7),("high",RuneForeign.UInt32,0w31)]
        val ()=check("packed bitfields preserve adjacent bytes",List.all(fn(name,ty,n)=>integer(invoke("runeffi_packed_" ^ name ^ "_get")ty
          [RuneForeign.Pointer][address packed])=n)
          [("prefix",RuneForeign.UInt8,165),("tail",RuneForeign.UInt8,90),("low",RuneForeign.UInt32,7),("high",RuneForeign.UInt32,31)])
    in () end)
  val ()=check("macro adapter",integer(invoke "runeffi_low" RuneForeign.UInt32 [RuneForeign.UInt32][RuneForeign.Unsigned 0wx1234])=52)
  val ()=check("inline adapter",integer(invoke "runeffi_twice" RuneForeign.SInt32 [RuneForeign.SInt32][RuneForeign.Signed 21])=42)
  val ()=check("fixed variadic integer promotions",integer(invoke "runeffi_variadic_sum" RuneForeign.SInt32
    [RuneForeign.UInt32,RuneForeign.SInt16,RuneForeign.SInt8][RuneForeign.Unsigned 0w2,RuneForeign.Signed 20,RuneForeign.Signed 22])=42)
  val ()=check("fixed variadic float promotion",Real.==(realValue(invoke "runeffi_variadic_real" RuneForeign.Float64
    [RuneForeign.UInt32,RuneForeign.Float32,RuneForeign.Float32][RuneForeign.Unsigned 0w2,RuneForeign.Real 0.25,RuneForeign.Real 0.5]),0.75))
  val ()=RuneForeign.release library
  val ()=check("resources cleaned",RuneForeign.live()=0w0)
  val ()=print("PASS generated C adapters: " ^ Int.toString(!checks) ^ " checks\n")
end
