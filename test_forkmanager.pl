#!/usr/bin/env perl

use v5.18;
use Time::HiRes 'time';
use Parallel::ForkManager;

  my $pm = new Parallel::ForkManager(4); 
  my @links = 1..10;
  my $btime = time;
  foreach my $link (@links) {
    $pm->start and next; # do the fork
    say ((time-$btime),"\t",$link);
    $pm->finish; # do the exit in the child process
  }
  $pm->wait_all_children;

