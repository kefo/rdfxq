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
module namespace    rdfxml2trix   = "http://3windmills.com/rdfxq/modules/rdfxml2trix#";

declare namespace   rdf         = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace   trix        = "http://www.w3.org/2004/03/trix/trix-1/";

(:~
:   This is the main function.  Input RDF/XML, output ntiples.
:   All other functions are local.
:
:   @param  $rdfxml        node() is the RDF/XML  
:   @return ntripes as xs:string
:)
declare function rdfxml2trix:rdfxml2trix(
    $rdfxml as element(rdf:RDF)
    ) as element(trix:TriX) {
    
    let $triples := 
        for $i in $rdfxml/child::node()[fn:name()]
        return rdfxml2trix:parse_class($i, "", "")
    let $trix := 
        element trix:TriX {
            $triples
        }
    return $trix
};

(:~
:   This function parses a RDF Class.
:
:   @param  $node        node()
:   @param  $uri_pass   xs:string, is the URI passed 
:                       from the property evaluation and to be
:                       used in the absence of a rdf:about or rdf:nodeID  
:   @return ntripes as xs:string
:)
declare function rdfxml2trix:parse_class(
    $node as node(), 
    $uri_pass,
    $uri4bnode
    ) as item()* {
        
    let $_uri4bnode := 
        if ($uri4bnode ne "") then
            $uri4bnode
        else
            let $mainuri := 
                if (xs:string($uri_pass) ne "") then
                    $uri_pass
                else if ($node/@rdf:about ne "") then
                    element trix:uri { fn:string($node/@rdf:about) }
                else if ($node/@rdf:about eq "") then
                    element trix:uri { fn:string($node/ancestor::rdf:RDF[1]/@xml:base) }
                else if ($node/@rdf:nodeID) then
                    element trix:id { xs:string($node/@rdf:nodeID) }
                else if ($node/@rdf:ID ne "" and $node/ancestor::rdf:RDF[1]/@xml:base) then
                    element trix:uri { fn:concat(xs:string($node/ancestor::rdf:RDF[1]/@xml:base), xs:string($node/@rdf:ID) ) }
                else
                    "noidentifier"
            return rdfxml2trix:return_uri4bnode($mainuri)
    
    let $subject :=
        if (xs:string($uri_pass) ne "") then
            $uri_pass
        else if ($node/@rdf:about ne "") then
            element trix:uri { fn:string($node/@rdf:about) }
        else if ($node/@rdf:about eq "") then
            element trix:uri { fn:string($node/ancestor::rdf:RDF[1]/@xml:base) }
        else if ($node/@rdf:nodeID) then
            element trix:id { xs:string($node/@rdf:nodeID) }
        else if ($node/@rdf:ID ne "" and $node/ancestor::rdf:RDF[1]/@xml:base) then
            element trix:uri { fn:concat(xs:string($node/ancestor::rdf:RDF[1]/@xml:base), xs:string($node/@rdf:ID) ) }
        else
            element trix:id { rdfxml2trix:return_bnode($node, $_uri4bnode) }
    let $triple := 
        if (fn:local-name($node) eq "Description") then
            (: fn:concat( $uri, " <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <" , $node/child::node()[fn:name(.) eq "rdf:type"]/@rdf:resource , "> . " , fn:codepoints-to-string(10)) :)
            ()
        else if (fn:namespace-uri($node) and fn:local-name($node)) then
            element trix:triple {
                $subject,
                element trix:uri { "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" },
                element trix:uri { fn:concat(fn:namespace-uri($node) , fn:local-name($node)) }
            }
        else if (fn:namespace-uri($node/parent::node()) and fn:local-name($node)) then
            (: this is hardly sound, but seems to fix the issue :)
            element trix:triple {
                $subject,
                element trix:uri { "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" },
                element trix:uri { fn:concat(fn:namespace-uri($node/parent::node()) , fn:local-name($node)) }
            }
        else 
            ()
    
    return
        if ($node/child::node()[fn:name()]) then
            let $properties := 
                for $i in $node/child::node()[fn:name()]
                return rdfxml2trix:parse_property($i , $subject, $_uri4bnode)
            return 
                (
                    $triple, 
                    $properties
                )
        else
            $triple
};

