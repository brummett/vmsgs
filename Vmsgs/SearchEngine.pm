package Vmsgs::SearchEngine;

use IO::Pipe;

# The back-end for the search engine
#
# Forks off a process to do the actual searching.  comms are via a 
# socket FH

sub new {
my($class,$query) = @_;

  my $pipe = IO::Pipe->new();

  my $pid;
  if ($pid = fork()) {
    # Parent... the msgs reader
    
