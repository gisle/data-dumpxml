use ExtUtils::MakeMaker;

WriteMakefile(
   NAME         => "Data::DumpXML",
   VERSION_FROM => "DumpXML.pm",
   PREREQ_PM    => {
		    'MIME::Base64' => 2.00,
		   },
   dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
);
