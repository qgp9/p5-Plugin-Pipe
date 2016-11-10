#!/usr/bin/env perl

use Time::HiRes;
use Encode;
use open ':std', ':encoding(UTF-8)';
use strict;
use warnings;
use utf8;
use v5.10;
use Data::Dumper;




#==========================
package Plugin::Pipe;
use Moo;
use Function::Parameters;
use namespace::clean;

has plugins => ( is => 'ro', default=>sub{{}} );
has actions => ( is => 'ro', default=>sub{[]} );
has config  => ( is => 'ro', default=>sub{{}} );
has pipes   => ( is => 'ro', default=>sub{{}} );
=comment
* plugins = { "plugin_id" => [ 'type', name, workers, options ]; 
* type : 'module', 'function', 'pipe'
* plugin_id : each "name", ref, ref
* workers = { 'worker_id(or name?)' => [ ref of worker, options ] ... } 
* actions has list of action
* $self->run(); : execute actions
* root -> alias of 'pipe_name'

let's start from 'module' with only an worker.
=cut

method _add_plugin ( $name ){
  eval "use $name";
  return $self->plugins->{ $name } = [
    'module',$name,{} 
  ];
}

method _add_worker ( $plugin ) {
  my $worker = $plugin->[1]->new;
  $plugin->[2]->{$worker} = [ $worker ]; 
  return $worker;
}

method _add_action( $plugin, $worker, $action ){
  say $worker, $action;
  my $action_org = $action;
  if ( ref $action || ref $action ne 'CODE' ){
    #eval "use $plugin->[1]";
    $action = eval "\\&$plugin->[1]::$action";
  }
  push @{$self->actions}, [ $worker, $action,{
      action_org=>$action_org,
    }];
}

method join_pipe ( %args ) {
  my $pipe_name = $args{pipe};
  if( $pipe_name eq 'root' || $pipe_name eq $self->name ){
    my $plugin = $self->_add_plugin( $args{worker} );
    my $worker = $self->_add_worker( $plugin );
    $self->_add_action( $plugin, $worker, $args{action} );
  }else{
    push @{$self->config->{building}{join}{$pipe_name}},\%args;
  }
}

method register_pipe ( %args ) {
  my $pipe_name = $args{pipe};
  if( not exists $args{holder} ){
    my $pipe = Plugin::Pipe->new( name=> $pipe_name );
    if( $self->pipes->{$pipe_name} ){
      say "ERROR: $pipe_name is already exists.";
      exit 1;
    }
    $self->pipes->{$pipe_name} = \%args;
  }
}
method compile {
  my $pipes = $self->config->{'building'}{'pipe'};
  for my $pipe_conf ( keys %$pipes ){
    my $pipe_name = $pipe_conf->{'pipe'};
  }
}

method run {
  my $i=0;
  for my $action ( @{ $self->actions } ){
    my $sub = $action->[1];
    $action->[0]->$sub();
  }
}


#==========================
package Plugin::Pipe::Example1;
use Moo;
use namespace::clean;

sub something1 {
  my ( $self ) = @_;
  say "something1 by Example1";
}

#==========================
package Plugin::Pipe::Example2;
use Moo;
use namespace::clean;

sub something2 {
  my ($self) = @_;
  say "something1 by Example2";
}
sub something3 {
  say "test by Example2";
}


#==========================
package main;
use Data::Dumper;
use strict;
use warnings;

=comment
my $pipe = Plugin::Pipe->new;
$pipe->register_plugin('Plugin::Pipe::Example1')
$pipe->register_plugin('Plugin::Pipe::Example2')
$pipe->run;
=cut

my $pipe2 = Plugin::Pipe->new();
$pipe2->register_pipe (
  pipe => 'test',
  join => 'root',
  # unique => 1
);
$pipe2->join_pipe (
  join    => 'root',
  worker  => 'Plugin::Pipe::Example1',
  action  => 'something1',
);
$pipe2->join_pipe( 
  join    => 'root',
  worker  => 'Plugin::Pipe::Example2',
  action  => 'something2'
);

$pipe2->join_pipe( 
  join    => 'test',
  worker  => 'Plugin::Pipe::Example2',
  action  => 'something3'
);

$pipe2->run;

=comment
my $pipe3 = Peasis::Pipe->new(
  pipes =>[
    {
      pipe   => 'Plugin::Pipe::Example1-do_something1',
      holder => 'Plugin::Pipe::Example1',
    }
  ],
  join => [
    { 
      pipe   => 'root',
      worker => 'Plugin::Pipe::Example2',
      action => 'something1',
    },{
      pipe   => 'Plugin::Pipe::Example1-do_something1',
      worker => 'Plugin::Pipe::Example2',
      action => 'something1'
    },
  ],
);
$pip3->run;



my $pipe4 = Peasis::Pipe->new(
  pipes => [
    {
      pipe   => 'Plugin::Pipe::Example1-do_something1',
      holder => 'Plugin::Pipe::Example1',
    }
  ],
  join => [
    { 
      pipe   => 'root',
      worker => 'Plugin::Pipe::Example2',
      action => 'something1',
    },{
      pipe   => 'Plugin::Pipe::Example1-do_something1',
      worker => 'Plugin::Pipe::Example2',
      action => 'something1'
    },
  ],
);
$pip3->run;
=cut
