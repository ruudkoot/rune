-- Report 5.3.1: hiding takes an import list's forms: T(..) hides its constructors.
module Main (main) where

import M hiding (Con2(..))

main :: IO ()
main = case Two of _ -> return ()
