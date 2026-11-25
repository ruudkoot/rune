{-# LANGUAGE RebindableSyntax, PackageImports #-}
-- Foreign.C.Error (T10 chapter 26): base's, except the eight functions whose type names Num, which are base's code
-- over the shim's Num.
module Foreign.C.Error (
    Errno(Errno), eOK, e2BIG, eACCES, eADDRINUSE, eADDRNOTAVAIL, eADV,
    eAFNOSUPPORT, eAGAIN, eALREADY, eBADF, eBADMSG, eBADRPC, eBUSY,
    eCHILD, eCOMM, eCONNABORTED, eCONNREFUSED, eCONNRESET, eDEADLK,
    eDESTADDRREQ, eDIRTY, eDOM, eDQUOT, eEXIST, eFAULT, eFBIG, eFTYPE,
    eHOSTDOWN, eHOSTUNREACH, eIDRM, eILSEQ, eINPROGRESS, eINTR, eINVAL,
    eIO, eISCONN, eISDIR, eLOOP, eMFILE, eMLINK, eMSGSIZE, eMULTIHOP,
    eNAMETOOLONG, eNETDOWN, eNETRESET, eNETUNREACH, eNFILE, eNOBUFS,
    eNODATA, eNODEV, eNOENT, eNOEXEC, eNOLCK, eNOLINK, eNOMEM, eNOMSG,
    eNONET, eNOPROTOOPT, eNOSPC, eNOSR, eNOSTR, eNOSYS, eNOTBLK,
    eNOTCONN, eNOTDIR, eNOTEMPTY, eNOTSOCK, eNOTTY, eNXIO, eOPNOTSUPP,
    ePERM, ePFNOSUPPORT, ePIPE, ePROCLIM, ePROCUNAVAIL, ePROGMISMATCH,
    ePROGUNAVAIL, ePROTO, ePROTONOSUPPORT, ePROTOTYPE, eRANGE, eREMCHG,
    eREMOTE, eROFS, eRPCMISMATCH, eRREMOTE, eSHUTDOWN, eSOCKTNOSUPPORT,
    eSPIPE, eSRCH, eSRMNT, eSTALE, eTIME, eTIMEDOUT, eTOOMANYREFS,
    eTXTBSY, eUSERS, eWOULDBLOCK, eXDEV, isValidErrno, getErrno,
    resetErrno, errnoToIOError, throwErrno, throwErrnoIf, throwErrnoIf_,
    throwErrnoIfRetry, throwErrnoIfRetry_, throwErrnoIfMinus1,
    throwErrnoIfMinus1_, throwErrnoIfMinus1Retry, throwErrnoIfMinus1Retry_,
    throwErrnoIfNull, throwErrnoIfNullRetry, throwErrnoIfRetryMayBlock,
    throwErrnoIfRetryMayBlock_, throwErrnoIfMinus1RetryMayBlock,
    throwErrnoIfMinus1RetryMayBlock_, throwErrnoIfNullRetryMayBlock,
    throwErrnoPath, throwErrnoPathIf, throwErrnoPathIf_,
    throwErrnoPathIfNull, throwErrnoPathIfMinus1, throwErrnoPathIfMinus1_
  ) where
import "base" Prelude (Eq(..), String, IO, FilePath)
import "base" Foreign.C.Error hiding (throwErrnoIfMinus1, throwErrnoIfMinus1_, throwErrnoIfMinus1Retry,
    throwErrnoIfMinus1Retry_, throwErrnoIfMinus1RetryMayBlock, throwErrnoIfMinus1RetryMayBlock_,
    throwErrnoPathIfMinus1, throwErrnoPathIfMinus1_)
import H2010.Classes

throwErrnoIfMinus1 :: (Eq a, Num a) => String -> IO a -> IO a
throwErrnoIfMinus1 = throwErrnoIf (== -1)
throwErrnoIfMinus1_ :: (Eq a, Num a) => String -> IO a -> IO ()
throwErrnoIfMinus1_ = throwErrnoIf_ (== -1)
throwErrnoIfMinus1Retry :: (Eq a, Num a) => String -> IO a -> IO a
throwErrnoIfMinus1Retry = throwErrnoIfRetry (== -1)
throwErrnoIfMinus1Retry_ :: (Eq a, Num a) => String -> IO a -> IO ()
throwErrnoIfMinus1Retry_ = throwErrnoIfRetry_ (== -1)
throwErrnoIfMinus1RetryMayBlock :: (Eq a, Num a) => String -> IO a -> IO b -> IO a
throwErrnoIfMinus1RetryMayBlock = throwErrnoIfRetryMayBlock (== -1)
throwErrnoIfMinus1RetryMayBlock_ :: (Eq a, Num a) => String -> IO a -> IO b -> IO ()
throwErrnoIfMinus1RetryMayBlock_ = throwErrnoIfRetryMayBlock_ (== -1)
throwErrnoPathIfMinus1 :: (Eq a, Num a) => String -> FilePath -> IO a -> IO a
throwErrnoPathIfMinus1 = throwErrnoPathIf (== -1)
throwErrnoPathIfMinus1_ :: (Eq a, Num a) => String -> FilePath -> IO a -> IO ()
throwErrnoPathIfMinus1_ = throwErrnoPathIf_ (== -1)
