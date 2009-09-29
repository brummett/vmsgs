package Vmsgs::CursesInterface::PostNew;

use Curses;
use Vmsgs::CursesInterface::InputWindow;
use Vmsgs::CursesInterface::PromptWindow;
use Vmsgs::Msg;

use strict;

our @ISA = qw ( Vmsgs::CursesInterface::InputWindow );

# Widget for all the steps for posting a new msg

sub new {
my($class,%args) = @_;
  my($self,$window);

  $self = Vmsgs::CursesInterface::InputWindow::new($class, height => 6,
                             width => 46,
                             inputlen => 30,
                             title => "New Message",
                             prompt => "Message Subject");
 
 

  $self->Debug("Creating new PostNew widget $self");

  $self->msgsinterface($args{'msgsinterface'});
  $self->{'editor'} = $args{'editor'};

  $self->start_debug(".vmsgs.debug");

  $self;
} # end new


sub Run {
my($self) = @_;
  my($input);

  $self->msgsinterface->SetArg0Status("posting");

  update_panels();
  doupdate();
  $input = $self->input();
  
  if (! length($input)) {
    my($message, $char);

    $message = "No subject, continue? (Y/N)";
    $self->window->addstr(4,int(length($message)/2), $message);
    update_panels();
    doupdate();

    while ( $char !~ m/y|n/i) {
      $char = getch();  
    }
    if ($char =~ m/n/i) {
      return ("quit",0);
    }
    $input = "(no subject)";
  }

  $self->DoPost($input);

  return ("quit", 0);
} # end PostNew

# Does all the hard work of posting
sub DoPost {
my($self,$subject) = @_;
  my($msg,$filename,$ask,$char);

  $filename="$ENV{'HOME'}/newmsgs.$$";
  
  $msg = new Vmsgs::Msg;
  $msg->header("Subject:", $subject);
  $msg->header("Author", $self->msgsinterface->me);
  $msg->header("Email", $self->msgsinterface->email);
  $msg->header("Date:", scalar(localtime()));
  $msg->header("X-msgs-client:", "vmsgs " . $Vmsgs::VERSION);
  $msg->header("X-posting-host:", $ENV{'HOST'}) if ($self->msgsinterface->server);
  $msg->body("");
  
  $msg->AppendSig();
  $self->Debug("Creating empty msg as file $filename");
  $msg->SaveToFile($filename);
    
  do { 
    $self->Debug(sprintf("Firing up editor %s",
                         $self->{'editor'}));
   
    endwin();                  # restore original tty modes */
    system($self->{'editor'} . " +7 $filename");
    refresh();
    Vmsgs::CursesInterface->set_kb_mode();
  
    $self->Debug(sprintf("Back from the editor return code %d errstring $!",$? >>8));
  
    $ask = new Vmsgs::CursesInterface::PromptWindow(height => 6,
                                                    width => 48,
                                                    title => "Confirm",
                                                    message => "Post this message?",
                                                    noscroll => 1,
                                    choices => [["Send", "S"],["Edit again","E"],["Forget it", "F"],["Dump to /dev/null", "D"]]);
    $char = $ask->input();
    $self->Debug("Read a >>$char<<");
  } while ($char =~ m/e/i);

  if ($char =~ m/s/i) {
    $self->Debug("Posting msg!");
    $msg = new Vmsgs::Msg();
    $msg->LoadFromFile($filename);
    
    $self->msgsinterface->Send($msg);
  }

  unlink($filename) if (-f $filename);
  $self->Debug("Done with DoPost");
} # end DoPost

1;
