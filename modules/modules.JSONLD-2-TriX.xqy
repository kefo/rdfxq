import module namespace x = "http://zorba.io/modules/xml";
import schema namespace opt = "http://zorba.io/modules/xml-options";
 
declare namespace as = "http://www.w3.org/2005/xpath-functions";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:indent "yes";

(:
See here for example JSON LD files:
https://github.com/ruby-rdf/json-ld/tree/develop/example-files

Another example here: http://wiki.teria.no/display/inloc/JSON-LD
And here: http://robtweed.wordpress.com/2013/11/20/creating-json-ld-documents-from-within-mumps/

:)

declare function local:parseList($list)
{
  
    for $l in $list/child::node()
    return
        typeswitch($l)
            case text() return
                let $vstr := fn:analyze-string(xs:string($l), '"([ ]*),([ ]*)"')
                return
                    if ( fn:normalize-space($l) eq ""  or fn:normalize-space($l) eq ",") then
                        ()
                    else if ($vstr/as:match) then
                        for $nm in $vstr/as:non-match
                        let $lvalue := fn:replace( $nm, '^([ ]*)"', '')
                        let $lvalue := fn:replace($lvalue, '"([ ]*)$', '')
                        return
                            element item {
                                attribute type {"string"},
                                $lvalue
                            }
                    else
                        let $lvalue := fn:replace(xs:string($l), '^([ ]*)"', '')
                        let $lvalue := fn:replace($lvalue, '"([ ]*)$', '')
                        return
                            element item {
                                attribute type {"string"},
                                $lvalue
                            }
            case element(object) return
                element item {
                    attribute type {"object"},
                    for $lnext in $l/text()
                    return local:parseObject($lnext)
                }
            default return ()  
};

declare function local:parseObject($object) 
{
    for $o in $object
    return 
        typeswitch ($o)
            case text() return
                let $vstr := fn:analyze-string(xs:string($o), '([ ]*),([ ]*)"')
                return
                    if ( fn:normalize-space($o) eq "" or fn:normalize-space($o) eq ",") then
                        ()
                    else if ($vstr/as:match) then
                        for $nm in $vstr/as:non-match
                        let $pairs := fn:analyze-string(xs:string($nm), '([ ]*):([ ]*)"')
                        return 
                            if ( fn:count($pairs/as:non-match) > 1 ) then
                                (: We have a pair :)
                                let $pname := fn:replace( $pairs/as:non-match[1], '^([, ]*)"', '')
                                let $pname := fn:replace( $pname, '"$', '')
                                let $pvalue := fn:replace( $pairs/as:non-match[2], '"([ ]*)$', '')
                                let $pvalue := fn:replace( $pvalue, '^"', '')
                                return
                                    element pair {
                                        attribute name { $pname },
                                        attribute type {"string"},
                                        $pvalue
                                    }
                            else if ( fn:count($pairs/as:non-match) eq 1 ) then
                                let $pname := fn:replace( $pairs/as:non-match[1], '"([ ]*):([ ]*)$', '')
                                let $pname := fn:replace( $pname, '"$', '')
                                let $pname := fn:replace( $pname, '^"', '')
                                return 
                                    if ($pname ne "") then
                                        element pair {
                                            attribute name {$pname},
                                            if ($o/following-sibling::object[1]) then
                                                attribute type {"object"}
                                            else
                                                attribute type {"array"},
                                            for $onext in ($o/following-sibling::object[1]|$o/following-sibling::list[1])[1]
                                            return local:parseObject($onext)
                                        }
                                    else
                                        ()
                            else
                                ()
                                (:
                                for $onext in $o/following-sibling::node()
                                return local:parseObject($onext)
                                :)
                    else
                        let $pairs := fn:analyze-string(xs:string($o), '"([ ]*):([ ]*)"')
                        return
                            if ( fn:count($pairs/as:non-match) eq 2 ) then
                                (: We have a pair :)
                                let $pname := fn:replace( $pairs/as:non-match[1], '^([, ]*)"', '')
                                let $pvalue := fn:replace( $pairs/as:non-match[2], '"([ ]*)$', '')
                                return
                                    element pair {
                                        attribute name { $pname },
                                        attribute type {"string"},
                                        $pvalue
                                    }
                            else 
                                let $ostr := fn:analyze-string(xs:string($o), '([ ]*)"([@a-zA-Z0-9]+)"([ ]*):')
                                return 
                                    if (xs:string($ostr/as:match[1]/as:group[2]) ne "") then
                                        element pair {
                                            attribute name { xs:string($ostr/as:match[1]/as:group[2]) },
                                            attribute type {"object"},
                                            for $onext in $o/following-sibling::object
                                            return local:parseObject($onext)
                                        }
                                    else
                                        ()
                                
            case element(list) return local:parseList($o)

            case element(object) return
                for $onext in $o/text()
                return local:parseObject($onext)
                    (:
                    element object {
                        local:parseObject($onext)
                    }
                    :)
            default return ()
    
};

