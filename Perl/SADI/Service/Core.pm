=head1 NAME

     SADI::Service::Core -- A Perl package for SADI services

=head1 DESCRIPTION

    This is a module that helps service providers for SADI services do most
    of the routine garbage that they need to do to parse and construct
    RDF messages for SADI


=head1 SYNOPSIS

 use SADI::Service::Core;
 my $service = SADI::Service::Core->new(
     ServiceName => "helloworld",
     ServiceType => "http://someontology.org/services/sometype",
     InputClass => "http://someontology.org/datatypes#Input1",
     OutputClass => "http://someontology.org/datatypes#Output1",
     Description => "the usual hello world service",
     UniqueIdentifier => "urn:lsid:myservices:helloworld",
     ServicePredicate => "http://someontology.org/predicates#newDataProvided",
     Authority => "helloworld.com",
     Provider => 'myaddress@organization.org',
     ServiceURI => "http://helloworld.com/cgi-bin/helloworld.pl",
     URL => "http://helloworld.com/cgi-bin/helloworld.pl",
     );
 
 # if GET then send interface and exit
 $service->sendInterfaceOnGET;
 $service->Prepare() || die "somehow the input data was improperly formed\n";

 # get the RDF nodes representing the input, based on input class (from 'new')
 my @inputs = $service->getInputNodes();

 # for each input, get the value of some property we want to operate on
 my %values = $service->getLiteralPropertyValues(
     nodes => \@inputs,
     property => "http://sadiframework.org/miscObjects.owl#keywordAsString");

 # and process that data
 &process_data($service,\%values); 

 # then respond and we're done!
 $service->Respond();

 sub process_data {
     my ($service, $values) = @_;
     my %values = %$values;
     foreach my $node(keys %values){
         my @values = @{$values{$node}};
         foreach my $value(@values){
             # BUSINESS LOGIC GOES HERE.  This demo just reverses the input
             $value = reverse($value);

             # Add and output triple to the model for that node
             $service->addOutputData(node => $node,
                                     value => $value
                                     );
     }
   }
 }

=cut

=head1 METHODS

=cut


package SADI::Service::Core;
use strict;
use Carp;
use vars qw($AUTOLOAD @ISA);
use RDF::Core::Resource;
use RDF::Core;
use RDF::Core::Model;
use RDF::Core::Storage::Memory;
use RDF::Core::Model::Parser;
use RDF::Core::Model::Serializer;

=head2 new

 $service = SADI::Service::Core->new(%args);
 args:
     ServiceName(string) - required; some single-word name
     ServiceURI(URI) - required; usually the URL of the service, but any unique ID
     ServiceType(URI) - required; the URI of an ontology term
     InputClass(URI) - required; the URI to an OWL ontology term
     OutputClass(URI) - reqruied; the URI to an OWL ontology term
     Description(text) - required; a human-readable description of the service
     Provider(email) - required; an email addresss
     ServicePredicate(URI) - requried; the predicate that the service will add
     URL(URL) - required; the URL to the service endpoint
     Authority(URI) - required; a URI representing the owner of the service
     Authoritative(1|0) - optional; is the service authoritative or not?
     ContentType(string) - optional; what content-type header should we respond with
     UniqueIdentifier(URI) - optional; if you have other ids (e.g. LSID) put here

=cut

=head2  ServiceName

  $name = $service->ServiceName($name)
  get/set the service name

=cut

=head2  ServiceURI

  $URI = $service->ServiceURI($URI)
  get/set the service URI.  This is the "rdf:about" identifier at the root of
  the service rdf:Description.

=cut

=head2  ServiceType

  $type = $service->ServiceType($type)
  get/set the service type

=cut

=head2  InputClass

  $input = $service->InputClass($input)
  get/set the service InputClass URI

=cut

=head2  OutputClass

  $output = $service->OutputClass($output)
  get/set the service OutputClass URI

=cut

=head2  Description

  $text = $service->Description($text)
  get/set the service description as human readable text

=cut

=head2  ServicePredicate

  $predURI = $service->ServicePredicate($URI)
  get/set the URI of the predicate the service will add to the input data

=cut

=head2  URL

  $URL = $service->URL($URL)
  get/set the service URL

=cut

=head2  Authority

  $URI = $service->Authority($URI)
  get/set the service providers unique identifier

=cut

=head2  Authoritative

  $bool = $service->Authooritative([1|0])
  get/set whether or not the service is authoritative

=cut



