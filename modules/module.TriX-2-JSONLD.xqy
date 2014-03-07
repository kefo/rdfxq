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
    trix2jsonld:trix2jsonld($trix, fn:false())
};


(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2jsonld:trix2jsonld(
        $trix as element(trix:TriX),
        $expanded as xs:boolean
        ) as xs:string
{
    if ($expanded) then
        trix2jsonld:trix2jsonld-expanded($trix)
    else
        trix2jsonld:trix2jsonld-compact($trix)
};


(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2jsonld:trix2jsonld-compact(
        $trix as element(trix:TriX)
        ) as xs:string
{

    (:
        A) Create context:
            1) Determine namespaces, and prefixes.
            
        B) Output triples,
            condense lists
            
        
    :)
    let $distinct-predicates := fn:distinct-values($trix//trix:triple/trix:*[2]|$trix//@datatype)
    let $namespaces := 
            for $p in $distinct-predicates
            let $pns := 
                if ( fn:contains($p, "#") ) then
                    fn:concat(fn:substring-before($p, "#"), "#")
                else
                    let $parts := fn:tokenize(xs:string($p), "/")
                    return fn:concat( fn:string-join($parts[fn:not(fn:last())], "/"), "/" )
            return $pns
    let $namespaces := fn:distinct-values($namespaces)
    let $namespaces := 
        <namespaces>
            {
                for $p in $namespaces
                let $pprefix := 
                    if ( fn:contains($p, "#") ) then
                        let $ppart := fn:substring-before($p, "#")
                        let $parts := fn:tokenize(xs:string($ppart), "/")
                        let $pf := xs:string($parts[fn:last()])
                        return 
                            if ( $pf eq "22-rdf-syntax-ns" ) then
                                "rdf"
                            else
                                $pf
                    else
                        let $parts := fn:tokenize(xs:string($p), "/")
                        return xs:string($parts[fn:last() - 1])
                let $pprefix := 
                    if ( fn:not(fn:matches($pprefix, "^([A-Za-z])")) ) then
                        (: Must be a slash namespace :)
                        let $pp := fn:tokenize(xs:string($p), "/")[fn:last() - 2]
                        return
                            if ( fn:not(fn:matches($pp, "^([A-Za-z])")) ) then
                                "n0"
                            else
                                $pp
                    else
                        $pprefix
                return
                    element ns {
                        attribute value {$p},
                        $pprefix
                    }
            }
        </namespaces>

    let $context := 
        for $n in $namespaces/ns
        let $line := fn:concat('"', xs:string($n), '": "' , xs:string($n/@value), '"')
        return $line
    let $context := fn:string-join($context, ", ")
    let $context := fn:concat('"@context": { ', $context , '}')
    
    
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
            let $pns := 
                if ( fn:contains($dp, "#") ) then
                    fn:concat(fn:substring-before($dp, "#"), "#")
                else
                    let $parts := fn:tokenize(xs:string($dp), "/")
                    return fn:concat( fn:string-join($parts[fn:not(fn:last())], "/"), "/" )
            let $prefix := xs:string($namespaces/ns[@value eq $pns])
            let $pname := 
                if ( fn:contains($dp, "#") ) then
                    fn:substring-after($dp, "#")
                else
                    fn:tokenize(xs:string($dp), "/")[fn:last()]
            let $predicate := fn:concat('"' , $prefix, ':', $pname, '": ')
            let $predicate-objects := 
                if (fn:contains($predicate,"rdf:type")) then
                    let $num-types := fn:count($ts)
                    return
                        if ($num-types > 1) then
                            let $types := 
                                for $t in $ts/trix:*[3]
                                return fn:concat('"', xs:string($t), '"')
                            return
                                fn:concat(
                                    '"@type": ',
                                    "[ ", fn:string-join($types, ", "), " ]"
                                )
                        else
                            fn:concat('"@type": "', xs:string($ts/trix:*[3]), '"')
                else
                    for $t in $ts/trix:*[3]
                    let $o :=
                        if (fn:name($t) eq "trix:uri") then
                            fn:concat($predicate, '{ "@id": "', xs:string($t), '" }')
                        else if (fn:name($t) eq "trix:id") then
                            fn:concat($predicate, '{ "@id": "_:', xs:string($t), '" }')
                        else if (fn:name($t) eq "trix:typedLiteral") then
                            fn:concat($predicate, '{ "@type": "', xs:string($t/@datatype), '", "@value": "', xs:string($t), '" }')
                        else if ($t/@xml:lang) then
                            fn:concat($predicate, '{ "@language": "', xs:string($t/@xml:lang), '", "@value": "', xs:string($t), '" }')
                        else
                            fn:concat($predicate, '"', xs:string($t), '"')
                    return $o
            return $predicate-objects
        return
            fn:concat(
                " { ", 
                $id, ", ",
                fn:string-join($predicates, ", "),
                " }"
                )
    return fn:concat(
                "{ ", 
                $context, ', ', 
                '"@graph": [ ', fn:string-join($triples, ", "), ' ] ',
                " }"
                )
                (: fn:string-join($triples, "&#x0a;") :)
    
};   
    
(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2jsonld:trix2jsonld-expanded(
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
