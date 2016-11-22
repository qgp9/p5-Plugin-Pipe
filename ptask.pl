#!/usr/bin/env perl

sub task;
sub sh;

task prod => sub {
  $level = 'JEKYLL_ENV=production';
};

task dev  => sub {
  $level = 'JEKYLL_ENV=development';
};

task thumbs => sub {
  sh './bin/gen_thumbs.sh'
};

task build_draft => 'thumbs', sub {
  sh qq|$level $build --future|;
};

task build => thumbs => sub {

};

task prod_build => build => thumbs => sub{ 
  desc "설명";
  sh   'echo TEST';
}; 

task publish => 'check_branch_pages prod_build push_github';


my %tasks;
my $com = shift @ARGV;
if ( exists $tasks{$com} ){
  execute_task($com);
}

sub task{my$n=shift;
  for( @_ ){

  }
  @{$tasks{$_}}=map { split /\s+/,$_ } @_;

  sub execute_task {
    my $com = shift;
    my $ref = ref $com;
    return $ref->() if $ref eq 'CODE';
    return 1        if $com eq '1';
    my $task = $tasks{$com};
    for( @$task ){
      execute_task($_) or die $!;
    }
  }
