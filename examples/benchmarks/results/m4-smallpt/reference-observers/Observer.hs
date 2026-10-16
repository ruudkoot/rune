module Main where
import qualified Kernel as K
import System.Environment
main = do
 [w,h,s] <- map read <$> getArgs
 image <- K.smallpt w h s
 putStrLn (K.hashImage image)
 mapM_ (\(K.Vec r g b) -> putStrLn(show r++" "++show g++" "++show b))image
