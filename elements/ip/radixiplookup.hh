// -*- c-basic-offset: 4 -*-
#ifndef CLICK_RADIXIPLOOKUP_HH
#define CLICK_RADIXIPLOOKUP_HH
#include <click/glue.hh>
#include <click/element.hh>
#include "iproutetable.hh"
CLICK_DECLS

/*
=c

RadixIPLookup(ADDR1/MASK1 [GW1] OUT1, ADDR2/MASK2 [GW2] OUT2, ...)

=s IP, classification

IP lookup using a radix trie

=d

Performs IP lookup using a radix trie.  The first level of the trie has 256
buckets; each succeeding level has 16.  The maximum number of levels that will
be traversed is thus 7.

Expects a destination IP address annotation with each packet. Looks up that
address in its routing table, using longest-prefix-match, sets the destination
annotation to the corresponding GW (if specified), and emits the packet on the
indicated OUTput port.

Each argument is a route, specifying a destination and mask, an optional
gateway IP address, and an output port.

Uses the IPRouteTable interface; see IPRouteTable for description.

Warning: This element is experimental.

=h table read-only

Outputs a human-readable version of the current routing table.

=h lookup read-only

Reports the OUTput port and GW corresponding to an address.

=h add write-only

Adds a route to the table. Format should be `C<ADDR/MASK [GW] OUT>'. Should
fail if a route for C<ADDR/MASK> already exists, but currently does not.

=h set write-only

Sets a route, whether or not a route for the same prefix already exists.

=h remove write-only

Removes a route from the table. Format should be `C<ADDR/MASK>'.

=h ctrl write-only

Adds or removes a group of routes. Write `C<add>/C<set ADDR/MASK [GW] OUT>' to
add a route, and `C<remove ADDR/MASK>' to remove a route. You can supply
multiple commands, one per line; all commands are executed as one atomic
operation.

=a IPRouteTable, StaticIPLookup, LinearIPLookup, SortedIPLookup,
DirectIPLookup, LinuxIPLookup
*/

class RadixIPLookup : public IPRouteTable { public:
    
    RadixIPLookup();
    ~RadixIPLookup();

    const char *class_name() const		{ return "RadixIPLookup"; }
    const char *processing() const		{ return PUSH; }

    void notify_noutputs(int);
    void cleanup(CleanupStage);

    int add_route(const IPRoute&, bool, IPRoute*, ErrorHandler *);
    int remove_route(const IPRoute&, IPRoute*, ErrorHandler *);
    int lookup_route(IPAddress, IPAddress&) const;
    String dump_routes();

  private:

    class Radix;
    
    // Simple routing table
    Vector<IPRoute> _v;
    int _vfree;
    
    int32_t _default_key;
    Radix* _radix;
    
};



class RadixIPLookup::Radix { public:

    static Radix* make_radix(int bitshift, int n);
    static void free_radix(Radix*);

    Radix* change(uint32_t addr, uint32_t naddr, int key, uint32_t key_priority);
    static int lookup(const Radix*, int, uint32_t addr);
    
  private:

    int32_t _route_index;
    int _bitshift;
    int _n;
    int _nchildren;
    struct Child {
	int key;
	uint32_t key_priority;
	Radix* child;
    } _children[0];

    Radix()			{ }
    ~Radix()			{ }

    friend class RadixIPLookup;
    
};

inline int
RadixIPLookup::Radix::lookup(const Radix* r, int cur, uint32_t addr)
{
    while (r) {
	int i1 = addr >> r->_bitshift;
	addr &= (1 << r->_bitshift) - 1;
	if (r->_children[i1].key >= 0)
	    cur = r->_children[i1].key;
	r = r->_children[i1].child;
    }
    return cur;
}

CLICK_ENDDECLS
#endif
