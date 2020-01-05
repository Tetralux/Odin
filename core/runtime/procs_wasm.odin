package runtime

@(link_name="memmove")
@export memmove :: proc(dst, src: rawptr, len: int) -> rawptr {
    for i in 0..len-1 {
        src_ptr := cast(^u8) (uintptr(src) + uintptr(i));
        dst_ptr := cast(^u8) (uintptr(dst) + uintptr(i));
        dst_ptr^ = src_ptr^;
    }
    return dst;
}

@(link_name="memcpy")
@export memcpy :: inline proc(dst, src: rawptr, len: int) -> rawptr {
    return memmove(dst, src, len);
}