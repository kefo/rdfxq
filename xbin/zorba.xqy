xquery version "3.0";

(:
:   Module Name: MARC/XML BIB 2 BIBFRAME RDF using Zorba
:
:   Module Version: 1.0
:
:   Date: 2014 March 19
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: Zorba
:
:   Xquery Specification: January 2007
:
:   Module Overview:     Convert RDF between different serializations.
:
:)

(:~
:   Convert RDF between different serializations.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since March 19, 2014
:   @version 1.0
:)

(: IMPORTED MODULES :)

import module namespace rdfxml2trix = "http://3windmills.com/rdfxq/modules/rdfxml2trix#" at "../modules/module.RDFXML-2-TriX.xqy";
import module namespace ntriples2trix = "http://3windmills.com/rdfxq/modules/ntriples2trix#" at "../modules/module.Ntriples-2-TriX.xqy";
import module namespace jsonld2trix = "http://3windmills.com/rdfxq/modules/jsonld2trix#" at "../modules/module.JSONLD-2-TriX.xqy";

import module namespace trix2ntriples = "http://3windmills.com/rdfxq/modules/trix2ntriples#" at "../modules/module.TriX-2-Ntriples.xqy";
import module namespace trix2jsonld = "http://3windmills.com/rdfxq/modules/trix2jsonld#" at "../modules/module.TriX-2-JSONLD-Generic.xqy";
import module namespace trix2rdfxml = "http://3windmills.com/rdfxq/modules/trix2rdfxml#" at "../modules/module.TriX-2-RDFXML.xqy";
import module namespace trix2mlsemtriples = "http://3windmills.com/rdfxq/modules/trix2mlsemtriples#" at "../modules/module.TriX-2-MLSemTriples.xqy";

(: NAMESPACES :)
import module namespace http            =   "http://zorba.io/modules/http-client";
import module namespace jx              =   "http://zorba.io/modules/json-xml";
import module namespace file            =   "http://expath.org/ns/file";
import module namespace parsexml        =   "http://zorba.io/modules/xml";
import schema namespace parseoptions    =   "http://zorba.io/modules/xml-options";

declare namespace rdf           = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace rdfs          = "http://www.w3.org/2000/01/rdf-schema#";


(:~
:   This variable is for the location of the source RDF.
:)
declare variable $s as xs:string external;

(:~
:   Set the input serialization. Expected values are: rdfxml (default), trix, ntriples, jsonld
:)
declare variable $i as xs:string external;

(:~
:   Set the output serialization. Expected values are: rdfxml (default), trix, ntriples, jsonld
:)
declare variable $o as xs:string external;

declare function local:json2snelson($json)
{
    if ( fn:count(jn:keys($json)) > 0 ) then
        for $k in jn:keys($json)
        return 
            if ( fn:count(jn:members($json($k))) > 0 )then
                element pair {
                    attribute name {$k},
                    attribute type {"array"},
                    
                    for $m in jn:members($json($k))
                    return 
                        if ( fn:count(jn:keys($m)) > 0 ) then
                            element item {
                                attribute type {"object"},
                                (: parse JSON object :)
                                local:json2snelson($m)
                            }
                        else
                            element item {
                                attribute type {
                                    if ($m instance of xs:integer) then
                                        "number"
                                    else if ($m instance of xs:string) then
                                        "string"
                                    else
                                        "boolean"
                                },
                                $m
                            }
                
                }
            else
                if ( fn:count(jn:keys($json($k))) > 0 ) then
                    element pair {
                        attribute name {$k},
                        attribute type {"object"},
                        (: parse JSON object :)
                        local:json2snelson($json($k))
                    }
                else
                    element pair {
                        attribute name {$k},
                        attribute type {
                            if ($json($k) instance of xs:integer) then
                                "number"
                            else if ($json($k) instance of xs:string) then
                                "string"
                            else
                                "boolean"
                        },
                        $json($k)
                    }
    else
        for $m in jn:members($json)
        return 
            if ( fn:count(jn:keys($m)) > 0 ) then
                element item {
                    attribute type {"object"},
                    (: parse JSON object :)
                    local:json2snelson($m)
                }
            else
                element item {
                    attribute type {
                        if ($m instance of xs:integer) then
                            "number"
                        else if ($m instance of xs:string) then
                            "string"
                        else
                            "boolean"
                    },
                    $m
                }
        
};

let $sname := 
    if ( fn:not(fn:matches($s, "^(http|ftp)")) ) then
        fn:concat("file://", $s)
    else
        $s

let $source := 
    if ( fn:starts-with($s, "http://" ) or fn:starts-with($s, "https://" ) ) then
        let $json := http:get($s)
        return $json("body")("content")
    else
        file:read-text($s)
        
let $source := 
    if ($i eq "ntriples") then
        $source
    else if ($i eq "jsonld") then
        let $json := jn:parse-json($source)
        (: return jx:json-to-xml($json[1]) :) 
        let $jsontype := 
            if ( fn:count(jn:keys($json)) > 0 ) then
                "object"
            else
                "array"
        return 
            element json {
                attribute type {$jsontype},
                local:json2snelson($json)
            }
    else
        parsexml:parse($source, <parseoptions:options/>)/element()

let $source-trix := 
    if ($i eq "rdfxml") then
        rdfxml2trix:rdfxml2trix($source)
    else if ($i eq "ntriples") then
        ntriples2trix:ntriples2trix($source)
    else if ($i eq "jsonld") then
        jsonld2trix:jsonld2trix($source, $sname)
    else
        $source
     
let $output := 
    if ($o eq "rdfxml") then
        trix2rdfxml:trix2rdfxml($source-trix, fn:false())
    else if ($o eq "rdfxml-abbrev") then
        trix2rdfxml:trix2rdfxml($source-trix, fn:true())
    else if ($o eq "jsonld") then
        trix2jsonld:trix2jsonld($source-trix, fn:false())
    else if ($o eq "jsonld-expanded") then
        trix2jsonld:trix2jsonld($source-trix, fn:true())
    else if ($o eq "ntriples") then
        trix2ntriples:trix2ntriples($source-trix)
    else if ($o eq "mlsemtriples") then
        trix2mlsemtriples:trix2mlsemtriples($source-trix)
    else if ($o eq "snelson") then
        $source
    else
        $source-trix

return $output

(:
let $graphs-count := fn:count($output//*:graph)
let $triples-count := fn:count($output//*:triple)
return 
    element debug {
        element input {
            attribute type {$i},
            attribute graphs {fn:count($source-trix//*:graph)},
            attribute triples {fn:count($source-trix//*:triple)}
        },
        element output {
            attribute type {$o},
            attribute graphs {fn:count($output//*:graph)},
            attribute triples {fn:count($output//*:triple)}
        },
        
        (:
        for $g in $output/*:graph
        let $guri := $g/*:uri[1]
        let $triples-c := fn:count($g/*:triple)
        return
            element debug-graph {
                attribute uri {$guri},
                attribute triples {$triples-c}
            },
        :)
        
        element output-data {
            $output
        }
    }
:)
(: return fn:count($output//*:triple) :)

