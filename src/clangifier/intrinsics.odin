package clangifier


import "core:os/os2"
import "core:path/filepath"


create_intrinsics :: proc() -> (src, header: ^os2.File) {
        err: os2.Error
        src, err = os2.create(filepath.join({OUT_BASE_DIR, "intrinsics.c"}))
        assert(err == nil)
        header, err = os2.create(filepath.join({OUT_BASE_DIR, "intrinsics.h"}))
        assert(err == nil)
        return
}


intrinsics :: `
typedef struct String {
        char const *data;
        unsigned int len;
} String;
`
