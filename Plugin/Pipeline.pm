package Plugin::Pipeline;
use Moo;
use Function::Parameters;
use Plugin::Pipeline::Pipe;
use v5.10;
use namespace::clean;

has name    => ( is => 'ro', default=>'root' ); ## TODO required.
has plugins => ( is => 'ro', default=>sub{{}} );
has pipes   => ( is => 'ro', default=>sub{{}} );
#has workers => ( is => 'ro', default=>sub{{}} );
has config  => ( is => 'ro', default=>sub{{
      _pipe => { root =>[] },
      _join  => {},
    }} );
has debug => ( is => 'rw', default => 0 );
=comment
* plugins = { "plugin_id" => [ 'type', name, workers, options ]; 
* type : 'module', 'function', 'pipe'
* plugin_id : each "name", ref, ref
* workers = { 'worker_id(or name?)' => [ ref of worker, options ] ... } 
* actions has list of action
* $self->run(); : execute actions
* root -> alias of 'pipe_name'
* TODO : check circular

let's start from 'module' with only an worker.
=cut

=pod
* Interface to register_plugin
%args = (
  plugin => 'name of module',
  use_worker => 'Not Yet',
  load_conf  => 'Not Yet',
);
=cut
method register_plugin(%args){
  unless ( $args{plugin} ){
    ERROR(0,1,qq/"plugin" should be defined as a name of module/);
  }
  $self->_add_plugin( $args{plugin} );
}

#### Add Plugin if it doesn't exists. return Plugin
method _add_plugin ( $name ){
  return $self->plugins->{$name} if $self->plugins->{$name};
  eval "use $name";
  return $self->plugins->{ $name } = { 
    'type' => 'module',   # Always module yet.
    'name' => $name,      # Should Module name
    'conf' => {},
    'worker' => [],       # List of workers. only one yet.
  };
}

#### Add Worker if it doesn't exists. return Worker
method _add_worker ( $plugin, $opts ) {
  my $worker = $plugin->{'worker'}[0]; # Yet only an worker
  unless ( $worker ){
    $worker = [ 
      undef,              # [0] worker object 
      $plugin->{'name'},  # [1] plugin name ( module name )
      undef,              # [2] worker_id. not yet.
      $opts,              # [3] options
    ];
    push @{$plugin->{worker}}, $worker;
  }
  return $worker;
}

=pod
* Interface to join
%args = ( 
  join   => 'name of pipe to join',
  worker => 'name of module. this will be objectify lazily',
             # Doesn't need for simple function
  acton  => 'name of function or function ref',
  desc   => 'dummy yet',
  life   => 'Not Yet',
  args   => 'Not Yet',
  else? # TODO
),
=cut
method join_pipe ( %args ) {
  my $pipe_name = $args{join};
  push @{$self->config->{'_join'}{$pipe_name}},\%args;
}

=pod
* Interface to register pipe;
* 'join' and 'provider' can not be together
%args = (
  pipe => 'name of pipe to register',
  join => 'join this pipe to another',
  provider => 'this pipe will be handled by provilder',
  desc => 'dummy yet',
  unique => 'Not yet',
  parllel => 'Not Yet. Is good idea?',
);
=cut
method register_pipe ( %args ) {
  my $pipe_name = $args{pipe};
  ### Pipe name cannot be 'root' or name of Pipeline
  if( $pipe_name eq 'root' || $pipe_name eq $self->name ){
    ERROR( 0, 1, "Name of pipe cannot be $pipe_name");
  }
  ### If request has 'join', add it to join request also.
  if ( defined $args{join} ) {
    $self->join_pipe( %args );
  }
  ### Add Pipe;
  push @{$self->config->{'_pipe'}{$pipe_name}}, \%args;;
}

=pod
* Get a pipe object by name
=cut
method get_pipe ( $name ){
  return undef if not defined $name;
  return $self->pipes->{$name};
}

=pod
* Compile all registered pipe and join request
* No argument
* TODO: Uniq Pipe?
=cut
method compile () {
  #### Compile pipe registers
  my $pipes = $self->config->{'_pipe'};
  while ( my ($pipe_name,$confs) = each %$pipes ){
    my $pipe = Plugin::Pipeline::Pipe->new( name=>$pipe_name );
    # TODO add providers
    $self->pipes->{$pipe_name} = $pipe;;
    for my $conf ( @$confs ) {
      ### If request had 'provider', 
      ### then prepare lazy sending of pipe to provider;
      my $provider = $conf->{'provider'};
      if ( $provider ){
        my $type = ref $provider;
        if( not $type ) { # Maybe String
          my $plugin = $self->_add_plugin( $provider );
          my %opts = ( 'send_pipe_info' => $pipe );
          my $worker = $self->_add_worker( $plugin,\%opts );
        }
      }
    }
    ### remove request from list since it's done
    delete $pipes->{$pipe_name};
  }

  #### Compile Join Requests
  my $join = $self->config->{'_join'};
  ### For each Pipe
  while ( my ($pipe_name,$confs) = each %$join ){
    ### Weight of actions begins at 10000 steped by 100 
    ### by request order
    ### These numbers are for easy handling of custom weight. 
    ### For example weight=>50 will mean very early action.
    ### and weight=>50000 will mean very late action.
    my $join_number = 10000;
    ### For each request per pipe
    for my $conf ( @$confs ) {
      my $join     = $self->get_pipe($conf->{'join'});
      ### Just Skip without join. TODO: give errors
      next unless $join ;
      ### Handle custom weight or just default.
      my %action_conf = ( 
        'weight' => $conf->{'weight'} || $join_number 
      );
      ### $woker_c is name of module. FIXME: if object?
      my $worker_c = $conf->{'worker'};
      ### if pipe is being joined
      my $pipe     = $self->get_pipe($conf->{'pipe'});
      if( $pipe ){
        $join->_add_action_pipe( $pipe, \%action_conf );
      }elsif ( $worker_c ){
        my $type = ref $worker_c;
        my $plugin = $self->_add_plugin( $type || $worker_c );
        my $worker = $self->_add_worker( $plugin );
        if( $type ) { # Worker MayBe an Object FIXME 
          ### add worker object to worker wraper.
          $worker->[0] = $worker_c; 
        }
        $join->_add_action( $worker, $conf->{'action'},\%action_conf );

      } else { # if worker_conf
        ### Simple Function which doesn't have worker
        $join->_add_action( [], $conf->{'action'},\%action_conf );
      }
      $join_number += 100; # Step 100
    }
  }
}

=pod
* Run Pipeline ( in real, run 'root' pipe )
=cut
method run ($data) {
  $data ||= {};
  $data->{'step'} = 0;
  return $self->pipes->{root}->run($data);
}

fun ERROR ( $level, $code, $msg ){
  say "ERROR: ",$msg;exit $code; # TODO level
}

fun DEBUG ( $level, $code, $msg, $step ){
  $step ||= 0;
  say "\t"x$step,"DEBUG:$code: ",$msg;; # TODO level
}

1;
