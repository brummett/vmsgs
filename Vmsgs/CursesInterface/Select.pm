package Vmsgs::CursesInterface::Select;

# Implements a Select screen widget

use Curses;
use Vmsgs::WidgetBase;
use Vmsgs::Debug;
use strict;

our @ISA = qw ( Vmsgs::WidgetBase Vmsgs::Debug );

# Create a new select screen.  args are
# msgsinterface - ref to a MsgsInterface object
# msgslist - ref to a MsgsList object
# 
# The current position for the MsgsInterface and MsgsList objects should be set
# before calling this function
sub new {
my($class,%args) = @_;
  my($self,$win);

  $self = {};
  bless $self,$class;
  
  $self->start_debug(".vmsgs.debug");
  $self->Debug("Creating new select window $self");
  $self->Debug(sprintf("Screen dimensions are height %d width %d",
                      getmaxy(),getmaxx()));

  # Initialize the internal state
  $self->msgsinterface($args{'msgsinterface'});
  $self->msgslist($args{'msgslist'});
  $self->state($args{'name'} || "selection");
  
  # Create the titlebar
  $win = new Curses(1,0,0,0);
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
  $win->scrollok(0);
  $self->window($win);
  $self->panel($win->new_panel());

  $self->msgsinterface->unmark_all();

  $self->Draw();

  $self;
} # end new


# Draw the main select panel from scratch
sub Draw {
my($self) = @_;
  my($middleline,$currentline,$currmsgid,$msg,$savedid);

  # $self->msgslist->pushcurrent();
  $savedid = $self->msgslist->currentid();

  $self->Debug("Drawing select widget $self from scratch");

  $self->window->clear();

  $middleline = $self->currentline() || int($self->window->getmaxy() / 2);
  $self->window->move($middleline,0);

  # First, draw the current msg and all those after
  $currentline = $middleline;
  $msg = $self->msgslist->get();
  while($msg && $currentline < $self->window->getmaxy()) {
    $self->Debug("moving cursor to Y $currentline X 0");
    $self->window->move($currentline,0);
    $self->PrintMsgInfoLine($msg);
 
    $msg = $self->msgslist->next();
    $currentline++;
  }

  # Now, draw all the msgs before the current one
  #$self->msgslist->popcurrent();
  #$self->msgslist->pushcurrent();
  $self->msgslist->setcurrentid($savedid);
  $msg = $self->msgslist->prev();
  $currentline = $middleline - 1;

  while($msg && $currentline >= 0) {
    $self->Debug("moving cursor to Y $currentline X 0");
    $self->window->move($currentline,0);
    $self->PrintMsgInfoLine($msg);
    
    $msg = $self->msgslist->prev();
    $currentline--;
  }

  #$self->msgslist->popcurrent();
  $self->msgslist->setcurrentid($savedid);
  $self->currentline($middleline);
} # end Draw


# Printout the line of info for the one msgID given
# Looks at the status of read/unread/current to know if it should be normal/bold/hilited
# the cursor should be placed before calling this
sub PrintMsgInfoLine {
my($self,$msg) = @_;
  my($msgid,$subject,$subjwidth);
 
  $msgid = $msg->id();
  $self->Debug("Printing a msgs info line for msgid $msgid");
 
  if ($msgid == $self->msgsinterface->currmsg()) {
    $self->Debug("$msgid is current!");
    $self->window->attron(A_REVERSE);
  }
  if (! $self->msgsinterface->isread($msgid)) {
    $self->Debug("$msgid is unread");
    $self->window->attron(A_BOLD);
  }
 
  # The width alloted for the subject, terminal width less 23 chars
  # which should like up with the format in the sprintf below.  23 chars
  # is the msg ID, marked, author and size columns
  $subjwidth = $self->window->getmaxx() - 23;
  $subject = substr($msg->header("Subject:"),0,$subjwidth);

  $self->window->addstr(sprintf("%6s%s%-10s %4s %s",
                                $msg->id(),
                                $self->msgsinterface->marked($msgid) ? "+" : " ",
                                $msg->header("Author"),
                                $msg->header("Content-length:"),
                                $subject));
 
  $self->window->attroff(A_REVERSE);
  $self->window->attroff(A_BOLD);
} # end PrintMsgInfoLine


# Clear out the 6th column, where the +s go next to msgIDs to show a msg is marked
sub ClearMarksColumn {
my($self) = @_;

  foreach ( 0 .. $self->window->getmaxy() ) {
    $self->window->attron(A_REVERSE) if ($_ == $self->currentline());  # Make it bold if this is the current line
    $self->window->addch($_, 6, " ");
    $self->window->attroff(A_REVERSE);
  }
} # end ClearMarksColumn


