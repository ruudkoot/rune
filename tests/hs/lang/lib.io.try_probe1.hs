-- Report 21: a bottom probe of try, the Report's own definition its reference: the result is not forced;
-- a marker, then the action.
module Main (main) where

import IO

main :: IO ()
main = do
  putStrLn "probe"
  try (return undefined) >>= putStrLn . either (const "Left") (const "Right")
