# $Id: DocType.pm,v 1.1.1.1 2001/10/25 19:44:25 matt Exp $

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
        
        $self->skip_whitespace($reader);
        
        $self->ExternalID($reader, $dtd);
        
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
            $self->parser_error("Not whitespace after SYSTEM identifier", $reader);
        $self->SystemLiteral($reader, $dtd);
    }
    elsif ($reader->match_string('PUBLIC')) {
        $self->skip_whitespace($reader);
        
        if ($reader->match('"')) {
            $reader->consume($PubidChar);
            $dtd->{PublicId} = $reader->consumed;
            $reader->match('"') || 
                $self->parser_error("Invalid token in PUBLIC ID (doctype) declaration", $reader);
            $self->skip_whitespace($reader) ||
                $self->parser_error("Not whitespace after PUBLIC ID in DOCTYPE", $reader);
        }
        
        $self->SystemLiteral($reader, $dtd);
    }
    else {
        return 0;
    }
    
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
        
        while(1) {
            last unless $self->markupdecl($reader) || $self->DeclSep($reader);
        }
        
        $reader->match(']') ||
            $self->parser_error("No close bracket on internal subset", $reader);
        $self->skip_whitespace($reader);
        return 1;
    }
    
    return 0;
}

sub DeclSep {
    my ($self, $reader) = @_;
    
    if ($self->PEReference($reader) ||
        $self->skip_whitespace($reader))
    {
        return 1;
    }
    
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
