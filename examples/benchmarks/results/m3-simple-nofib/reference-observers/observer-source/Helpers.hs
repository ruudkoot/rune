module Main where
import Kernel
import GHC.Float(castDoubleToWord64)
import Numeric(showHex)
main=mapM_ (\x->putStrLn(showHex(castDoubleToWord64 x)""))
 [newton_raphson(\x->x-2.0)3.0,newton_raphson(\x-> -1.0)7.0,
  newton_raphson(\x->2.0)7.0,zonal_pressure 1.4 10.0,zonal_energy 1.4 10.0]
