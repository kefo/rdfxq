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

import module namespace rdfxqshared     = "http://3windmills.com/rdfxq/modules/rdfxqshared#" at "../modules/module.Shared.xqy";

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

    let $namespaces := rdfxqshared:namespaces-from-trix($trix)
    let $context := trix2jsonld:get-context($namespaces)
    let $distinct-subjects := fn:distinct-values($trix//trix:triple[trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"] and trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"]]/trix:*[1])
    let $triples :=
        for $ds in $distinct-subjects
        let $subjects := $trix//trix:triple[trix:*[1] eq $ds]
        return trix2jsonld:get-compact-resource($namespaces, $subjects)
    return fn:concat(
                "{ ", 
                $context, ', ', 
                '"@graph": [ ', fn:string-join($triples, ", "), ' ] ',
                " }"
                )

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
                fn:concat('"@id": "', xs:string($subjects[1]/trix:*[1]), '"')
            else
                fn:concat('"@id": "_:', xs:string($subjects[1]/trix:*[1]), '"')
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

};


(:~
:   Returns a JSON object representing a 
:   compact JSON LD resource.
:
:   @param  $namespaces     namespace info to use 
:   @param  $subjects       as element(trix:triple) are the triples
:   @return item()*
:)
declare function trix2jsonld:get-compact-resource(
        $namespaces,
        $subjects as element(trix:triple)*
    ) as xs:string
{
    let $id := 
        if (fn:name($subjects[1]/trix:*[1]) eq "trix:uri") then
            fn:concat('"@id": "', xs:string($subjects[1]/trix:*[1]), '"')
        else
            fn:concat('"@id": "_:', xs:string($subjects[1]/trix:*[1]), '"')
    let $distinct-predicates := fn:distinct-values($subjects/trix:*[2])
    let $predicates := 
        for $dp in $distinct-predicates
        let $ts := $subjects[trix:*[2] eq $dp]
        let $pns := 
            if ( fn:contains($dp, "#") ) then
                fn:concat(fn:substring-before($dp, "#"), "#")
            else
                let $parts := fn:tokenize(xs:string($dp), "/")
                let $parts := 
                    for $p at $pos in $parts
                    where $pos < fn:count($parts)
                    return $p
                return fn:concat( fn:string-join($parts, "/"), "/" )
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
                let $num-types := fn:count($ts)
                return
                    if ($num-types > 1) then
                        let $objects := 
                            for $t in $ts/trix:*[3]
                            let $o :=
                                if (fn:name($t) eq "trix:uri") then
                                    fn:concat('{ "@id": "', xs:string($t), '" }')
                                else if (fn:name($t) eq "trix:id") then
                                    if ($t/parent::node()/following-sibling::node()[trix:*[1][. eq $t] and trix:*[2][. eq "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"]]) then
                                        (: we have a list :)
                                        let $listitems := trix2jsonld:get-listitem($t)
                                        return fn:concat('{ "@list": [ "' , fn:string-join($listitems, '", "'), '" ] }')
                                    else
                                        fn:concat('{ "@id": "_:', xs:string($t), '" }')
                                else if (fn:name($t) eq "trix:typedLiteral") then
                                    fn:concat('{ "@type": "', xs:string($t/@datatype), '", "@value": "', trix2jsonld:clean-string(xs:string($t)), '" }')
                                else if ($t/@xml:lang) then
                                    fn:concat('{ "@language": "', xs:string($t/@xml:lang), '", "@value": "', trix2jsonld:clean-string(xs:string($t)), '" }')
                                else
                                    fn:concat('"', trix2jsonld:clean-string(xs:string($t)), '"')
                                return $o
                            return 
                                fn:concat(
                                    $predicate,
                                    "[ ", fn:string-join($objects, ", "), " ]"
                                )
                    else
                        for $t in $ts/trix:*[3]
                        let $o :=
                            if (fn:name($t) eq "trix:uri") then
                                fn:concat($predicate, '{ "@id": "', xs:string($t), '" }')
                            else if (fn:name($t) eq "trix:id") then
                                if ($t/parent::node()/following-sibling::node()[trix:*[1][. eq $t] and trix:*[2][. eq "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"]]) then
                                    (: we have a list :)
                                    let $listitems := trix2jsonld:get-listitem($t)
                                    return fn:concat($predicate, '{ "@list": [ "' , fn:string-join($listitems, '", "'), '" ] }')
                                else
                                    fn:concat($predicate, '{ "@id": "_:', xs:string($t), '" }')
                            else if (fn:name($t) eq "trix:typedLiteral") then
                                fn:concat($predicate, '{ "@type": "', xs:string($t/@datatype), '", "@value": "', trix2jsonld:clean-string(xs:string($t)), '" }')
                            else if ($t/@xml:lang) then
                                fn:concat($predicate, '{ "@language": "', xs:string($t/@xml:lang), '", "@value": "', trix2jsonld:clean-string(xs:string($t)), '" }')
                            else
                                fn:concat($predicate, '"', trix2jsonld:clean-string(xs:string($t)), '"')
                        return $o
        return $predicate-objects
    return
        fn:concat(
            " { ", 
            $id, ", ",
            fn:string-join($predicates, ", "),
            " }"
            )  
};

