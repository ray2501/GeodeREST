
GeodeREST
=====

[Apache Geode] (http://geode.incubator.apache.org/) provides a database-like consistency model,
reliable transaction processing and a shared-nothing architecture to maintain
very low latency performance with high concurrency processing.

[Gemcached] (http://geode.docs.pivotal.io/docs/tools_modules/gemcached/chapter_overview.html) is
a Geode adapter that allows Memcached clients to communicate with a
Geode server cluster, as if the servers were memcached servers.
So User can use memcached clients to access data stored in embedded Gemcached servers.

This extension is an Apache Geode REST Client Library for [Tcl] (http://tcl.tk).
The library consists of a single [Tcl Module] (http://tcl.tk/man/tcl8.6/TclCmd/tm.htm#M9) file.

GeodeREST is using Tcl built-in package http to send request to Apache Geode server
REST interface and get response.

This extension needs Tcl 8.6 and tcllib json package.


Interface
=====

The library has 1 TclOO class, GeodeREST.


Example
=====

## Add, update and delete value

    package require GeodeREST

    set mygeode [GeodeREST new http://localhost:8080]
    if {[$mygeode connect]==0} {
        puts "Http status code is not OK, exit"
        exit
    }

    puts "Current regions:"
    puts [$mygeode list_all_regions]

    $mygeode setupRegion regionA
    $mygeode create "myKey" {{"hello": "world"}}
    $mygeode create "myKey2" {{"hello2": "world2"}}
    $mygeode put "myKey" {{"hello": "Beautiful world"}}
    $mygeode get "myKey"
    $mygeode update "myKey" {{"hello": "world"}}
    $mygeode get "myKey"
    $mygeode compare_and_set "myKey" {{"hello": "world"}} {{"hello": "Beautiful world"}}
    $mygeode get "myKey"

    puts "Current data:"
    puts [$mygeode get_all]

    # delete value
    $mygeode delete "myKey2"
    $mygeode delete_all

## Query example 

    puts "adhoc query:"
    puts [$mygeode adhoc_query "SELECT * FROM /regionA"]

    puts "specified parameterized query:"
    $mygeode new_query "myQuery" {SELECT * FROM /regionA r WHERE r.hello = $1}
    puts [$mygeode list_all_queries]
    puts [$mygeode run_query "myQuery" {[{"@type": "string", "@value": "Beautiful world"}]}]
    $mygeode delete_query "myQuery"

## HTTPS support

If user enables HTTPS support, below is an example:

    package require GeodeREST

    set mygeode [GeodeREST new https://localhost:8080 1]
    if {[$mygeode connect]==0} {
        puts "Http status code is not OK, exit"
        exit
    }

Please notice, I use [TLS extension] (http://tls.sourceforge.net/) to add https support. So https support needs TLS extension.

