package Data::DumpXML;

use strict;
use vars qw(@EXPORT_OK $VERSION);

require Exporter;
*import = \&Exporter::import;
@EXPORT_OK=qw(dump_xml dump);

$VERSION = "0.0001";  # $Date$

use overload ();
use vars qw(%seen %ref $count);

#use HTTP::Date qw(time2iso);

sub dump_xml
{
    local %seen;
    local %ref;
    local $count = 0;
    my $out = qq(<?xml version="1.0" encoding="US-ASCII"?>\n);
    $out .= `cat dumpxml.dtd`;
    #$out .= qq(<!DOCTYPE dumpxml SYSTEM "dumpxml.dtd">\n);
    #$out .= qq(<data time="@{[time2iso()]}">);
    $out .= "<data>";
    $out .= format_list(map _dump($_), @_);
    $out .= "</data>\n";

    $count = 0;
    $out =~ s/\01/$ref{++$count} ? qq( id="$ref{$count}") : ""/ge;

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
	return qq(<alias id="$ref_no"/>);
    }
    $seen{$id} = ++$count;

    $class = $class ? " class=" . quote($class) : "";
    $id = "\1";  # magic that is removed or expanded to ' id="1"' in the end.

    if ($type eq "SCALAR") {
	return "<undef$class$id/>"
	    unless defined $$rval;
	return "<ref$class$id>" . format_list(_dump($$rval, 1)) . "</ref>"
	    if ref $$rval;
	if ($$rval =~ /[\x0-\x8\xB\xC\xE-\x1F\x7f-\x9f]/) {
	    # these chars can't be represented in XML at all
	    require MIME::Base64;
	    my $nl = (length $$rval < 40) ? "" : "\n";
	    my $b64 = MIME::Base64::encode($$rval, $nl);
	    return qq(<str$class encoding="base64"$id>$nl$b64</str>);
	}
	return "<str$class$id>" . esc($$rval) . "</str>";
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
	    $val =~ s/^/  /gm;
	    $out .= " <key>" . esc($key) . "</key>\n$val\n";
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
    for (@elem) { s/^/ /gm; }   # indent
    return "\n" . join("\n", @elem);
}

# put a string value in double quotes
sub quote {
    local($_) = shift;
    s/\"/&qout;/g;
    s/([^\040-\176])/sprintf("&#x%x;", ord($1))/ge;
    return qq("$_");
}

sub esc {
    local($_) = shift;
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/([^\040-\176])/sprintf("&#x%x;", ord($1))/ge;
    return $_;
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
list of something as argument and produce a string as result.  For
compatibility with C<Data::Dump> there is also an alias dump().

The string returned is an XML document that represents any perl data
structure passed in.  The following DTD (yeah, I know this is not
really a DTD yet) is used:

  <data>(undef|str|ref|alias)*</data>
  <undef/>
  <str>...</str>
  <ref>(undef|str|ref|alias|array|hash|glob|code)</ref>
  <alias/>
  <array>(undef|str|ref|alias)*</array>
  <hash>(key (undef|str|ref|alias))*</hash>
  <key>...</key>
  <glob/>
  <code/>

If dump_xml() is called in void context, then the dump will be printed on
STDERR instead of being returned.

=head1 BUGS

Character entity references for most characters below 32 ('space') is
illegal XML.  This can still be generated for hash keys.  Should
switch to base64 encoding here too when strange characters occur.

=head1 SEE ALSO

L<Data::Dump>, L<XML::Parser>

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
