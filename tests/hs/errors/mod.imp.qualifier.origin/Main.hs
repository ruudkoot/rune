-- Report 5.3.2: the qualifier is the imported module's, not the one that declared the entity: not D.d.
module Main (main) where

import B

main :: IO ()
main = print D.d
