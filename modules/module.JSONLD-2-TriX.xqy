xquery version "1.0";

(:
:   Module Name: JSONLD 2 TriX
:
:   Module Version: 1.0
:
:   Date: 2014 Feb 10
:
:   Copyright: Public Domain
:
:   Proprietary XQuery Extensions Used: none
:
:   Xquery Specification: January 2007
:
:   Module Overview:    Assumes properly formatted JSON LD, 
:       which has already been converted to XML conforming to
:       Snelson's design [1, 2], and converts to TriX.
:
:       [1] http://john.snelson.org.uk/post/48547628468/parsing-json-into-xquery
:       [2] http://www.zorba.io/documentation/latest/modules/zorba/data-converters/json
:)
   
(:~
:   Takes JSON LD converts to XML, converts to TriX.
:
:   @author Kevin Ford (kefo@loc.gov)
:   @since February 10, 2014
:   @version 1.0
:)
module namespace    jsonld2trix   = "http://3windmills.com/rdfxq/modules/jsonld2trix#";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

declare namespace   sa          = "http://www.w3.org/2009/xpath-functions/analyze-string";

(:
See here for example JSON LD files:
https://github.com/ruby-rdf/json-ld/tree/develop/example-files

Another example here: http://wiki.teria.no/display/inloc/JSON-LD
And here: http://robtweed.wordpress.com/2013/11/20/creating-json-ld-documents-from-within-mumps/
https://dvcs.w3.org/hg/json-ld/raw-file/default/test-suite/reports/earl.jsonld

:)

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $json        as xs:string
:   @return trix:TriX as element
:)
declare function jsonld2trix:jsonld2trix(
    $jsonxml as element()
    ) as element(trix:TriX) {
    
    let $context := <context />
    let $triples :=
        for $o in $jsonxml[@type eq "object"]|$jsonxml/item[@type eq "object"]
        return jsonld2trix:parse-object($o, $context)
    
    let $context := jsonld2trix:set-context($context, $jsonxml[@type eq "object"]/pair[@name eq "@context"])
    let $graphs :=
        for $g in $jsonxml/pair[@name eq "@graph"]
        let $guri := ($g/preceding-sibling::node()[@name eq "@id"]|$g/following-sibling::node()[@name eq "@id"])[1]
        let $guri := xs:string($guri)
        return
            element trix:graph {
                if ($guri ne "") then
                    element trix:uri {$guri}
                else
                    (),
                    
                for $o in $g/item[@type eq "object"]
                return jsonld2trix:parse-object($o, $context)
            }
        
    return
        element trix:TriX {
            $triples,
            $graphs
        }
};



(:~
:   This function tests a string for a namespace prefix.
:   If one is found, it replaces it with the namespaces, concatenates
:   it with the value and returns it as a string.
:
:   @param  $str        as xs:string
:   @param  $context    as element(context)
:   @return xs:string
:)
declare function jsonld2trix:create-triple(
    $s as xs:string,
    $p as xs:string,
    $o as element()
    ) as element(trix:triple)
{
    element trix:triple {
        if ( fn:starts-with($s, "_:") ) then
            element trix:id { fn:replace($s, "_:", "") }
        else
            element trix:uri { $s },
        element trix:uri { $p },
        $o
    }
};


(:~
:   This function tests a string for a namespace prefix.
:   If one is found, it replaces it with the namespaces, concatenates
:   it with the value and returns it as a string.
:
:   @param  $str        as xs:string
:   @param  $context    as element(context)
:   @return xs:string
:)
declare function jsonld2trix:expand-uri(
    $str as xs:string,
    $context as element(context)
    ) as xs:string
{
    let $str-analysis := fn:analyze-string($str, ":")
    let $expanded-uri := 
        if ( 
            $str-analysis/sa:match[1] and 
            fn:not(fn:matches($str-analysis/sa:non-match[1], "http|info"))
            ) then
            let $ns := xs:string($context/ns[@prefix eq xs:string($str-analysis/sa:non-match[1])][1])
            let $s := fn:replace($str, fn:concat(xs:string($str-analysis/sa:non-match[1]), ":"), "")
            return fn:concat($ns, $s)
        else if ( 
            $str-analysis/sa:match[1] and 
            fn:matches($str-analysis/sa:non-match[1], "http|info")
            ) then
            $str
        else
            $str
            (: fn:concat($context/ns[@base eq "true"][1], $str) :)
    return $expanded-uri
};


