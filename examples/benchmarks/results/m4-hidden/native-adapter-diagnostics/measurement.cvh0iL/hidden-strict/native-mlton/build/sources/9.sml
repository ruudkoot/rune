functor BenchHiddenDriverFn(structure K:sig
  type number
  type vector
  type edge
  structure N:sig val bits:real->Word32.word val value:number->real end
  datatype command=Move of number*number|Line of number*number|Flush
  val plot:edge BenchStream.stream->command BenchStream.stream
  val prepare:vector->vector BenchStream.stream BenchStream.stream->edge BenchStream.stream
end
structure Parser:sig
  val scene:string->K.vector BenchStream.stream BenchStream.stream
  val view:string->K.vector
end) =
struct
  structure W=Word64
  structure S=BenchStream
  structure L=BenchLazy
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun hash text=
    let fun loop i acc=if i=String.size text then acc else
          loop(i+1)(W.+(W.fromInt(Char.ord(String.sub(text,i))),W.*(acc,0w31)))
    in loop 0 0w0 end
  fun hashReference text=
    let fun loop i power acc=if i<0 then acc else
          loop(i-1)(W.*(power,0w31))
            (W.+(acc,W.*(power,W.fromInt(Char.ord(String.sub(text,i))))))
    in loop(String.size text-1)0w1 0w0 end
  fun word text=case IntInf.fromString text of
      SOME n=>if n>=0 andalso n<=4294967295 then Word32.fromLargeInt n
        else raise Fail "hidden reference word outside binary32"
    |NONE=>raise Fail "invalid hidden reference word"
  datatype expected=Point of string*Word32.word*Word32.word|Break
  fun reference text=List.map(fn row=>case String.tokens Char.isSpace row of
      ["F"]=>Break
    |[kind,x,y]=>if kind="M"orelse kind="L"then Point(kind,word x,word y)
       else raise Fail "invalid hidden reference command"
    |_=>raise Fail "invalid hidden reference row")
    (String.tokens(fn c=>c= #"\n")text)
  fun number n=
    let val value=K.N.value n
        val text=String.translate(fn #"~"=>"-"|c=>String.str c)
          (Real.fmt(StringCvt.GEN(SOME 9))value)
        val _=case Real.fromString text of SOME result=>
            if K.N.bits(BenchMandelSingle.round result)=K.N.bits value then()
            else raise Fail "incorrect result: hidden numeric rendering"
          |NONE=>raise Fail "incorrect result: hidden numeric rendering"
    in text end
  fun render values wanted=
    let
      fun point kind a b expected=
        case expected of Point(tag,x,y)::rest=>
          if tag=kind andalso K.N.bits(K.N.value a)=x andalso K.N.bits(K.N.value b)=y
          then(number a^" "^number b^(if kind="M"then" moveto "else" lineto "),rest)
          else raise Fail "incorrect result: hidden coordinate or command"
        |_=>raise Fail "incorrect result: missing hidden point reference"
      fun loop values expected parts count=case L.force values of
          S.Nil=>if List.null expected then
            (String.concat(List.rev("\nstroke grestore\n"::parts)),count)
            else raise Fail "incorrect result: missing hidden commands"
        |S.Cons(value,rest)=>
          let val(text,remaining,increment)=case L.force value of
              K.Move(a,b)=>let val(t,r)=point "M" a b expected in(t,r,0)end
            |K.Line(a,b)=>let val(t,r)=point "L" a b expected in(t,r,1)end
            |K.Flush=>(case expected of Break::tail=>("\nstroke newpath\n",tail,0)
                |_=>raise Fail "incorrect result: hidden path discontinuity")
          in loop rest remaining(text::parts)(count+increment)end
    in loop values wanted["\nerasepage gsave 100 100 translate 0 setlinewidth newpath\n"]0 end
  fun run[repeatText,path,view,referencePath]=
    let val repetitions=BenchInput.between(0,1000)(BenchInput.integer repeatText)
        val wanted=reference(read referencePath)
        fun loop 0 edges=Int.toString repetitions^":"^Int.toString edges
          |loop n edges=
            let val faces=Parser.scene(read path)
                val commands=K.plot(K.prepare(Parser.view view)faces)
                val(text,count)=render commands wanted
                val _=if hash text=hashReference text then()
                  else raise Fail "incorrect result: hidden text hash"
            in loop(n-1)(edges+count)end
    in loop repetitions 0 end
    |run _=raise Fail "hidden expects repetitions, scene, view and coordinate reference"
end
