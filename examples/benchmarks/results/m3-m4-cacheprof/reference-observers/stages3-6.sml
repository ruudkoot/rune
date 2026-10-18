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
