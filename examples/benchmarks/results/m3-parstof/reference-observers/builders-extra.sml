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
