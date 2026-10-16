module Main where
import qualified Kernel as K
import System.Environment
main=getArgs >>= \[size] -> putStr(K.fmt(K.pseudolimit (0,0) (read size,0) (0,read size)))
