package Data::DumpXML::Parser;

use strict;
use vars qw($VERSION @ISA);

$VERSION = "0.02";

require XML::Parser;
@ISA=qw(XML::Parser);

sub new
{
    my($class, %arg) = @_;
    $arg{Style} = "Data::DumpXML::ParseStyle";
    return $class->SUPER::new(%arg);
}

package Data::DumpXML::ParseStyle;

use Array::RefElem qw(av_push hv_store);

sub Init
{
    my $p = shift;
    $p->{dump_data} = [];
    push(@{$p->{stack}}, $p->{dump_data});
}

sub Start
{
    my($p, $tag, %attr) = @_;
    $p->{in_str}++ if $tag eq "str" || $tag eq "key";
    my $obj = [\%attr];
    push(@{$p->{stack}[-1]}, $obj);
    push(@{$p->{stack}}, $obj);
}

sub Char
{
    my($p, $str) = @_;
    return unless $p->{in_str};
    push(@{$p->{stack}[-1]}, $str);
}

sub End
{
    my($p, $tag) = @_;
    my $obj = pop(@{$p->{stack}});
    my $attr = shift(@$obj);

    my $ref;

    if ($tag eq "str" || $tag eq "key") {
	$p->{in_str}--;
        my $val = join("", @$obj);
        if (my $enc = $attr->{encoding}) {
            if ($enc eq "base64") {
                require MIME::Base64;
                $val = MIME::Base64::decode($val);
            }
            else {
                warn "Unknown encoding '$enc'";
            }
        }
	$ref = \$val;
    }
    elsif ($tag eq "ref") {
	my $val = $obj->[0];
	$ref = \$val;
    }
    elsif ($tag eq "array" || $tag eq "data") {
	my @val;
	for (@$obj) {
	    av_push(@val, $$_);
	}
	$ref = \@val;
    }
    elsif ($tag eq "hash") {
	my %val;
	while (@$obj) {
	    my $keyref = shift @$obj;
	    my $valref = shift @$obj;
	    hv_store(%val, $$keyref, $$valref);
	}
	$ref = \%val;
    }
    elsif ($tag eq "undef") {
	my $val = undef;
	$ref = \$val;
    }
    elsif ($tag eq "alias") {
	$ref = $p->{alias}{$attr->{ref}};
    }
    else {
	my $val = "*** $tag ***";
	$ref = \$val;
    }

    $p->{stack}[-1][-1] = $ref;

    if (my $c = $attr->{class}) {
	bless $ref, $c;
    }

    if (my $id = $attr->{id}) {
	$p->{alias}->{$id} = $ref;
    }
}

sub Final
{
    my $p = shift;
    my $data = $p->{dump_data}[0];
    return $data;
}

1;

__END__

=head1 NAME

Data::DumpXML - Dump arbitrary data structures as XML

=head1 SYNOPSIS

 use Data::DumpXML::Parser;

 my $p = Data::DumpXML::Parser->new;
 my $data = $p->parsefile(shift || "test.xml");

=head1 DESCRIPTION

The C<Data::DumpXML::Parser> is an C<XML::Parser> subclass that will
recreate the data structure from the XML produced by C<Data::DumpXML>.
A reference to an array of the values dumped are returned by the
parsefile() method.

=head1 SEE ALSO

L<Data::DumpXML>, L<XML::Parser>

=head1 AUTHOR

Copyright 2000 Gisle Aas.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
