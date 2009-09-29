package Vmsgs::CursesInterface::Read;

use Curses;
use Vmsgs::WidgetBase;
use Vmsgs::CursesInterface::ScrollableWindow;
use Vmsgs::Debug;
use strict;

our @ISA = qw (Vmsgs::CursesInterface::ScrollableWindow Vmsgs::WidgetBase Vmsgs::Debug);

our $DEBUG = 0;

# Implements the widget to read msgs with

# Create a new Read widget
sub new {
my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  $self->start_debug(".vmsgs.debug");
  $self->Debug("Creating new Read widget $self");

  # Initialize the internal state
  my %args = @_;
  $self->msgsinterface($args{'msgsinterface'});
  $self->msgslist($args{'msgslist'});
  $self->state("read");

  # Create the titlebar
  my $win = new Curses(1,0,0,0);
  if (!$win) {
    $self->Debug("Can't create titlebar: $!");
    return undef;
  }
  $win->attron(A_REVERSE);
  $win->scrollok(0);
  $self->titlebar($win);
  $self->titlepanel($win->new_panel());
  $self->DrawTitlebar();
 
  # Create the bottombar
  $win = new Curses(1,0,getmaxy()-1,0);
  if (!$win) {
    $self->Debug("Can't create bottombar: $!");
    return undef;
  }
  $win->attron(A_REVERSE);
  $win->scrollok(0);
  $self->bottombar($win);
  $self->bottompanel($win->new_panel());
  $self->DrawBottombar();
 
  # Create the main panel
  $win = new Curses(getmaxy()-2,0,1,0);
  if (!$win) {
    $self->Debug("Can't create main select window: $!");
    return undef;
  }
  $self->width(getmaxx());
  $self->height(getmaxy()-2);
  $win->scrollok(0);
  $self->window($win);
  $self->panel($win->new_panel());
  $self->currentline(0);

  $self->reset();
  $self->Draw();
  
  $self;
} # end new


# Clears out the strings cache and resets the current line
# Should be called between reading each msg
sub reset {
my($self) = @_;

  $self->Debug("resetting read widget");

  $self->currentline(0);
  $self->msgsinterface->setread($self->msgslist->currentid());
  my $msg = $self->msgslist->get();
  my $string = $self->{'showheaders'} ? $msg->Textify() : $msg->body();
  $self->StoreLines($string);
} # end reset


# Draw the main window from scratch.  The current line goes at the top of the window
sub Draw {
my($self) = @_;
  my($msg,$string,$strings,$currentline,$screenline);

  return if ($self->{'timeout'});  # kludge to avoid paging ahead after a getch timeout

  $self->msgsinterface->SetArg0Status("reading " . $self->msgslist->currentid());

  return $self->SUPER::Draw();

#  $self->Debug("Drawing read window $self from scratch");
#
#  $self->window->clear();
#  $self->window->move(0,0);
#
#  $strings = $self->Lines();
#
#  $currentline = $self->currentline();
#  $screenline = 1;
#  $msg = $self->msgslist->get();
#
#  $self->Debug(sprintf("Ready to draw the msg currentline $currentline %d total lines",scalar(@$strings)));
#
#  while($screenline <= $self->window->getmaxy()) {
#    # last if ($currentline > $msg->header("Content-length:"));
#    last if ($currentline > scalar(@$strings));
#
#    $self->Debug("Drawing line of a msg screenline $screenline currentline $currentline");
#
#    $self->window->addstr($strings->[$currentline]);
#    # Make sure there's a newline at the end
#    $self->window->addstr("\n") unless ($strings->[$currentline] =~ m/\n$/);  
#
#    # This handles the case where the line was wider than the terminal
#    # width, so should count as 2 (or more) lines
#    $screenline += (int(length($strings->[$currentline]) / $self->window->getmaxx) + 1);
#    $currentline++;
#  } # end while
#
#  # decrement it because during the last trip through the above
#  # while() loop, it really shouldn't have incremented it
#  # maybe that while() above should be a for() instead...
#  $currentline--;
#
#  $self->Debug("Done drawing, currentline is $currentline");
#  $self->ShowScrollbars();
#  $self->currentline($currentline);
} # end Draw


# Called by the navigation functions to advance to retreat the current msg
# pointer.  $direction is 1 to advance, -1 to retreat
sub NextMsg {
my($self,$direction) = @_;

  if ($direction > 0 ) {  # Advance
    $self->Debug("Advancing to the next msg");
    if (! $self->msgslist->next()) {  # undef if this was the last msg
      $self->Debug("Last msg, returning undef");
      return undef;
    }
  } elsif ($direction < 0) {  # retreat
    $self->Debug("Advancing to the prev msg");
    if (! $self->msgslist->prev()) { # undef if this was the first msg
      $self->Debug("First msg, returning undef");
      return undef;
    }
  }

  $self->msgsinterface->currmsg($self->msgslist->currentid);
  $self->reset();
  1;
} # end NextMsg
  

