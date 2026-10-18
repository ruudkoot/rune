
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