{

	# Encapsulated:
	# DATA
	#___________________________________________________________
	#ATTRIBUTES
	my %_attr_data =    #     				DEFAULT    	ACCESSIBILITY
	  (
                ServiceName     => [ undef, 'read/write' ],
                ServiceURI     => [ undef, 'read/write' ],
                ServiceType     => [ undef, 'read/write' ],
                InputClass     => [ undef, 'read/write' ],
                OutputClass     => [ undef, 'read/write' ],
                Description     => [ undef, 'read/write' ],
                UniqueIdentifier     => [ undef, 'read/write' ],
                ContentType    => ["text/plain", 'red/write'],
                Provider        => ["anonymous\@sadiframework.org", 'read/write'],
                Format          => ["sadi", 'read/write'],
                URL             => [undef, 'read/write'],
                Authoritative   => ['0', 'read/write'],
                Authority       => [undef, 'read/write'],
                ServicePredicate    => [undef, 'read/write'],
                _model          => [undef, 'read/write'],
                _output_model  => [undef, 'read/write'],
                _default_request_method => ["GET", 'read/write'],
                
		
	  );

	#_____________________________________________________________
	# METHODS, to operate on encapsulated class data
	# Is a specified object attribute accessible in a given mode
	sub _accessible {
		my ( $self, $attr, $mode ) = @_;
		$_attr_data{$attr}[1] =~ /$mode/;
	}

	# Classwide default value for a specified object attribute
	sub _default_for {
		my ( $self, $attr ) = @_;
		$_attr_data{$attr}[0];
	}

	# List of names of all specified object attributes
	sub _standard_keys {
		keys %_attr_data;
	}
}

sub new {
	my ( $caller, %args ) = @_;
	my $caller_is_obj = ref( $caller );
	return $caller if $caller_is_obj;
	my $class = $caller_is_obj || $caller;
	my $self = bless {}, $class;
	foreach my $attrname ( $self->_standard_keys ) {
		if ( exists $args{$attrname} ) {
			$self->{$attrname} = $args{$attrname};
		} elsif ( $caller_is_obj ) {
			$self->{$attrname} = $caller->{$attrname};
		} else {
			$self->{$attrname} = $self->_default_for( $attrname );
		}
	}
        $self->ServiceURI($args{ServiceURI}?$args{ServiceURI}:$args{URL});
        #die "Needs Predicate" unless $self->Predicate();
        die "Needs Input Class" unless $self->InputClass();
        die "Needs Output Class" unless $self->OutputClass();
        die "Needs provider email" unless $self->Provider();
        die "Needs Authority URI" unless $self->Authority();
        die "No Endpoint specified ('URL' init parameter)" unless $self->URL();
        die "No service name specified" unless $self->ServiceName();
        die "No ServiceType specified" unless $self->InputClass();
        die "Needs Description" unless $self->Description();
        
        $self->_prepareOutputModel();
	return $self;
}

=head2 Prepare

  $service->Prepare()

  Prepare the incoming data and make sure it is at least parsible;  this will
  "die" if it is not RDF data coming in.  No arguments.  Returns true if
  the incoming message was parsable, though if it isnt then it'll likely
  crap-out at some point rather than returning false...

=cut


sub Prepare {
    my ($self) = @_;
    my $rdf = join "",<>;
    die unless ($rdf =~ /RDF/);
    my $storage = new RDF::Core::Storage::Memory;
    my $model = new RDF::Core::Model (Storage => $storage);
    my %options = (Model => $model,
                 Source => $rdf,
                 SourceType => 'string',
                 #parserOptions
                 BaseURI => "http://www.foo.com/",
                 BNodePrefix => "genid"
                );
    my $parser = new RDF::Core::Model::Parser(%options);
    $parser->parse;
    $self->_model($model);
    return 1;
}



=head2 getInputNodes

 @nodes = $service->getInputNodes(%args)

 get the input passed to the service

 args:
      type => URI  ;  optional
 returns
      an array of RDF::Core::Resource objects

=cut

sub getInputNodes {
    my ($self, %args) = @_;
    my $predicate = $args{type} || $self->InputClass;
    my $model = $self->_model();
    my $type = RDF::Core::Resource->new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type");
    my $inputtype = RDF::Core::Resource->new($predicate);
    #  we need the inpout types to be "Input" because a client can honestly send us a more complex type that inherits and it wpont be understood without a reasoner
    
    my $yesno = $model->existsStmt(undef, $type, $inputtype);
    return () unless $yesno;
    my $enumerator = $model->getStmts(undef, $type, $inputtype);
    my @subjects;

    my $statement = $enumerator->getFirst;
    while (defined $statement) {
        push @subjects, $statement->getSubject;
        $statement = $enumerator->getNext
    }
    $enumerator->close;
    return @subjects;
}

