package XML::SAX::PurePerl;

use strict;
use vars qw/$VERSION/;
use Carp;

#use 5.7.2;

$VERSION = '0.80';

use XML::SAX::PurePerl::Productions qw($S $Letter $NameChar $Any $CharMinusDash $Char);
use XML::SAX::PurePerl::Reader;
use XML::SAX::PurePerl::EncodingDetect ();
use XML::SAX::PurePerl::Exception;
use XML::SAX::PurePerl::DocType ();
use XML::SAX::PurePerl::DTDDecls ();
use XML::SAX::PurePerl::XMLDecl ();
use IO::File;

my %int_ents = (
        amp => '&',
        lt => '<',
        gt => '>',
        quot => '"',
        apos => "'",
        );

my $xmlns_ns = "http://www.w3.org/2000/xmlns/";
my $xml_ns = "http://www.w3.org/XML/1998/namespace";

# Parser options
my $decl_handler = "http://xml.org/sax/handlers/DeclHandler";
my $lex_handler = "http://xml.org/sax/handlers/LexicalHandler";

sub new {
    my $class = shift;
    unshift @_, 'Handler' unless @_ > 1;
    my %opts = @_;
    return bless \%opts, $class;
}

sub set_option {
    my $self = shift;
    my ($opt, $val) = @_;
    $self->{$opt} = $val;
}

sub parse {
    my $self = shift;
    
    if (defined $self->{ParseOptions}) {
        $self->parser_error("Parser instance already parsing");
    }
    
    $self->{ParseOptions} = _get_options($self, @_);

    if (!defined $self->{ParseOptions}{Handler}) {
        require XML::SAX::PurePerl::DebugHandler;
        $self->{ParseOptions}{Handler} = XML::SAX::PurePerl::DebugHandler->new();
    }
    
    if (!defined $self->{ParseOptions}{DocumentHandler}) {
        $self->{ParseOptions}{DocumentHandler} = $self->{ParseOptions}{Handler};
    }
    
    if (!defined $self->{ParseOptions}{DTDHandler}) {
        $self->{ParseOptions}{DTDHandler} = $self->{ParseOptions}{Handler};
    }
    
    if (!defined $self->{ParseOptions}{EntityResolver}) {
        $self->{ParseOptions}{EntityResolver} = $self->{ParseOptions}{Handler};
    }
    
    if (!defined $self->{ParseOptions}{ErrorHandler}) {
        $self->{ParseOptions}{ErrorHandler} = $self->{ParseOptions}{Handler};
    }
    
    $self->{ParseOptions}{DeclHandler} = $self->{ParseOptions}{$decl_handler};
    $self->{ParseOptions}{LexicalHandler} = $self->{ParseOptions}{$lex_handler};
    
    my $reader;
    if (defined $self->{ParseOptions}{Source}{ByteStream}) {
        $reader = XML::SAX::PurePerl::Reader::Stream->new(
                $self->{ParseOptions}{Source}{ByteStream}
                );
    }
    elsif (defined $self->{ParseOptions}{Source}{String}) {
        $reader = XML::SAX::PurePerl::Reader::String->new(
                $self->{ParseOptions}{Source}{String}
                );
    }
    elsif (defined $self->{ParseOptions}{Source}{SystemId}) {
        $reader = XML::SAX::PurePerl::Reader::URI->new(
                $self->{ParseOptions}{Source}{SystemId}
                );
    }
    else {
        $self->parser_error("Nothing to parse");
    }
    
    $reader->public_id($self->{ParseOptions}{Source}{PublicId});
    $reader->system_id($self->{ParseOptions}{Source}{SystemId});
    
    return $self->_parse($reader);
}

