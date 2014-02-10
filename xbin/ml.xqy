xquery version "1.0";

(:
:   Module Name: MARC/XML BIB 2 BIBFRAME RDF using MarkLogic
:
:   Module Version: 1.0
:
:   Date: 2012 December 03
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: xdmp (MarkLogic)
:
:   Xquery Specification: January 2007
:
:   Module Overview:     Transforms MARC/XML Bibliographic records
:       to RDF conforming to the BIBFRAME model.  Outputs RDF/XML,
:       N-triples, or JSON.
:
:)

(:~
:   Transforms MARC/XML Bibliographic records
:   to RDF conforming to the BIBFRAME model.  Outputs RDF/XML,
:   N-triples, or JSON.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since December 03, 2012
:   @version 1.0
:)

(: IMPORTED MODULES :)

import module namespace rdfxml2trix = "http://3windmills.com/rdfxq/modules/rdfxml2trix#" at "../modules/module.RDFXML-2-TriX.xqy";
import module namespace ntriples2trix = "http://3windmills.com/rdfxq/modules/ntriples2trix#" at "../modules/module.Ntriples-2-TriX.xqy";
import module namespace jsonld2trix = "http://3windmills.com/rdfxq/modules/jsonld2trix#" at "../modules/module.JSONLD-2-TriX.xqy";

import module namespace xqilla = "http://xqilla.sourceforge.net/Functions" at "../modules/module.JSON-2-SnelsonXML.xqy";


import module namespace trix2ntriples = "http://3windmills.com/rdfxq/modules/trix2ntriples#" at "../modules/module.TriX-2-Ntriples.xqy";
import module namespace trix2rdfxml = "http://3windmills.com/rdfxq/modules/trix2rdfxml#" at "../modules/module.TriX-2-RDFXML.xqy";


(: NAMESPACES :)
declare namespace xdmp  = "http://marklogic.com/xdmp";

declare namespace rdf           = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace rdfs          = "http://www.w3.org/2000/01/rdf-schema#";


declare option xdmp:output "indent-untyped=yes" ; 

(:~
:   This variable is for the base uri for your Authorites/Concepts.
:   It is the base URI for the rdf:about attribute.
:   
:)
declare variable $baseuri as xs:string := xdmp:get-request-field("baseuri","http://base-uri/");

(:~
:   This variable is for the MARCXML location - externally defined.
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
        return jsonld2trix:jsonld2trix($jsonxml)
    else
        $source
     
let $output := 
    if ($o eq "rdfxml") then
        trix2rdfxml:trix2rdfxml($source-trix)
    else if ($o eq "ntriples") then
        trix2ntriples:trix2ntriples($source-trix)
    else if ($o eq "snelson") then
        xqilla:parse-json($source)
    else
        $source-trix

return $output