# Called when the user presses K or KEY_UP to move the current position up one (numerically down)
# You can also pass in a count to move that many msgs
sub KeyUp {
my($self,$count) = @_;
  my($oldcurrentmsg,$currentline,$msg);

  $self->Debug("In KeyUp");

  $count ||= 1;    # Default count is 1

  $oldcurrentmsg = $self->msgslist->get();
  $currentline = $self->currentline();

  # First update the curent position in the msg list
  $msg = $self->msgslist->prev($count);
  return undef unless (defined($msg));  # just return if it's already the last one
  $self->msgsinterface->currmsg($self->msgslist->currentid);

  if ($self->currentline() - $count < 0) {  # Moving would put us off the top of the window so redraw the screen
    $self->Draw();
  } else {

    # Unhilite the ex-current msg
    $self->Debug("Moving cursor to line $currentline to unhilite old current");
    $self->window->move($currentline,0);
    $self->PrintMsgInfoLine($oldcurrentmsg);

    # Redraw the new current msg hilited
    $currentline -= $count;
    $self->Debug("Moving to line $currentline to hilite new current");
    $self->currentline($currentline);
    $self->window->move($currentline,0);
    $self->PrintMsgInfoLine($msg);
  } # end else

  $self->UpdateBottombar();
} # end KeyUp

# Called when the user presses J or KEY_DOWN to move the current position down one (numerically higher)
# You can also pass in a count to move that many msgs
sub KeyDown {
my($self,$count) = @_;
  my($oldcurrentmsg,$currentline,$msg);
 
  $self->Debug("In KeyDown");

  $count ||= 1;  # Default count is 1

  $self->Debug(sprintf("Before advancing current msgid is %d",
                       $self->msgslist->currentid));
  $oldcurrentmsg = $self->msgslist->get();
  $currentline = $self->currentline();
 
  # First update the curent position in the msg list
  $msg = $self->msgslist->next($count);
  return undef unless (defined($msg));  # just return if it's already the last one
  $self->msgsinterface->currmsg($self->msgslist->currentid);
  $self->Debug(sprintf("After advancing current msgid is %d",
                       $self->msgslist->currentid));

#  if ($oldcurrent == $self->msgslist->currentid) {  # If we were already at the last one
#    $self->window->move($currentline,0);
#    $self->PrintMsgInfoLine($oldcurrent);
#    return undef;   # and return
#  }

  # Moving would put us off the bottom of the window so redraw the screen
  if ($self->currentline() + $count >= $self->window->getmaxy()) {  
    $self->currentline(0);  # This will force Draw() to redraw from scratch
    $self->Draw();
  } else {
 
    # Unhilite the ex-current msg
    $self->Debug("Moving cursor to line $currentline to unhilite old current");
    $self->window->move($currentline,0);
    $self->PrintMsgInfoLine($oldcurrentmsg);
 
    # Redraw the new current msg hilited
    $currentline += $count;
    $self->Debug("Moving to line $currentline to hilite new current");
    $self->currentline($currentline);
    $self->window->move($currentline,0);
    $self->PrintMsgInfoLine($msg);
  } # end else

  $self->UpdateBottombar();
} # end KeyDown


# Create the titlebar's contents from scratch
sub DrawTitlebar {
my($self) = @_;

  my $winhandle = $self->titlebar();

  $winhandle->move(0,0);
  $winhandle->addstr(" " x $winhandle->getmaxx());

  $winhandle->addstr(0,0,sprintf("vmsgs %8s",$Vmsgs::VERSION));
  my $fromstring = "from " . ($self->msgsinterface->server() || "local");
  $winhandle->addstr(0,55,sprintf("%25s", $fromstring));
} # end DrawTitlebar


# Create the bottombar's contents from scratch
sub DrawBottombar {
my($self) = @_;
  my $winhandle = $self->bottombar();
  
  $winhandle->clear();
  $winhandle->move(0,0);

  # Time at col 4
  # mode string at col 13
  # total # msgs at col 37
  # # new msgs at col 52
  $winhandle->addstr(sprintf("-- %5s -- %10s -- help:? -- %6s msgs -- %6s new --",
                             $self->_PrintTime(),
                             $self->state(),
                             $self->msgslist->count(),
                             $self->msgsinterface->lastmsg() - $self->msgsinterface->maxread()));
} # end DrawBottombar


sub UpdateBottombar {
my($self) = @_;
  my($total,$new);

  $total = $self->msgslist->count();
  $new = $self->msgsinterface->lastmsg() - $self->msgsinterface->maxread();

  $self->Debug("Updating bottombar $total total $new new");
                       
  $self->bottombar->addstr(0,3,sprintf("%5s",$self->_PrintTime()));
  $self->bottombar->addstr(0,36,sprintf("%6s",$total));
  $self->bottombar->addstr(0,51,sprintf("%6s",$new));
} # end UpdateBottomBar


