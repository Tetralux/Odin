package main

import "core:fmt"
import "core:os"
import "core:bufio"
import "core:io"
import "core:strings"
import "core:mem"
import "core:mem/virtual"

main :: proc() {
	arena: virtual.Growing_Arena
	allocator := virtual.growing_arena_allocator(&arena)

	buf := make([]byte, 1024, allocator)
	fmt.println(buf)
}