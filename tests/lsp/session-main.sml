val ()=case CommandLine.arguments () of [vm,worker] =>
  OS.Process.exit (RuneLspSession.serve {lib="lib",maxMessageBytes=16*1024*1024,workerCommand=vm,workerArgs=[worker]})
  | _ => OS.Process.exit OS.Process.failure
