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
    
    let $distinct-subjects := fn:distinct-values($trix//trix:triple[trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"] and trix:*[2][. ne "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"]]/trix:*[1])
    let $m := map:map()
    let $build := 
        for $t in $distinct-subjects
        return map:put($m, xs:string($t), element trix:Trix { $trix//trix:triple[trix:*[1] eq $t] })
    
    let $triples := 
        for $key in map:keys($m)
        let $allsubjects := map:get($m, $key)
        let $subjects := $allsubjects//trix:triple
        return trix2jsonld:get-compact-resource($namespaces, $subjects, $trix)

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

    let $distinct-subjects := fn:distinct-values($trix//trix:triple/trix:*[1])
    let $m := map:map()
    let $build := 
        for $t in $distinct-subjects
        return map:put($m, xs:string($t), element trix:Trix { $trix//trix:triple[trix:*[1] eq $t] })
    
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
        let $allsubjects := map:get($m, $key)
        let $subjects := $allsubjects//trix:triple
        return trix2jsonld:get-expanded-resource($subjects)
        
    return fn:concat(
                "[ ", 
                fn:string-join($triples, ", "),
                " ]"
                )

};
