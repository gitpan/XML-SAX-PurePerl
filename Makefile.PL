use ExtUtils::MakeMaker;

require 5.00503;

if ($] < 5.007002) {
    print <<EOT;
Perl 5.7.2 is required (actually bleedperl 11884 or higher) for this module
to work with encodings other than ASCII and UTF-8, due to advanced unicode 
functionality only supported in the very latest perl.

However, it has been made to work on lower perl versions, but you will
get an exception thrown if you try and parse files in other encodings.

EOT
    if (prompt("Do you wish to continue?", "y") !~ /^y/i) {
        exit;
    }
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME		=> 'XML::SAX::PurePerl',
    VERSION_FROM	=> 'PurePerl.pm', # finds $VERSION
    PREREQ_PM		=> {'File::Temp' => 0}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM => 'PurePerl.pm', # retrieve abstract from module
    AUTHOR     => 'Matt Sergeant, matt@sergeant.org',
);
