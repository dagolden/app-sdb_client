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
use IO::Interactive qw/is_interactive/;
use SimpleDB::Client;
use Object::Tiny qw/opt sdb/; 
use Try::Tiny;
use List::AllUtils qw/uniq/;

my $options = [
  Param("profile|p"),
  Switch("force|f"),
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
  (my $method = "cmd_$command") =~ s{-}{_}g;
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
      [ 'Select', {'SelectExpression' => "select count(*) from `$domain`"} ]
    );
    until ( $bulk->is_done ) {
      foreach my $item ( $bulk->items ) {
        say "$domain $item->{Item}[0]{Attribute}{Value}";
      }
    }
  }
}

sub cmd_delete_domain {
  my ($self, @domains) = @_;
  for my $domain ( uniq @domains ) {
    if ($self->opt->get_force || $self->_prompt_yn("Are you sure you want to delete $domain?") ) {
      $self->sdb->send_request('DeleteDomain', {DomainName => $domain});
      say "Deleted $domain";
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

sub _prompt {
  my ($self, $message, $default) = @_;
  return $default unless is_interactive();
  local $|=1;
  print "$message [$default]: ";
  my $response = <STDIN>;
  chomp $response;
  return $response;
}

sub _prompt_yn {
  my ($self, $message, $default) = @_;
  $default ||= "no";
  $message .= " (yes/no)";
  return $self->_prompt($message, $default) =~ m{^y(?:es)?$};
}

1;

__END__

=for Pod::Coverage
cmd_count_domain
cmd_delete_domain
cmd_help
cmd_list_domains
dispatch
opt
run
sdb

=head1 SYNOPSIS

  use App::sdb_client;
  my $app = App::sdb_client->new;
  exit $app->run;

=head1 DESCRIPTION

  Guts of the L<sdb-client> program.  No user-serviceable parts inside.

=cut

# vim: ts=2 sts=2 sw=2 et:
