package Plugin::Pipeline::Pipe;
use Moo;
use v5.10;
use Function::Parameters;
use namespace::clean;

has name       => ( is => 'ro' );
has actions    => ( is => 'ro', default => sub{[]} );
has providers  => ( is => 'ro', default => sub{{}} ); # TODO
has is_ordered => ( is => 'ro', default => undef   );

my $debug = 0;

## worker_item : [ worker_obj, plugin, worker_id, opts ]
## action_item : [ action, worker, compiled, is_pipe, opts ]
method _add_action( $worker, $action, $opts ){
  #$opts->{'action_org'} = $action; # Backup
  #### Convert a string Action to CODE
  if ( ref $action ne 'CODE' ){
    $action = "$worker->[1]::$action" if $worker->[1]; # plugin
    $action = eval "\\&$action";
  }
  #### Now Action should be CODE
  if ( ref $action ne 'CODE' ){
    ERROR( 0, 1, "Action is not a function." );
  };
  #### Add Action
  push @{$self->actions}, [ 
    $action,  # [0] acion       / CODE
    $worker,  # [1] worker      / array ref
    undef,    # [2] is compiled / bool
    undef,    # [3] is pipe     / bool 
    $opts,    # [4] options     / hash ref
  ];
}

#### Add Pipe Action
method _add_action_pipe ( $pipe, $opts ){
  push @{$self->actions}, [
    sub{ $pipe->run(@_) }, # [0] action
    $pipe,                 # [1] worker / pipe obj
    1,                     # [2] is compiled 
    1,                     # [3] is pipe
    $opts,                 # [4] option
  ];
}

#### Run Pipe. $data is a brief case while piping
#### TODO: fix $data structure
method run( $data ) {
  $data->{step}++;
  DEBUG( 1, 'P1', qq/Start Pipe "/.$self->name.qq/"/, $data );
  #### Order actions by weight in the beging
  unless( $self->is_ordered ){
    @{$self->actions} = sort { 
      $a->[4]{weight} <=> $b->[4]{weight} 
    } @{$self->actions};
    $self->{'is_ordered'} = 1;
  }
  #### Loop over Actions
  $data->{pipe} = $self;
  for my $action ( @{$self->actions} ) {
    $self->_action( $action, $data );
  }

  DEBUG( 1, 'P2', "End Of Pipe ".$self->name, $data );
  $data->{step}--;
  return $data;
}

#### Call Each Action
method _action( $action, $data ){
  # [0]    -> action
  # [1][0] -> worker_obj
  # [1][1] -> plugin
  # [1][2] -> worker_id
  # [1][3] -> worker opts
  # [2]    -> compiled
  #### Compile Action in the begining
  unless ( $action->[2] ){ # plugin
    unless ( $action->[1][0] ){ # worker
      if ( $action->[1][1] ){   # plugin
        #### Create Worker Object
        $action->[1][0] = $action->[1][1]->new;
        #### Send Pipe information to provider if needed
        my $pipe= $action->[1][3]{'send_pipe_info'};
        if( $pipe ){
          $action->[1][0]->recieve_pipe_info({pipe=>$pipe});
        }
        #### Compile Action
        my $tmp_action = $action->[0];
        $action->[0] = sub{$tmp_action->($action->[1][0],@_)};
      }
    }
    $action->[2] = 1; # Set "Is Compiled"
  }
  #### CALL Action with $data
  return $action->[0]->($data);
}

fun ERROR ( $level, $code, $msg ){
  say "ERROR: ",$msg;exit $code; # TODO level
}

fun DEBUG ( $level, $code, $msg, $opts ){
  return if $level < $debug;
  my $step = $opts->{'step'} || 0;
  say "#---"x$step,"DEBUG:$code: ",$msg;; # TODO level
}

1;
