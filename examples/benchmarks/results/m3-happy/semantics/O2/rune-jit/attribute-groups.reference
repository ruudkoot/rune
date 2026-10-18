

-- parser produced by Happy Version 1.16

data HappyAbsSyn t4 t5
	= HappyTerminal T
	| HappyErrorToken Int
	| HappyAbsSyn4 t4
	| HappyAbsSyn5 t5

action_0 (6) = happyShift action_3
action_0 (4) = happyGoto action_4
action_0 (5) = happyGoto action_2
action_0 _ = happyFail

action_1 (6) = happyShift action_3
action_1 (5) = happyGoto action_2
action_1 _ = happyFail

action_2 (6) = happyShift action_3
action_2 (5) = happyGoto action_5
action_2 _ = happyFail

action_3 _ = happyReduce_2

action_4 (7) = happyAccept
action_4 _ = happyFail

action_5 _ = happyReduce_1

happyReduce_1 = happySpecReduce_2  4 happyReduction_1
happyReduction_1 (HappyAbsSyn5  happy_var_2)
	(HappyAbsSyn5  happy_var_1)
	 =  HappyAbsSyn4
		 (\happyInhAttrs -> let { happySelfAttrs = happyInhAttrs{ a = (a happySubAttrs_1)  }; (happyConditions_1,happySubAttrs_1) = happy_var_1 happyEmptyAttrs{ b = 2 , a = 1 , a = 3  }; (happyConditions_2,happySubAttrs_2) = happy_var_2 happyEmptyAttrs{ a = 4  }; happyConditions = [ok (a happySubAttrs_2) ]++happyConditions_1++happyConditions_2 } in (happyConditions,happySelfAttrs)
	)
happyReduction_1 _ _  = notHappyAtAll 

happyReduce_2 = happySpecReduce_1  5 happyReduction_2
happyReduction_2 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn5
		 (\happyInhAttrs -> let { happySelfAttrs = happyInhAttrs{ a = happy_var_1  }; happyConditions = [] } in (happyConditions,happySelfAttrs)
	)
happyReduction_2 _  = notHappyAtAll 

happyNewToken action sts stk [] =
	action 7 7 notHappyAtAll (HappyState action) sts stk []

happyNewToken action sts stk (tk:tks) =
	let cont i = action i i tk (HappyState action) sts stk tks in
	case tk of {
	X -> cont 6;
	_ -> happyError' (tk:tks)
	}

happyError_ tk tks = happyError' (tk:tks)

newtype HappyIdentity a = HappyIdentity a
happyIdentity = HappyIdentity
happyRunIdentity (HappyIdentity a) = a

instance Monad HappyIdentity where
    return = HappyIdentity
    (HappyIdentity p) >>= q = q p

happyThen :: () => HappyIdentity a -> (a -> HappyIdentity b) -> HappyIdentity b
happyThen = (>>=)
happyReturn :: () => a -> HappyIdentity a
happyReturn = (return)
happyThen1 m k tks = (>>=) m (\a -> k a tks)
happyReturn1 :: () => a -> b -> HappyIdentity a
happyReturn1 = \a tks -> (return) a
happyError' :: () => [T] -> HappyIdentity a
happyError' = HappyIdentity . happyError

do_happyParse tks = happyRunIdentity happySomeParser where
  happySomeParser = happyThen (happyParse action_0 tks) (\x -> case x of {HappyAbsSyn4 z -> happyReturn z; _other -> notHappyAtAll })

happyParse toks = let { f = do_happyParse toks; (conds,attrs) = f happyEmptyAttrs; x = foldr seq attrs conds; } in (a x)

happySeq = happyDontSeq

data HappyAttrs = HappyAttributes {a :: Int, b :: Int}
happyEmptyAttrs = HappyAttributes {a = error "invalid reference to attribute 'a'", b = error "invalid reference to attribute 'b'"}


