package os

import "core:strings"
import "core:c"
import "core:mem"

OS     :: "none";
ARCH   :: "wasm32";
ENDIAN :: "little";

Handle :: distinct i32;
Errno  :: distinct u32;

stdout: Handle : 0;
stderr: Handle : 1;
stdin:  Handle : 2;

INVALID_HANDLE :: ~Handle(0);

@(link_name="__errno_location") 
@export __errno_location :: proc() -> ^int {
	return &errno;
}
@thread_local errno: int;

// NOTE(tetra): __stack_pointer provided by wasm-ld I think?
// NOTE(tetra): Stack grows upwards from __data_end and heap grows upwards from __heap_base;
//              Stack size is therefore the difference between these pointers.
//              Stack size is set at link time.
foreign _ {
	__heap_base: rawptr;
	__data_end:  rawptr;

	// call this to get the current size of the heap
	@(link_name="llvm.wasm.memory.size.i32") __wasm_size :: proc(_: u32) -> u32 ---;
	// call this to grow the heap
	@(link_name="llvm.wasm.memory.grow.i32") __wasm_grow :: proc(current_pages_allocated: i32, delta: u32) -> i32 ---; // .. I think?
}

File_Time :: struct {
	seconds:     i64,
	nanoseconds: i64,
}

Stat :: struct {
	device_id:     u64, // ID of device containing file
	serial:        u64, // File serial number
	nlink:         u64, // Number of hard links
	mode:          u32, // Mode of the file
	uid:           u32, // User ID of the file's owner
	gid:           u32, // Group ID of the file's group
	_:             i32, // 32 bits of padding
	rdev:          u64, // Device ID, if device
	size:          i64, // Size of the file, in bytes
	block_size:    i64, // Optimal bllocksize for I/O
	blocks:        i64, // Number of 512-byte blocks allocated

	last_access:   File_Time, // Time of last access
	modified:      File_Time, // Time of last modification
	status_change: File_Time, // Time of last status change

	_: i64,
	_: i64,
	_: i64,
};



get_last_error :: proc() -> int {
	return __errno_location()^;
}

O_RDONLY   :: 0x00000;
O_WRONLY   :: 0x00001;
O_RDWR     :: 0x00002;
O_CREATE   :: 0x00040;
O_EXCL     :: 0x00080;
O_NOCTTY   :: 0x00100;
O_TRUNC    :: 0x00200;
O_NONBLOCK :: 0x00800;
O_APPEND   :: 0x00400;
O_SYNC     :: 0x01000;
O_ASYNC    :: 0x02000;
O_CLOEXEC  :: 0x80000;

when ODIN_NO_CRT {
	// NOTE(tetra): With no-crt, we have no way to output to stdout; there _is no_ stdout.
	// These are just shims for if you do actually want to.
	foreign _ {
		@(link_name="write", weak_linkage) __wasm_write :: proc "c" (fd: Handle, buf: rawptr, bytes: int, written: ^int) -> Errno ---;
		@(link_name="read",  weak_linkage) __wasm_read  :: proc "c" (fd: Handle, buf: rawptr, max_readable: int, read: ^int) -> Errno ---;
		@(link_name="exit",  weak_linkage) __wasm_exit  :: proc "c" (exit_code: int) -> ! ---;
	}
} else {
	foreign _ {
		@(link_name="__wasi_fd_write",  weak_linkage) __wasi_fd_write :: proc "c" (fd: Handle, iovs: rawptr, num_iovs: i32, written: ^c.size_t) -> Errno ---;
		@(link_name="__wasi_fd_read",   weak_linkage) __wasi_fd_read  :: proc "c" (fd: Handle, iovs: rawptr, num_iovs: c.size_t, read: ^c.size_t) -> Errno ---;
		@(link_name="__wasi_proc_exit", weak_linkage) __wasi_proc_exit :: proc "c" (exit_code: i32) -> ! ---;
	}
}

open :: proc(path: string, flags: int = O_RDONLY, mode: int = 0) -> (Handle, Errno) {
	return INVALID_HANDLE, ENOSYS;
}

close :: proc(fd: Handle) -> Errno {
	return ENOSYS;
}

