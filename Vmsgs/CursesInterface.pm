package Vmsgs::CursesInterface;

use Curses;

use Vmsgs::Msg;
use Vmsgs::Debug;
use Vmsgs::MsgsList;

# The widget classes we'll need
use Vmsgs::CursesInterface::InputWindow;
use Vmsgs::CursesInterface::PromptWindow;
use Vmsgs::CursesInterface::Select;
use Vmsgs::CursesInterface::Read;
use Vmsgs::CursesInterface::Help;
use Vmsgs::CursesInterface::PostNew;
use Vmsgs::CursesInterface::Followup;
use Vmsgs::CursesInterface::SaveMsg;
use Vmsgs::CursesInterface::Search;
use Vmsgs::CursesInterface::MailReply;

use strict;

our @ISA = qw ( Vmsgs::Debug );
our $DEBUG = 0;

# Implements the curses interface for vmsgs.  Requires the libpanel stuff too

our $VERSION = "1.0";

sub new {
my($class,$state) = @_;
  my($self);

  $self->{'state'} = $state;

  bless $self,$class;

  $self->start_debug(".vmsgs.debug") if ($DEBUG);
  $self->Debug("creating new CursesInterface object");
  $self->{'search_level'} = 0;

  $self;
} # end new


# Start up the reading machine
sub Init {
my($self,$state) = @_;
  my($topwindow,$msgslist,$event,$mode,$command,$msgid);
  local(%SIG);

  $self->Debug("In Init");

  $self->{'main_msgslist'} = $self->_BuildInitialMsgsList($state->{'msgs'},$state->{'rules'});
#  open(STDERR,">.vmsgs.stderr");

  $SIG{'WINCH'} = sub {
    $self->Debug("Resizing window...");
    def_prog_mode();
    endwin();
    initscr();
    $topwindow->Draw();
    update_panels();
    doupdate();
  };

  $SIG{'TERM'} = $SIG{'INT'} = sub {
    $self->Debug("Interrupt!  Trying to exit nicely");
    $self->Shutdown();
    exit(0);
  };

  #$SIG{'CONT'} = sub {
  #  refresh();
  #  $topwindow->Draw();
  #  1;
  #};

  initscr();
  $self->set_kb_mode();

  $self->Debug(sprintf("In Curses mode currmsg is %s",
                       $state->{'msgs'}->currmsg()));

  $topwindow = new Vmsgs::CursesInterface::Select(msgsinterface => $state->{'msgs'},
                                                  msgslist => $self->{'main_msgslist'});
  if (!$topwindow) {
    $self->Debug("Failed to create new select widget");
    return undef;
  }

  $self->MainLoop(topwindow => $topwindow,
                  msgslist => $self->{'main_msgslist'});

  $self->Debug("Exited from top-level MainLoop");
} # end Init


sub set_kb_mode {
  noecho();
  cbreak();
  keypad(1);
  halfdelay(100);  # Check for new msgs every 10 seconds
  curs_set(0);  # make the cursor invisible
}




