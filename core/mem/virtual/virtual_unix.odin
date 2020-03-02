//+build linux, darwin
package virtual;

import "core:os"
import "core:mem"

foreign import libc "system:c"

foreign libc {
	@(link_name="mprotect") _unix_mprotect :: proc(base: rawptr, size: u64, prot: i32) -> i32 ---;
	@(link_name="mmap")     _unix_mmap     :: proc(base: rawptr, size: u64, prot: i32, flags: i32, fd: os.Handle, offset: i32) -> rawptr ---;
	@(link_name="munmap")   _unix_munmap   :: proc(base: rawptr, size: u64) -> i32 ---;
	@(link_name="madvise")  _unix_madvise  :: proc(addr: rawptr, size: u64, advise: i32) -> i32 ---;
}


// NOTE(tetra): These constants are the same for all Unix-based operating systems.
MAP_FAILED :: -1;

PROT_NONE  :: 0;
PROT_READ  :: 1;
PROT_WRITE :: 2;
PROT_EXEC  :: 4;

MADV_NORMAL     :: 0; /* No further special treatment.  */
MADV_RANDOM     :: 1; /* Expect random page references.  */
MADV_SEQUENTIAL :: 2; /* Expect sequential page references.  */
MADV_WILLNEED   :: 3; /* Will need these pages.  */
MADV_DONTNEED   :: 4; /* Don't need these pages.  */


Memory_Access_Flag :: enum i32 {
	// NOTE(tetra): Order is important here.
	Read,
	Write,
	Execute,
}
Memory_Access_Flags :: bit_set[Memory_Access_Flag; i32]; // NOTE: For PROT_NONE, use `{}`.

// Reserve virtual address space, but do not commit it; it will not consume physical memory.
reserve :: proc(size: int, desired_base: rawptr = nil) -> (memory: []byte) {
	flags: i32 = MAP_PRIVATE | MAP_ANONYMOUS;
	if desired_base != nil do flags |= MAP_FIXED;

	// NOTE(tetra): Linux doesn't have a concept of seperate reserve and commit steps.
	// However, pages that are marked inaccessible are not committed and do not count towards
	// system resource usage; they are only reserved.
	ptr := _unix_mmap(desired_base, u64(size), PROT_NONE, flags, os.INVALID_HANDLE, 0);

	// NOTE: sets errno.
	if int(uintptr(ptr)) == MAP_FAILED do return;

	memory = mem.slice_ptr(cast(^u8) ptr, size);
	return;
}

// Reserve and commit virtual memory.
// Equivalent to calling reserve, then commit.
alloc :: proc(size: int, access := Memory_Access_Flags{.Read, .Write}, desired_base: rawptr = nil) -> (memory: []byte) {
	memory = reserve(size, desired_base);
	if memory == nil do return;

	assert(commit(memory, access));
	return;
}

// Frees all pages that overlap the given memory block.
free :: proc(memory: []byte) {
	page_size := os.get_page_size();
	assert(mem.align_forward(&memory[0], uintptr(page_size)) == &memory[0], "must start at page boundary");
	assert(_unix_munmap(&memory[0], u64(len(memory))) != MAP_FAILED);
}

// Commit pages to physical memory so they can be used.
//
// NOTE(tetra): On Linux, presumably with overcommit on, this doesn't actually
// commit the memory; that only happens when you write to the pages.
commit :: proc(memory: []byte, access := Memory_Access_Flags{.Read, .Write}) -> bool {
	assert(memory != nil);

	page_size := os.get_page_size();
	assert(mem.align_forward(&memory[0], uintptr(page_size)) == &memory[0], "must start at page boundary");
	set_access(memory, access);
	_ = _unix_madvise(&memory[0], u64(len(memory)), MADV_WILLNEED); // ignored, since advisory is not required
	return true; // TODO: maybe inline call to mprotect?; on Windows it's part of the virtualalloc call.
}

// Decommit pages that were previously committed, causing them to be removed from physical memory,
// and therefore freeing up system resources, but does not free the virtual memory; you may
// commit them again later.
decommit :: proc(memory: []byte) {
	assert(memory != nil);

	page_size := os.get_page_size();
	assert(mem.align_forward(&memory[0], uintptr(page_size)) == &memory[0], "must start at page boundary");
	_ = _unix_madvise(&memory[0], u64(len(memory)), MADV_DONTNEED); // ignored, since advisory is not required
	set_access(memory, {});
}

set_access :: proc(memory: []byte, access: Memory_Access_Flags) {
	assert(memory != nil);

	page_size := os.get_page_size();
	assert(mem.align_forward(&memory[0], uintptr(page_size)) == &memory[0], "must start at page boundary");
	ret := _unix_mprotect(&memory[0], u64(len(memory)), transmute(i32) access);
	assert(ret == 0);
}
