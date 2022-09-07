<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="xs saxon html" version="3.0">

  <xsl:mode name="render-work-matches" on-no-match="text-only-copy"/>
  <xsl:mode name="render-override-matches" on-no-match="text-only-copy"/>
  <xsl:mode name="augment-xpath-links" on-no-match="shallow-copy"/>

  <xsl:param name="term" as="xs:string" select="''"/>
  <xsl:param name="overrides-term" as="xs:string" select="''"/>
  <xsl:param name="xpath" as="xs:string" select="''"/>
  <xsl:param name="types" as="xs:string" select="''"/>
  <xsl:param name="langs" as="xs:string" select="'de,en'"/>
  <xsl:param name="svnbaseurl" as="xs:string" select="'http://localhost/svn'"/>
  <xsl:param name="siteurl" as="xs:string" select="'http://localhost/control'"/>
  <xsl:param name="group" select="'hierarchy'"/>
  <xsl:param name="work-id-position" as="xs:integer" select="3">
    <!-- the path component position, measured from the XML file name, which is 1.
      Example: in imprint/series/workid/xml/file.xml, workid is 3rd to last --> 
  </xsl:param>
  <xsl:param name="show-details" as="xs:boolean" select="true()"/>
  <xsl:param name="customization" as="xs:string" select="'default'"/>

  <xsl:template match="search-results">
    <div class="search-results">
      <xsl:choose>
        <xsl:when test="$group = 'hierarchy'">
          <details open="true">
            <summary>
              <xsl:text expand-text="yes">Total: {@count}</xsl:text>
            </summary>
            <xsl:call-template name="by-hierarchy">
              <xsl:with-param name="results" select="result"/>
            </xsl:call-template>  
          </details>
        </xsl:when>
      </xsl:choose>  
    </div>
  </xsl:template>

  <xsl:template name="by-hierarchy">
    <xsl:param name="hierarchy-component" as="xs:integer" select="1"/>
    <xsl:param name="results" as="element(result)*"/>
    <xsl:param name="open" as="xs:boolean" select="false()">
      <!-- will be set to true() when processing the path components that contain the work IDs -->
    </xsl:param>
    <!-- assumption: @virtual-path starts with a slash and its two (for $work-id-position=3)
         last components (example: xml/file.xml) are not used for grouping  -->
    <xsl:for-each-group select="$results" 
      group-by="tokenize(@virtual-path, '/')[normalize-space()][$hierarchy-component]">
      <xsl:sort select="current-grouping-key()"/>
      <xsl:variable name="is-overrides-group" select="exists(@type)" as="xs:boolean"/>
      <xsl:variable name="terminals" as="element(result)*"
        select="current-group()/self::result[@virtual-steps + 1 - $work-id-position = $hierarchy-component]"/>
      <xsl:variable name="show-overrides" as="xs:boolean" 
        select="$is-overrides-group and $hierarchy-component = $work-id-position"/>
      <xsl:variable name="context" as="element(result)" select="."/>
      <xsl:variable name="summary-link" as="element(html:a)">
        <a href="{$siteurl}?svnurl={
                  if ($hierarchy-component gt @virtual-steps - $work-id-position)
                  then string-join(
                         tokenize(@svnurl, '/')[position() le min((
                                                    last() - $context/@virtual-steps + $hierarchy-component,
                                                    last() -1
                                               ))],
                         '/'
                       )
                  else $svnbaseurl || 
                         string-join(
                         tokenize(@virtual-path, '/')[position() le last() - $context/@virtual-steps + $hierarchy-component],
                         '/'
                       )}&amp;restrict_path=true&amp;term={$term}&amp;overrides-term={$overrides-term}&amp;xpath={$xpath}{
                         string-join(for $lang in tokenize($langs, ',') return '&amp;lang=' || $lang)
                       }{
                         string-join(for $type in tokenize($types, ',') return '&amp;type=' || $type)
                       }"
           target="_blank">
          <xsl:value-of select="current-grouping-key()"/>
          <xsl:if test="exists($terminals)">
            <xsl:text xml:space="preserve"> </xsl:text>
            <xsl:value-of select="$terminals[1]/breadcrumbs/title[1]"/>
          </xsl:if>
        </a>
      </xsl:variable>
      <details>
        <xsl:if test="$open or count(current-group()) = 1">
          <xsl:attribute name="open" select="'true'"/>
        </xsl:if>
        <summary>
          <xsl:sequence select="$summary-link"/>
          <xsl:text xml:space="preserve"> (</xsl:text>
          <xsl:value-of select="count(current-group())"/>
          <xsl:text>)</xsl:text>
          <xsl:value-of select="count(current-group())"/>
          <xsl:call-template name="types"/>
        </summary>
        <xsl:choose>
          <xsl:when test="$show-overrides">
            <ul>
              <xsl:apply-templates select="current-group()" mode="render-override-matches"/>
            </ul>
          </xsl:when>
          <xsl:otherwise>
            <xsl:if test="$open">
              <xsl:for-each-group select="current-group()" group-by="(@breadcrumbs-signature, @path)[1]">
                <xsl:choose>
                  <xsl:when test="exists(current-group()/context)">
                    <details open="true" class="work-matches">
                      <summary>
                        <xsl:apply-templates select="breadcrumbs" mode="render-work-matches"/>
                      </summary>
                      <ul>
                        <xsl:apply-templates select="current-group()/context" mode="render-work-matches"/>
                      </ul>
                    </details>
                  </xsl:when>
                  <xsl:when test="empty(current-group()/breadcrumbs)">
                    <!-- XPath-only results -->
                    <ul>
                      <xsl:apply-templates select="current-group()" mode="render-work-matches"/>
                    </ul>
                  </xsl:when>
                  <xsl:otherwise>
                    <p class="search-breadcrumbs">
                      <xsl:apply-templates select="breadcrumbs" mode="render-work-matches"/>
                    </p>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:for-each-group>
            </xsl:if>
            <xsl:variable name="overrides-in-hierarchy" as="element(result)*"
              select="if ($is-overrides-group)
                      then current-group()[@virtual-steps + 1 - $work-id-position = $hierarchy-component]
                      else ()">
              <!-- only override-params.xml -->
            </xsl:variable>
            <xsl:if test="exists($overrides-in-hierarchy)">
              <ul>
                <xsl:apply-templates select="$overrides-in-hierarchy" mode="render-override-matches">
                  <xsl:with-param name="display-path-steps" select="1" as="xs:integer" tunnel="yes"/>
                </xsl:apply-templates>
              </ul>  
            </xsl:if>
            <xsl:if test="exists($terminals)">
              <xsl:call-template name="by-hierarchy">
                <xsl:with-param name="hierarchy-component" select="@virtual-steps" as="xs:integer"/>
                <xsl:with-param name="results" select="$terminals" as="element(result)+"/>
                <xsl:with-param name="open" as="xs:boolean" select="true()"/>
              </xsl:call-template>
            </xsl:if>
            <xsl:if test="exists(current-group() except $terminals)">
              <xsl:call-template name="by-hierarchy">
                <xsl:with-param name="hierarchy-component" select="$hierarchy-component + 1" as="xs:integer"/>
                <xsl:with-param name="results" select="current-group() except $terminals" as="element(result)+"/>
              </xsl:call-template>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </details>
    </xsl:for-each-group>
  </xsl:template>

  <xsl:template name="types">
    <xsl:param name="nodes" select="current-group()"/>
    <xsl:variable name="types" as="xs:string*" select="$nodes/@type"/>
    <xsl:for-each select="distinct-values($types)">
      <xsl:text xml:space="preserve"> </xsl:text>
      <span class="filetype {.}">
        <xsl:value-of select="."/>
      </span>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="result" mode="render-work-matches">
    <p class="search-breadcrumbs">
      <xsl:apply-templates select="breadcrumbs/title[position() gt 1]" mode="#current"/>
    </p>
    <xsl:apply-templates select="context" mode="#current"/>
  </xsl:template>
  
  <xsl:template match="result[empty(context)][empty(breadcrumbs)]" mode="render-work-matches">
    <li>
      <xsl:apply-templates select="@path" mode="#current"/>
    </li>
  </xsl:template>
  
  <xsl:template match="result" mode="render-override-matches">
    <li>
      <xsl:apply-templates select="@dbpath" mode="#current"/>
    </li>
  </xsl:template>

  <xsl:template match="context" mode="render-work-matches">
    <li>
      <xsl:apply-templates select="../@path" mode="#current"/>
      <p class="search-context">
        <xsl:apply-templates mode="#current"/>
      </p>
    </li>
  </xsl:template>
  
  <xsl:template match="@path" mode="render-work-matches">
    <xsl:variable name="dbpath" as="xs:string" select="../@dbpath"/>
    <xsl:variable name="prelim" as="document-node()">
      <xsl:document>
        <xsl:analyze-string select="." regex="/">
          <xsl:matching-substring>
            <xsl:value-of select="."/>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <a href="{$siteurl}/{$customization}/render-xml-source?svn-url={$dbpath}&amp;xpath=">
              <xsl:value-of select="."/>
            </a>
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </xsl:document>
    </xsl:variable>
    <p class="search-xpath">
      <input type="button" value="Copy"/>
      <xsl:apply-templates select="$prelim" mode="augment-xpath-links"/>
    </p>
  </xsl:template>
  
  <xsl:template match="@dbpath" mode="render-override-matches">
    <xsl:param name="display-path-steps" select="2" as="xs:integer" tunnel="yes"/>
    <xsl:variable name="dbpath" as="xs:string" select="."/>
    <p class="override">
      <a target="xmlsrc" href="{$siteurl}/{$customization}/render-xml-source?svn-url={$dbpath}&amp;xpath=/*{
        if (../@type = 'css') then '&amp;text=true&amp;indent=false' else ''}">
        <xsl:value-of select="string-join(tokenize(., '/')[position() gt last() - $display-path-steps], '/')"/>
      </a>
    </p>
  </xsl:template>
  
  <xsl:template match="html:a/@href" mode="augment-xpath-links">
    <xsl:attribute name="href" select="string-join((., ../preceding-sibling::node(), ..))"/>
    <xsl:attribute name="target" select="'xmlsrc'"/>
  </xsl:template>

  <xsl:template match="breadcrumbs/title" mode="render-work-matches">
    <span class="search-breadcrumb">
      <xsl:apply-templates mode="#current"/>
    </span>
    <xsl:if test="not(position() = last())">
      <xsl:text xml:space="preserve"> > </xsl:text>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="mark" mode="render-work-matches">
    <span class="search-mark">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
</xsl:stylesheet>