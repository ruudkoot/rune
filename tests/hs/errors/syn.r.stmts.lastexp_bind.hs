-- Report 9.5: stmts -> stmt1 ... stmtn exp [;]: a do block ends in an expression, not a binding.
module Main (main) where

main :: IO ()
main = do { x <- return () }
