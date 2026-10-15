(* IntInf: canonical small integers or signed immutable packed magnitudes.
   The bytes are little endian, independent of the arithmetic workspace's
   limb width. Arrays below are private scratch and never escape in a value.

   Implements: INT_INF

   Implements: INTEGER

   Status: optional *)
structure IntInf =
struct
  type limb = int
  datatype int = S of limb | B of bool * string

  val intQuot = _prim "int_quot" : limb * limb -> limb
  val intRem = _prim "int_rem" : limb * limb -> limb
  val intToString = _prim "int_to_string" : limb -> string
  val strSize = _prim "string_size" : string -> limb
  val strSub = _prim "string_sub" : string * limb -> char
  val anew = _prim "array_new" : limb * limb -> limb array
  val alen = _prim "array_length" : limb array -> limb
  val at = _prim "array_sub" : limb array * limb -> limb
  val put = _prim "array_update" : limb array * limb * limb -> unit
  val intAdd = _prim "int_add" : limb * limb -> limb
  fun width (n, k) = width (intAdd (intAdd (n,n),1), k+1)
                      handle Overflow => k+1
  val machineBits = width (0,0)
  val smallBytes = (machineBits + 7) div 8
  val limbBits = if machineBits >= 61 then 30 else 15
  val shiftWord = _prim "word_lsl" : word * word -> word
  val toWord = _prim "word_from_int" : limb -> word
  val fromWord = _prim "word_to_int" : word -> limb
  fun pow2 k = fromWord(shiftWord(0w1,toWord k))
  val base = pow2 limbBits
  val mask = base - 1
  val smallTop = pow2 ((machineBits-1) mod 8)
  val zero = S 0
  val one = S 1

  fun byte (s,i) = ord (strSub (s,i))
  fun bput (a,i,n) = RuneBytes.update (a,i,chr n)
  val gmpAvailable = _prim "intinf_gmp_available" : unit -> bool
  val maxBits = _prim "intinf_max_bits" : unit -> limb
  val checkBits = _prim "intinf_check_bits" : limb -> unit
  val gmpBinary = _prim "intinf_binary" : limb * bool * string * bool * string -> bool * string
  val gmpDivMod = _prim "intinf_divmod" : bool * bool * string * bool * string -> (bool * string) * (bool * string)
  val gmpShift = _prim "intinf_shift" : bool * bool * string * word -> bool * string
  val gmpPower = _prim "intinf_power" : bool * string * limb -> bool * string
  val gmpDecimal = _prim "intinf_decimal" : string -> string
  fun digitBits 0 = 0 | digitBits n = 1 + digitBits(n div 2)
  fun magBits s =
    let val n = strSize s in if n = 0 then 0 else (n-1)*8+digitBits(byte(s,n-1)) end
  fun checkMag s =
    if strSize s <= 8 then ()
    else let val limit = maxBits()
         in if strSize s <= limit div 8 then ()
            else if strSize s > limit div 8 + 1 then checkBits(limit+1)
            else checkBits(magBits s) end
  (* All callers supply a canonical, budget-checked magnitude: pack and
     GMP export enforce that contract, and an existing magnitude is checked
     before reuse. The bytewise left shift selects its significant length.
     Test the signed boundary before decoding, without an Overflow handler. *)
  fun make (neg,s) =
    let val n = strSize s
        fun lowZero i = i < 0 orelse (byte(s,i) = 0 andalso lowZero(i-1))
        fun fits () = n < smallBytes orelse byte(s,n-1) < smallTop orelse
          (neg andalso byte(s,n-1) = smallTop andalso lowZero(n-2))
        fun small (i,acc) =
          if i < 0 then S acc
          else small (i-1, if neg then acc*256-byte(s,i) else acc*256+byte(s,i))
    in if n = 0 then zero
       else if n > smallBytes then B (neg,s)
       else if fits() then small (n-1,0) else B (neg,s)
    end
  fun smallMag n =
    let val out = RuneBytes.new (smallBytes,0)
        fun loop (x,i) = if x = 0 then RuneBytes.extract (out,0,i)
          else let val r = intRem (x,256)
               in bput (out,i,if r < 0 then ~r else r); loop (intQuot(x,256),i+1) end
    in loop (n,0) end
  fun magnitude (S n) = smallMag n | magnitude (B (_,s)) = (checkMag s; s)
  fun negative (S n) = n < 0 | negative (B (n,_)) = n
  fun isZero (S 0) = true | isZero _ = false
  fun fromInt n = S n
  fun toInt (S n) = n | toInt _ = raise Overflow

  (* The workspace is a little-endian array plus its significant length. *)
  fun trim (a,n) = if n > 0 andalso at(a,n-1) = 0 then trim(a,n-1) else (a,n)
  val unpackBytes = _prim "intinf_unpack" : string * limb -> limb array
  val packBytes = _prim "intinf_pack" : limb array * limb * limb -> string
  fun unpack s = let val a = unpackBytes(s,limbBits) in trim(a,alen a) end
  fun pack (a,n) =
    let val (a,n) = trim(a,n)
        val () = if n = 0 orelse n <= maxBits() div limbBits then ()
                 else checkBits((n-1)*limbBits+digitBits(at(a,n-1)))
    in packBytes(a,n,limbBits) end
  fun cmpMag (a,b) =
    let val na = strSize a and nb = strSize b
        fun loop i = if i < 0 then EQUAL
          else let val x = byte(a,i) and y = byte(b,i)
               in if x < y then LESS else if x > y then GREATER else loop(i-1) end
    in if na < nb then LESS else if na > nb then GREATER else loop(na-1) end
  fun carryDigits (a,n,c) =
    if c = 0 then (a,n)
    else let val r = anew(n+1,0)
             fun copy i = if i = n then put(r,n,c)
                          else (put(r,i,at(a,i)); copy(i+1))
             val () = copy 0
         in (r,n+1) end
  val smallLimbs = (machineBits+limbBits-1) div limbBits
  val smallLimbTop = pow2 ((machineBits-1) mod limbBits)
  (* A small scratch result never needs an intermediate packed string.
     Runtime budgets are at least 64 bits and cover every supported small int. *)
  fun finish (neg,work) =
    let val (a,n) = trim work
        fun lowZero i = i < 0 orelse (at(a,i) = 0 andalso lowZero(i-1))
        fun fits () = n < smallLimbs orelse at(a,n-1) < smallLimbTop orelse
          (neg andalso at(a,n-1) = smallLimbTop andalso lowZero(n-2))
        fun small(i,v) = if i < 0 then S v else
          small(i-1,if neg then v*base-at(a,i) else v*base+at(a,i))
    in if n = 0 then zero
       else if n <= smallLimbs andalso fits() then small(n-1,0)
       else B(neg,pack(a,n)) end
  fun addMag (sa,sb) =
    if strSize sa < strSize sb then addMag(sb,sa)
    else let val (a,na) = unpack sa and (b,nb) = unpack sb
             fun loop(i,c) = if i = na then c
               else let val v = at(a,i) + (if i < nb then at(b,i) else 0) + c
                    in if v >= base then (put(a,i,v-base); loop(i+1,1))
                       else (put(a,i,v); loop(i+1,0)) end
         in carryDigits(a,na,loop(0,0)) end
  fun subMag (sa,sb) =
    let val (a,na) = unpack sa and (b,nb) = unpack sb
        fun loop(i,c) = if i = na then ()
          else let val v = at(a,i) - (if i < nb then at(b,i) else 0) - c
               in put(a,i,if v < 0 then v+base else v); loop(i+1,if v < 0 then 1 else 0) end
        val () = loop(0,0)
    in (a,na) end
  fun mulDigits ((a,na),(b,nb)) =
    let val r = anew(na+nb,0)
        fun row(i,j,c) = if j = nb then put(r,i+nb,c)
          else let val v = at(a,i)*at(b,j)+at(r,i+j)+c
               in put(r,i+j,v mod base); row(i,j+1,v div base) end
        fun loop i = if i = na then () else (row(i,0,0); loop(i+1))
        val () = if na = 0 orelse nb = 0 then () else loop 0
    in pack(r,na+nb) end
  fun mulMag (sa,sb) = mulDigits(unpack sa,unpack sb)
  (* The machine multiply has already proved that the result needs B.
     Keep its inputs boxed until promotion and put the shorter magnitude
     in the outer multiplication loop. The at-most-once tail swap also keeps
     this cold routine separate from mulI's small fast path. *)
  fun mulOverflow (a,b) =
    let
      val x = case a of S x => x | _ => raise Match
      val y = case b of S y => y | _ => raise Match
      val nx = if x > 0 then ~x else x
      val ny = if y > 0 then ~y else y
    in if nx < ny then mulOverflow(b,a)
       else let
          fun bits v =
            let val q = intQuot(v,base)
            in if q = 0 then digitBits(if v < 0 then ~v else v)
               else limbBits + bits q end
          val () = if maxBits() >= machineBits+machineBits then ()
                   else checkBits(bits x+bits y-1)
          fun digits v =
            let val a = anew((machineBits+limbBits-1) div limbBits,0)
                fun loop(v,i) = if v = 0 then (a,i)
                  else let val d = intRem(v,base)
                       in put(a,i,if d < 0 then ~d else d); loop(intQuot(v,base),i+1) end
            in loop(v,0) end
        in B((x < 0) <> (y < 0),mulDigits(digits x,digits y)) end
    end
  fun scale ((a,n),d) =
    let val r = anew(n+1,0)
        fun loop(i,c) = if i = n then put(r,n,c)
          else let val v = at(a,i)*d+c
               in put(r,i,v mod base); loop(i+1,v div base) end
        val () = loop(0,0)
    in (r,n) end
  fun divideSmall ((a,n),d) =
    let val q = anew(n,0)
        fun loop(i,r) = if i < 0 then (trim(q,n),r)
          else let val v = r*base+at(a,i)
               in put(q,i,v div d); loop(i-1,v mod d) end
    in loop(n-1,0) end
  fun divModMag (sa,sb) =
    if cmpMag(sa,sb) = LESS then ("",sa)
    else
      let val (a,m) = unpack sa and (b,n) = unpack sb
      in
        if n = 1 then
          let val (q,r) = divideSmall((a,m),at(b,0))
          in (pack q,smallMag r) end
        else
          let
            val d = base div (at(b,n-1)+1)
            val (u,_) = scale((a,m),d)
            val (v,_) = scale((b,n),d)
            val q = anew(m-n+1,0)
            val top = at(v,n-1)
            fun correct(qh,rh,j) =
              if rh < base andalso qh*at(v,n-2) > rh*base+at(u,j+n-2)
              then correct(qh-1,rh+top,j) else qh
            fun subtract(j,qh,i,c,bw) =
              if i = n then
                let val t = at(u,j+n)-c-bw
                in put(u,j+n,if t < 0 then t+base else t); t < 0 end
              else let val p = qh*at(v,i)+c
                       val t = at(u,j+i)-(p mod base)-bw
                   in put(u,j+i,if t < 0 then t+base else t);
                      subtract(j,qh,i+1,p div base,if t < 0 then 1 else 0) end
            fun addBack(j,i,c) =
              if i = n then put(u,j+n,(at(u,j+n)+c) mod base)
              else let val t = at(u,j+i)+at(v,i)+c
                   in put(u,j+i,t mod base); addBack(j,i+1,t div base) end
            fun loop j = if j < 0 then ()
              else let val num = at(u,j+n)*base+at(u,j+n-1)
                       val estimate = if at(u,j+n) = top then base-1 else num div top
                       val qh = correct(estimate,num-estimate*top,j)
                       val borrowed = subtract(j,qh,0,0,0)
                       val () = if borrowed then addBack(j,0,0) else ()
                   in put(q,j,if borrowed then qh-1 else qh); loop(j-1) end
            val () = loop(m-n)
            val (r,_) = divideSmall((u,n),d)
          in (pack(q,m-n+1),pack r) end
      end

  fun negI (S n) = (S (~n) handle Overflow => B(false,smallMag n))
    | negI (B (neg,s)) = (checkMag s; make(not neg,s))
  fun absI x = if negative x then negI x else x
  (* A large magnitude is at least the magnitude of every small value.
     Update a private copy only as far as carry/borrow propagates; the rest
     is copied in bulk. Signed quot/rem also handle the minimum machine int. *)
  fun addLargeSmall (neg,s,x) =
    let val () = checkMag s
        val n = strSize s
        val adding = neg = (x < 0)
        val out = RuneBytes.new(n+1,0)
        val () = RuneBytes.blitString(s,0,out,0,n)
        fun step(i,d,q,c) =
          let val a = if i < n then byte(s,i) else 0
              val t = if adding then a+d+c else a-d-c
          in if t < 0 then (bput(out,i,t+256); loop(i+1,q,1))
             else if t >= 256 then (bput(out,i,t-256); loop(i+1,q,1))
             else (bput(out,i,t); loop(i+1,q,0)) end
        and loop(i,v,c) =
          if v = 0 andalso c = 0 then if i > n then i else n
          else if v > ~256 andalso v < 256 then step(i,if v < 0 then ~v else v,0,c)
          else let val r = intRem(v,256)
               in step(i,if r < 0 then ~r else r,intQuot(v,256),c) end
        val used = loop(0,x,0)
        fun top i = if i > 0 andalso RuneBytes.sub(out,i-1) = #"\000" then top(i-1) else i
        val count = if adding then used else top used
        (* Check the exact boundary before allocating the immutable result. *)
        val () = if count <= 8 then ()
          else let val limit = maxBits()
               in if count <= limit div 8 then ()
                  else if count > limit div 8 + 1 then checkBits(limit+1)
                  else checkBits((count-1)*8+digitBits(ord(RuneBytes.sub(out,count-1)))) end
        val result = RuneBytes.extract(out,0,count)
    in if adding then B(neg,result) else make(neg,result) end
  (* Callers supply two large values, or a failed machine addition. With
     equal signs their sum cannot return to the small representation. *)
  fun addPacked (na,ma,nb,mb) =
    let val () = checkMag ma
        val () = checkMag mb
    in if na = nb then
         B(na,if gmpAvailable() then #2(gmpBinary(0,na,ma,nb,mb)) else pack(addMag(ma,mb)))
       else if gmpAvailable() then make(gmpBinary(0,na,ma,nb,mb))
       else if cmpMag(ma,mb) = LESS then finish(nb,subMag(mb,ma))
       else finish(na,subMag(ma,mb)) end
  fun addBig (a,b) = addPacked(negative a,magnitude a,negative b,magnitude b)
  (* Destructure the arguments once so known calls can pass the operands
     directly, without allocating an argument tuple on the small path. *)
  fun addI (a,b) =
    case a of
      S x => (case b of S y => (S(x+y) handle Overflow => addBig(a,b))
                     | B (neg,s) => if x = 0 then b else addLargeSmall(neg,s,x))
    | B (neg,s) => (case b of S 0 => a | S x => addLargeSmall(neg,s,x)
                           | B (nb,mb) => addPacked(neg,s,nb,mb))
  fun subI (S a,S b) = (S(a-b) handle Overflow => addBig(S a,negI(S b)))
    | subI (a,b) = addI(a,negI b)
  fun mulBig (a,b) =
    let val ma = magnitude a and mb = magnitude b
        val () = if strSize ma + strSize mb <= maxBits() div 8 then ()
                 else checkBits(magBits ma+magBits mb-1)
    in if gmpAvailable() then make(gmpBinary(2,negative a,ma,negative b,mb))
       else make(negative a <> negative b,mulMag(ma,mb)) end
  fun mulLargeSmall (large as B (neg,s),x) =
    if x = ~1 then negI large
    else if x <= ~base orelse x >= base orelse gmpAvailable() then mulBig(large,S x)
    else let val () = checkMag s
             val d = if x < 0 then ~x else x
             val () = if strSize s <= (maxBits()-limbBits) div 8 then ()
                      else checkBits(magBits s+digitBits d-1)
             val (a,n) = unpack s
             fun loop(i,c) = if i = n then c
               else let val v = at(a,i)*d+c
                    in put(a,i,v mod base); loop(i+1,v div base) end
         in finish(neg <> (x < 0),carryDigits(a,n,loop(0,0))) end
    | mulLargeSmall (a,x) = mulBig(a,S x)
  fun mulI (a,b) =
    case a of
      S x => (case b of S y => (S(x*y) handle Overflow => mulOverflow(a,b))
                     | _ => if x = 0 then zero else if x = 1 then b else mulLargeSmall(b,x))
    | _ => (case b of S 0 => zero | S 1 => a | S x => mulLargeSmall(a,x)
                     | _ => mulBig(a,b))
  fun quotBig (a,b) =
    if isZero b then raise Div
    else let val ma = magnitude a and mb = magnitude b
         in if strSize ma < strSize mb then (zero,a)
            else if gmpAvailable() then
              let val (q,r) = gmpDivMod(false,negative a,ma,negative b,mb)
              in (make q,make r) end
            else let val (q,r) = divModMag(ma,mb)
                 in (make(negative a <> negative b,q),make(negative a,r)) end
         end
  fun quotRemI (a,S 1) = (a,zero)
    | quotRemI (a,S (~1)) = (negI a,zero)
    | quotRemI (S a,S b) = ((S(intQuot(a,b)),S(intRem(a,b)))
                           handle Overflow => quotBig(S a,S b))
    (* A canonical large magnitude exceeds every nonnegative small value.
       A negative small value can tie the positive large boundary, so that
       case still uses the general division path. *)
    | quotRemI (a as S n,b as B (neg,s)) =
        if n >= 0 orelse neg orelse strSize s > smallBytes then (zero,a)
        else quotBig(a,b)
    | quotRemI p = quotBig p
  fun floorFromTrunc (a,b) =
    let val (q,r) = quotRemI(a,b)
    in if isZero r orelse negative a = negative b then (q,r)
       else (subI(q,one),addI(r,b)) end
  fun divModI (a,S 1) = (a,zero)
    | divModI (a,S (~1)) = (negI a,zero)
    | divModI (a as S _,b) = floorFromTrunc(a,b)
    | divModI (a,b) =
      if isZero b then raise Div
      else if gmpAvailable() then
        let val ma = magnitude a and mb = magnitude b
        in if strSize ma < strSize mb then
             if negative a = negative b then (zero,a) else (S (~1),addI(a,b))
           else let val (q,r) = gmpDivMod(true,negative a,ma,negative b,mb)
                in (make q,make r) end
        end
      else floorFromTrunc(a,b)
  fun compare (S a,S b) = if a < b then LESS else if a > b then GREATER else EQUAL
    (* Canonical large values lie outside the machine range. Mixed
       comparisons therefore need neither conversion nor allocation. *)
    | compare (S _,B (neg,_)) = if neg then GREATER else LESS
    | compare (B (neg,_),S _) = if neg then LESS else GREATER
    | compare (B (na,a),B (nb,b)) =
        if na <> nb then (if na then LESS else GREATER)
        else if na then cmpMag(b,a) else cmpMag(a,b)
  fun sign (S n) = if n = 0 then 0 else if n < 0 then ~1 else 1
    | sign (B (neg,_)) = if neg then ~1 else 1
  fun pow (x,n) =
    if n < 0 then if isZero x then raise Div
      else if x = one then one
      else if x = S (~1) then (if intRem(n,2) = 0 then one else x)
      else zero
    else if n = 0 then one
    else if isZero x orelse x = one then x
    else if x = S (~1) then (if n mod 2 = 0 then one else x)
    else let val m = magnitude x
             val bits = magBits m
             val limit = maxBits()
             val () = if bits > 1 andalso n > (limit-1) div (bits-1)
                      then checkBits(limit+1) else ()
             fun loop(b,e,acc) =
               if e = 0 then acc
               else let val acc = if e mod 2 = 0 then acc else mulI(acc,b)
                    in if e = 1 then acc else loop(mulI(b,b),e div 2,acc) end
         in if gmpAvailable() then make(gmpPower(negative x,m,n)) else loop(x,n,one) end

  val decimalChunk = if limbBits = 30 then 1000000000 else 10000
  val decimalDigits = if limbBits = 30 then 9 else 4
  (* Only this private copy is overwritten. Keeping one quotient workspace
     avoids quadratic temporary allocation while extracting decimal chunks. *)
  fun decimalSml s =
      let
        val (a,n) = unpack s
        fun divide (i,r) = if i < 0 then r
          else let val v = r*base+at(a,i)
               in put(a,i,v div decimalChunk); divide(i-1,v mod decimalChunk) end
        fun chunks (0,acc) = acc
          | chunks (n,acc) =
              let val r = divide(n-1,0)
              in chunks(#2(trim(a,n)),r::acc) end
        fun zeros(n,ss) = if n <= 0 then ss else zeros(n-1,"0"::ss)
        fun render(_,[]) = []
          | render(first,c::cs) =
              let val t = intToString c
                  val t = if first then t else concat(zeros(decimalDigits-strSize t,[t]))
              in t::render(false,cs) end
      in concat(render(true,chunks(n,[]))) end
  fun toString (S n) = intToString n
    | toString (B (neg,s)) =
      let val () = checkBits(magBits s)
          val text = if gmpAvailable() then gmpDecimal s else decimalSml s
      in if neg then "~" ^ text else text end
  fun log2 x = if sign x <= 0 then raise Domain else magBits(magnitude x)-1
  fun radixBase StringCvt.BIN = 2 | radixBase StringCvt.OCT = 8
    | radixBase StringCvt.DEC = 10 | radixBase StringCvt.HEX = 16
  fun fmt StringCvt.DEC x = toString x
    | fmt radix x =
      if isZero x then "0"
      else let val s = magnitude x
               val r = radixBase radix
               val bits = if r = 2 then 1 else if r = 8 then 3 else 4
               val digits = (magBits s+bits-1) div bits
               val prefix = if negative x then 1 else 0
               val out = RuneBytes.new(digits+prefix,0)
               val () = if prefix = 1 then bput(out,0,126) else ()
               fun loop i = if i = digits then ()
                 else let val bit = (digits-i-1)*bits
                          val pos = bit div 8 and shift = bit mod 8
                          val v = byte(s,pos) + (if pos+1 < strSize s then byte(s,pos+1)*256 else 0)
                          val d = (v div pow2 shift) mod r
                      in bput(out,i+prefix,if d < 10 then 48+d else 55+d); loop(i+1) end
               val () = loop 0
           in RuneBytes.extract(out,0,digits+prefix) end

  fun scan radix (getc : (char,'a) StringCvt.reader) src =
    let
      val r = radixBase radix
      fun digitValue c =
        let val n = ord c
            val v = if 48 <= n andalso n <= 57 then n-48
              else if 97 <= n andalso n <= 102 then n-87
              else if 65 <= n andalso n <= 70 then n-55 else 99
        in if v < r then SOME v else NONE end
      fun digitNext src = case getc src of
        SOME(c,_) => (case digitValue c of SOME _ => true | NONE => false) | NONE => false
      val src = StringCvt.skipWS getc src
      val (neg,src) = case getc src of
        SOME(#"~",rest) => (true,rest) | SOME(#"-",rest) => (true,rest)
      | SOME(#"+",rest) => (false,rest) | _ => (false,src)
      val src = if r <> 16 then src else
        case getc src of SOME(#"0",rest) =>
          (case getc rest of SOME(c,rest') =>
             if (c = #"x" orelse c = #"X") andalso digitNext rest' then rest' else src
           | NONE => src) | _ => src
      fun big (src,a,n) =
        let
          fun grow () =
            let val b = anew(alen a*2+1,0)
                fun copy i = if i = n then () else (put(b,i,at(a,i)); copy(i+1))
                val () = copy 0
            in b end
          fun more(d,rest) =
            let val () = if n = 0 then () else checkBits((n-1)*limbBits+digitBits(at(a,n-1)))
                val a = if n = alen a then grow() else a
                fun mul(i,c) = if i = n then
                    if c = 0 then n else (put(a,n,c); n+1)
                  else let val v = at(a,i)*r+c
                       in put(a,i,v mod base); mul(i+1,v div base) end
            in big(rest,a,mul(0,d)) end
        in case getc src of
             SOME(c,rest) => (case digitValue c of SOME d => more(d,rest)
                              | NONE => (make(neg,pack(a,n)),src))
           | NONE => (make(neg,pack(a,n)),src)
        end
      fun small(src,v) =
        case getc src of
          SOME(c,rest) =>
            (case digitValue c of
               SOME d =>
                 let val next = SOME(v*r+d) handle Overflow => NONE
                 in case next of SOME w => small(rest,w)
                    | NONE =>
                        let val (a,n) = unpack(smallMag v)
                            val (a,_) = scale((a,n),r)
                            fun add(i,c) = if c = 0 then ()
                              else let val t = at(a,i)+c
                                   in put(a,i,t mod base); add(i+1,t div base) end
                            val () = add(0,d)
                            val (_,n) = trim(a,n+1)
                        in big(rest,a,n) end
                 end
             | NONE => (S(if neg then ~v else v),src))
        | NONE => (S(if neg then ~v else v),src)
    in if digitNext src then SOME(small(src,0)) else NONE end
  fun fromString s = StringCvt.scanString (scan StringCvt.DEC) s

  val wordAnd = _prim "word_andb" : word * word -> word
  val wordOr = _prim "word_orb" : word * word -> word
  val wordXor = _prim "word_xorb" : word * word -> word
  val wordFromInt = _prim "word_from_int" : limb -> word
  val wordToInt = _prim "word_to_int" : word -> limb
  val wordToIntX = _prim "word_to_int_x" : word -> limb
  fun twosMagnitude (x,neg) =
    let val (a,n) = unpack(magnitude x)
        fun borrow i = if at(a,i) = 0 then (put(a,i,mask); borrow(i+1))
                       else put(a,i,at(a,i)-1)
        val () = if neg then borrow 0 else ()
    in if neg then trim(a,n) else (a,n) end
  fun bitwiseBig (code,f,signOf,a,b) =
    if gmpAvailable() then make(gmpBinary(code,negative a,magnitude a,negative b,magnitude b))
    else let val na = negative a and nb = negative b
        val (ma,la) = twosMagnitude(a,na)
        val (mb,lb) = twosMagnitude(b,nb)
        val n = if la > lb then la else lb
        val neg = signOf(na,nb)
        val out = if la >= lb then ma else mb
        fun get(s,len,negative,i) =
          let val b = if i < len then at(s,i) else 0
          in if negative then mask-b else b end
        fun loop(i,c) = if i = n then c
          else let val v = wordToInt(f(wordFromInt(get(ma,la,na,i)),wordFromInt(get(mb,lb,nb,i))))
                   val v = (if neg then mask-v else v)+c
               in if v >= base then (put(out,i,0); loop(i+1,1))
                  else (put(out,i,v); loop(i+1,0)) end
        val carry = loop(0,if neg then 1 else 0)
    in finish(neg,carryDigits(out,n,carry)) end
  (* Positive OR/XOR with a small operand cannot change the large value's
     top bit. Copy the unchanged high bytes and visit only the low ones. *)
  fun bitPositive (f,s,x) =
    let val () = checkMag s
    in if x = 0 then B(false,s)
       else let val n = strSize s
                val out = RuneBytes.new(n,0)
                val () = RuneBytes.blitString(s,0,out,0,n)
                fun loop(i,v) = if v = 0 then ()
                  else (bput(out,i,wordToInt(f(wordFromInt(byte(s,i)),wordFromInt(v mod 256))));
                        loop(i+1,v div 256))
                val () = loop(0,x)
            in B(false,RuneBytes.extract(out,0,n)) end
    end
  fun bitPositiveLarge (code,f,sa,sb) =
    let val () = checkMag sa
        val () = checkMag sb
    in if gmpAvailable() then make(gmpBinary(code,false,sa,false,sb))
       else let val (a,na) = unpack sa and (b,nb) = unpack sb
                val common = if na < nb then na else nb
                val out = if na >= nb then a else b
                val n = if code = 3 then common else if na >= nb then na else nb
                fun loop i = if i = common then ()
                  else (put(out,i,wordToInt(f(wordFromInt(at(a,i)),wordFromInt(at(b,i)))));
                        loop(i+1))
                val () = loop 0
            in finish(false,(out,n)) end
    end
  fun bitwise (code,f,signOf) (a,b) =
    case a of
      S x => (case b of
                S y => S(wordToIntX(f(wordFromInt x,wordFromInt y)))
              | B (neg,s) => if code <> 3 andalso not neg andalso x >= 0
                  then bitPositive(f,s,x) else bitwiseBig(code,f,signOf,a,b))
    | B (neg,s) => (case b of
                S x => if code <> 3 andalso not neg andalso x >= 0
                  then bitPositive(f,s,x) else bitwiseBig(code,f,signOf,a,b)
              | B (nb,mb) => if not neg andalso not nb
                  then bitPositiveLarge(code,f,s,mb)
                  else bitwiseBig(code,f,signOf,a,b))
  val andb = bitwise(3,wordAnd,fn(a,b)=>a andalso b)
  val orb = bitwise(4,wordOr,fn(a,b)=>a orelse b)
  val xorb = bitwise(5,wordXor,fn(a,b)=>a <> b)
  fun notb x = subI(negI x,one)
  fun << (x,w) =
    if w = 0w0 then x
    else if isZero x then zero
    else let val s = magnitude x
             val available = maxBits()-magBits s
             val wordGreater = _prim "word_gt" : word * word -> bool
             val () = if wordGreater(w,wordFromInt available) then checkBits(maxBits()+1) else ()
             val k = wordToInt w
             val n = strSize s
             val whole = k div 8 and bits = k mod 8
             val factor = pow2 bits
             fun smlShift () =
             let val out = RuneBytes.new(n+whole+1,0)
             fun loop(i,c) = if i = n then
                 (bput(out,i+whole,c); if c = 0 then n+whole else n+whole+1)
               else let val v = byte(s,i)*factor+c
                    in bput(out,i+whole,v mod 256); loop(i+1,v div 256) end
             val used = if bits = 0 then
                 (RuneBytes.blitString(s,0,out,whole,n); n+whole)
               else loop(0,0)
             in make(negative x,RuneBytes.extract(out,0,used)) end
         in if gmpAvailable() then make(gmpShift(true,negative x,s,w)) else smlShift() end
  fun ~>> (x,w) =
    if w = 0w0 then x
    else if isZero x then zero
    else if gmpAvailable() then make(gmpShift(false,negative x,magnitude x,w))
    else let val k = wordToInt w handle Overflow => ~1
        val neg = negative x
        val m = magnitude x
        fun shifted () =
          if k < 0 orelse k >= magBits m then if neg then S (~1) else zero
          else let val (digits,n) = unpack m
                   val whole = k div limbBits and bits = k mod limbBits
                   val factor = pow2 bits
                   val highFactor = base div factor
                   fun discarded i = if i = whole then at(digits,i) mod factor <> 0
                                     else at(digits,i) <> 0 orelse discarded(i+1)
                   val roundUp = neg andalso discarded 0
                   fun loop i = if i = n-whole then ()
                     else let val low = at(digits,i+whole) div factor
                              val high = if i+whole+1 < n then at(digits,i+whole+1) mod factor else 0
                          in put(digits,i,low+high*highFactor); loop(i+1) end
                   val () = loop 0
                   fun increment i = if i = n-whole then 1
                     else if at(digits,i) = mask then (put(digits,i,0); increment(i+1))
                     else (put(digits,i,at(digits,i)+1); 0)
                   val carry = if roundUp then increment 0 else 0
               in finish(neg,carryDigits(digits,n-whole,carry)) end
    in shifted() end

  val precision : limb option = NONE
  val minInt : int option = NONE
  val maxInt : int option = NONE
  val toLarge = fn (x : int) => x
  val fromLarge = fn (x : int) => x
  val op + = addI
  val op - = subI
  val op * = mulI
  val ~ = negI
  val abs = absI
  val quotRem = quotRemI
  val divMod = divModI
  val quot = fn (a,b) => #1(quotRemI(a,b))
  val rem = fn (a,b) => #2(quotRemI(a,b))
  val op div = fn (a,b) => #1(divModI(a,b))
  val op mod = fn (a,b) => #2(divModI(a,b))
  val op < = fn (a,b) => compare(a,b) = LESS
  val op <= = fn (a,b) => compare(a,b) <> GREATER
  val op > = fn (a,b) => compare(a,b) = GREATER
  val op >= = fn (a,b) => compare(a,b) <> LESS
  fun min (a,b) = if compare(a,b) = GREATER then b else a
  fun max (a,b) = if compare(a,b) = LESS then b else a
  fun sameSign (a,b) = sign a = sign b
end

(* The largest integers are the arbitrary precision ones.

   Implements: INTEGER where type int = IntInf.int *)
structure LargeInt = IntInf

(* Integer constants and overloaded operators at IntInf.int. *)
structure RuneIntInf =
struct
  fun fromLit (digits : string) : IntInf.int =
    case IntInf.fromString digits of
      SOME i => i
    | NONE => raise Fail "RuneIntInf.fromLit"
end

_overload int IntInf via RuneIntInf.fromLit
