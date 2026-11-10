-- Module IO, section 21.11 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002 with its published
-- errata applied: a modified version of the Report's code, which does not
-- define Haskell 98. LICENSE says what was changed; errata.tsv and
-- overlay.tsv list each change, and pristine/ holds the code as printed.
module IO {- export list omitted -} where

-- Just provide an implementation of the system-independent
-- actions that IO exports.

try            :: IO a -> IO (Either IOError a)
try f          =  catch (do r <- f
                            return (Right r))
                        (return . Left)

bracket        :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
bracket before after m = do
        x  <- before
        rs <- try (m x)
        after x
        case rs of
           Right r -> return r
           Left  e -> ioError e

-- variant of the above where middle computation doesn't want x
bracket_        :: IO a -> (a -> IO b) -> IO c -> IO c
bracket_ before after m = do
         x  <- before
         rs <- try m
         after x
         case rs of
            Right r -> return r
            Left  e -> ioError e
