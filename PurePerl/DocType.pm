# $Id: DocType.pm,v 1.3 2001/11/02 15:24:27 matt Exp $

package XML::SAX::PurePerl;

use strict;
use XML::SAX::PurePerl::Productions qw($PubidChar);

sub doctypedecl {
    my ($self, $reader) = @_;
    
    if ($reader->match_string('<!DOCTYPE')) {
        $self->skip_whitespace($reader) ||
            $self->parser_error("No whitespace after doctype declaration", $reader);
        
        my $dtd = {};
        $dtd->{Name} = $self->Name($reader) ||
            $self->parser_error("Doctype declaration has no root element name", $reader);
        
        if ($self->skip_whitespace($reader)) {
            # might be externalid...
            $self->ExternalID($reader, $dtd);
        }
        
        $self->skip_whitespace($reader);
        
        $self->InternalSubset($reader);
        
        $reader->match('>') ||
                $self->parser_error("Doctype not closed", $reader);
        
        return 1;
    }
    
    return 0;
}

sub ExternalID {
    my ($self, $reader, $dtd) = @_;
    
    if ($reader->match_string('SYSTEM')) {
        $self->skip_whitespace($reader) ||
            $self->parser_error("No whitespace after SYSTEM identifier", $reader);
        $self->SystemLiteral($reader, $dtd);
    }
    elsif ($reader->match_string('PUBLIC')) {
        $self->skip_whitespace($reader) ||
            $self->parser_error("No whitespace after PUBLIC identifier", $reader);
        
        my $quote = $self->quote($reader) || 
            $self->parser_error("Not a quote character in PUBLIC identifier", $reader);
        
        $reader->consume(qr/[^$quote]/);
        my $pubid = $reader->consumed;
        if ($pubid !~ /^($PubidChar)+$/) {
            $self->parser_error("Invalid characters in PUBLIC identifier", $reader);
        }
        
        $reader->match($quote) || 
            $self->parser_error("Invalid quote character ending PUBLIC identifier", $reader);
        $self->skip_whitespace($reader) ||
            $self->parser_error("Not whitespace after PUBLIC ID in DOCTYPE", $reader);
        
        $self->SystemLiteral($reader, $dtd);
    }
    else {
        return 0;
    }
    
    # FIXME - this is in the wrong place
    $self->lexhandler_method('start_dtd', $dtd);
    
    return 1;
}

sub SystemLiteral {
    my ($self, $reader, $dtd) = @_;
    
    my $quote = $self->quote($reader);
    
    $reader->consume(qr/[^$quote]/);
    $dtd->{SystemId} = $reader->consumed;
    
    $reader->match($quote) ||
        $self->parser_error("Invalid token in System Literal", $reader);
}

sub InternalSubset {
    my ($self, $reader) = @_;
    
    if ($reader->match('[')) {
        
        1 while $self->IntSubsetDecl($reader);
        
        $reader->match(']') ||
            $self->parser_error("No close bracket on internal subset", $reader);
        $self->skip_whitespace($reader);
        return 1;
    }
    
    return 0;
}

sub IntSubsetDecl {
    my ($self, $reader) = @_;

    return $self->DeclSep($reader) || $self->markupdecl($reader);
}

sub DeclSep {
    my ($self, $reader) = @_;

    if ($self->skip_whitespace($reader)) {
        return 1;
    }

    if ($self->PEReference($reader)) {
        return 1;
    }
    
#    if ($self->ParsedExtSubset($reader)) {
#        return 1;
#    }
    
    return 0;
}

sub PEReference {
    my ($self, $reader) = @_;
    
    if ($reader->match('%')) {
        my $peref = $self->Name($reader) ||
            $self->parser_error("PEReference did not find a Name", $reader);
        # TODO - load/parse the peref
        
        $reader->match(';') ||
            $self->parser_error("Invalid token in PEReference", $reader);
        return 1;
    }
    
    return 0;
}

sub markupdecl {
    my ($self, $reader) = @_;
    
    if ($self->elementdecl($reader) ||
        $self->AttlistDecl($reader) ||
        $self->EntityDecl($reader) ||
        $self->NotationDecl($reader) ||
        $self->PI($reader) ||
        $self->Comment($reader))
    {
        return 1;
    }
    
    return 0;
}

1;