# Does the user input loop until something interesting is selected, or the timer runs out
# Args are:
#    msgid - position the current msg pointer at this msg, default is to use $self->msgslist->currentid()
# Returns a 2-element list: (command, msgid) 
#    where command can be "read", "followup", "postnew", "mailreply", "savemsg", "search", "timeout", "quit", "help"
# Basicly, anything that the select widget can't do itself
sub Run {
my($self,%args) = @_;
  my($char,$command,$msgid);

  if (($self->{'last_currentid'} != $self->msgslist->currentid()) or
      ($self->{'last_count'} != $self->msgslist->count())) {
    $self->msgsinterface->currmsg($self->msgslist->currentid());
    $self->Debug("Something in msgslist changed, redrawing");
    $self->Draw();
  }

  $self->msgsinterface->SetArg0Status("running") unless ($self->{'timeout'});
    

  READ_A_KEY:
  while(! $command) {
    # Update the screen
    $self->UpdateBottombar();
    update_panels();
    doupdate();

    $self->{'timeout'} = 0;
    halfdelay($args{'timeout'}) if ($args{'timeout'});
    $char = getch();
    $self->Debug("Got user's input >>$char<<");

    $command = "";
    if ($char == -1) {
      $self->Debug("Detected timeout");
      $self->{'timeout'} = 1;
      $command = "timeout";

    } elsif ($char eq " " or $char eq "\n" or $char eq KEY_ENTER) {  # space or enter
      $command = "read";
    
    } elsif ($char eq "n") {  # Post a new msg
      $command = "postnew";

    } elsif ($char eq "f" or $char eq "r") {  # followup or reply
      $command = "followup";

    } elsif ($char eq "w") {  # Write this msg to a file 
      $command = "savemsg";

    } elsif ($char eq "k" or $char eq KEY_UP or $char eq "K") {
      $self->KeyUp();

    } elsif  ($char eq "j" or $char eq KEY_DOWN or $char eq "J") {
      $self->KeyDown();

    } elsif ($char eq KEY_PPAGE or $char eq KEY_A3 or $char eq KEY_LEFT) {
      my $count = $self->window->getmaxy();
      while ($count-- && $self->msgslist->prev()) {;}  # Decrement the msglist pointer $count times
      $self->msgsinterface->currmsg($self->msgslist->currentid());
      $self->Draw();

    } elsif ($char eq KEY_NPAGE or $char eq KEY_C3 or $char eq KEY_RIGHT) {
      my $count = $self->window->getmaxy();
      while ($count-- && $self->msgslist->next()) {;}  # Increment the msglist pointer $count times
      $self->msgsinterface->currmsg($self->msgslist->currentid());
      $self->Draw();

    } elsif ($char eq ".") {   # Mark this msg for later
      if ($self->msgsinterface->marked($self->msgslist->currentid)) {
        $self->msgsinterface->unmark($self->msgslist->currentid);
      } else {
        $self->msgsinterface->mark($self->msgslist->currentid);
      }
      $self->KeyDown();

    } elsif ($char eq ">") {  # Start reading the marked msgs
      $command = "checkmarks";

    } elsif  ($char eq "h" or $char eq "?" or $char eq KEY_HELP) { 
      $command = "help";

    } elsif ($char eq "m") { # Mail a reply back to the author
      $command = "mailreply";

    } elsif ($char eq "/") { # Search & select
      $command = "search";

    } elsif ($char eq "\cL") {
      $self->Debug("Redrawing on user's request");
      $self->Draw();

    } elsif ($char eq "C") {  # Catch up
      while($self->msgslist->next()) {
        $self->msgsinterface->setread($self->msgslist->currentid());
      }

      # Redraw with the last msg current and in the middle
      $self->msgsinterface->currmsg($self->msgslist->currentid());
      $self->currentline(int($self->window->getmaxy() / 2));
      $self->Draw();

    } elsif ($char eq "P") {  # Go to the parent of this msg
      my $msg = $self->msgslist->get();
      if ($msg && $msg->header('Followup-to:')) {
        my $parentid = $msg->header('Followup-to:');
        $self->msgsinterface->currmsg($parentid);
        $self->msgslist->setcurrentid($parentid);
        $self->Draw();
      } else {
        beep();
      }

    } elsif ($char eq "\t") {
      my $newmsgid = $self->msgsinterface->maxread();
      my $arenew = $self->msgsinterface->lastmsg() > $self->msgsinterface->maxread();
      $self->Debug("Skipping to the next unread msg $newmsgid");
      $self->msgsinterface->currmsg($newmsgid + $arenew);
      $self->msgslist->setcurrentid($newmsgid + $arenew);
      $self->currentline(int($self->window->getmaxy() / 2));
      $self->Draw();

#    } elsif ($char eq KEY_RIGHT or $char eq KEY_LEFT) {
#      # Check for these keys specificly because they screw
#      # up the digit detection
# Really? Still? seems to work ok now 28 sep 05
#      beep();

    } elsif ($char =~ m/\d/) {  # Jump to a msg by ID 
      $command = "jump";
      $msgid = $char;
      $self->Debug(sprintf("Preparing to jump, id >>%s<< length %d",$char,length($char)));

    } elsif ($char eq "q") {   # Quit from this select screen
      $command = "quit";

    } elsif ($char eq "Q") {
      $command = "QUIT";

    } else {
      beep();
    }

  } # end while(1);

  $msgid = defined($msgid) ? $msgid : $self->msgslist->currentid();

  alarm(0);  # Cancel any pending alarm

  # Save these so we can check to see if they changed between calls to Run()
  $self->{'last_currentid'} = $self->msgslist->currentid();
  $self->{'last_count'} = $self->msgslist->count();

  $self->Debug("Run returning command $command msgid $msgid");
  ($command, $msgid);
} #end Run


1;