=head2 getLiteralPropertyValues

  %values = $service->getLiteralPropertyValues(%args)

  get the value for some property of interest (e.g. from input node(s))

  args
      property =>  $URI  :  the URI of the predicate for which you want a value
      nodes =>  @nodes   :  the list of nodes (e.g. from getInputNodes)
  returns
      hash of {$nodeURI => [$val, $val], ...}

=cut

      
sub getLiteralPropertyValues {
    my ($self, %args) = @_;
    my $model = $self->_model;
    my $property = $args{property};
    my $nodes = $args{nodes};
    my @nodes = @$nodes;
    my %valuehash;  # the output  {$node, \@scalars}
    my $desired_property = RDF::Core::Resource->new($property);

    foreach my $subject (@nodes){
        my $iterator = $model->getStmts($subject, $desired_property, undef);
        my $statement = $iterator->getFirst;
        my @values;
        while (defined $statement) {
            my $input_object = $statement->getObject;
            my $value; 
            if (ref($input_object) eq "RDF::Core::Literal"){
                $value = $input_object->getValue;        
                push @values, $value;
            }
            $statement = $iterator->getNext
        }
        $iterator->close;
        $valuehash{$subject->getURI} = \@values;
    }
    return %valuehash;
}

=head2 addOutputData

  $service->addOutputData(%args);

  add an output triple to the model; the predicate of the triple
  is automatically extracted from the ServicePredicate.  Also, the
  node is automatically rdf:typed as the OutputClass

  args
     node => $URI  (the URI of the subject node as a string)
     value => $val  (a string value)
     predicate => $URI (optional - the predicate to put between them.  
                        Defaults to $self->ServicePredicate)

=cut

     
sub addOutputData {
    my ($self, %args) = @_;
    my $outputmodel = $self->_output_model;
    my $nodename = $args{node};
    my $node = RDF::Core::Resource->new($nodename);
    my $value = $args{value};
    my $predicate_sent = $args{predicate};
    my $predicate = $predicate_sent?RDF::Core::Resource->new($predicate_sent):RDF::Core::Resource->new($self->ServicePredicate);
    my $type = RDF::Core::Resource->new($self->OutputClass);
    my $typepredicate = RDF::Core::Resource->new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type");

    my $object = RDF::Core::Literal->new($value);
    my $statement = RDF::Core::Statement->new($node, $predicate, $object);
    my $typestatement = RDF::Core::Statement->new($node, $typepredicate, $type);
    $self->_addToModel(statement => $statement);
    $self->_addToModel(statement => $typestatement);
}


=head2 Respond

  $service->respond();

  send the service response back to the client

=cut


sub Respond {
    my ($self) = @_;
    print "Content-Type: ",$self->ContentType,"; charset=ISO-8859-1;\n\n\n"; 
    print "\n\n";
    print $self->serializeOutputModel();
}


=head2 serializeInputModel

  $xml = $service->serializeInputModel()

  if you want access to the raw RDF-XML for the input data, use this method.
  Returns you a string with the raw XML

=cut


sub serializeInputModel {
    my ($self) = @_;
    my $model = $self->_model;
    my $output;
    my $serializer = new RDF::Core::Model::Serializer(
                                                        Model=>$model,
                                                        Output=>\$output,
#                                                        BaseURI => 'URI://BASE/',
                                                       );
    $serializer->serialize;
    return $output;
}


=head2 serializeOutputModel

  $xml = $service->serializeOutputModel()

  if you want access to the raw RDF-XML for the output data (at any point
  during the construction of the output), use this method.
  Returns you a string with the raw XML

=cut


sub serializeOutputModel {
    my ($self) = @_;
    my $model = $self->_output_model;
    my $output;
    my $serializer = new RDF::Core::Model::Serializer(
                                                        Model=>$model,
                                                        Output=>\$output,
#                                                        BaseURI => 'URI://BASE/',
                                                       );
    $serializer->serialize;
    return $output;
}

=head2 sendInterfaceOnGET

  according to the SADI best-practices, the service URL should return the
  interface document if you call it with GET.  Here we auto-generate that
  document.  This should be the first line in your service after you create the
  $service object.
  
  $service->sendInterfaceOnGET()

=cut


