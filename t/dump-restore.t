use strict;
use Data::DumpXML qw(dump_xml);
use Data::DumpXML::Parser;

my $obj = bless { foo => 33, bar => "<>" }, "Obj";

my @tests = (
   [1..10],
   [\1],
   [\\\\\\1],
   [undef],
   [bless[], "Foo"],
   [$obj, $obj, \$obj, [$obj, $obj]],
   [\$obj->{foo}, $obj, $obj],
   [{"\0" => "\1"}],
   [bless [], 'Class&<>"'],   # funny class name
   [join("", map chr, 0.255)],
   ["ære våre børn"],
   #[bless["ære våre børn"], "fårepølse"],  # high-bit class names are mangled
);


print "1.." . @tests . "\n";
my $testno = 1;
for (@tests) {
   my $xml1 = dump_xml(@$_);
   print $xml1;

   my $restore = Data::DumpXML::Parser->new->parse($xml1);
   my $xml2 = dump_xml(@$restore);

   unless ($xml1 eq $xml2) {
       print $xml2;
       print "not ";
   }
   print "ok " . $testno++ . "\n";
}
