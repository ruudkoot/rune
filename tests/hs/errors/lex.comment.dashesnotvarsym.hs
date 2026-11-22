-- Report 2.4: varsym -> (symbol {symbol | :})<reservedop | dashes>: `--` is never an operator, so `(--)` opens a
-- comment and leaves its parenthesis open.
module Main (main) where

(--) :: Int -> Int -> Int
a -- b = a

main :: IO ()
main = return ()
