package Vmsgs::CursesInterface::Followup;
 
# Widget for handling a followup (reply)

use Curses;
use Vmsgs::CursesInterface::InputWindow;
use Vmsgs::Msg;

use strict;

our @ISA = qw ( Vmsgs::CursesInterface::InputWindow );

# Widget for all the steps for posting a new msg

sub new {
my($class,%args) = @_;
  my($self,$window);

  $self = bless {},$class;

  $self->start_debug(".vmsgs.debug");
  $self->Debug("Creating new Followup widget $self editor is " . $args{'editor'});

  $self->msgsinterface($args{'msgsinterface'});
  $self->{'editor'} = $args{'editor'};
  $self->{'msgid'} = $args{'msgid'};

  $self;
} # end new


sub Run {
my($self) = @_;
  my($oldmsg,$msg,$subject,$filename,$ask,$char,@body,$numlines);

  $self->msgsinterface->SetArg0Status("replying to " . $self->{'msgid'});

  $filename="$ENV{'HOME'}/newmsgs.$$";

  $oldmsg = $self->msgsinterface->Get($self->{'msgid'});
  $subject = $oldmsg->header("Subject:");
  if ($subject =~ m/^Re\:(.*)/) {
    $subject="Re[2]:$1";
  } elsif ($subject =~ m/^Re\[(\d+)\]\:(.*)/) {
    $subject="Re[". ($1 + 1) ."]:$2";
  } else {
    $subject = "Re: $subject";
  }
  
  $msg = new Vmsgs::Msg;
  $msg->header("Subject:", $subject);
  $msg->header("Author", $self->msgsinterface->me);
  $msg->header("Email", $self->msgsinterface->email);
  $msg->header("Date:", scalar(localtime()));
  $msg->header("X-msgs-client:", "vmsgs " . $main::VERSION);
  $msg->header("X-posting-host:", $ENV{'HOST'}) if ($self->msgsinterface->server);
  $msg->header("Followup-to:",$self->{'msgid'});

  push(@body,$oldmsg->header("Author") . " said:");
  foreach ( $oldmsg->body() ) {
    push(@body, "\> $_");
    $numlines++;
  }
  push(@body,"");  # make a blank line at the bottom
  $numlines += 10;  # Skip past all the headers, too
  $msg->body(\@body);
  $msg->AppendSig();
  $msg->SaveToFile($filename);
  
  $self->Debug(sprintf("Firing up editor %s starting at line $numlines",
                       $self->{'editor'}));
 
  def_prog_mode();           # save current tty modes */
  endwin();                  # restore original tty modes */
  system($self->{'editor'} . " +$numlines $filename");
  curs_set(0);

  $self->Debug(sprintf("Back from the editor return code %d errstring $!",$? >>8));

  $ask = new Vmsgs::CursesInterface::PromptWindow(width => 38,
                                                  height => 6,
                                                  title => "Confirm",
                                                  message => "Post this message?",
                                  choices => [["Send", "S"],["Forget it", "F"],["Dump to /dev/null", "D"]]);
  $char = $ask->input();

  $self->Debug("Read a >>$char<<");
  if ($char =~ m/s/i) {
    $self->Debug("Posting msg!");
    $msg = new Vmsgs::Msg();
    $msg->LoadFromFile($filename);
    
    $self->msgsinterface->Send($msg);
  }

  unlink($filename) if (-f $filename);
  $self->Debug("Done with Followup::Run");

  ("quit",$self->{'msgid'});
} # end Run

1;
