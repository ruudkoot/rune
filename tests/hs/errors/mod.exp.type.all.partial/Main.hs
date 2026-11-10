-- Report 5.2: T(..) of an imported type exports what is in scope: B was not imported.
module Main (main) where

import M

main :: IO ()
main = case B of _ -> return ()
