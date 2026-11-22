-- rows: der.show.readable der.read.neg R42 R88
-- Report 10.4, readings.md R88: a negative Float or Double is parenthesised above precedence 6, and derived Read takes that
-- form back.
module Main (main) where

data T = T Double Float deriving (Show, Read, Eq)

main :: IO ()
main = do
  print (Just (-1.5 :: Double), T (-2.5) (-0.5))
  print (read (show (T (-2.5) (-0.5))) == T (-2.5) (-0.5), read "Just (-1)" :: Maybe Int, read "Just (-1.5)" :: Maybe Double)
