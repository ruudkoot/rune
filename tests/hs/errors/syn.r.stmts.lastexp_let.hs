-- Report 9.5: stmts -> stmt1 ... stmtn exp [;]: a do block ends in an expression, not a let.
module Main (main) where

main :: IO ()
main = do { let { z = () } }
