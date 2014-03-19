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
module namespace    trix2rdfxml   = "http://3windmills.com/rdfxq/modules/trix2rdfxml#";

import module namespace rdfxqshared = "http://3windmills.com/rdfxq/modules/rdfxqshared#" at "../modules/module.Shared.xqy";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function trix2rdfxml:trix2rdfxml(
        $trix as element(trix:TriX),
        $abbreviated as xs:boolean
        ) as element(rdf:RDF)
{
    let $namespaces := rdfxqshared:namespaces-from-trix($trix)
    let $triples := 
        for $g in $trix//trix:triple
        
        let $s := $g/trix:*[1]
        let $p := $g/trix:*[2]
        let $o := $g/trix:*[3]
        
        let $pns := 
            if ( fn:contains($p, "#") ) then
                fn:concat(fn:substring-before($p, "#"), "#")
            else
                let $parts := fn:tokenize(xs:string($p), "/")
                let $parts := 
                    for $p at $pos in $parts
                    where $pos < fn:count($parts)
                    return $p
                return fn:concat( fn:string-join($parts, "/"), "/" )
                
        let $pname := 
            if ( fn:contains($p, "#") ) then
                fn:substring-after($p, "#")
            else
                fn:tokenize(xs:string($p), "/")[fn:last()]

        let $pqname := fn:QName($pns, fn:concat($namespaces/ns[@value eq $pns], ":", $pname))
        
        return
            element rdf:Description {
                if ( fn:name($s) eq "trix:uri" ) then
                    attribute rdf:about { xs:string($s) }
                else if ( fn:name($s) eq "trix:id" ) then
                    attribute rdf:nodeID { xs:string($s) }
                else
                    (),
                element { $pqname } {
                    if ( fn:name($o) eq "trix:uri" ) then
                        attribute rdf:resource { xs:string($o) }
                    else if ( fn:name($o) eq "trix:id" ) then
                        attribute rdf:nodeID { xs:string($o) }
                    else if ( fn:name($o) eq "trix:typedLiteral" ) then
                        (
                            attribute rdf:datatype {$o/@datatype},
                            xs:string($o)
                        )
                    else
                        (
                            $o/@xml:lang,
                            xs:string($o)
                        )
                }
            }
    let $triples := 
        if ($abbreviated) then
            let $distinct-abouts := fn:distinct-values($triples/@rdf:about)
            let $abouts := 
                for $s in $distinct-abouts
                let $ts := $triples[@rdf:about = $s]/child::node()[fn:name()]
                return
                    element rdf:Description {
                        attribute rdf:about {$s},
                        $ts
                    }
            let $distinct-ids := fn:distinct-values($triples/@rdf:nodeID)
            let $ids := 
                for $s in $distinct-ids
                let $ts := $triples[@rdf:nodeID = $s]/child::node()[fn:name()]
                return
                    element rdf:Description {
                        attribute rdf:nodeID {$s},
                        $ts
                    }
            return ($abouts, $ids)
        else
            $triples
    return
        element rdf:RDF {
            $triples
        }
};