let $json := '{
  "@context": {
    "generatedAt": {
      "@id": "http://www.w3.org/ns/prov#generatedAtTime",
      "@type": "http://www.w3.org/2001/XMLSchema#date"
    },
    "Person": "http://xmlns.com/foaf/0.1/Person",
    "name": "http://xmlns.com/foaf/0.1/name",
    "knows": "http://xmlns.com/foaf/0.1/knows",
    "homepage":
        [
            "http://personal.example.org/",
            "http://work.example.com/jsmith/"
        ]
  },
  "@id": "http://example.org/graphs/73",
  "generatedAt": "2012-04-09",
  "@graph":
  [
    {
      "@id": "http://manu.sporny.org/about#manu",
      "@type": "Person",
      "name": "Manu Sporny",
      "knows": "http://greggkellogg.net/foaf#me"
    },
    {
      "@id": "http://greggkellogg.net/foaf#me",
      "@type": "Person",
      "name": "Gregg Kellogg",
      "knows": "http://manu.sporny.org/about#manu"
    }
  ]
}'

(:
let $json := '
{
  "@context":
  {
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "foaf": "http://xmlns.com/foaf/0.1/",
    "foaf:homepage": { "@type": "@id" },
    "picture": { "@id": "foaf:depiction", "@type": "@id" }
  },
  "@id": "http://me.markus-lanthaler.com/",
  "@type": "foaf:Person",
  "foaf:name": "Markus Lanthaler",
  "foaf:homepage": "http://www.markus-lanthaler.com/",
  "picture": "http://twitter.com/account/profile_image/markuslanthaler"
}
'
:)

let $json := '
   {
     "firstName" : "John",
     "lastName" : "Smith",
     "address" : {
       "streetAddress" : "21 2nd Street",
       "city" : "New York",
       "state" : "NY",
       "postalCode" : 10021
     },
     "phoneNumbers" : [ "212 732-1234", "646 123-4567" ]
   }
   '
   
let $json := '
{
  "@context":
  {
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "name": "http://xmlns.com/foaf/0.1/name",
    "age":
    {
      "@id": "http://xmlns.com/foaf/0.1/age",
      "@type": "xsd:integer"
    },
    "homepage":
    {
      "@id": "http://xmlns.com/foaf/0.1/homepage",
      "@type": "@id"
    }
  },
  "@id": "http://example.com/people#john",
  "name": "John Smith",
  "age": "41",
  "homepage":
  [
    "http://personal.example.org/",
    "http://work.example.com/jsmith/"
  ]
}
'

let $json := 
'{
  "@context": "http://schema.org",
  "@type": "Person",
  "name": "John Doe",
  "jobTitle": "Graduate research assistant",
  "affiliation": "University of Dreams",
  "additionalName": "Johnny",
  "url": "http://www.example.com",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "1234 Peach Drive",
    "addressLocality": "Wonderland",
    "addressRegion": "Georgia"
  }
}
'

