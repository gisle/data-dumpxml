package Data::DumpXML;

use strict;
use vars qw(@EXPORT_OK $VERSION);

require Exporter;
*import = \&Exporter::import;
@EXPORT_OK=qw(dump_xml dump);

$VERSION = "1.01";  # $Date$

use vars qw($INDENT);  # configuration
$INDENT = " " unless defined $INDENT;

use overload ();
use vars qw(%seen %ref $count);

#use HTTP::Date qw(time2iso);

sub dump_xml
{
    local %seen;
    local %ref;
    local $count = 0;
    my $out = qq(<?xml version="1.0" encoding="US-ASCII"?>\n);
    $out .= qq(<!DOCTYPE data SYSTEM "dumpxml.dtd">\n);
    #$out .= qq(<data time="@{[time2iso()]}">);
    $out .= "<data>";
    $out .= format_list(map _dump($_), @_);
    $out .= "</data>\n";

    $count = 0;
    $out =~ s/\01/$ref{++$count} ? qq( id="r$ref{$count}") : ""/ge;

    print STDERR $out unless defined wantarray;
    $out;
}

*dump = \&dump_xml;

sub _dump
{
    my $rval = \$_[0]; shift;
    my $deref = shift;
    $rval = $$rval if $deref;

    my($class, $type, $id);
    if (overload::StrVal($rval) =~ /^(?:([^=]+)=)?([A-Z]+)\(0x([^\)]+)\)$/) {
	$class = $1;
	$type  = $2;
	$id    = $3;
    } else {
	return qq(<!-- Can\'t parse \") . overload::StrVal($rval) . qq(\" -->);
    }

    if (my $seq = $seen{$id}) {
	my $ref_no = $ref{$seq} || ($ref{$seq} = keys(%ref) + 1);
	return qq(<alias ref="r$ref_no"/>);
    }
    $seen{$id} = ++$count;

    $class = $class ? " class=" . quote($class) : "";
    $id = "\1";  # magic that is removed or expanded to ' id="r1"' in the end.

    if ($type eq "SCALAR" || $type eq "REF") {
	return "<undef$class$id/>"
	    unless defined $$rval;
	return "<ref$class$id>" . format_list(_dump($$rval, 1)) . "</ref>"
	    if ref $$rval;
	my($str, $enc) = esc($$rval);
	return "<str$class$id$enc>$str</str>";
    }
    elsif ($type eq "ARRAY") {
	return "<array$class$id/>" unless @$rval;
	return "<array$class$id>" . format_list(map _dump($_), @$rval) .
	       "</array>";
    }
    elsif ($type eq "HASH") {
	my $out = "<hash$class$id>\n";
	for my $key (sort keys %$rval) {
	    my $val = \$rval->{$key};
	    $val = _dump($$val);
	    if ($INDENT) {
		$val =~ s/^/$INDENT$INDENT/gm;
		$out .= $INDENT;
	    }
	    my($str, $enc) = esc($key);
	    $out .= "<key$enc>$str</key>\n$val\n";
	}
	$out .= "</hash>";
	return $out;
    }
    elsif ($type eq "GLOB") {
	return "<glob$class$id/>";
    }
    elsif ($type eq "CODE") {
	return "<code$class$id/>";
    }
    else {
	#warn "Can't handle $type data";
	return "<!-- Unknown type $type -->";
    }
    die "Assert";
}

sub format_list
{
    my @elem = @_;
    if ($INDENT) {
	for (@elem) { s/^/$INDENT/gm; }
    }
    return "\n" . join("\n", @elem);
}

# put a string value in double quotes
sub quote {
    local($_) = shift;
    s/&/&amp;/g;
    s/\"/&quot;/g;
    s/</&lt;/g;
    s/([^\040-\176])/sprintf("&#x%x;", ord($1))/ge;
    return qq("$_");
}

