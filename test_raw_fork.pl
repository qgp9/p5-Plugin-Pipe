#!/usr/bin/env perl

use v5.18;
use Time::HiRes 'time';


my @links = 1..10;
my $btime = time;
my $nfork = 0;
foreach my $link (@links) {
   my $pid = fork();
   die if not defined $pid;
   if ( $pid ){
     $nfork++;
     if ($nfork > 4){
       wait;
       $nfork--;
     }
   }else{
    sleep 1;
    say ((time-$btime),"\t",$link);
    exit;
   }
}