(:~
:   Returns a JSON object representing a 
:   context for JSON LD resources.
:
:   @param  $namespaces
:   @return xs:string
:)
declare function trix2jsonld:get-context($namespaces)
    as xs:string
{
  
    let $context := 
        for $n in $namespaces/ns
        let $line := fn:concat('"', xs:string($n), '": "' , xs:string($n/@value), '"')
        return $line
    let $context := fn:string-join($context, ", ")
    let $context := fn:concat('"@context": { ', $context , '}')
    return $context
  
};

(:~
:   Returns a JSON object representing an 
:   expanded JSON LD resource.
:
:   @param  $first  as 
:   @return item()*
:)
declare function trix2jsonld:get-expanded-resource(
        $subjects as element(trix:triple)*
    ) as xs:string
{
    let $id := 
        if (fn:name($subjects[1]/trix:*[1]) eq "trix:uri") then
            fn:concat('"@id": "', xs:string($subjects[1]/trix:*[1]), '"')
        else
            fn:concat('"@id": "_:', xs:string($subjects[1]/trix:*[1]), '"')
    let $distinct-predicates := fn:distinct-values($subjects/trix:*[2])
    let $predicates := 
        for $dp in $distinct-predicates
        let $ts := $subjects[trix:*[2] eq $dp]
        let $predicate := 
            if (xs:string($dp) eq "http://www.w3.org/1999/02/22-rdf-syntax-ns#type") then
                '"@type": '
            else
                fn:concat('"' , xs:string($dp), '": ')
        let $object := 
            if (fn:contains($predicate,"@type")) then
                for $t in $ts/trix:*[3]
                return fn:concat('"', xs:string($t), '"')
            else
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
                                fn:concat('"@value": "', trix2jsonld:clean-string(xs:string($t)), '"')
                            ),
                            ",&#x0a;"
                        )
                    else if ($t/@xml:lang) then
                        fn:string-join(
                            (
                                fn:concat('"@language": "', xs:string($t/@xml:lang), '"'),
                                fn:concat('"@value": "', trix2jsonld:clean-string(xs:string($t)), '"')
                            ),
                            ",&#x0a;"
                        )
                    else
                            fn:concat('"@value": "', trix2jsonld:clean-string(xs:string($t)), '"')
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
};


(:~
:   This recusively returns list items.
:
:   @param  $first  as 
:   @return item()*
:)
declare function trix2jsonld:get-listitem(
        $first
        ) as item()*
{
    let $list-item := $first/parent::node()/following-sibling::node()[trix:*[1][. eq $first] and trix:*[2][. eq "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"]]/trix:*[3]
    let $next := $first/parent::node()/following-sibling::node()[trix:*[1][. eq $first] and trix:*[2][. eq "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"]]/trix:*[3]
    return
        if (xs:string($next) eq "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil") then
            $list-item
        else
            (
                $list-item,
                trix2jsonld:get-listitem($next)
            )
};

(:~
:   Clean string.  At present, only escapes double quotes
:
:   @param  $str as xs:string
:   @return xs:String
:)
declare function trix2jsonld:clean-string(
        $str as xs:string
        ) as xs:string
{
    let $str := fn:replace($str, '\\"', '"')
    let $str := fn:replace($str, '"', '\\"')
    return $str
};