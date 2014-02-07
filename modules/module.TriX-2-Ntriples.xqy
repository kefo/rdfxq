xquery version "1.0";

(:
:   Module Name: TriX 2 ntriples
:
:   Module Version: 1.0
:
:   Date: 2014 February 7
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: none
:
:   Xquery Specification: January 2007
:
:   Module Overview:    Takes RDF/XML converts to ntriples.
:       xdmp extension used in order to quote/escape otherwise valid
:       XML.
:
:)
   
(:~
:   Takes RDF/XML and transforms to ntriples.  xdmp extension 
:   used in order to quote/escape otherwise valid XML.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since February 7, 2014
:   @version 1.0
:)
module namespace    trix2ntriples   = "http://3windmills.com/rdfxq/modules/trix2ntriples#";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2ntriples:trix2ntriples(
        $trix as element(trix:TriX)
        ) as xs:string
{
    let $graphs := 
        for $g in $trix/trix:graph
        let $guri := xs:string($g/trix:uri)
        let $triples := 
            for $t in $g/trix:triple
            let $tstr := trix2ntriples:triple($t)
            return
                if ($guri eq "") then
                    $tstr
                else
                    fn:concat($guri, " ", $tstr)
        return fn:string-join($triples, "&#x0a;")
    return fn:string-join($graphs, "&#x0a;")
};



(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2ntriples:triple(
        $t as element(trix:triple)
        ) as xs:string
{
    let $spo := 
        for $a in $t/node()[fn:name()]
        return
            typeswitch($a)
                case element(trix:uri) return fn:concat("<" , xs:string($a), ">")
                case element(trix:id) return fn:concat("_:" , xs:string($a))
                case element(trix:plainLiteral) return 
                    if ($a/@xml:lang) then
                        fn:concat('"' , xs:string($a), '"@' , xs:string($a/@xml:lang) )
                    else 
                        fn:concat('"' , xs:string($a), '"')
                case element(trix:typedLiteral) return fn:concat('"' , xs:string($a), '"^^<', xs:string($a/@datatype), '>' )
                default return ""
    let $line := fn:string-join($spo, " ")
    let $line := fn:concat($line, " .")
    return fn:normalize-space($line)
};



