-- Report 21: a bottom probe of bracket_, the Report's own definition its reference: the result is not forced;
-- a marker, then the action.
module Main (main) where

import IO

main :: IO ()
main = do
  putStrLn "probe"
  bracket_ (return ()) (\_ -> putStrLn "after") (return undefined) >>= \_ -> putStrLn "done"