let $json := 
'
{
  "@context": {
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "mf": "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
    "mq": "http://www.w3.org/2001/sw/DataAccess/tests/test-query#",
    
    "comment": "rdfs:comment",
    "entries": {"@id": "mf:entries", "@container": "@list"},
    "name": "mf:name",
    "action": "mf:action",
    "data": {"@id": "mq:data", "@type": "@id"},
    "query": {"@id": "mq:query", "@type": "@id"},
    "result": {"@id": "mf:result", "@type": "xsd:boolean"}
  },
  "@type": "mf:Manifest",
  "entries": [{
    "@type": "mf:ManifestEntry"
  }]
}
'

let $json := '
{
              "@id": "schema:QualitativeValue",
              "@type": "rdfs:Class",
              "description": "A predefined value for a product characteristic, e.g. the the power cord plug type \"US\" or the garment sizes \"S\", \"M\", \"L\", and \"XL\"",
              "http://purl.org/dc/terms/source": {
                "@id": "http://www.w3.org/wiki/WebSchemas/SchemaDotOrgSources#source_GoodRelationsClass"
              },
              "name": "QualitativeValue",
              "rdfs:subClassOf": "schema:Enumeration"
            }
            '
            
let $json := '
   {
     "firstName" : "John",
     "lastName" : "Smith",
     "address" : {
       "streetAddress" : "21 2nd Street",
       "city" : "New York",
       "state" : "NY",
       "postalCode" : 10021
     },
     "phoneNumbers" : [ "212 732-1234", "646 123-4567" ]
   }
   '

let $json := '
[
  {
    "@id": "http://me.markus-lanthaler.com/",
    "http://xmlns.com/foaf/0.1/name": [
      { "@value": "Markus Lanthaler" }
    ],
    "http://xmlns.com/foaf/0.1/homepage": [
      { "@id": "http://www.markus-lanthaler.com/" }
    ]
  }
]
'

let $json := fn:replace($json, "\n", "")
let $curlies := 
    for $c in fn:analyze-string($json, "[ ]*\{[ ]*|[ ]*\}[ ]*")/*
    return
        typeswitch ($c)
            case element(as:non-match) return 
                let $pnm := fn:normalize-space(xs:string($c))
                return 
                    if ( fn:ends-with($pnm, '\') and fn:name($c/following-sibling::as:*[1]) eq "as:match") then
                        fn:concat( xs:string($c), $c/following-sibling::as:*[1] )
                    else
                        xs:string($c)
            case element(as:match) return
                let $pnm := fn:normalize-space($c/preceding-sibling::as:*[1])
                return 
                    if ( fn:ends-with($pnm, '\')) then
                        ""
                    else
                        if (fn:normalize-space($c) eq "{") then
                            '<object>'
                        else
                            '</object>'
            default return ""

let $json := fn:string-join($curlies, "")

let $lists := 
    for $c in fn:analyze-string($json, "[ ]*\[[ ]*|[ ]*\][ ]*")/*
    return
        typeswitch ($c)
            case element(as:non-match) return 
                let $pnm := fn:normalize-space(xs:string($c))
                return 
                    if ( fn:ends-with($pnm, '\') and fn:name($c/following-sibling::as:*[1]) eq "as:match") then
                        fn:concat( xs:string($c), $c/following-sibling::as:*[1] )
                    else
                        xs:string($c)
            case element(as:match) return
                let $pnm := fn:normalize-space($c/preceding-sibling::as:*[1])
                return 
                    if ( fn:ends-with($pnm, '\')) then
                        ""
                    else
                        if (fn:normalize-space($c) eq "[") then
                            '<list>'
                        else
                            '</list>'
            default return ""

let $json := fn:string-join($lists, "")
let $jsonxml := x:parse(
   $json,
   <opt:options>
     <opt:parse-external-parsed-entity/>
   </opt:options>
 )

let $jsonxml := 
    element json { 
        if (fn:name($jsonxml) eq "object") then
            attribute type {"object"}
        else
            attribute type {"array"},
        local:parseObject($jsonxml)
    }
    (:
    for $o in $jsonxml
        return local:parseObject($o)
    }
    :)

return $jsonxml
