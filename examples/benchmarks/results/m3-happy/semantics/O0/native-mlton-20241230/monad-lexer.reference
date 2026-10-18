

-- parser produced by Happy Version 1.16

data HappyAbsSyn t4
	= HappyTerminal T
	| HappyErrorToken Int
	| HappyAbsSyn4 t4

action_0 (5) = happyShift action_2
action_0 (4) = happyGoto action_3
action_0 _ = happyFail

action_1 (5) = happyShift action_2
action_1 _ = happyFail

action_2 _ = happyReduce_1

action_3 (6) = happyAccept
action_3 _ = happyFail

happyReduce_1 = happySpecReduce_1  4 happyReduction_1
happyReduction_1 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn4
		 (happy_var_1
	)
happyReduction_1 _  = notHappyAtAll 

happyNewToken action sts stk
	= lex(\tk -> 
	let cont i = action i i tk (HappyState action) sts stk in
	case tk of {
	eof -> action 6 6 tk (HappyState action) sts stk;
	X -> cont 5;
	_ -> happyError' tk
	})

happyError_ tk = happyError' tk

happyThen :: Ctx => M a -> (a -> M b) -> M b
happyThen = (bind)
happyReturn :: Ctx => a -> M a
happyReturn = (ret)
happyThen1 = happyThen
happyReturn1 :: Ctx => a -> M a
happyReturn1 = happyReturn
happyError' :: Ctx => T -> M a
happyError' tk = bad tk

happyParse = happySomeParser where
  happySomeParser = happyThen (happyParse action_0) (\x -> case x of {HappyAbsSyn4 z -> happyReturn z; _other -> notHappyAtAll })

happySeq = happyDontSeq



