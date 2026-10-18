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
   |Success(a,rest)=>(case last rest of ParseFail message=>ParseFail message|Success(b,tail)=>Success(join a b,tail))
 fun convert cvt parser tokens=case parser tokens of ParseFail message=>ParseFail message
   |Success(value,rest)=>Success(cvt value,rest)
 fun literal cvt wanted tokens=case L.force tokens of X.Done=>raise Fail"literal beyond EOF"
   |X.Tok((tag,value,_),rest)=>if tag=wanted then Success(cvt value,rest)else ParseFail Unknown
 fun repeat join initial parser tokens=case parser tokens of ParseFail _=>Success(initial,tokens)
   |Success(value,rest)=>(case repeat join initial parser rest of Success(values,tail)=>Success(join value values,tail)
      |ParseFail _=>raise Fail"repetition invariant")
 fun plus join initial parser tokens=case parser tokens of ParseFail message=>ParseFail message
   |Success(value,rest)=>(case repeat join initial parser rest of Success(values,tail)=>Success(join value values,tail)
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

fun f_m_pexpr_CASE a_casexpr a_patli a_cels=D.delay(fn()=>F_Pexpr_CASE(a_casexpr,a_patli,a_cels))
fun f_m_punion a_thetag a_typli a_unili=D.delay(fn()=>F_Punion(a_thetag,a_typli,a_unili))
fun f_m_pexpli_C a_expli a_eli=D.delay(fn()=>F_Pexpli_C(a_expli,a_eli))
val c_m_pexpli_N=D.delay(fn()=>C_Pexpli_N)
fun f_m_pfunction a_funname a_funparli a_expr=D.delay(fn()=>F_Pfunction(a_funname,a_funparli,a_expr))
fun f_m_pexpr_APPLY a_fexpr a_pexpr=D.delay(fn()=>F_Pexpr_APPLY(a_fexpr,a_pexpr))
fun f_m_pexpr_name a_name=D.delay(fn()=>F_Pexpr_name(a_name))
fun f_m_ppatli_C a_thetag a_pvl a_expr a_pli=D.delay(fn()=>F_Ppatli_C(a_thetag,a_pvl,a_expr,a_pli))
val c_m_pproglist_empty=D.delay(fn()=>C_Pproglist_empty)
fun f_m_ptype_parazd a_name a_typli=D.delay(fn()=>F_Ptype_parazd(a_name,a_typli))
val c_m_ptypli_empty=D.delay(fn()=>C_Ptypli_empty)
fun f_m_pexpr_UNION a_thetag a_expli=D.delay(fn()=>F_Pexpr_UNION(a_thetag,a_expli))
fun f_m_pexpr_char a_thechar=D.delay(fn()=>F_Pexpr_char(a_thechar))
fun f_m_pdeftype a_name a_tparli a_rhs=D.delay(fn()=>F_Pdeftype(a_name,a_tparli,a_rhs))
fun f_m_pbindlhs_name a_name=D.delay(fn()=>F_Pbindlhs_name(a_name))
fun f_m_pbindlhs_pvl a_pvl=D.delay(fn()=>F_Pbindlhs_pvl(a_pvl))
val c_m_pcelse_empty=D.delay(fn()=>C_Pcelse_empty)
fun f_m_pcelse_expr a_expr=D.delay(fn()=>F_Pcelse_expr(a_expr))
fun f_m_pexpr_LET a_letbi a_expr=D.delay(fn()=>F_Pexpr_LET(a_letbi,a_expr))
fun f_m_pexpr_TUPLE a_expli=D.delay(fn()=>F_Pexpr_TUPLE(a_expli))
fun f_m_pexpr_int a_i=D.delay(fn()=>F_Pexpr_int(a_i))
fun f_m_pftype a_fname a_typ=D.delay(fn()=>F_Pftype(a_fname,a_typ))
fun f_m_pfunparli_C a_parname a_fpl=D.delay(fn()=>F_Pfunparli_C(a_parname,a_fpl))
val c_m_pfunparli_N=D.delay(fn()=>C_Pfunparli_N)
fun f_m_pletbinds_C a_lhs a_expr a_plbli=D.delay(fn()=>F_Pletbinds_C(a_lhs,a_expr,a_plbli))
val c_m_pletbinds_N=D.delay(fn()=>C_Pletbinds_N)
val c_m_ppatli_N=D.delay(fn()=>C_Ppatli_N)
fun f_m_ppatvarli_C a_patnam a_pvl=D.delay(fn()=>F_Ppatvarli_C(a_patnam,a_pvl))
val c_m_ppatvarli_N=D.delay(fn()=>C_Ppatvarli_N)
fun f_m_ppr_deftype a_defty=D.delay(fn()=>F_Ppr_deftype(a_defty))
fun f_m_ppr_ftype a_fty=D.delay(fn()=>F_Ppr_ftype(a_fty))
fun f_m_ppr_func a_fun=D.delay(fn()=>F_Ppr_func(a_fun))
fun f_m_pproglist a_part a_proli=D.delay(fn()=>F_Pproglist(a_part,a_proli))
fun f_m_prhs_type a_typ=D.delay(fn()=>F_Prhs_type(a_typ))
fun f_m_prhs_union a_unili=D.delay(fn()=>F_Prhs_union(a_unili))
fun f_m_ptparlist a_parnam a_tpli=D.delay(fn()=>F_Ptparlist(a_parnam,a_tpli))
val c_m_ptparlist_empty=D.delay(fn()=>C_Ptparlist_empty)
fun f_m_ptype_fun a_fty a_pty=D.delay(fn()=>F_Ptype_fun(a_fty,a_pty))
fun f_m_ptype_tparname a_name=D.delay(fn()=>F_Ptype_tparname(a_name))
fun f_m_ptype_tuple a_typli=D.delay(fn()=>F_Ptype_tuple(a_typli))
fun f_m_ptypli a_typ a_typli=D.delay(fn()=>F_Ptypli(a_typ,a_typli))
val c_m_punion_empty=D.delay(fn()=>C_Punion_empty)
val c_tok_error=60
val c_tok_EOF=61
val c_tok_char=11
val c_tok_int=12
val c_tok_TYPE=15
val c_tok_FTYPE=16
val c_tok_LET=17
val c_tok_IN=18
val c_tok_IF=19
val c_tok_THEN=20
val c_tok_ELIF=21
val c_tok_ELSE=22
val c_tok_FI=23
val c_tok_CASE=24
val c_tok_uppid=25
val c_tok_str=13
val c_tok_lowid=14
val c_tok_opfunc=26
val c_tok_opapnd=31
val c_tok_opcolon=32
val c_tok_opand=33
val c_tok_opsep=34
val c_tok_ople=35
val c_tok_opneq=37
val c_tok_opeq=36
val c_tok_opge=38
val c_tok_oplt=39
val c_tok_opgt=40
val c_tok_opdef=30
val c_tok_opadd=41
val c_tok_opdash=42
val c_tok_opmul=43
val c_tok_opdiv=44
val c_tok_opperc=45
val c_tok_optwig=46
val c_tok_btup=47
val c_tok_etup=50
val c_tok_begin=51
val c_tok_end=52
val c_tok_obrack=53
val c_tok_cbrack=54
val c_tok_semi=55
val c_tok_comma=56
val c_tok_hash=57
val c_err_comment="Illegal comment"
val c_err_lexical="Lexical error"
val c_err_CASE="Illegal CASE expression"
val c_err_CASEpatt="Illegal CASE-pattern"
val c_err_ELSE="Illegal ELSE-part"
val c_err_FI="FI expected"
val c_err_THEN="Illegal THEN-part"
val c_err_THENELIF="Illegal THEN part for ELIF"
val c_err_cbrack="Close bracket (')') expected"
val c_err_closbr="Close bracket (')') expected"
val c_err_constr="Illegal tuple or union constructor\n"
val c_err_endCASE="End-CASE ('}') expected"
val c_err_endtup="end of tuple (']') expected"
val c_err_endtupl="End of tuple (']') expected"
val c_err_enduni="End of union (']') expected"
val c_err_explist="Illegal expression list"
val c_err_funcdef="Error in function definition"
val c_err_funtyp="Error in function type definition"
val c_err_funtype="Illegal function-type definition"
val c_err_letlist="Illegal LET-definition list"
val c_err_nest="Illegal nested expression"
val c_err_nesttype="Illegal nested type definition"
val c_err_progterm="Program doesn't terminate with EOF"
val c_err_rhsop="Illegal rhs of operator expression"
val c_err_rhstype="Illegal rhs of type definition"
val c_err_rhsunop="Illegal rhs of unary operator expression"
val c_err_semicol="Semicolon (';') expected"
val c_err_tuptype="Illegal tuple-type definition"
val c_err_typedef="Error in type definition"
val c_err_unitype="Illegal union-type definition"
 fun f_map f xs=List.map f xs
 val c_fparNILname=text"N"
 fun f_fpartup2 a b=pair a b
 fun f_fparsel1 a _=a
 fun f_fparsel2 _ b=b
 val f_fpardroptok=dropToken
 val f_fpargetchar=getChar
 val f_fpargetint=getInteger
 val f_fpargetname=getName
 val f_fparerr=error
 val f_fpar_opermk=operator
 fun f_fpar_case_mk expr pair=D.delay(fn()=>let val(patterns,last)=D.force pair in F_Pexpr_CASE(expr,patterns,last)end)
 fun f_fpar_deftype_rhs_mk first last=D.delay(fn()=>let val(name,types)=D.force first in F_Punion(name,types,last)end)
 fun f_fpar_exprlist_mk values=D.delay(fn()=>D.force(List.foldr(fn(x,xs)=>f_m_pexpli_C x xs)c_m_pexpli_N(D.force values)))
 fun f_fpar_function_mk first expr=D.delay(fn()=>let val(name,args)=D.force first in F_Pfunction(name,args,expr)end)
 fun ifList [] last=last
   |ifList(pair::rest)last=D.delay(fn()=>let val(test,body)=D.force pair
        val outer=f_m_pexpr_APPLY(f_m_pexpr_APPLY(f_m_pexpr_name(text"if"))test)body
      in D.force(f_m_pexpr_APPLY outer(ifList rest last))end)
 fun f_fpar_ifexpr_mk first last=D.delay(fn()=>
   let val(test,bodyElifs)=D.force first val(body,elifs)=D.force bodyElifs
   in D.force(ifList(D.delay(fn()=>(test,body))::D.force elifs)last)end)
 fun f_fpar_pattli_mk first last=D.delay(fn()=>
   let val(names,expr)=D.force first val(name,vars)=D.force names
   in F_Ppatli_C(name,vars,expr,last)end)
 fun f_fpar_prog_mkempty _=c_m_pproglist_empty
 fun f_fpar_simptype_eparaz name=f_m_ptype_parazd name c_m_ptypli_empty
 fun f_fpar_str_mk text=D.delay(fn()=>case D.force text of
      []=>F_Pexpr_UNION(c_fparNILname,c_m_pexpli_N)
     |c::cs=>F_Pexpr_UNION(binName(D.delay(fn()=>32)),f_m_pexpli_C(f_m_pexpr_char(D.delay(fn()=>c)))
        (f_m_pexpli_C(f_fpar_str_mk(D.delay(fn()=>cs)))c_m_pexpli_N)))
 fun f_fpardeftype_mk first rhs=D.delay(fn()=>let val(name,args)=D.force first in F_Pdeftype(name,args,rhs)end)
 fun f_fparttuplety_empty name=pair name c_m_ptypli_empty
 fun f_fparoptoapp_left pair=D.delay(fn()=>
   let val(first,values)=D.force pair
       fun loop []=first
         |loop(p::rest)=D.delay(fn()=>let val(opcode,right)=D.force p
              in D.force(f_m_pexpr_APPLY(f_m_pexpr_APPLY(f_m_pexpr_name(binName opcode))(loop rest))right)end)
   in D.force(loop(List.rev(D.force values)))end)
 fun f_fparoptoapp_right pair=D.delay(fn()=>
   let val(first,values)=D.force pair
   in case D.force values of []=>D.force first
     |p::rest=>let val(opcode,next)=D.force p
          val right=f_fparoptoapp_right(D.delay(fn()=>(next,D.delay(fn()=>rest))))
          val name=binName opcode
      in if Char.isUpper(List.hd(D.force name))then
           F_Pexpr_UNION(name,f_m_pexpli_C first(f_m_pexpli_C right c_m_pexpli_N))
         else D.force(f_m_pexpr_APPLY(f_m_pexpr_APPLY(f_m_pexpr_name(binName opcode))first)right)end end)
 fun f_par_letlist_mk first rest=D.delay(fn()=>let val(lhs,expr)=D.force first in F_Pletbinds_C(lhs,expr,rest)end)
 fun f_par_unopexpr_mk opcode expr=f_m_pexpr_APPLY(f_m_pexpr_name(unName opcode))expr
 fun f_par_appexpr_mk values=D.delay(fn()=>case D.force values of []=>raise Fail"empty application"
    |first::rest=>D.force(List.foldl(fn(x,f)=>f_m_pexpr_APPLY f x)first rest))
 val f_paralt=alt
 val f_parseq=sequence
 val f_parcvt=convert
 val f_parlit=literal
 val f_parrep_right=repeat
 val f_parrepplus_right=plus
 val f_parfail=fail
 val f_paropt=optional

fun c_par_tparname tokens=(f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_hash) (f_parcvt f_m_ptype_tparname (f_parlit f_fpargetname c_tok_lowid))) tokens
and c_par_typelist tokens=(f_parseq f_m_ptypli c_par_type (f_parrep_right f_m_ptypli c_m_ptypli_empty (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_comma) c_par_type))) tokens
and c_par_type_sub tokens=(f_paralt (cons (f_parseq f_m_ptype_parazd (f_parlit f_fpargetname c_tok_lowid) (f_parrep_right f_m_ptypli c_m_ptypli_empty c_par_simptype)) (cons c_par_simptype (cons (f_parcvt f_m_ptype_tuple (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_btup) (f_parfail (f_fparerr c_err_tuptype) (f_parseq f_fparsel1 c_par_typelist (f_parlit f_fpardroptok c_tok_etup))))) [])))) tokens
and c_par_type tokens=(f_paralt (cons (f_parseq f_m_ptype_fun c_par_type_sub (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_opfunc) (f_parfail (f_fparerr c_err_funtype) c_par_type))) (cons c_par_type_sub []))) tokens
and c_par_simptype tokens=(f_paralt (cons (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_obrack) (f_parseq f_fparsel1 (f_parfail (f_fparerr c_err_nesttype) c_par_type) (f_parfail (f_fparerr c_err_closbr) (f_parlit f_fpardroptok c_tok_cbrack)))) (cons c_par_tparname (cons (f_parcvt f_fpar_simptype_eparaz (f_parlit f_fpargetname c_tok_lowid)) [])))) tokens
and c_par_ttuplety tokens=(f_paralt (cons (f_parseq f_fpartup2 (f_parlit f_fpargetname c_tok_uppid) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_comma) c_par_typelist)) (cons (f_parcvt f_fparttuplety_empty (f_parlit f_fpargetname c_tok_uppid)) []))) tokens
and c_par_deftype_rhs tokens=(f_paralt (cons (f_parcvt f_m_prhs_type c_par_type) (cons (f_parcvt f_m_prhs_union (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_btup) (f_parfail (f_fparerr c_err_unitype) (f_parseq f_fparsel1 (f_parseq f_fpar_deftype_rhs_mk c_par_ttuplety (f_parrep_right f_fpar_deftype_rhs_mk c_m_punion_empty (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_opsep) c_par_ttuplety))) (f_parfail (f_fparerr c_err_endtup) (f_parlit f_fpardroptok c_tok_etup)))))) []))) tokens
and c_par_deftype tokens=(f_parseq f_fpardeftype_mk (f_parseq f_fpartup2 (f_parlit f_fpargetname c_tok_lowid) (f_parrep_right f_m_ptparlist c_m_ptparlist_empty (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_hash) (f_parlit f_fpargetname c_tok_lowid)))) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_opdef) (f_parfail (f_fparerr c_err_rhstype) c_par_deftype_rhs))) tokens
and c_par_ftype tokens=(f_parseq f_m_pftype (f_parlit f_fpargetname c_tok_lowid) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_opdef) c_par_type)) tokens
and c_par_take_apart tokens=(f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_oplt) (f_parseq f_fparsel1 (f_parrepplus_right f_m_ppatvarli_C c_m_ppatvarli_N (f_parlit f_fpargetname c_tok_lowid)) (f_parlit f_fpardroptok c_tok_opgt))) tokens
and c_par_unop tokens=(f_paralt (f_map f_fpar_opermk (cons c_tok_opdash (cons c_tok_optwig [])))) tokens
and c_par_pattern tokens=(f_parfail (f_fparerr c_err_CASEpatt) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_oplt) (f_parseq f_fpartup2 (f_parlit f_fpargetname c_tok_uppid) (f_parseq f_fparsel1 (f_parrep_right f_m_ppatvarli_C c_m_ppatvarli_N (f_parlit f_fpargetname c_tok_lowid)) (f_parlit f_fpardroptok c_tok_opgt))))) tokens
and c_par_const tokens=(f_paralt (cons (f_parcvt f_m_pexpr_int (f_parlit f_fpargetint c_tok_int)) (cons (f_parcvt f_m_pexpr_char (f_parlit f_fpargetchar c_tok_char)) (cons (f_parcvt f_fpar_str_mk (f_parlit f_fpargetname c_tok_str)) [])))) tokens
and c_par_op0 tokens=(f_paralt (f_map f_fpar_opermk (cons c_tok_opmul (cons c_tok_opdiv (cons c_tok_opperc []))))) tokens
and c_par_op1 tokens=(f_paralt (f_map f_fpar_opermk (cons c_tok_opadd (cons c_tok_opdash [])))) tokens
and c_par_op2 tokens=(f_paralt (f_map f_fpar_opermk (cons c_tok_ople (cons c_tok_oplt (cons c_tok_opeq (cons c_tok_opneq (cons c_tok_opgt (cons c_tok_opge [])))))))) tokens
and c_par_op3 tokens=(f_paralt (f_map f_fpar_opermk (cons c_tok_opsep (cons c_tok_opand [])))) tokens
and c_par_op4 tokens=(f_fpar_opermk c_tok_opcolon) tokens
and c_par_ope tokens=(f_fpar_opermk c_tok_opapnd) tokens
and c_par_bind tokens=(f_parseq f_fpartup2 (f_paralt (cons (f_parcvt f_m_pbindlhs_name (f_parlit f_fpargetname c_tok_lowid)) (cons (f_parcvt f_m_pbindlhs_pvl c_par_take_apart) []))) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_opdef) c_par_expr)) tokens
and c_par_unopexpr tokens=(f_paralt (cons (f_parseq f_par_unopexpr_mk c_par_unop (f_parfail (f_fparerr c_err_rhsunop) c_par_appexpr)) (cons c_par_appexpr []))) tokens
and c_par_matchlist tokens=(f_parseq f_fpartup2 (f_parfail (f_fparerr c_err_CASE) (f_parrepplus_right f_fpar_pattli_mk c_m_ppatli_N c_par_match)) (f_paropt c_m_pcelse_empty (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_ELSE) (f_parfail (f_fparerr c_err_ELSE) (f_parcvt f_m_pcelse_expr c_par_expr))))) tokens
and c_par_match tokens=(f_parseq f_fpartup2 c_par_pattern (f_parseq f_fparsel1 c_par_expr (f_parfail (f_fparerr c_err_semicol) (f_parlit f_fpardroptok c_tok_semi)))) tokens
and c_par_case tokens=(f_parseq f_fpar_case_mk (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_CASE) (f_parfail (f_fparerr c_err_CASE) c_par_expr)) (f_parfail (f_fparerr c_err_CASE) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_begin) (f_parseq f_fparsel1 c_par_matchlist (f_parfail (f_fparerr c_err_endCASE) (f_parlit f_fpardroptok c_tok_end)))))) tokens
and c_par_structor tokens=(f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_btup) (f_parfail (f_fparerr c_err_constr) (f_parseq f_fparsel1 (f_parseq f_m_pexpr_UNION (f_parlit f_fpargetname c_tok_uppid) (f_paropt c_m_pexpli_N (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_comma) c_par_exprlist))) (f_parfail (f_fparerr c_err_enduni) (f_parlit f_fpardroptok c_tok_etup))))) tokens
and c_par_letlist tokens=(f_parfail (f_fparerr c_err_letlist) (f_parrepplus_right f_par_letlist_mk c_m_pletbinds_N (f_parseq f_fparsel1 c_par_bind (f_parfail (f_fparerr c_err_semicol) (f_parlit f_fpardroptok c_tok_semi))))) tokens
and c_par_ifexpr tokens=(f_parseq f_fpar_ifexpr_mk (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_IF) (f_parfail (f_fparerr c_err_FI) (f_parseq f_fpartup2 c_par_expr (f_parfail (f_fparerr c_err_THEN) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_THEN) (f_parseq f_fpartup2 c_par_expr (f_parrep_right cellCons (cellNil()) c_par_elifpart))))))) (f_parfail (f_fparerr c_err_ELSE) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_ELSE) (f_parseq f_fparsel1 c_par_expr (f_parfail (f_fparerr c_err_FI) (f_parlit f_fpardroptok c_tok_FI)))))) tokens
and c_par_exprlist tokens=(f_parfail (f_fparerr c_err_explist) (f_parcvt f_fpar_exprlist_mk (f_parseq cellCons c_par_expr (f_parrep_right cellCons (cellNil()) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_comma) c_par_expr))))) tokens
and c_par_expr tokens=(f_paralt (cons (f_parseq f_m_pexpr_LET (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_LET) c_par_letlist) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_IN) c_par_expr)) (cons c_par_opexpr []))) tokens
and c_par_opexpr4 tokens=(f_parcvt f_fparoptoapp_right (f_parseq f_fpartup2 c_par_opexpr3 (f_parrep_right cellCons (cellNil()) (f_parseq f_fpartup2 c_par_op4 (f_parfail (f_fparerr c_err_rhsop) c_par_opexpr3))))) tokens
and c_par_opexpr3 tokens=(f_parcvt f_fparoptoapp_left (f_parseq f_fpartup2 c_par_opexpr2 (f_parrep_right cellCons (cellNil()) (f_parseq f_fpartup2 c_par_op3 (f_parfail (f_fparerr c_err_rhsop) c_par_opexpr2))))) tokens
and c_par_opexpr2 tokens=(f_parcvt f_fparoptoapp_left (f_parseq f_fpartup2 c_par_opexpr1 (f_parrep_right cellCons (cellNil()) (f_parseq f_fpartup2 c_par_op2 (f_parfail (f_fparerr c_err_rhsop) c_par_opexpr1))))) tokens
and c_par_opexpr1 tokens=(f_parcvt f_fparoptoapp_left (f_parseq f_fpartup2 c_par_opexpr0 (f_parrep_right cellCons (cellNil()) (f_parseq f_fpartup2 c_par_op1 (f_parfail (f_fparerr c_err_rhsop) c_par_opexpr0))))) tokens
and c_par_opexpr0 tokens=(f_parcvt f_fparoptoapp_left (f_parseq f_fpartup2 c_par_unopexpr (f_parrep_right cellCons (cellNil()) (f_parseq f_fpartup2 c_par_op0 (f_parfail (f_fparerr c_err_rhsop) c_par_unopexpr))))) tokens
and c_par_opexpr tokens=(f_parcvt f_fparoptoapp_left (f_parseq f_fpartup2 c_par_opexpr4 (f_parrep_right cellCons (cellNil()) (f_parseq f_fpartup2 c_par_ope c_par_opexpr4)))) tokens
and c_par_elifpart tokens=(f_parseq f_fpartup2 (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_ELIF) c_par_expr) (f_parfail (f_fparerr c_err_THENELIF) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_THEN) c_par_expr))) tokens
and c_par_tuplctor tokens=(f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_btup) (f_parseq f_fparsel1 (f_parcvt f_m_pexpr_TUPLE c_par_exprlist) (f_parfail (f_fparerr c_err_endtupl) (f_parlit f_fpardroptok c_tok_etup)))) tokens
and c_par_simexpr tokens=(f_paralt (cons (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_obrack) (f_parfail (f_fparerr c_err_nest) (f_parseq f_fparsel1 c_par_expr (f_parfail (f_fparerr c_err_cbrack) (f_parlit f_fpardroptok c_tok_cbrack))))) (cons c_par_structor (cons c_par_tuplctor (cons c_par_ifexpr (cons c_par_case (cons (f_parcvt f_m_pexpr_name (f_parlit f_fpargetname c_tok_lowid)) (cons c_par_const [])))))))) tokens
and c_par_appexpr tokens=(f_parcvt f_par_appexpr_mk (f_parrepplus_right cellCons (cellNil()) c_par_simexpr)) tokens
and c_par_function tokens=(f_parseq f_fpar_function_mk (f_parseq f_fpartup2 (f_parlit f_fpargetname c_tok_lowid) (f_parrep_right f_m_pfunparli_C c_m_pfunparli_N (f_parlit f_fpargetname c_tok_lowid))) (f_parfail (f_fparerr c_err_funcdef) (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_opdef) (f_parseq f_fparsel1 c_par_expr (f_parfail (f_fparerr c_err_semicol) (f_parlit f_fpardroptok c_tok_semi)))))) tokens
and c_par_progpart tokens=(f_paralt (cons (f_parcvt f_m_ppr_deftype (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_TYPE) (f_parfail (f_fparerr c_err_typedef) (f_parseq f_fparsel1 c_par_deftype (f_parfail (f_fparerr c_err_semicol) (f_parlit f_fpardroptok c_tok_semi)))))) (cons (f_parcvt f_m_ppr_ftype (f_parseq f_fparsel2 (f_parlit f_fpardroptok c_tok_FTYPE) (f_parfail (f_fparerr c_err_funtyp) (f_parseq f_fparsel1 c_par_ftype (f_parfail (f_fparerr c_err_semicol) (f_parlit f_fpardroptok c_tok_semi)))))) (cons (f_parcvt f_m_ppr_func c_par_function) [])))) tokens
and c_par_proglist tokens=(f_paralt (cons (f_parseq f_m_pproglist c_par_progpart c_par_proglist) (cons (f_parfail (f_fparerr c_err_progterm) (f_parcvt f_fpar_prog_mkempty (f_parlit f_fpardroptok c_tok_EOF))) []))) tokens

 fun quote text="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"|c=>String.str c)text^"\""
 fun arr xs="["^String.concatWith","xs^"]"
 fun textJSON cell=quote(String.implode(D.force cell))
 fun intJSON cell=intText(D.force cell)
 fun charJSON cell=intText(Char.ord(D.force cell))
 fun dump_T_ptbindlhs cell=case D.force cell of F_Pbindlhs_name(a0)=>arr[quote"F_Pbindlhs_name",textJSON a0]|F_Pbindlhs_pvl(a0)=>arr[quote"F_Pbindlhs_pvl",dump_T_ptpatvarli a0]
 and dump_T_ptcelse cell=case D.force cell of F_Pcelse_expr(a0)=>arr[quote"F_Pcelse_expr",dump_T_ptexpr a0]|C_Pcelse_empty=>arr[quote"C_Pcelse_empty"]
 and dump_T_ptdeftype cell=case D.force cell of F_Pdeftype(a0,a1,a2)=>arr[quote"F_Pdeftype",textJSON a0,dump_T_pttparlist a1,dump_T_ptrhs a2]
 and dump_T_ptexpli cell=case D.force cell of F_Pexpli_C(a0,a1)=>arr[quote"F_Pexpli_C",dump_T_ptexpr a0,dump_T_ptexpli a1]|C_Pexpli_N=>arr[quote"C_Pexpli_N"]
 and dump_T_ptexpr cell=case D.force cell of F_Pexpr_APPLY(a0,a1)=>arr[quote"F_Pexpr_APPLY",dump_T_ptexpr a0,dump_T_ptexpr a1]|F_Pexpr_TUPLE(a0)=>arr[quote"F_Pexpr_TUPLE",dump_T_ptexpli a0]|F_Pexpr_UNION(a0,a1)=>arr[quote"F_Pexpr_UNION",textJSON a0,dump_T_ptexpli a1]|F_Pexpr_CASE(a0,a1,a2)=>arr[quote"F_Pexpr_CASE",dump_T_ptexpr a0,dump_T_ptpatli a1,dump_T_ptcelse a2]|F_Pexpr_LET(a0,a1)=>arr[quote"F_Pexpr_LET",dump_T_ptletbinds a0,dump_T_ptexpr a1]|F_Pexpr_name(a0)=>arr[quote"F_Pexpr_name",textJSON a0]|F_Pexpr_int(a0)=>arr[quote"F_Pexpr_int",intJSON a0]|F_Pexpr_char(a0)=>arr[quote"F_Pexpr_char",charJSON a0]
 and dump_T_ptftype cell=case D.force cell of F_Pftype(a0,a1)=>arr[quote"F_Pftype",textJSON a0,dump_T_pttype a1]
 and dump_T_ptfunction cell=case D.force cell of F_Pfunction(a0,a1,a2)=>arr[quote"F_Pfunction",textJSON a0,dump_T_ptfunparli a1,dump_T_ptexpr a2]
 and dump_T_ptfunparli cell=case D.force cell of F_Pfunparli_C(a0,a1)=>arr[quote"F_Pfunparli_C",textJSON a0,dump_T_ptfunparli a1]|C_Pfunparli_N=>arr[quote"C_Pfunparli_N"]
 and dump_T_ptletbinds cell=case D.force cell of F_Pletbinds_C(a0,a1,a2)=>arr[quote"F_Pletbinds_C",dump_T_ptbindlhs a0,dump_T_ptexpr a1,dump_T_ptletbinds a2]|C_Pletbinds_N=>arr[quote"C_Pletbinds_N"]
 and dump_T_ptpatli cell=case D.force cell of F_Ppatli_C(a0,a1,a2,a3)=>arr[quote"F_Ppatli_C",textJSON a0,dump_T_ptpatvarli a1,dump_T_ptexpr a2,dump_T_ptpatli a3]|C_Ppatli_N=>arr[quote"C_Ppatli_N"]
 and dump_T_ptpatvarli cell=case D.force cell of F_Ppatvarli_C(a0,a1)=>arr[quote"F_Ppatvarli_C",textJSON a0,dump_T_ptpatvarli a1]|C_Ppatvarli_N=>arr[quote"C_Ppatvarli_N"]
 and dump_T_ptpr cell=case D.force cell of F_Ppr_deftype(a0)=>arr[quote"F_Ppr_deftype",dump_T_ptdeftype a0]|F_Ppr_ftype(a0)=>arr[quote"F_Ppr_ftype",dump_T_ptftype a0]|F_Ppr_func(a0)=>arr[quote"F_Ppr_func",dump_T_ptfunction a0]
 and dump_T_ptproglist cell=case D.force cell of F_Pproglist(a0,a1)=>arr[quote"F_Pproglist",dump_T_ptpr a0,dump_T_ptproglist a1]|C_Pproglist_empty=>arr[quote"C_Pproglist_empty"]
 and dump_T_ptrhs cell=case D.force cell of F_Prhs_union(a0)=>arr[quote"F_Prhs_union",dump_T_ptunionli a0]|F_Prhs_type(a0)=>arr[quote"F_Prhs_type",dump_T_pttype a0]
 and dump_T_pttparlist cell=case D.force cell of F_Ptparlist(a0,a1)=>arr[quote"F_Ptparlist",textJSON a0,dump_T_pttparlist a1]|C_Ptparlist_empty=>arr[quote"C_Ptparlist_empty"]
 and dump_T_pttype cell=case D.force cell of F_Ptype_fun(a0,a1)=>arr[quote"F_Ptype_fun",dump_T_pttype a0,dump_T_pttype a1]|F_Ptype_tuple(a0)=>arr[quote"F_Ptype_tuple",dump_T_pttypli a0]|F_Ptype_parazd(a0,a1)=>arr[quote"F_Ptype_parazd",textJSON a0,dump_T_pttypli a1]|F_Ptype_tparname(a0)=>arr[quote"F_Ptype_tparname",textJSON a0]
 and dump_T_pttypli cell=case D.force cell of F_Ptypli(a0,a1)=>arr[quote"F_Ptypli",dump_T_pttype a0,dump_T_pttypli a1]|C_Ptypli_empty=>arr[quote"C_Ptypli_empty"]
 and dump_T_ptunionli cell=case D.force cell of F_Punion(a0,a1,a2)=>arr[quote"F_Punion",textJSON a0,dump_T_pttypli a1,dump_T_ptunionli a2]|C_Punion_empty=>arr[quote"C_Punion_empty"]
 fun value X.Empty=arr[quote"C_Tokv_E"]
   |value(X.Character x)=arr[quote"F_Tokv_ch",intText(Char.ord(D.force x))]
   |value(X.Integer x)=arr[quote"F_Tokv_i",intText(D.force x)]
   |value(X.Text x)=arr[quote"F_Tokv_str",quote(String.implode(D.force x))]
   |value(X.Error(c,message))=arr[quote"F_Tokv_err",intText(Char.ord c),quote message]
 fun dumpTokens stream=case BenchLazy.force stream of X.Done=>arr[quote"[]"]
   |X.Tok((tag,v,line),tail)=>arr[quote"(:)",arr[quote"(,,)",intText tag,value v,intText line],dumpTokens tail]

 fun parseJSON input=case c_par_proglist(X.tokenize input)of
    ParseFail Unknown=>arr[quote"F_Par_fail",arr[quote"C_Emess_uk"]]
   |ParseFail(Known(message,line))=>arr[quote"F_Par_fail",arr[quote"F_Emess_known",quote(L.force message),intText line]]
   |Success(tree,rest)=>arr[quote"F_Par_succ",dump_T_ptproglist tree,dumpTokens rest]
end
