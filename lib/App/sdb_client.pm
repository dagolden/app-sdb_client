#!perl
use 5.010;
use strict;
use warnings;
use autodie;
package App::sdb_client;
# ABSTRACT: Guts of Amazon SimpleDB command-line client
# VERSION

use Net::Amazon::Config;
use SimpleDB::Client;

# XXX fix all this boilerplate
#
#my $sdb = SimpleDB::Client->new(secret_key=>'abc', access_key=>'123');
#
## create a domain
#my $hashref = $sdb->send_request('CreateDomain', {DomainName => 'my_things'});
#
## insert attributes
#my $hashref = $sdb->send_request('PutAttributes', {
#    DomainName             => 'my_things',
#    ItemName               => 'car',
#    'Attribute.1.Name'     => 'color',
#    'Attribute.1.Value'    => 'red',
#    'Attribute.1.Replace'  => 'true',
#});
#
## get attributes
#my $hashref = $sdb->send_request('GetAttributes', {
#    DomainName             => 'my_things',
#    ItemName               => 'car',
#});
#
## search attributes
#my $hashref = $sdb->send_request('Select', {
#    SelectExpression       => q{select * from my_things where color = 'red'},

1;

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

# vim: ts=2 sts=2 sw=2 et:
