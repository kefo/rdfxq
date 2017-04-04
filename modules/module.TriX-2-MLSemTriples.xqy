xquery version "1.0";

(:
:   Module Name: TriX 2 MarkLogic Semtriples
:
:   Module Version: 1.0
:
:   Date: 2016 November 1
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: none
:
:   Xquery Specification: January 2007
:
:   Module Overview:    Takes TriX converts to MarkLogic SemTriples.
:   
:
:)
   
(:~
:   Takes TriX converts to MarkLogic SemTriples.
:
:   @author Kevin Ford (kefo@3windmills.com)
:   @since November 1, 2016
:   @version 1.0
:)
module namespace    trix2mlsemtriples   = "http://3windmills.com/rdfxq/modules/trix2mlsemtriples#";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";
declare namespace   sem         = "http://marklogic.com/semantics";

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2mlsemtriples:trix2mlsemtriples(
        $trix as element(trix:TriX)
        ) as element(sem:triples)
{

    let $triples := 
        for $t in $trix//trix:triple
        let $tstr := trix2mlsemtriples:triple($t)
        return $tstr
    return element sem:triples { $triples }
    
};



(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2mlsemtriples:triple(
        $t as element(trix:triple)
        ) as element(sem:triple)
{
    let $spo := 
        for $a at $pos in $t/node()[fn:name()]
        let $semtriples_element := 
            if ($pos eq 1) then
                "sem:subject"
            else if ($pos eq 2) then
                "sem:predicate"
            else
                "sem:object"
        return
            element {$semtriples_element} {
                typeswitch($a)
                    case element(trix:uri) return xs:string($a)
                    case element(trix:id) return fn:concat("http://marklogic.com/semantics/blank/" , xs:string($a))
                    case element(trix:plainLiteral) return 
                        if ($a/@xml:lang) then
                            ($a/@xml:lang, fn:replace(xs:string($a), '\\"', '"'))
                        else 
                            (
                                attribute datatype { "http://www.w3.org/2001/XMLSchema#string" },
                                fn:replace(xs:string($a), '\\"', '"')
                            )
                    case element(trix:typedLiteral) return ($a/@datatype, fn:replace(xs:string($a), '\\"', '"'))
                    default return ""
            }
    return element sem:triple { $spo }
};



