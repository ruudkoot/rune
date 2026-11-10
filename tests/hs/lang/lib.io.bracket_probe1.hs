-- Report 21: a bottom probe of bracket, the Report's own definition its reference: the acquired value is not forced;
-- a marker, then the action.
module Main (main) where

import IO

main :: IO ()
main = do
  putStrLn "probe"
  bracket (return undefined) (\_ -> putStrLn "release") (\_ -> return 'b') >>= print
