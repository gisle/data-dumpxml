use ExtUtils::MakeMaker;

WriteMakefile(
   NAME         => "Data::DumpXML",
   VERSION_FROM => "DumpXML.pm",
   dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
);
