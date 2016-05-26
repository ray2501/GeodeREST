# GeodeREST --
#
#	Apache Geode REST Client Library for Tcl
#
# Copyright (C) 2016 Danilo Chang <ray2501@gmail.com>
#
# Retcltribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Retcltributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Retcltributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

package require Tcl 8.6
package require TclOO
package require http
package require json

package provide GeodeREST 0.1

oo::class create GeodeREST {
    variable server
    variable ssl_enabled
    variable response
    variable baseurl
    variable region

    constructor {{SERVER http://localhost:8080} {SSL_ENABLED 0}} {
        set server $SERVER
        set ssl_enabled $SSL_ENABLED
        set response ""
        set baseurl "$SERVER/gemfire-api/v1"
        set region ""

        if {$ssl_enabled} {
            if {[catch {package require tls}]==0} {
                http::register https 443 [list ::tls::socket -ssl3 0 -ssl2 0 -tls1 1]
            } else {
                error "SSL_ENABLED needs package tls..."
            }
        }
    }

    destructor {
    }

    method send_request {url method {headers ""} {data ""}} {
        variable tok

        if {[string length $data] < 1} {
            if {[catch {set tok [http::geturl $url -method $method \
                -headers $headers]}]} {
                return "error"
            }
        } else {
            if {[catch {set tok [http::geturl $url -method $method \
                -headers $headers -query $data]}]} {
                return "error"
            }
        }

        set res [http::status $tok]
        set [namespace current]::response [http::data $tok]

        http::cleanup $tok
        return $res
    }

    #
    # List all available resources (regions) in the Geode cluster
    #
    method list_all_regions {} {
        my variable headerl
        my variable names
        my variable parse_result
        my variable regions

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set res [my send_request $baseurl GET $headerl]

        if {[string compare $res "ok"]==0} {
            set parse_result [json::json2dict $response]
            if {[catch {set regions [dict get $parse_result regions]}]} {
                return {}
            }

            set names [list]
            foreach myregion $regions {
                lappend names [dict get $myregion name]
            }
            return $names
        }

        return {}
    }

    #
    # Give a region name to access data
    # Use method list_all_regions to get names to check
    #
    method setupRegion {REGION} {
        my variable found
        my variable names

        set found 0
        set [namespace current]::region $REGION
        set names [my list_all_regions]

        foreach name $names {
            if {[string compare $name $region]==0} {
                set found 1
            }
        }

        return $found
    }

    #
    # Returns all the data in a Region
    #
    method get_all {} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json" ]

        set params [list]
        lappend params limit ALL
        set querystring [http::formatQuery {*}$params]

        set myurl "$baseurl/$region?$querystring"
        set res [my send_request $myurl GET $headerl]

        if {[string compare $res "ok"]==0} {
            return $response
        }

        return {}
    }

    #
    # Creates a new data value in the Region
    #
    method create {KEY VALUE} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json" \
                        Content-Type "application/json"]

        set params [list]
        lappend params key $KEY
        set querystring [http::formatQuery {*}$params]

        set myurl "$baseurl/$region?$querystring"
        set res [my send_request $myurl POST $headerl $VALUE]

        return $res
    }

    #
    # Updates or inserts data for a specified key
    #
    method put {KEY VALUE} {
        my variable headerl
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json" \
                        Content-Type "application/json"]

        set myurl "$baseurl/$region/$KEY"
        set res [my send_request $myurl PUT $headerl $VALUE]

        return $res
    }

    #
    # Returns all keys in the Region
    #
    method keys {} {
        my variable headerl
        my variable myurl
        my variable keys

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set myurl "$baseurl/$region/keys"
        set res [my send_request $myurl GET $headerl]

        if {[string compare $res "ok"]==0} {
            set parse_result [json::json2dict $response]
            set keys [dict get $parse_result keys]
           
            return $keys
        }

        return {}
    }

    #
    # Returns the data value for a specified key
    #
    method get {KEY} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set params [list]
        lappend params ignoreMissingKey true
        set querystring [http::formatQuery {*}$params]

        set myurl "$baseurl/$region/$KEY?$querystring"
        set res [my send_request $myurl GET $headerl]

        if {[string compare $res "ok"]==0} {
            return $response
        }

        return {}
    }

    #
    # Updates the data in a region only if the specified key is present
    #
    method update {KEY VALUE} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json" \
                        Content-Type "application/json"]

        set params [list]
        lappend params op REPLACE
        set querystring [http::formatQuery {*}$params]

        set myurl "$baseurl/$region/$KEY?$querystring"
        set res [my send_request $myurl PUT $headerl $VALUE]

        return $res
    }

    #
    # Compares old values and if identical replaces with a new value
    #
    method compare_and_set {KEY OLDVALUE NEWVALUE} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json" \
                        Content-Type "application/json"]

        set params [list]
        lappend params op CAS
        set querystring [http::formatQuery {*}$params]

        set value "{\"@old\": $OLDVALUE, \"@new\": $NEWVALUE}"

        set myurl "$baseurl/$region/$KEY?$querystring"
        set res [my send_request $myurl PUT $headerl $value]

        return $res
    }

    #
    # Deletes the corresponding data value for the specified key
    #
    method delete {KEY} {
        my variable headerl
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set myurl "$baseurl/$region/$KEY"
        set res [my send_request $myurl DELETE $headerl]

        return $res
    }

    #
    # Delete all entries in the region
    #
    method delete_all {} {
        my variable headerl
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set myurl "$baseurl/$region"
        set res [my send_request $myurl DELETE $headerl]

        return $res
    }

    #
    # Lists all stored Queries in the server
    #
    method list_all_queries {} {
        my variable headerl
        my variable myurl
        my variable queries

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set myurl "$baseurl/queries"
        set res [my send_request $myurl GET $headerl]

        if {[string compare $res "ok"]==0} {
            set parse_result [json::json2dict $response]
            set queries [dict get $parse_result queries]
            return $queries
        }

        return {}
    }

    #
    # Runs the Query with specified parameters
    #
    method run_query {query_id query_args} {
        my variable headerl
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json" \
                          Content-Type "application/json"]

        set myurl "$baseurl/queries/$query_id"
        set res [my send_request $myurl POST $headerl $query_args]

        if {[string compare $res "ok"]==0} {
            return $response
        }

        return {}
    }

    #
    # Creates a new Query and adds it to the server
    #
    method new_query {query_id query_string} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set params [list]
        lappend params id $query_id
        lappend params q $query_string
        set querystring [http::formatQuery {*}$params]

        set myurl "$baseurl/queries?$querystring"
        set res [my send_request $myurl POST $headerl]

        return $res
    }

    #
    # Update the specified named query
    #
    method update_query {query_id query_string} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set params [list]
        lappend params q $query_string
        set querystring [http::formatQuery {*}$params]

        set myurl "$baseurl/queries/$query_id?$querystring"
        set res [my send_request $myurl PUT $headerl]

        return $res
    }

    #
    # Delete the specified named query
    #
    method delete_query {query_id} {
        my variable headerl
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set myurl "$baseurl/queries/$query_id"
        set res [my send_request $myurl DELETE $headerl]

        return $res
    }

    #
    # Runs an adhoc Query
    #
    method adhoc_query {QUERY_STRING} {
        my variable headerl
        my variable params
        my variable querystring
        my variable myurl

        set [namespace current]::response ""
        set headerl [list Accept "application/json"]

        set params [list]
        lappend params q $QUERY_STRING
        set querystring [http::formatQuery {*}$params]

        set myurl "$baseurl/queries/adhoc?$querystring"
        set res [my send_request $myurl GET $headerl]

        if {[string compare $res "ok"]==0} {
            return $response
        }

        return {}
    }
}

