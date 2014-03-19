xquery version "1.0";

(:
:   Module Name: RDFXML 2 ntriples
:
:   Module Version: 1.0
:
:   Date: 2010 Oct 18
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
:   NB: This file has been modified to remove a ML dependency at
:   around line 126 (xdmp:quote).  Could be a problem for Literal types.  
:)
   
(:~
:   Takes RDF/XML and transforms to ntriples.  xdmp extension 
:   used in order to quote/escape otherwise valid XML.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since October 18, 2010
:   @version 1.0
:)
module namespace    ntriples2trix   = "http://3windmills.com/rdfxq/modules/ntriples2trix#";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

declare namespace   sa          = "http://www.w3.org/2009/xpath-functions/analyze-string";

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function ntriples2trix:ntriples2trix(
    $ntriples as xs:string
    ) as element(trix:TriX) {
    
    let $triples := 
        for $tstr in fn:tokenize($ntriples, "\n")
        where fn:normalize-space($tstr) ne ""
        return ntriples2trix:triple($tstr)
            
    let $trix := 
        element trix:TriX {
            $triples
        }
    return $trix
};


declare function ntriples2trix:triple(
    $tstr as xs:string
    ) as element(trix:triple)
{
    
    let $t := fn:tokenize($tstr, " ")
    
    let $s := 
        if ( fn:starts-with($t[1], "_") ) then
            let $sstr := fn:substring($t[1], 3)
            return element trix:id { $sstr }
        else
            let $sstr := fn:substring($t[1], 2)
            let $sstr := fn:substring($sstr, 1, fn:string-length($sstr) - 1)
            return element trix:uri { $sstr }
    
    let $p := fn:substring($t[2], 2)
    let $p := fn:substring($p, 1, fn:string-length($p) - 1)
    let $p := element trix:uri { $p }
        
    let $o := fn:string-join( $t[fn:position() ne 1 and fn:position() ne 2], " ")
    let $o := fn:normalize-space($o)
    let $o := 
        if ( fn:ends-with($o, ".") ) then
            fn:substring($o, 1, fn:string-length($o) - 1)
        else 
            $o
    let $o := fn:normalize-space($o)
    let $o :=
        if ( fn:starts-with($o, "_") ) then
            (: Blank node :)
            let $ostr := fn:substring($o, 3)
            return element trix:id { $ostr }
        else if ( fn:starts-with($o, "<") ) then
            (: URI :)
            let $ostr := fn:substring($o, 2)
            let $ostr := fn:substring($ostr, 1, fn:string-length($ostr) - 1)
            return element trix:uri { $ostr }
        else if ( fn:matches($o, "@[a-zA-Z]{2}$") ) then
            (: Plain literal with language tag :)
            let $langtag := fn:lower-case(fn:normalize-space(fn:substring-after($o, '"@')))
            let $ostr := fn:substring-before($o, '"@')
            let $ostr := fn:substring($ostr, 2)
            return 
                element trix:plainLiteral {
                    attribute xml:lang { $langtag },
                    $ostr
                }
        else if ( fn:matches($o, "\^\^(<)([a-zA-Z0-9/%#\-:\.]+)(>)$") ) then
            (: Typed literal :)
            let $datatype := fn:normalize-space(fn:substring-after($o, '"^^'))
            let $datatype := fn:replace($datatype, "<>", "")
            let $ostr := fn:substring-before($o, '"^^')
            let $ostr := fn:substring($ostr, 2)
            return 
                element trix:typedLiteral {
                    attribute datatype { $datatype },
                    $ostr
                }
        else
            (: Plain literal :)
            let $ostr := fn:substring($o, 2)
            let $ostr := fn:substring($ostr, 1, fn:string-length($ostr) - 1)
            return element trix:plainLiteral { $ostr }
    
    return
        element trix:triple { $s, $p, $o }
    
};


