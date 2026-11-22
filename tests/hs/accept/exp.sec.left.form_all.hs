-- rows: exp.sec.right.form exp.sec.ex.plusastarb exp.sec.ex.starparen exp.sec.ex.plusparen exp.sec.right.assoc
-- Report 3.5: ( e op ) and ( op e ), and the Report's valid examples (+a*b), (*(a+b)) and (+(a+b)); a right section
-- of a right-associative operator holds a chain of it.
module Main (main) where

main :: IO ()
main = do
  print ((a +) 1, (a `op` ) 1, (+ a) 1, (`op` a) 1, (+a*b) 1)
  print ((*(a+b)) 1, (+(a+b)) 1, (^ a ^ b) 2)
  where
    a = 2 :: Int
    b = 3 :: Int
    op = (-)
