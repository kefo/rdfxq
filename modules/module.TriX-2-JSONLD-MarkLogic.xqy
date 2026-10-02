xquery version "1.0";

(:
:   Module Name: TriX 2 JSONLD for MarkLogic
:
:   Module Version: 1.0
:
:   Date: 2014 May 09
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: none
:
:   Xquery Specification: January 2007
:
:   Module Overview:    Takes Trix, creates a map of the data, and sends
:       selected bits to the generic function.  Faster than the straight-forward
:       generic method.  MarkLogic specific.
:
:)
   
(:~
:   Takes Trix, creates a map of the data, and sends
:   selected bits to the generic function.  Faster than the straight-forward
:   generic method.  MarkLogic specific.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since May 9, 2014
:   @version 1.0
:)
module namespace    trix2jsonld-ml   = "http://3windmills.com/rdfxq/modules/trix2jsonld-ml#";

import module namespace rdfxqshared     = "http://3windmills.com/rdfxq/modules/rdfxqshared#" at "../modules/module.Shared.xqy";
import module namespace trix2jsonld     = "http://3windmills.com/rdfxq/modules/trix2jsonld#" at "../modules/module.TriX-2-JSONLD-Generic.xqy";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

declare namespace   map         = "http://marklogic.com/xdmp/map";

(:~
:   This is the main function.  Input TriX, output jsonld *compact.*
:   All other functions are local.
:
:   @param  $trix        node() is the TriX XML
:   @return jsonld as xs:string
:)
declare function trix2jsonld-ml:trix2jsonld(
        $trix as element(trix:TriX)
        ) as xs:string
{
    trix2jsonld-ml:trix2jsonld($trix, fn:false())
};


(:~
:   This is the main function.  Input TriX XML, output jsonld, expanded or 
:   compacted.  $expanded=false or $expanded=true, default is false
:
:   @param  $trix        node() is the TriX XML
:   @param  $expanded    boolean()
:   @return jsonld as xs:string
:)
declare function trix2jsonld-ml:trix2jsonld(
        $trix as element(trix:TriX),
        $expanded as xs:boolean
        ) as xs:string
{
    if ($expanded) then
        trix2jsonld-ml:trix2jsonld-expanded($trix)
    else
        trix2jsonld-ml:trix2jsonld-compact($trix)
};


(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2jsonld-ml:trix2jsonld-compact(
        $trix as element(trix:TriX)
        ) as xs:string
{

    let $namespaces := rdfxqshared:namespaces-from-trix($trix)
    let $context := trix2jsonld:get-context($namespaces)
    
    (: Walk the tree once and bucket the triples by subject in a single pass.
     : The previous version looped over the distinct subjects and re-scanned
     : //trix:triple for each one, which is O(subjects x triples) and cannot be
     : index-resolved because $trix is a constructed, in-memory node.  It also
     : built one element trix:Trix copy per subject, copying most of the tree
     : once per subject; the buckets now hold the original nodes instead. :)
    let $all-triples := $trix//trix:triple
    let $list-firsts := trix2jsonld:get-list-firsts($all-triples)
    let $m := map:map()
    let $build :=
        for $t in $all-triples
        let $s := xs:string($t/trix:*[1])
        return map:put($m, $s, (map:get($m, $s), $t))

    let $triples :=
        for $key in map:keys($m)
        let $subjects := map:get($m, $key)
        (: Subjects that only ever carry rdf:first/rdf:rest are list nodes; they
         : are serialised inline as "@list" by the resource that points at them,
         : so they are not emitted as members of "@graph". :)
        where $subjects[trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"] and trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"]]
        return trix2jsonld:get-compact-resource($namespaces, $subjects, $trix, $list-firsts)

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
declare function trix2jsonld-ml:trix2jsonld-expanded(
        $trix as element(trix:TriX)
    ) as xs:string
{

    (: Single pass bucketing by subject; see trix2jsonld-compact above for why. :)
    let $all-triples := $trix//trix:triple
    let $list-firsts := trix2jsonld:get-list-firsts($all-triples)
    let $m := map:map()
    let $build :=
        for $t in $all-triples
        let $s := xs:string($t/trix:*[1])
        return map:put($m, $s, (map:get($m, $s), $t))

    (:
    This appeared to make no speed difference.
    Keeping, for now, as a marker of something that has been tried and found 
    not to have an impact.
    :)
    (:
    let $m := map:map()
    let $build := 
        for $s in $trix//trix:triple/trix:*[1]
        let $s_str := xs:string($s)
        return 
            if ( fn:empty(map:get($m, $s_str)) ) then
                map:put($m, $s_str, element trix:Trix { $trix//trix:triple[trix:*[1] eq $s] })
            else
                ()
    :)
    
    let $triples :=
        for $key in map:keys($m)
        let $subjects := map:get($m, $key)
        where $subjects[trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"] and trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"]]
        return trix2jsonld:get-expanded-resource($subjects, $trix, $list-firsts)

    return fn:concat(
                "[ ",
                fn:string-join($triples, ", "),
                " ]"
                )

};
