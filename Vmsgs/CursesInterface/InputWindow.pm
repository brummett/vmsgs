package Vmsgs::CursesInterface::InputWindow;

# Implements a dialog box that displays a prompt and gets some user input

use Curses;
use Vmsgs::WidgetBase;
use Vmsgs::Debug;
use strict;

use base qw ( Vmsgs::Debug Vmsgs::WidgetBase );

# Create a new prompt window.  It is centered in the teminal screen,
# and the text is centered in the window
# Args are:
# prompt - the string to prompt the user with
# inputlen - the number of characters you're expecting to get back, to center the response in the window
# height - the height of the window
# width - the width of the window
# title - if present, this will show up at the top of the window
# defaultinput - if present, this is the default answer from input() if the user just presses enter
sub new {
my($class,%args) = @_;
  my($self,$win,@lines,$promptwidth,$currentline,$input);

  $self = {};
  bless $self,$class;

  $self->state("input");

  $self->{'width'} = $args{'width'};
  $self->{'height'} = $args{'height'};
  $self->{'inputlen'} = $args{'inputlen'};
  $self->{'title'} = $args{'title'};
  $self->{'defaultinput'} = $args{'defaultinput'};

#  $self->start_debug(".vmsgs.debug");
  $self->Debug(sprintf("Creating new input window prompt %s inputlen %d height %d width %d",
                       $args{'prompt'},$args{'inputlen'},$args{'height'},$args{'width'}));

  # First, create the new window
  $win = $self->window(new Curses($args{'height'},
                                  $args{'width'},
                                  int((getmaxy() - $args{'height'}) / 2),
                                  int((getmaxx() - $args{'width'}) / 2)));
  $win->scrollok(0);
  $win->clear();
  $win->box("|","-");
  $self->panel($self->window->new_panel());

  if ($self->{'title'}) {
    $self->{'title'} = " " . $self->{'title'} . " ";
    $win->addstr(0, 3, $self->{'title'});
  }

  # Break up the prompt into the right number of lines
  $promptwidth = $args{'width'} - 4;  # 4 accounts for the box and space border
  $args{'prompt'} .= " ";  
  while(length($args{'prompt'})) {
    if ($args{'prompt'} =~ s/^(.{1,$promptwidth})\s+//) {
      push(@lines,$1);
    } else {
      push(@lines,$args{'prompt'});
      $args{'prompt'} = "";
    }
  } # end while

  $self->Debug(sprintf("promptwidth is %d prompt broken into %d lines",
                       $promptwidth, scalar(@lines)));

  # Print the lines into the window
  $currentline = 1;
  foreach (@lines) {
    $win->addstr($currentline++,
                 int(($args{'width'} - length($_)) / 2),
                 $_);
  } # end foreach

  $self->currentline($currentline);

  $self;
} # end new


# Clear the area that the user typed into so they can try again
sub reset {
my($self) = @_;

  $self->window->move($self->currentline(),1);
  $self->window->clrtobot();
  $self->window->box("|","-");
  if ($self->{'title'}) {
    $self->{'title'} = " " . $self->{'title'} . " ";
    $self->window->addstr(0, int(length($self->{'title'})/2), $self->{'title'});
  }

} # end reset
 

# Actually gets the user's input, return the string that they typed
sub input {
my($self) = @_;
  my($input,$win);

  $self->Debug("Getting user's input");
  
  $win = $self->window();

  # re-center the cursor and get the user's input
  curs_set(1);
  $win->move($self->currentline(), int(($self->{'width'} - $self->{'inputlen'}) / 2));
  if (defined($self->{'defaultinput'})) {
    $win->addch($self->{'defaultinput'});
    update_panels();
    doupdate();
  }
  echo();
  $win->getstr($input);
  noecho();
  curs_set(0);

  $input = $self->{'defaultinput'} . $input;
  $input =~ s/\n$//;

  $self->Debug("They entered >>$input<<");
 
  $input;
} # end input



1;
