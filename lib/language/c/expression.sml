(* Implements: C_EXPRESSION *)
structure CExpression : C_EXPRESSION =
struct
  type binding = {ty : CParse.ctype, value : IntInf.int option}
  exception Error of CLex.location * string
  datatype expression = Literal of CLex.token | Name of CLex.token
    | Unary of CLex.token * expression | Binary of CLex.token * expression * expression
    | Conditional of CLex.token * expression * expression * expression
    | Cast of CLex.token * CParse.ctype * expression
    | MeasureType of CLex.token * CParse.ctype | MeasureValue of CLex.token * expression
  fun evaluate {target,sizeType,tokens,lookup,resolveType,integerType,measure} =
    let val tokens=List.filter(fn(t:CLex.token)=> #kind t<>CLex.Newline)tokens
        val fallback={file="<expression>",line=1,column=1}
        fun fail token message=raise Error(CLex.diagnostic(token,message))
        fun missing()=raise Error(case rev tokens of []=>fallback | t::_=> #location t,"incomplete C expression")
        fun rank s=case s of "||"=>1 | "&&"=>2 | "|"=>3 | "^"=>4 | "&"=>5 | "=="=>6 | "!="=>6
          | "<"=>7 | ">"=>7 | "<="=>7 | ">="=>7 | "<<"=>8 | ">>"=>8 | "+"=>9 | "-"=>9
          | "*"=>10 | "/"=>10 | "%"=>10 | _=>0
        fun group [] _ _=missing()
          | group((t:CLex.token)::rest) depth acc=
            if #text t=")" andalso depth=0 then (rev acc,rest)
            else group rest (if #text t="(" then depth+1 else if #text t=")" then depth-1 else depth)(t::acc)
        fun primary []=missing()
          | primary((t:CLex.token)::rest)=
            if #text t="(" then
              let val(inside,after)=group rest 0 []
              in case resolveType inside of SOME ty=>let val(e,tail)=primary after in (Cast(t,ty,e),tail) end
                | NONE=>let val(e,tail)=conditional inside
                        in case tail of []=>(e,after) | bad::_=>fail bad "unexpected parenthesized C expression token" end end
            else if List.exists(fn s=>s= #text t)["sizeof","_Alignof","alignof","__alignof","__alignof__"] then
              (case rest of openToken::tail=>if #text openToken="(" then
                let val(inside,after)=group tail 0 []
                in case resolveType inside of SOME ty=>(MeasureType(t,ty),after)
                  | NONE=>if #text t="_Alignof" then fail t "_Alignof requires a type name"
                    else let val(e,tail)=conditional inside
                         in case tail of []=>(MeasureValue(t,e),after) | bad::_=>fail bad "invalid measured expression" end end
                else if #text t="sizeof" then let val(e,tail)=primary rest in (MeasureValue(t,e),tail) end
                else fail t "alignment operator requires parentheses"
              | []=>missing())
            else if List.exists(fn s=>s= #text t)["+","-","!","~","*","&"] then
              let val(e,tail)=primary rest in (Unary(t,e),tail) end
            else if #kind t=CLex.Number orelse #kind t=CLex.CharacterLiteral then (Literal t,rest)
            else if #kind t=CLex.Identifier then (Name t,rest) else fail t "expected C constant expression"
        and binary minimum input=
          let val(left,rest)=primary input
              fun more(left,(t:CLex.token)::tail)=if rank(#text t)<minimum then (left,t::tail)
                    else let val(right,after)=binary(rank(#text t)+1)tail in more(Binary(t,left,right),after) end
                | more pair=pair
          in more(left,rest) end
        and conditional input=
          let val(condition,rest)=binary 1 input
          in case rest of q::tail=>if #text q="?" then
               let val(yes,after)=conditional tail
               in case after of colon::tail=>if #text colon=":" then
                    let val(no,rest)=conditional tail in (Conditional(q,condition,yes,no),rest) end
                    else fail colon "expected ':'" | []=>missing() end
             else(condition,rest) | []=>(condition,rest) end
        val(tree,rest)=conditional tokens
        val ()=case rest of []=>() | t::_=>fail t "unexpected C expression token"
        val intType=CInteger.integerType target CInteger.Int true
        fun ctype ty=CParse.Builtin(CType.spelling ty)
        fun integral token ty=case integerType ty of SOME ty=>ty | NONE=>fail token "integer C operand required"
        fun promoted ty= #ty(CInteger.promote target {integer=0,ty=ty})
        fun binding t=case lookup(#text(t:CLex.token)) of SOME b=>b | NONE=>fail t "unresolved C constant/object"
        fun unwrap(CParse.Attributed(ty,_))=unwrap ty | unwrap ty=ty
        fun typeof(Literal t)=ctype(#ty(CInteger.literal target t))
          | typeof(Name t)= #ty(binding t)
          | typeof(Cast(t,ty,e))=
              let fun scalar ty=isSome(integerType ty) orelse
                    (case unwrap ty of CParse.Pointer _=>true | _=>false)
              in if scalar ty andalso scalar(typeof e) then ty else fail t "C cast requires scalar types" end
          | typeof(MeasureType(t,ty))=(ignore(measure ty);ctype sizeType)
          | typeof(MeasureValue(t,e))=(ignore(measure(typeof e));ctype sizeType)
          | typeof(Unary(t,e))=
              if #text t="*" then (case unwrap(typeof e) of CParse.Pointer{target,...}=>target
                | _=>fail t "dereference requires a pointer")
              else if #text t="&" then (case e of Name _=>CParse.Pointer{target=typeof e,qualifiers=[]}
                | Unary(opToken,_)=>if #text opToken="*" then CParse.Pointer{target=typeof e,qualifiers=[]}
                    else fail t "address requires an object"
                | _=>fail t "address requires an object")
              else let val ty=promoted(integral t (typeof e)) in ctype(if #text t="!" then intType else ty) end
          | typeof(Binary(t,a,b))=
              let val left=integral t (typeof a) val right=integral t (typeof b)
              in ctype(if List.exists(fn s=>s= #text t)["==","!=","<",">","<=",">=","&&","||"] then intType
                else if #text t="<<" orelse #text t=">>" then promoted left else CInteger.common target(left,right)) end
          | typeof(Conditional(t,c,a,b))=(ignore(integral t (typeof c));
              ctype(CInteger.common target(integral t (typeof a),integral t (typeof b))))
        fun truth({integer,...}:CInteger.value)=integer<>0
        fun bool b : CInteger.value={integer=if b then 1 else 0,ty=intType}
        fun measured token ty : CInteger.value=
          let val{size,alignment}=measure ty
              val n=if #text token="sizeof" then size else IntInf.fromInt alignment
              val(_,maximum)=CInteger.limits sizeType
          in if n<0 orelse n>maximum then fail token "C size/alignment exceeds size_t" else {integer=n,ty=sizeType} end
        fun eval(Literal t)=CInteger.literal target t
          | eval(Name t)=let val{ty,value}=binding t val ty=integral t ty
              in case value of SOME n=>CInteger.convert ty {integer=n,ty=ty} | NONE=>fail t "C object has no constant value" end
          | eval(Cast(t,ty,e))=
              let val ty=integral t ty val value=eval e
              in if #width ty=1 then {integer=if truth value then 1 else 0,ty=ty}
                 else CInteger.convert ty value end
          | eval(MeasureType(t,ty))=measured t ty
          | eval(MeasureValue(t,e))=measured t (typeof e)
          | eval(Unary(t,e))=CInteger.unary target t (eval e)
          | eval(Binary(t,a,b))=if #text t="&&" then bool(truth(eval a) andalso truth(eval b))
              else if #text t="||" then bool(truth(eval a) orelse truth(eval b))
              else CInteger.binary target t (eval a,eval b)
          | eval(Conditional(t,c,a,b))=
              CInteger.convert(CInteger.common target(integral t (typeof a),integral t (typeof b)))
                (eval(if truth(eval c) then a else b))
        val ()=ignore(typeof tree)
    in eval tree end
    handle CInteger.Error e=>raise Error e | CConst.Error e=>raise Error e
end