(:~
:   This function parses a JSON object.  It can be called recursively, 
:   updating context each time.
:
:   @param  $str        as xs:string
:   @param  $context    as element(context)
:   @return xs:string
:)
declare function jsonld2trix:parse-object(
    $object as element(),
    $context as element(context)
    ) as element(trix:triple)*
{
    let $context := jsonld2trix:set-context($context, $object/pair[@name eq "@context"])
    let $uri := jsonld2trix:set-uri($object/pair[@name eq "@id"], $context)
    let $ts := 
        for $p in $object/pair[@name ne "@id" and @name ne "@context" and @name ne "@graph"]
        let $prop := $context/prop[@name eq xs:string($p/@name)][1]
        let $prop := 
            if ( fn:not($prop/@name) ) then
                let $pstr := xs:string($p/@name)
                let $p-expanded := jsonld2trix:expand-uri($pstr, $context)
                return 
                    element prop { 
                        attribute name {$pstr},
                        $p-expanded 
                    }
            else
                $prop
        let $t := 
            if ($p/@type eq "string") then
                if ($prop/@name eq "@type") then
                    (: RDF Type :)
                    let $pstr := xs:string($p)
                    let $p-expanded := jsonld2trix:expand-uri($pstr, $context)
                    let $o := element trix:uri { $p-expanded }
                    return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                else if ($prop/@datatype eq "@id") then
                    let $o := element trix:uri { xs:string($p) }
                    return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                else if ($prop/@datatype ne "") then
                    let $o := 
                        element trix:typedLiteral {
                            attribute datatype { xs:string($prop/@datatype) },
                            xs:string($p)
                        }
                    return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                else
                    let $o := 
                        element trix:plainLiteral {
                        xs:string($p)
                    }
                    return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                    
            else if ($p/@type eq "array") then
                for $a in $p/item
                return
                    if ($prop/@datatype eq "@id") then
                        let $o := element trix:uri { xs:string($a) }
                        return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                    else if ($prop/@datatype ne "") then
                        let $o := 
                            element trix:typedLiteral {
                                attribute datatype { xs:string($prop/@datatype) },
                                xs:string($a)
                            }
                        return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                    else if ($a/@type eq "object") then
                        if (
                                fn:count($a/pair[@name ne "@id"]) eq 0 and
                                $a/pair[@name eq "@id"]
                            ) then
                            let $o := element trix:uri { xs:string($a/pair[@name eq "@id"]) } 
                            return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                        else
                            let $o := 
                                element trix:plainLiteral {
                                    xs:string($a/pair[1])
                                }
                            return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                    else
                        let $o := 
                            element trix:plainLiteral {
                                xs:string($a)
                            }
                        return jsonld2trix:create-triple($uri, xs:string($prop), $o)
            
            else if 
                (
                    $p/@type eq "object" and
                    fn:count($p/pair[@name ne "@id"]) eq 0 and
                    $p/pair[@name eq "@id"]
                ) then
                (:  We have an JSON object with only an ID, 
                    which means it is the object of this triple
                :)
                let $o := element trix:uri { xs:string($p/pair[@name eq "@id"]) } 
                return jsonld2trix:create-triple($uri, xs:string($prop), $o)
            else if ($p/@type eq "object") then
                jsonld2trix:parse-object($p, $context)
            else
                ()
        return $t

    return $ts
};


declare function jsonld2trix:set-context(
    $context,
    $context-pair as element()*
    ) as element(context) 
{

    let $namespaces := 
        for $p in $context-pair/pair[@type eq "string"]|$context-pair/pair[@type eq "object"]/pair[@name eq "@id"]
        let $pstr := xs:string($p)
        let $pname := 
            if ( fn:starts-with(xs:string($p/@name), "@") ) then
                xs:string($p/../@name)
            else
                xs:string($p/@name)
        let $default := 
            if ($p/@name eq "@vocab") then
                fn:true()
            else
                fn:false()
        let $base := 
            if ($p/@name eq "@base") then
                fn:true()
            else
                fn:false()
        return
            if (fn:matches($pstr, "(#|/)$")) then
                (: We have a namespace :)
                element ns {
                    attribute prefix {$pname},
                    
                    if ($default) then
                        attribute default {"true"}
                    else
                        (),
                    
                    if ($base) then
                        attribute base {"true"}
                    else
                        (),
                        
                    $pstr
                }
            else
                ()
                
    let $temp-context := element context {$namespaces}
    
    let $properties := 
        (
            
            element prop {
                attribute name {"@type"},
                attribute datatype {"@id"},
                "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
            },


            for $p in $context-pair/pair[@type eq "string"]
            let $pstr := xs:string($p)
            return
                if ( fn:not(fn:matches($pstr, "(#|/)$")) ) then
                    (: We do NOT have a namespace :)
                    element prop {
                        $p/@name,
                        $pstr
                    }
                else
                    (),


            for $p in $context-pair/pair[@type eq "object"]
            let $pname := xs:string($p/@name)
            let $puri := 
                if ($p/pair[@name eq "@id"]) then
                    let $uriname := xs:string($p/pair[@name eq "@id"])
                    let $uriname-expanded := jsonld2trix:expand-uri($uriname, $temp-context)
                    return $uriname-expanded
                    
                else if ( fn:contains($pname, ":") ) then
                    let $pname-expanded := jsonld2trix:expand-uri($pname, $temp-context)
                    return $pname-expanded
                else if ($temp-context/ns[@default eq "true"]) then
                    fn:concat($temp-context/ns[@default eq "true"][1], $pname)
                else
                    $pname
            let $pdatatype := 
                if ($p/pair[@name eq "@type"]) then 
                    let $ptype := xs:string($p/pair[@name eq "@type"])
                    let $ptype-expanded := jsonld2trix:expand-uri($ptype, $temp-context)
                    return $ptype-expanded
                else
                    ""
            return 
                element prop {
                    attribute name {$pname},
                    attribute datatype {$pdatatype},
                    $puri
                }
        )
        
    return
        element context {
            $namespaces,
            $properties,
            $context/*
        }
};


declare function jsonld2trix:set-uri(
    $pair as element()*,
    $context as element(context)
    ) as xs:string
{
    if ( fn:empty($pair) ) then
        (: We need a bnode? :)
        (: Not confident this will be robust enough, we'll see :)
        let $currentDT := xs:string(fn:current-dateTime())
        let $currentDT := fn:replace($currentDT, ":|\-|\.", "")
        let $unique_num := xs:integer( fn:count($context/ancestor-or-self::node()) + fn:count($context//child::node()) )
        return fn:concat("_:bnode" , $currentDT, xs:string($unique_num))
    else
        let $uri := xs:string($pair)
        let $panalyze := fn:analyze-string($uri, ":")
        let $uri := 
            if ( 
                $panalyze/sa:match[1] and 
                fn:not(fn:matches($panalyze/sa:non-match[1], "http|info"))
                ) then
                    xs:string($context/ns[@prefix eq xs:string($panalyze/sa:non-match[1])][1])
            else if ($context/ns[@base eq "true"]) then
                fn:concat($context/ns[@base eq "true"][1], $uri)
            else
                $uri
        let $uri := 
            if (fn:empty($uri) or $uri = "") then
                xs:string($pair)
            else
                $uri
        return $uri
};





