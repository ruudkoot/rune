-- Report 2.4, the table of samples: `F.` lexes as `F .`, two tokens: the constructor F composed.
module Main (main) where

data T = F Int deriving Show

main :: IO ()
main = print ((F. negate) 1)