(:~
:   This function parses a RDF Property
:
:   @param  $node       node()
:   @param  $uri        xs:string, is the URI passed 
:                       from the Class evaluation
:   @return ntripes as xs:string
:)
declare function rdfxml2trix:parse_property(
    $node as node(), 
    $subject,
    $_uri4bnode as xs:string
    ) as element(trix:triple)* {
    
    let $predicate := element trix:uri { fn:concat(fn:namespace-uri($node) , fn:local-name($node)) }
    
    let $object := 
        if ($node/@rdf:resource) then
            element trix:uri { xs:string($node/@rdf:resource) }
        else if ($node[@rdf:parseType eq "Collection"] and fn:not($node/@rdf:nodeID)) then
            element trix:id { rdfxml2trix:return_bnode($node/child::node()[fn:name()][1], $_uri4bnode) }
        else if ($node[@rdf:parseType eq "Resource"] and fn:not($node/@rdf:nodeID)) then
            element trix:id { rdfxml2trix:return_bnode($node[fn:name()][1], $_uri4bnode) }
        else if ($node/child::node()[fn:name()][1]/@rdf:nodeID) then
            element trix:id { fn:concat("_:" , fn:data($node/child::node()[fn:name()][1]/@rdf:nodeID)) }
        else if ($node/child::node()[fn:name()][1]/@rdf:about) then
            element trix:uri { xs:string($node/child::node()[fn:name()][1]/@rdf:about) }
        else if ($node[@rdf:parseType eq "Literal"]) then
            (:
            let $plainLiteral := 
                fn:concat('"' , 
                    fn:replace(
                        fn:replace(
                            fn:replace(
                                fn:string-join($node//text(), " "), 
                                '&quot;',
                                '\\"'
                            ),
                            '\n',
                            '\\r\\n'
                        ),
                        "\t",
                        '\\t'
                    ),
                '"')
            :)
            let $plainLiteral := fn:string-join($node//text(), " ")
            let $plainLiteral := fn:replace($plainLiteral, "\n", " ")
            let $plainLiteral := fn:replace($plainLiteral, "\t", " ")
            return element trix:plainLiteral { $plainLiteral }
            (: '"Comment"' :)
        else if (fn:local-name($node/child::node()[fn:name()][1]) ne "") then
            element trix:id { rdfxml2trix:return_bnode($node/child::node()[fn:name()][1], $_uri4bnode) }
        else
            let $typedLiteral := rdfxml2trix:clean_string(xs:string($node))
            return
                if ($node/@rdf:datatype) then
                    element trix:typedLiteral { 
                        attribute datatype { xs:string($node/@rdf:datatype) },
                        rdfxml2trix:clean_string(xs:string($node)) 
                    }
                else 
                    element trix:plainLiteral { 
                        $node/@xml:lang,
                        $typedLiteral 
                    }

    let $triple := 
        element trix:triple {
            $subject,
            $predicate,
            $object
        }

    return
        if ($node/child::node()[fn:name()]) then
            (
                $triple, 
    
                if ($node/@rdf:parseType eq "Collection") then
                    let $classes := rdfxml2trix:parse_collection($node/child::node()[fn:name()][1] , $object, $_uri4bnode)
                    return $classes
                
                else if ($node/@rdf:parseType eq "Resource") then
                    let $class := element rdf:Description { $node/child::node()[fn:name()] }
                    return rdfxml2trix:parse_class($class , $object, $_uri4bnode)
                
                else if (fn:not($node/@rdf:parseType)) then
                    let $classes := 
                        for $i in $node/child::node()[fn:name()]
                        return rdfxml2trix:parse_class($i , $object, $_uri4bnode)
                    return $classes
                
                else
                    ()
            )
        else
            $triple

};

(:~
:   Parse a rdf:parseType="Collection" element
:
:   @param  $node       node()
:   @param  $uri        xs:string, is the URI passed 
:                       from the Property evaluation
:   @return ntripes as xs:string
:)
declare function rdfxml2trix:parse_collection(
    $node as node(), 
    $subject,
    $_uri4bnode as xs:string
    ) as item()* {
    
    let $predicate := element trix:uri { "http://www.w3.org/1999/02/22-rdf-syntax-ns#first" }
    
    let $object := 
        if ($node/@rdf:resource) then
            element trix:uri { xs:string($node/@rdf:resource) }
        else if ($node/@rdf:about) then
            element trix:uri { xs:string($node/@rdf:about) }
        else if ($node/@rdf:nodeID) then
            element trix:id { xs:string($node/@rdf:nodeID) }
        else
            element trix:id { rdfxml2trix:return_bnode($node/child::node()[fn:name()][1], $_uri4bnode) }
            
    let $triple := 
        element trix:triple {
            $subject,
            $predicate,
            $object
        }
    
    let $following_bnode :=
        if ($node/following-sibling::node()[fn:name()][1]) then 
            element trix:id { rdfxml2trix:return_bnode_collection($node/following-sibling::node()[fn:name()][1]) }
        else 
            fn:false()
    let $rest := 
        if ($following_bnode) then
            element trix:triple {
                $subject,
                element trix:uri { "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest" },
                $following_bnode
            }
        else
            element trix:triple {
                $subject,
                element trix:uri { "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest" },
                element trix:uri { "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil" }
            }

    let $class := rdfxml2trix:parse_class($node, $object, $_uri4bnode)
        
    return
        if ($following_bnode) then
            let $sibling :=  rdfxml2trix:parse_collection($node/following-sibling::node()[fn:name()][1] , $following_bnode, $_uri4bnode)
            return 
                (
                    $triple, 
                    $rest, 
                    $class, 
                    $sibling
                )
        else
            ($triple, $rest, $class)

};

(:~
:   Helper funtion, to return a _bnode
:
:   @param  $node       node()
:   @return _bnode as xs:string
:)
declare function rdfxml2trix:return_bnode($node as node(), $_uri4bnode as xs:string) as xs:string
 {
    let $unique_num := xs:integer( fn:count($node/ancestor-or-self::node()) + fn:count($node/preceding::node()) )
    return fn:concat("b" , xs:string($unique_num) , $_uri4bnode)
};

(:~
:   Helper funtion, to return a _bnode for a collection
:
:   @param  $node       node()
:   @return _bnode as xs:string
:)
declare function rdfxml2trix:return_bnode_collection($node as node()) as xs:string {
    let $unique_num := xs:integer( fn:count($node/ancestor-or-self::node()) + fn:count($node/preceding::node()) )
    return fn:concat("b" , "0" , xs:string($unique_num))
};

(:~
:   bnode distinction - munges the URI in an attempt to 
:   create a better probability for bnode uniqueness
:
:   @param  $uri        xs:string
:   @return _bnode      as xs:string
:)
declare function rdfxml2trix:return_uri4bnode($uri as xs:string) as xs:string {
    let $uriparts := fn:tokenize($uri, '/')
    let $uriparts4bnode := 
            for $u in $uriparts
            let $str := 
                if ( fn:matches($u , ':|#') eq fn:false() ) then
                    fn:replace($u, '\.', 'dOt')
                else ()
            return $str
    return fn:string-join( $uriparts4bnode , '')
};


(:~
:   Clean string of odd characters.
:
:   @param  $string       string to clean
:   @return xs:string
:)
declare function rdfxml2trix:clean_string($str as xs:string) as xs:string
 {
    let $str := fn:replace( $str, '\\', '\\\\')
    let $str := fn:replace( $str , '&quot;' , '\\"')
    let $str := fn:replace( $str, "\n", "\\r\\n")
    let $str := fn:replace( $str, "\t", "\\t")
    let $str := fn:replace( $str, "’", "'")
    let $str := fn:replace( $str, '“|”', '\\"')
    (: 
        Commented out the below because it was impeding the proper presentation of
        this particular character. This line was part of the initial commit but 
        feels at this moment in time that it was one string cleaning rule 
        too far.
    :)
    (: let $str := fn:replace( $str, 'ā', '\\u0101') :)
    return $str
};



