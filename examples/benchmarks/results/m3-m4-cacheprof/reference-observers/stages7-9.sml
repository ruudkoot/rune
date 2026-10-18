 datatype possiblyString=Stated of string|Guessed of string
 fun isGuessed(Guessed _)=true|isGuessed _=false
 fun getString(Stated s)=s|getString(Guessed s)=s
 fun deQuote text=String.implode(List.filter(fn c=>c<> #"\"")(String.explode text))
 fun quoted text=String.size text>=2 andalso String.sub(text,0)= #"\""andalso String.sub(text,String.size text-1)= #"\""
 fun splitArgs text=
   let fun zap [] _=[]
         |zap(c::rest)inside=if c= #"\""then c::zap rest(not inside)
             else(if inside andalso c= #","then #"_"else c)::zap rest inside
       fun split []=[]
         |split chars=let val(first,tail)=span(fn c=>c<> #",")chars
                      in first::split(case tail of[]=>[]|_::rest=>rest)end
   in split(zap(String.explode text)false)end
 fun addCCs lines=
   let fun worker file lineNo func lines=F.defer(fn()=>case view lines of NONE=>F.empty()
         |SOME(line,rest)=>
           let fun next file lineNo func line=emit[line](worker file lineNo func rest)
               fun unchanged()=next file lineNo func line
               fun sourceInt text=case Int.fromString text of SOME n=>n|NONE=>inputerr"invalid source line number"
           in case line of Real(n,_,insn)=>
                if hasRealAnns insn then next file lineNo func(Real(n,CC(getString file,lineNo,getString func),insn))else unchanged()
            |Label(_,s)=>let val cleaned=trim s
                        in if isGuessed func andalso takeString 2 cleaned<>".L"then
                              next file lineNo(Guessed(takeString(String.size cleaned-1)cleaned))line
                           else unchanged()end
            |Pseudo(_,s)=>
              (case String.tokens Char.isSpace(trim s)of
                 ".stabn"::args::_=>(case splitArgs args of"68"::_::ln::_=>next file(sourceInt ln)func line|_=>unchanged())
                |".stabs"::args::_=>
                   (case splitArgs args of filename::"100"::_=>
                       if String.size filename>0 andalso String.sub(filename,String.size filename-1)<> #"/"
                       then next(Stated(deQuote filename))lineNo func line else unchanged()
                    |filename::"132"::_=>next(Stated(deQuote filename))lineNo func line
                    |function::"36"::_=>if deQuote function=""then unchanged()
                       else let val(name,_)=span(fn c=>c<> #":")(String.explode function)
                            in next file lineNo(Stated(deQuote name))line end
                    |_=>unchanged())
                |[".file",filename]=>if isGuessed file andalso quoted filename
                                     then next(Guessed(deQuote filename))lineNo func line else unchanged()
                |_=>unchanged())end)
   in worker(Guessed"_unknown_file_")0(Guessed"_unknown_function_")lines end
 fun decimal n=let val text=Int.toString n in if String.isPrefix"~"text then"-"^dropString 1 text else text end
 fun showString text="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"| #"\t"=>"\\t"| #"\r"=>"\\r"|c=>String.str c)text^"\""
 fun showCC NoCC="NoCC"
   |showCC(CC(file,n,func))="CC "^showString file^" "^(if n<0 then paren(decimal n)else decimal n)^" "^showString func
 fun showPoint(a,b,c)="("^decimal a^","^decimal b^","^decimal c^")"
 fun unique []=[]|unique(x::xs)=x::unique(List.filter(fn y=>y<>x)xs)
 fun indexOf xs wanted=
   let fun loop _ []=internal"indexOf"
         |loop n(x::rest)=if x=wanted then n else loop(n+1)rest
   in loop 0 xs end
 type descriptors={debug:string list D.t,files:string list,functions:string list,points:(int*int*int)list}
 fun makeCCdescriptors all=
   let val ccs=List.filter(not o isNoCC)all
       fun file(CC(name,_,_))=name|file _=internal"cc file"
       fun func(CC(_,_,name))=name|func _=internal"cc function"
       fun number(CC(_,n,_))=n|number _=internal"cc line"
       val files=unique(List.map file ccs)
       fun canonicalise []=[]
         |canonicalise((name,file)::rest)=(name,name^"("^file^")")::canonicalise(List.filter(fn(other,_)=>other<>name)rest)
       val canonical=canonicalise(List.map(fn cc=>(func cc,file cc))ccs)
       val fnKeys=List.map #1 canonical
       val functions=List.map #2 canonical
       val points=List.map(fn cc=>(indexOf files(file cc),number cc,indexOf fnKeys(func cc)))ccs
       val debug=D.delay(fn()=>["file names:"]@List.map(fn s=>"   "^s)files
           @["canonicalised function names:"]@List.map(fn s=>"   "^s)functions
           @["raw source points:"]@List.map(fn cc=>"   "^showCC cc)ccs
           @["cooked source points:"]@List.map(fn point=>"   "^showPoint point)points)
   in {debug=debug,files=files,functions=functions,points=points}:descriptors end
 val tableStart="cacheprof_magic_table"
 val bucketsStart="cacheprof_magic_buckets"
 fun useCCdescriptors({debug,files,functions,points}:descriptors)=F.defer(fn()=>
   let fun comment s="\t# "^s
       fun word n="\t.long "^decimal n
       fun byte n="\t.byte "^decimal n
       fun string s=comment(showString s)::List.map(fn c=>byte(Char.ord c))(String.explode s)@[byte 0]
       fun point(p as(a,b,c))=comment(showPoint p)::List.map word[a,b,c,0,0,0,0]
       val result=List.map comment["","---- start of the cost centers ----"]
          @List.map comment(D.force debug)@["\t.data","\t.align 4",archLabelDef tableStart]
          @[comment"number of filenames, funcnames, points, cc addr"]
          @List.map word[List.length files,List.length functions,List.length points]
          @["\t.long "^archLabelUse bucketsStart]
          @List.concat(List.map string(files@functions))
          @["\t.align 4",archLabelDef bucketsStart]
          @List.concat(List.map point points)
          @List.map comment["","---- end of the cost centers ----"]
   in F.fromList(List.map(fn text=>Pseudo(0,text))result)end)
 fun insnPush reg=Insn(SomeAnns[AnnC"save"],O_pushl,[OP_REG reg])
 fun insnPop reg=Insn(SomeAnns[AnnC"rest"],O_popl,[OP_REG reg])
 val standardPreamble=[insnPush EAX,insnPush EBX]
 val standardPostamble=[insnPop EBX,insnPop EAX]
 fun bucketAddress ccid=OP_D(Const[Pos(UF_LABEL("$"^archLabelUse bucketsStart)),Pos(UF_NUM(decimal(28*ccid)))])
 fun useAnnot ccid annotation=
   let val(kind,size,operand)=case annotation of AnnR(s,o')=>("rd",s,o')
         |AnnM(s,o')=>("mo",s,o')|AnnW(s,o')=>("wr",s,o')|AnnC _=>internal"useAnnot on comment annotation"
       val hook=case kind of"rd"=>"Rd"|"mo"=>"Mo"|_=>"Wr"
       fun instruction comment opcode operands=Insn(SomeAnns[AnnC comment],opcode,operands)
   in standardPreamble@[
       instruction(kind^"-1")O_leal[operand,OP_REG EAX],
       instruction(kind^"-2")O_movl[bucketAddress ccid,OP_REG EBX],
       instruction(kind^"-3")O_call[OP_D(Const[Pos(UF_NAME("cacheprof_hook_"^hook^decimal size))])]]
      @standardPostamble end
 fun synthInstructions ccid(insn as Insn(annotations,_,_))=List.concat(List.map(useAnnot ccid)(getAnns annotations))@[insn]
 fun synthLine nextcc(line as Pseudo _)=(nextcc,F.fromList[line])
   |synthLine nextcc(line as Label _)=(nextcc,F.fromList[line])
   |synthLine nextcc(line as Real(n,cc,insn))=
      if hasRealAnns insn then(nextcc+1,F.defer(fn()=>F.fromList(List.map(fn i=>Real(n,cc,i))(synthInstructions nextcc insn))))
      else(nextcc,F.fromList[line])
 fun synth2 lines=F.defer(fn()=>
   let val descriptors=makeCCdescriptors(List.map getCC(F.toList lines))
       fun walk next lines=case view lines of NONE=>(next,F.empty())
         |SOME(line,rest)=>
           let val(after,group)=synthLine next line
               val(last,groups)=walk after rest
           in(last,F.cons(D.delay(fn()=>group),groups))end
       val(used,groups)=walk 0 lines
       val _=if used=List.length(#points descriptors)then()else internal"doFile: cc supply/usage mismatch\n"
   in F.append(concat groups)(useCCdescriptors descriptors)end)
 fun useIncAnn(AnnW _)=incSequence 1"cacheprof_level1_writes"
   |useIncAnn(AnnR _)=incSequence 1"cacheprof_level1_reads"
   |useIncAnn(AnnM _)=incSequence 1"cacheprof_level1_reads"@incSequence 1"cacheprof_level1_writes"
   |useIncAnn _=internal"level1 comment annotation"
 fun synth1Line(line as Real(n,cc,insn as Insn(annotations,_,_)))=
      if hasRealAnns insn then List.map(fn i=>Real(n,cc,i))(List.concat(List.map useIncAnn(getAnns annotations)))@[line]
      else[line]
   |synth1Line line=[line]
 fun synth1 lines=concatMap(fn line=>F.defer(fn()=>F.fromList(synth1Line line)))lines
 fun incrementsCounter(Insn(_,O_addl,[OP_LIT(Const[Pos(UF_NUM _)]),OP_D(Const[Pos(UF_NAME first)])]))
       (Insn(_,O_adcl,[OP_LIT(Const[Pos(UF_NUM zero)]),OP_D(Const[Pos(UF_NUM four),Pos(UF_NAME second)])]))=
        takeString 10 first="cacheprof_"andalso takeString 10 second="cacheprof_"andalso zero="0"andalso four="4"
   |incrementsCounter _ _=false
 fun peephole lines=F.defer(fn()=>
   let fun fallback()=case view lines of NONE=>F.empty()|SOME(line,rest)=>emit[line](peephole rest)
       fun match()=case view lines of SOME(l1 as Real(_,_,i1),r1)=>
          (case view r1 of SOME(l2 as Real(_,_,i2),r2)=>
           (case view r2 of SOME(Real(_,_,Insn(_,O_popfl,[])),r3)=>
            (case view r3 of SOME(Real(_,_,Insn(_,O_pushfl,[])),r4)=>
             (case view r4 of SOME(l5 as Real(_,_,i5),r5)=>
              (case view r5 of SOME(l6 as Real(_,_,i6),tail)=>
                 if incrementsCounter i1 i2 andalso incrementsCounter i5 i6
                 then SOME(emit[l1,l2,l5,l6]tail)else NONE
               |_=>NONE)
              |_=>NONE)
             |_=>NONE)
            |_=>NONE)
           |_=>NONE)
          |_=>NONE
   in case match()of SOME shortened=>peephole shortened|NONE=>fallback()end)
 fun isStabLine(Pseudo(_,s))=takeString 5(trim s)=".stab"|isStabLine _=false
 fun finalCleanup lines=F.map(fn line=>ppLine line^"\n")(F.filter(not o isStabLine)lines)
 fun output level text=
   let val preparsed=preparse text
       val parsed=parse preparsed
       val simplified=simplify parsed
       val transformed=if level=0 then simplified
          else let val counted=useBBs(identifyBBs simplified)
                   val annotated=annotate counted
               in if level=1 then synth1 annotated
                  else if level=2 then synth2(addCCs annotated)else inputerr"profiling level"end
   in finalCleanup(peephole transformed)end
 fun rendered level text=String.concat(F.toList(output level text))
