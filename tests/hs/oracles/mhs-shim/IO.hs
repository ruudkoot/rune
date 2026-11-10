module IO (module System.IO, module System.IO.Error, try, bracket, bracket_, catch) where
import System.IO
import System.IO.Error
import Control.Exception (catch)
try :: IO a -> IO (Either IOError a)
try = tryIOError
bracket :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
bracket before after m = do { x <- before; rs <- try (m x); after x; case rs of { Right r -> return r; Left e -> ioError e } }
bracket_ :: IO a -> (a -> IO b) -> IO c -> IO c
bracket_ before after m = do { x <- before; rs <- try m; after x; case rs of { Right r -> return r; Left e -> ioError e } }
