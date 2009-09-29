package Vmsgs::CursesInterface::PromptWindow;

# Implements a widget to display a message and get a single keystroke as input

use Curses;
use Vmsgs::WidgetBase;
use Vmsgs::Debug;
use strict;

our @ISA = qw ( Vmsgs::WidgetBase Vmsgs::Debug );


# Create the new window.  Args are
# message - the main message in the window
# title - if present, the title for the window
# height - height for the window
# width - width of the window
# nocenter - set to true if the caller wants to format the strings, otherwise
#          each line is centered in the window
# choices - ref to a list of choices.  Elements are list refs
#    [choice-string, hotkey]  If choice-string and hotkey start with the same letter, it will be hilited
#    If choices if empty, a single choice "Ok" with a hotkey of enter is created. 
sub new {
my($class,%args) = @_;
  my($self,$win,@lines,$currentline,$promptwidth,$choicelen,@strings,);

  $self = {};
  bless $self,$class;

  $self->state("prompt");

  if (! defined($args{'choices'})) {  # If there were no choices...
    $args{'choices'} = [['Ok', "\n"]];
  }

  $self->{'height'} = $args{'height'};
  $self->{'width'} = $args{'width'};
  $self->{'title'} = $args{'title'};
  $self->{'message'} = $args{'message'};
  $self->{'choices'} = $args{'choices'};

#  $self->start_debug(".vmsgs.debug");
  $self->Debug(sprintf("Creating new prompt window message %s inputlen %d height %d width %d",
                       $args{'message'},$args{'inputlen'},$args{'height'},$args{'width'}));

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

  @strings = split(/^/, $args{'message'});
  foreach ( @strings ) {
    while(length($_)) {
      # if ($args{'message'} =~ s/^(.{1,$promptwidth})\s+//) {
      if (m/^\n$/) {
        push(@lines,"");  # an empty line
        $_ = "";
      } elsif (s/^(.{1,$promptwidth})\s+//) {
        push(@lines,$1);
      } else {  # Special cases for the last word in a string
        if (length($lines[$#lines] . " $_") > $promptwidth) {
          push(@lines, $_);
        } else {
          $lines[$#lines] .= " " . $_;
        }
        $_ = "";
      }
    } # end while
  } # end foreach


  # Print the lines into the window
  $currentline = 1;
  foreach (@lines) {
    if ($args{'nocenter'}) {
      $win->addstr($currentline++, 2, $_);  # column 2 skips the box and space border
    } else {
      $win->addstr($currentline++,
                   int(($args{'width'} - length($_)) / 2),
                   $_);
    }
  } # end foreach

  # How wide will all the choices be
  foreach ( @{$args{'choices'}} ) {
    $choicelen += length($_->[0]) + 1;  # the string length + 1 for the space between
  }

  # Now, print out all the choices
  $currentline++;  # Leave a blank line before the choices
  $win->move($currentline, int(($args{'width'} - $choicelen)/2));
  foreach ( @{$args{'choices'}} ) {
    my $firstchar = substr($_->[0], 0,1);
    $self->Debug(sprintf("Checking first char of choice %s with key %s", $firstchar, $_->[1]));
    if ($firstchar eq $_->[1])  { # If they start with the same letter
      $self->Debug("They match, bolding first char of choice");
      
      $win->attron(A_BOLD);
      $win->addch($firstchar);
      $win->attroff(A_BOLD);
      $win->addstr(sprintf("%s ",substr($_->[0], 1)));
    } else {
      $win->addstr(sprintf("%s ", $_->[0]));
    }
  } # end foreach
 
  $self->currentline($currentline);

  $self;
} # end new


sub input {
my($self) = @_;
  my($char,$choices);

  update_panels();
  doupdate();

  foreach ( @{$self->{'choices'}} ) {
    $choices .= $_->[1];
  }
  $choices .= "\n";  # To choose the default answer

  noecho();
  $self->Debug("Getting input from the user allowed choices >>$choices<<");
  while($char !~ m/[$choices]/i) {
    $char = getch();
    next unless ($char != -1);
    $self->Debug("Got a key $char");
  }

  $self->Debug("input char was >>$char<<\n");
  if ($char eq "\n") {
    $self->Debug("Returning the default choice");
    $char = $self->{'choices'}->[0]->[1];
  }
  $char;
} # end input

1;
