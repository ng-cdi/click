# inveb3 hping3 -S -s 80 -p 10000 --keep 10.0.0.1
#  c1 hping3 -S -s 10000 -p 80 --keep 10.0.0.254


AddressInfo(
  client1   10.1.0.2 10.1.0.0/24	00:00:00:01:00:01,
  client2   10.1.0.3 10.1.0.0/24	00:00:00:01:00:02,
  client3   10.1.0.4 10.1.0.0/24	00:00:00:01:00:03,
  client4   10.1.0.5 10.1.0.0/24	00:00:00:01:00:04,
  client5   10.1.0.6 10.1.0.0/24	00:00:00:01:00:05,
  frontend  10.1.0.1 10.1.0.0/24	00:00:00:01:00:ff,
  backends  10.0.0.1 10.0.0.0/24 	00:00:00:00:00:ff,
  backend1  10.0.0.2 10.0.0.0/24 	00:00:00:00:00:01,
  backend2  10.0.0.3 10.0.0.0/24 	00:00:00:00:00:02,
  backend3  10.0.0.4 10.0.0.0/24 	00:00:00:00:00:03,
  backend4  10.0.0.5 10.0.0.0/24 	00:00:00:00:00:04,
  backend5  10.0.0.6 10.0.0.0/24 	00:00:00:00:00:05
);


eth_classifier0, eth_classifier1 :: Classifier( 12/0806 20/0001,
                                                12/0806 20/0002,
                                                12/0800,
                                                -
);

backend_map :: SourceIPHashMapper(5 0xbadbeef,
                                 backends - backend1 - 0 1 4055,
                                 backends - backend2 - 0 1 80147,
                                 backends - backend3 - 0 1 37181,
                                 backends - backend4 - 0 1 36356,
                                 backends - backend5 - 0 1 3719
);

backend_map_rr :: RoundRobinIPMapper(
                                 backends - backend1 - 0 1,
                                 backends - backend2 - 0 1,
                                 backends - backend3 - 0 1,
                                 backends - backend4 - 0 1,
                                 backends - backend5 - 0 1
);


rewriter :: MinionRewriter(backend_map_rr,
                       drop,
                       TCP_TIMEOUT 30,
                       TCP_DONE_TIMEOUT 30,
                       TCP_NODATA_TIMEOUT 30,
                       LOG_HOST "127.0.0.1",
                       STATE "/home/toucan/lb-click/config.csv"
);

from_clients :: FromDevice(click-eth0);
from_backends :: FromDevice(click-eth1);
// from_clients :: FromDevice(cs1-eth2);
// from_backends :: FromDevice(bs1-eth6);


// q1 :: Queue(1024);
// to_clients :: q1 -> ToDevice(tap0, BURST 512);
// q2 :: Queue(1024);
// to_backends :: q2 -> ToDevice(tap1, BURST 512);

to_clients :: Queue(1024000) -> ToDevice(click-eth0, BURST 51200);
to_backends :: Queue(1024000) -> ToDevice(click-eth1, BURST 51200);
// to_clients :: Queue(1024000) -> ToDevice(cs1-eth2, BURST 51200);
// to_backends :: Queue(1024000) -> ToDevice(bs1-eth6, BURST 51200);

from_clients -> [0]eth_classifier0;
from_backends -> [0]eth_classifier1;

eth_classifier0[0] -> Discard; // ARPResponder(clients) -> to_clients;
eth_classifier1[0] -> Discard; // ARPResponder(backends) -> to_backends;

eth_classifier0[1] -> Discard; // [1]arpq0;
eth_classifier1[1] -> Discard; // [1]arpq1;

//Clients
eth_classifier0[2] -> Strip(14) -> CheckIPHeader() -> IPPrint() -> [0]rewriter;

//Backends
eth_classifier1[2] -> Strip(14) -> CheckIPHeader() -> IPPrint() -> [1]rewriter;

eth_classifier0[3] -> Discard;
eth_classifier1[3] -> Discard;

rewriter[1] -> SetTCPChecksum() -> EtherEncap(0x800, frontend, client1) -> to_clients;
rewriter[0] -> SetTCPChecksum() -> EtherEncap(0x800, backends, backend1) -> to_backends;