read :: proc(fd: Handle, data: []byte) -> (int, Errno) {
	when ODIN_NO_CRT {
		read: int;
		if __wasm_read == nil do return -1, ENOSYS;
		err := __wasm_read(fd, &data[0], len(data), &read);
		return read, err;
	} else {
		read: i32;
		if __wasi_fd_read == nil do return -1, ENOSYS;
		err := __wasi_fd_read(fd, &data[0], len(data), &read);
		return read, err;
	}
}

write :: proc(fd: Handle, data: []byte) -> (int, Errno) {
	when ODIN_NO_CRT {
		written: int;
		if __wasm_write == nil do return -1, ENOSYS;
		err := __wasm_write(fd, &data[0], len(data), &written);
		return written, err;
	} else {
		written: i32;
		if __wasi_fd_write == nil do return -1, ENOSYS;
		err := __wasi_fd_write(fd, &data[0], 1, &written);
		return int(written), err;
	}
}

fstat :: proc(fd: Handle) -> (Stat, Errno) {
	return {}, ENOSYS;
}

ERROR_NONE: Errno : 0;
EPERM:      Errno : 1;
ENOENT:     Errno : 2;
ESRCH:      Errno : 3;
EINTR:      Errno : 4;
EIO:        Errno : 5;
ENXIO:      Errno : 6;
EBADF:      Errno : 9;
EAGAIN:     Errno : 11;
ENOMEM:     Errno : 12;
EACCES:     Errno : 13;
EFAULT:     Errno : 14;
EEXIST:     Errno : 17;
ENODEV:     Errno : 19;
ENOTDIR:    Errno : 20;
EISDIR:     Errno : 21;
EINVAL:     Errno : 22;
ENFILE:     Errno : 23;
EMFILE:     Errno : 24;
ETXTBSY:    Errno : 26;
EFBIG:      Errno : 27;
ENOSPC:     Errno : 28;
ESPIPE:     Errno : 29;
EROFS:      Errno : 30;
EPIPE:      Errno : 32;

EDEADLK:      Errno : 35;	/* Resource deadlock would occur */
ENAMETOOLONG: Errno : 36;	/* File name too long */
ENOLCK:       Errno : 37;	/* No record locks available */

ENOSYS: Errno : 38;	/* Invalid system call number */

