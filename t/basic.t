print "1..4\n";

use strict;
use Data::DumpXML qw(dump_xml);

my $xml;

$xml = remove_space(dump_xml(33));
print "not " unless $xml =~ m,<data><str>33</str></data>,;
print "ok 1\n";

$xml = remove_space(dump_xml(\33));
print "not " unless $xml =~ m,<data><ref><str>33</str></ref></data>,;
print "ok 2\n";

$xml = remove_space(dump_xml([33,"\0"]));
print "not " unless $xml =~ m,<data><ref><array><str>33</str><str encoding="base64">AA==</str></array></ref></data>,;
print "ok 3\n";

my $undef = undef;
my $ref1 = \$undef;
bless $ref1, "undef-class";
my $ref2 = \$ref1;
bless $ref2, "ref-class";
$xml = remove_space(dump_xml(bless {ref => $ref2}, "Bar"));
print "not " unless $xml =~ m,<data><ref><hash class="Bar"><key>ref</key><ref><ref class="ref-class"><undef class="undef-class"/></ref></ref></hash></ref></data>,;
print "ok 4\n";


#------------

sub remove_space
{
    my $xml = shift;
    $xml =~ s/>\s+</></g;
    $xml;
}
