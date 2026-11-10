-- rows: exp.neg.afterop.low exp.neg.lefttail exp.neg.rightofcons exp.exp10.operand
-- Report 3.4: -e is prefix negation, where lexp6 -> - exp7 allows it: after an operator of lower precedence, at the head
-- of a left chain at level 6, and heading the operand of a lower level; and an exp10 may be the right operand
-- of an operator.
module Main (main) where

main :: IO ()
main = do
  print (- 1 == - 1, True && - 1 == (-1 :: Int), - 2 + 3 - 4 :: Int, - 1 : [], (-1) : [] :: [Int])
  print (1 + let y = 1 in y :: Int, Just 1 >>= \x -> Just x, 2 * if True then 1 else 0 :: Int)
