val () =
  ((case CommandLine.arguments () of
       ["faults"] => ProtocolFaults.one ()
     | ["fault-peer",mode,file] => ProtocolFaults.peer mode file ()
     | ["fault-client",mode,file] => ProtocolFaults.peerCheck mode file ()
     | ["fault-lost-interrupt"] => ProtocolChecks.kernelWith false true ()
     | ["repl",name] => ReplProtocolChecks.one name false ()
     | ["repl",name,"--update"] => ReplProtocolChecks.one name true ()
     | ["dap"] => ProtocolChecks.dap false ()
     | ["dap","--windows"] => ProtocolChecks.windows "dap" ()
     | ["dap-native"] => ProtocolChecks.dap true ()
     | ["kernel"] => ProtocolChecks.kernel false ()
     | ["kernel","--windows"] => ProtocolChecks.windows "kernel" ()
     | ["kernel-native"] => ProtocolChecks.kernel true ()
     | ["notebook"] => ProtocolChecks.notebook ()
     | ["interop",library,compiler,vm,directory] => ProtocolChecks.interop library compiler vm directory ()
     | _ => raise Fail "protocol-check repl NAME [--update] | dap/kernel [--windows] | notebook | interop LIB COMPILER VM OUT")
   handle e => (Sh.say ("FAIL protocol: " ^ (case e of ProtocolChecks.Failed text => text | KernelChecks.Failed text => text | DapChecks.Failed text => text
        | ProtocolIO.Failed text => text | ReplProtocolChecks.Failed text => text | Framing.Header text => text | Zmtp.Error text => text | _ => General.exnMessage e) ^ "\n");Posix.Process.exit 0w1))
