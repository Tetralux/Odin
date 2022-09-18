package structzero

import "core:mem"
import "core:fmt"

main :: proc() {
    using fmt;

    S :: struct {
        i: i32,
        u: u64,
    };

    pb :: proc(s: ^S) {
        data := mem.ptr_to_bytes(s, 1);
        fmt.printf("%x\n", data);
    }

    s: S;
    pb(&s); println(s); println();

    data := mem.ptr_to_bytes(&s, 1);
    for b in &data {
        b = 0xaa;
    }
    pb(&s); println(s); println();

    s = {};
    pb(&s); println(s); println();
    /*
    [0, 0, 0, 0, aa, aa, aa, aa, 0, 0, 0, 0, 0, 0, 0, 0]
    S{i = 0, u = 0}
    */
}