sub _parse {
    my ($self, $reader) = @_;
    
    $self->{InScopeNamespaceStack} = [ { 
        '#Default' => undef,
        'xmlns' => $xmlns_ns,
        'xml' => $xml_ns,
    } ];
    
    $self->dochandler_method('start_document', {});
    
    eval {
        $reader->init;
        
        if (defined $self->{ParseOptions}{Source}{Encoding}) {
            $reader->set_encoding($self->{ParseOptions}{Source}{Encoding});
        }
        else {
            $self->encoding_detect($reader);
        }
        
        # parse a document
        $self->document($reader);
    };
    if ($@) {
        if (ref $@ && $self->{ParseOptions}{IgnoreError}) {
            # do nothing
        }
        else {
            $self->_reset;
            
            die $@ if ref $@;
            throw XML::SAX::PurePerl::Exception ( Message => $@ );
        }
    }
    
    my $results = $self->dochandler_method('end_document', {});
    
    $self->_reset;
    
    return $results;
}

sub _reset {
    my $self = shift;
    delete @{$self}{qw(no_error error_message xml_version 
                standalone InScopeNamespaceStack ParseOptions)};
}

sub parse_any {
    my $self = shift;
    my $source = shift;
    
    my $reader = XML::SAX::PurePerl::Reader->new($source);
    
    return $self->_parse($reader);
}

sub parse_file {
    my $self = shift;
    my $source = shift;
    my $options = _get_options($self, @_);
    $options->{Source}{ByteStream} = $source;
    return $self->parse($options);
}

sub parse_uri {
    my $self = shift;
    my $source = shift;
    my $options = _get_options($self, @_);
    $options->{Source}{SystemId} = $source;
    return $self->parse($options);
}

sub parse_string {
    my $self = shift;
    my $source = shift;
    my $options = _get_options($self, @_);
    $options->{Source}{String} = $source;
    return $self->parse($options);
}

sub _get_options {
    my $hash = shift;
    
    if (!defined($hash)) {
        $hash = {};
    }
    
    if (@_ == 1) {
        my $options = shift;
        return { %$hash, %$options };
    }
    else {
        return { %$hash, @_ };
    }
}

sub get_feature {
    my ($self, $feature) = @_;
    return $self->{$feature} ? 1 : 0;
}

sub set_feature {
    my ($self, $feature, $value) = @_;
    return $self->{$feature} = ($value ? 1 : 0);
}

sub get_property {
    my ($self, $property) = @_;
    return $self->{$property};
}

sub set_property {
    my ($self, $property, $value) = @_;
    return $self->{$property} = $value;
}

sub dochandler_method {
    my $self = shift;
    my ($method_name, @params) = @_;
    
    return $self->handler_method($self->{ParseOptions}{DocumentHandler}, $method_name, @params);
}

sub lexhandler_method {
    my $self = shift;
    my ($method_name, @params) = @_;
    
    if (my $handler = $self->{ParseOptions}{LexicalHandler}) {
        return $self->handler_method($handler, $method_name, @params);
    }    
}

sub dtdhandler_method {
    my $self = shift;
    my ($method_name, @params) = @_;
    
    if (my $handler = $self->{ParseOptions}{DTDHandler}) {
        return $self->handler_method($handler, $method_name, @params);
    }
}

sub declhandler_method {
    my $self = shift;
    my ($method_name, @params) = @_;
    
    if (my $handler = $self->{ParseOptions}{DeclHandler}) {
        return $self->handler_method($handler, $method_name, @params);
    }
}

sub handler_method {
    my $self = shift;
    my ($handler, $method_name, @params) = @_;
    if (my $method = $handler->can($method_name)) {
        return $method->($handler, @params);
    }
}

sub parser_error {
    my $self = shift;
    my ($error, $reader) = @_;
    
    if (my $handler = $self->{ParseOptions}{ErrorHandler}) {
        if (my $method = $handler->can('fatal_error')) {
            # call handler
            $method->($handler, XML::SAX::PurePerl::Exception->new(Message => $error, reader => $reader));
            # now exit cleanly
            $self->{ParseOptions}{IgnoreError} = 1;
            throw XML::SAX::PurePerl::Exception (Message => "An error to ignore");
        }
    }
    throw XML::SAX::PurePerl::Exception (Message => $error, reader => $reader);    
}

sub document {
    my ($self, $reader) = @_;
    
    # document ::= prolog element Misc*
    
    $self->prolog($reader);
    $self->element($reader) ||
        $self->parser_error("Document requires an element", $reader);
    
    while(!$reader->eof) {
        $self->Misc($reader) || 
                $self->parser_error("Only Comments, PIs and whitespace allowed at end of document", $reader);
    }
}

