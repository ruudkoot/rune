-- Report 3.14: a statement let decls and an expression let decls in e are told apart in one do block. (Its own braces
-- close the statement's let: without them the ; after it is the let block's, by 9.3, and print y a declaration.)
module Main (main) where

main :: IO ()
main = do { let x = 1 in print (x :: Int); let { y = 2 }; print (y :: Int) }
