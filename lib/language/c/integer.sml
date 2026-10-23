(* Implements: C_INTEGER *)
structure CInteger : C_INTEGER =
struct
  datatype rank = Char | Short | Int | Long | LongLong
  type integerType = {rank : rank, width : int, signed : bool}
  type value = {integer : IntInf.int, ty : integerType}
  type target = {char : int, short : int, int : int, long : int, longLong : int}
  exception Error of CLex.location * string
  fun order Char=0 | order Short=1 | order Int=2 | order Long=3 | order LongLong=4
  fun integerType (target:target) rank signed =
    let val width=case rank of Char=> #char target | Short=> #short target | Int=> #int target
          | Long=> #long target | LongLong=> #longLong target
    in if width<8 orelse width>128 then raise Domain else {rank=rank,width=width,signed=signed} end
  fun power width=IntInf.<<(1,Word.fromInt width)
  fun limits ({width,signed,...}:integerType) =
    if width<1 orelse width>128 then raise Domain
    else if signed then let val half=power(width-1) in (IntInf.~ half,IntInf.-(half,1)) end
    else (0,IntInf.-(power width,1))
  fun literal target (token:CLex.token) : value =
    let val ()=if #kind token=CLex.CharacterLiteral andalso not(String.isPrefix "'" (#text token))
          then raise Error(CLex.diagnostic(token,"prefixed character constants require an explicit target encoding")) else ()
        val {integer,...}=CConst.literal{width=128,token=token}
        val text=String.map Char.toLower (#text token)
        val suffix=case List.find(fn suffix=>String.isSuffix suffix text)
          ["ui64","i64u","ull","llu","i64","ul","lu","ll","u","l",""] of SOME s=>s | NONE=>""
        val decimal=not(String.isPrefix "0x" text orelse String.isPrefix "0b" text orelse
          (size text>1 andalso String.sub(text,0)= #"0"))
        val char= #kind token=CLex.CharacterLiteral
        val unsigned=String.isSubstring "u" suffix
        val longlong=String.isSubstring "ll" suffix orelse String.isSubstring "i64" suffix
        val long=String.isSubstring "l" suffix
        val ranks=if char then [Int] else if longlong then [LongLong] else if long then [Long,LongLong] else [Int,Long,LongLong]
        fun choices rank=if unsigned then [integerType target rank false]
          else if decimal orelse char then [integerType target rank true]
          else [integerType target rank true,integerType target rank false]
        fun choose []=raise Error(CLex.diagnostic(token,"integer literal exceeds the supported C target types"))
          | choose(ty::rest)=let val(lo,hi)=limits ty
            in if integer>=lo andalso integer<=hi then {integer=integer,ty=ty} else choose rest end
    in choose(List.concat(List.map choices ranks)) end
  fun convert (ty as {width,signed,...}:integerType) ({integer,...}:value) : value =
    let val modulus=power width
        val bits=IntInf.mod(integer,modulus)
        val value=if width=1 andalso not signed then (if integer=0 then 0 else 1)
          else if signed andalso bits>=power(width-1) then IntInf.-(bits,modulus) else bits
    in {integer=value,ty=ty} end
  fun promote target (value as {ty={rank,...},...}:value) =
    if order rank>=order Int then value else
      let val signedInt=integerType target Int true
          val (_,largest)=limits signedInt
          val (_,required)=limits(#ty value)
      in convert (if required<=largest then signedInt else integerType target Int false) value end
  fun promotedType target ty = #ty(promote target {integer=0,ty=ty})
  fun common target (left,right) =
    let val a as {rank=ra,width=wa,signed=sa}=promotedType target left
        val b as {rank=rb,width=wb,signed=sb}=promotedType target right
    in if sa=sb then if order ra>=order rb then a else b
       else let val unsigned=if sa then b else a
                val signed=if sa then a else b
            in if order(#rank unsigned)>=order(#rank signed) then unsigned
               else if #width signed> #width unsigned then signed
               else integerType target (#rank signed) false end
    end
  fun unary target (token:CLex.token) value : value =
    let val value as {integer,ty}=promote target value
        fun fail message=raise Error(CLex.diagnostic(token,message))
        val(lo,hi)=limits ty
        fun checked n=if #signed ty andalso (n<lo orelse n>hi) then fail "signed C unary overflow"
          else convert ty {integer=n,ty=ty}
    in case #text token of "+"=>value | "-"=>checked(IntInf.~ integer)
      | "~"=>checked(IntInf.notb integer)
      | "!"=>{integer=if integer=0 then 1 else 0,ty=integerType target Int true}
      | _=>fail "unsupported C unary operator"
    end
  fun binary target (token:CLex.token) (left,right) =
    let fun fail message=raise Error(CLex.diagnostic(token,message))
        val a=promote target left val b=promote target right
        val ty=common target (#ty a,#ty b)
        val {integer=x,...}=convert ty a
        val {integer=y,...}=convert ty b
        val (least,largest)=limits ty
        fun checked ty n : value =
          let val (least,largest)=limits ty
          in if #signed ty andalso (n<least orelse n>largest) then fail "signed C integer overflow"
             else convert ty {integer=n,ty=ty} end
        fun bool condition : value={integer=if condition then 1 else 0,ty=integerType target Int true}
        fun divide remainder =
          if y=0 then fail "division by zero in C constant"
          else if #signed ty andalso x=least andalso y= ~1 then fail "signed C division overflow"
          else checked ty (if remainder then IntInf.rem(x,y) else IntInf.quot(x,y))
        fun shift left =
          let val {integer=x,ty}=a val count= #integer b
          in if count<0 orelse count>=IntInf.fromInt(#width ty) then fail "invalid C shift count"
             else if left andalso #signed ty andalso x<0 then fail "left shift of a negative C integer"
             else checked ty ((if left then IntInf.<< else IntInf.~>>)(x,Word.fromInt(IntInf.toInt count))) end
    in case #text token of
      "+"=>checked ty (IntInf.+(x,y)) | "-"=>checked ty (IntInf.-(x,y)) | "*"=>checked ty (IntInf.*(x,y))
    | "/"=>divide false | "%"=>divide true
    | "&"=>checked ty (IntInf.andb(x,y)) | "|"=>checked ty (IntInf.orb(x,y)) | "^"=>checked ty (IntInf.xorb(x,y))
    | "<<"=>shift true | ">>"=>shift false
    | "=="=>bool(x=y) | "!="=>bool(x<>y) | "<"=>bool(x<y) | ">"=>bool(x>y)
    | "<="=>bool(x<=y) | ">="=>bool(x>=y)
    | _=>fail "unsupported C integer operator"
    end
end
