# $Id$

package XML::SAX::PurePerl;

sub elementdecl {
    my ($self, $reader) = @_;
    
    if ($reader->match_string('<!ELEMENT')) {
        $self->skip_whitespace($reader) ||
            $self->parser_error("No whitespace after ELEMENT declaration", $reader);
        
        my $el_obj = {};
        $el_obj->{Name} = $self->Name($reader);
        
        $self->skip_whitespace($reader) ||
            $self->parser_error("No whitespace after ELEMENT's name", $reader);
            
        $self->contentspec($reader, $el_obj);
        
        $self->skip_whitespace($reader);
        
        $reader->match('>') ||
            $self->parser_error("Closing angle bracket not found on ELEMENT declaration", $reader);
        
        return 1;
    }
    
    return 0;
}

sub contentspec {
    my ($self, $reader, $el_obj) = @_;
    
    if ($reader->match_string('EMPTY')) {
        $el_obj->{Model} = 'EMPTY';
        return 1;
    }
    elsif ($reader->match_string('ANY')) {
        $el_obj->{Model} = 'ANY';
        return 1;
    }
    elsif ($self->Mixed($reader, $el_obj)) {
        return 1;
    }
    elsif ($self->children($reader, $el_obj)) {
        return 1;
    }
    
    $self->parser_error("contentspec not found in ELEMENT declaration", $reader);
}

sub Mixed {
    my ($self, $reader, $el_obj) = @_;
    
    if ($reader->match('(')) {
        $self->skip_whitespace($reader);
        if (!$reader->match_string('#PCDATA')) {
            # HACK ALERT! Must find a better way to fix this!
            $reader->{buffer} = '(' . $reader->{buffer} . $reader->current;
            return 0;
        }
        
        
        
        $reader->match(')') || 
            $self->parser_error("Invalid token in Mixed content", $reader);
    }
    
    return 0;
}

sub children {
    my ($self, $reader, $el_obj) = @_;
}

sub AttlistDecl {
    my ($self, $reader) = @_;
    
    return 0;
}

sub EntityDecl {
    my ($self, $reader) = @_;
    
    return 0;
}

sub NotationDecl {
    my ($self, $reader) = @_;
    
    return 0;
}

1;
