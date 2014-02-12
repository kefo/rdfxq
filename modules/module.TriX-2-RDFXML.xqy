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
        $trix as element(trix:TriX)
        ) as element(rdf:RDF)
{
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
                return fn:concat( fn:string-join($parts[fn:not(fn:last())], "/"), "/" )
        
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

        let $pname := 
            if ( fn:contains($p, "#") ) then
                fn:substring-after($p, "#")
            else
                fn:tokenize(xs:string($p), "/")[fn:last()]
            
        let $pqname := fn:QName($pns, fn:concat($pprefix, ":", $pname))
        
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
    return
        element rdf:RDF {
            $triples
        }
};