sub MainLoop {
my($self,%args) = @_;
  my($command,$msgid,$msgslist,$topwindow,@windowstack,$msgsinterface);

  $msgslist = $args{'msgslist'};
  $topwindow = $args{'topwindow'};
  $msgsinterface = $self->{'state'}->{'msgs'};
  $self->Debug("Entering new MainLoop instance msgslist $msgslist topwindow $topwindow");

  $msgsinterface->SetArg0Status("running");

  # The main loop
  MAIN_LOOP:
  while($topwindow) {
    ($command,$msgid) = $topwindow->Run(msgid => $msgid);

    $self->Debug("Back from widget::Run returned command $command msgid $msgid");

    if ($command eq "read") {
      push(@windowstack,$topwindow);
      $topwindow = new Vmsgs::CursesInterface::Read(msgsinterface => $msgsinterface,
                                                 msgslist => $msgslist);
    
    } elsif ($command eq "postnew") {
      push(@windowstack,$topwindow);
      $topwindow = new Vmsgs::CursesInterface::PostNew(msgsinterface => $msgsinterface,
                                                       editor => $self->{'state'}->{'editor'});
      $self->set_kb_mode();

    } elsif ($command eq "followup") {
      push(@windowstack,$topwindow);
      $topwindow = new Vmsgs::CursesInterface::Followup(msgsinterface => $msgsinterface,
                                                        editor => $self->{'state'}->{'editor'},
                                                        msgid => $msgid);
      $self->set_kb_mode();

    } elsif ($command eq "savemsg") {
      push(@windowstack,$topwindow);
      $topwindow = new Vmsgs::CursesInterface::SaveMsg(msgsinterface => $msgsinterface,
                                                       msgid => $msgid);

    } elsif ($command eq "help") {
      push(@windowstack,$topwindow);
      $topwindow = new Vmsgs::CursesInterface::Help(mode => $topwindow->state());

    } elsif ($command eq "search") {
      push(@windowstack,$topwindow);
      $topwindow = new Vmsgs::CursesInterface::Search(msgsinterface => $msgsinterface,
                                                      msgslist => $msgslist);
      
    } elsif ($command eq "mailreply") {
      push(@windowstack,$topwindow);
      $topwindow = new Vmsgs::CursesInterface::MailReply(msgsinterface => $msgsinterface,
                                                        editor => $self->{'state'}->{'editor'},
                                                        msgid => $msgid);
      $self->set_kb_mode();
  
    } elsif ($command eq "jump") {
      $msgid = $self->JumpMsg($topwindow,$msgid,$msgslist->currentid());
      $msgslist->setcurrentid($msgid);
      $msgsinterface->currmsg($msgslist->currentid());
      $topwindow->Draw();

    } elsif ($command eq "dosearch") {
      my $oldrules = $self->{'state'}->{'rules'};
      my $newrules = $self->{'state'}->{'rules'} = $oldrules->clone();
      $newrules->prepare_search();
      $newrules->unshift(@$msgid); # After a search dialog, $msgid is the search query ['read','from','authorname'] for example

      my $newlist = $msgslist->clone(msgsrules => $newrules);
      if ($newlist->no_matches()) {  # the search terms didn't find anything
        $self->NoSearchMatches();
      } else {
        $self->{'search_level'}++;
print STDERR "Before setting currentid of new msgslist\n" if ($DEBUG);
        $newlist->setcurrentid($msgslist->currentid);
        my $newtopwindow = Vmsgs::CursesInterface::Select->new(msgsinterface => $msgsinterface,
                                                               msgslist => $newlist,
                                                               name => "search (".$self->{'search_level'}.")");
print STDERR "Created new select widget\n" if ($DEBUG);
        ($command,$msgid) = $self->MainLoop(msgslist => $newlist,
                                            topwindow => $newtopwindow);
        $self->{'search_level'}--;
print STDERR "Back from MainLoop\n" if ($DEBUG);
      }
      $self->{'state'}->{'rules'} = $oldrules;
      $topwindow = pop(@windowstack);

    } elsif ($command eq "checkmarks") {
      if (&CheckMarks($msgsinterface)) {
        # push(@windowstack,$topwindow);
        my $newmsgslist = $self->_BuildMarkedMsgsList($msgsinterface);
        my $newtopwindow = new Vmsgs::CursesInterface::Select(msgsinterface => $msgsinterface,
                                                              msgslist => $newmsgslist);
        ($command,$msgid) = $self->MainLoop(msgslist => $newmsgslist,
                                            topwindow => $newtopwindow);

        # A hack to clear the +s next to marked msgs after we come back to a selection widget
        $topwindow->ClearMarksColumn() if ($topwindow->can('ClearMarksColumn'));   
        
      }
    } elsif ($command eq "quit") {
      $topwindow = pop(@windowstack);

    } elsif ($command eq "QUIT") {
      $topwindow = undef;

    } elsif ($command ne "timeout") {
      $self->Debug("Unknown command $command");
    }

    $self->IncorporateNewMsgs($msgsinterface, $self->{'main_msgslist'}, $self->{'state'}->{'rules'});
  } # end while

  $self->Debug("Leaving MainLoop instance returning command $command msgid $msgid");
  return ($command,$msgid);
} # end MainLoop


sub IncorporateNewMsgs {
my($self,$msgsinterface,$msgslist,$rules) = @_;
  my($newlastmsg,@list);

  (undef,$newlastmsg) = $msgsinterface->bounds();
  if ($newlastmsg > $msgsinterface->lastmsg()) {
    $self->Debug("There are new msgs to read");

    foreach ( ($msgsinterface->lastmsg + 1) .. $newlastmsg ) {
      my $msg = $msgsinterface->Get($_);
      if ($rules->pass($msg)) {
        $self->Debug("msgid $_ passed the rules test");
        push(@list,$msg);
      }
    } # end foreach

    $self->Debug(sprintf("Adding %d new msgs to the msgslist $msgslist",
                         scalar(@list)));
    $msgslist->append(\@list);

    $msgsinterface->lastmsg($newlastmsg);
  } # end if
} # end IncorporateNewMsgs


sub NoSearchMatches {
my($self) = @_;
  my $win = Vmsgs::CursesInterface::PromptWindow->new(height => 6,
                                                      width => 26,
                                                      title => "No Matches",
                                                      message => "There were no matches to your search");
  $win->input();
};



