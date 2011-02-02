#-----------------------------------------------------------------
# Service name: getEcEncodedByKeggGenes
# Authority:    dev.biordf.net
# Created:      14-Jun-2010 11:38:30 PDT
# Contact:      edward.kawas+sadiservices@gmail.com
# Description:  
#               Fetches the enzymes that the input KEGG genes encode (if they exist).
#-----------------------------------------------------------------

package Service::getEcEncodedByKeggGenes;

use FindBin qw( $Bin );
use lib $Bin;

#-----------------------------------------------------------------
# This is a mandatory section - but you can still choose one of
# the two options (keep one and commented out the other):
#-----------------------------------------------------------------
use SADI::Base;
# --- (1) this option loads dynamically everything
BEGIN {
    use SADI::Generators::GenServices;
    new SADI::Generators::GenServices->async_load(
	 service_names => ['getEcEncodedByKeggGenes']);
}

# (this to stay here with any of the options above)
use vars qw( @ISA );
@ISA = qw( net::biordf::dev::getEcEncodedByKeggGenesBase );
use strict;

# add vocabulary use statements
use SADI::RDF::Predicates::DC_PROTEGE;
use SADI::RDF::Predicates::FETA;
use SADI::RDF::Predicates::OMG_LSID;
use SADI::RDF::Predicates::OWL;
use SADI::RDF::Predicates::RDF;
use SADI::RDF::Predicates::RDFS;
use Implementations;

sub process_it {
    my ($self, $values, $core) = @_;
    # empty data, then return
    return unless $values;

    my @inputs = @$values;
    # iterate over each input
    foreach my $input (@inputs) {
    	use SADI::Utils;
        my $accession = SADI::Utils->unLSRNize($input, $core);
        unless ($accession) {
            $accession = $input->getURI;
            # get just the id number
            $accession = "$1:$2" if $accession =~ m/KEGG\:([a-z]+)[:](.*)/gi;
        }
        my $class = Implementations::getEcEncodedByKeggGenes($input, $accession, $LOG);
        $core->addOutputData(
                node => $class,
        );
    }
}

1;
__END__

=head1 NAME

Service::getEcEncodedByKeggGenes - a SADI service

=head1 SYNOPSIS

 # the only thing that you need to do is provide your
 # business logic in process_it()!
 #
 # This method consumes an array reference of input data
 # (RDF::Core::Resource),$values, and a reference to 
 # a SADI::RDF::Core object, $core.
 #
 # Basically, iterate over the the inputs, do your thing
 # and then $core->addOutputData().
 #
 # Since this is an asynchronous implementation of a SADI
 # web service, I am assuming that your task takes a while
 # to run. So to save what you have so far, do store($core).
 # 

=head1 DESCRIPTION

Fetches the enzymes that the input KEGG genes encode (if they exist).

=head1 CONTACT

B<Authority>: dev.biordf.net

B<Email>: edward.kawas+sadiservices@gmail.com

=cut