-- also: --eta=ghc
-- M24, D50: strictness evaluates before an I/O action nothing the source evaluates after it. f is strict in x only
-- after an action, so the line is printed before error ends the program, also where GHC's eta rule sees through IO
-- to the state token; an action that raises, caught, comes before the value it is sequenced with (precise
-- exceptions).
module Main (main) where

import IO

f :: Int -> Int -> IO ()
f 0 x = print (x + 1)
f n x = do
  putStrLn "before"
  f (n - 1) x

g :: Int -> IO ()
g x = do
  ioError (userError "raised") `catch` (\_ -> putStrLn "caught")
  print (x * 2)

main :: IO ()
main = g 21 >> f 1 (error "after")