# Called when the user starts to enter a number to jump to a msg by ID#
sub JumpMsg {
my($self,$selectwin,$char,$currid) = @_;
  my($promptwin,$msgnum);

  $self->Debug("In JumpMsg");

  $promptwin = new Vmsgs::CursesInterface::InputWindow(height => 6,
                                                        width => 20,
                                                        inputlen => 6,
                                                        title => "Goto msg",
                                                        prompt => "New msg id",
                                                        defaultinput => $char);
  $msgnum = $promptwin->input();
  $self->Debug("User entered $msgnum");

  # Construct a new msgnum based on the user's input and the current msgID
  $msgnum = substr($currid, 0, length($currid) - length($msgnum)) . $msgnum;
  
  $msgnum;
} # end JumpMsg



# Asks the user if they want to go back and re-read marked msgs
sub CheckMarks {
my($msgsinterface) = @_;
  my($win,$char);

  if (scalar($msgsinterface->marks())) {
    $win = new Vmsgs::CursesInterface::PromptWindow(height => 6,
                                                    width => 26,
                                                    title => "Marks",
                                                    message => "Read marked messages?",
                                                    choices => [["Yes", "Y"],["No","N"]]);
    $char = $win->input();
    if ($char eq "Y" or $char eq "y") {
      return 1;
    } else {
      return 0;
    }
  } else {
    return 0;
  }
}
  
  
  

sub _BuildInitialMsgsList {
my($self,$msgsinterface,$rules) = @_;
  my($msgslist,$firstid,$lastid);

  $firstid = $msgsinterface->currmsg() - 50;  # Start reading in 50 back
  $lastid = $msgsinterface->lastmsg();

  $self->Debug("Creating initial MsgsList from id $firstid to $lastid");
  $msgslist = new Vmsgs::MsgsList(msgsinterface => $msgsinterface,
                                  msgsrules => $rules,
                                  msgidlist => [[$msgsinterface->firstmsg(), $firstid-1], $firstid .. $lastid],
                                  current => $msgsinterface->currmsg());

  # Since the current pointer in the list may not be set exactly to what you asked
  # it to be set to (depending on what's actually in the list and the contents of
  # the .msgsrules file), you have to re-sync the msgsinterface with what was
  # actually picked as current by the list
  $msgsinterface->currmsg($msgslist->currentid());

  $msgslist;
} #end _BuildInitialMsgsList
  

sub _old_BuildInitialMsgsList {
my($self,$msgsinterface,$rules) = @_;
  my(@list,$msgslist,$numread,$msg,$msgid);

  my $READAHEAD = 50;  # Read in this many msgs to begin with

  $self->Debug("In _BuildMsgsList");

  $numread = 0;
  $msgid = $msgsinterface->currmsg() - $READAHEAD/2;  # Put the current msg in the middle
  while ($numread < $READAHEAD && $msgid <= $msgsinterface->lastmsg()) {

    $self->Debug("Looking at msgid $msgid numread $numread");
    $msg = $msgsinterface->Get($msgid);

    if ($rules->pass($msg)) {
      $self->Debug("msgid $msgid passed the rules test");

      # simple huristic to pick out read from unread at the start of the program
      $msgsinterface->setread($msgid) if ($msgid < $msgsinterface->currmsg());  
    
      push(@list,$msg);
      $numread++;
    }
    $msgid++;
  } # end while
  
  $msgslist = new Vmsgs::MsgsList(@list);
  # You have to do this both ways because the first one tries setting the current ID
  # in the list, which may be adjusted depending on the msgIDs actually stored in the
  # list and what's in the .msgsrules file.  The second one syncs the msgsinterface with
  # the msgID selected vt the list
  $msgslist->setcurrent($msgsinterface->currmsg());
  $msgsinterface->currmsg($msgslist->currentid());

  $msgslist;
} # end _BuildInitialMsgsList



# Build a MsgsList object out of the marked msgs
sub _BuildMarkedMsgsList {
my($self,$msgsinterface) = @_;
  my(@list,$msg,$msgslist);

  @list = sort $msgsinterface->marks();

  $self->Debug(sprintf("Building a MsgsList out of %d marked msgs ids",
                       scalar(@list)));
  $msgslist = new Vmsgs::MsgsList(msgsinterface => $msgsinterface,
                                  msgidlist => \@list);
  $msgsinterface->currmsg($msgslist->currentid());

  $msgslist;
} # end BuildMarkedMsgsList


# update the screen then block until the user presses a key
sub NullLoop {
my($self) = @_;

  $self->Debug("In NullLoop");
  update_panels();
  doupdate();

  getch();
  $self->Debug("Exiting NullLoop");
}


sub Shutdown {
my($self) = @_;
  $self->Debug("Shutting down Curses interface");
  $self->DESTROY();
}

sub DESTROY {
my($self) = @_;
  $self->Debug("In Curses interface destructor");
  
  curs_set(1);
  endwin();
} # end DESTROY


# save a widget to the window stack
sub _savewin {
  push(@{$_[0]->{'windowstack'}}, $_[1]);
}

# pop a widget off the stack
sub _popwin {
  pop(@{$_[0]->{'windowstack'}});
}


1;
