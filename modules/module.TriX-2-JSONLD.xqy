xquery version "1.0";

(:
:   Module Name: TriX 2 JSONLD
:
:   Module Version: 1.0
:
:   Date: 2014 February 14
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
:   @since February 14, 2014
:   @version 1.0
:)
module namespace    trix2jsonld   = "http://3windmills.com/rdfxq/modules/trix2jsonld#";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2jsonld:trix2jsonld(
        $trix as element(trix:TriX)
        ) as xs:string
{

    let $distinct-subjects := fn:distinct-values($trix//trix:triple/trix:*[1])
    let $triples := 
        for $ds in $distinct-subjects
        let $subjects := $trix//trix:triple[trix:*[1] eq $ds]
        let $id := 
            if (fn:name($subjects[1]/trix:*[1]) eq "trix:uri") then
                fn:concat('"@id": "', xs:string($ds), '"')
            else
                fn:concat('"@id": "_:', xs:string($ds), '"')
        let $distinct-predicates := fn:distinct-values($subjects/trix:*[2])
        let $predicates := 
            for $dp in $distinct-predicates
            let $ts := $subjects[trix:*[2] eq $dp]
            let $predicate := fn:concat('"' , xs:string($dp), '": ')
            let $object := 
                for $t in $ts/trix:*[3]
                let $o :=
                    if (fn:name($t) eq "trix:uri") then
                        fn:concat('"@id": "', xs:string($t), '"')
                    else if (fn:name($t) eq "trix:id") then
                        fn:concat('"@id": "_:', xs:string($t), '"')
                    else if (fn:name($t) eq "trix:typedLiteral") then
                        fn:string-join(
                            (
                                fn:concat('"@type": "', xs:string($t/@datatype), '"'),
                                fn:concat('"@value": "', xs:string($t), '"')
                            ),
                            ",&#x0a;"
                        )
                    else if ($t/@xml:lang) then
                        fn:string-join(
                            (
                                fn:concat('"@language": "', xs:string($t/@xml:lang), '"'),
                                fn:concat('"@value": "', xs:string($t), '"')
                            ),
                            ",&#x0a;"
                        )
                    else
                        fn:concat('"@value": "', xs:string($t), '"')
                return
                    fn:concat("{ ", $o, " }")
            return 
                fn:concat(
                    $predicate,
                    "[ ", fn:string-join($object, ", "), " ]"
                    )
        return
            fn:concat(
                " { ", 
                $id, ", ",
                fn:string-join($predicates, ", "),
                " }"
                )
    return fn:concat(
                "[ ", 
                fn:string-join($triples, ", "),
                " ]"
                )
                (: fn:string-join($triples, "&#x0a;") :)
    
};
