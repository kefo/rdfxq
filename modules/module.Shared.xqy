xquery version "1.0";

(:
:   Module Name: Shared funcs
:
:   Module Version: 1.0
:
:   Date: 2014 March 19
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: none
:
:   Xquery Specification: January 2007
:
:   Module Overview:    Shared functions, string cleaning and namespace
:       stuff.
:
:)
   
(:~
:   Shared functions, string cleaning and namespace stuff.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since March 19, 2014
:   @version 1.0
:)
module namespace    rdfxqshared   = "http://3windmills.com/rdfxq/modules/rdfxqshared#";

declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";


(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function rdfxqshared:namespaces-from-trix(
        $trix as element(trix:TriX)
        ) as element(namespaces)
{
    let $distinct-predicates := fn:distinct-values($trix//trix:triple/trix:*[2]|$trix//@datatype)
    let $namespaces := 
            for $p in $distinct-predicates
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
    return $namespaces
};