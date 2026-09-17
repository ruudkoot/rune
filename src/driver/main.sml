structure Main =
struct
  fun main (_ : string, args : string list) : OS.Process.status =
    (print ("rune " ^ Config.version ^ " (lib: " ^ Config.defaultLibDir ^ ") args=["
            ^ String.concatWith "," args ^ "] map-test="
            ^ Int.toString (StringMap.numItems (StringMap.fromList [("a", 1), ("b", 2), ("a", 3)])) ^ "\n");
     OS.Process.success)
end
