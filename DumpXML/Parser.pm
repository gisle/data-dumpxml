package Data::DumpXML::Parser;

use strict;
use vars qw($VERSION @ISA);

$VERSION = "0.01";

require XML::Parser;
@ISA=qw(XML::Parser);

sub new
{
    my($class, %arg) = @_;
    $arg{Style} = "Data::DumpXML::ParseStyle";
    return $class->SUPER::new(%arg);
}

package Data::DumpXML::ParseStyle;

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

    return $alias->{$attr->{ref} }if $type eq "alias";

    #print "T $type\n";
    my $ref;  # a reference to the thing

    if ($type eq "ref") {
	$e = $e->[0];
	my $val = fix($e, $alias);
	$ref = \$val;
    }
    elsif ($type eq "array") {
	for (my $i = 0; $i < @$e; $i++) {
	    my $cur = $e->[$i];
	    $cur = fix($cur, $alias);
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
	    $val = fix($val, $alias);
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