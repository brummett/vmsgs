package Vmsgs::CursesInterface::Help;

use Curses;
use Vmsgs::Debug;
use Vmsgs::CursesInterface::PromptWindow;

use strict;

our @ISA = qw ( Vmsgs::Debug Vmsgs::CursesInterface::PromptWindow );

our $SelectHelp = "Help for the Select screen

<space> and <enter> - Read the currently selected message
n           - Create a new message
f or r      - Post a followup to the current message
w           - Append the current message to a file
k or <Up>   - Move the current message up
j or <Down> - Move the current message down
.           - Mark the current message for later reading
>           - Read all the currently marked messages
h or ?      - Bring up this help screen
/           - Enter search mode
C           - Mark all messages as read (Catch up)
q           - Exit this select screen
Q           - Quit vmsgs

You may also jump directly to a message by entering its msgID number";

our $ReadHelp = "Help for the Read screen

<space> - Move to the next page
<enter> or <Down> - Move down one line
<backspace> - Move back one page
n or <right> - Move to the next message
p or <left>  - Move to the previous message
r or f       - Post a followup to the current message
w            - Append the current message to a file
.            - Mark the current message for later reading
>            - Read all the currently marked messages
?            - Bring up this help screen
h            - Toggle the showing of message headers
q or i       - Exit this Read screen
Q            - Quit vmsgs";

our $SearchHelp = "Help for the Search screen

No help available yet :)";

# $state is which help we should print out: select, read, etc
sub new {
my($class,%args) = @_;
  my($self,$height,$width,$string);

  if ($args{'mode'} eq "selection") {
    $height = 22;
    $width = 65;
    $string = $SelectHelp;
  } elsif ($args{'mode'} eq "read") {
    $height = 20;
    $width = 65;
    $string = $ReadHelp;
  } elsif ($args{'mode'} eq "search") {
    $height = 10;
    $width = 60;
    $string = $SearchHelp;
  } else {
    $height = 6;
    $width = 40;
    $string = "Unknown state " . $args{'mode'};
  }

  $self = Vmsgs::CursesInterface::PromptWindow::new($class,
                                                    width => $width,
                                                    height => $height,
                                                    title => "Help",
                                                    nocenter => 1,
                                                    message => $string);

  $self->Debug(sprintf("Created new help screen for mode %s", $args{'mode'}));

  $self;
} # end new
                                                    
  
sub Run {
my($self) = @_;

  $self->Debug("Showing help window");
  $self->input();
  ("quit",undef);
} # end Run


1;
