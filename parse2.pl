#!/usr/bin/perl -w

use strict;
use XML::Parser;

my $p = XML::Parser->new(Style => "Data::DumpXML::Style");
my $x = $p->parsefile(shift || "test.xml");

use Data::Dump qw(dump);
print dump($x), "\n";

package Data::DumpXML::Style;

use Array::RefElem qw(av_store hv_store);

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
    my $obj = [$tag, \%attr];
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
    $p->{in_str}-- if $tag eq "str" || $tag eq "key";
}

sub Final
{
    my $p = shift;
    my $data = $p->{dump_data}[0];
    die unless $data->[0] eq "data";
    $data->[0] = "array";
    return fix($data, {});
}

sub fix
{
    my($e, $alias) = @_;
    my $type = shift @$e;
    my $attr = shift @$e;

    #print "T $type\n";
    my $ref;  # a reference to the thing

    if ($type eq "ref") {
	$e = $e->[0];
	if ($e->[0] eq "alias") {
	    my $ref_attr = $e->[1]{ref};
	    $ref = \$alias->{$ref_attr};
	}
	else {
	    my $val = fix($e, $alias);
	    $ref = \$val;
	}
    }
    elsif ($type eq "array") {
	for (my $i = 0; $i < @$e; $i++) {
	    my $cur = $e->[$i];
	    my $type = $cur->[0];
	    if ($type eq "alias") {
		my $ref = $cur->[1]{ref};
		$cur = $alias->{$ref};
	    }
	    else {
		$cur = fix($cur, $alias);
	    }
	    &av_store($e, $i, $$cur);
	}
	$ref = $e;
    }
    elsif ($type eq "hash") {
	my %hv;
	for (my $i = 0; $i < @$e; $i += 2) {
	    my $key = $e->[$i];
	    die unless $key->[0] eq "key";
	    $key->[0] = "str";
	    $key = ${fix($key, $alias)};

	    my $val = $e->[$i+1];
	    my $val_type = $val->[0];
	    if ($val_type eq "alias") {
		my $ref = $val->[1]{ref};
		$val = $alias->{$ref};
	    }
	    else {
		$val = fix($val, $alias);
	    }
	    hv_store(%hv, $key, $$val);
	}
	$ref = \%hv;
    }
    elsif ($type eq "str") {
	my $val = join("", @$e);
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
    elsif ($type eq "undef") {
	my $val = undef;
	$ref = \$val;
    }
    else {
	my $val = "XXX $type";
	$ref = \$val;
    }

    if (my $c = $attr->{class}) {
	bless $ref, $c;
    }

    if (my $id = $attr->{id}) {
	$alias->{$id} = $ref;
    }

    return $ref;
}
