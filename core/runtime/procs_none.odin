//+build none
package runtime

@(link_name="memset")
memset :: proc "c" (ptr: rawptr, val: i32, len: int) -> rawptr {
    b := byte(val);

    p_start := uintptr(ptr);
    p_end := p_start + uintptr(max(len, 0));
    for p := p_start; p < p_end; p += 1 {
        (^byte)(p)^ = b;
    }

    return ptr;
}

@(link_name="memmove")
@export memmove :: proc "c" (dst, src: rawptr, len: int) -> rawptr {
    for i in 0..len-1 {
        src_ptr := cast(^u8) (uintptr(src) + uintptr(i));
        dst_ptr := cast(^u8) (uintptr(dst) + uintptr(i));
        dst_ptr^ = src_ptr^;
    }
    return dst;
}

@(link_name="memcpy")
@export memcpy :: proc "c" (dst, src: rawptr, len: int) -> rawptr {
    return memmove(dst, src, len);
}