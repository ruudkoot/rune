-- Report 8: a static ccall import of a libc function.
module Main where
import Foreign.C.Types
foreign import ccall "math.h sin" c_sin :: CDouble -> CDouble
main = print (realToFrac (c_sin 0) :: Double)
