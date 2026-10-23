structure SdlContract=Win32ContractFn(struct structure Win32=Win32Sdl val name="sdl" end)
structure SdlContractMain =
struct
  fun main arguments=
    let val baseline=RuneForeign.live()
        val ()=Win32SdlDriver.load arguments
        val result=Suite.run{args=[],print=print}SdlContract.tests
        val errors=ref([]:string list)
        fun attempt label action=action() handle e=>errors:=(label ^ ": " ^ General.exnMessage e):: !errors
        val ()=attempt "model reset" Win32Sdl.reset
        val ()=attempt "driver shutdown" Win32SdlDriver.shutdown
        val ()=if RuneForeign.live()=baseline then () else errors:="native identities remain live":: !errors
        val ()=List.app(fn message=>TextIO.output(TextIO.stdErr,"FAIL SDL Win32 contract cleanup: " ^ message ^ "\n"))(rev(!errors))
    in if #failed result=0 andalso null(!errors) then () else OS.Process.exit OS.Process.failure end
end
val ()=SdlContractMain.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL SDL Win32 contract: " ^ (case e of
    Win32Common.Types.Error{function,code}=>function ^ ": " ^ Word32.toString code
  | Win32Common.Types.Unsupported text=>text | RuneForeign.Error{message,...}=>message
  | _=>General.exnMessage e) ^ "\n");OS.Process.exit OS.Process.failure)
