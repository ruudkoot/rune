-- Report 8, 4.1.2: (:) is built-in syntax and no import list may name it.
module Main (main) where

import Prelude ((:))

main :: IO ()
main = return ()
