xquery version "1.0";

(:
:   Module Name: JSONLD 2 TriX
:
:   Module Version: 1.0
:
:   Date: 2014 Feb 10
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: none
:
:   Xquery Specification: January 2007
:
:   Module Overview:    Assumes properly formatted JSON LD, 
:       which has already been converted to XML conforming to
:       Snelson's design [1, 2], and converts to TriX.
:
:       [1] http://john.snelson.org.uk/post/48547628468/parsing-json-into-xquery
:       [2] http://www.zorba.io/documentation/latest/modules/zorba/data-converters/json
:)
   
(:~
:   Takes JSON LD converts to XML, converts to TriX.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since February 10, 2014
:   @version 1.0
:)
module namespace    jsonld2trix   = "http://3windmills.com/rdfxq/modules/jsonld2trix#";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

(:
See here for example JSON LD files:
https://github.com/ruby-rdf/json-ld/tree/develop/example-files

Another example here: http://wiki.teria.no/display/inloc/JSON-LD
And here: http://robtweed.wordpress.com/2013/11/20/creating-json-ld-documents-from-within-mumps/

:)

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $json        as xs:string
:   @return trix:TriX as element
:)
declare function jsonld2trix:jsonld2trix(
    $jsonxml as element()
    ) as element(trix:TriX) {
    
    <trix:TriX></trix:TriX>
};


declare function jsonld2trix:get-context(
    $jsonxml as element()
    ) as element(context) {
    
    
};



