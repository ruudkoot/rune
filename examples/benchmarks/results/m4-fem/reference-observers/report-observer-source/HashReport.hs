module Main where
import NofibUtils(hash)
import Data.Word(Word64)
import Numeric(showHex)
main=getContents >>= (\text->putStrLn(showHex(fromIntegral(hash text)::Word64)""))
