structure P=BenchStdlibTextPrograms
val input=BenchStdlibText.Bytes.ofString BenchStdlibText.text
val _=List.app(fn name=>print(name^" "^P.runBytes input name 5^"\n"))
 ["bytes_get","bytes_set","bytes_cat","bytes_sub","bytes_blit","bytes_concat","bytes_iter","bytes_map","bytes_trim","bytes_index","bytes_contains","bytes_uppercase_ascii"]
val _=List.app(fn name=>print(name^" "^P.runString name 5^"\n"))
 ["string_get","string_sub","string_blit","string_concat","string_iter","string_map","string_trim","string_index","string_contains","string_uppercase_ascii","string_split_on_char","string_compare","string_equal"]
