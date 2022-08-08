<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:jats="http://jats.nlm.nih.gov" 
  xmlns:css="http://www.w3.org/1996/css"
  xmlns:xlink="http://www.w3.org/1999/xlink" 
  xmlns:saxon="http://saxon.sf.net/"
  exclude-result-prefixes="css jats xs xlink saxon" version="3.0">

  <xsl:mode name="fulltext" on-no-match="shallow-skip"/>
  <xsl:mode name="fulltext-text" on-no-match="text-only-copy"/>
  <xsl:mode name="fulltext-untangle-nested" on-no-match="shallow-copy"/>
  <xsl:mode name="fulltext-untangle-nested2" on-no-match="shallow-copy"/>

  <xsl:template match="/">
    <doc>
      <xsl:apply-templates mode="fulltext"/>
    </doc>
  </xsl:template>
  
  <xsl:template match="book-meta" mode="fulltext">
    <xsl:apply-templates select="book-title-group/book-title, contrib-group" mode="#current"/>
  </xsl:template>
  
  <xsl:template match="book-part-meta" mode="fulltext">
    <xsl:apply-templates select="title-group/title, contrib-group" mode="#current"/>
  </xsl:template>

  <xsl:template match="contrib" mode="fulltext">
    <p>
      <xsl:apply-templates select="." mode="path"/>
      <xsl:apply-templates select="." mode="fulltext-text"/>
    </p>
  </xsl:template>

  <xsl:template match="toc" mode="fulltext"/>
  
  <xsl:template match="p" mode="fulltext fulltext-text">
    <xsl:copy copy-namespaces="no">
      <xsl:copy-of select="@id"/>
      <xsl:apply-templates select="." mode="path"/>
      <xsl:apply-templates mode="fulltext-text"/>
    </xsl:copy>
    <xsl:apply-templates select=".//boxed-text" mode="fulltext"/>
  </xsl:template>
  
  <xsl:template match="boxed-text" mode="fulltext-text"/>
  
  <xsl:template match="*[@css:display = 'none']" mode="fulltext"/>
  
  <xsl:template match="*" mode="path" as="attribute(path)">
    <xsl:attribute name="path" select="path() => replace('/Q\{\}', '/')"/>
  </xsl:template>
  
  <xsl:template match="title | p" mode="fulltext-text fulltext" priority="10">
    <xsl:variable name="next-match" as="element(*)+">
      <xsl:next-match/>
    </xsl:variable>
    <xsl:apply-templates select="$next-match" mode="fulltext-untangle-nested"/>
  </xsl:template>
  
  <xsl:template match="*[p]" mode="fulltext-untangle-nested">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="." mode="path"/>
      <xsl:apply-templates select="@* | node()" mode="fulltext-untangle-nested2"/>
    </xsl:copy>
    <xsl:apply-templates select="p" mode="fulltext-untangle-nested"/>
  </xsl:template>

  <xsl:template match="p" mode="fulltext-untangle-nested2"/>


  <xsl:template match="text()" mode="fulltext fulltext-text">
    <xsl:value-of select="replace(., '[\p{Zs}\s]+', ' ', 's')"/>
  </xsl:template>
  
  <xsl:template match="list | def-list | table-wrap" mode="fulltext-text">
    <xsl:apply-templates select="." mode="fulltext"/>
  </xsl:template>
  
  <xsl:template match="index-term | alternatives/tex-math" mode="fulltext fulltext-text"/>
  
  <xsl:template match="title | term | mixed-citation" mode="fulltext">
    <xsl:copy copy-namespaces="no">
      <xsl:copy-of select="parent::title-group/parent::*/../@id, ../@id, @id"/>
      <xsl:apply-templates select="." mode="path"/>
      <xsl:apply-templates mode="fulltext-text"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="book-title" mode="fulltext">
    <title>
      <xsl:copy-of select="parent::book-title-group/parent::*/../@id, ../@id, @id"/>
      <xsl:apply-templates select="." mode="path"/>
      <xsl:apply-templates mode="fulltext-text"/>
    </title>
  </xsl:template>
  
  <xsl:template match="table-wrap/caption/title" mode="fulltext" priority="1">
    <p content-type="title" xsl:exclude-result-prefixes="#all">
      <xsl:copy-of select="../@id"/>
      <xsl:apply-templates mode="fulltext-text"/>
    </p>
  </xsl:template>
  
  <xsl:template match="xref[@alt]" mode="fulltext-text fulltext">
    <xsl:value-of select="normalize-space(@alt)"/>
  </xsl:template>
  
  
  <xsl:template match="fn | xref[@alt][@ref-type = ('table-fn')]" mode="fulltext fulltext-text"
                priority="1">
    <xsl:text> </xsl:text>
    <xsl:next-match/>
  </xsl:template>
  
  <xsl:template match="break" mode="fulltext fulltext-text">
    <xsl:text> </xsl:text>
  </xsl:template>
  
  <xsl:template match="book-part | front-matter-part | sec | glossary | preface | boxed-text" 
    mode="fulltext" priority="1">
    <div xsl:exclude-result-prefixes="#all">
      <xsl:apply-templates select="label" mode="label"/>
      <xsl:apply-templates mode="#current"/>
    </div>
  </xsl:template>
  
  <xsl:template match="label" mode="fulltext"/>
  
  <xsl:template match="label" mode="label" >
    <xsl:attribute name="n" select="."/>
  </xsl:template>
  
</xsl:stylesheet>