# Called when the user presses J, ENTER or KEY_DOWN to show one more line of the msg
sub LineDown {
my($self,$ok_to_next) = @_;

#  my $strings = $self->Lines();
    
  return 1 if $self->SUPER::LineDown();

  return 1 unless ($ok_to_next);  
  if ($self->NextMsg(1)) {
    $self->Draw;
    return 1;
  } else {
    return undef;
  }
  
} # end LineDown


# Called when the user presses SPACE or KEY_NPAGE
sub PageDown {
my($self) = @_;

  if ($self->SUPER::PageDown()) {
    return 1;
  } else {
    if ($self->NextMsg(1)) {
      $self->Draw();
      return 1;
    } else {
      return undef;
    }
  }

} # end PageDown


# Called when the user pressees K or KEY_UP to back up one line of the msg
sub LineUp {
my($self,$ok_to_next) = @_;
 
  return 1 if $self->SUPER::LineUp();

  return 1 unless ($ok_to_next);
  if ($self->NextMsg(-1)) {
    $self->Draw();
    return 1;
  } else {
    return undef;
  }

} # end LineUp


# Called when the user presses KEY_BACKSPACE or KEY_PPAGE
sub PageUp {
my($self) = @_;
  if ($self->SUPER::PageUp()) {
    return 1;
  } else {
    if ($self->NextMsg(-1)) {
      $self->Draw();
      return 1;
    } else {
      return 0;
    }
  }

} # end PageUp

sub DrawTitlebar {
my($self) = @_;
  my($winhandle,$msg,$datestr);
 
  return if ($self->{'timeout'});  # Don't redraw after a getch timeout

  $msg = $self->msgslist->get();

  # The date is stored in the msg as "dayname monthname date timestring year"
  $msg->header("Date:") =~ m/\w+\s+(\w+)\s+(\d+)\s+(\d+\:\d+)\:\d+\s+(\d+)/;
  # We'll print it out as "date monthname year timestring"
  $datestr = "$2 $1 $4 $3";
  
  $winhandle = $self->titlebar();
  $winhandle->clear();
  $winhandle->move(0,0);

  $winhandle->addstr(sprintf("%-50s %20s",
                             $msg->header("Author") . ": " . $msg->header("Subject:"),
                             $datestr));
} # end DrawTitlebar
 

sub DrawBottombar {
my($self) = @_;
  my($winhandle);

  $winhandle = $self->bottombar();
  $winhandle->clear();
  $winhandle->move(0,0);

  # time at col 4
  # msgid at col 13
  # more msgs at col 23
  # printed percent at col 45
  $winhandle->addstr(sprintf("-- %5s -- %6s -- %8s -- help:? -- %3s --","","","",""));
  $self->UpdateBottombar();
} # end DrawBottombar


sub UpdateBottombar {
my($self) = @_;
  my($winhandle,$msg,$morestr,$percent);

  $msg = $self->msgslist->get();

  $morestr = $self->msgslist->count() - $self->msgslist->currentpos - 1;
  if ($morestr <= 0) {
    $morestr = "LAST";
  } else {
    $morestr .= " MORE";
  }

  if ($msg->header("Content-length:")) {
    $percent = $self->currentline / $msg->header("Content-length:");
  } else {
    $percent = 1;
  }
  $self->Debug(sprintf("Updating Bottombar msgid %d more string %s percent %4f",
                       $msg->id(), $morestr, $percent));

  $percent = $self->_Percentage($percent);

  $winhandle = $self->bottombar();
  $winhandle->addstr(0,3,sprintf("%5s",$self->_PrintTime()));
  $winhandle->addstr(0,12,sprintf("%6s", $msg->id()));
  if ($self->msgsinterface->marked($msg->id())) {
    $winhandle->addch("+");
  }
  $winhandle->addstr(0,22,sprintf("%8s",$morestr));
  $winhandle->addstr(0,44,sprintf("%3s",$percent));
} # end UpdateBottombar


## Used to cache array-ified body of msgs so we don't have to split() the
## body every time returns ref to the whole array
#sub CacheStrings {
#my($self) = @_;
#
#  if ($self->LineCount()) {
#    $self->Lines
#    my($msg,$string);
# 
#    $self->msgsinterface->setread($self->msgslist->currentid());
#
#    $msg = $self->msgslist->get();
#    $string = $self->{'showheaders'} ? $msg->Textify() : $msg->body();
#    $self->Lines($string);
#  } else {
#
#  $self->{'bodycache'};
#}


