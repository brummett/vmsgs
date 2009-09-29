package Vmsgs::CursesInterface::MailReply;
 
# Widget for handling a reply via email

use Curses;
use Vmsgs::CursesInterface::InputWindow;
use Vmsgs::Msg;
use IO::File;

use strict;

our @ISA = qw ( Vmsgs::CursesInterface::InputWindow );

# Widget for all the steps for posting a new msg

sub new {
my($class,%args) = @_;
  my($self,$window);

  $self = bless {},$class;

#  $self->start_debug(".vmsgs.debug");
  $self->Debug("Creating new MailReply widget $self");

  $self->msgsinterface($args{'msgsinterface'});
  $self->{'editor'} = $args{'editor'};
  $self->{'msgid'} = $args{'msgid'};

  $self;
} # end new


sub Run {
my($self) = @_;
  my($oldmsg,$msg,$subject,$filename,$ask,$char,@body,$numlines,$fh);

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
  
  push(@body,"you wrote in msgs:\n");
  foreach ( $oldmsg->body() ) {
    push(@body, "\> $_");
    $numlines++;
  }
  push(@body,"\n\n");  # make a blank line at the bottom
  $numlines += 3;  

  # Save the text into a file that can be edited
  if (! ($fh = new IO::File(">$filename"))) {
    $self->Debug("Can't create $filename: $!");
    $self->ErrorBox($filename,$!);
  } else {
  
    foreach ( @body ) {
      print $fh $_;
    }
    close($fh);

    $self->Debug(sprintf("Firing up editor %s starting at line $numlines",
                         $self->{'editor'}));
   
    endwin();                  # restore original tty modes */
    system($self->{'editor'} . " +$numlines $filename");
    refresh();
    Vmsgs::CursesInterface->set_kb_mode();
  
    $self->Debug(sprintf("Back from the editor return code %d errstring $!",$? >>8));
  
    $ask = new Vmsgs::CursesInterface::PromptWindow(width => 38,
                                                    height => 6,
                                                    title => "Confirm",
                                                    message => "Mail this message?",
                                    choices => [["Send", "S"],["Forget it", "F"],["Dump to /dev/null", "D"]]);
    $char = $ask->input();
  
    if ($char eq "s") {
      $self->Debug("Sending mail!");
     
      if (! ($fh = new IO::File($filename))) {
        $self->Debug("Can't open $filename: $!");
        &ErrorBox($filename,$!);
      } else {
        my($retval, $author);
        $author = $oldmsg->header("Author");
        $self->Debug("Sending mail to $author");
        $retval = system("mail -s \"$subject\" $author < $filename");
        $retval = $retval >> 8;
        $self->Debug("Back from mail got return code $retval");
      }
    }
  
    unlink($filename) if (-f $filename);
  }

  $self->Debug("Done with MailReply::Run");
  ("quit",$self->{'msgid'});
} # end Run


sub ErrorBox {
my($self,$filename,$msg) = @_;
  my($prompt,$width);

  $prompt = "Can't open temporary file $filename:\n\n";
  $width = length($prompt) > length($msg) ? length($prompt) : length($msg);

  my $win = new Vmsgs::CursesInterface::PromptWindow(width => $width+6,
                                                     height => 6,
                                                     title => "Error",
                                                     message => $prompt . $msg);
  $win->input();
} #end ErrorBox


1;
