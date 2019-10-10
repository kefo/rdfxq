xquery version "1.0";

(:
:   Module Name: MARC/XML BIB 2 BIBFRAME RDF using MarkLogic
:
:   Module Version: 1.0
:
:   Date: 2014 February 07
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: xdmp (MarkLogic)
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
:   @since Feb 7, 2014
:   @version 1.0
:)

(: IMPORTED MODULES :)

import module namespace rdfxml2trix = "http://3windmills.com/rdfxq/modules/rdfxml2trix#" at "../modules/module.RDFXML-2-TriX.xqy";
import module namespace ntriples2trix = "http://3windmills.com/rdfxq/modules/ntriples2trix#" at "../modules/module.Ntriples-2-TriX.xqy";
import module namespace jsonld2trix = "http://3windmills.com/rdfxq/modules/jsonld2trix#" at "../modules/module.JSONLD-2-TriX.xqy";

import module namespace xqilla = "http://xqilla.sourceforge.net/Functions" at "../modules/module.JSON-2-SnelsonXML.xqy";

import module namespace trix2ntriples = "http://3windmills.com/rdfxq/modules/trix2ntriples#" at "../modules/module.TriX-2-Ntriples.xqy";
import module namespace trix2jsonld-ml = "http://3windmills.com/rdfxq/modules/trix2jsonld-ml#" at "../modules/module.TriX-2-JSONLD-MarkLogic.xqy";
import module namespace trix2rdfxml = "http://3windmills.com/rdfxq/modules/trix2rdfxml#" at "../modules/module.TriX-2-RDFXML.xqy";

import module namespace rdfxqshared     = "http://3windmills.com/rdfxq/modules/rdfxqshared#" at "../modules/module.Shared.xqy";

(: NAMESPACES :)
declare namespace xdmp  = "http://marklogic.com/xdmp";

declare namespace rdf           = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace rdfs          = "http://www.w3.org/2000/01/rdf-schema#";


(:~
:   This variable is for the location of the source RDF.
:)
declare variable $s as xs:string := xdmp:get-request-field("s","");

(:~
:   Set the input serialization. Expected values are: rdfxml (default), trix, ntriples, jsonld
:)
declare variable $i as xs:string := xdmp:get-request-field("i","rdfxml");

(:~
:   Set the output serialization. Expected values are: rdfxml (default), trix, ntriples, jsonld
:)
declare variable $o as xs:string := xdmp:get-request-field("o","rdfxml");

let $sname := 
    if ( fn:not(fn:matches($s, "^(http|ftp)")) ) then
        fn:concat("file://", $s)
    else
        $s

let $source := 
    if ($i eq "ntriples" or $i eq "jsonld") then
        xdmp:document-get(
            $s, 
            <options xmlns="xdmp:document-get">
                <format>text</format>
            </options>
        )
    else 
        xdmp:document-get(
            $s, 
            <options xmlns="xdmp:document-get">
                <format>xml</format>
            </options>
        )

let $source := 
    if ($i eq "ntriples" or $i eq "jsonld") then
        $source
    else
        $source/element()

let $source-trix := 
    if ($i eq "rdfxml") then
        rdfxml2trix:rdfxml2trix($source)
    else if ($i eq "ntriples") then
        ntriples2trix:ntriples2trix($source)
    else if ($i eq "jsonld") then
        let $jsonxml := xqilla:parse-json($source)
        return jsonld2trix:jsonld2trix($jsonxml, $sname)
    else
        $source
     
let $output := 
    if ($o eq "rdfxml") then
        (
            xdmp:add-response-header("Content-type", "application/rdf+xml"),
            trix2rdfxml:trix2rdfxml($source-trix, fn:false())
        )
    else if ($o eq "rdfxml-abbrev") then
        (
            xdmp:add-response-header("Content-type", "application/rdf+xml"),
            trix2rdfxml:trix2rdfxml($source-trix, fn:true())
        )
    else if ($o eq "jsonld") then
        (
            xdmp:add-response-header("Content-type", "application/json"),
            trix2jsonld-ml:trix2jsonld($source-trix, fn:false())
        )
    else if ($o eq "jsonld-expanded") then
        (
            xdmp:add-response-header("Content-type", "application/json"),
            trix2jsonld-ml:trix2jsonld($source-trix, fn:true())
        )
    else if ($o eq "ntriples") then
        (
            xdmp:add-response-header("Content-type", "text/plain"),
            trix2ntriples:trix2ntriples($source-trix)
        )
    else if ($o eq "snelson") then
        (
            xdmp:add-response-header("Content-type", "application/xml"),
            xqilla:parse-json($source)
        )
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