ENOTEMPTY: 	Errno : 39;	/* Directory not empty */
ELOOP: 		Errno : 40;	/* Too many symbolic links encountered */
EWOULDBLOCK: Errno : EAGAIN;	/* Operation would block */
ENOMSG: 	Errno : 42;	/* No message of desired type */
EIDRM: 		Errno : 43;	/* Identifier removed */
ECHRNG: 	Errno : 44;	/* Channel number out of range */
EL2NSYNC: 	Errno : 45;	/* Level 2 not synchronized */
EL3HLT: 	Errno : 46;	/* Level 3 halted */
EL3RST: 	Errno : 47;	/* Level 3 reset */
ELNRNG: 	Errno : 48;	/* Link number out of range */
EUNATCH: 	Errno : 49;	/* Protocol driver not attached */
ENOCSI: 	Errno : 50;	/* No CSI structure available */
EL2HLT: 	Errno : 51;	/* Level 2 halted */
EBADE: 		Errno : 52;	/* Invalid exchange */
EBADR: 		Errno : 53;	/* Invalid request descriptor */
EXFULL: 	Errno : 54;	/* Exchange full */
ENOANO: 	Errno : 55;	/* No anode */
EBADRQC: 	Errno : 56;	/* Invalid request code */
EBADSLT: 	Errno : 57;	/* Invalid slot */
EDEADLOCK:  Errno : EDEADLK;
EBFONT: 	Errno : 59;	/* Bad font file format */
ENOSTR: 	Errno : 60;	/* Device not a stream */
ENODATA: 	Errno : 61;	/* No data available */
ETIME: 		Errno : 62;	/* Timer expired */
ENOSR: 		Errno : 63;	/* Out of streams resources */
ENONET: 	Errno : 64;	/* Machine is not on the network */
ENOPKG: 	Errno : 65;	/* Package not installed */
EREMOTE: 	Errno : 66;	/* Object is remote */
ENOLINK: 	Errno : 67;	/* Link has been severed */
EADV: 		Errno : 68;	/* Advertise error */
ESRMNT: 	Errno : 69;	/* Srmount error */
ECOMM: 		Errno : 70;	/* Communication error on send */
EPROTO: 	Errno : 71;	/* Protocol error */
EMULTIHOP: 	Errno : 72;	/* Multihop attempted */
EDOTDOT: 	Errno : 73;	/* RFS specific error */
EBADMSG: 	Errno : 74;	/* Not a data message */
EOVERFLOW: 	Errno : 75;	/* Value too large for defined data type */
ENOTUNIQ: 	Errno : 76;	/* Name not unique on network */
EBADFD: 	Errno : 77;	/* File descriptor in bad state */
EREMCHG: 	Errno : 78;	/* Remote address changed */
ELIBACC: 	Errno : 79;	/* Can not access a needed shared library */
ELIBBAD: 	Errno : 80;	/* Accessing a corrupted shared library */
ELIBSCN: 	Errno : 81;	/* .lib section in a.out corrupted */
ELIBMAX: 	Errno : 82;	/* Attempting to link in too many shared libraries */
ELIBEXEC: 	Errno : 83;	/* Cannot exec a shared library directly */
EILSEQ: 	Errno : 84;	/* Illegal byte sequence */
ERESTART: 	Errno : 85;	/* Interrupted system call should be restarted */
ESTRPIPE: 	Errno : 86;	/* Streams pipe error */
EUSERS: 	Errno : 87;	/* Too many users */
ENOTSOCK: 	Errno : 88;	/* Socket operation on non-socket */
EDESTADDRREQ: Errno : 89;	/* Destination address required */
EMSGSIZE: 	Errno : 90;	/* Message too long */
EPROTOTYPE: Errno : 91;	/* Protocol wrong type for socket */
ENOPROTOOPT: 	Errno : 92;	/* Protocol not available */
EPROTONOSUPPORT: Errno : 93;	/* Protocol not supported */
ESOCKTNOSUPPORT: Errno : 94;	/* Socket type not supported */
EOPNOTSUPP: 	Errno : 95;	/* Operation not supported on transport endpoint */
EPFNOSUPPORT: 	Errno : 96;	/* Protocol family not supported */
EAFNOSUPPORT: 	Errno : 97;	/* Address family not supported by protocol */
EADDRINUSE: 	Errno : 98;	/* Address already in use */
EADDRNOTAVAIL: 	Errno : 99;	/* Cannot assign requested address */
ENETDOWN: 		Errno : 100;	/* Network is down */
ENETUNREACH: 	Errno : 101;	/* Network is unreachable */
ENETRESET: 		Errno : 102;	/* Network dropped connection because of reset */
ECONNABORTED: 	Errno : 103;	/* Software caused connection abort */
ECONNRESET: 	Errno : 104;	/* Connection reset by peer */
ENOBUFS: 		Errno : 105;	/* No buffer space available */
EISCONN: 		Errno : 106;	/* Transport endpoint is already connected */
ENOTCONN: 		Errno : 107;	/* Transport endpoint is not connected */
ESHUTDOWN: 		Errno : 108;	/* Cannot send after transport endpoint shutdown */
ETOOMANYREFS: 	Errno : 109;	/* Too many references: cannot splice */
ETIMEDOUT: 		Errno : 110;	/* Connection timed out */
ECONNREFUSED: 	Errno : 111;	/* Connection refused */
EHOSTDOWN: 		Errno : 112;	/* Host is down */
EHOSTUNREACH: 	Errno : 113;	/* No route to host */
EALREADY: 		Errno : 114;	/* Operation already in progress */
EINPROGRESS: 	Errno : 115;	/* Operation now in progress */
ESTALE: 		Errno : 116;	/* Stale file handle */
EUCLEAN: 		Errno : 117;	/* Structure needs cleaning */
ENOTNAM: 		Errno : 118;	/* Not a XENIX named type file */
ENAVAIL: 		Errno : 119;	/* No XENIX semaphores available */
EISNAM: 		Errno : 120;	/* Is a named type file */
EREMOTEIO: 		Errno : 121;	/* Remote I/O error */
EDQUOT: 		Errno : 122;	/* Quota exceeded */

