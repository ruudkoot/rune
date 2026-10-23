structure Win32SdlExampleMain =
struct
  fun main arguments=case arguments of library::adapters::options=>
    let val ()=Win32SdlDriver.load[library,adapters]
        val status=Win32Example.main(List.exists(fn option=>option="--smoke")options)
          handle e=>((Win32SdlDriver.shutdown() handle _=>());raise e)
        val ()=Win32Sdl.reset()
        val ()=Win32SdlDriver.shutdown()
    in if status=Int32.fromInt 0 then () else OS.Process.exit OS.Process.failure end
    | _=>raise Fail "expected SDL library and generated adapter library paths"
end
val ()=Win32SdlExampleMain.main(CommandLine.arguments())