sub prolog {
    my ($self, $reader) = @_;
    
    $self->XMLDecl($reader);
    
    # consume all misc bits
    1 while($self->Misc($reader));
    
    if ($self->doctypedecl($reader)) {
        while (!$reader->eof) {
            $self->Misc($reader) || last;
        }
    }
}

sub element {
    my ($self, $reader) = @_;
    
    if ($reader->match('<')) {
        my $name = $self->Name($reader) ||
                $self->parser_error("Invalid element name", $reader);
        
        my @attribs;
        
        1 while( @attribs < push(@attribs, $self->Attribute($reader)) );
        
        $self->skip_whitespace($reader);
        
        my $content;
        unless ($reader->match_string('/>')) {
            $reader->match('>') ||
                $self->parser_error("No close element tag", $reader);
            
            # only push onto _el_stack if not an empty element
            push @{$self->{_el_stack}}, $name;
            $content++;
        }
        
        # Namespace processing
        push @{ $self->{InScopeNamespaceStack} },
             { %{ $self->{InScopeNamespaceStack}[-1] } };
        $self->_scan_namespaces(@attribs);
        
        my ($prefix, $namespace) = $self->_namespace($name);
        if ($prefix && !defined $namespace) {
            $self->parser_error("prefix '$prefix' not bound to any namespace", $reader);
        }
        $namespace = "" unless defined $namespace;
        
        my $localname = $name;
        if ($namespace && $prefix) {
            ($localname) = $name =~ /^[^:]:(.*)$/;
        }
        
        # Create element object and fire event
        my %attrib_hash;
        while (@attribs) {
            my ($name, $value) = splice(@attribs, 0, 2);
            my ($namespace, $localname, $prefix) = ('', $name, '');
            if (index($name, ':') >= 0) {
                # prefixed attribute - get namespace
                ($prefix, $namespace) = $self->_namespace($name);
                if (!defined $namespace) {
                    $self->parser_error("prefix '$prefix' not bound to any namespace", $reader);
                }
                ($localname) = $name =~ /^[^:]*:(.*)$/;
            }
            $attrib_hash{"{$namespace}$localname"} = {
                        Name => $name,
                        LocalName => $localname,
                        Prefix => $prefix,
                        NamespaceURI => $namespace,
                        Value => $value,
            };
        }
        
        $self->dochandler_method('start_element', {
                Name => $name,
                LocalName => $localname,
                Prefix => $prefix,
                NamespaceURI => $namespace,
                Attributes => \%attrib_hash,
        } );
        
        # warn("($name\n");
        
        if ($content) {
            $self->content($reader);
            
            $reader->match_string('</') || $self->parser_error("No close tag marker", $reader);
            my $end_name = $self->Name($reader);
            $end_name eq $name || $self->parser_error("End tag mismatch ($end_name != $name)", $reader);
            $self->skip_whitespace($reader);
            $reader->match('>') || $self->parser_error("No close '>' on end tag", $reader);
            pop @{ $self->{InScopeNamespaceStack} };
        }
        
        $self->dochandler_method('end_element', {
            Name => $name,
            LocalName => "TODO",
            Prefix => "TODO",
            NamespaceURI => "TODO",
        } );
        
        return 1;
    }
    
    return 0;
}

sub _scan_namespaces {
    my ($self, %attributes) = @_;

    while (my ($attr_name, $value) = each %attributes) {
        if ($attr_name eq 'xmlns') {
            $self->{InScopeNamespaceStack}[-1]{'#Default'} = $value;
        } elsif ($attr_name =~ /^xmlns:(.*)$/) {
            my $prefix = $1;
            $self->{InScopeNamespaceStack}[-1]{$prefix} = $value;
        }
    }
}

sub _namespace {
    my ($self, $name) = @_;

    my ($prefix, $localname) = split(/:/, $name);
    if (!defined($localname)) {
        if ($prefix eq 'xmlns') {
            return '', undef;
        } else {
            return '', $self->{InScopeNamespaceStack}[-1]{'#Default'};
        }
    } else {
        return $prefix, $self->{InScopeNamespaceStack}[-1]{$prefix};
    }
}