ENOMEDIUM: 		Errno : 123;	/* No medium found */
EMEDIUMTYPE: 	Errno : 124;	/* Wrong medium type */
ECANCELED: 		Errno : 125;	/* Operation Canceled */
ENOKEY: 		Errno : 126;	/* Required key not available */
EKEYEXPIRED: 	Errno : 127;	/* Key has expired */
EKEYREVOKED: 	Errno : 128;	/* Key has been revoked */
EKEYREJECTED: 	Errno : 129;	/* Key was rejected by service */

/* for robust mutexes */
EOWNERDEAD: 	Errno : 130;	/* Owner died */
ENOTRECOVERABLE: Errno : 131;	/* State not recoverable */

ERFKILL: 		Errno : 132;	/* Operation not possible due to RF-kill */

EHWPOISON: 		Errno : 133;	/* Memory page has hardware error */


file_size :: proc(fd: Handle) -> (i64, Errno) {
	return -1, ENOSYS;
}

get_page_size :: proc() -> int {
	return 64 * 1024; // 64K
}


current_thread_id :: proc "contextless" () -> int {
	return 1; // TODO: real value here
}

exit :: proc(exit_code: int) -> ! {
	when ODIN_NO_CRT {
		if __wasm_exit != nil do __wasm_exit(exit_code);
	} else {
		if __wasi_proc_exit != nil do __wasi_proc_exit(i32(exit_code));
	}
}

heap_alloc :: proc(size: int) -> rawptr {
	return nil;
}

heap_free :: proc(ptr: rawptr) {
	// TODO
}

heap_resize :: proc(ptr: rawptr, new_size: int) -> rawptr {
	return nil;
}

// @private heap_cursor: int;
// @private current_heap_size: int;
// @private current_heap_pages: int;

// @private
// Heap_Free_List :: struct {
// 	next: ^Heap_Free_List,
// 	len: u16,
// 	ptrs: [16382]rawptr,
// }

// @private heap_free_list: Heap_Free_List; // NOTE(tetra): initialized by heap_alloc

// // TODO: Improve.
// heap_alloc :: proc(size: int) -> rawptr {
// 	for i in 0..heap_free_list.len-1 {
// 		ptr := #no_bounds_check heap_free_list.ptrs[i];
// 		size_ptr := mem.ptr_offset((^i32)(ptr), -1);
// 		if int(size_ptr^) >= size {
// 			if i > 0 {
// 				heap_free_list.ptrs[i] = heap_free_list.ptrs[heap_free_list.len-1];
// 				heap_free_list.len -= 1;
// 			}
// 			return ptr;
// 		}
// 	}

// 	remaining := current_heap_size - heap_cursor;

// 	if (remaining < size) {
// 		page_size := get_page_size();

// 		pages_needed := 0;
// 		for remaining < size {
// 			pages_needed += 1;
// 			remaining += page_size;
// 		}

// 		// TODO(tetra): Handle grow failure
// 		_ = __wasm_grow(i32(current_heap_pages), u32(pages_needed));
// 		current_heap_size += page_size;
// 		current_heap_pages += pages_needed;
// 	}

// 	offset := heap_cursor + size_of(i32); // to store the size
// 	heap_cursor += size + size_of(i32);

// 	ptr := rawptr(uintptr(__heap_base) + uintptr(offset));

// 	offset_ptr := (^i32)(uintptr(ptr) - size_of(i32));
// 	assert(size < int(max(i32)));
// 	offset_ptr^ = i32(size);

// 	return ptr;
// }

// heap_free :: proc(old_memory: rawptr) {
// 	list := &heap_free_list;
// 	for list.next != nil do list = list.next;

// 	// TODO: alloc new list and chain it.
// 	assert(list.len+1 <= len(list.ptrs));

// 	list.ptrs[list.len] = old_memory;
// 	list.len += 1;
// }

// heap_resize :: proc(old_ptr: rawptr, new_size: int) -> rawptr {
// 	new_ptr := heap_alloc(new_size);
// 	if new_ptr == nil do return nil;

// 	size_ptr := mem.ptr_offset((^i32)(old_ptr), -1);
// 	mem.copy(new_ptr, old_ptr, int(size_ptr^));

// 	heap_free(old_ptr);
// 	return new_ptr;
// }