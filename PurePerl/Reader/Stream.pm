# $Id$

package XML::SAX::PurePerl::Reader::Stream;

use strict;
use vars qw(@ISA);

use XML::SAX::PurePerl::Reader;

@ISA = ('XML::SAX::PurePerl::Reader');

sub new {
    my $class = shift;
    my $ioref = shift;
    if ($] >= 5.007002) {
        binmode($ioref, ':raw'); # start in raw mode
    }
    return bless { fh => $ioref, line => 1, col => 0, buffer => '' }, $class;
}

sub next {
    my $self = shift;
    
    # check for chars in buffer first.
    if (length($self->{buffer})) {
        return $self->{current} = substr($self->{buffer}, 0, 1, ''); # last param truncates buffer
    }
    
#    if ($self->eof) {
#        die "Unable to read past end of file marker (b: $self->{buffer}, c: $self->{current}, m: $self->{matched})";
#    }
    
    my $buff;
    my $bytesread = read($self->{fh}, $buff, 1); # read 1 "byte" or character?
    # warn("read: $buff\n");
    if (defined($bytesread)) {
        if ($bytesread) {
            if ($buff eq "\n") {
                $self->{line}++;
                $self->{column} = 1;
            } else { $self->{column}++ }
                        
            return $self->{current} = $buff;
        }
        return undef;
    }
    
    # read returned undef. This is an error...
    die "Error reading from filehandle: $!";
}

sub set_encoding {
    my $self = shift;
    my ($encoding) = @_;
    
    if ($] >= 5.007002) {
        binmode($self->{fh}, ":encoding($encoding)");
    }
    else {
        die "Only ASCII encoding allowed without perl 5.7.2 or higher. You tried: $encoding" if $encoding !~ /ASCII/i;
    }
    $self->{encoding} = $encoding;
}

sub bytepos {
    my $self = shift;
    tell($self->{fh});
}

sub eof {
    my $self = shift;
    return CORE::eof($self->{fh});
}

1;
