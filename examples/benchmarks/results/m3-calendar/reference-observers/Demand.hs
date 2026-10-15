module Main where
import qualified Kernel as K
main = do
 print(length(K.cjustify 7 [error "unneeded glyph"]))
 print(length(unlines [[error "unneeded glyph"]]))
 print(length(take 1(K.groop 7 (1:error "unneeded group tail"))))
