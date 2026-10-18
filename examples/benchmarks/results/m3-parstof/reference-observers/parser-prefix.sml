functor BenchParstofFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure X=BenchParstofLexFn(D)
datatype T_ptbindlhs_node=F_Pbindlhs_name of stringCell|F_Pbindlhs_pvl of T_ptpatvarli
and T_ptcelse_node=F_Pcelse_expr of T_ptexpr|C_Pcelse_empty
and T_ptdeftype_node=F_Pdeftype of stringCell*T_pttparlist*T_ptrhs
and T_ptexpli_node=F_Pexpli_C of T_ptexpr*T_ptexpli|C_Pexpli_N
and T_ptexpr_node=F_Pexpr_APPLY of T_ptexpr*T_ptexpr|F_Pexpr_TUPLE of T_ptexpli|F_Pexpr_UNION of stringCell*T_ptexpli|F_Pexpr_CASE of T_ptexpr*T_ptpatli*T_ptcelse|F_Pexpr_LET of T_ptletbinds*T_ptexpr|F_Pexpr_name of stringCell|F_Pexpr_int of int D.t|F_Pexpr_char of char D.t
and T_ptftype_node=F_Pftype of stringCell*T_pttype
and T_ptfunction_node=F_Pfunction of stringCell*T_ptfunparli*T_ptexpr
and T_ptfunparli_node=F_Pfunparli_C of stringCell*T_ptfunparli|C_Pfunparli_N
and T_ptletbinds_node=F_Pletbinds_C of T_ptbindlhs*T_ptexpr*T_ptletbinds|C_Pletbinds_N
and T_ptpatli_node=F_Ppatli_C of stringCell*T_ptpatvarli*T_ptexpr*T_ptpatli|C_Ppatli_N
and T_ptpatvarli_node=F_Ppatvarli_C of stringCell*T_ptpatvarli|C_Ppatvarli_N
and T_ptpr_node=F_Ppr_deftype of T_ptdeftype|F_Ppr_ftype of T_ptftype|F_Ppr_func of T_ptfunction
and T_ptproglist_node=F_Pproglist of T_ptpr*T_ptproglist|C_Pproglist_empty
and T_ptrhs_node=F_Prhs_union of T_ptunionli|F_Prhs_type of T_pttype
and T_pttparlist_node=F_Ptparlist of stringCell*T_pttparlist|C_Ptparlist_empty
and T_pttype_node=F_Ptype_fun of T_pttype*T_pttype|F_Ptype_tuple of T_pttypli|F_Ptype_parazd of stringCell*T_pttypli|F_Ptype_tparname of stringCell
and T_pttypli_node=F_Ptypli of T_pttype*T_pttypli|C_Ptypli_empty
and T_ptunionli_node=F_Punion of stringCell*T_pttypli*T_ptunionli|C_Punion_empty
withtype stringCell=char list D.t
and T_ptbindlhs=T_ptbindlhs_node D.t
and T_ptcelse=T_ptcelse_node D.t
and T_ptdeftype=T_ptdeftype_node D.t
and T_ptexpli=T_ptexpli_node D.t
and T_ptexpr=T_ptexpr_node D.t
and T_ptftype=T_ptftype_node D.t
and T_ptfunction=T_ptfunction_node D.t
and T_ptfunparli=T_ptfunparli_node D.t
and T_ptletbinds=T_ptletbinds_node D.t
and T_ptpatli=T_ptpatli_node D.t
and T_ptpatvarli=T_ptpatvarli_node D.t
and T_ptpr=T_ptpr_node D.t
and T_ptproglist=T_ptproglist_node D.t
and T_ptrhs=T_ptrhs_node D.t
and T_pttparlist=T_pttparlist_node D.t
and T_pttype=T_pttype_node D.t
and T_pttypli=T_pttypli_node D.t
and T_ptunionli=T_ptunionli_node D.t
 datatype message=Unknown|Known of string L.delay*int
 datatype 'a parsed=ParseFail of message|Success of 'a*X.tokens L.delay
 fun select1 a _=a
 fun select2 _ b=b
 fun pair a b=D.delay(fn()=>(a,b))
 fun cellCons a b=D.delay(fn()=>a::D.force b)
 fun cellNil()=D.delay(fn()=>[])
 fun cons a b=a::b
 fun best Unknown second=second
   |best first Unknown=first
   |best(first as Known(_,a))(second as Known(_,b))=if a<b then second else first
 fun alt parsers tokens=
   let fun loop error []=ParseFail error
         |loop error(parser::rest)=case parser tokens of ParseFail next=>loop(best error next)rest|ok=>ok
   in loop Unknown parsers end
 fun sequence join first last tokens=case first tokens of ParseFail message=>ParseFail message
   |Success(a,rest)=>(case last rest of ParseFail message=>ParseFail message|Success(b,tail)=>Success(D.delay(fn()=>D.force(join a b)),tail))
 fun convert cvt parser tokens=case parser tokens of ParseFail message=>ParseFail message
   |Success(value,rest)=>Success(D.delay(fn()=>D.force(cvt value)),rest)
 fun literal cvt wanted tokens=case L.force tokens of X.Done=>raise Fail"literal beyond EOF"
   |X.Tok((tag,value,_),rest)=>if tag=wanted then Success(D.delay(fn()=>D.force(cvt value)),rest)else ParseFail Unknown
 fun repeat join initial parser tokens=case parser tokens of ParseFail _=>Success(initial,tokens)
   |Success(value,rest)=>(case repeat join initial parser rest of Success(values,tail)=>Success(D.delay(fn()=>D.force(join value values)),tail)
      |ParseFail _=>raise Fail"repetition invariant")
 fun plus join initial parser tokens=case parser tokens of ParseFail message=>ParseFail message
   |Success(value,rest)=>(case repeat join initial parser rest of Success(values,tail)=>Success(D.delay(fn()=>D.force(join value values)),tail)
       |ParseFail _=>raise Fail"repetition invariant")
 fun optional initial parser tokens=case parser tokens of ParseFail _=>Success(initial,tokens)|ok=>ok
 fun fail err parser tokens=case parser tokens of ParseFail Unknown=>
      (case L.force tokens of X.Tok((_,_,line),_)=>ParseFail(Known(L.delay(fn()=>err tokens),line))
        |X.Done=>raise Fail"error beyond EOF")
    |answer=>answer
 fun dropToken _=cellNil()
 fun getName(X.Text value)=value|getName _=raise Fail"name token"
 fun getInteger(X.Integer value)=value|getInteger _=raise Fail"integer token"
 fun getChar(X.Character value)=value|getChar _=raise Fail"character token"
 fun operator tag=literal(fn _=>D.delay(fn()=>tag))tag
 fun text value=D.delay(fn()=>String.explode value)
 fun intText n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun findName tag []="Huh?!"
   |findName tag((code,name)::rest)=if tag=code then name else findName tag rest
 val binaryNames=[(31,"append"),(33,"and"),(34,"or"),(35,"le"),(36,"eq"),
   (37,"neq"),(38,"ge"),(39,"lt"),(40,"gt"),(41,"add"),(42,"sub"),
   (43,"mul"),(44,"div"),(45,"rem"),(32,"C")]
 fun binName tag=text(findName(D.force tag)binaryNames)
 fun unName tag=text(findName(D.force tag)[(46,"not"),(42,"neg")])
 fun valueText X.Empty=""
   |valueText(X.Character c)=String.str(D.force c)
   |valueText(X.Integer n)=intText(D.force n)
   |valueText(X.Text s)=String.implode(D.force s)
   |valueText(X.Error(c,message))=message^" at char: "^String.str c
 val tokenNames=[(11,"",""),(12,"",""),(13,"\"","\""),(14,"",""),
   (15,"TYPE",""),(16,"FTYPE",""),(17,"LET",""),(18,"IN",""),(19,"IF",""),
   (20,"THEN",""),(21,"ELIF",""),(22,"ELSE",""),(23,"FI",""),(24,"CASE",""),
   (25,"",""),(26,"->",""),(30,"=",""),(31,"++",""),(32,":",""),(33,"&",""),
   (34,"|",""),(35,"<=",""),(36,"==",""),(38,">=",""),(39,"<",""),(40,">",""),
   (41,"+",""),(42,"-",""),(43,"*",""),(44,"/",""),(45,"%",""),(46,"~",""),
   (47,"[",""),(50,"]",""),(51,"{",""),(52,"}",""),(53,"(",""),(54,")",""),
   (55,";",""),(56,",",""),(57,"#",""),(60,"",""),(61,"EOF","")]
 fun printToken(tag,value,_)=
   let fun loop []="Unknown token in ptoken !?!\n"
         |loop((code,beforeText,afterText)::rest)=if code=tag then beforeText^valueText value^afterText else loop rest
   in loop tokenNames end
 (* Error preview remains lazy: only its first 25 output characters are needed. *)
 fun preview tokens=
   let fun stream input=L.delay(fn()=>case L.force input of X.Done=>X.End
           |X.Tok(token,tail)=>L.force(append(X.chars(printToken token^" "))(stream tail)))
       and append left right=L.delay(fn()=>case L.force left of X.End=>L.force right
           |X.Ch(c,tail)=>X.Ch(c,append tail right))
       fun take 0 _=[]|take n input=case L.force input of X.End=>[]|X.Ch(c,tail)=>c::take(n-1)tail
   in String.implode(take 25(stream tokens))end
 fun error message tokens=case L.force tokens of
      X.Tok((_,_,line),_)=>"line "^intText line^", \""^preview tokens^"...\": "^message^"\n"
    |X.Done=>raise Fail"error at empty stream"
