#!/usr/bin/perl -w

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

#    use Data::Dump; Data::Dump::dump("---> $tag", $obj);

    my $objref = $obj;
    my $attr = shift @$obj;
    if ($tag eq "str" || $tag eq "key") {
	$p->{in_str}--;
	my $str = join("", @$obj);
	if (my $enc = $attr->{encoding}) {
	    if ($enc eq "base64") {
		require MIME::Base64;
		$str = MIME::Base64::decode($str);
	    }
	    else {
		warn "Unknown encoding '$enc'";
	    }
	}
	$p->{stack}[-1][-1] = $str;
	$objref = \$p->{stack}[-1][-1];
    }
    elsif ($tag eq "undef") {
	$p->{stack}[-1][-1] = undef;
	$objref = \$p->{stack}[-1][-1];
    }
    elsif ($tag eq "ref") {
	if (ref($obj->[0]) eq "ARRAY" && int(@{$obj->[0]}) > 1) {
	    $p->{stack}[-1][-1] = $obj->[0][1];
	}
	else {
	    $p->{stack}[-1][-1] = \$obj->[0];
	}
	$objref = \$p->{stack}[-1][-1];
    }
    elsif ($tag eq "data") {
	#$p->{stack}[-1][-1] = $obj;
    }
    elsif ($tag eq "array") {
	$p->{stack}[-1][-1] = ["array", $obj];
    }
    elsif ($tag eq "hash") {
	my $objref = {};
	for (my $i = 0; $i < @$obj; $i += 2) {
	    &hv_store($objref, $obj->[$i], $obj->[$i+1]);
	}
	$p->{stack}[-1][-1] = ["hash", $objref];
    }
    elsif ($tag eq "alias") {
	my $id = $attr->{id};
	#print "ALIAS $id\n";
	eval {
	    &av_store($p->{stack}[-1], -1, ${$p->{id}{$id}});
	};
	if ($@ && $@ =~ /^Not a SCALAR reference/) {
	    # assuming the thing above is <ref>...
	    $p->{stack}[-1][-1] = ["alias", $p->{id}{$id}];
	}
	$objref = \$p->{stack}[-1][-1];
    }
    else {
	# catch anything else (glob/code/...)
	$p->{stack}[-1][-1] = undef;
	$objref = \$p->{stack}[-1][-1];
    }
    if (my $class = $attr->{class}) {
	#print "BLESS $objref\n";
	bless $objref, $class;
    }

    if ((my $id = $attr->{id}) && $tag ne "alias") {
	$p->{id}{$id} = $objref;
    }
}

sub Final
{
    my $p = shift;
    $p->{dump_data}[0];
}
