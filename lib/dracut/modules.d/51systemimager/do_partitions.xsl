<?xml version="1.0" encoding="UTF-8"?>
<!--
     vi:set filetype=xml et ts=8:

     This file is part of SystemImager.

     SystemImager is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 2 of the License, or
     (at your option) any later version.

     SystemImager is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with SystemImager. If not, see <https://www.gnu.org/licenses/>.

     Copyright (C) 2017-2019 Olivier LAHAYE <olivier.lahaye1@free.fr>

     Purpose:
        XSL disks-layout processor: Used against a disks-layout.xml file, this
        filter will output partitions to be created in smart order so the variable
        size partition is outputed after all others.
.
	Each line list the following values separated by semicolons:
	- disk device
	- partition type (gpt/msdos/convert/none)
	- creation reference
	- partition number
	- partition size
	- partition size unit
	- partition type
	- partition id
	- partition name
	- partition flags
	- lvm group it belongs to
	- raid device it belongs to

     Usage:
        xmlstarlet tr do_part.xsl disk-layout.xml
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:exslt="http://exslt.org/common" version="1.0" extension-element-prefixes="exslt">
	<xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
	<xsl:strip-space elements="*"/>
	<xsl:template match="/config/disk"> <!-- We are loking for disk informations only -->
		<!-- For each disk block -->
		<xsl:call-template name="PrintPartition">
			<!-- Compute primary or extended partitions to create -->
			<xsl:with-param name="index">
				<xsl:value-of select="count(part)"/>
			</xsl:with-param>
			<xsl:with-param name="reference">end</xsl:with-param>
			<xsl:with-param name="type">primary|extended</xsl:with-param>
		</xsl:call-template>
		<xsl:call-template name="PrintPartition">
			<!-- then, compute logical partitions to create -->
			<xsl:with-param name="index">
				<xsl:value-of select="count(part)"/>
			</xsl:with-param>
			<xsl:with-param name="reference">end</xsl:with-param>
			<xsl:with-param name="type">logical</xsl:with-param>
		</xsl:call-template>
	</xsl:template>
	<!-- We're done -->
	<!-- Main recursive template that will dump partitions to create for the matched disk -->
	<xsl:template name="PrintPartition">
		<xsl:param name="index"/> <!-- partition node number within disk item-->
		<xsl:param name="reference"/> <!-- beginning or end: should we create partition relative from beginning or from end of free space -->
		<xsl:param name="type"/> <!-- type of partitions -->
		<xsl:choose>
			<xsl:when test="$index=1">
				<xsl:if test="contains($type,part[position()=$index]/@p_type)">
					<xsl:value-of select="concat(@dev,';',@label_type,';',$reference,';',part[position()=$index]/@num,';',part[position()=$index]/@size,';',@unit_of_measurement,';',part[position()=$index]/@p_type,';',part[position()=$index]/@id,';',part[position()=$index]/@p_name,';',part[position()=$index]/@flags,';',part[position()=$index]/@lvm_group,';',part[position()=$index]/@raid_dev,'&#10;')"/> <!-- write partition information -->
				</xsl:if>
			</xsl:when>
			<xsl:when test="contains($type,part[position()=$index]/@p_type) and part[position()=$index]/@size!='*'">
				<xsl:if test="$reference='end'">
					<xsl:value-of select="concat(@dev,';',@label_type,';',$reference,';',part[position()=$index]/@num,';',part[position()=$index]/@size,';',@unit_of_measurement,';',part[position()=$index]/@p_type,';',part[position()=$index]/@id,';',part[position()=$index]/@p_name,';',part[position()=$index]/@flags,';',part[position()=$index]/@lvm_group,';',part[position()=$index]/@raid_dev,'&#10;')"/> <!-- write partition information -->
				</xsl:if>
				<xsl:call-template name="PrintPartition">
					<xsl:with-param name="index">
						<xsl:value-of select="number($index)-1"/>
					</xsl:with-param>
					<xsl:with-param name="reference">
						<xsl:value-of select="$reference"/>
					</xsl:with-param>
					<xsl:with-param name="type">
						<xsl:value-of select="$type"/>
					</xsl:with-param>
				</xsl:call-template>
				<xsl:if test="$reference='beginning'">
					<xsl:value-of select="concat(@dev,';',@label_type,';',$reference,';',part[position()=$index]/@num,';',part[position()=$index]/@size,';',@unit_of_measurement,';',part[position()=$index]/@p_type,';',part[position()=$index]/@id,';',part[position()=$index]/@p_name,';',part[position()=$index]/@flags,';',part[position()=$index]/@lvm_group,';',part[position()=$index]/@raid_dev,'&#10;')"/> <!-- write partition information -->
				</xsl:if>
			</xsl:when>
			<xsl:when test="contains($type,part[position()=$index]/@p_type) and part[position()=$index]/@size='*'">
				<xsl:call-template name="PrintPartition">
					<xsl:with-param name="index">
						<xsl:value-of select="number($index)-1"/>
					</xsl:with-param>
					<xsl:with-param name="reference">beginning</xsl:with-param>
					<xsl:with-param name="type">
						<xsl:value-of select="$type"/>
					</xsl:with-param>
				</xsl:call-template>
				<xsl:value-of select="concat(@dev,';',@label_type,';','beginning;',part[position()=$index]/@num,';',part[position()=$index]/@size,';',@unit_of_measurement,';',part[position()=$index]/@p_type,';',part[position()=$index]/@id,';',part[position()=$index]/@p_name,';',part[position()=$index]/@flags,';',part[position()=$index]/@lvm_group,';',part[position()=$index]/@raid_dev,'&#10;')"/> <!-- write partition information -->
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="PrintPartition">
					<xsl:with-param name="index">
						<xsl:value-of select="number($index)-1"/>
					</xsl:with-param>
					<xsl:with-param name="reference">
						<xsl:value-of select="$reference"/>
					</xsl:with-param>
					<xsl:with-param name="type">
						<xsl:value-of select="$type"/>
					</xsl:with-param>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>