sub content {
    my ($self, $reader) = @_;
    
    $self->CharData($reader);
    
    while (1) {
        if ($reader->match_string('</')) {
            $reader->buffer('</');
            return 1;
        }
        elsif ( $self->Reference($reader) ||
                $self->CDSect($reader) || 
                $self->PI($reader) || 
                $self->Comment($reader) ||
                $self->element($reader) 
               )
        {
            $self->CharData($reader);
            next;
        }
        else {
            last;
        }
    }
    
    return 1;
}

sub CDSect {
    my ($self, $reader) = @_;
    
    if ($reader->match_string('<![CDATA[')) {
        my $chars = '';
        while (1) {
            if ($reader->eof) {
                $self->parser_error("EOF looking for CDATA section end", $reader);
            }
            $reader->consume(qr/[^\]]/);
            $chars .= $reader->consumed;
            if ($reader->match(']')) {
                if ($reader->match_string(']>')) {
                    # end of CDATA section
                    
                    $self->dochandler_method('characters', {Data => $chars});
                    last;
                }
                $chars .= ']';
            }
        }
        return 1;
    }
    
    return 0;
}

sub CharData {
    my ($self, $reader) = @_;
    
    my $chars = '';
    while (1) {
        $reader->consume(qr/[^<&\]]/);
        $chars .= $reader->consumed;
        if ($reader->match(']')) {
            if ($reader->match_string(']>')) {
                $self->parser_error("String ']]>' not allowed in character data", $reader);
            }
            else {
                $chars .= ']';
            }
            next;
        }
        last;
    }
    
    $self->dochandler_method('characters', { Data => $chars });
}

sub Misc {
    my ($self, $reader) = @_;
    if ($self->Comment($reader)) {
        return 1;
    }
    elsif ($self->PI($reader)) {
        return 1;
    }
    elsif ($self->skip_whitespace($reader)) {
        return 1;
    }
    
    return 0;
}

sub Reference {
    my ($self, $reader) = @_;
    
    if (!$reader->match('&')) {
        return 0;
    }
    
    if ($reader->match('#')) {
        # CharRef
        my $char;
        if ($reader->match('x')) {
            $reader->consume(qr/[0-9a-fA-F]/) ||
                $self->parser_error("Hex character reference contains illegal characters", $reader);
            my $hexref = $reader->consumed;
            $char = chr(hex($hexref));
        }
        else {
            $reader->consume(qr/[0-9]/) ||
                $self->parser_error("Decimal character reference contains illegal characters", $reader);
            my $decref = $reader->consumed;
            $char = chr($decref);
        }
        $reader->match(';') ||
                $self->parser_error("No semi-colon found after character reference", $reader);
        if ($char !~ /^$Char$/) { # match a single character
            $self->parser_error("Character reference refers to an illegal XML character", $reader);
        }
        $self->dochandler_method('characters', { Data => $char });
        return 1;
    }
    else {
        # EntityRef
        my $name = $self->Name($reader);
        $reader->match(';') ||
                $self->parser_error("No semi-colon found after entity name", $reader);
        
        # expand it
        if ($self->_is_entity($name)) {
            
            if ($self->_is_external($name)) {
                my $value = $self->_get_entity($name);
                my $ent_reader = XML::SAX::PurePerl::Reader::URI->new($value);
                $self->encoding_detect($ent_reader);
                $self->extParsedEnt($ent_reader);
            }
            else {
                my $value = $self->_stringify_entity($name);
                my $ent_reader = XML::SAX::PurePerl::Reader::String->new($value);
                $self->content($ent_reader);
            }
            return 1;
        }
        elsif (_is_internal($name)) {
            $self->dochandler_method('characters', { Data => $int_ents{$name} });
            return 1;
        }
        else {
            $self->parser_error("Undeclared entity", $reader);
        }
    }
}

