{-# LANGUAGE PackageImports #-}
-- System.IO.Error (T10 chapter 42): base's, with the Report's catch and try (base's catchIOError and tryIOError).
module System.IO.Error (
    IOError, userError, mkIOError, annotateIOError, isAlreadyExistsError,
    isDoesNotExistError, isAlreadyInUseError, isFullError, isEOFError,
    isIllegalOperation, isPermissionError, isUserError, ioeGetErrorString,
    ioeGetHandle, ioeGetFileName, IOErrorType, alreadyExistsErrorType,
    doesNotExistErrorType, alreadyInUseErrorType, fullErrorType,
    eofErrorType, illegalOperationErrorType, permissionErrorType,
    userErrorType, ioError, catch, try
  ) where
import "base" Prelude (IO, Either)
import "base" System.IO.Error hiding (catch, try)
import "this" Prelude (catch)

try :: IO a -> IO (Either IOError a)
try = tryIOError
