-- Report 5.3.3: import Foo as A (f) brings in f and A.f, not Foo.f.
module Main (main) where

import Foo as A (f)

main :: IO ()
main = print Foo.f
