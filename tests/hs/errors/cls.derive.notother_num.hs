-- Report 4.3.3: no class of the Prelude but the six is derivable: not Num.
module Main (main) where

data T = A deriving (Eq, Show, Num)

main :: IO ()
main = return ()
