-- Report 9.3: a block's context is the column of its first lexeme, a positive number L pushes above the enclosing one;
-- a nested do at a deeper column opens its own, and a line back at the outer column closes it. Its expansion, token
-- by token, is tests/hs/roundtrip/layout/lay.stack.positive_nested.braces, which hs/syntax/expansions holds to L.
module Main (main) where

main :: IO ()
main = do
      putStr "a"
      do
        putStr "b"
        putStr "c"
      putStrLn "d"
