package Vmsgs::TextInterface;

use Symbol;  # For the Pipe command

use Vmsgs::Msg;
use Vmsgs::Debug;
use Vmsgs::MsgsList;

# All the widgets we'll need
use Vmsgs::TextInterface::Read;
use Vmsgs::TextInterface::Help;
use Vmsgs::TextInterface::PostNew;
use Vmsgs::TextInterface::Followup;


use strict;

our @ISA = qw (Vmsgs::Debug);

our $VERSION = "1.0";


# Implements an interface that looks like the standard msgs interface

sub new {
my($class,$state) = @_;
  my $self = {};
  bless $self,$class;

  $|=1;

  $self->{'state'} = $state;

#  $self->start_debug(".vmsgs.debug");
  $self->Debug("TextInterface::new object is $self");
  $self;
} # end new


# Starts up the msg-reading machine
sub Init {
my($self,$state) = @_;
  my($widget,$msglist,$msgsinterface);

  $msgsinterface = $state->{'msgs'};
  $self->Debug("In TextInterface::Init()");

  if (defined($main::opt_s)) {
    $self->Debug("Posting a new message");

    $widget = new Vmsgs::TextInterface::PostNew(msgsinterface => $msgsinterface,
                                                editor => $state->{'editor'});

  } elsif (defined($main::opt_r)) {
    my $current = $msgsinterface->currmsg() - 1;
    
    $self->Debug("Responding to msg $current");
    $widget = new Vmsgs::TextInterface::Followup(msgsinterface => $msgsinterface,
                                                 editor => $state->{'editor'},
                                                 msgid => $current);

  } elsif ($msgsinterface->currmsg() == $msgsinterface->lastmsg() &&
           $msgsinterface->maxread() == $msgsinterface->currmsg()) {
    print "No new messages.\n";
  } else {
    $self->Debug("No special args, starting reading machine!");
    
    $self->Debug(sprintf("getting ready to read current is %d", $msgsinterface->currmsg));
    $self->{'main_msgslist'} = new Vmsgs::MsgsList(msgsinterface => $msgsinterface,
                                   msgsrules => $state->{'rules'},
                                   msgidlist => [[$msgsinterface->firstmsg() , $msgsinterface->currmsg()-1],
                                                 $msgsinterface->currmsg() .. $msgsinterface->lastmsg()],
                                   current => $msgsinterface->currmsg());
    $self->Debug(sprintf("corrected current is %d",$self->{'main_msgslist'}->currentid()));
    $msgsinterface->currmsg($self->{'main_msgslist'}->currentid());

    $widget = new Vmsgs::TextInterface::Read(msgsinterface => $msgsinterface,
                                             msgslist => $self->{'main_msgslist'});
    $msgsinterface->SetArg0Status("running");

  }

  $|=1;

  $self->MainLoop(topwindow => $widget,
                  msgslist => $msglist,
                  msgsinterface => $state->{'msgs'},
                  editor => $state->{'editor'},
                  rules => $state->{'rules'});
    
  $self->Debug("Leaving TextInterface::Init");
} # end Init


sub MainLoop {
my($self,%args) = @_;
  my($msgsinterface, $topwidget, $msgslist, $msgid, $command, @widgetstack);

  $msgslist = $args{'msgslist'};
  $topwidget = $args{'topwindow'};
  $msgsinterface = $args{'msgsinterface'};
  $self->Debug("Entering new TextInterface::MainLoop");

  MAIN_LOOP:
  while($topwidget) {
    ($command,$msgid) = $topwidget->Run(msgid => $msgid);
    $command = "quit" unless($command);

    $self->Debug("Back from widget::Run returned command $command msgid $msgid");

    if ($command eq "read") {
      push(@widgetstack, $topwidget);
      $topwidget = new Vmsgs::TextInterface::Read(msgsinterface => $msgsinterface,
                                                  msgslist => $msgslist);

    } elsif ($command eq "postnew") {
      push(@widgetstack, $topwidget);
      $topwidget = new Vmsgs::TextInterface::PostNew(msgsinterface => $msgsinterface,
                                                     editor => $args{'editor'});

    } elsif ($command eq "followup") {
      push(@widgetstack,$topwidget);
      $topwidget = new Vmsgs::TextInterface::Followup(msgsinterface => $msgsinterface,
                                                        editor => $args{'editor'},
                                                        msgid => $msgid);

    } elsif ($command eq "help") {
      push(@widgetstack,$topwidget);
      $topwidget = new Vmsgs::TextInterface::Help(mode => $topwidget->state());

    } elsif ($command eq "quit") {
      $topwidget = pop(@widgetstack);

    } elsif ($command eq "QUIT") {
      $topwidget = undef;

    } elsif ($command eq "pipe") {
      $self->Pipe($msgsinterface,$msgid);
    }

  } # end while($topwidget)
  $self->Debug("Leaving TextInterface::MainLoop returning command $command msgid $msgid");

  return ($command,$msgid);
} # end MainLoop 



sub Pipe {
my($self,$msgsinterface,$msgid) = @_;
  my($fh,$command,$msg,$string);

  $fh = gensym();

  print "\nCommand: ";
  chomp($command = <STDIN>);
   
  $fh = gensym();
  if (!open($fh,"|$command")) {
    print "Can't start $command: $!";
    return;
  }

  $msg = $msgsinterface->Get($msgid);
  if ($msg) {
    $string = $msg->Textify();
    $self->Debug("Sending >>$string<< to command >>$command<<");
    print $fh $string;
  } else {
    $self->Debug("Couldn't get info for msgid $msgid");
    print "Can't get info for msg $msgid\n";
  }

  $self->Debug("done with pipe");
  close($fh);
} # end PipeCommand
    



sub Shutdown {
my($self) = @_;

  $self->Debug("Shutting down the text interface");
}
1;
