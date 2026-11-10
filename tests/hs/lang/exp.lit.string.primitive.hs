-- rows: exp.app.left exp.app.con.partial R14
-- Report 3.2: a string literal abbreviates a list of characters; 3.3: application is left associative, and a data
-- constructor may be partially applied.
module Main (main) where

data C = C Int Int deriving Show

f :: Int -> Int -> Int
f = (-)

main :: IO ()
main = do
  print ("ab" == ['a', 'b'], head "ab")
  print ((f 5) 2, f 5 2)
  print (map (C 1) [2, 3], map ((:) 1) [[2]])
