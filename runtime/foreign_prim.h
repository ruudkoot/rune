/* The trusted binary bridge. Resource identities and scalar bits use
   little-endian 64-bit words; native addresses never enter these strings.
   Operation families are independent of the number of bound functions. */
static uint64_t foreign_u64(const unsigned char *bytes) {
    uint64_t word = 0;
    for (unsigned i = 0; i < 8; i++) word |= (uint64_t)bytes[i] << (8 * i);
    return word;
}
static void foreign_bytes(unsigned char *bytes, uint64_t word) {
    for (unsigned i = 0; i < 8; i++) bytes[i] = (unsigned char)(word >> (8 * i));
}
static int p_foreign(VM *vm) {
    check_tag(vm, ARG(4), T_INT, "foreign");
    check_tag(vm, ARG(3), T_WORD64, "foreign");
    check_tag(vm, ARG(2), T_WORD64, "foreign");
    Obj *meta = check_obj(vm, ARG(1), K_STRING, "foreign");
    Obj *input = check_obj(vm, ARG(0), K_STRING, "foreign");
    int64_t operation = val_imm(ARG(4));
    uint64_t id = val_word64(ARG(3)), auxiliary = val_word64(ARG(2)), result_id = 0;
    size_t nmeta = obj_len(meta), ninput = obj_len(input), noutput = 0;
    const unsigned char *metadata = (const unsigned char *)obj_bytes(meta);
    const unsigned char *data = (const unsigned char *)obj_bytes(input);
    unsigned char scalar[8] = {0}, *output = scalar;
    int ok = 1, own_output = 0;
    ForeignError error;
    memset(&error, 0, sizeof error);
    if (operation == 0) result_id = (uint64_t)foreign_available();
    else if (operation == 11) result_id = foreign_target();
    else {
        if (!vm->foreign) {
            ForeignSystem system = {sys_library_open, sys_library_symbol, sys_library_close,
                                    sys_library_error, sys_foreign_capture};
            vm->foreign = foreign_create(&system);
            if (!vm->foreign) { error.error_number = ENOMEM; strcpy(error.message, "foreign context allocation failed"); ok = 0; }
        }
        if (ok) switch (operation) {
        case 1: result_id = foreign_library(vm->foreign, (const char *)metadata, nmeta); ok = result_id != 0; break;
        case 2: result_id = foreign_symbol(vm->foreign, id, (const char *)metadata, nmeta); ok = result_id != 0; break;
        case 3:
            if (auxiliary > SIZE_MAX) { ok = 0; error.error_number = ERANGE; break; }
            result_id = foreign_memory(vm->foreign, (size_t)auxiliary); ok = result_id != 0; break;
        case 4:
            if (nmeta != 8 || auxiliary > SIZE_MAX || foreign_u64(metadata) > MAX_STRING) {
                ok = 0; error.error_number = ERANGE; break;
            }
            noutput = (size_t)foreign_u64(metadata);
            output = malloc(noutput ? noutput : 1); own_output = 1;
            if (!output) { ok = 0; error.error_number = ENOMEM; break; }
            ok = foreign_read(vm->foreign, id, (size_t)auxiliary, output, noutput) == 0; break;
        case 5:
            if (auxiliary > SIZE_MAX) { ok = 0; error.error_number = ERANGE; break; }
            ok = foreign_write(vm->foreign, id, (size_t)auxiliary, data, ninput) == 0; break;
        case 6:
            if (nmeta != 8 || auxiliary > SIZE_MAX || foreign_u64(metadata) > SIZE_MAX) {
                ok = 0; error.error_number = ERANGE; break;
            }
            result_id = foreign_view(vm->foreign, id, (size_t)auxiliary, (size_t)foreign_u64(metadata)); ok = result_id != 0; break;
        case 7: ok = foreign_release(vm->foreign, id) == 0; break;
        case 8: {
            if (nmeta < 2 || nmeta - 2 > 1024) { ok = 0; error.error_number = EINVAL; break; }
            ForeignType arguments[1024];
            for (size_t i = 2; i < nmeta; i++) arguments[i - 2] = (ForeignType)metadata[i];
            result_id = foreign_prepare(vm->foreign, id, metadata[0], (ForeignType)metadata[1], arguments, nmeta - 2);
            ok = result_id != 0; break;
        }
        case 9: {
            if (ninput % 9 || ninput / 9 > 1024) { ok = 0; error.error_number = EINVAL; break; }
            size_t count = ninput / 9;
            ForeignValue arguments[1024], result;
            for (size_t i = 0; i < count; i++) {
                arguments[i].type = (ForeignType)data[i * 9];
                uint64_t word = foreign_u64(data + i * 9 + 1);
                if (arguments[i].type == FOREIGN_F32 || arguments[i].type == FOREIGN_F64)
                    memcpy(&arguments[i].value.real, &word, sizeof word);
                else arguments[i].value.word = word;
            }
            ok = foreign_call(vm->foreign, id, arguments, count, &result, &error) == 0;
            if (ok) {
                if (result.type == FOREIGN_POINTER) result_id = result.value.pointer;
                else if (result.type != FOREIGN_VOID) {
                    uint64_t word;
                    if (result.type == FOREIGN_F32 || result.type == FOREIGN_F64) memcpy(&word, &result.value.real, sizeof word);
                    else word = result.value.word;
                    foreign_bytes(scalar, word); noutput = 8;
                }
            }
            break;
        }
        case 10: result_id = foreign_live(vm->foreign); break;
        default: ok = 0; error.error_number = EINVAL; strcpy(error.message, "unknown foreign operation"); break;
        }
        if (!ok && !error.error_number) error = *foreign_error(vm->foreign);
    }
    if (!ok && !error.message[0]) {
        const char *message = sys_error_msg(error.error_number);
        size_t n = strlen(message); if (n >= sizeof error.message) n = sizeof error.message - 1;
        memcpy(error.message, message, n); error.message[n] = 0;
    }
    if (!ok) noutput = 0;
    /* C never retains a heap address. Once native work is over, root every
       partial SML result on the VM stack through each following allocation. */
    vm_push(vm, mk_bool(ok));
    vm_push(vm, mk_word64(result_id));
    vm_push(vm, mk_ptr(vm_string_from(vm, (const char *)output, (uint32_t)noutput)));
    if (own_output) free(output);
    vm_push(vm, mk_ptr(vm_string_from(vm, error.message, (uint32_t)strlen(error.message))));
    vm_push(vm, mk_int(error.error_number));
    vm_push(vm, mk_word(error.native_error));
    Obj *result = vm_alloc_fields(vm, K_TUPLE, 0, 6);
    for (int i = 5; i >= 0; i--) obj_fill_field(result, (uint32_t)i, vm_pop(vm));
    return ret(vm, 5, mk_ptr(result));
}
