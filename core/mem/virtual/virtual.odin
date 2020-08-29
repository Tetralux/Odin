package virtual

import "core:mem"
import "core:os"

// Returns a pointer to the first byte of the page that a pointer lies within.
// The pointer may point to any byte within the page.
enclosing_page_ptr :: proc(ptr: rawptr) -> rawptr {
	page_size := os.get_page_size();
	start := mem.align_backward(ptr, uintptr(page_size));
	return start;
}

// Returns a pointer to the first byte of the next page.
next_page_ptr :: proc(ptr: rawptr) -> rawptr {
	page_size := os.get_page_size();
	page := enclosing_page_ptr(ptr);
	start := mem.align_forward(rawptr(uintptr(page)+1), uintptr(page_size));
	return start;
}

// Returns a pointer to the first byte of the previous page.
previous_page_ptr :: proc(ptr: rawptr) -> rawptr {
	page_size := os.get_page_size();
	page := enclosing_page_ptr(ptr);
	start := mem.align_backward(rawptr(uintptr(page)-1), uintptr(page_size));
	return start;
}

// Given a number of bytes, returns the number of pages needed to contain it.
// ```odin
// assert(virtual.bytes_to_pages(4097) == 2); // assuming page size is 4096.
// ```
bytes_to_pages :: proc(size: int) -> int {
	page_size := os.get_page_size();
	bytes := mem.align_forward_uintptr(uintptr(size), uintptr(page_size));
	return int(bytes) / page_size;
}

// Given a number of pages, returns the number of bytes that is.
pages_to_bytes :: proc(num_pages: int) -> int {
	return num_pages * os.get_page_size();
}

// Gets a number of pages as a slice.
// The pointer may point to any of the bytes in the first page.
page_slice :: proc(ptr: rawptr, num_pages := 1) -> []byte {
	if num_pages <= 0 do return nil;

	page_ptr := cast(^byte) enclosing_page_ptr(ptr);
	bytes := pages_to_bytes(num_pages) * os.get_page_size();
	return mem.slice_ptr(page_ptr, bytes);
}


// A push buffer, just like `mem.Arena`, but which is backed by virtual memory.
//
// This means it can expand dynamically, up to a maximum size, but the backing
// memory remains contiguous.
//
// Only the amount currently in use actually takes up physical memory, rounded up to
// a multiple of the page size.
//
// Resetting this arena with `arena_free_all` will decommit the memory, freeing up physical memory.
//
// WARNING: attempting to write to a pointer within this arena that was returned by
// `arena_alloc` after `arena_free_all` has been called, will segfault.
// Attempting to modify data in the arena's virtual memory region before it has been
// returned from `arena_alloc` may also segfault.
Arena :: struct {
	memory: []byte,
	cursor: int,

	pages_committed: int,
	high_mark:       int, // largest number of bytes allocated

	desired_base_ptr: rawptr, // may be nil on first allocation
}

// Initialize an area with the given maximum size and base pointer.
// The max size can be abnormally huge, since only what you write to will be committed to physical memory.
@(require_results)
arena_init :: proc(va: ^Arena, max_size: int, desired_base_ptr: rawptr = nil) -> bool {
	if max_size == 0 do return true;

	memory := reserve(max_size, desired_base_ptr);
	if memory == nil do return false;

	va^ = {
		memory = memory,
		desired_base_ptr = desired_base_ptr,
	};
	return true;
}

// Frees all the allocations made using this arena.
// The virtual memory is decommitted, but not released.
// This will free up physical memory but keep the virtual address space reserved.
// You may then proceed as if you had only just created the arena and called `arena_init`.
arena_free_all :: proc(using va: ^Arena) {
	cursor = 0;
	decommit(memory);
}

// Gets a suitably-aligned pointer to a certain number of bytes of virtual memory in the arena.
// The arena should already be initialized.
arena_alloc :: proc(va: ^Arena, requested_size, alignment: int) -> rawptr {
	if va.memory == nil do return nil;

	// NOTE(tetra): Check the new region stays with the arena, commit the pages,
	// and shift up the cursor.

	ptr := &va.memory[va.cursor];
	ptr = cast(^byte) mem.align_forward(ptr, uintptr(alignment));

	new_cursor := mem.ptr_sub(ptr, raw_data(va.memory)) + requested_size;
	if new_cursor >= len(va.memory) do return nil;

	new_total_pages_needed := bytes_to_pages(new_cursor);
	if new_total_pages_needed > va.pages_committed {
		pages := page_slice(raw_data(va.memory), new_total_pages_needed);
		ok := commit(pages);
		assert(ok);
		va.pages_committed = new_total_pages_needed;
	}

	va.high_mark = max(va.high_mark, new_cursor);
	va.cursor = new_cursor;

	return ptr;
}

