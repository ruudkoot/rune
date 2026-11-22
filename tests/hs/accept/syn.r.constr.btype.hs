-- Report 9.5: the fields of an infix constructor are btypes, of a prefix one atypes: Maybe Int :+ Maybe Bool.
module Main (main) where

data T = Maybe Int :+ Maybe Bool | P (Maybe Int) [Bool] deriving Show

main :: IO ()
main = print (Just 1 :+ Nothing)
