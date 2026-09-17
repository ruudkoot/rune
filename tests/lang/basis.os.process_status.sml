val () = print (Int.toString OS.Process.success ^ Int.toString OS.Process.failure ^ Bool.toString (OS.Process.isSuccess OS.Process.success) ^ "\n")
val () = OS.Process.exit OS.Process.failure