// Resizes a previous allocation.
// If `old_memory` is the latest allocation from this allocator, the allocation will be resized in-place.
// Otherwise, this is equivalent to calling `arena_alloc` and copying.
arena_realloc :: proc(va: ^Arena, old_memory: rawptr, old_size, size, alignment: int) -> rawptr {
	// NOTE(tetra): If we can't resize in place, copy to new allocation instead.
	old_memory_end := mem.ptr_offset(cast(^byte)old_memory, old_size);
	if old_memory == nil || old_memory_end != &va.memory[va.cursor] {
		ptr := arena_alloc(va, size, alignment);
		if ptr == nil do return nil;

		mem.copy(ptr, old_memory, old_size);
		return ptr;
	}


	// NOTE(tetra): We were the last allocation; commit the new pages and shift up the cursor.

	new_cursor := va.cursor - old_size + size;
	if new_cursor >= len(va.memory) do return nil;

	new_total_pages_needed := bytes_to_pages(new_cursor);
	if new_total_pages_needed > va.pages_committed {
		pages := page_slice(raw_data(va.memory), new_total_pages_needed);
		ok := commit(pages);
		assert(ok);
		va.pages_committed = new_total_pages_needed;
	}

	va.high_mark = max(va.high_mark, new_cursor);
	va.cursor = new_cursor;

	return old_memory;
}

// Releases the virtual memory back to the system.
// Afterwards, the arena can be initialized again with `arena_init`.
arena_destroy :: proc(using va: ^Arena) {
	free(memory);
	va^ = {};
}

arena_allocator_proc :: proc(data: rawptr, mode: mem.Allocator_Mode,
                             size, alignment: int,
						     old_memory: rawptr, old_size: int,
						     flags: u64 = 0, loc := #caller_location) -> rawptr {
	arena := cast(^Arena) data;

	if old_memory != nil {
		index := mem.ptr_sub((^byte)(old_memory), raw_data(arena.memory));
		if index < 0 || index >= len(arena.memory) do panic("memory does not belong to this allocator", loc);
	}

	switch mode {
	case .Alloc:
		return arena_alloc(arena, size, alignment);
	case .Free:
		// do nothing
	case .Free_All:
		arena_free_all(arena);
	case .Resize:
		return arena_realloc(arena, old_memory, old_size, size, alignment);
	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory);
		if set != nil {
			set^ = {.Alloc, .Free_All, .Resize, .Query_Features};
		}
		return set;
	case .Query_Info:
		// TODO(tetra): consider if we should use this
		return nil;
	}

	return nil;
}

arena_allocator :: proc(arena: ^Arena) -> mem.Allocator {
	return {
		procedure = arena_allocator_proc,
		data = arena,
	};
}


Arena_Temp_Memory :: struct {
	arena:  ^Arena,
	cursor: int,
}

// Creates a "mark" which you can snap back to later.
// Useful if you want to make a bunch of allocations, but want to release them all
// shortly afterwards, without effecting anything allocated before them.
// ```odin
// {
//     mark := virtual.arena_begin_temp_memory(arena);
//     defer virtual.arena_end_temp_memory(mark);
//
//     // do allocations here
// } // .. which are then released here
// ```
arena_begin_temp_memory :: proc(using va: ^Arena) -> Arena_Temp_Memory {
	return {
		arena = va,
		cursor = cursor,
	};
}

// Reset back to a previous mark, freeing all of the memory allocations since then.
// This will decommit any extra pages that have been committed since the mark.
arena_end_temp_memory :: proc(mark: Arena_Temp_Memory) {
	using mark := mark;

	if arena.cursor == 0 do return;

	// NOTE(tetra): We cannot decommit the page that the old cursor lies in, only
	// the pages after it.

	// TODO(tetra): Decommit at all? Decommit only in chunks and not pages, to reduce syscall count?

	ptr := &arena.memory[cursor];
	start := enclosing_page_ptr(ptr);
	if start < ptr {
		// NOTE(tetra): If the cursor's on the first byte of a page, we don't need to decommit
		// that page, since the cursor points to the next location _available_, and not
		// the next index that's _in use._
		start = next_page_ptr(start);
	}

	decommit_cursor := mem.ptr_sub((^byte)(start), raw_data(arena.memory));
	if arena.cursor > decommit_cursor {
		decommit(arena.memory[decommit_cursor:]);
		pages := bytes_to_pages(arena.cursor - decommit_cursor);
		arena.pages_committed -= pages;
	}

	arena.cursor = cursor;
}