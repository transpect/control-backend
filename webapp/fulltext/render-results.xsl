<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="xs saxon html" version="3.0">

  <xsl:mode name="render-work-matches" on-no-match="text-only-copy"/>

  <xsl:param name="term" as="xs:string" select="'test'"/>
  <xsl:param name="xpath" as="xs:string" select="''"/>
  <xsl:param name="langs" as="xs:string" select="'de,en'"/>
  <xsl:param name="svnbaseurl" as="xs:string" select="'http://localhost/svn'"/>
  <xsl:param name="siteurl" as="xs:string" select="'http://localhost/control'"/>
  <xsl:param name="group" select="'hierarchy'"/>
  <xsl:param name="work-id-position" as="xs:integer" select="3">
    <!-- the path component position, measured from the XML file name, which is 1.
      Example: in imprint/series/workid/xml/file.xml, workid is 3rd to last --> 
  </xsl:param>
  <xsl:param name="show-details" as="xs:boolean" select="true()"/>

  <xsl:template match="search-results">
    <div id="search-results">
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
      <xsl:variable name="terminals" as="element(result)*"
        select="current-group()/self::result[@virtual-steps + 1 - $work-id-position = $hierarchy-component]"/>
      <details>
        <xsl:if test="$open or count(current-group()) = 1">
          <xsl:attribute name="open" select="'true'"/>
        </xsl:if>
        <summary>
          <xsl:variable name="context" as="element(result)" select="."/>
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
                         )}&amp;restrict_path=true&amp;term={$term}&amp;xpath={$xpath}{
                           string-join(for $lang in tokenize($langs, ',') return '&amp;lang=' || $lang)
                         }"
             target="_blank">
            <xsl:value-of select="current-grouping-key()"/>
            <xsl:if test="exists($terminals)">
              <xsl:text> </xsl:text>
              <xsl:value-of select="$terminals[1]/breadcrumbs/title[1]"/>
            </xsl:if>
          </a>
          <xsl:text> (</xsl:text>
          <xsl:value-of select="count(current-group())"/>
          <xsl:text>)</xsl:text>
        </summary>
        <xsl:if test="$open">
          <xsl:for-each-group select="current-group()" group-by="@breadcrumbs-signature">
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
              <xsl:otherwise>
                <p class="search-breadcrumbs">
                  <xsl:apply-templates select="breadcrumbs" mode="render-work-matches"/>
                </p>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each-group>
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
      </details>
    </xsl:for-each-group>
  </xsl:template>

  <xsl:template match="result" mode="render-work-matches">
    <p class="search-breadcrumbs">
      <xsl:apply-templates select="breadcrumbs/title[position() gt 1]" mode="#current"/>
    </p>
    <xsl:apply-templates select="context" mode="#current"/>
  </xsl:template>

  <xsl:template match="context" mode="render-work-matches">
    <li>
      <p class="search-xpath">
        <xsl:value-of select="../@path"/>
      </p>
      <p class="search-context">
        <xsl:apply-templates mode="#current"/>
      </p>
    </li>
  </xsl:template>

  <xsl:template match="breadcrumbs/title" mode="render-work-matches">
    <span class="search-breadcrumb">
      <xsl:apply-templates mode="#current"/>
    </span>
    <xsl:if test="not(position() = last())">
      <xsl:text> > </xsl:text>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="mark" mode="render-work-matches">
    <span class="search-mark">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
</xsl:stylesheet>