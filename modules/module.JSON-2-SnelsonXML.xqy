xquery version "1.0";

(:
 : Copyright (c) 2010-2011
 :     John Snelson. All rights reserved.
 :
 : Licensed under the Apache License, Version 2.0 (the "License");
 : you may not use this file except in compliance with the License.
 : You may obtain a copy of the License at
 :
 :     http://www.apache.org/licenses/LICENSE-2.0
 :
 : Unless required by applicable law or agreed to in writing, software%private 
 : distributed under the License is distributed on an "AS IS" BASIS,
 : WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 : See the License for the specific language governing permissions and
 : limitations under the License.
 :)

(: 
    The bulk of this code adheres to the above.
    I've down graded it to Xquery 1.0 from 3.0 so
    that it will run on all most XQuery parsers.
    
    File from: http://xqilla.hg.sourceforge.net/hgweb/xqilla/xqilla/raw-file/6458513c94c0/src/functions/XQillaModule.xq
    See also, http://xqilla.hg.sourceforge.net/hgweb/xqilla/xqilla/diff/d845bac30681/src/functions/XQillaModule.xq

:)


module namespace xqilla="http://xqilla.sourceforge.net/Functions";

(:----------------------------------------------------------------------------------------------------:)
(: JSON parsing :)

declare function xqilla:parse-json($json as xs:string)
  as element()?
{
  let $res := xqilla:parseValue(xqilla:tokenize($json))
  return
    if(fn:exists(fn:remove($res,1))) then xqilla:parseError($res[2])
    else element json {
      $res[1]/@*,
      $res[1]/node()
    }
};

declare function xqilla:parseValue($tokens as element(token)*)
{
  let $token := $tokens[1]
  let $tokens := fn:remove($tokens,1)
  return
    if($token/@t = "lbrace") then (
      let $res := xqilla:parseObject($tokens)
      let $tokens := fn:remove($res,1)
      return (
        element res {
          attribute type { "object" },
          $res[1]/node()
        },
        $tokens
      )
    ) else if ($token/@t = "lsquare") then (
      let $res := xqilla:parseArray($tokens)
      let $tokens := fn:remove($res,1)
      return (
        element res {
          attribute type { "array" },
          $res[1]/node()
        },
        $tokens
      )
    ) else if ($token/@t = "number") then (
      element res {
        attribute type { "number" },
        text { $token }
      },
      $tokens
    ) else if ($token/@t = "string") then (
      element res {
        attribute type { "string" },
        text { xqilla:unescape-json-string($token) }
      },
      $tokens
    ) else if ($token/@t = "true" or $token/@t = "false") then (
      element res {
        attribute type { "boolean" },
        text { $token }
      },
      $tokens
    ) else if ($token/@t = "null") then (
      element res {
        attribute type { "null" }
      },
      $tokens
    ) else xqilla:parseError($token)
};

declare function xqilla:parseObject($tokens as element(token)*)
{
  let $token1 := $tokens[1]
  let $tokens := fn:remove($tokens,1)
  return
    if(fn:not($token1/@t = "string")) then xqilla:parseError($token1) else
      let $token2 := $tokens[1]
      let $tokens := fn:remove($tokens,1)
      return
        if(fn:not($token2/@t = "colon")) then xqilla:parseError($token2) else
          let $res := xqilla:parseValue($tokens)
          let $tokens := fn:remove($res,1)
          let $pair := element pair {
            attribute name { $token1 },
            $res[1]/@*,
            $res[1]/node()
          }
          let $token := $tokens[1]
          let $tokens := fn:remove($tokens,1)
          return
            if($token/@t = "comma") then (
              let $res := xqilla:parseObject($tokens)
              let $tokens := fn:remove($res,1)
              return (
                element res {
                  $pair,
                  $res[1]/node()
                },
                $tokens
              )
            ) else if($token/@t = "rbrace") then (
              element res {
                $pair
              },
              $tokens
            ) else xqilla:parseError($token)
};

declare function xqilla:parseArray($tokens as element(token)*)
{
  let $res := xqilla:parseValue($tokens)
  let $tokens := fn:remove($res,1)
  let $item := element item {
    $res[1]/@*,
    $res[1]/node()
  }
  let $token := $tokens[1]
  let $tokens := fn:remove($tokens,1)
  return
    if($token/@t = "comma") then (
      let $res := xqilla:parseArray($tokens)
      let $tokens := fn:remove($res,1)
      return (
        element res {
          $item,
          $res[1]/node()
        },
        $tokens
      )
    ) else if($token/@t = "rsquare") then (
      element res {
        $item
      },
      $tokens
    ) else xqilla:parseError($token)
};