sub esc {
    local($_) = shift;
    if (/[\x00-\x08\x0B\x0C\x0E-\x1F\x7f-\xff]/) {
	# \x00-\x08\x0B\x0C\x0E-\x1F these chars can't be represented in XML at all
	# \x7f is special
	# \x80-\xff will be mangled into UTF-8
	require MIME::Base64;
	my $nl = (length($_) < 40) ? "" : "\n";
	my $b64 = MIME::Base64::encode($_, $nl);
	return $nl.$b64, qq( encoding="base64");
    }

    s/&/&amp;/g;
    s/</&lt;/g;
    s/([^\040-\176])/sprintf("&#x%x;", ord($1))/ge;
    return $_, "";
}

1;

__END__

=head1 NAME

Data::DumpXML - Dump arbitrary data structures as XML

=head1 SYNOPSIS

 use Data::DumpXML qw(dump_xml);
 $xml = dump_xml(@list)

=head1 DESCRIPTION

This module provide a single function called dump_xml() that takes a
list of something as argument and produce a string as result.

The string returned is an XML document that represents any perl data
structure passed in.  The following DTD is used:

  <!DOCTYPE data [
   <!ENTITY % scalar "undef | str | ref | alias">

   <!ELEMENT data (%scalar;)*>
   <!ELEMENT undef EMPTY>
   <!ELEMENT str (#PCDATA)>
   <!ELEMENT ref (%scalar; | array | hash | glob | code)>
   <!ELEMENT alias EMPTY>
   <!ELEMENT array (%scalar;)*>
   <!ELEMENT hash  (key, (%scalar;))*>
   <!ELEMENT key (#PCDATA)>
   <!ELEMENT glob EMPTY>
   <!ELEMENT code EMPTY>

   <!ENTITY % stdattlist 'id       ID             #IMPLIED
                          class    CDATA          #IMPLIED'>
   <!ENTITY % encoding   'encoding (plain|base64) "plain"'>

   <!ATTLIST undef %stdattlist;>
   <!ATTLIST ref %stdattlist;>
   <!ATTLIST undef %stdattlist;>
   <!ATTLIST array %stdattlist;>
   <!ATTLIST hash %stdattlist;>
   <!ATTLIST glob %stdattlist;>
   <!ATTLIST code %stdattlist;>

   <!ATTLIST str %stdattlist; %encoding;>
   <!ATTLIST key %encoding;>

   <!ATTLIST alias ref IDREF #IMPLIED>
  ]>

As an example of the XML documents producted; the following call:

  $a = bless [1,2], "Foo";
  $a->[2] = \$a;
  $b = $a;
  dump_xml($a, $b);

will produce:

  <?xml version="1.0" encoding="US-ASCII"?>
  <data>
   <ref id="r1">
    <array class="Foo" id="r2">
     <str>1</str>
     <str>2</str>
     <ref>
      <alias ref="r1"/></ref></array></ref>
   <ref>
    <alias ref="r2"/></ref></data>

If dump_xml() is called in void context, then the dump will be printed
on STDERR instead of being returned.  For compatibility with
C<Data::Dump> there is also an alias for dump_xml() simply called
dump().

You can set the variable $Data::DumpXML::INDENT to control indenting
before calling dump_xml().  To suppress indenting set it as "".

The C<Data::DumpXML::Parser> is a class that can restore
datastructures dumped by dump_xml().

=head1 BUGS

Class names with 8-bit characters will be dumped as Latin-1, but
converted to UTF-8 when restored by the Data::DumpXML::Parser.

The content of globs and subroutines are not dumped.  They are
restored as the strings; "** glob **" and "** code **".

LVALUE and IO objects are not dumped at all.  They will simply
disappear from the restored data structure.

=head1 SEE ALSO

L<Data::DumpXML::Parser>, L<XML::Parser>, L<XML::Dumper>, L<Data::Dump>

=head1 AUTHORS

The C<Data::DumpXML> module is written by Gisle Aas <gisle@aas.no>,
based on C<Data::Dump>.

The C<Data::Dump> module was written by Gisle Aas, based on
C<Data::Dumper> by Gurusamy Sarathy <gsar@umich.edu>.

 Copyright 1998-2000 Gisle Aas.
 Copyright 1996-1998 Gurusamy Sarathy.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
