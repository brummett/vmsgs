package Vmsgs::CursesInterface::PromptWindow;

# Implements a widget to display a message and get a single keystroke as input

use Curses;
use Vmsgs::WidgetBase;
use Vmsgs::Debug;
use strict;

use base qw ( Vmsgs::WidgetBase Vmsgs::Debug );


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
  $self->{'nocenter'} = $args{'nocenter'};

#  $self->start_debug(".vmsgs.debug");
  $self->Debug(sprintf("Creating new prompt window message %s inputlen %d height %d width %d",
                       $args{'message'},$args{'inputlen'},$args{'height'},$args{'width'}));

  if ($args{'height'} > getmaxy()) {
    # Asked to create a window taller than the terminal
    $self->{'scrolly'} = 1;
    $self->{'height'} = getmaxy() - 2;
  }

  # Should we both supporting horizontal scrolling windows?
  if ($args{'width'} > getmaxx()) {
    print STDERR "Warning createing $class.  Requested width " .
                 $args{'width'} . " max width " . getmaxx() . "\n";
    $self->{'width'} = getmaxx() - 2;
  }
                   
  $win = $self->window(new Curses($self->{'height'},
                                  $self->{'width'},
                                  int((getmaxy() - $self->{'height'}) / 2),
                                  int((getmaxx() - $self->{'width'}) / 2)));
  $win->scrollok(0);
  $win->clear();
  $self->panel($self->window->new_panel());
 
  if ($self->{'title'}) {
    $self->{'title'} = " " . $self->{'title'} . " ";
    $win->addstr(0, 3, $self->{'title'});
  }
 
  # Break up the prompt into the right number of lines
  $promptwidth = $self->{'width'} - 4;  # 4 accounts for the box and space border
  $self->{'prompt'} .= " ";

  my @strings = split(/^/, $self->{'message'});
  foreach ( @strings ) {
    while(length($_)) {
      # if ($self->{'message'} =~ s/^(.{1,$promptwidth})\s+//) {
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
  $self->{'strings'} = \@lines;
  foreach (@lines) {
    if ($self->{'nocenter'}) {
      $win->addstr($currentline++, 2, $_);  # column 2 skips the box and space border
    } else {
      $win->addstr($currentline++,
                   int(($self->{'width'} - length($_)) / 2),
                   $_);
    }
    last if ($currentline >= ($self->{'height'} - 3));
  } # end foreach

  $win->box("|","-");

  $self->ShowChoices();
  $self->ShowScrollbars();
 
  $self->currentline($currentline);

  $self;
} # end new


sub ShowChoices {
my($self) = @_;
  my $win = $self->window();

  # How wide will all the choices be
  my $choicelen = 0;
  foreach ( @{$self->{'choices'}} ) {
    $choicelen += length($_->[0]) + 1;  # the string length + 1 for the space between
  }

  # Center the choices on the last line of the window
  $win->move($self->{'height'} - 2, int(($self->{'width'} - $choicelen)/2));

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


sub ShowScrollbars {
my($self) = @_;
  # If we haven't shown all the way to the bottom
  my $doshow = ($self->currentline() < scalar(@{$self->{'strings'}}));
print STDERR "Show bottom scroll $doshow\n";

  $self->window->addstr($self->{'height'} - 4,
                        $self->{'width'} - 2,
                        $doshow ? '|' : ' ');
  $self->window->addstr($self->{'height'} - 3,
                        $self->{'width'} - 2,
                        $doshow ? '|' : ' ');
  $self->window->addstr($self->{'height'} - 2,
                        $self->{'width'} - 2,
                        $doshow ? 'V' : ' ');

  $doshow = ($self->currentline() > $self->{'height'});
print STDERR "Show top scroll $doshow\n";
  $self->window->addstr(4,
                        $self->{'width'} - 2,
                        $doshow ? '|' : ' ');
  $self->window->addstr(3,
                        $self->{'width'} - 2,
                        $doshow ? '|' : ' ');
  $self->window->addstr(2,
                        $self->{'width'} - 2,
                        $doshow ? '^' : ' ');
}


sub input {
my($self) = @_;
  my($char,$choices);

  update_panels();
  doupdate();

  foreach ( @{$self->{'choices'}} ) {
    $choices .= $_->[1];
  }
  $choices .= "\n\033";  # To choose the default answer, and for escape

  noecho();
  $self->Debug("Getting input from the user allowed choices >>$choices<<");
  while($char !~ m/[$choices]/i) {
    $char = getch();
    next unless ($char != -1);
    $self->Debug("Got a key $char");

    if ($char eq KEY_UP && $self->{'scrolly'}) {
      $self->LineUp();
      redo;

    } elsif ($char eq KEY_DOWN && $self->{'scrolly'}) {
      $self->LineDown();
      redo;
    }
  }

  $self->Debug("input char was >>$char<<\n");
  if ($char eq "\n") {
    $self->Debug("Returning the default choice");
    $char = $self->{'choices'}->[0]->[1];
  }
  $char;
} # end input



sub LineDown {
my($self) = @_;
  my $currentline = $self->currentline();
  $currentline++;

  # If we haven't shown the whole thing yet
  if ($currentline <= scalar(@{$self->{'strings'}})) { 
    print STDERR "scrolling down currline $currentline strings ",scalar(@{$self->{'strings'}}),"\n";
    $self->window->scrollok(1);
    $self->window->scrl(1);
    $self->window->scrollok(0);
    $self->window->addstr($self->{'height'} - 3,
                          1,
                          " " x ($self->{'width'} - 2));
    print STDERR "adding string >>",$self->{'strings'}->[$currentline],"<<\n";
    $self->window->addstr($self->{'height'} - 3,
                          2,
                          $self->{'strings'}->[$currentline]);
  }

  $self->currentline($currentline);
  
  $self->ShowScrollbars();
  $self->window->box("|","-");
  update_panels();
  doupdate();
}

sub LineUp {
my($self) = @_;
 
}
1;
