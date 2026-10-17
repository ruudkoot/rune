module Recorder where
import Data.IORef
import System.IO.Unsafe(unsafePerformIO)
import Control.Exception(evaluate)
import NofibUtils(hash)
storage :: IORef [(Maybe String,String)]
storage=unsafePerformIO(newIORef [])
{-# NOINLINE storage #-}
record path text=do
 _<-evaluate(hash text)
 modifyIORef' storage ((path,text):)
reset=writeIORef storage []
collect=reverse <$> readIORef storage
