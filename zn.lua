#!/usr/bin/env luajit
local ffi = require('ffi')
local C = ffi.load('zn')
local M = setmetatable({C=C},{__index = C})

-- todo : fix how lists of ZnIds are returned
-- do proper unreffing of loaded strings/data instead of interning/leaking all.

ffi.cdef[[
/*
1: Initializing ZN
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀                                                         */

typedef struct _Zn Zn; 
                                                                           /*
Zn is the core ZN instance reference, it carries most of the ZN state and is
passed in to almost all C level API calls as the first argument. 

zn_new creates a new Zn instance, db_path is either the root of the ZN
database or NULL to use per user default database.                         */

Zn * zn_new (const char *db_path);                                         
                                                                           /*
zn_destroy tears down an ZN instance - will free up resources and issue a leak
report if the ZN build is a debug build.                                   
                                                                           */
void zn_destroy (Zn *zn);
                                                                           /*

2: Storing and Retrieving Data
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

Data stored in ZN is immutable and never changes, if you change the name or
title of something the old string object still exists.  ZN manages data as
/blobs/, and mappings from these blob /objects/ to /ZNIds/ which are 64bit
integer handles natively on a machine or 256bit /hashes/ for
persistent/definitive storage and network transmission.

The 256bit id for a blob is a cryptographic hash of it's content.  The 64bit
ZnId's are based on storage offsets in a the on-disk representation. The
on-disk representation is directly mmapped and used from disk on 64bit and
when possible on 32bit. ZnId's can be considered stable between processes and
restarts on the same host.                                                 */

typedef  int64_t ZnId;
typedef  int64_t ZnSize;
                                                                           /*

zn_string is used to turn \0 terminated strings into ZnId's the same ZnId will
be returned if you call zn_string again with the same string as argument.  */

ZnId zn_string (Zn *zn, const char *string);                               /*

Usage:
  const ZnId string_id = zn_string (zn, "this is a string");


zn_get_length returns the length in bytes of the blob for the object       */

ZnSize zn_get_length (Zn *zn, ZnId id);
                                                                           /*

zn_printf allows you to quickly generate string with embedded information from
code in C, similar mechanisms wouldn't be neccesary in python or ruby.     */

ZnId zn_printf (Zn *zn, const char *fmt, ...);                             /*


zn_load loads the data refered to by id into memory (if needed) and returns a
pointer to it. zn_loadz returns the buffer with a 0 byte padding to allow safe
handling with libC string handling functions, use zn_unref when done with the
returned pointer.                                                          */

const void *zn_load (Zn *zn, ZnId id);
const char *zn_loadz (Zn *zn, ZnId id);                                    /*

When we are done with the memory we got back from zn_load / zn_loadz we must
unref it with:                                                             */

void zn_unref (Zn *zn, ZnId id);                                           /*
                                    

zn_ref can be used when reference counting is needed, a zn_ref needs to be
balanced out with zn_unref like zn_load                                    */

void zn_ref (Zn *zn, ZnId id);                                             /*


zn_data is the core API that turns blobs of data of given (or unknown 0
terminated) length is turned into recallable ZnId's. You can free the original
data afterwards if you keep track of the returned ZnId.                    */

ZnId zn_data (Zn *zn, const void *data, ZnSize length);                    /*
 

Passing the same string or blob to ZN twice will give you the same ZnId for it
(on the same host, with a network distributed ZN system - different nodes
would have different ids). For network wide and persistent storage in
datastructures not managed by ZN you should use the hash corresponding to an
ZnId instead.

zn_compute_hash permits computing the hash that would be used by an object
without storing it.                                                        */

void zn_compute_hash (Zn *zn,
                      const char *data, ZnSize length, uint8_t *hash);     /*


zn_hash writes out the 32bytes (256bit) of the ZnIds hash to provided buffer*/

void  zn_hash       (Zn *zn, ZnId id, uint8_t *hash_buf);                  /*


The result of zn_hash_length will be 20 or 32 depending on whether skein or
sha1 is used (skein is default, 32byte = 256bit)                           */

int   zn_hash_length (Zn *zn);                                             /*


The zn_get_hex and zn_get_base64 functions returns allocated \0 terminated
string buffers that should be free()d after use.                           */

char *zn_get_hex    (Zn *zn, ZnId id);
char *zn_get_base64 (Zn *zn, ZnId id);                                     /*


Functions of the same form, taking either raw binary data, \0 terminated-
hexadecimal data or base64 encoded data for lookup returning ZnId or 0 on
failure to look it up.                                                     */

ZnId zn_resolve        (Zn *zn, const uint8_t *hash_bin);
ZnId zn_resolve_hex    (Zn *zn, const char    *hash_hex);
ZnId zn_resolve_base64 (Zn *zn, const char    *hash_base64);               /*


zn_handle can be used to create "anonymous" objects, which further meta-data,
like a changeable human-readable title can be attached to and other structure
can be attached to.                                                        */

ZnId zn_handle (Zn *zn);                                                   /*


3: Global key/values for objects
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

Meta-data is stored in meta-data sidecars which are associated with id's using
associakeys - a way of creating a basic key/value meta-data system for Content
Addressed Storage on top of a key/value storage system. (see zn-associakey.c
for details.)

Meta-data sidecars are regular blobs containing information about a node in a
graph, the nodes out-going named edges (keys); each named edge has an ordered
list of values.  Each value can also carry a list of key/value(s) pairs known
as attribute/details. Along with this declarative data part, the meta-data
sidecar contains a reference to the previous meta-data sidecar and a timestamp
for when it was created.


zn_set_key associates a given value with a key, this is the value that will
be retrieve later by zn_get_key                                            */

void zn_set_key (Zn *zn, ZnId id, ZnId key, ZnId value);                   /*


zn_get_key retrieves the value set for key, if there is multiple values for
the key the last value (set) will be returned                              */

ZnId zn_get_key (Zn *zn, ZnId id, ZnId key);                               /*


zn_has_key can be used to check if a given key has an associated value     */

int  zn_has_key (Zn *zn, ZnId id, ZnId key);                               /*


Zn manages loosely structured decoupled meta-data associations between data.
This is done with multi-value keys. Each ZnId has a list of keys (which can
be any valid ZnId). And each of these keys have an ordered list of values.

ZnId key   = zn_string (zn, "title");
ZnId title = zn_string (zn, "zn introduction");
ZnId title2;

zn_set_key (zn, id, key, title);

title2 = zn_get_key (zn, id, key);

assert (title2 == title);

zn_has_key returns 0 if no value is set, this permits using 0 as a valid set
value 

You can remove a key from an id by using zn_unset_key, this removes all children.                                                                  */
void zn_unset_key (Zn *zn, ZnId id, ZnId key);                             /*


zn_list_keys returns an allocated NULL terminated array (to be free()d after
use) of the kys set on id, or NULL if there is none.                       */

ZnId * zn_list_keys        (Zn *zn, ZnId id);
int    zn_count_keys       (Zn *zn, ZnId id);                              /*


utility functions for integer/floating point values / details are provided,
these functions store a parsable ascii version in the data. - in the future
they might store a \0 byte and at a fixed offset store magic and a binary
representation, permitting faster access.                                  */

void    zn_set_key_int (Zn *zn, ZnId id, ZnId key, int64_t value);
int64_t zn_get_key_int (Zn *zn, ZnId id, ZnId key); 
void    zn_set_key_float (Zn *zn, ZnId id, ZnId key, double value);
double  zn_get_key_float (Zn *zn, ZnId id, ZnId key);                      /*


4: Multi-Value with Ordered List
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

Multiple values can be associated with each key - the order of values is
maintained and the same value can occur multiple times for the same key, a
current idiom is to use the key "children" containing sub-items. This is
slightly different from the RDF semantics where you have multiple edges with
the same name and each of them carrying a different value; all of those edges
are merged into one in the Zn datamodel and they contain an ordered set of
values. One can transform data represented in RDF to Zn and back, but Zn can
express order in ways which are hard for RDF to express.

zn_set_value (zn, id, key, position, value) lets you insert before any
existing value, passing in -1 for value_no appends. -2 only adds if the value
isn't already set for key. Perhaps set_value should be renamed             */

int  zn_set_value (Zn *zn, ZnId id, ZnId key, int value_no, ZnId value);   /*

(zn, id, key, 0, zn_string (zn, "original title"));
zn_set_value (zn, id, key, 1, zn_string (zn, "alternate title"));

zn_replace_value takes the same arguments as set_value but replaces the value
at the position instead.                                                   */

void zn_replace_value(Zn *zn, ZnId id, ZnId key, int value_no, ZnId new_value); 
                                                                           /*
zn_get_key (zn, id, key); is equivelent to zn_get_value (zn, id, key, 0);  */

ZnId zn_get_value (Zn *zn, ZnId id, ZnId key, int no);                     /*


zn_list_values gets a NULL terminated allocated array, to be free()'d after
use, of the values an id's key has.                                        */

ZnId * zn_list_values      (Zn *zn, ZnId id, ZnId key);
int    zn_count_values     (Zn *zn, ZnId id, ZnId key);                    /*


a shortcut method for passing -1 to set_value's no argument                */

int  zn_append_value (Zn *zn, ZnId id, ZnId key, ZnId value);              /*


a shortcut method for passing -2 to set_value's no argument, this treats the
key as a set where each value can only occur once                          */

/* XXX: s/zn_add_value/zn_add_property/ ? */
int  zn_add_value (Zn *zn, ZnId id, ZnId key, ZnId value);                 /*


There is quite a few ways of removing items;

remove a specific value                                                    */

void zn_unset_value_no  (Zn *zn, ZnId id, ZnId key, int no);               /*


remove first value matching                                                */

void zn_unset_value     (Zn *zn, ZnId id, ZnId key, ZnId value);           /*


remove all values matching                                                 */

void zn_unset_value_all (Zn *zn, ZnId id, ZnId key, ZnId value);           /*


To reorder values you can use zn_swap_values (zn, id, position1, position2);*/

void zn_swap_values(Zn *zn,ZnId id, ZnId key, int value_no, int other_value_no);
                                                                              /*

5: Local key/values on Values
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

It is often useful to associate additional meta-data with a particular value.
These key/value pairs are called attribute/details in ZN. The API is mirrored
on how the value API can be used for multi-value use - and should be usable
from this shorther reference:                                              */

ZnId   zn_get_attribute   (Zn *zn, ZnId id, ZnId key, int no, ZnId attribute);
int    zn_has_attribute   (Zn *zn, ZnId id, ZnId key, int no, ZnId attribute);
void   zn_set_attribute   (Zn *zn, ZnId id, ZnId key,
                           int value_no, ZnId attribute, ZnId detail);     /* 

unsetting the attribute takes all details with it                          */
void   zn_unset_attribute (Zn *zn, ZnId id, ZnId key, int no, ZnId attribute);

void   zn_set_detail      (Zn *zn, ZnId id, ZnId key, int value_no,
                           ZnId attribute, int detail_no, ZnId detail);
ZnId   zn_get_detail      (Zn *zn, ZnId id, ZnId key,
                           int value_no, ZnId attribute, int detail_no);
void   zn_unset_detail    (Zn *zn, ZnId id, ZnId key, int value_no,
                           ZnId attribute, ZnId detail);
void   zn_unset_detail_all(Zn *zn, ZnId id, ZnId key, int value_no,
                           ZnId attribute, ZnId detail); 
void   zn_unset_detail_no (Zn *zn, ZnId id, ZnId key, int value_no,
                           ZnId attribute, int detail_no);  /* XXX:NYI */
void   zn_swap_details    (Zn *zn, ZnId id, ZnId key, int value_no,
                           ZnId attribute, int detail1, int detail2);/*XXX:NYI */
void   zn_replace_detail  (Zn *zn, ZnId id, ZnId key, int value_no,
                           ZnId attribute, int detail_no, ZnId detail); 
ZnId * zn_list_attributes (Zn *zn, ZnId id, ZnId key, int value_no);
ZnId * zn_list_details     (Zn *zn, ZnId id, ZnId key, int value_no,
                            ZnId attribute);
int    zn_count_attributes (Zn *zn, ZnId id, ZnId key, int value_no);
int    zn_count_details    (Zn *zn, ZnId id, ZnId key, int value_no,
                            ZnId attribute);                               /* 
The following functions are wrappers for various accessors that provide
C types instead of strings, the underlying stored values are still
strings, these methos are able to parse RDF suffixed ^^ types.             */

void    zn_set_attribute_int (Zn *zn, ZnId id, ZnId key,
                              int value_no, ZnId attribute, int64_t value);
int64_t zn_get_attribute_int (Zn *zn, ZnId id, ZnId key,
                               int value_no, ZnId attribute);
void    zn_set_attribute_float (Zn *zn, ZnId id, ZnId key,
                                int value_no, ZnId attribute, double value);
double  zn_get_attribute_float (Zn *zn, ZnId id, ZnId key,
                                int value_no, ZnId attribute);
void    zn_set_detail_int  (Zn *zn, ZnId id, ZnId key, int value_no,
                           ZnId attribute, int detail_no, int64_t detail);
int64_t zn_get_detail_int  (Zn *zn, ZnId id, ZnId key,
                            int value_no, ZnId attribute, int no);         /*


6: Change monitoring
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
 
Whenever the meta-data associated with an id that is monitored changes
monitoring callbacks referring to the id will be fired. Code and rendering
logic should be structured with the expectation of changes occuring, and that
the document being displayed is alive.

A side effect of adding monitors is that the gossip daemon gathers and spreads
gossip about monitored items - this abstraction is provided in the hope that
it can lead to more responsive and up to date data with lower latency when it
later would be required.

The monitor callback might be invoked in a different thread than the thread used to register it. */

int  zn_monitor_add    (Zn           *zn,
                        ZnId          id, /* or 0 for all */
                        ZnId        (*monitor)(Zn           *zn, 
                                               ZnId          id,
                                               void         *userdata),
                        void         *userdata);
void zn_monitor_remove (Zn *zn, int monitor_id);                           /*


7: Storage and Access Tuneables
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

The zn backend engine is still under development, and only recently has
the ability to have multiple concurrent instances with different access
patterns, XXX: new and better ways of doing this will likely arise.

zn_dup duplicates an existing zn instance - permitting to tweak some
access settings locally for a block of code, destroy with zn_destroy 
when done.                                                                 */

Zn * zn_dup (Zn *zn);                                                      /*


using the time filter changes what time to retrieve meta data for, see the
manipulating time section for more details, setting it to -1 resets the time
filter.                                                                    */

void zn_set_time_filter (Zn *zn, ZnId max_time);
ZnId zn_get_time_filter (Zn *zn);                                          /*


global salt used for all hash, change this and you are operating in a separate
data universe - without knowing the salt for encrypted data figuring out a
dataset would be hard, for an unencrypted dataset - it would be worthwhile to
use a dictionary attack on the salt for recovery purposes.                 */

void        zn_set_salt (Zn *zn, const char *salt); /* XXX: should add length, optionally -1 */
const char *zn_get_salt (Zn *zn);                                          /*

Compression
▀▀▀▀▀▀▀▀▀▀▀

The database of zn has built in support for compression, currently the
flags for compression is set on the item in the database. In the future
this might move to the data itself.

Data created with compression enabled will still be decompressed even if
compression is later disabled internally the deflated length is stored as a
uint64_t before the compressed data for extra validation.
*/
void zn_set_compress     (Zn *zn, int compression_enabled);
int  zn_get_compress     (Zn *zn); 
/*
XXX: the compression scheme might change, in such a way that compression is an
aspect of the content and not the storage of it.. this needs contemplation.

8: Encryption
▀▀▀▀▀▀▀▀▀▀▀▀▀

When encryption is enabled a secret is used to derive encryption and
scrambling of the keys. Having access to the secret used for this scrambling
is equivalent to having access to the data.

If compression and encryption are enabled at the same time, the data is first
compressed - then encrypted. (compression wouldn't work otherwise). The data
is addressed by its unencrypted, uncompressed hash. (NOTE: compression is
currently not exposed API due to inoperabilities with encryption).

Setting the secret enables encryption and scrambling - crypto is disabled
again by setting secret to NULL. 

The encryption used is http://en.wikipedia.org/wiki/XXTEA using the first 16
bytes of the hash of the secret as private pre-shared key. Without further
countermeasures - some traffic analysis of bootstrapping node could provide
pieces of content containing known plain-text.                             */

void zn_set_secret    (Zn *zn, const uint8_t *secret, int length);         /*


9: Data-Mesh (Networking)
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

When some hosts have been added, the gossip daemon/thread runs in the
background synchronising data.                                             */

void zn_add_host    (Zn *zn, const char *path);
void zn_remove_host (Zn *zn, const char *path);                            /*


Hosts in the network collaborate to keep the data mesh up to date - meta-data
about nodes reachable with a given level of hops in the graph from given items
is synchronized with the peer repositories. In both pull and push manner -
there is currently no distinction between repositories - there is no masters
or all repositories could be considered masters; syncing can happen without
running an API server locally.  This graph-local synchronization is similar to
desirable pre-fetch ranges for caching before doing interactive visualisation
and manipulation of content - the synchronisation is thus driven by data use.

See lib/zn-gossip.c for details about the mesh synchronisation.


10: Content Deduplication
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

Deduplication is experimental and needs to be enabled through environment
variables. At the moment the only available strategy is a rolling byte dedup.
To enable it use:

export ZN_DEDUP=byte

XXX: Due to how meta-data sidecars are manipulated; a revision/diff based
approach with just a historic search on itself should be sufficient.


11: Utility functions
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

zn_get_mime_type is a utility call, that might well be removed later, it
returns a mime-type key based on simple mimetype sniffing of the content   */

const char *zn_get_mime_type    (Zn *zn, ZnId id); 
ZnId zn_mktime (Zn *zn,
                int year, int mon, int day,
                int hour, int min, int sec,
                int isdst);                                                /*

mktime is not good en`ugh, needs timezone or is it always UCT ?,
also need a way to decode a ZN based time to bits..


time is monotonically increasing, requesting the time should give you
at least second resolution. */

ZnId     zn_time_now            (Zn *zn);
uint64_t zn_get_time_stamp      (Zn *zn, ZnId id);
uint64_t zn_get_prev_time_stamp (Zn *zn, ZnId id);
ZnId     zn_time_current        (Zn *zn);                                  /*
zn_time_current is useful together with zn_time_plus to do a bit of
arithmetic on it. */
ZnId     zn_time_plus           (Zn *zn, ZnId time, uint64_t delta_seconds);/*


The most generally "useful" statistic to gather from a db is how many items it
store - I guess adding size consumption for the repository is also reasonable.
                                                                            */

ZnSize zn_entries  (Zn *zn);                                               /*

The number of internal objects; and objects from other salts/name spaces can
make real use of this data difficult.  The iterator created self destructs
when iteration is complete and zn_db_iterator_next returns 0. In a distributed
system this would only iterate the items of a single nodes db. Iterating over
the entries in the database becomes trickier with different salts and
encryptions - since many of the 64bit entries belong to other datasets. It is
better to treat the graph as the structure element and make walks in the graph
instead.                                                                   */

typedef struct _ZnIterator ZnIterator;
ZnIterator    *zn_iterator_new  (Zn *zn);
ZnId           zn_iterator_next (ZnIterator *iterator);
void           zn_iterator_stop (ZnIterator *iterator);                    /*

The following API maintains parent/child relations for bidirectional navigation
of parent/child relationships.

*/

void   zn_remove_children       (Zn *zn, ZnId id);
/*     zn_unset_key             (zn, id, zn_string (zn, "children"));*/
void   zn_add_child_at          (Zn *zn, ZnId id, int pos, ZnId child);
/*     zn_set_value             (zn, id, zn_string (zn, "children"), pos, child)
       zn_add_value             (zn, child, zn_string (zn, "parents"), id) */
void   zn_remove_child          (Zn *zn, ZnId id, int pos);
/*     zn_unset_value_hh        (zn, id, zn_string (zn, "children"), no); */
void   zn_replace_child         (Zn *zn, ZnId id, int no, ZnId child);
/*     zn_replace_value         (zn, id, zn_string (zn, "children"), no, child)*/
void   zn_swap_children         (Zn *zn, ZnId id, int pos1, int pos2);
/*     zn_swap_values           (zn, id, zn_string (zn, "children"), pos1, pos2) */
ZnId   zn_get_child             (Zn *zn, ZnId id, int pos);
/*     zn_get_value             (zn, id, zn_string (zn, "children"), no) */
ZnId  *zn_list_children         (Zn *zn, ZnId id);
/*     zn_list_values (zn, id, zn_string (zn, "children")) */
int    zn_count_children        (Zn *zn, ZnId id);
/*     zn_count_values (zn, id, zn_string (zn, "children")) */
void   zn_child_unset_key       (Zn *zn, ZnId id, int no, ZnId key);
/*     zn_unset_attribute (zn, id, zn_string (zn, "children"), no, key) */
ZnId * zn_child_get_key         (Zn *zn, ZnId id, int no, ZnId key);
/*     zn_list_details          (zn, id, zn_string (zn, "children"), key); */
int    zn_child_has_key         (Zn *zn, ZnId id, int no, ZnId key);
/*     zn_has_attribute         (zn, id, zn_string (zn, "children"), key); */
void   zn_child_add_key         (Zn *zn, ZnId id, int no, ZnId key, ZnId value);
/*     zn_set_detail            (zn, id, zn_string (zn, "children"), no,  key, 0, value); */
void   zn_child_set_key         (Zn *zn, ZnId id, int no, ZnId key, ZnId value);
/*     zn_set_attribute (zn, id, zn_string (zn, "children"), no, key, value);*/
void   zn_child_unset_key_value (Zn *zn, ZnId id, int no, ZnId key, ZnId value);
/*     zn_child_unset_key_value (zn, id, zn_string (zn, "children"), no, key, value); */
ZnId * zn_child_get_keys        (Zn *zn, ZnId id, int no);
/*     zn_list_attributes       (zn, id, zn_string (zn, "children"), no) */
int    zn_child_count_keys      (Zn *zn, ZnId id, int no);
/*     zn_count_attributes      (zn, id, zn_string (zn, "children"), no) */
ZnId * zn_child_list_keys       (Zn *zn, ZnId id, int no);
/*     zn_list_attributes       (zn, id, zn_string (zn, "children"), no) */
ZnId   zn_child_get_key_one     (Zn *zn, ZnId id, int no, ZnId key);
/*     zn_get_attribute         (zn, id, zn_string (zn, "children"), no) */
ZnId   zn_child_get_key_one_int (Zn *zn, ZnId id, int no, ZnId key);
void   zn_append_child          (Zn *zn, ZnId id, ZnId child);
ZnId  *zn_get_parents           (Zn *zn, ZnId id);
int    zn_count_parents         (Zn *zn, ZnId id);                         /*

12: Missing bits
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

ZN is by default caching modifications, and writing one new meta-data
sidecar when data leaves the cache, zn_flush should flush all pending
chanhes, zn_flush should be issued when making a snapshot or bookmark
for referring to a particular state.:
                                                                            */
void zn_flush (Zn *zn);



]]

