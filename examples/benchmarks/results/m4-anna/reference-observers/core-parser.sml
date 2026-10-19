 fun cached slot build tokens=
   let val parser=case !slot of SOME p=>p|NONE=>let val p=build()in slot:=SOME p;p end
   in parser tokens end
 fun inNames choices text=List.exists(fn s=>tokenIs s text)choices
 val keywords=["let","letrec","case","in","of","end"]
 fun firstChar text=force(head text)
 fun isName text=Char.isAlpha(firstChar text)andalso not(inNames keywords text)
 fun isConstructor text=firstChar text>= #"A"andalso firstChar text<= #"Z"andalso not(inNames keywords text)
 val paName=paSatisfy isName
 val paConstructorName=paSatisfy isConstructor
 val relations=["<=","<",">=",">","==","~="]
 val paRelation=paSatisfy(inNames relations)
 fun trailingSemi parser=paThen2(fn a=>fn _=>a)parser(literal";")
 type scDefinition=name*(nameNode F.seq*core)D.t
 type coreBinding=name*core
 type constructorAlt=name*tdefNode F.seq
 val programSlot:coreProgram parser option ref=ref NONE
 val typeDefsSlot:typeDef F.node parser option ref=ref NONE
 val typeDefSlot:typeDef parser option ref=ref NONE
 val constructorAltsSlot:constructorAlt F.node parser option ref=ref NONE
 val constructorAltSlot:constructorAlt parser option ref=ref NONE
 val typeExprSlot:tdefNode parser option ref=ref NONE
 val scDefsSlot:scDefinition F.node parser option ref=ref NONE
 val scSlot:scDefinition parser option ref=ref NONE
 val exprSlot:nameNode coreNode parser option ref=ref NONE
 val letSlot:nameNode coreNode parser option ref=ref NONE
 val letrecSlot:nameNode coreNode parser option ref=ref NONE
 val bindingsSlot:coreBinding F.node parser option ref=ref NONE
 val bindingSlot:coreBinding parser option ref=ref NONE
 val caseSlot:nameNode coreNode parser option ref=ref NONE
 val alternativesSlot:scDefinition F.node parser option ref=ref NONE
 val alternativeSlot:scDefinition parser option ref=ref NONE
 val lambdaSlot:nameNode coreNode parser option ref=ref NONE
 val expr1Slot:nameNode coreNode parser option ref=ref NONE
 val expr2Slot:nameNode coreNode parser option ref=ref NONE
 val expr3Slot:nameNode coreNode parser option ref=ref NONE
 val expr4Slot:nameNode coreNode parser option ref=ref NONE
 val expr5Slot:nameNode coreNode parser option ref=ref NONE
 val expr6Slot:nameNode coreNode parser option ref=ref NONE
 val expr1cSlot:partialNode parser option ref=ref NONE
 val expr2cSlot:partialNode parser option ref=ref NONE
 val expr3cSlot:partialNode parser option ref=ref NONE
 val expr4cSlot:partialNode parser option ref=ref NONE
 val expr5cSlot:partialNode parser option ref=ref NONE
 val atomicSlot:nameNode coreNode parser option ref=ref NONE
 fun assembleOp left partial=D.delay(fn()=>case force partial of NoOp=>force left
   |FoundOp(opname,right)=>EAp(cell(EAp(cell(EVar opname),left)),right))
 fun paProgram tokens=cached programSlot(fn()=>paThen3(fn a=>fn _=>fn c=>pair a c)
      paTypeDefs(literal";;")paScDefs)tokens
 and paTypeDefs tokens=cached typeDefsSlot(fn()=>paZeroOrMore(trailingSemi paTypeDefinition))tokens
 and paTypeDefinition tokens=cached typeDefSlot(fn()=>paThen4(fn a=>fn b=>fn _=>fn d=>triple a b d)
      paName(paZeroOrMore paName)(literal"::=")paConstructorAlts)tokens
 and paConstructorAlts tokens=cached constructorAltsSlot(fn()=>paOneOrMoreSep paConstructorAlt(literal"|"))tokens
 and paConstructorAlt tokens=cached constructorAltSlot(fn()=>paThen2 pair paConstructorName(paZeroOrMore paTypeExpr))tokens
 and paTypeExpr tokens=cached typeExprSlot(fn()=>paAlts[
      (tokenIs"(",paThen3(fn _=>fn e=>fn _=>e)(literal"(")
        (paThen2(fn n=>fn args=>cell(TDefCons(n,args)))paName(paZeroOrMore paTypeExpr))(literal")")),
      (isName,paApply paName(fn n=>cell(TDefVar n)))])tokens
 and paScDefs tokens=cached scDefsSlot(fn()=>paOneOrMore(trailingSemi paSc))tokens
 and paSc tokens=cached scSlot(fn()=>paThen4(fn n=>fn args=>fn _=>fn body=>pair n(pair args body))
      paName(paZeroOrMore paName)(literal"=")paExpr)tokens
 and paExpr tokens=cached exprSlot(fn()=>paAlts[(tokenIs"let",paLet),(tokenIs"letrec",paLetrec),
      (tokenIs"case",paCase),(tokenIs"\\",paLambda),(fn _=>true,paExpr1)])tokens
 and paLet tokens=cached letSlot(fn()=>paThen4(fn _=>fn bindings=>fn _=>fn body=>cell(ELet(cell false,bindings,body)))
      (literal"let")paBindings(literal"in")paExpr)tokens
 and paLetrec tokens=cached letrecSlot(fn()=>paThen4(fn _=>fn bindings=>fn _=>fn body=>cell(ELet(cell true,bindings,body)))
      (literal"letrec")paBindings(literal"in")paExpr)tokens
 and paBindings tokens=cached bindingsSlot(fn()=>paOneOrMoreSep paBinding(literal";"))tokens
 and paBinding tokens=cached bindingSlot(fn()=>paThen3(fn n=>fn _=>fn e=>pair n e)paName(literal"=")paExpr)tokens
 and paCase tokens=cached caseSlot(fn()=>paThen4(fn _=>fn e=>fn _=>fn alts=>cell(ECase(e,alts)))
      (literal"case")paExpr(literal"of")paAlternatives)tokens
 and paAlternatives tokens=cached alternativesSlot(fn()=>paThen2(fn a=>fn _=>a)
      (paOneOrMoreSep paAlternative(literal";"))(literal"end"))tokens
 and paAlternative tokens=cached alternativeSlot(fn()=>paThen4(fn c=>fn args=>fn _=>fn e=>pair c(pair args e))
      paConstructorName(paZeroOrMore paName)(literal"->")paExpr)tokens
 and paLambda tokens=cached lambdaSlot(fn()=>paThen4(fn _=>fn args=>fn _=>fn e=>cell(ELam(args,e)))
      (literal"\\")(paOneOrMore paName)(literal"->")paExpr)tokens
 and paExpr1 tokens=cached expr1Slot(fn()=>paThen2 assembleOp paExpr2 paExpr1c)tokens
 and paExpr2 tokens=cached expr2Slot(fn()=>paThen2 assembleOp paExpr3 paExpr2c)tokens
 and paExpr3 tokens=cached expr3Slot(fn()=>paThen2 assembleOp paExpr4 paExpr3c)tokens
 and paExpr4 tokens=cached expr4Slot(fn()=>paThen2 assembleOp paExpr5 paExpr4c)tokens
 and paExpr5 tokens=cached expr5Slot(fn()=>paThen2 assembleOp paExpr6 paExpr5c)tokens
 and paExpr6 tokens=cached expr6Slot(fn()=>paApply(paOneOrMore paAtomic)
      (fn terms=>foldLeft(fn f=>fn a=>cell(EAp(f,a)))(head terms)(tail terms)))tokens
 and paExpr1c tokens=cached expr1cSlot(fn()=>paAlts[
      (tokenIs"|",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"|")paExpr1),
      (tokenIs"#",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"#")paExpr1),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr2c tokens=cached expr2cSlot(fn()=>paAlts[
      (tokenIs"&",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"&")paExpr2),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr3c tokens=cached expr3cSlot(fn()=>paAlts[
      (inNames relations,paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))paRelation paExpr4),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr4c tokens=cached expr4cSlot(fn()=>paAlts[
      (tokenIs"+",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"+")paExpr4),
      (tokenIs"-",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"-")paExpr5),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr5c tokens=cached expr5cSlot(fn()=>paAlts[
      (tokenIs"*",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"*")paExpr5),
      (tokenIs"/",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"/")paExpr6),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paAtomic tokens=cached atomicSlot(fn()=>paAlts[
      (isConstructor,paApply paConstructorName(fn n=>cell(EConstr n))),
      (tokenIs"(",paThen3(fn _=>fn e=>fn _=>e)(literal"(")paExpr(literal")")),
      (isName,paApply paName(fn n=>cell(EVar n))),
      (fn n=>Char.isDigit(firstChar n),paApply paNumber(fn n=>cell(ENum n)))])tokens
 fun parseSyntax tokens=
   let fun unexpected rest=case L.force rest of C.Nil=>myFail"Syntax error: Unexpected end of source text"
      |C.Cons(tok,_)=>let val(line,text)=L.force tok
        in myFail("Syntax error: unexpected token \""^string text^"\" on line "^signed line)end
   in case L.force(paProgram tokens)of PFail rest=>unexpected rest|POk(program,rest)=>
       case L.force rest of C.Nil=>raise Match|C.Cons(tok,tail)=>
         let val(line,text)=L.force tok
         in case L.force tail of C.Nil=>if equalInt line(int 999999)andalso tokenIs"$$$"text then program else raise Match
             |_=>unexpected rest end
   end
