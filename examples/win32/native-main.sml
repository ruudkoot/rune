val ()=
  let val smoke=List.exists(fn option=>option="--smoke")(CommandLine.arguments())
      val status=Win32Example.main smoke handle e=>((Win32Native.close() handle _=>());raise e)
      val ()=Win32Native.close()
  in if status=Int32.fromInt 0 then () else OS.Process.exit OS.Process.failure end
