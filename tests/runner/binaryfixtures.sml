(* Independent metadata-only ELF/PE fixtures. They are never executed.
   ELF layouts: https://gabi.xinuos.com/elf/02-eheader.html and 07-pheader.html.
   PE layout: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format.
   Fixed, separated segments deliberately differ from the packager's former
   fixture writer, so the parser and its test do not share layout arithmetic. *)
structure BinaryFixtures =
struct
  exception Invalid of string
  fun need (ok, why) = if ok then () else raise Invalid why
  fun put array big offset width (value : IntInf.int) =
    let fun loop (i, value) =
          if i = width then need (value = 0, "fixture integer overflow") else
            let val byte = IntInf.toInt (IntInf.mod (value, 256))
                val index = offset + (if big then width - 1 - i else i)
            in Word8Array.update (array, index, Word8.fromInt byte); loop (i + 1, IntInf.div (value, 256)) end
    in need (value >= 0, "negative fixture integer"); loop (0, value) end
  fun text array offset value =
    CharVector.appi (fn (i, c) => Word8Array.update (array, offset + i, Word8.fromInt (Char.ord c))) value
  fun elf arch interpreter needed =
    let val (bits, big, machine) = case arch of "x86_64" => (64, false, 62)
          | "i686" => (32, false, 3) | "aarch64" => (64, false, 183)
          | "ppc64" => (64, true, 21) | _ => raise Invalid "unknown ELF fixture architecture"
        val data = Word8Array.array (1024, 0w0)
        fun number at width value = put data big at width (IntInf.fromInt value)
        val wide = bits = 64
        val word = if wide then 8 else 4
        val header = if wide then 64 else 52
        val entry = if wide then 56 else 32
        val base = 1048576
        val interp = interpreter ^ "\000"
        val strings = "\000" ^ String.concat (List.map (fn name => name ^ "\000") needed)
        val () = need (size interp < 128 andalso size strings < 128 andalso length needed < 12, "oversized ELF fixture")
        val () = text data 0 "\127ELF"
        val () = number 4 1 (if wide then 2 else 1)
        val () = number 5 1 (if big then 2 else 1)
        val () = number 6 1 1
        val () = number 16 2 2
        val () = number 18 2 machine
        val () = number 20 4 1
        val () = number (if wide then 32 else 28) word 128
        val () = number (if wide then 52 else 40) 2 header
        val () = number (if wide then 54 else 42) 2 entry
        val () = number (if wide then 56 else 44) 2 3
        fun segment (i, kind, offset, size, flags) =
          let val at = 128 + i * entry
              val () = number at 4 kind
          in if wide then
               (number (at + 4) 4 flags; number (at + 8) 8 offset; number (at + 16) 8 (base + offset);
                number (at + 24) 8 (base + offset); number (at + 32) 8 size; number (at + 40) 8 size; number (at + 48) 8 8)
             else
               (number (at + 4) 4 offset; number (at + 8) 4 (base + offset); number (at + 12) 4 (base + offset);
                number (at + 16) 4 size; number (at + 20) 4 size; number (at + 24) 4 flags; number (at + 28) 4 4) end
        val dynamicSize = (length needed + 2) * word * 2
        val () = segment (0, 1, 0, 1024, 5)
        val () = segment (1, 3, 512, size interp, 4)
        val () = segment (2, 2, 768, dynamicSize, 6)
        val () = text data 512 interp
        val () = text data 640 strings
        fun dynamic (i, tag, value) = (number (768 + i * word * 2) word tag; number (768 + (i * 2 + 1) * word) word value)
        fun libraries ([], _, i) = i
          | libraries (name :: rest, offset, i) = (dynamic (i, 1, offset); libraries (rest, offset + size name + 1, i + 1))
        val i = libraries (needed, 1, 0)
        val () = dynamic (i, 5, base + 640)
        val () = dynamic (i + 1, 0, 0)
    in Word8Array.vector data end
  fun pe machine =
    let val data = Word8Array.array (192, 0w0)
        val () = text data 0 "MZ"
        val () = put data false 60 4 128
        val () = text data 128 "PE\000\000"
        val () = put data false 132 2 (IntInf.fromInt machine)
    in Word8Array.vector data end
  fun write file bytes = let val output = BinIO.openOut file
                        in BinIO.output (output, bytes); BinIO.closeOut output end
end
