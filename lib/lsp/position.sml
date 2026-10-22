(* LSP coordinate conversion over immutable UTF-8 text.

   Implements: LSP_POSITION *)
structure LspPosition :> LSP_POSITION =
struct
  structure P=LspProtocol
  type point={byte:int,utf16:int,utf32:int}
  type line={start:int,stop:int,points:point vector}
  datatype t=Text of {text:string,lines:line vector}
  exception Invalid
  exception Limit
  val zero : point={byte=0,utf16=0,utf32=0}
  val zeroPoints=Vector.fromList [zero]
  fun bounded {text,maxLines} =
    let val ()=if maxLines<1 then raise Domain else ()
        val length=size text
        fun finish (start,stop,points) : line = {start=start,stop=stop,points=case points of [_] => zeroPoints | _ => Vector.fromList (List.rev points)}
        fun scan (at,start,u16,u32,points,lines,lineCount) =
          if at=length then Text {text=text,lines=Vector.fromList (List.rev (finish (start,at,points) :: lines))}
          else if String.sub (text,at)= #"\r" orelse String.sub (text,at)= #"\n" then
            let val ()=if lineCount>=maxLines then raise Limit else ()
                val next=if String.sub (text,at)= #"\r" andalso at+1<length andalso String.sub (text,at+1)= #"\n" then at+2 else at+1
            in scan (next,next,0,0,[zero],finish (start,at,points) :: lines,lineCount+1) end
          else case Utf8.decode (text,at) of NONE => raise Invalid
          | SOME (scalar,bytes) =>
              let val next=at+bytes
                  val u16=u16+(if scalar>0xFFFF then 2 else 1)
                  val u32=u32+1
                  val points=if u32 mod 64=0 then {byte=next-start,utf16=u16,utf32=u32} :: points else points
              in scan (next,start,u16,u32,points,lines,lineCount) end
    in scan (0,0,0,0,[zero],[],1) end
  fun make text=bounded {text=text,maxLines=Vector.maxLen}
  fun text (Text {text,...})=text
  fun lineCount (Text {lines,...})=Vector.length lines
  fun units P.Utf8 ({byte,...}:point)=byte
    | units P.Utf16 ({utf16,...}:point)=utf16
    | units P.Utf32 ({utf32,...}:point)=utf32
  fun prior (points:point vector,measure,target) =
    let fun search (low,high) = if low+1>=high then Vector.sub (points,low)
          else let val mid=low+(high-low) div 2
               in if measure (Vector.sub (points,mid))<=target then search (mid,high) else search (low,mid) end
    in search (0,Vector.length points) end
  fun valid n = IntInf.>= (n,0) andalso IntInf.<= (n,P.maxInteger)
  fun offset (Text {text,lines},encoding,{line,character}:P.position) =
    if not (valid line andalso valid character) then NONE
    else if IntInf.>= (line,IntInf.fromInt (Vector.length lines)) then SOME (size text)
    else
      let val {start,stop,points}=Vector.sub (lines,IntInf.toInt line)
          val target=if IntInf.> (character,IntInf.fromInt (stop-start)) then stop-start else IntInf.toInt character
          val point=prior (points,units encoding,target)
          fun scan (at,count) =
            if at=stop then SOME stop else if count=target then SOME at
            else case Utf8.decode (text,at) of NONE => NONE | SOME (scalar,bytes) =>
              let val step=case encoding of P.Utf8 => bytes | P.Utf16 => if scalar>0xFFFF then 2 else 1 | P.Utf32 => 1
              in if count+step>target then NONE else scan (at+bytes,count+step) end
      in scan (start+ #byte point,units encoding point) end
  fun position (Text {text,lines},encoding,offset) =
    if offset<0 orelse offset>size text then NONE else
      let fun search (low,high) = if low+1>=high then low
            else let val mid=low+(high-low) div 2
                 in if #start (Vector.sub (lines,mid))<=offset then search (mid,high) else search (low,mid) end
          val line=search (0,Vector.length lines)
          val {start,stop,points}=Vector.sub (lines,line)
          val offset=Int.min (offset,stop)
          val point=prior (points,fn p:point => #byte p,offset-start)
          fun scan (at,count) = if at=offset then SOME {line=IntInf.fromInt line,character=IntInf.fromInt count}
            else case Utf8.decode (text,at) of NONE => NONE | SOME (scalar,bytes) =>
              if at+bytes>offset then NONE else
              scan (at+bytes,count+(case encoding of P.Utf8 => bytes | P.Utf16 => if scalar>0xFFFF then 2 else 1 | P.Utf32 => 1))
      in scan (start+ #byte point,units encoding point) end
  (* Keep sparse scalar checkpoints through edits within one line. The
     greedy thinning keeps gaps bounded without rescanning unchanged text. *)
  fun editLine (Text {text=old,lines},lineNo,a,b,inserted) =
    let val {start,stop,points}=Vector.sub (lines,lineNo)
        fun pointAt at =
          let val p=prior (points,fn p:point => #byte p,at-start)
              fun scan (byte,u16,u32) = if byte=at then {byte=byte-start,utf16=u16,utf32=u32}:point
                else case Utf8.decode (old,byte) of NONE => raise Invalid
                 | SOME (scalar,width) => scan (byte+width,u16+(if scalar>0xFFFF then 2 else 1),u32+1)
          in scan (start+ #byte p,#utf16 p,#utf32 p) end
        val left=pointAt a
        val right=pointAt b
        fun scanInsert (byte,u16,u32,count,acc) =
          if byte=size inserted then
            let val last={byte=a-start+byte,utf16=u16,utf32=u32}:point
            in (List.rev (last :: acc),last) end
          else case Utf8.decode (inserted,byte) of NONE => raise Invalid
            | SOME (scalar,width) =>
                let val next=byte+width
                    val u16=u16+(if scalar>0xFFFF then 2 else 1)
                    val u32=u32+1
                    val count=count+1
                    val acc=if count mod 64=0 then {byte=a-start+next,utf16=u16,utf32=u32} :: acc else acc
                in scanInsert (next,u16,u32,count,acc) end
        val (middle,last)=scanInsert (0,#utf16 left,#utf32 left,0,[left])
        val db=size inserted-(b-a)
        val d16= #utf16 last- #utf16 right
        val d32= #utf32 last- #utf32 right
        val prefix=Vector.foldr (fn (p:point,acc) => if #byte p<=a-start then p :: acc else acc) [] points
        val suffix=Vector.foldr (fn (p:point,acc) => if #byte p<=b-start then acc else
          (if db=0 andalso d16=0 andalso d32=0 then p else
            {byte= #byte p+db,utf16= #utf16 p+d16,utf32= #utf32 p+d32}) :: acc) [] points
        fun thin []=[]
          | thin (first::rest) =
              let fun loop (kept:point,candidate:point,[],acc) =
                        List.rev (if #byte candidate= #byte kept then acc else candidate :: acc)
                    | loop (kept,candidate,p::rest,acc) =
                        if #byte p<= #byte candidate then loop (kept,candidate,rest,acc)
                        else if #utf32 p- #utf32 kept<=64 then loop (kept,p,rest,acc)
                        else loop (candidate,candidate,p::rest,candidate :: acc)
              in loop (first,first,rest,[first]) end
        val changed:line={start=start,stop=stop+db,points=Vector.fromList (thin (prefix @ middle @ suffix))}
        fun shift ({start,stop,points}:line):line={start=start+db,stop=stop+db,points=points}
        val lines=Vector.tabulate (Vector.length lines,fn i =>
          if i<lineNo then Vector.sub (lines,i) else if i=lineNo then changed
          else if db=0 then Vector.sub (lines,i) else shift (Vector.sub (lines,i)))
    in Text {text=String.substring (old,0,a) ^ inserted ^ String.extract (old,b,NONE),lines=lines} end

  fun editBounded {document=Text {text=old,lines},start=a,stop=b,text=inserted,maxLines} =
    let val ()=if maxLines<1 then raise Domain else ()
        val count=Vector.length lines
        val sizeOld=size old
        fun boundary at=at=sizeOld orelse isSome (Utf8.decode (old,at))
        val ()=if a>=0 andalso a<=b andalso b<=sizeOld andalso boundary a andalso boundary b andalso Utf8.isValid inserted
          then () else raise Invalid
        fun lineIndex offset =
          let fun search (low,high) = if low+1>=high then low
                else let val mid=low+(high-low) div 2
                     in if #start (Vector.sub (lines,mid))<=offset then search (mid,high) else search (low,mid) end
          in search (0,count) end
        val leftLine=lineIndex a
        val rightLine=lineIndex b
        val joinsCRLF=inserted="" andalso a>0 andalso b<sizeOld andalso
          String.sub (old,a-1)= #"\r" andalso String.sub (old,b)= #"\n"
    in if leftLine=rightLine andalso not joinsCRLF andalso b<= #stop (Vector.sub (lines,leftLine)) andalso
          not (CharVector.exists (fn c => c = #"\r" orelse c = #"\n") inserted)
       then if count>maxLines then raise Limit else
         editLine (Text {text=old,lines=lines},leftLine,a,b,inserted)
       else let
        val first=Int.max (0,lineIndex a-1)
        val last=Int.min (count-1,lineIndex b+1)
        val from= #start (Vector.sub (lines,first))
        val hasSuffix=last+1<count
        val to=if hasSuffix then #start (Vector.sub (lines,last+1)) else sizeOld
        val region=String.substring (old,from,a-from) ^ inserted ^ String.substring (old,b,to-b)
        val allowance=maxLines-first-(count-last-1)
        val ()=if allowance<1 then raise Limit else ()
        val Text {lines=regionLines,...}=bounded {text=region,maxLines=allowance+(if hasSuffix then 1 else 0)}
        val kept=Vector.length regionLines-(if hasSuffix then 1 else 0)
        fun shifted delta ({start,stop,points}:line) : line={start=start+delta,stop=stop+delta,points=points}
        val prefix=Vector.tabulate (first,fn i => Vector.sub (lines,i))
        val replacement=Vector.tabulate (kept,fn i => shifted from (Vector.sub (regionLines,i)))
        val delta=size inserted-(b-a)
        val suffix=Vector.tabulate (count-last-1,fn i =>
          let val line=Vector.sub (lines,last+1+i) in if delta=0 then line else shifted delta line end)
        val text=String.substring (old,0,a) ^ inserted ^ String.extract (old,b,NONE)
    in Text {text=text,lines=Vector.concat [prefix,replacement,suffix]} end end

  fun edit (document,start,stop,text)=
    editBounded {document=document,start=start,stop=stop,text=text,maxLines=Vector.maxLen}

end
