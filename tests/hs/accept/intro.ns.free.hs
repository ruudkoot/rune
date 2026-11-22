-- Report 1.4: a constructor may take a name the Prelude gives a type, with that type hidden: Int.
module Main (main) where

import Prelude hiding (Int)

data Num2 = Int | Two

f :: Num2 -> Bool
f Int = True
f Two = False

main :: IO ()
main = return ()
