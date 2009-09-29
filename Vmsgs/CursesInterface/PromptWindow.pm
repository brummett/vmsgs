package Vmsgs::CursesInterface::PromptWindow;

# Implements a widget to display a message and get a single keystroke as input

use Curses;
use Vmsgs::WidgetBase;
use Vmsgs::CursesInterface::ScrollableWindow;
use Vmsgs::Debug;
use strict;

use base qw ( Vmsgs::CursesInterface::ScrollableWindow Vmsgs::WidgetBase Vmsgs::Debug );


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
my $class = shift;
  my $self = $class->SUPER::new(@_);

  my($win,@lines,$currentline,$promptwidth,$choicelen,@strings,);

  $self->state("prompt");

  my %args = @_;
  if (! defined($args{'choices'})) {  # If there were no choices...
    $args{'choices'} = [['Ok', "\n"]];
  }

  $self->{'title'} = $args{'title'};
  $self->{'message'} = $args{'message'};
  $self->{'choices'} = $args{'choices'};
  $self->center_justify(! $args{'nocenter'});
  $self->{'noscroll'} = $args{'noscroll'};

#  $self->start_debug(".vmsgs.debug");
  $self->Debug(sprintf("Creating new prompt window message %s inputlen %d height %d width %d",
                       $args{'message'},$args{'inputlen'},$args{'height'},$args{'width'}));


  # FIXME  If this is an odd number, then the bar at the bottom
  # containing the choices is one line too low, and covers up the 
  # bottom of the box frame.  
  # to see the issue, make the help window height an odd number
  if ($args{'height'} > getmaxy()) {
    # Asked to create a window taller than the terminal
    $self->{'scrolly'} = 1;
    $args{'height'} = getmaxy() - 2;
  }

  # Should we both supporting horizontal scrolling windows?
  if ($args{'width'} > getmaxx()) {
    print STDERR "Warning creating $class.  Requested width " .
                 $args{'width'} . " max width " . getmaxx() . "\n";
    $self->{'width'} = getmaxx() - 2;
  }

  # This is actually a window to box in the scrollable window
  $self->titlebar(Curses->new($args{'height'},
                              $args{'width'},
                              int((getmaxy() - $args{'height'}) / 2),
                              int((getmaxx() - $args{'width'}) / 2)));
  $self->titlepanel($self->titlebar->new_panel());
  $self->titlebar->box("|","-");
  $self->boxed(1);
  if ($self->{'title'}) {
    $self->{'title'} = " " . $self->{'title'} . " ";
    $self->titlebar->addstr(0, 3, $self->{'title'});
  }
                   
  # leave 4 chars for the box and space border, and one for the scroll bar
  $self->width($args{'width'} - 5);
  # leave a line at the bottom for the choices and room for the box border
  $self->height($args{'height'} - 3);  
  $win = $self->window(Curses->new($self->height,
                                   $self->width,
                                   int((getmaxy() - $self->height) / 2) + 1,
                                   int((getmaxx() - $self->width) / 2) + 1));
  $win->scrollok(0);
  $win->clear();
  $self->panel($self->window->new_panel());
 
  my $width = $self->width;
  my @strings = split(/^/, $self->{'message'});
  foreach ( @strings ) {
    while(length($_)) {
      # if ($self->{'message'} =~ s/^(.{1,$width})\s+//) {
      if (m/^\n$/) {
        push(@lines,"");  # an empty line
        $_ = "";
      } elsif (s/^(.{1,$width})\s+//) {
        push(@lines,$1);
      } else {  # Special cases for the last word in a string
        if (length($lines[$#lines] . " $_") > $width) {
          push(@lines, $_);
        } else {
          $lines[$#lines] .= " " . $_;
        }
        $_ = "";
      }
    } # end while
  } # end foreach

  $self->currentline(0);
  $self->StoreLines(@lines);
  $self->Draw();
#  # Print the lines into the window
#  $currentline = 1;
#  $self->StoreLines(@lines);
#  foreach (@lines) {
#    if ($self->{'nocenter'}) {
#      $win->addstr($currentline++, 2, $_);  # column 2 skips the box and space border
#    } else {
#      $win->addstr($currentline++,
#                   int(($self->{'width'} - length($_)) / 2),
#                   $_);
#    }
#    last if ($currentline >= ($self->{'height'} - 3));
#  } # end foreach

  $self->bottombar(Curses->new(1,
                               $self->width,
                               int((getmaxy() - $self->height) / 2) + $self->height,
                               int((getmaxx() - $self->width) / 2)));
  $self->bottompanel($self->bottombar->new_panel());
                               
  $self->ShowChoices();
 
  $self->currentline($currentline);

  $self;
} # end new


sub ShowChoices {
my($self) = @_;
  my $win = $self->bottombar;

  # How wide will all the choices be
  my $choicelen = 0;
  foreach ( @{$self->{'choices'}} ) {
    $choicelen += length($_->[0]) + 1;  # the string length + 1 for the space between
  }

  # Center the choices on the last line of the window
  $win->move(0, int(($self->width - $choicelen)/2));

  foreach ( @{$self->{'choices'}} ) {
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
}


sub input {
my($self) = @_;
  my($char,$choices);

  foreach ( @{$self->{'choices'}} ) {
    $choices .= $_->[1];
  }
  $choices .= "\n\033";  # To choose the default answer, and for escape

  noecho();
  $self->Debug("Getting input from the user allowed choices >>$choices<<");
  while($char !~ m/[$choices]/i) {
    update_panels();
    doupdate();

    $char = getch();
    next unless ($char != -1);
    $self->Debug("Got a key $char");

    if ($char eq KEY_UP && $self->{'scrolly'}) {
      $self->LineUp();
      $self->ShowScrollbars();
      redo;

    } elsif ($char eq KEY_DOWN && $self->{'scrolly'}) {
      $self->LineDown();
      $self->ShowScrollbars();
      redo;

    } elsif ($char eq KEY_NPAGE && $self->{'scrolly'}) {
      $self->PageDown();
      $self->ShowScrollbars();

    } elsif ($char eq KEY_PPAGE && $self->{'scrolly'}) {
      $self->PageUp();
      $self->ShowScrollbars();

    }
  }

  $self->Debug("input char was >>$char<<\n");
  if ($char eq "\n") {
    $self->Debug("Returning the default choice");
    $char = $self->{'choices'}->[0]->[1];
  }
  $char;
} # end input



 
1;
