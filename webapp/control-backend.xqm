module namespace control-backend = 'http://transpect.io/control-backend';

declare namespace control = 'http://transpect.io/control';

(:declare
  %rest:POST("{$doc}")
  %rest:path("/control-backend/ftindex/jats")
  %rest:query-param("path-to-repo", "{$path-to-repo}", "normal")
  %rest:query-param("path-in-repo", "{$path-in-repo}", "normal")
  %updating
  %output:method("xml")
function control-backend:ftindex-jats($doc as document-node(element(*))) 
   {
    update:output(
  (<rest:response>
    <http:response status="200">
      <http:header name="Content-Language" value="en"/>
      <http:header name="Access-Control-Allow-Origin" value="*"/>
      <http:header name="Content-Type" value="text/xml; charset=utf-8"/>
     </http:response>
  </rest:response>,
  <success/>)
  ),
    try {
      insert node $doc/* as last into db:open('CHPD_override_RDF')/*
    } catch * {
    }
};:)

declare
  %rest:POST("{$log}")
  %rest:path("/control-backend/{$customization}/parse-commit-log")
  %output:method("xml")
function control-backend:parse-commit-log($log as xs:string, $customization as xs:string) as element(commit) {
  let $lines as xs:string+ := tokenize($log, '[&#xa;&#xd;]+'),
      $repo-info as xs:string+ := $lines[1] => tokenize(),
      $repo-path as xs:string := $repo-info[1],
      $revision as xs:string := $repo-info[2]
  return <commit repo-path="{$repo-path}" revision="{$revision}"> {
    for $line in $lines[position() gt 1]
    let $items := $line => tokenize(),
        $action as xs:string? := switch($items[1])
                                 case 'U' return 'update'
                                 case 'D' return 'delete'
                                 default return ()
    return (
      if ($action) then element{$action}{
        attribute path {$items[2]}
      } else ()
    )
  }</commit>
};

declare
  %rest:POST("{$log}")
  %rest:path("/control-backend/{$customization}/process-commit-log")
  %output:method("xml")
  %updating
function control-backend:process-commit-log($log as xs:string, $customization as xs:string) {
  update:output(<success/>),
  let $parsed-log := control-backend:parse-commit-log($log, $customization)
  return
    for $pattern in doc('../control/config.xml')/control:config/control:ftindexes/control:file/@pattern
    return
      for $action in $parsed-log/*[matches(@path, $pattern)]
      return (
      switch($action/local-name())
        case 'update'
          return
          for $temp-path in control-backend:get-commit-file($action/../@repo-path, $action/@path, $action/../@revision, $customization)
          return (
            control-backend:add-xml-by-path($temp-path, $action/@path, $customization)(:,
            file:delete(file:parent($temp-path), true()):)
          )
        case 'delete'
          return control-backend:remove-xml-by-path($action/@path, $customization)
        default return ()
      )
};

declare function control-backend:get-commit-file($path-to-repo, $path-in-repo, $revision, $customization) as xs:string {
  (: returns the path to the file that has been saved using svnlook cat :)
  let $local-dir := '/tmp/transpect-control/commits' || $path-to-repo || replace($path-in-repo, '[^/]+$', '')
  return (
    file:create-dir($local-dir),
    proc:system(file:resolve-path('basex/webapp/control-backend/scripts/svnlook-cat.sh'), ($path-to-repo, $path-in-repo, $revision, $local-dir))
  )
};

declare 
%updating
function control-backend:remove-xml-by-path($path, $customization) {
  let $dbname := string(doc('../control/config.xml')/control:config/control:db)
  return 
    for $doc in db:open($dbname, $path)
    let $lang := control-backend:determine-lang($doc)
    return (
      db:delete(doc('../control/config.xml')/control:config/control:ftindexes/control:ftindex[@lang = ($lang, 'en')[1]], $path),
      db:delete($dbname, $path)
    )
};

declare
  %rest:GET
  %rest:path("/control-backend/{$customization}/add-xml-by-path")
  %rest:query-param("fspath", "{$fspath}")
  %rest:query-param("dbpath", "{$dbpath}", '')
  %output:method("xml")
  %updating
function control-backend:add-xml-by-path($fspath as xs:string, $dbpath as xs:string, $customization as xs:string) {
  let $doc := doc($fspath),
      $lang as xs:string := control-backend:determine-lang($doc),
      $ftdb as xs:string := string(doc('../control/config.xml')/control:config/control:ftindexes/control:ftindex[@lang = ($lang, 'en')[1]]),
      $db as xs:string := string(doc('../control/config.xml')/control:config/control:db),
      $dbpath-or-fallback := if (not($dbpath)) then $fspath else $dbpath 
  return 
  (
    if (not(db:exists($ftdb)))
    then db:create($ftdb, control-backend:apply-ft-xslt($doc), $dbpath-or-fallback, 
                   map{'language': $lang, 'ftindex': true(), 'diacritics': true()}) 
    else db:replace($ftdb, $dbpath-or-fallback, control-backend:apply-ft-xslt($doc)),
    if (not(db:exists($db))) 
    then db:create($db, $doc, $dbpath-or-fallback, map{'updindex': true()}) 
    else db:replace($db, $dbpath-or-fallback, $doc)
  )
};

declare
  %rest:GET
  %rest:path("/control-backend/{$customization}/add-xml-by-svn-info")
  %rest:query-param("svn-info-filename", "{$svn-info-filename}")
  %output:method("xml")
  %updating
function control-backend:add-xml-by-svn-info($svn-info-filename as xs:string, $customization as xs:string) {
  (: the fulltext and content dbs must exist before invoking this :)
  update:output(<success/>),
  let $svn-info := doc($svn-info-filename),
      $dir := file:parent($svn-info-filename)
  return
    for $entry in $svn-info/svn-info/info/entry
    let $fs-relpath := $entry/@path,
        $resolved-fs-path := file:resolve-path($fs-relpath, $dir),
        $repo-url := $entry/repository/root,
        $repo-lastpath := ($repo-url => tokenize('/'))[last()],
        $path-in-repo :=$entry/relative-url => replace('^\^', '')
    return control-backend:add-xml-by-path($resolved-fs-path, $repo-lastpath || $path-in-repo, $customization)
    (:<doc>{
      attribute fspath {$resolved-fs-path},
      attribute dbpath {$repo-lastpath || $path-in-repo}
    }</doc>:)
};

declare function control-backend:apply-ft-xslt($doc as document-node(element(*))) {
  let $ns-uri := namespace-uri-from-QName(node-name($doc/*)),
      $name := local-name($doc/*),
      $stylesheet as xs:string? := switch($ns-uri)
                                     case '' return 
                                       switch($name)
                                         case 'article'
                                         case 'book'
                                           return 'fulltext/vocabularies/bits/bits2ft.xsl'
                                         default return ()
                                     default return ()
     return if ($stylesheet) then xslt:transform($doc, $stylesheet) else $doc
};

declare function control-backend:determine-lang($doc as document-node(element(*))) as xs:string {
  $doc/*/@xml:lang
};
