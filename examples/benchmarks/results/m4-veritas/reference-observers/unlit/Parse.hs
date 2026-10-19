
 module Parse where

 import Data.Char(isDigit)--1.3
 import Token

 import Unparse

 import Build_Tm

 import Build_itrm

 import Core_datatype

 import Type_defs

 import Attributes

 import Kernel

 import Sub_Core1

 import Sub_Core2

 import Sub_Core3

 import Sub_Core4

 import Vtslib



 type Parse_State = ( [ Tag ] , Sgn )




 parse_trm sg tgL s
        = case parse_itm ( tgL , sg ) s of
              ( Opnd ( Itrm itm )) -> Ok itm
              Prs_Err mesg         -> Bad mesg

 parse_Thm_M sg ps str
	= if is_valid_Thm th
		then Ok th
		else Bad mesg
	  where
	  th = parse_Thm sg ps str
	  ( TH_Err mesg ) = th

 parse_Thm sg ps = parse_deriv (ps, sg) . parse_itm (ps, sg)

 parse_Trm sg ps = parse_tm ( ps , sg )

 trm_to_Trm = build_trm'

 dec_to_Dec = build_dc

 sgn_to_Sgn = build_sg



 parse_tm (tgL , sg ) str
	= build_trm sg flag_itm
	  where
	  ( flag_itm , _ ) = drive_parse ( tgL , sg ) str

 parse_itm sg str
	= itm
	  where
	  (itm , _ ) = drive_parse sg str












 drive_parse :: Parse_State -> String -> ( Flagged_ITrm , [Token] )

 drive_parse sg str
	= term sg [Rvd ""] ( tokenise str )


















 term :: Parse_State -> [Token] -> [Token] -> (Flagged_ITrm , [Token])

 term sg tmnL tkL
	= ( tm , tkL2 )
	  where
	  tm = foldl1 app' ( prioritise tmL )
	  ( tmL , tkL2 ) = term' sg tmnL tkL




























 term' :: Parse_State -> [Token] -> [Token] -> ([Flagged_ITrm] , [Token])
































 term' sg tmnL ( Rvd "if" : tkL )
 	= ( [ cond_tm ] , tkL4 )
	  where
	  cond_tm = cond' dc t_tm f_tm
	  ( dc   , _ : tkL2 ) = hyp sg [ Rvd "then" ] tkL
	  ( t_tm , _ : tkL3 ) = term sg2 [ Rvd "else" ] tkL2
	  ( f_tm , tkL4 )     = term sg2 tmnL tkL3
	  sg2 = pst_extend dc sg




















 term' sg tmnL ( Rvd "let" : tkL )
	= ( [ let' dc tm1 tm2 ] , tkL4 )
	  where
	  ( dc  , _ : tkL2 ) = abdec sg [ IfxOp "=" ] tkL
	  ( tm1 , _ : tkL3 ) = term sg [ Rvd "in" ] tkL2
	  ( tm2 , tkL4 )     = term sg2 tmnL tkL3
	  sg2 = pst_extend dc sg
















 term' sg tmnL ( Rvd "recurse" : tkL )
	= ( [ recurse' tmL srt ] , tkL3 )
	  where
	  ( tmL , tkL2 ) = recurse_cls sg [] tkL
	  ( srt , tkL3 ) = term sg tmnL tkL2





{-
 term' sg tmnl ( Rvd "fn" : tkl )
	= case tkl? of
		Rvd "|" : tkl?' ->
-}























 term' sg tmnL ( Rvd "\185" : tkL )
	= ( app_op : argtm : tmL , tkL3 )
	  where
	  ( argtm , _ : tkL2 ) = term sg [ Rvd "\176" ] tkL
	  ( tmL   , tkL3 )     = term' sg tmnL tkL2
	  app_op = Opr ( Spl "" ) BinR 100















 term' sg tmnL ( Bdr nm : tkL )
	= ( [ bdr_tm ] , tkL3 )
	  where
	  bdr_tm = binder' nm dc tm
	  ( dc , _ : tkL2 ) = bdec sg [ Rvd "." ] tkL
	  ( tm , tkL3 )     = term sg2 tmnL tkL2
	  sg2 = pst_extend dc sg



















 term' sg tmnL ( Rvd "," : tkL )
	= ( pair_op : argtmL , tkL2 )
	  where
	  ( argtmL, tkL2 ) = term' sg ( Rvd "typed" : tmnL ) tkL
	  pair_op = Opr ( Spl "," ) BinR 20









 term' sg tmnL ( Rvd "typed" : tkL )
	= ( [ tpe_op , tpe ] , tkL2 )
	  where
	  ( tpe , tkL2 ) = term sg tmnL tkL
	  tpe_op  = Opr ( Spl "typed" ) BinL 1














 term' sg tmnL ( Rvd "\168": Clr no1 : Rvd ",": Clr no2 : Rvd "\169": tkL )
	= ( sym' no1 no2 : tmL , tkL2 )
	  where
	  ( tmL , tkL2 ) = term' sg tmnL tkL










 term' sg tmnL ( Rvd "\168" : Clr no1 : Rvd "," : Clr no2 : Rvd "," :
						Clr no3 : Rvd "\169" : tkL )
 	= ( const' no1 no2 no3 : tmL , tkL2 )
	  where
	  ( tmL , tkL2 ) = term' sg tmnL tkL












 term' sg tmnL	 ( Rvd "{" : tkL )
	= ( binder' Subtype dc tm : tmL , tkL4 )
	  where
	  ( dc , _ : tkL2 ) = bdec sg [ Rvd "|" ] tkL
	  ( tm , _ : tkL3 ) = term sg2 [ Rvd "}" ] tkL2
	  ( tmL , tkL4 )    = term' sg tmnL tkL3
	  sg2 = pst_extend dc sg
















 term' sg tmnL ( Rvd "[" : tkL )
	= ( dc : tmL , tkL3 )
	  where
	  ( dc , _ : tkL2 ) = bdec sg [ Rvd "]" ] tkL
	  ( tmL , tkL3 )    = term' sg2 tmnL tkL2
	  sg2 = pst_extend dc sg

















 term' sg tmnL ( IfxBdr bdr : tkL )
	= ( bdrop : tmL , tkL2 )
	  where
	  bdrop = make_prebdr bdr
	  ( tmL , tkL2 ) = term' sg tmnL tkL












 term' sg tmnL ( IfxOp op : tkL )
	= ( iop : tmL , tkL2 )
	  where
	  iop = make_iop op
	  ( tmL , tkL2 ) = term' sg tmnL tkL











 term' sg tmnL ( Rvd "\181" : tkL )
	= ( not_op : tmL , tkL2 )
	  where
	  not_op = Opr ( Spl "Not" ) Pre 60
	  ( tmL , tkL2 ) = term' sg tmnL tkL













 term' sg tmnL ( Rvd "(" : tkL )
	= ( tm : tmL , tkL3 )
	  where
	  ( tm , _ : tkL2 )  = term sg [ Rvd ")" ] tkL
	  ( tmL , tkL3 ) = term' sg tmnL tkL2





 term' sg tmnL ( Rvd "@" : tkL )
 	= ( [ Prs_Err "@ not implemented " ] , dmy )













 term' sg tmnL ( Clr ( 'U' : arg@(_:_) ) : tkL ) | and ( map isDigit arg )
	= ( universe : tmL , tkL2 )
	  where
	  universe = ( Opnd . Itrm ) ( Constant ( Univ i ) [] [] )
	  i        = read arg
	  ( tmL , tkL2 ) = term' sg tmnL tkL










 term' sg tmnL ( Clr nm : tkL ) | nm == "true" || nm == "false" || nm == "bool"
	= ( cst : tmL , tkL2 )
	  where
	  cst = ( Opnd . Itrm ) ( Constant ( ctr nm ) [] [] )
	  ctr "true"  = T
	  ctr "false" = F
	  ctr "bool"  = Bool'
	  ( tmL , tkL2 ) = term' sg tmnL tkL





 term' pst@( tgL , sg ) tmnL ( Clr nm : tkL )
	= if in_tgL then ( tag' tg argL : tmL2 , tkL3 )
	            else ( sym_id : tmL1 , tkL2' )
	  where
	  sym_id = lookUp nm sg
	  ( tmL1 , tkL2' ) = term' pst tmnL tkL
	  ( tmL2 , tkL3 )  = term' pst tmnL tkL2
	  ( in_tgL , tg@( _ , arg_kndL , _ )) = fetch_tg nm tgL
	  ( argL , tkL2 ) = parse_tag_arg [] arg_kndL tkL

	  parse_tag_arg tg_resL ( knd : kndL ) lcl_tkL
		= parse_tag_arg ( tg_res : tg_resL ) kndL lcl_tkL3
		  where
		  ( tg_res , lcl_tkL3 )
			= case knd of
				Term_Arg  -> ( Tg_Trm trm_res , lcl_tkL2 )
				Deriv_Arg -> ( Tg_Thm thm_res , lcl_tkL2 )
				Int_Arg   -> parse_iL lcl_tkL
		  trm_res = build_trm sg res_tm
		  thm_res = parse_deriv pst res_tm
		  ( res_tm , lcl_tkL2 ) = aterm pst [] lcl_tkL

	  parse_tag_arg tg_resL [] lcl_tkL
		= ( reverse tg_resL , lcl_tkL )











{-
 term' pst@( _ , sg)  tmnL ( Clr nm : tkL )
	= ( sym_id : tmL , tkL2 ) -- also checks tag list
	  where
	  sym_id = lookup nm sg
	  ( tmL , tkL2 ) = term' pst tmnL tkL
-}











 term' sg tmnL tkL@( tk : _ ) | tk `elem` tmnL
	= ( [] , tkL )







 term' sg tmnl ( Rvd str : tkl )
--	= ( [ Prs_Err (" unexpected '" ++ str ++ "' (term)") ], dmy )	
	= ( [ Prs_Err (" unexpected '" ++ str ++ "'"++ " (term) tmnl: " ++ concat ( map disp_tk tmnl )++ "|") ], dmy )	





 term' sg tmnl [] |  Rvd ""  `elem` tmnl
	= ( [] , [] )

 term' sg tmnl []
	= ( [] , [] )
{- end of file with tmnl not empty is not necessarily an error e.g. ';' in sig
  	= ( [ Prs_Err mesg ] , dmy )
	  where
  	  mesg = " expecting '" ++ concat ( map disp_tk tmnl ) ++ "'"
-}







 term' sg _ ( Scan_Err mesg : _ )
	= ( [ Prs_Err mesg ] , dmy )















 aterm sg tmnl ( Rvd "\168": Clr no1 : Rvd ",": Clr no2 : Rvd "\169": tkl )
	= ( sym' no1 no2 , tkl )




 aterm sg tmnl ( Rvd "\168" : Clr no1 : Rvd "," : Clr no2 : Rvd "," :
						Clr no3 : Rvd "\169" : tkl )
 	= ( const' no1 no2 no3 , tkl )



 aterm sg tmnl ( Rvd "{" : tkl )
	= ( binder' Subtype dc tm , tkl3 )
	  where
	  ( dc , _ : tkl2 ) = bdec sg [ Rvd "|" ] tkl
	  ( tm , tkl3 ) = term sg2 [ Rvd "}" ] tkl2
	  sg2 = pst_extend dc sg




 aterm sg tmnl ( Clr ( 'U' : arg@(_:_) ) : tkl ) | and ( map isDigit arg )
	= ( universe , tkl )
	  where
	  universe = ( Opnd . Itrm ) ( Constant ( Univ i ) [] [] )
	  i        = read arg



 aterm sg tmnl ( Clr nm : tkl ) | nm == "true" || nm == "false" || nm == "bool"
	= ( cst , tkl )
	  where
	  cst = ( Opnd . Itrm ) ( Constant ( ctr nm ) [] [] )
	  ctr "true"  = T
	  ctr "false" = F
	  ctr "bool"  = Bool'



 aterm sg tmnl ( Rvd "(" : tkl )
	= ( tm , tkl2 )
	  where
	  ( tm , _ : tkl2 )  = term sg [ Rvd ")" ] tkl



 aterm ( _ , sg ) tmnl ( Clr nm : tkl )
	= ( sym_id , tkl ) -- also checks tag list
	  where
	  sym_id = lookUp nm sg

 aterm sg tmnl ( tk : tkl )
	= ( Prs_Err (" unexpected '" ++ disp_tk tk ++ "' (aterm -- no tmnl check)" ) , dmy )


























 hyp :: Parse_State -> [Token] -> [Token] -> ( Flagged_ITrm , [Token] )

 hyp sg tmnL ( Rvd "[" : tkL )
	= case tkL2 of
		nxt : _ | nxt `elem` tmnL
			-> ( btm , tkL2 )
               nxt : _ -> ( Prs_Err mesg1 , dmy )
			   where
	  		   mesg1 = "Unexpected token '"++ disp_tk nxt ++"'"
		_	-> ( Prs_Err mesg2 , dmy )
	  where
	  ( btm , _ : tkL2 ) = bdec sg [ Rvd "]" ] tkL
	  mesg2 = "Unexpected end of file"









 hyp sg tmnL tkL
	= ( anon_dc , tkL2 )
	  where
	  anon_dc = symbol_dec' tm  ( Name "_" ) [ hyp_ndpnd ]
	  ( tm , tkL2 ) = term sg tmnL tkL

































 bdec :: Parse_State -> [Token] -> [Token] -> ( Flagged_ITrm , [Token] )

 bdec sg tmnL tkL
	= case tkL2 of
		Rvd ";" : tkL2'
			-> ( decpair' [un_grp] nxt_dc rest , tkL3 )
			   where
	                   ( rest , tkL3 ) = bdec sg2 tmnL tkL2'
		tk : _ | tk `elem` tmnL
			->  ( nxt_dc , tkL2 )
--		oth     ->  ( Prs_Err "Malformed declaration" , dmy )
		oth     ->  error ( "Bdec: " ++ concat ( map disp_tk oth ) ++ "\ntmnl: " ++ concat ( map disp_tk tmnL ) ++ "|" )
 	  where
	  ( nxt_dc , tkL2 ) = bdec' sg tmnL tkL
	  sg2 = pst_extend nxt_dc sg














 bdec' :: Parse_State -> [Token] -> [Token] -> ( Flagged_ITrm , [Token] )

 bdec' sg tmnL ( Rvd "(" : tkL )
	= ( nxt_dc , tkL2 )
	  where
         ( nxt_dc , _ : tkL2 ) = bdec sg [ Rvd ")" ] tkL

 bdec' sg tmnL tkL
	= bdec_name sg ( Rvd ";" : tmnL ) [] tkL




























 bdec_name :: Parse_State -> [Token] -> [Name'] -> [Token]
					-> (Flagged_ITrm , [Token])

 bdec_name sg tmnL nmL tkL
	= case nm of
		Ok inm   -> switch inm tkL2
		Bad mesg -> ( Prs_Err mesg , dmy )
	  where
	  ( nm , tkL2 ) = name tkL

         switch inm ( Rvd "," : tkL2' ) = bdec_name sg tmnL ( inm : nmL ) tkL2'

	  switch inm ( IfxOp ":" : tkL2' )
		= ( make_dc ( reverse ( inm : nmL )) srt dec_tpe , tkL3 )
		  where
		  ( srt , tkL3 ) = term sg ( Rvd ";" : tmnL ) tkL2'

	  switch inm tkL
		= ( make_dc ( reverse ( inm : nmL )) dft dec_untpe , tkL )

	  dft = Opnd ( Itrm ( Constant ( Univ 0 ) [] [] )) --temporary default






















 make_dc :: [Name'] -> Flagged_ITrm -> Attribute -> Flagged_ITrm

 make_dc nmL ( Opnd ( Itrm srt )) tped
	= case dcL of
		[] -> Prs_Err "empty declaration"
		_  -> foldr1 ( decpair' [grp] ) dcL
	  where
	  dcL = make_dcL 0 nmL
	  make_dcL cnt ( nm : nmL )
		= dc : ( make_dcL ( cnt + 1 ) nmL )
		  where
		  dc = Opnd ( Idec ( Symbol_dec shft_srt [ sym_nm nm , tped ]))
		  shft_srt = shift_trm [] cnt srt
	  make_dcL _ [] = []

 make_dc nmL ( Prs_Err mesg ) _
	= Prs_Err mesg

 make_dc nmL _ _ = error "unexpected term in make_dc"



















 abdec :: Parse_State -> [Token] -> [Token] -> ( Flagged_ITrm , [Token] )

 abdec sg tmnL ( Rvd "(" : tkL )
	= ( nxt_dc , tkL2 )
	  where
         ( nxt_dc , _ : tkL2 ) = bdec sg [ Rvd ")" ] tkL

 abdec sg tmnL tkL
	= case nm of
		Ok inm   -> ( symbol_dec' dft inm [] , tkL2 )
		Bad mesg -> ( Prs_Err mesg , dmy )
	  where
	  ( nm , tkL2 ) = name tkL
	  dft = Opnd ( Itrm ( Constant ( Univ 0 ) [] [] )) --temporary default











-- name :: [Token] -> ( MayBe Name' , [Token] )









 name ( Rvd "{" : Clr id : tkL )
	= case tkL3 of
		Rvd "}" : tkL3' -> ( Ok ( Operator' id prc optype ) , tkL3' )
		_		-> ( Bad "missing '}'" , dmy )
	  where
	  ( optype , tkL2 ) = optyp tkL
	  ( prc    , tkL3 ) = opprc tkL2







 name ( Clr id : tkL )
	= ( Ok ( Name id ) , tkL )

 name ( oth : tkL )
	= ( Bad ( " unexpected '" ++ disp_tk oth ++ "' (name)" ) , dmy )

 name [] = ( Bad "empty identifier" , dmy )


















 optyp :: [Token] -> ( Oprtype , [Token] )

 optyp ( Rvd "Pre" : tkL )
	= ( Pre , tkL )

 optyp ( Rvd "BinL" : tkL )
	= ( BinL , tkL )

 optyp ( Rvd "BinR" : tkL )
	= ( BinR , tkL )

 optyp ( Rvd "Post" : tkL )
	= ( Post , tkL )



 optyp tkL
	= ( BinL , tkL )















 opprc :: [Token] -> ( Int , [Token] )

 opprc ( Clr prcid : tkL ) | and ( map isDigit prcid )
	= ( read prcid , tkL )

 opprc tkL
	= ( 1 , tkL )	



















 recurse_cls :: Parse_State -> [Flagged_ITrm] -> [Token] -> ( [Flagged_ITrm] , [Token])

 recurse_cls sg fnL tkL
	= case tkL2 of
		Rvd "end" : Rvd "typed" : tkL2'
			-> ( fn : fnL , tkL2' )
		Rvd "end" : _
			-> ( [ Prs_Err " recurse must be typed " ] , dmy )
		_       -> recurse_cls sg ( fn : fnL ) tkL2
	  where
	  ( fn , tkL2 ) = aterm sg [ Rvd "end" ] tkL










{-
 fn_clauses
	= case ident_type tkL of
		Ok ( i , j , k )
			 -> match ctrL nmL ( i , j ) tkL
			    where
			    ( Data _ ctrL [ dat_nm nmL ] )
					= fetch_type sg i j
	  	Bad mesg -> ( Prs_Err mesg , dmy )


 match sg ctrL ( tpe_nm : nmL ) tp_id tkl
	= ( recurse' fnL srt , tkl2 )
	  where
	  ( fnL , tkl2 ) = match_cls

 match_cls ctr_argL nm
	= case tkl2 of
		Rvd "\167" : tkl2' -> make_rhs
		otherwise          -> error ""
	  where
	  ( ( nm , fmls ) , tkl2 ) = parg sg nm tmnl abdec True tkl
	  sg2 = extend' sg ( fmls ++ rcL )
	  rcL = find_recursive ctr_argL tp_id fmls

 make_rhs
	= case tkl2 of
		Rvd "|" : tkl2'       -> match_cls
		tk : _ | tk `elem` tmnl -> ( clsL , tkl2 )
   	  where
	  tm = add_lambda
	  ( rhs , tkl2 ) = term sg2 tmnl tkl2'




 find_recursive ( arg : argL ) tp_id


 ident_type sg ( Clr nm : tkl )
	= case lookUp nm sg of
		( True , Const i j k _ _ ) -> Ok ( i , j , k )	
	        otherwise                  -> ident_type sg tkl

 ident_type sg ( Rvd "\167" : _ )
	= Bad "No constructor before '\167'"

 ident_type sg ( Rvd tk : _ )	
	= Bad " Unexpected '" ++ disp_tk tk ++ "'"

-}




















 prioritise :: [Flagged_ITrm] -> [Flagged_ITrm]

 prioritise tmL = case ptse [] [] False tmL of
			[]  -> [ Prs_Err "Empty term" ]
			oth -> oth

















 type Flag_I = Flagged_ITrm -- shorthand

 ptse :: [Flag_I] -> [Flag_I] -> Bool -> [Flag_I] -> [Flag_I]





 ptse opnds oprs _ ( Prs_Err tm : opL )
	= [ Prs_Err tm ]












 ptse opnds oprs False ( Opnd tm : opL )
	= ptse ( Opnd tm : opnds ) oprs True opL











 ptse opnds oprs True opL@( Opnd _ : _ )
	= ptse opnds oprs True ( app_op : opL )
	  where
	  app_op = Opr ( Spl "" ) BinL 100
















 ptse opnds oprs _ ( op@( Opr _ Pre prc ) : opL )
	= ptse ( op : opnds ) ( op : oprs ) False opL














 ptse opnds oprs _ ( op@( Opr _ BinL prc ) : opL )
	= ptse ( swap_op op opnds' ) ( op : oprs' ) False opL
	  where
	  ( opnds' , oprs' ) = flush opnds oprs prc null_op











 ptse opnds oprs _ ( op@( Opr op_nm BinR prc ) : opL )
	= ptse ( swap_op op opnds' ) ( op : oprs' ) False opL
	  where
	  ( opnds' , oprs' ) = flush opnds oprs prc cmp_op
	  cmp_op ( Opr _ BinR prc' ) = prc' <= prc
	  cmp_op _ = False















 ptse opnds oprs fl ( op@( Opr _ Post prc ) : opL )
--	= ptse ( swap_op op opnds' ) ( op : oprs' ) False opL
	= ptse ( swap_op op opnds' ) oprs'  fl opL
	  where
	  ( opnds' , oprs' ) = flush opnds oprs prc null_op





 ptse opnds oprs _ []
	= opnds'
	  where
	  ( opnds' , _ ) = flush opnds oprs (-1) null_op











 null_op :: a -> Bool

 null_op _ = False

















 swap_op :: Flagged_ITrm -> [Flagged_ITrm] -> [Flagged_ITrm]

 swap_op op ( top_op : opnds )
	= app' op top_op : opnds

 swap_op op [] = [ op ]






















 flush :: [Flagged_ITrm] -> [Flagged_ITrm] -> Int
	     -> ( Flagged_ITrm -> Bool ) -> ( [Flagged_ITrm] , [Flagged_ITrm] )

 flush opnds oprs@( op@(Opr op_nm op_tpe prc) : opL ) pprc cmp
	= if pprc > prc || cmp op
		then ( opnds , oprs )
		else flush opnds' opL pprc cmp
	  where
	  opnds' = add_op op_nm op_tpe opnds

 flush opnds [] _ _ = ( opnds , [] )
















































 add_op :: Operator -> Oprtype -> [Flagged_ITrm] -> [Flagged_ITrm]

 add_op op Pre ( arg : fn : opnds )
	= app' fn arg : opnds

 add_op op BinL ( arg : fn : opnds )
	= app' fn arg : opnds

 add_op op BinR ( arg : fn : opnds )
	= app' fn arg : opnds




 add_op op Post opnds
	= opnds

 add_op op _ _
	= [ Prs_Err ( " Insufficient arguments for operator" ) ] -- ++ op ) ]





















 make_prebdr :: String -> Flagged_ITrm

 make_prebdr bdr
	= Opr ( OpBdr prefix_form ) BinR prc
	  where
	  ( prefix_form , prc ) = map_bdr bdr
	  map_bdr "\167" = ( Lambda , 5 )
	  map_bdr "\183" = ( Pi     , 80 )
	  map_bdr "\184" = ( Sigma  , 90 )
	  map_bdr "\182" = ( Imp    , 20 )
	  map_bdr "\187" = ( Delta  , 10 )



















 make_iop :: String -> Flagged_ITrm

 make_iop ":"
	= Opr ( Spl ":" ) BinL 15

 make_iop op
	= Opr ( OpIfx oprep ) BinR prc
	  where
	  ( oprep , prc ) = map_op op
	  map_op "\179" = ( And , 40 )
	  map_op "\180" = ( Or , 30 )
	  map_op "="    = ( Eq' , 15 )
	  map_op "\172" = ( Issubtype , 70 )








 lookup_name sg nm
	= case lookUp nm sg of
		Opnd (Itrm tm ) -> SOME tm	
		Prs_Err _       -> NONE
		_               -> error "could be ok, check 'lookup_name' in parse.lhs"
















 lookUp :: String -> Sgn -> Flagged_ITrm

 lookUp nm sg
	= lookup' isg nm 0
	  where
	  isg = internal_Sgn sg





















 lookup' :: ISgn -> String -> Int -> Flagged_ITrm

 lookup' ( Extend dc sg _ ) nm i
	= if in_dc then tm
		   else lookup' sg nm ( i + 1 )
	  where
	  ( in_dc , tm ) = lookup_dc dc [] nm i 0

 lookup' ( Empty _ ) nm i
	= Prs_Err ( " Undefined symbol: " ++ nm )

















 lookup_dc :: IDec -> [IDec] -> String -> Int -> Int -> ( Bool , Flagged_ITrm )

 lookup_dc dc dcL nm  i j
	= if found then ( found , tm )
		   else case dcL of
				dc : dcL' -> lookup_dc dc dcL' nm i ( j + 1 )
				[]        -> ( False , error "" )
	  where
	  ( found , tm ) = lookup_dc' dc dcL nm i j











 lookup_dc' :: IDec -> [IDec] -> String -> Int -> Int -> (Bool , Flagged_ITrm)








 lookup_dc' ( Decpair dc1 dc2 _ ) dcL nm  i j
	= lookup_dc dc1 ( dc2 : dcL ) nm i ( j + 1 )




 lookup_dc' ( Symbol_dec _ ( ( _ , Symbol_Name nm' ) : _ ) ) _ nm i j
	= lookup_nm nm' nm i j

 lookup_dc' ( Axiom_dec _ ( ( _ , Symbol_Name nm' ) : _ ) ) _ nm i j
	= lookup_nm nm' nm i j




 lookup_dc' ( Data _ _ [ ( _ , Datatype_Name nmL ) ] ) _  nm i j
	= lookup_nml nmL nm i j 0





 lookup_dc' ( Def _ _ [ ( _ , Symbol_Name nm' )] ) _ nm i j
	= lookup_nm nm' nm i j










 lookup_nm :: Name' -> String -> Int -> Int -> ( Bool , Flagged_ITrm )








 lookup_nm ( Name nm' ) nm i j
 	| nm == nm' = ( True , ( Opnd . Itrm ) ( Sym i j [] [sym_nmd] ) )
	| otherwise = ( False , error "" )







 lookup_nm ( Operator' nm' prc opt ) nm i j
 	| nm == nm' = ( True , Opr ( OpItrm ( Sym i j [] [sym_nmd] )) opt prc )
	| otherwise = ( False , error "" )



















 lookup_nml :: [Name'] -> String -> Int -> Int -> Int -> (Bool , Flagged_ITrm)

 lookup_nml ( Name nm' : nml ) nm i j k
 	| nm == nm' = ( True , ( Opnd . Itrm ) ( Const i j k [] [sym_nmd] ) )
	| otherwise = lookup_nml nml nm i j ( k + 1 )

 lookup_nml ( Operator' nm' prc opt : nml ) nm i j k
 	| nm == nm' = ( True , Opr
			       ( OpItrm ( Const i j k [] [sym_nmd] )) opt prc )
	| otherwise = lookup_nml nml nm i j ( k + 1 )

 lookup_nml [] _ _ _ _
	= ( False , error "" )













 dmy :: [Token]

 dmy = [ Rvd "" ]







 pst_extend :: Flagged_ITrm -> Parse_State -> Parse_State

 pst_extend ( Opnd ( Idec idc )) ( tgL , sg )
	= ( tgL , extend dc sg )	
	  where
	  dc = build_dc sg idc







 fetch_tg tg_nm1 ( tg@( tg_nm2 , _ , _ ) : tgL )
	| tg_nm1 == tg_nm2 = ( True , tg )
	| otherwise        = fetch_tg tg_nm1 tgL

 fetch_tg _ [] = ( False , ( "" , [] , [] ) )









 parse_deriv :: Parse_State -> Flagged_ITrm -> Thm

 parse_deriv pst ( Opnd ( Itrm itm ))
	= deriv pst itm

 parse_deriv _ _
	= TH_Err "unimplemented feature"




 deriv :: Parse_State -> ITrm -> Thm


 deriv pst@( tgL , sg ) ( Tagid ( str , _ , cnv_fnL ) argL )
	= case fetch_fn cnv_fnL of
		Ok cnv_fn -> cnv_fn argL
		Bad mesg  -> TH_Err mesg
	  where
	  fetch_fn ( Thm_Fn fn : _ ) = Ok fn
	  fetch_fn ( _ : oth )       = fetch_fn oth
	  fetch_fn []                = Bad ( "cannot convert tag " ++ str ++ " to theorem" )

 deriv pst@( tgL , sg ) ( Binder Delta idc itm _ _ )
	= case typ_of_trm sg2 dc_typ of
		Constant Bool' _ _      -> discharge th
		Constant ( Univ _ ) _ _ -> generalise th
		otherwise               -> TH_Err "dc type not bool or univ"
	  where
	  th = deriv ( tgL , extend dc sg ) itm
	  ( dc_typ , _ , sg2 ) = internal_Trm ( typ_of_Dec dc )
	  dc = build_dc sg idc


 deriv pst@( _ , sg ) ( App itm1 itm2 _ _ )
	= case th_tm of
		Binder Forall _ _ _ _ -> specialise th1 tm
		Binder Imp    _ _ _ _ -> modus_ponens th1 th2
		otherwise             -> TH_Err "not \177 or \182"
	  where
	  th1 = deriv pst itm1
	  th2 = deriv pst itm2
	  tm  = build_trm' sg itm2
	  ( th_tm , _ ) = internal_Thm th1

 deriv pst@( _ , sg ) ( Pair itm1 itm2 _ _ _ )
	= modus_ponens ( modus_ponens spec_th th1 ) th2
	  where
	  spec_th = specialise ( specialise th tm1 ) tm2
	  tm1 = typ_of_Thm th1
	  tm2 = typ_of_Thm th2
	  th1 = deriv pst itm1
	  th2 = deriv pst itm2
	  th  = taut ( parse_tm pst str )
	  str = "\177 a:bool. \177 b:bool.a \182 b \182 a \179 b"

 deriv ( _ , sg ) ( Sym i j _ _ )
	= axiom sg i j

 deriv pst@( _ , SG isg ) itm
	= TH_Err (" Invalid construction: " ++ unparse' isg itm )

 deriv _ _ = error "deriv error"

















 parse_iL :: [Token] -> ( Tag_Arg , [Token] )

 parse_iL ( Rvd "\168" : tkL )
	= parse_iL' [] tkL

 parse_iL _ = ( Tg_Trm ( TM_Err "Malformed integer list" ) , dmy )






 parse_iL' iL ( Clr str : tkL ) | and ( map isDigit str )
	= parse_iL'' ( read str : iL ) tkL

 parse_iL' iL ( Rvd "\169" : tkL )
	= ( Tg_Int iL , tkL )

 parse_iL' iL ( tk : _ )
	= ( Tg_Trm ( TM_Err ( "Malformed item in integer list: " ++ disp_tk tk )) , dmy )

 parse_iL' iL []
	= ( Tg_Trm ( TM_Err "Unexpected end of input" ) , dmy )




 parse_iL'' iL ( Rvd "\169" : tkL )
	= ( Tg_Int iL , tkL )

 parse_iL'' iL ( Rvd "," : tkL )
	= parse_iL' iL tkL

 parse_iL'' iL _
	= ( Tg_Trm ( TM_Err " ',' or '\169' expected " ) , dmy )
