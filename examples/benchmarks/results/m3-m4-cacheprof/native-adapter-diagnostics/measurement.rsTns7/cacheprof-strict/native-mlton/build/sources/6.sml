(*
   This file is part of Cacheprof, a profiling tool for finding
   sources of cache misses in programs.

   Copyright (C) 1999 Julian Seward (jseward@acm.org)
   Home page: http://www.cacheprof.org

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
   02111-1307, USA.

   The GNU General Public License is contained in the file LICENSE.
*)
(* The original Julian Seward/GPL2-or-later notice is prepended by the importer.
 * Finite stage streams follow D. Parsed instruction descriptors are strict,
 * matching the source forceLine boundary before simplification. *)
functor BenchCacheprofFn(D:BENCH_SUSPEND)=
struct
 structure A=BenchCacheprofArch
 open A
 structure F=BenchIdaFiniteFn(D)
 datatype preline=PrePseudo of int*string|PreLabel of int*string|PreReal of int*string
 datatype cc=NoCC|CC of string*int*string
 datatype reg=EAX|EBX|ECX|EDX|EDI|ESI|EBP|ESP|AX|BX|CX|DX|SI|DI|BP
   |AL|BL|CL|DL|AH|BH|CH|DH|ST_0|ST_1|ST_2|ST_3|ST_4|ST_5|ST_6|ST_7
 datatype amode=AM_B of reg|AM_BI of reg*reg|AM_IS of reg*string|AM_BIS of reg*reg*string
 datatype unsigned=UF_NUM of string|UF_NAME of string|UF_LABEL of string|UF_TIMES of unsigned*unsigned
 datatype signed=Neg of unsigned|Pos of unsigned
 datatype constant=Const of signed list
 datatype operand=OP_REG of reg|OP_LIT of constant|OP_D of constant|OP_DA of constant*amode
   |OP_A of amode|OP_STAR of operand
 datatype annot=AnnR of int*operand|AnnM of int*operand|AnnW of int*operand|AnnC of string
 datatype annotations=DontAnnMe|SomeAnns of annot list
 datatype insn=Insn of annotations*opcode*operand list
 datatype line=Pseudo of int*string|Label of int*string|Real of int*cc*insn
 datatype bb=BB of line F.seq
 datatype token=LReg of string|LNum of string|LName of string|LLabel of string
   |LComma|LLParen|LRParen|LPlus|LMinus|LStar|LDollar
 datatype 'a parseResult=PFail|POk of 'a*token list
 fun internal text=raise Fail("\ncacheann: Internal error: "^text^"\n")
 fun incomplete text=raise Fail("\ncacheann: Unhandled instruction set artefact:\n   "^text^"\n")
 fun inputerr text=raise Fail("\ncacheann: Bad input: "^text^"\n")
 fun member x xs=List.exists(fn y=>x=y)xs
 fun concat xss=D.delay(fn()=>case D.force xss of F.Nil=>F.Nil
   |F.Cons(xs,rest)=>D.force(F.append(D.force xs)(concat rest)))
 fun concatMap f xs=concat(F.map f xs)
 fun emit values rest=F.append(F.fromList values)rest
 fun view xs=case D.force xs of F.Nil=>NONE|F.Cons(x,rest)=>SOME(D.force x,rest)
 fun trim text=String.extract(text,
   let fun loop i=if i<String.size text andalso Char.isSpace(String.sub(text,i))then loop(i+1)else i in loop 0 end,NONE)
 fun takeString n text=String.substring(text,0,Int.min(Int.max(0,n),String.size text))
 fun dropString n text=String.extract(text,Int.min(Int.max(0,n),String.size text),NONE)
 fun span test chars=
   let fun loop [] out=(String.implode(List.rev out),[])
         |loop(all as c::rest)out=if test c then loop rest(c::out)else(String.implode(List.rev out),all)
   in loop chars[]end
 fun isLabelIsh c=Char.isAlphaNum c orelse c= #"."orelse c= #"_"
 fun isNameIsh c=Char.isAlphaNum c orelse c= #"_"orelse c= #"."
 fun isDigitish c=Char.isDigit c orelse Char.contains"xabcdefABCDEF"c
 fun preparseLine(number,text)=
   let val cleaned=trim text
       val(label,rest)=span isLabelIsh(String.explode cleaned)
       val looks=String.size label>0 andalso(case rest of #":"::[]=>true| #":"::c::_=>Char.isSpace c|_=>false)
   in if cleaned=""then[]
      else if looks then PreLabel(number,label^":")::preparseLine(number,String.implode(List.tl rest))
      else if Char.contains".#"(String.sub(cleaned,0))then[PrePseudo(number,text)]
      else let val(beforeSemi,afterSemi)=span(fn c=>c<> #";")(String.explode cleaned)
           in PreReal(number,beforeSemi)::preparseLine(number,String.implode(case afterSemi of []=>[]|_::xs=>xs))end end
 fun sourceLines text=
   let val lines=String.fields(fn c=>c= #"\n")text
   in if String.size text>0 andalso String.sub(text,String.size text-1)= #"\n"then List.take(lines,List.length lines-1)
      else if text=""then[]else lines end
 fun preparse text=
   let fun loop _ []=F.empty()
         |loop n(line::rest)=F.defer(fn()=>emit(preparseLine(n,line))(loop(n+1)rest))
   in loop 1(sourceLines text)end
 val regMap=[("%eax",EAX),("%ebx",EBX),("%ecx",ECX),("%edx",EDX),("%edi",EDI),("%esi",ESI),("%ebp",EBP),("%esp",ESP),
   ("%ax",AX),("%bx",BX),("%cx",CX),("%dx",DX),("%si",SI),("%di",DI),("%bp",BP),
   ("%al",AL),("%bl",BL),("%cl",CL),("%dl",DL),("%ah",AH),("%bh",BH),("%ch",CH),("%dh",DH),
   ("%st",ST_0),("%st(0)",ST_0),("%st(1)",ST_1),("%st(2)",ST_2),("%st(3)",ST_3),("%st(4)",ST_4),("%st(5)",ST_5),("%st(6)",ST_6),("%st(7)",ST_7)]
 fun register name=case List.find(fn(key,_)=>key=name)regMap of SOME(_,r)=>r|NONE=>incomplete("findReg: '"^name^"'")
 fun olex text=
   let fun barf cs=inputerr("lexical error on: '"^String.implode cs^"'")
       fun lex []=[]
         |lex(all as c::rest)=
          if Char.isSpace c then lex rest
          else case c of #"("=>LLParen::lex rest| #")"=>LRParen::lex rest| #","=>LComma::lex rest
           | #"+"=>LPlus::lex rest| #"-"=>LMinus::lex rest| #"*"=>LStar::lex rest
           | #"$"=>LDollar::lex rest| #"#"=>[]
           | #"%"=>
              let val(name,tail)=span Char.isAlpha rest val full="%"^name
              in if name="st"andalso(case tail of #"("::_=>true|_=>false)then
                   let val(suffix,last)=span(Char.contains"(01234567)")tail in LReg(full^suffix)::lex last end
                 else if List.exists(fn(key,_)=>key=full)regMap then LReg full::lex tail else barf all end
           |_=>if Char.isDigit c then let val(n,tail)=span isDigitish rest in LNum(String.str c^n)::lex tail end
               else if Char.isAlpha c orelse c= #"_"then let val(n,tail)=span isNameIsh rest in LName(String.str c^n)::lex tail end
               else if c= #"."then let val(n,tail)=span isLabelIsh rest in LLabel("."^n)::lex tail end
               else barf all
   in lex(String.explode text)end
 fun pEmpty x ts=POk(x,ts)
 fun pSat test []=PFail|pSat test(t::ts)=if test t then POk(t,ts)else PFail
 fun pApply f p ts=case p ts of PFail=>PFail|POk(x,rest)=>POk(f x,rest)
 fun pName word value(LName name::rest)=if word=name then POk(value,rest)else PFail
   |pName _ _ _=PFail
 fun p2 f p q ts=case p ts of PFail=>PFail|POk(x,rest)=>
   (case q rest of PFail=>PFail|POk(y,last)=>POk(f x y,last))
 fun p3 f p q r=p2(fn x=>fn(y,z)=>f x y z)p(p2(fn y=>fn z=>(y,z))q r)
 fun pStar p ts=case p ts of PFail=>POk([],ts)|POk(x,rest)=>
   (case pStar p rest of POk(xs,last)=>POk(x::xs,last)|PFail=>internal"pStar failed")
 fun pPlus p=p2(fn x=>fn xs=>x::xs)p(pStar p)
 fun pAlt p q ts=case p ts of PFail=>q ts|ok=>ok
 fun pAlts []=internal"empty parser alternatives"
   |pAlts(p::ps)=List.foldl(fn(q,p)=>pAlt p q)p ps
 fun pOpt p ts=case p ts of PFail=>POk(NONE,ts)|POk(x,rest)=>POk(SOME x,rest)
 fun punct token=pSat(fn t=>t=token)
 fun pInParens p=p3(fn _=>fn x=>fn _=>x)(punct LLParen)p(punct LRParen)
 fun pPreComma p=p2(fn _=>fn x=>x)(punct LComma)p
 fun pStarComma p=pAlts[
   p2(fn xs=>fn y=>xs@[y])(pPlus(p2(fn x=>fn _=>x)p(punct LComma)))p,
   pApply(fn x=>[x])p,pEmpty[]]
 fun pLNum ts=pApply(fn LNum x=>x|_=>internal"pLNum")(pSat(fn LNum _=>true|_=>false))ts
 fun pLReg ts=pApply(fn LReg x=>x|_=>internal"pLReg")(pSat(fn LReg _=>true|_=>false))ts
 fun pLName ts=pApply(fn LName x=>x|_=>internal"pLName")(pSat(fn LName _=>true|_=>false))ts
 fun pLLabel ts=pApply(fn LLabel x=>x|_=>internal"pLLabel")(pSat(fn LLabel _=>true|_=>false))ts
 fun pReg ts=pApply register pLReg ts
 fun pOpcode ts=pAlts(List.map(fn(opcode,_)=>pName(A.name opcode)opcode)x86info)ts
 fun pUnsignedA ts=pAlts[pApply UF_NUM pLNum,pApply UF_NAME pLName,pApply UF_LABEL pLLabel]ts
 fun pUnsignedF ts=pAlts[
   p3(fn x=>fn _=>fn y=>UF_TIMES(x,y))pUnsignedA(punct LStar)pUnsignedF,
   p3(fn _=>fn x=>fn _=>x)(punct LLParen)pUnsignedF(punct LRParen),pUnsignedA]ts
 fun pSignedF ts=pAlts[p2(fn _=>fn x=>Pos x)(punct LPlus)pUnsignedF,p2(fn _=>fn x=>Neg x)(punct LMinus)pUnsignedF]ts
 fun pConst ts=pAlts[
   p2(fn x=>fn xs=>Const(Pos x::xs))pUnsignedF(pStar pSignedF),
   p3(fn _=>fn x=>fn xs=>Const(Neg x::xs))(punct LMinus)pUnsignedF(pStar pSignedF)]ts
 fun pAMode ts=pInParens(pAlts[
   p3(fn a=>fn b=>fn c=>AM_BIS(a,b,c))pReg(pPreComma pReg)(pPreComma pLNum),
   p2(fn a=>fn b=>AM_BI(a,b))pReg(pPreComma pReg),
   p2(fn a=>fn b=>AM_IS(a,b))(pPreComma pReg)(pPreComma pLNum),
   pApply AM_B pReg])ts
 fun pOperand ts=pAlts[
   pApply OP_REG pReg,p2(fn _=>fn c=>OP_LIT c)(punct LDollar)pConst,
   p2(fn c=>fn a=>OP_DA(c,a))pConst pAMode,pApply OP_D pConst,pApply OP_A pAMode,
   p2(fn _=>fn operand=>OP_STAR operand)(punct LStar)pOperand]ts
 fun pInsn ts=p2(fn opcode=>fn operands=>Insn(SomeAnns[],opcode,operands))pOpcode(pStarComma pOperand)ts
 fun parse lines=F.map(fn PrePseudo(n,s)=>Pseudo(n,s)|PreLabel(n,s)=>Label(n,s)
   |PreReal(n,s)=>case pInsn(olex s)of POk(i,[])=>Real(n,NoCC,i)
       |_=>inputerr("(stdin):"^Int.toString n^": syntax error on '"^s^"'\n"))lines
 fun ppReg r=case List.find(fn(_,value)=>value=r)regMap of SOME(name,_)=>name|NONE=>internal"register printer"
 fun ppUnsigned(UF_NUM x)=x|ppUnsigned(UF_NAME x)=x|ppUnsigned(UF_LABEL x)=x
   |ppUnsigned(UF_TIMES(a,b))=ppUnsigned a^"*"^ppUnsigned b
 fun ppSigned(Neg x)="-"^ppUnsigned x|ppSigned(Pos x)="+"^ppUnsigned x
 fun ppConst(Const xs)=
   let val text=String.concat(List.map ppSigned xs)
       fun drop i=if i<String.size text andalso String.sub(text,i)= #"+"then drop(i+1)else String.extract(text,i,NONE)
   in drop 0 end
 fun paren text="("^text^")"
 fun ppAMode(AM_B r)=paren(ppReg r)
   |ppAMode(AM_BI(a,b))=paren(ppReg a^","^ppReg b)
   |ppAMode(AM_IS(r,n))=paren(","^ppReg r^","^n)
   |ppAMode(AM_BIS(a,b,n))=paren(ppReg a^","^ppReg b^","^n)
 fun ppOperand(OP_REG r)=ppReg r|ppOperand(OP_LIT c)="$"^ppConst c
   |ppOperand(OP_D c)=ppConst c|ppOperand(OP_A a)=ppAMode a
   |ppOperand(OP_DA(c,a))=ppConst c^ppAMode a|ppOperand(OP_STAR x)="*"^ppOperand x
 fun ppInsn(Insn(_,opcode,operands))=A.name opcode^(if List.null operands then""else" "^String.concatWith","(List.map ppOperand operands))
 fun ppLine(Pseudo(_,s))=s|ppLine(Label(_,s))=s|ppLine(Real(_,_,i))="\t"^ppInsn i
 fun getLineNo(Pseudo(n,_))=n|getLineNo(Label(n,_))=n|getLineNo(Real(n,_,_))=n
 fun isReal(Real _)=true|isReal _=false
 fun isPseudo(Pseudo _)=true|isPseudo _=false
 fun isOriginalInsn(Real(_,_,Insn(DontAnnMe,_,_)))=false
   |isOriginalInsn(Real(_,_,Insn(SomeAnns[],_,_)))=true
   |isOriginalInsn(Real _)=internal"isOriginalInsn"|isOriginalInsn _=false
 fun getAnns DontAnnMe=[]|getAnns(SomeAnns xs)=xs
 fun getCC(Real(_,cc,_))=cc|getCC _=NoCC
 fun isNoCC NoCC=true|isNoCC _=false
 fun hasRealAnns(Insn(anns,_,_))=List.exists(fn AnnC _=>false|_=>true)(getAnns anns)
 fun archLabelDef name=".L"^name^":"
 fun archLabelUse name=".L"^name
 fun constName name=Const[Pos(UF_NAME name)]
 fun constNumber n=Const[Pos(UF_NUM(Int.toString n))]
 fun incSequence k name=[
   Insn(DontAnnMe,O_pushfl,[]),
   Insn(DontAnnMe,O_addl,[OP_LIT(constNumber k),OP_D(constName name)]),
   Insn(DontAnnMe,O_adcl,[OP_LIT(constNumber 0),OP_D(Const[Pos(UF_NUM"4"),Pos(UF_NAME name)])]),
   Insn(DontAnnMe,O_popfl,[])]
 fun simplify lines=
   let fun worker lc lines=F.defer(fn()=>case view lines of NONE=>F.empty()
         |SOME(first,rest)=>
           let fun ordinary()=emit[first](worker lc rest)
           in case first of Real(ln,cc,Insn(SomeAnns[],O_leave,[]))=>
                emit[Real(ln,cc,Insn(SomeAnns[],O_movl,[OP_REG EBP,OP_REG ESP])),
                     Real(ln,cc,Insn(SomeAnns[],O_popl,[OP_REG EBP]))](worker lc rest)
            |Real(ln,cc,Insn(SomeAnns[],prefix,[]))=>
              if member prefix[O_rep,O_repz,O_repnz]then
               (case view rest of SOME(Real(_,_,Insn(SomeAnns[],operation,[])),tail)=>
                 let fun labelName n="cacheprof_x86_rep_expansion"^Int.toString n
                     fun insn opcode operands=Real(ln,cc,Insn(DontAnnMe,opcode,operands))
                     fun original opcode=Real(ln,cc,Insn(SomeAnns[],opcode,[]))
                     fun label n=Pseudo(n,archLabelDef(labelName n))
                     fun target n=OP_D(Const[Pos(UF_LABEL(archLabelUse(labelName n)))])
                 in if prefix=O_rep andalso member operation[O_movsl,O_movsw,O_movsb,O_stosl,O_stosw,O_stosb]then
                      emit[insn O_pushfl[],label lc,insn O_testl[OP_REG ECX,OP_REG ECX],
                        insn O_jz[target(lc+1)],insn O_decl[OP_REG ECX],original operation,
                        insn O_jmp[target lc],label(lc+1),insn O_popfl[]](worker(lc+2)tail)
                    else if member prefix[O_repz,O_repnz]andalso member operation[O_cmpsb,O_scasb]then
                      emit[label lc,insn O_pushfl[],insn O_testl[OP_REG ECX,OP_REG ECX],
                        insn O_jz[target(lc+1)],insn O_popfl[],original operation,insn O_pushfl[],
                        insn O_decl[OP_REG ECX],insn O_popfl[],
                        insn(if prefix=O_repnz then O_jz else O_jnz)[target(lc+2)],
                        insn O_jmp[target lc],label(lc+1),insn O_popfl[],label(lc+2)](worker(lc+3)tail)
                    else ordinary()end
                |_=>ordinary())
              else ordinary()
            |_=>ordinary()end)
   in worker 0 lines end
 fun identifyBBs lines=
   let val blocks=F.map(fn line=>BB(F.fromList[line]))lines
       fun merge blocks=F.defer(fn()=>case view blocks of NONE=>F.empty()
          |SOME(first as BB lines1,rest)=>case view rest of NONE=>F.fromList[first]
           |SOME(second as BB lines2,tail)=>
             let val line=F.nth lines2 0
                 fun join()=merge(emit[BB(F.append lines1(F.fromList[line]))]tail)
                 fun separate()=emit[first](merge rest)
             in if isPseudo line then join()
                else if isOriginalInsn line then
                  let val reals=F.toList(F.filter isReal lines1)
                  in if List.null reals then separate()
                     else let val last=List.last reals
                          in if isOriginalInsn last andalso
                              (case last of Real(_,_,Insn(_,opcode,_))=>member opcode nonJumpyOpcodes|_=>false)
                             then join()else separate()end end
                else separate()end)
   in merge blocks end
 fun useBB(BB lines)=F.defer(fn()=>
   let val n=F.length(F.filter isOriginalInsn lines)
       val first=F.nth lines 0
   in if n=0 then lines
      else emit(List.map(fn insn=>Real(getLineNo first,NoCC,insn))(incSequence n"cacheprof_icount"))lines end)
 fun useBBs blocks=concatMap useBB blocks
 val theEdi=OP_A(AM_B EDI)
 val theEsi=OP_A(AM_B ESI)
 val theSpPlus4=OP_DA(constNumber 4,AM_B ESP)
 val theSpPlus8=OP_DA(constNumber 8,AM_B ESP)
 fun annsFromEffects [] _=NONE
   |annsFromEffects(effect::rest)operands=
      let fun mismatch()=annsFromEffects rest operands
      in case(effect,operands)of
         (OE_RR(a,b),[x,y])=>SOME[AnnR(a,x),AnnR(b,y)]
        |(OE_RM(a,b),[x,y])=>SOME[AnnR(a,x),AnnM(b,y)]
        |(OE_RW(a,b),[x,y])=>SOME[AnnR(a,x),AnnW(b,y)]
        |(OE_R a,[x])=>SOME[AnnR(a,x)]
        |(OE_M a,[x])=>SOME[AnnM(a,x)]
        |(OE_W a,[x])=>SOME[AnnW(a,x)]
        |(OE_nW a,[_,y])=>SOME[AnnW(a,y)]
        |(OE_RRM(a,b,c),[x,y,z])=>SOME[AnnR(a,x),AnnR(b,y),AnnM(c,z)]
        |_=>mismatch()end
 fun annsOf opcode operands=
   let fun mismatch()=incomplete("operand info doesn't match operands: "^ppInsn(Insn(SomeAnns[],opcode,operands)))
   in case getOperandInfo opcode of
      OI effects=>(case annsFromEffects effects operands of SOME anns=>anns|NONE=>mismatch())
     |OI_Jumpy=>(case operands of[OP_STAR x]=>[AnnR(4,x)]|[_]=>[]|_=>mismatch())
     |OI_NoEffect=>[]
     |OI_Error=>internal("unsimplified opcode: "^A.name opcode)
     |OI_Special=>
       if opcode=O_pushl then(case operands of[x]=>[AnnR(4,x),AnnW(4,theSpPlus4)]|_=>mismatch())
       else if opcode=O_call then(case operands of[OP_STAR x]=>[AnnR(4,x),AnnW(4,theSpPlus4)]
          |[_]=>[AnnW(4,theSpPlus4)]|_=>mismatch())
       else if opcode=O_popl then(case operands of[x]=>[AnnR(4,theSpPlus8),AnnW(4,x)]|_=>mismatch())
       else if opcode=O_ret then[AnnR(4,theSpPlus8)]
       else if opcode=O_scasb then[AnnR(1,theEdi)]
       else if opcode=O_cmpsb then[AnnR(1,theEdi),AnnR(1,theEsi)]
       else if opcode=O_movsl then[AnnR(4,theEsi),AnnW(4,theEdi)]
       else if opcode=O_movsw then[AnnR(2,theEsi),AnnW(2,theEdi)]
       else if opcode=O_movsb then[AnnR(1,theEsi),AnnW(1,theEdi)]
       else if opcode=O_stosl then[AnnW(4,theEdi)]
       else if opcode=O_stosw then[AnnW(2,theEdi)]
       else if opcode=O_stosb then[AnnW(1,theEdi)]
       else incomplete("unclassifiable opcode: "^A.name opcode)end
 fun annOperand(AnnR(_,x))=x|annOperand(AnnM(_,x))=x|annOperand(AnnW(_,x))=x
   |annOperand _=internal"comment has no operand"
 fun isMemOp(OP_REG _)=false|isMemOp(OP_LIT _)=false|isMemOp(OP_D _)=true
   |isMemOp(OP_DA _)=true|isMemOp(OP_A _)=true|isMemOp(OP_STAR _)=incomplete"isMemOp: not sure about *-form"
 fun annotateInsn(insn as Insn(DontAnnMe,_,_))=insn
   |annotateInsn(Insn(_,opcode,operands))=
      Insn(SomeAnns(List.filter(fn ann=>isMemOp(annOperand ann))(annsOf opcode operands)),opcode,operands)
 fun annotate lines=F.map(fn Real(n,cc,i)=>Real(n,cc,annotateInsn i)|other=>other)lines
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
 fun emitOutput level text consume=
   let fun loop chunks=case view chunks of NONE=>()
         |SOME(chunk,rest)=>(consume chunk;loop rest)
   in loop(output level text)end
end
