/* * Exemple simplifié de programme P4 pour la classification QoS 
 * Ce code permet d'identifier les flux vidéo (basé sur le port UDP)
 * et de leur appliquer une priorité haute directement dans le data plane.
 */

#include <core.p4>
#include <v1model.p4>

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    udp_t        udp;
}

/* --- PARSER --- */
parser MyParser(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t std_meta) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            17: parse_udp;
            default: accept;
        }
    }
    state parse_udp {
        packet.extract(hdr.udp);
        transition accept;
    }
}

/* --- INGRESS PROCESSING --- */
control MyIngress(inout headers hdr, inout metadata meta, inout standard_metadata_t std_meta) {
    
    action set_high_priority(bit<9> port) {
        std_meta.egress_spec = port;
        // Marquage du DSCP pour la QoS
        hdr.ipv4.diffserv = 0xB8; // EF (Expedited Forwarding)
    }

    table qos_routing {
        key = {
            hdr.udp.dstPort: exact;
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            set_high_priority;
            drop;
        }
        size = 1024;
    }

    apply {
        if (hdr.ipv4.isValid() && hdr.udp.isValid()) {
            qos_routing.apply();
        }
    }
}

control MyComputeChecksum(inout headers hdr, inout metadata meta) { apply { } }
control MyEgress(inout headers hdr, inout metadata meta, inout standard_metadata_t std_meta) { apply { } }
control MyDeparser(packet_out packet, in headers hdr) { apply { packet.emit(hdr); } }

V1Model(MyParser(), MyComputeChecksum(), MyIngress(), MyEgress(), MyComputeChecksum(), MyDeparser())