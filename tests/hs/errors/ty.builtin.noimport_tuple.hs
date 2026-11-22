-- Report 4.1.2: the built-in type constructors cannot be named in an import list: not (,).
module Main (main) where

import Prelude ((,))


main :: IO ()
main = return ()
