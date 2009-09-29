package Vmsgs::TextInterface::Read;

use Vmsgs::Debug;
use Vmsgs::WidgetBase;
use strict;

our @ISA = qw ( Vmsgs::WidgetBase Vmsgs::Debug );

# Implements the read-msg mode of the plain text interface

# Create a new Read widget
sub new {
my($class,%args) = @_;
  my($self);

  $self = {};
  bless $self,$class;

  $self->Debug("Creating new TextInterface::Read widget $self");

  # Initialize the internal state
  $self->msgsinterface($args{'msgsinterface'});
  $self->msgslist($args{'msgslist'});
  $self->state("read");

  $self;
} # end new


# Main entry point for the widget's actions
sub Run {
my($self,%args) = @_;
  my($msg,$char,$command,$msgid);

  $self->msgslist->currentid($args{'msgid'}) if ($args{'msgid'});

  RUN_LOOP:
  while($self->msgslist->currentid <= $self->msgsinterface->lastmsg) { # while there's msgs left to read
    $command = "";
    $self->msgsinterface->currmsg($self->msgslist->currentid);

    $msg = $self->msgslist->get();

    $self->msgsinterface->SetArg0Status("reading " . $msg->id());

    $self->Debug(sprintf("Display info for msg id %d", $msg->id()));

    printf("Message %d (%d more)\nFrom %s %s\nSubject: %s\n(%d lines) More? [Ynrphqbm|] ",
           $msg->id(),
           $self->msgslist->count() - $self->msgslist->currentpos(),
           $msg->header("Author"),
           $msg->header("Date:"),
           $msg->header("Subject:"),
           $msg->header("Content-length:"));
    
    chomp($char = <STDIN>);
    $self->Debug("Read in command char $char");
    print "\n";

    if ($char =~ m/n/i or $char eq "J") {
      $self->Debug("Skipping to next msg");
      $self->msgslist->next();
   
    } elsif ($char =~ m/r/i) {
      $self->Debug("Respond");
      $command = "followup";

    } elsif ($char =~ m/p/i) {
      $self->Debug("Post new");
      $command = "postnew";
    
    } elsif ($char =~ m/\|/) {
      $self->Debug("Pipe command");
      $command = "pipe";
 
    } elsif ($char =~ m/h|\?/i) {
      $self->Debug("Help screen");
      $command = "help";

    } elsif ($char =~ m/q/i) {
      $self->Debug("Quit");
      $command = "quit";

    } elsif ($char =~ m/m/i) {
      $self->Debug("Mark");
      if ($self->msgsinterface->marked($self->msgslist->currentid)) {
        $self->msgsinterface->unmark($self->msgslist->currentid);
      } else {
        $self->msgsinterface->mark($self->msgslist->currentid);
      }

    } elsif ($char =~ m/b\s*(\d*)/i) {
      my $id = $1 || 1;
      $self->Debug("Skipping back $1 msgs");
      while($id--) {
        last unless $self->msgslist->prev();
      } # end while
    
#    } elsif ($char =~ m/k/i) {
#      $self->Debug("Killfile");
#      $command = "killfile";

    } else {
      my($lines,@body);

      $self->Debug("Read body");

      $self->msgsinterface->setread($self->msgslist->currentid());
      $lines = $ENV{'LINES'} || 22;  # Default to 22 lines on the terminal
      $self->Debug("Printing $lines lines");

      @body = split(/^/,$msg->body());
  
      while(@body) {
        print splice(@body,0,$lines);
        if (@body) {
          print "-- More --";
          chomp($char = <STDIN>);
          if ($char =~ m/q/i) {
            last;
          }
        } # end if more than one page of body
      } # end while
      print "----\n";

      # Go to the next msg
      last unless $self->msgslist->next();
    } # end else

    return ($command, $self->msgslist->currentid()) if ($command);

  } # end while msgs left to read

  ("quit", $self->msgslist->currentid());  # If we get here, we've read all the msgs
} # end Run


1;