sub sendInterfaceOnGET {
    my ($self) = @_;
    
    my $name = $self->ServiceName();
    my $uri = $self->ServiceURI();
    my $type = $self->ServiceType();
    my $input = $self->InputClass();
    my $output = $self->OutputClass();
    my $desc = $self->Description();
    my $id = $self->UniqueIdentifier() || $self->ServiceURI();
    my $contenttype= $self->ContentType();
    my $email = $self->Provider();
    my $format = $self->Format();
    my $URL = $self->URL();
    my $authoritative = $self->Authoritative();
    my $authority = $self->Authority();
    my $nodeid1 = $authority.$name."aaa";
    my $nodeid2 = $authority.$name."bbb";
    my $nodeid3 = $authority.$name."ccc";
    my $nodeid4 = $authority.$name."ddd";
    my $nodeid5 = $authority.$name."eee";
    my $nodeid6 = $authority.$name."fff";
    my $nodeid7 = $authority.$name."ggg";

    
    my $sadi_interface_signature = qq{<?xml version="1.0" encoding="UTF-8"?>
    <rdf:RDF
     xmlns="http://www.w3.org/2002/07/owl#"
     xmlns:a="http://www.mygrid.org.uk/mygrid-moby-service#"
     xmlns:b="http://protege.stanford.edu/plugins/owl/dc/protege-dc.owl#" 
     xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
     xmlns:owl="http://www.w3.org/2002/07/owl#"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
     xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">    
<rdf:Description rdf:about="$uri">
    <rdf:type rdf:resource="http://www.mygrid.org.uk/mygrid-moby-service#serviceDescription"/>
    <b:format>$format</b:format>
    <b:identifier>$id</b:identifier>
    <a:locationURI>$URL</a:locationURI>
    <a:hasServiceDescriptionText>$desc</a:hasServiceDescriptionText>
    <a:hasServiceDescriptionLocation/>
    <a:hasServiceNameText>$name</a:hasServiceNameText>
    <a:providedBy>
        <rdf:Description rdf:about="$nodeid1">
            <a:authoritative>$authoritative</a:authoritative>
            <b:creator>$email</b:creator>
            <b:publisher>$authority</b:publisher>
            <rdf:type rdf:resource="http://www.mygrid.org.uk/mygrid-moby-service#organisation"/>
        </rdf:Description>
    </a:providedBy>
    <a:hasOperation>
        <rdf:Description rdf:about="$nodeid2">
            <a:hasOperationNameText>$name</a:hasOperationNameText>
            <rdf:type rdf:resource="http://www.mygrid.org.uk/mygrid-moby-service#operation"/>
            <a:performsTask>
                <rdf:Description rdf:about="$nodeid3">
                    <rdf:type rdf:resource="http://www.mygrid.org.uk/mygrid-moby-service#operationTask"/>

                    <rdf:type rdf:resource="http://sadiframework.org/RESOURCES/_______whattoputhere______"/>

                </rdf:Description>
            </a:performsTask>

            <a:inputParameter rdf:resource="$input"/>

            <a:outputParameter rdf:resource="$output"/>
        </rdf:Description>
    </a:hasOperation>
</rdf:Description>
</rdf:RDF>
};

    my $method = $ENV{REQUEST_METHOD} || $self->_default_request_method();
    if ($method eq "GET"){
        print "Content-Type: $contenttype; charset=ISO-8859-1;\n\n";
        print $sadi_interface_signature;
        exit;
    }
    #die unless $ENV{CONTENT_LENGTH} < 20;
}


sub _prepareOutputModel {
    my ($self) = @_;
    my $storage = new RDF::Core::Storage::Memory;
    my $model = new RDF::Core::Model (Storage => $storage);
    my %options = (Model => $model,
                 BNodePrefix => "genid"
                );
    $self->_output_model($model);
}

sub _addToModel {
    my ($self, %args) = @_;
    my $statement = $args{statement};
    my $model = $self->_output_model();
    $model->addStmt($statement);
}

sub AUTOLOAD {
	no strict "refs";
	my ( $self, $newval ) = @_;
	$AUTOLOAD =~ /.*::(\w+)/;
	my $attr = $1;
	if ( $self->_accessible( $attr, 'write' ) ) {
		*{$AUTOLOAD} = sub {
			if ( defined $_[1] ) { $_[0]->{$attr} = $_[1] }
			return $_[0]->{$attr};
		};    ### end of created subroutine
###  this is called first time only
		if ( defined $newval ) {
			$self->{$attr} = $newval;
		}
		return $self->{$attr};
	} elsif ( $self->_accessible( $attr, 'read' ) ) {
		*{$AUTOLOAD} = sub {
			return $_[0]->{$attr};
		};    ### end of created subroutine
		return $self->{$attr};
	}

	# Must have been a mistake then...
	croak "No such method: $AUTOLOAD";
}
sub DESTROY { }
1;