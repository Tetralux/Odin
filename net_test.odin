package net_test

import "core:net"
import "core:net/http"

import "core:strings"
import "core:time"
import "core:strconv"
import "core:thread"
import "core:sync"
import "core:mem"
import "core:os"

import "core:fmt"

main :: proc() {
	should_fetch := false
	mode : enum {None, Tcp, Udp}

	for arg in os.args {
		if arg[0] == '-' {
			cmd := arg[1:]
			switch cmd {
			case "dns": should_fetch = true
			case "udp":   mode = .Udp
			case "tcp":   mode = .Tcp
			}
		}
	}

	// extern_addr, parse_ok := net.parse_addr("::::fffe:fefd:fcfb:faf9");
	// extern_addr, parse_ok := net.parse_addr("10.0.2.15");
	// extern_addr, parse_ok := net.parse_addr("fe80::6b73:25c3:67e8:f8a1");
	// extern_addr, parse_ok := net.parse_addr("::1");
	// assert(parse_ok);
	// println(extern_addr);

	init_global_temporary_allocator(1 << 22)

	a := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&a, context.allocator)
	context.allocator = mem.tracking_allocator(&a)
	defer {
		if len(a.allocation_map) > 0 {
			for _, leak in a.allocation_map {
				fmt.printf("- %v: %v bytes leaked (%p)\n", leak.location, leak.size, leak.memory)
			}
		}
		if len(a.bad_free_array) > 0 {
			for leak in a.bad_free_array {
				fmt.printf("- %v: Bad free (%p)\n", leak.location, leak.memory)
			}
		}
	}

	when true {
		if should_fetch {
			fmt.printf("info: fetching DNS records...\n")
			fetch_records()
			fmt.println()
		} else {
			fmt.printf("info: not fetching any DNS records; pass -dns to change that.\n")
		}

		switch mode {
		case .Tcp:
			fmt.printf("info: interacting with TCP server...\n")
			tcp_local()
		case .Udp:
			fmt.printf("info: interacting with UDP server...\n")
			udp_local()
		case .None:
			fmt.printf("info: not doing any server interaction; pass -tcp or -udp to change that.\n")
		}
	} else when false {
		// NOTE: for testing timeout options work. TWEAK as appropriate
		// s, dial_err := net.dial_tcp(net.Ipv4_Loopback, 9000)
		s, make_err := net.make_unbound_udp_socket(.IPv6)
		assert(make_err == nil)

		// _, addr, ok := net.resolve("google.com")
		// assert(ok)
		// fmt.println(addr)
		addr := net.parse_address("192.168.0.32")
		n, send_err := net.send_udp(s, []byte{'h', 'i'}, net.Endpoint{addr, 9000})
		fmt.println(n, send_err)
		// if dial_err != nil do fmt.panicf("dial: %v", dial_err)

		// set_err := net.set_option(s, .Receive_Timeout, time.Millisecond * 3000)
		// if set_err != nil do fmt.panicf("dial: %v", set_err)
		// // TODO: set_option() currently expects milliseconds for the timeout options on Windows,
		// // but an os.Timeval on Linux. Decide how to unify them.

		// buf: [42]byte
		// n, read_err := net.recv(s, buf[:]) // Should block for 3000ms then return err=.Timeout
		// fmt.printf("n=%v, err=%v\n", n, read_err)
	} else {
		// NOTE: test UDP max dgram limits
		s, make_err := net.make_unbound_udp_socket(.IPv6)
		assert(make_err == nil)

		outbuf := make([]byte, 100)
		for _, i in outbuf do outbuf[i] = byte(i)

		sent, send_err := net.send_udp(s, outbuf, {net.Ipv6_Loopback, 9000})
		if send_err != nil do fmt.panicf("send failed: %v (%v)", send_err, (^i32)(&send_err)^)

		data_available :: proc(s: net.Udp_Socket) -> int {
			n, _, _ := net.recv_udp(s, []byte{})
			return n
		}

		// size_needed := data_available(s)
		inbuf := make([]byte, 10)
		recvd, src_addr, recv_err := net.recv_udp(s, inbuf)
		if recv_err == .Buffer_Too_Small {
			fmt.printf("recv failed: %v: got %v\n", recv_err, recvd)
			inbuf2 := make([]byte, 100)
			r2, _, r2e := net.recv_udp(s, inbuf2)
			assert(r2e == nil)
			fmt.println(r2, inbuf2[:r2])
		} else if recv_err != nil do fmt.panicf("recv failed: %v (%v)", recv_err, (^i32)(&recv_err)^)

		for i in 0..=recvd-1 {
			assert(outbuf[i] == inbuf[i])
		}
	}


	// // resp, ok := http.get("http://google.co.uk/search?q=toad");
	// resp, ok := http.get("http://icanhazip.com");
	// assert(ok);

	// fmt.println(resp.status_code, len(resp.body));
	// os.write_entire_file("google.html", transmute([]byte) resp.body);
}

