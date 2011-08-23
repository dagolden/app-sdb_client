#!perl
use 5.010;
use strict;
use warnings;
use autodie;
package App::sdb_client;
# ABSTRACT: Guts of Amazon SimpleDB command-line client
# VERSION

use Data::Stream::Bulk::Callback;
use Data::Dumper;
use Getopt::Lucid ':all';
use Net::Amazon::Config;
use SimpleDB::Client;
use Object::Tiny qw/opt sdb/; 
use Try::Tiny;
use List::AllUtils qw/uniq/;

my $options = [
  Param("profile|p"),
];

sub run {
  my $self = shift;
  $self->{opt} ||= Getopt::Lucid->getopt( $options );
  my $config = Net::Amazon::Config->new;
  my $profile = $config->get_profile( $self->opt->get_profile );
  $self->{sdb} ||= SimpleDB::Client->new(
    secret_key=>$profile->secret_access_key,
    access_key=>$profile->access_key_id,
  );

  my $command = shift @ARGV || "help";
  return try { $self->dispatch($command, @ARGV); 0 }
    catch { warn "$_\n"; 1 };
}

sub dispatch {
  my ($self, $command, @args) = @_;
  (my $method = $command) =~ s{-}{_}g;
  $method = "cmd_$command";
  if ( $self->can($method) ) {
    $self->$method(@args);
  }
  else {
    die "Command '$command' not supported.\n";
  }
}

sub cmd_help {
  require Pod::Usage;
  Pod::Usage::pod2usage();
}

sub cmd_list_domains {
  my ($self, @args) = @_;
  my $bulk = $self->_bulk_request('ListDomainsResult', ['ListDomains']);
  until ( $bulk->is_done ) {
    foreach my $item ( $bulk->items ) {
      $item->{DomainName} = [$item->{DomainName}] unless ref $item->{DomainName};
      say for @{$item->{DomainName}};
    }
  }
}

sub cmd_count_domain {
  my ($self, @args) = @_;
  for my $domain ( uniq @args ) {
    my $count;
    my $bulk = $self->_bulk_request('SelectResult', 
      [ 'Select', {'SelectExpression' => "select count(*) from $domain"} ]
    );
    until ( $bulk->is_done ) {
      foreach my $item ( $bulk->items ) {
        say "$domain $item->{Item}[0]{Attribute}{Value}";
      }
    }
  }
}

sub _bulk_request {
  my ($self, $response_key, $request) = @_;
  return Data::Stream::Bulk::Callback->new(
    callback => sub {
      state ($next_token, $done);
      return if $done;
      my $response = $self->sdb->send_request(
        @$request, ($next_token ? (NextToken => $next_token) : () )
      );
      $next_token = $response->{NextToken};
      if ( $response->{$response_key} ) {
        $done = ! ( defined $next_token && length $next_token );
        return [ $response->{$response_key} ];
      }
      elsif ( $next_token ) {
        # no response yet, but told there is more?
        return $self->get_more;
      }
      else {
        return;
      }
    }
  );
}

1;

__END__

=for Pod::Coverage
dispatch
opt
run
sdb
cmd_help
cmd_list_domains
cmd_count_domain

=head1 SYNOPSIS

  use App::sdb_client;
  my $app = App::sdb_client->new;
  exit $app->run;

=head1 DESCRIPTION

  Guts of the L<sdb-client> program.  No user-serviceable parts inside.

=cut

# vim: ts=2 sts=2 sw=2 et:
