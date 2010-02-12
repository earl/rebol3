/*
** dyncall.c -- A dyncall extension for REBOL3
**
** Copyright (C) 2010 Andreas Bolka <a AT bolka DOT at>
** Licensed under the terms of the Apache License, Version 2.0
*/

#include "reb-c.h"
#include "reb-ext.h"

#include <assert.h>
#include <dyncall.h>

const char *init_block =
    "REBOL [\n"
        "Title: {dyncall extension}\n"
        "Name: dyncall\n"
        "Author: Andreas Bolka\n"
        "Type: extension\n"
        "Exports: [dyncall]\n"
    "]\n"
    "dyncall: command [\n"
        "{Dynamically call a library function}\n"
        "library [file!]\n"
        "cconv  [word!]\n"
        "symbol [string!]\n"
        "spec [string!]\n"
        "args [block!]\n"
    "]\n"
;

RXIEXT const char *RX_Init(int opts, RXILIB *lib) {
    RXI = lib;
    if (lib->version == RXI_VERSION)
        return init_block;
    return 0;
}

RXIEXT int RX_Call(int cmd, RXIFRM *frm) {
    char *library, *symbol, *spec;
    RXI_GET_STRING(RXA_SERIES(frm, 1), RXA_INDEX(frm, 1), (void**)&library);
    RXI_GET_STRING(RXA_SERIES(frm, 3), RXA_INDEX(frm, 3), (void**)&symbol);
    RXI_GET_STRING(RXA_SERIES(frm, 4), RXA_INDEX(frm, 4), (void**)&spec);
    REBSER *args = RXA_SERIES(frm, 5);
    i32 args_i = RXA_INDEX(frm, 5);
    i32 args_n = RXI_SERIES_INFO(args, RXI_INFO_TAIL);

    void *dll = (void*)dlopen(library); /* FIXME use OS_OPEN_LIBRARY */
    void *fun = (void*)dlsym(dll, symbol); /* FIXME use OS_FIND_FUNCTION */

    DCCallVM* vm = dcNewCallVM(4096); /* FIXME magic number */
    dcMode(vm, DC_CALL_C_DEFAULT); /* FIXME handle cconv param */

    for (; args_i < args_n && *spec != ')'; ++args_i, ++spec) {
        RXIARG val;
        i32 val_type = RXI_GET_VALUE(args, args_i, &val);
        switch (*spec) {
            case 'i':
                assert(val_type == RXT_INTEGER && "Invalid argument type");
                dcArgInt(vm, val.int64);
                break;
            case 'd':
                assert(val_type == RXT_DECIMAL && "Invalid argument type");
                dcArgDouble(vm, val.dec64);
                break;
            default:
                assert(0 && "Unknown argument spec");
        }
    }
    assert(*spec++ == ')' && "Invalid spec");
    switch (*spec) {
        case 'i':
            RXA_INT64(frm, 1) = dcCallInt(vm, (DCpointer)fun);
            RXA_TYPE(frm, 1) = RXT_INTEGER;
            break;
        case 'd':
            RXA_DEC64(frm, 1) = dcCallDouble(vm, (DCpointer)fun);
            RXA_TYPE(frm, 1) = RXT_DECIMAL;
            break;
    }

    dcFree(vm);

    dlclose(dll); /* FIXME use OS_CLOSE_LIBRARY */

    return RXR_VALUE;
}
