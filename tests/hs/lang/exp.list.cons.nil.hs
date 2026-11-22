-- rows: tr.list exp.list.lazy exp.cons.fixity
-- Report 3.7: the constructors are : and []; [e1, ..., ek] is e1 : (e2 : ( ... (ek : []))); forming a list evaluates no
-- element; : is infixr 5.
module Main (main) where

f :: [Int] -> String
f [] = "nil"
f (_ : _) = "cons"

main :: IO ()
main = do
  print (f [], f [1])
  print ([1, 2, 3] == 1 : (2 : (3 : [])))
  print (length [undefined, undefined :: Int])
  let x = 1
      xs = [5]
  print (1 : 2 : [], x + 1 : xs)
