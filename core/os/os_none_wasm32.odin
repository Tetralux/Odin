package os

import "core:strings"

ARCH :: "wasm32";
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


_File_Time :: struct {
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
	_padding:      i32, // 32 bits of padding
	rdev:          u64, // Device ID, if device
	size:          i64, // Size of the file, in bytes
	block_size:    i64, // Optimal bllocksize for I/O
	blocks:        i64, // Number of 512-byte blocks allocated

	last_access:   _File_Time, // Time of last access
	modified:      _File_Time, // Time of last modification
	status_change: _File_Time, // Time of last status change

	_reserve1,
	_reserve2,
	_reserve3:     i64,
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

foreign _ {
    @(link_name="host.print") wasm_write_to_stdout :: proc "c" (ptr: rawptr, len: i32) -> i32 ---;
}


open :: proc(path: string, flags: int = O_RDONLY, mode: int = 0) -> (Handle, Errno) {
	return INVALID_HANDLE, ENOSYS;
}

close :: proc(fd: Handle) -> Errno {
	return ENOSYS;
}

read :: proc(fd: Handle, data: []byte) -> (int, Errno) {
	return -1, ENOSYS;
}

write :: proc(fd: Handle, data: []byte) -> (int, Errno) {
    // if fd == stdout {
    //     wasm_write_to_stdout(#no_bounds_check &data[0], i32(len(data)));
    //     return int(i32(len(data))), ERROR_NONE;
    // }
	return -1, ENOSYS;
}

fstat :: proc(fd: Handle) -> (Stat, Errno) {
    return {}, ENOSYS;
}

ERROR_NONE:    	Errno : 0;
EPERM:         	Errno : 1;
ENOENT:        	Errno : 2;
ESRCH:         	Errno : 3;
EINTR:         	Errno : 4;
EIO:           	Errno : 5;
ENXIO:         	Errno : 6;
EBADF:         	Errno : 9;
EAGAIN:        	Errno : 11;
ENOMEM:        	Errno : 12;
EACCES:        	Errno : 13;
EFAULT:        	Errno : 14;
EEXIST:        	Errno : 17;
ENODEV:        	Errno : 19;
ENOTDIR:       	Errno : 20;
EISDIR:        	Errno : 21;
EINVAL:        	Errno : 22;
ENFILE:        	Errno : 23;
EMFILE:        	Errno : 24;
ETXTBSY:       	Errno : 26;
EFBIG:         	Errno : 27;
ENOSPC:        	Errno : 28;
ESPIPE:        	Errno : 29;
EROFS:         	Errno : 30;
EPIPE:         	Errno : 32;

EDEADLK: 		Errno :	35;	/* Resource deadlock would occur */
ENAMETOOLONG: 	Errno : 36;	/* File name too long */
ENOLCK: 		Errno : 37;	/* No record locks available */

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


current_thread_id :: proc "contextless" () -> int {
	return 1; // TODO: real value here
}



// TODO: better names for procs and args
foreign _ {
    // call this to get the current size of the heap
    @(link_name="llvm.wasm.memory.size.i32") __wasm_size :: proc(_: u32) -> u32 ---;

    // call this to grow the heap
    @(link_name="llvm.wasm.memory.grow.i32") __wasm_grow :: proc(_: u32, delta: u32) -> i32 ---;
}

heap_alloc :: proc(size: int) -> rawptr {
	return nil;
}
 
heap_free :: proc(old_memory: rawptr) {
	return;
}

heap_resize :: proc(ptr: rawptr, new_size: int) -> rawptr {
	return nil;
}