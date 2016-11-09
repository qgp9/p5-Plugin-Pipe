#!/usr/bin/env perl

use Time::HiRes;
use Encode;
use open ':std', ':encoding(UTF-8)';
use strict;
use warnings;
use utf8;

#==========================
package Peasis::Base; 
use strict;
use warnings;
use base 'Import::Base';
our @IMPORT_MODULES = (
  'strict', 
  'warnings',
  'feature' => [qw( :5.10 )],
  'Data::Dumper',
  'Function::Parameters',
);
our %IMPORT_BUNDLES = (
  plugin => [ qw/<Moo namespace::autoclean/ ],
);

#==========================
package Peasis::Plugin; 
use Peasis::Base 'plugin';



#==========================
package Peasis::Pipe;
use Peasis::Base 'plugin';
has plugins => ( is => 'rw', default=>sub{{}} );
has pipes   => ( is => 'rw', default=>sub{[undef]} );


method pipe_id ( $plugin_name, $pipe_name ) {
  my $plugin = $self->plugins{$plugin_name};
  return undef unless defined $pid;
  return $pid->{pipes}{$pipe_name};
}

method register_plugin ( $plugin_name ) {
  # TODO handle type;
  unless ( $self->get_plugin( $plugin_name ) ){
    eval "use $plugin";                 #TODO handle exception.
    $self->plugins->{$plugin_name} = $plugin_name->new; # TODO args
  }
}

method get_plugin ( $plugin_name ) {
  return $self->plugins->{$plugin_name};
}

method _get_or_create_plugin ( $plugin_name ) {
  my $plugin = $self->get_plugin( $plugin_name );
  $self->register_plugin($plugin_name) unless $plugin
  $plugin = $self->get_plugin( $plugin_name );
  return $plugin;
}

method _get_pipe ( $name ) {
  my $id = $self->pipe_map->{$name};
  return defined $id ? $self->pipes->[$id] : undef;
}
method _add_pipe ( $name ) {
  push @{$self->pipes}, { name=>$name };
  $self->pipe_map->{$name} = $#{$self->pipes};

}
method _get_or_create_pipe ( $name ){
  my $pipe = $self->_get_pipe($name);
  unless ( $pipe ){

  }
}

method _add_worker ( $name, $worker ){
  $self->workers->{$name} = $worker;  # TODO check dups?
}
method _get_worker ( $name ) {
  return $self->workers->{$name};
}

method _get_or_create_wroker ( $name ){
  my $worker = $self->_get_worker( $name );
  unless ( $worker ) {
    eval qq/use $name;/;  # TODO error handle
    $worker = $name->new; # TODO args
    $self->_add_worker( $name, $worker );
  }
  return $worker;
}

method register_pipe ( %config ) {
  my $pipe_name   = $config{pipe}   or exit 1;
  my $holder_name = $config{holder} or exit 1;
  my $holder  = $self->_get_or_create_plugin($holder_name) ;
  my $pipe    = $self->_get_or_create_pipe($pipe_name, $holder);
  return $pipe;
}


method join {
  my $pipe_name   = $config{pipe}   or exit 1;
  my $worker_name = $config{worker} or exit 1;
  my $action      = $config{action} or exit 1;
  my $pipe        = $self->_get_or_create_pipe  ( $pipe_name );
  my $worker      = $self->_get_or_create_worker( $worker_name );
  $self->_add_action( $pipe, $worker, $action );
}

#==========================
package Peasis::Runner;
use Moo;
use namespace::clean;
has plugins => ( is => 'ro' );

sub run {

}

#==========================
package Peasis::Plugin::Example1;
use Moo;
use namespace::clean;

has pipe => ( is=>'ro' );
has pipe_some1 => (is=>'rw');

sub something1 {
  my ( $self ) = @_;
  $self->pipe_some1->run;
  say "something1 by Example1";
}

#==========================
package Peasis::Plugin::Example2;
use Moo;
use namespace::clean;

has pipe => ( is=>'ro' );
has pipe_some1 => (is=>'rw');

sub register {
  my ( $self, $pipe ) = @_;
  $pipe->register_in('Peasis::Plugin::Example1','do_somethine1', &something1);
}

sub something1 {
  my ($self) = @_;
  say "something1 by Example2";
}


#==========================
package main;
use Data::Dumper;
use strict;
use warnings;

=comment
my $pipe = Peasis::Pipe->new;
$pipe->register_plugin('Peasis::Plugin::Example1')
$pipe->register_plugin('Peasis::Plugin::Example2')
$pipe->run;
=cut

my $pipe2 = Peasis::Pipe->new();
$pipe2->register_pipe (
  pipe   => 'Peasis::Plugin::Example1-do_something1',
  plugin => 'Peasis::Plugin::Example1',
);
$pipe2->join_pipe (
  pipe    => 'root',
  worker  => 'Peasis::Plugin::Example2',
  action  => 'something1',
);
$pipe2->join_pipe( 
  pipe    => 'Peasis::Plugin::Example1-do_something1',
  worker  => 'Peasis::Plugin::Example2',
  action  => 'something1'
);

$pipe2->run;

=comment
my $pipe3 = Peasis::Pipe->new(
  pipes =>[
    {
      pipe   => 'Peasis::Plugin::Example1-do_something1',
      holder => 'Peasis::Plugin::Example1',
    }
  ],
  join => [
    { 
      pipe   => 'root',
      worker => 'Peasis::Plugin::Example2',
      action => 'something1',
    },{
      pipe   => 'Peasis::Plugin::Example1-do_something1',
      worker => 'Peasis::Plugin::Example2',
      action => 'something1'
    },
  ],
);
$pip3->run;



my $pipe4 = Peasis::Pipe->new(
  pipes => [
    {
      pipe   => 'Peasis::Plugin::Example1-do_something1',
      holder => 'Peasis::Plugin::Example1',
    }
  ],
  join => [
    { 
      pipe   => 'root',
      worker => 'Peasis::Plugin::Example2',
      action => 'something1',
    },{
      pipe   => 'Peasis::Plugin::Example1-do_something1',
      worker => 'Peasis::Plugin::Example2',
      action => 'something1'
    },
  ],
);
$pip3->run;
=cut
