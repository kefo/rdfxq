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
:   @param  $json        as element(json)
:   @return trix:TriX as element
:)
declare function jsonld2trix:jsonld2trix(
    $jsonxml as element()
    ) as element(trix:TriX) {
    jsonld2trix:jsonld2trix($jsonxml, "")
};


(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $json        as element(json)
:   @param  $graphuri    as xs:string
:   @return trix:TriX as element
:)
declare function jsonld2trix:jsonld2trix(
    $jsonxml as element(),
    $graphuri as xs:string
    ) as element(trix:TriX) {
    
    let $jsonxml := jsonld2trix:insert-jsonids($jsonxml, $graphuri)
    (: return element trix:TriX { $jsonxml } :)

    let $context := 
        <context>
            <fileuri>{$graphuri}</fileuri>
        </context>
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
        if ( fn:starts-with($s, "_:") or fn:starts-with($s, "bnode")) then
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

    let $expanded-uri := 
        if ( fn:matches($str, ":") ) then
            let $parts := fn:tokenize($str, ":")
            return
                (: If it *does not* begin with http or info, we are looking at a prefix. :)
                if (fn:not(fn:matches($parts[1], "http|info"))) then
                    let $ns := xs:string($context/ns[@prefix eq $parts[1]][1])
                    let $s := fn:replace($str, fn:concat($parts[1], ":"), "")
                    return fn:concat($ns, $s)
                else
                    $str
        else
            $str
    return $expanded-uri
};


(:~
:   This function traverse the JSON XML and inserts 
:   an \@id pair if necessary.
:
:   @param  $json        as element(json)
:   @return element
:)
declare function jsonld2trix:insert-jsonids(
    $jsonxml as element(),
    $graphuri as xs:string
    ) as element()* 
{
    
    for $i at $pos in $jsonxml
    
    (:
    let $tree := 
        for $a in $i/pair[@type eq "object"]
        return jsonld2trix:insert-jsonids($a, "")
    :)
    
    let $idexists := 
        if (
            $i/child::node()[@name eq "@id"]
            ) then
            fn:true()
        else
            fn:false()

    let $id := 
        if ($idexists) then
            $i/pair[@name eq "@id"]
        else if ($pos eq 1) then
            element pair {
                attribute name {"@id"},
                attribute type {"string"},
                jsonld2trix:set-uri($i, <context />)
            }
        else ()
    return
            element {fn:local-name($i)} {
                $i/@*,
                (: element dude {"hello"}, :)
                $i/child::node()[@name eq "@context"],
                
                if (fn:count($i/child::node()[fn:name()]) eq 1 and $i/pair[@type eq "array"]) then
                    ()
                else if (fn:count($i/child::node()[@name eq "@value"]) > 0) then
                    ()
                else
                    $id,
                
                for $a in $i/child::node()[fn:local-name()]
                return 
                    if (fn:exists($a/@name) and ($a/@name eq "@context" or $a/@name eq "@id")) then
                        ()
                    else if ($a/@type eq "object") then
                        jsonld2trix:insert-jsonids($a, "")
                    else if ($a/@type eq "array") then
                        element {fn:name($a)} {
                            $a/@*,
                            for $b in $a/child::node()[fn:local-name()]
                            return
                                if ($b/@type eq "object") then
                                    jsonld2trix:insert-jsonids($b, "")
                                else
                                    $b
                        }
                    else
                        $a
                
            }
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
    let $seed := fn:string-join($object/text()|$object/pair/text(), "")
    let $seed :=
        if ( xs:string($seed) ne "" ) then
            xs:string($seed)
        else
            fn:replace(xs:string(fn:current-dateTime()), ":|\.|\-", "")
    let $uri := 
        if (
            fn:count($context/prop[@name eq "@type"]) < 2 and
            ( fn:not($object/pair[@name eq "@id"]) or $object/pair[@name eq "@id"][1] eq "" )
            ) then
            xs:string($context/fileuri)
        else
            $object/pair[@name eq "@id"][1]
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
                        attribute datatype {""},
                        attribute container {""},
                        attribute language {""},
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
                            if ($prop[@language ne ""]) then
                                attribute xml:lang { fn:lower-case(xs:string($prop/@language)) }
                            else
                                (),
                        xs:string($p)
                    }
                    return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                    
            else if ($p/@type eq "array" and $prop/@container ne "@list") then
                for $a at $pos in $p/item
                return
                    if ($prop/@datatype eq "@id") then
                        let $id := xs:string($a)
                        let $o := 
                            if ( fn:starts-with($id, "_:") ) then
                                element trix:id { fn:replace($id, "_:", "") }
                            else
                                element trix:uri { $id }
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
                            let $id := xs:string($a/pair[@name eq "@id"])
                            let $o := 
                                if ( fn:starts-with($id, "_:") ) then
                                    element trix:id { fn:replace($id, "_:", "") }
                                else
                                    element trix:uri { $id }
                            return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                        else if ( fn:count($a/pair[@name eq "@id"]) eq 0 ) then
                            let $o := 
                                if ($a/pair[@name eq "@type"]) then
                                    element trix:typedLiteral {
                                        attribute datatype { xs:string($a/pair[@name eq "@type"]) },
                                        xs:string($a/pair[@name eq "@value"])
                                    }
                                else
                                    element trix:plainLiteral {
                                        if ($a/pair[@name eq "@language"]) then
                                            attribute xml:lang { fn:lower-case(xs:string($a/pair[@name eq "@language"])) }
                                        else
                                            (),
                                        xs:string($a/pair[@name eq "@value"])
                                    }
                            return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                        else
                            let $object := jsonld2trix:parse-object($a, $context)
                            let $object-uri := $object[1]/trix:*[1]
                            return (
                                jsonld2trix:create-triple($uri, xs:string($prop), $object-uri),
                                $object
                            )
                            (:
                            let $o := 
                                element trix:plainLiteral {
                                    xs:string($a/pair[1])
                                }
                            return jsonld2trix:create-triple($uri, xs:string($prop), $o)
                            :)
                    else if ($a/@name eq "@type") then
                        (: RDF Type :)
                        let $property := xs:string($context/prop[@name eq "@type"][1])
                        let $o := element trix:uri { xs:string($a) }
                        return jsonld2trix:create-triple($uri, $property, $o)    
                        
                    else
                        let $o := 
                            element trix:plainLiteral {
                                xs:string($a)
                            }
                        return jsonld2trix:create-triple($uri, xs:string($prop), $o)
            
            else if 
                (
                    $p/@type eq "object" and
                    fn:count($p/pair) eq 1 and
                    $p/pair[@name eq "@id"]
                ) then
                (:  We have an JSON object with only an ID, 
                    which means it is the object of this triple
                :)
                let $o := element trix:uri { xs:string($p/pair[@name eq "@id"]) } 
                return jsonld2trix:create-triple($uri, xs:string($prop), $o)
            else if (
                $p/@type eq "object" and 
                $p/pair[@name eq "@value"]
                ) then
                let $o := 
                    if ($p/pair[@name eq "@type"]) then
                        element trix:typedLiteral {
                            attribute datatype { xs:string($p/pair[@name eq "@type"]) },
                            xs:string($p/pair[@name eq "@value"])
                        }
                    else
                        element trix:plainLiteral {
                            if ($p/pair[@name eq "@language"]) then
                                attribute xml:lang { fn:lower-case(xs:string($p/pair[@name eq "@language"])) }
                            else
                                (),
                            xs:string($p/pair[@name eq "@value"])
                        }
                return jsonld2trix:create-triple($uri, xs:string($prop), $o)
            
            else if (
                        (
                            $p/@type eq "object" and 
                            $p/pair[1][@type eq "array"] and
                            $p/pair[1][@name eq "@list"]
                        ) or (
                            $p/@type eq "array" and $prop/@container eq "@list"
                        )
                    ) then
                let $items := 
                    if (
                            $p/@type eq "object" and 
                            $p/pair[@type eq "array"] and
                            $p/pair[@name eq "@list"]
                        ) then
                        $p/pair[@type eq "array"]/item
                    else
                        $p/item
                for $a at $pos in $items
                (: Fucking lists :)
                let $following-uri := 
                    if (fn:count($a/../item) > $pos) then
                        let $following-a := $items[$pos + 1]
                        return jsonld2trix:set-uri($following-a, $context)
                    else
                        "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"
                        
                let $following-uri :=
                    if ( fn:starts-with($following-uri, "_:") ) then
                        element trix:id { fn:replace($following-uri, "_:", "") }
                    else
                        element trix:uri { $following-uri }

                (: This may not be necessary :)
                let $subject := 
                    if ($a/@name eq "@id") then
                        element trix:uri { xs:string($a) }
                    else
                        let $u := jsonld2trix:set-uri($a, $context)
                        let $u := fn:replace($u, "_:", "")
                        return element trix:id { $u }
                        (:element trix:id { fn:concat(jsonld2trix:set-uri((), $context, fn:concat($seed, "3xyz")), $pos) } :)

                let $object :=     
                    if (
                        $a/@type eq "object"
                        ) then
                        
                        if (
                            fn:count($a/pair) eq 1 and
                            $a/pair[@name eq "@id"]
                        ) then
                        (:  
                            We have an JSON object with only an ID, 
                            which means it is the object of this triple
                        :)
                        let $obj-uri := xs:string($a/pair[@name eq "@id"]) (: jsonld2trix:set-uri($a/pair, $context) :)
                        return
                            if ( fn:starts-with($obj-uri, "_:") ) then
                                element trix:id { fn:replace($obj-uri, "_:", "") }
                            else
                                element trix:uri { $obj-uri }
                        else
                            jsonld2trix:parse-object($a, $context)
                    else if ($a/@type eq "string") then
                        element trix:plainLiteral {
                            xs:string($a)
                        }
                    else
                        element trix:plainLiteral {"NO GOOD"}
                let $object-uri := 
                    if (fn:name($object[1]) eq "trix:triple") then
                        $object[1]/trix:*[1]
                    else
                        $object
                let $object := 
                    if (fn:name($object[1]) eq "trix:triple") then
                        $object
                    else
                        ()
                    
                return
                    if ($pos eq 1) then
                        (: needs a first and rest :)
                        (
                            jsonld2trix:create-triple($uri, xs:string($prop), $subject),
                            jsonld2trix:create-triple($subject, "http://www.w3.org/1999/02/22-rdf-syntax-ns#first", $object-uri),
                            jsonld2trix:create-triple($subject, "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest", $following-uri),
                            $object
                        )
                    else if ($pos eq $a/fn:last()) then
                        (
                            jsonld2trix:create-triple($subject, "http://www.w3.org/1999/02/22-rdf-syntax-ns#first", $object-uri),
                            jsonld2trix:create-triple($subject, "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest", $following-uri),
                            $object
                        )
                    else
                        (: needs a first and rest :)
                        (
                            jsonld2trix:create-triple($subject, "http://www.w3.org/1999/02/22-rdf-syntax-ns#first", $object-uri),
                            jsonld2trix:create-triple($subject, "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest", $following-uri),
                            $object
                        )
            else if ($p/@type eq "object") then
                let $object := jsonld2trix:parse-object($p, $context)
                let $object-uri := $object[1]/trix:*[1]
                return
                    (
                        jsonld2trix:create-triple($uri, xs:string($prop), $object-uri),
                        $object
                    )
            else
                () (: jsonld2trix:create-triple($uri, "whatever", element trix:literal{ $prop }) :)
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
                attribute container {""},
                attribute language {""},
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
            let $pcontainer := xs:string($p/pair[@name eq "@container"])
            let $planguage := xs:string($p/pair[@name eq "@language"])

            return 
                element prop {
                    attribute name {$pname},
                    attribute datatype {$pdatatype},
                    attribute container {$pcontainer},
                    attribute language {$planguage},
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
    
    (: We need a bnode? :)
    (: Not confident this will be robust enough, we'll see :)
    let $seed := fn:string-join($pair/@*/text()|$pair/text()|$pair/pair/text()|$pair/item/text(), "")
    let $seed := fn:string-join($pair/@*/text()|$pair//text(), "")
    let $seed :=
        if ( xs:string($seed) ne "" ) then
            xs:string($seed)
        else
            fn:replace(xs:string(fn:current-dateTime()), ":|\.|\-", "")
    let $s := fn:sum(fn:string-to-codepoints($seed))
    let $randnum := (69069 * $s + 1) mod 4294967296
    let $num := xs:integer( fn:count($context/ancestor-or-self::node()) + fn:count($context//child::node()) )
    return fn:concat("_:bnode" , xs:string($num), xs:string($randnum))
        
};





