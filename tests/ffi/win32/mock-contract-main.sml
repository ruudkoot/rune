structure MockContract=Win32ContractFn(struct structure Win32=Win32Mock val name="mock" end)
structure MockContractMain=Main(struct val name="win32/mock/contract" val tests=MockContract.tests end)
val ()=MockContractMain.main()