function M.new(db_path)
  return ffi.gc(C.zn_new(db_path), C.zn_destroy)
end

ffi.metatype('Zn', {__index= {
  string = function(...) return C.zn_string(...) end,
  get_length = function(...) return C.zn_get_length (...) end,
  deref = function(...) return ffi.string(C.zn_load(...)) end, -- missing gc
  unref = function(...) C.zn_unref(...) end,
  get_key = function(...) return C.zn_get_key(...) end,
  set_key = function(...) C.zn_set_key(...) end,
  has_key = function(...) return C.zn_has_key(...) end,
  unset_key = function(...) C.zn_unset_key(...) end,
  list_keys = function(...) C.zn_list_keys (...) end,
  count_keys = function(...) C.zn_count_keys (...) end,
  set_key_int = function(...) C.zn_set_key_int (...) end,
  get_key_int = function(...) return C.zn_get_key_int (...) end,
  set_key_float = function(...) C.zn_set_key_float (...) end,
  get_key_float = function(...) return C.zn_get_key_float (...) end,
  set_value = function(...) C.zn_set_value(...) end,
  replace_value = function(...) C.zn_replace_value(...) end,
  get_value = function(...) C.zn_get_value(...) end,
  list_values = function(...) return C.zn_list_values(...) end,
  count_values = function(...) return C.zn_count_values(...) end,
  append_value = function(...) return C.zn_append_value(...) end,
  add_value = function(...) return C.zn_add_value(...) end,
  unset_value_no = function(...) return C.zn_unset_value_no(...) end,
  unset_value = function(...) return C.zn_unset_value(...) end,
  unset_value_all = function(...) return C.zn_unset_value_all(...) end,
  swap_values = function(...) return C.zn_swap_values(...) end,

  get_attribute = function(...) return C.zn_get_attribute (...) end,
  has_attribute = function(...) return C.zn_has_attribute (...) end,
  set_attribute = function(...) C.zn_set_attribute (...) end,
  unset_attribute = function(...) C.zn_unset_attribute (...) end,

  get_detail = function(...) return C.zn_get_detail (...) end,
  set_detail = function(...) C.zn_set_detail (...) end,
  has_detail = function(...) return C.zn_has_detail (...) end,
  unset_detail = function(...) C.zn_unset_detail (...) end,
  unset_detail_no = function(...) C.zn_unset_detail_no (...) end,
  swap_details = function(...) C.zn_swap_details (...) end,
  replace_detail = function(...) C.zn_replace_detail (...) end,
  list_attributes = function(...) return C.zn_list_attributes (...) end,
  list_details = function(...) return C.zn_list_details (...) end,
  count_attributes = function(...) return C.zn_count_attributes (...) end,
  count_details = function(...) return C.zn_count_details (...) end,
  set_attribute_int = function(...) C.zn_set_attribute_int (...) end,
  get_attribute_int = function(...) return C.zn_get_attribute_int (...) end,
  set_attribute_float = function(...) C.zn_set_attribute_float (...) end,
  get_attribute_float = function(...) return C.zn_get_attribute_float (...) end,
  set_detail_int = function(...) C.zn_set_detail_int (...) end,
  get_detail_int = function(...) return C.zn_get_detail_int (...) end,
  


  remove_children = function(...) C.zn_remove_children (...) end,
  add_child_at = function(...) C.zn_add_child_at (...) end,
  remove_child = function(...) C.zn_remove_child (...) end,
  replace_child = function(...) C.zn_replace_child (...) end,
  swap_children = function(...) C.zn_swap_children (...) end,
  get_child = function(...) return C.zn_get_child (...) end,
  list_children = function(...) return C.zn_list_children (...) end,
  count_children = function(...) return C.zn_count_children (...) end,
  child_unset_key = function(...) C.zn_child_unset_key (...) end,
  child_get_key = function(...) return C.zn_child_get_key (...) end,
  child_has_key = function(...) return C.zn_child_has_key (...) end,
  child_add_key = function(...) C.zn_child_add_key (...) end,
  child_set_key = function(...) C.zn_child_set_key (...) end,
  child_unset_key_value = function(...) C.zn_child_unset_key_value (...) end,
  child_get_keys = function(...) return C.zn_child_get_keys (...) end,
  child_count_keys = function(...) return C.zn_child_count_keys (...) end,
  child_list_keys = function(...) return C.zn_child_list_keys (...) end,
  child_get_key_one = function(...) return C.zn_child_get_key_one (...) end,
  append_child = function(...) return C.zn_append_child (...) end,
  get_parents = function(...) return C.zn_get_parents (...) end,
  count_parents = function(...) return C.zn_count_parents (...) end,
  get_mime_type = function(...) return ffi.string(C.zn_get_mime_type (...)) end

}})

return M