declare function xqilla:parseError($token as element(token))
  as empty-sequence()
{
  fn:error(xs:QName("xqilla:PARSEJSON01"),
    fn:concat("Unexpected token: ", fn:string($token/@t), " (""", fn:string($token), """)"))
};

declare function xqilla:tokenize($json as xs:string)
  as element(token)*
{
  let $tokens := ("\{", "\}", "\[", "\]", ":", ",", "true", "false", "null", "\s+",
    '"([^"\\]|\\"|\\\\|\\/|\\b|\\f|\\n|\\r|\\t|\\u[A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9])*"',
    "-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?")
  let $regex := fn:string-join(for $t in $tokens return fn:concat("(",$t,")"),"|")
  for $match in fn:analyze-string($json, $regex)/*
  return
    if($match/self::*:non-match) then xqilla:token("error", fn:string($match))
    else if($match/*:group/@nr = 1) then xqilla:token("lbrace", fn:string($match))
    else if($match/*:group/@nr = 2) then xqilla:token("rbrace", fn:string($match))
    else if($match/*:group/@nr = 3) then xqilla:token("lsquare", fn:string($match))
    else if($match/*:group/@nr = 4) then xqilla:token("rsquare", fn:string($match))
    else if($match/*:group/@nr = 5) then xqilla:token("colon", fn:string($match))
    else if($match/*:group/@nr = 6) then xqilla:token("comma", fn:string($match))
    else if($match/*:group/@nr = 7) then xqilla:token("true", fn:string($match))
    else if($match/*:group/@nr = 8) then xqilla:token("false", fn:string($match))
    else if($match/*:group/@nr = 9) then xqilla:token("null", fn:string($match))
    else if($match/*:group/@nr = 10) then () (:ignore whitespace:)
    else if($match/*:group/@nr = 11) then
      let $v := fn:string($match)
      let $len := fn:string-length($v)
      return xqilla:token("string", fn:substring($v, 2, $len - 2))
    else if($match/*:group/@nr = 13) then xqilla:token("number", fn:string($match))
    else xqilla:token("error", fn:string($match))
};

declare function xqilla:token($t, $value)
{
  <token t="{$t}">{ fn:string($value) }</token>
};

(:----------------------------------------------------------------------------------------------------:)
(: JSON serializing :)

declare function xqilla:serialize-json($json-xml as element()?)
  as xs:string?
{
  if(fn:empty($json-xml)) then () else

  fn:string-join(
    xqilla:serializeJSONElement($json-xml)
  ,"")
};

declare function xqilla:serializeJSONElement($e as element())
  as xs:string*
{
  if($e/@type = "object") then xqilla:serializeJSONObject($e)
  else if($e/@type = "array") then xqilla:serializeJSONArray($e)
  else if($e/@type = "null") then "null"
  else if($e/@type = "boolean") then fn:string($e)
  else if($e/@type = "number") then fn:string($e)
  else ('"', xqilla:escape-json-string($e), '"')
};

declare function xqilla:serializeJSONObject($e as element())
  as xs:string*
{
  "{",
  $e/*/(
    if(fn:position() = 1) then () else ",",
    '"', xqilla:escape-json-string(@name), '":',
    xqilla:serializeJSONElement(.)
  ),
  "}"
};

declare function xqilla:serializeJSONArray($e as element())
  as xs:string*
{
  "[",
  $e/*/(
    if(fn:position() = 1) then () else ",",
    xqilla:serializeJSONElement(.)
  ),
  "]"
};

(:----------------------------------------------------------------------------------------------------:)
(: JSON unescaping :)

declare function xqilla:unescape-json-string($val as xs:string)
  as xs:string
{
  fn:string-join(
    let $regex := '[^\\]+|(\\")|(\\\\)|(\\/)|(\\b)|(\\f)|(\\n)|(\\r)|(\\t)|(\\u[A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9])'
    for $match in fn:analyze-string($val, $regex)/*
    return
      if($match/*:group/@nr = 1) then """"
      else if($match/*:group/@nr = 2) then "\"
      else if($match/*:group/@nr = 3) then "/"
      (: else if($match/*:group/@nr = 4) then "&#x08;" :)
      (: else if($match/*:group/@nr = 5) then "&#x0C;" :)
      else if($match/*:group/@nr = 6) then "&#x0A;"
      else if($match/*:group/@nr = 7) then "&#x0D;"
      else if($match/*:group/@nr = 8) then "&#x09;"
      else if($match/*:group/@nr = 9) then
        fn:codepoints-to-string(xqilla:decode-hex-string(fn:substring($match, 3)))
      else fn:string($match)
  ,"")
};

declare function xqilla:escape-json-string($val as xs:string)
  as xs:string
{
  fn:string-join(
    let $regex := '(")|(\\)|(/)|(&#x0A;)|(&#x0D;)|(&#x09;)|[^"\\/&#x0A;&#x0D;&#x09;]+'
    for $match in fn:analyze-string($val, $regex)/*
    return
      if($match/*:group/@nr = 1) then "\"""
      else if($match/*:group/@nr = 2) then "\\"
      else if($match/*:group/@nr = 3) then "\/"
      else if($match/*:group/@nr = 4) then "\n"
      else if($match/*:group/@nr = 5) then "\r"
      else if($match/*:group/@nr = 6) then "\t"
      else fn:string($match)
  ,"")
};
declare function xqilla:decode-hex-string($val as xs:string)
  as xs:integer
{
  xqilla:decodeHexStringHelper(fn:string-to-codepoints($val), 0)
};

declare function xqilla:decodeHexChar($val as xs:integer)
  as xs:integer
{
  let $tmp := $val - 48 (: '0' :)
  let $tmp := if($tmp <= 9) then $tmp else $tmp - (65-48) (: 'A'-'0' :)
  let $tmp := if($tmp <= 15) then $tmp else $tmp - (97-65) (: 'a'-'A' :)
  return $tmp
};

declare function xqilla:decodeHexStringHelper($chars as xs:integer*, $acc as xs:integer)
  as xs:integer
{
  if(fn:empty($chars)) then $acc
  else xqilla:decodeHexStringHelper(fn:remove($chars,1), ($acc * 16) + xqilla:decodeHexChar($chars[1]))
};
