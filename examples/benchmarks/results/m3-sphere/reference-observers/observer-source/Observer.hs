module Main where
import qualified Kernel as K
import System.Environment
main = do
 [size] <- getArgs
 mapM_ (\((i,j),(r,g,b))->putStrLn(unwords[show i,show j,show r,show g,show b,show(round(255*r)::Integer),show(round(255*g)::Integer),show(round(255*b)::Integer)])) (K.ray(read size))
