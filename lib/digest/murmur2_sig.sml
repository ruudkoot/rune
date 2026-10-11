(* MurmurHash2, 32 bits (Austin Appleby's, on x86): a fast hash that is no
   digest -- it resists no adversary -- which tools agree on by name, as
   JupyterLab's debugger names a notebook's cell by the hash of its code.

   Area: Data formats *)
signature MURMUR2 =
sig
  (* `hash {seed, data}` is the hash of the bytes of `data` (a string of
     bytes: text as its UTF-8) from `seed`.

     Example: `hash {seed = 0w0, data = "a"} = 0w2456313694` *)
  val hash : {seed : Word32.word, data : string} -> Word32.word
end
