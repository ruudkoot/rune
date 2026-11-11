-- Report 10.4: a derived Show uses the fixity in force where the type is declared, not where it is shown. T declares
-- infixl 6 :+: and infixl 7 :*:, so a :*: inside a :+: needs no parentheses; Main has a :*: of its own at infixl 5,
-- which changes nothing in how T's values are shown, while its own type's show follows its own declaration.
module Main (main) where

import qualified T

infixl 5 :*:
data M = K | M :*: M deriving Show

main :: IO ()
main = do
  print (T.L 1 T.:+: (T.L 2 T.:*: T.L 3))
  print ((T.L 1 T.:+: T.L 2) T.:*: T.L 3)
  print (K :*: K)
  print (Just (K :*: K))