fetch_records :: proc() {
	// recs, ok := net.get_dns_records_from_os("google.com", .SRV); // TWEAK this to test things
	recs, err := net.get_dns_records_from_os("_sip._tls.DUCLAVIER.COM", .SRV) // TWEAK this to test things
	if err != nil {
		fmt.println("could not fetch records: %v", err)
		return
	}
	if len(recs) == 0 {
		fmt.println("no records returned")
		return
	}
	defer net.destroy_dns_records(recs)
	for r in recs {
		fmt.printf(" - %v\n", r)
	}
}

m: sync.Mutex

tcp_local :: proc() {
	using fmt

	// Maybe you got this from a config file, so you
	// // don't know if it's a hostname or address.
	// ep_string := "192.168.0.32";
	ep_string := "localhost"

	// Resolving an address just returns the address.
	ep4, ep6, resolve_err := net.resolve(ep_string)
	if resolve_err != nil {
		printf("error: cannot resolve %v: %v\n", ep_string, resolve_err)
		return
	}
	ep := ep4
	ep.port = ep.port if ep.port != 0 else 9000


	// NOTE: use a thread pool to perform a bunch of connections.

	pool: thread.Pool
	thread.pool_init(&pool, 32)
	thread.pool_start(&pool)
	sync.mutex_init(&m)
	defer thread.pool_destroy(&pool)

	defer thread.pool_wait_and_process(&pool)

	lprintf :: proc(format: string, args: ..any) {
		sync.mutex_lock(&m)
		defer sync.mutex_unlock(&m)

		fmt.printf(format, ..args)
	}

	N :: 5
	for i in 0..=N-1 {
		thread.pool_add_task(&pool, proc(task: ^thread.Task) {
			ep := cast(^net.Endpoint) task.data
			s, err := net.dial_tcp(ep.address, ep.port)
			if err != nil {
				lprintf("error: cannot blocking dial: %v\n", err)
				return
			}
			defer {
				net.shutdown(s, .Both)
				net.close(s)
			}

			// opt_err := net.set_option(s, .Linger, time.Milliseconds * 3000)
			// if opt_err != nil do panicf("set_option() failed: %v (%v)\n", opt_err, (^i32)(&opt_err)^)

			// time.sleep(time.Duration(1e9));

			str := "Hello, World!"
			sent, send_err := net.send(s, transmute([]byte) str)
			assert(sent == len(str) && send_err == nil)
			lprintf("[%v] wrote %v bytes\n", task.user_index, len(str))

			buf: [4096]byte
			n, recv_err := net.recv(s, buf[:])
			if recv_err != nil {
				lprintf("[%v] error: recv failed: %v\n", task.user_index, recv_err)
				return
			}
			assert(n == len(str), "didn't echo correctly")
			recvd := buf[:len(str)]

			lprintf("[%v] Got %v bytes: '%v'\n", task.user_index, len(recvd), string(recvd))
		}, &ep, i)
	}
}


udp_local :: proc() {
	using fmt

	// TODO: threaded version

	addr := net.parse_address("::1")
	// addr := net.parse_address("fe80::e982:ee:f62b:d1c5");
	assert(addr != nil)

	s, create_err := net.make_unbound_udp_socket(net.family_from_address(addr))
	if create_err != nil {
		printf("error: dial failed: %v\n", create_err)
		return
	}
	defer net.close(s)

	local_endpoint := net.Endpoint{addr, 9000}

	str := "Hello, World!"
	sent, send_err := net.send(s, transmute([]byte) str, local_endpoint)
	if send_err != nil {
		printf("error: send failed: %v\n", send_err)
		return
	}
	assert(sent == len(str))
	printf("wrote %v bytes\n", len(str))

	buf: [4096]byte
	read, from_endpoint, recv_err := net.recv(s, buf[:])
	if recv_err != nil {
		printf("error: recv failed: %v (%v)\n", recv_err, int(recv_err.(net.UDP_Recv_Error)))
		return
	}
	printf("recv from %v\n", net.endpoint_to_string(from_endpoint))
	if read != len(str) {
		printf("error: recvd < %v (%v)\n", len(str), read)
		return
	}
	recvd := buf[:read]
	printf("recvd %v bytes: '%v'\n", read, string(recvd))
}