# Does the user input loop until something interesting is selected, or the timer runs out
# Args are:
#    msgid - position the current msg pointer at this msg, default is to use $self->msgslist->currentid()
# Returns a 2-element list: (command, msgid)
#    where command can be "followup", "postnew", "mailreply", "savemsg", "timeout", "quit", "help"
# Basicly, anything that the select widget can't do itself
sub Run {
my($self,%args) = @_;
  my($char,$command,$msgid);

  return ("quit", undef) if ($self->{'quitflag'});

  if ($args{'msgid'} && $args{'msgid'} != $self->msgslist->currentid()) {
    $self->Debug("Updating the current msg pointer to ".$args{'msgid'});
    if ($self->msgslist->setcurrentid($args{'msgid'})) {
      $self->Draw();
    }
  }
 
  $self->msgsinterface->unmark_all() unless ($self->{'timeout'});
 
  READ_A_KEY:
  while(! $command) {

    # Update the screen
    if (! $self->{'timeout'}) {
#      $self->ShowScrollbars();
      $self->DrawTitlebar();
      $self->DrawBottombar();
      update_panels();
      doupdate();
    }
 
    $self->{'timeout'} = 0;
    $self->{'quitflag'} = 0;
    $char = getch();
    $self->Debug("Got user's input >>$char<<");
 
    $command = "";

    if ($char == -1) {
      $self->Debug("Detected timeout");
      $self->{'timeout'} = 1;
      $command = "timeout";
 
    } elsif ($char eq " " or $char eq KEY_NPAGE  or $char eq KEY_C3) {
      if (! $self->PageDown()) {
        $command = "quit";  # because this was the last msg
      }

    } elsif ($char eq "\n" or $char eq KEY_DOWN or $char eq "j" or $char eq KEY_ENTER) {
      if (! $self->LineDown($char eq KEY_DOWN ? 0 : 1) ) {
        $command = "quit";  # because this was the last msg
      }

    } elsif ($char eq "\b" or $char eq KEY_BACKSPACE or $char eq KEY_PPAGE or $char eq KEY_A3) {
      if (! $self->PageUp() ) {
        $command = "quit";
      }

    } elsif ($char eq "k" or $char eq KEY_UP) {
      $self->LineUp($char eq KEY_UP ? 0 : 1);

    } elsif ($char eq "n" or $char eq KEY_RIGHT or $char eq "J") {
      if (! $self->msgslist->next()) {  # We were already at the last msg
        $command = "quit";
      } else {
        $self->msgsinterface->currmsg($self->msgslist->currentid());
        $self->reset();
        $self->Draw();
      }

    } elsif ($char eq "p" or $char eq KEY_LEFT or $char eq "K") {
      if (! $self->msgslist->prev()) {  # We were already at the first msg
        $command = "quit";
      } else {
        $self->msgsinterface->currmsg($self->msgslist->currentid());
        $self->reset();
        $self->Draw();
      }

    } elsif ($char eq "P") {  # Go to the parent of this msg
      my $msg = $self->msgslist->get();
      if ($msg && $msg->header('Followup-to:')) {
        my $parentid = $msg->header('Followup-to:');
        $self->msgsinterface->currmsg($parentid);
        $self->msgslist->setcurrentid($parentid);
        $self->reset();
        $self->Draw();
      } else {
        beep();
      }
      
    } elsif ($char eq "r" or $char eq "f") {
      $command = "followup";

    } elsif ($char eq "w") {
      $command = "savemsg";

    } elsif ($char eq "\t") {
      my $newmsgid = $self->msgsinterface->maxread();
      my $arenew = $self->msgsinterface->lastmsg() > $self->msgsinterface->maxread();
      if ($arenew) {
        $self->Debug("Skipping to the next unread msg $newmsgid");
        $self->msgsinterface->currmsg($newmsgid+1);
        $self->msgslist->setcurrentid($newmsgid+1);
        #$self->currentline(int($self->window->getmaxy() / 2));
        $self->reset();
        $self->Draw();
      } else {
        $command = "quit";
      }


    } elsif ($char eq "h") {
      $self->{'showheaders'} = ! $self->{'showheaders'};
      $self->Debug(sprintf("Toggeling showheaders now is %d",$self->{'showheaders'}));
      $self->reset();
      $self->Draw();
 
    } elsif ($char eq ".") {
      if ($self->msgsinterface->marked($self->msgslist->currentid)) {
        $self->msgsinterface->unmark($self->msgslist->currentid);
      } else {
        $self->msgsinterface->mark($self->msgslist->currentid);
      }

    } elsif ($char eq ">") {
      $command = "checkmarks";

    } elsif ($char eq "?" or $char eq KEY_HELP) {
      $command = "help";

    } elsif ($char eq "m") {
      $command = "mailreply";

    } elsif ($char eq "i" or $char eq "q") {
      $command = "quit";

    } elsif ($char eq "Q") {
      $command = "QUIT";
    
    } else {
      beep();
    }
  } # end while(1);

  if ($command ne "timeout") {
    if ($command eq "quit" && $self->msgsinterface->marks()) {
      $command = "checkmarks";
      $self->{'quitflag'} = 1;  # So when we come back to this widget, it'll exit
    }

    $msgid ||= $self->msgslist->currentid();
  }
  $self->Debug("Run returning command was $command msgid $msgid");

  ($command,$msgid);
} # end Run


1;
