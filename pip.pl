#!/usr/bin/env perl

use Time::HiRes;
use Encode;
use open ':std', ':encoding(UTF-8)';
use strict;
use warnings;
use utf8;
use v5.10;
use Data::Dumper;
use base 'lib';


#==========================

#==========================

#==========================
package Plugin::Pipeline::Example1;
use Moo;
use namespace::clean;

has first_pipe => ( is=>'ro' );

sub recieve_pipe_info {
  my ( $self, $pipe_info ) = @_;
  $self->{first_pipe} = $pipe_info->{pipe};
}

sub something1 {
  my ( $self ) = @_;
  say "something1 by Example1";
  $self->first_pipe->run();

}

sub some_function1 {
  say "some_function1 in Example1";
}


#==========================
package Plugin::Pipeline::Example2;
use Moo;
use namespace::clean;

sub something2 {
  my ($self) = @_;
  say "something2 by Example2";
}
sub something3 {
  say "test by Example2 , something3";
}


#==========================
package main;
use Data::Dumper;
use Plugin::Pipeline;
use Plugin::Pipeline::Pipe;
use strict;
use warnings;

$Plugin::Pipeline::Pipe::debug = 2;

#test_simple_method_call();
test_configure();

=pod
 
=cut

sub test_configure2 {
  my $pipe2 = Plugin::Pipeline->new( name=>'my_pipeline' );
  $pipe2->load_config([
      { 
        level1 => [
          {level1_1 => [],}

        ], 
      },
      { 
        level2 => [
        ], 
      },
      { 
        level3 => [] 
      },
      { 
        root => [
          [ sub{ say "root1"} ],
          { level4 => [] }.
        ],
      },
    ]);

  $pipe2->compile;
  $pipe2->run;
}

sub test_configure {
  my $pipe2 = Plugin::Pipeline->new( name=>'my_pipeline' );
  $pipe2->load_config({
      'root' => [{
          worker  => 'Plugin::Pipeline::Example1',
          action  => 'something1',
        },{
          pipe => 'test',
          weight => 50,
        },{
          worker  => 'Plugin::Pipeline::Example1',
          action  => 'something1',
        },
        [ qw/Plugin::Pipeline::Example2 something2/ ],
        \&Plugin::Pipeline::Example1::some_function1,

      ],
      'test' => [{
          worker  => 'Plugin::Pipeline::Example2',
          action  => \&Plugin::Pipeline::Example2::something3,
        },
        sub { say "This is test sub"; },
      ],
      'PIPE::Plugin::Pipeline::Example1' => [{
          provider => 'Plugin::Pipeline::Example1',
        },{
          action => sub{ say 'This is PIPE::Plugin::Pipeline::Example1'},
        },
      ],
    }
  );

  $pipe2->compile;
  $pipe2->run;
}

sub test_simple_method_call {
  my $pipe2 = Plugin::Pipeline->new();
  $pipe2->join_pipe (
    join    => 'root',
    worker  => 'Plugin::Pipeline::Example1',
    action  => 'something1',
    desc    => 'something1 by Example1'
  );
  $pipe2->register_pipe (
    pipe => 'test',
    join => 'root',
    weight => 50,
    desc    => 'test pipe',
    # provider => 'Plugin::Pipeline::Example1',
    # unique => 1
  );
  $pipe2->register_pipe (
    pipe => 'PIPE::Plugin::Pipeline::Example1',
    provider => 'Plugin::Pipeline::Example1',
  );
  $pipe2->join_pipe (
    join => 'PIPE::Plugin::Pipeline::Example1',
    action => sub{ say 'This is PIPE::Plugin::Pipeline::Example1'},
  );
  $pipe2->join_pipe( 
    join    => 'root',
    worker  => 'Plugin::Pipeline::Example2',
    action  => 'something2',
    desc    => 'something2'
  );

  $pipe2->join_pipe( 
    join    => 'test',
    worker  => 'Plugin::Pipeline::Example2',
    #action  => 'something3',
    action  => \&Plugin::Pipeline::Example2::something3,
    desc    => 'something3',
  );

  $pipe2->join_pipe(
    join  => 'root',
    #plugin  => 'Plugin::Pipeline::Example1',
    action  => \&Plugin::Pipeline::Example1::some_function1,
    desc    => 'some_function',
  );

  my $testsub = sub { say "This is test sub"; };

  $pipe2->join_pipe(
    join    => 'test',
    action  => $testsub,
    desc    => 'testsub',
  );

  $pipe2->compile;
  $pipe2->run;
}




=cut