sub AttReference {
    # a reference in an attribute value.
    my ($self, $reader) = @_;
    
    if ($reader->match('#')) {
        # CharRef
        my $char;
        if ($reader->match('x')) {
            $reader->consume(qr/[0-9a-fA-F]/) ||
                $self->parser_error("Hex character reference contains illegal characters", $reader);
            my $hexref = $reader->consumed;
            $char = chr(hex($hexref));
        }
        else {
            $reader->consume(qr/[0-9]/) ||
                $self->parser_error("Decimal character reference contains illegal characters", $reader);
            my $decref = $reader->consumed;
            $char = chr($decref);
        }
        $reader->match(';') ||
                $self->parser_error("No semi-colon found after character reference", $reader);
        if ($char !~ /^$Char$/) { # match a single character
            $self->parser_error("Character reference refers to an illegal XML character", $reader);
        }
        return $char;
    }
    else {
        # EntityRef
        my $name = $self->Name($reader);
        $reader->match(';') ||
                $self->parser_error("No semi-colon found after entity name", $reader);
        
        # expand it
        if ($self->_is_entity($name)) {
            if ($self->_is_external($name)) {
                $self->parser_error("No external entity references allowed in attribute values", $reader);
            }
            else {
                my $value = $self->_stringify_entity($name);
                return $value;
            }
        }
        elsif (_is_internal($name)) {
            return $int_ents{$name};
        }
        else {
            $self->parser_error("Undeclared entity '$name'", $reader);
        }
    }
        
}

sub extParsedEnt {
    my ($self, $reader) = @_;
    
    $self->TextDecl($reader);
    $self->content($reader);
}

sub _is_internal {
    my $e = shift;
    return 1 if $e eq 'amp' || $e eq 'lt' || $e eq 'gt' || $e eq 'quot' || $e eq 'apos';
    return 0;
}

sub _is_external {
    my ($self, $name) = @_;
    if ($self->{ParseOptions}{external_entities}{$name}) {
        return 1;
    }
    return ;
}

sub _is_entity {
    my ($self, $name) = @_;
    if (exists $self->{ParseOptions}{entities}{$name}) {
        return 1;
    }
    return 0;
}

sub _stringify_entity {
    my ($self, $name) = @_;
    if (exists $self->{ParseOptions}{expanded_entity}{$name}) {
        return $self->{ParseOptions}{expanded_entity}{$name};
    }
    # expand
    my $reader = XML::SAX::PurePerl::Reader::URI->new($self->{ParseOptions}{entities}{$name});
    $reader->consume(qr/./);
    return $self->{ParseOptions}{expanded_entity}{$name} = $reader->consumed;
}

sub _get_entity {
    my ($self, $name) = @_;
    return $self->{ParseOptions}{entities}{$name};
}

sub skip_whitespace {
    my ($self, $reader) = @_;
    
    return $reader->consume($S);
}

sub Attribute {
    my ($self, $reader) = @_;
    
    $self->skip_whitespace($reader) || return;
    if ($reader->match_string("/>")) {
        $reader->buffer("/>");
        return;
    }
    if ($reader->match(">")) {
        $reader->buffer(">");
        return;
    }
    if (my $name = $self->Name($reader)) {
        $self->skip_whitespace($reader);
        $reader->match('=') ||
                $self->parser_error("No '=' in Attribute", $reader);
        $self->skip_whitespace($reader);
        my $value = $self->AttValue($reader);
        
        return $name, $value;
    }
    
    return;
}

my $quotre = qr/[^<&\"]/;
my $aposre = qr/[^<&\']/;

sub AttValue {
    my ($self, $reader) = @_;
    
    my $quote = '"';
    my $re = $quotre;
    if (!$reader->match($quote)) {
        $quote = "'";
        $re = $aposre;
        $reader->match($quote) ||
                $self->parser_error("Not a quote character", $reader);
    }
    
    my $value = '';
    
    while (1) {
        if ($reader->consume($re)) {
            $value .= $reader->consumed;
        }
        elsif ($reader->match('&')) {
            $value .= $self->AttReference($reader);
        }
        elsif ($reader->match($quote)) {
            # end of attrib
            last;
        }
        else {
            $self->parser_error("Invalid character in attribute value", $reader);
        }
    }
    
    return $value;
}

sub Comment {
    my ($self, $reader) = @_;
    
    if ($reader->match_string('<!--')) {
        my $comment_str = '';
        while (1) {
            if ($reader->match('-')) {
                if ($reader->match_string('-')) {
                    $reader->match_string('>') ||
                        $self->parser_error("Invalid string in comment field", $reader);
                    last;
                }
                $comment_str .= '-';
                $reader->consume($CharMinusDash) ||
                    $self->parser_error("Invalid string in comment field", $reader);
                $comment_str .= $reader->consumed;
            }
            elsif ($reader->consume($CharMinusDash)) {
                $comment_str .= $reader->consumed;
            }
            else {
                $self->parser_error("Invalid string in comment field", $reader);
            }
        }
        
        $self->lexhandler_method('comment', { Data => $comment_str });
        
        return 1;
    }
    return 0;
}

sub PI {
    my ($self, $reader) = @_;
    if ($reader->match_string('<?')) {
        my ($target, $data);
        $target = $self->Name($reader) ||
            $self->parser_error("PI has no target", $reader);
        if ($self->skip_whitespace($reader)) {
            while (1) {
                if ($reader->match_string('?>')) {
                    last;
                }
                elsif ($reader->match($Any)) {
                    $data .= $reader->matched;
                }
                else {
                    last;
                }
            }
        }
        else {
            $reader->match_string('?>') ||
                $self->parser_error("PI closing sequence not found", $reader);
        }
        $self->dochandler_method('processing_instruction',
            { Target => $target, Data => $data });
        
        return 1;
    }
    return 0;
}

sub Name {
    my ($self, $reader) = @_;
    
    my $name = '';
    if ($reader->match('_')) {
        $name .= '_';
    }
    elsif ($reader->match(':')) {
        $name .= ':';
    }
    else {
        $reader->consume($Letter) ||
            $self->parser_error("Name contains invalid start character '" . $reader->current . "'", $reader);
        $name .= $reader->consumed;
    }
    
    $reader->consume($NameChar);
    $name .= $reader->consumed;
    return $name;
}

sub quote {
    my ($self, $reader) = @_;
    my $quote = '"';
    
    if (!$reader->match($quote)) {
        $quote = "'";
        $reader->match($quote) ||
            $self->parser_error("Invalid quote token", $reader);
    }
    return $quote;
}

1;
__END__

=head1 NAME

XML::SAX::PurePerl - Pure Perl XML Parser with SAX2 interface

=head1 SYNOPSIS

  use XML::Handler::Foo;
  use XML::SAX::PurePerl;
  my $handler = XML::Handler::Foo->new();
  my $parser = XML::SAX::PurePerl->new(Handler => $handler);
  $parser->parse_uri("myfile.xml");

=head1 DESCRIPTION

This module implements an XML parser in pure perl. It is written around the upcoming
perl 5.8's unicode support and support for multiple document encodings (using the
PerlIO layer), however it has been ported to work with ASCII documents under lesser
perl versions.

The SAX2 API is described in detail at http://sourceforge.net/projects/perl-xml/, in
the CVS archive, under libxml-perl/docs. Hopefully those documents will be in a
better location soon.

Please refer to the SAX2 documentation for how to use this module - it is merely a
front end to SAX2, and implements nothing that is not in that spec (or at least tries
not to - please email me if you find errors in this implementation).

=head1 BUGS

Currently lots, probably. At the moment the weakest area is parsing DOCTYPE declarations,
though the code is in place to start doing this. Also parsing parameter entity
references is causing me much confusion, since it's not exactly what I would call
trivial, or well documented in the XML grammar. XML documents with internal subsets
are likely to fail.

I am however trying to work towards full conformance using the Oasis test suite.

=head1 AUTHOR

Matt Sergeant, matt@sergeant.org. Copyright 2001.

Please report all bugs to the Perl-XML mailing list at perl-xml@listserv.activestate.com.

=head1 LICENSE

This is free software. You may use it or redistribute it under the same terms as
Perl 5.7.2 itself.

=cut

