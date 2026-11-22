-- rows: exp.parse.oplet exp.parse.sig exp.parse.lambdasig
-- Report 3: the meta-rule's parses, shown here by their values; they wait for F's printer too: bin/rhc --dump-ast
-- --no-spans must show let { ... } in (x + y), z + (let { ... } in (x + y)), (f x y) :: Int and \x -> ((a+b) :: Int).
module Main (main) where

f :: Int -> Int -> Int
f x y = x * 10 + y

main :: IO ()
main = do
  print (let { x = 1; y = 2 } in x + y :: Int)
  print (100 + let { x = 1; y = 2 } in x + y :: Int)
  print (f 1 2 :: Int)
  print ((\x -> x + 1 :: Int) 4)
