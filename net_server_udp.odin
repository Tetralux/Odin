package udp_test

import "core:fmt"
import "core:net"

main :: proc() {
    using fmt;

    addr := net.parse_address("::1");
    assert(addr != nil);

    s, create_err := net.make_bound_udp_socket(addr, 9000);
    if create_err != nil {
        printf("error: create failed: %v (%v)\n", create_err, int(create_err.(net.Bind_Error)));
        return;
    }
    defer net.close(s);
    printf("waiting for data on '%v'\n", net.address_to_string(addr));

    // println(net.set_option(s, .Broadcast, true))

    for {
        buf: [4096]byte;

        num_recvd, remote_addr, recv_err := net.recv(s, buf[:]);
        if recv_err != nil {
            printf("error: recv failed: %v (%v)\n", recv_err, int(recv_err.(net.UDP_Recv_Error)))
            return
        }
        if num_recvd == 0 {
            return
        }

        data_received := buf[:num_recvd]
        printf("[%v] recvd %v bytes (%q)\n", net.endpoint_to_string(remote_addr), num_recvd, data_received);

        num_sent, sent_err := net.send(s, data_received, remote_addr);
        if sent_err != nil {
            printf("[%v] error: send_to failed: %v\n", net.endpoint_to_string(remote_addr), sent_err);
            return;
        }
        if num_sent != num_recvd {
            printf("[%v] error: send_to < %v (%v)\n", net.endpoint_to_string(remote_addr), num_recvd, num_sent);
            return;
        }
        printf("[%v] sent %v bytes (%q)\n", net.endpoint_to_string(remote_addr), num_sent, data_received)
    }
}