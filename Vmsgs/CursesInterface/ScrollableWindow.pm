package Vmsgs::CursesInterface::ScrollableWindow;

use strict;

use Curses;
use Vmsgs::WidgetBase;
use base 'Vmsgs::WidgetBase';


sub new {
my($class) = @_;

  my $self = bless {},$class;

  #Curses::curs_set(0);  # make the cursor invisible
  $self;
}

# Accessor for storing all the text lines this widget will hold
sub StoreLines {
my($self,@lines) = @_;

  if (ref $lines[0] eq 'ARRAY') {  # It's been presplit
    $self->{'lines'} = $lines[0];
  } elsif (@lines == 1) {
    my @strings = split(/\n/,$lines[0]);
    $self->{'lines'} = \@strings;
  } else {
    $self->{'lines'} = \@lines;
  }
}

# Returns a list of lines in the given range.  Default returns all of them
sub Lines {
my($self,$start,$end) = @_;
  if (defined $start && ! defined $end) {
    # Just return that one line they asked for
    $self->{'lines'}->[$start];
  } elsif (defined $start && defined $end) {
    $start = 0 if ($start < 0);
    $end = $#{$self->{'lines'}} if ($end >= @{$self->{'lines'}});

    my @range = @{$self->{'lines'}}[$start..$end];
    return \@range;
  } else {
    $self->{'lines'};
  }
}


# How many lines?
sub LineCount {
my($self) = @_;
  $self->{'lines'} ||= [];

  scalar(@{$self->{'lines'}});
}

sub ClearLines {
my($self) = @_;
  $self->{'lines'} = [];
}


# Fill in the window from scratch with text from the Lines buffer
sub Draw {
my($self) = @_;

  $self->window->clear();
  $self->window->move(0,0);

  $self->ShowScrollbars();

  my $currentline = $self->currentline();
  my $win = $self->window;
  my $row = 0;
  while ($row < $self->height) {
    last if ($currentline > $self->LineCount());
    my $string = $self->Lines($currentline++);
    my $col = $self->center_justify ?
              int(($self->width - length($string)) / 2) : 
              $self->boxed * 2;

    $win->addstr($row++, $col, $string);
    # This handles the case where the line was wider than the terminal
    # width, so should count as 2 (or more) lines
    $row += (int(length($string) / $self->window->getmaxx));
  }
  $self->currentline($currentline - 1);
}
    

sub noscroll {
my($self,$val) = @_;
  if (defined $val) {
    $self->{'noscroll'} = $val;
  } else {
    $self->{'noscroll'};
  }
}
  

sub ShowScrollbars {
my($self) = @_;

  return if $self->noscroll();
  # If this window was not boxed, then the arrows should show in the
  # rightmost column.  If is it boxed, then the next to last column.
  my $column = $self->width - $self->boxed - 1;
  my $overscan = 2;#($self->boxed * 2) + 2;

  my $doshow = ($self->currentline() >= ($self->height - $overscan));
  my $rowoffset = $self->boxed;
  $self->window->addstr($rowoffset + 2,
                        $column,
                        $doshow ? '|' : ' ');
  $self->window->addstr($rowoffset + 1,
                        $column,
                        $doshow ? '|' : ' ');
  $self->window->addstr($rowoffset,
                        $column,
                        $doshow ? '^' : ' ');

  # If we haven't shown all the way to the bottom
  $doshow = (($self->currentline() + $self->height() - $overscan) <= $self->LineCount());
  $rowoffset = $self->height - $self->boxed - 1;
  $self->window->addstr($rowoffset - 2,
                        $column,
                        $doshow ? '|' : ' ');
  $self->window->addstr($rowoffset - 1,
                        $column,
                        $doshow ? '|' : ' ');
  $self->window->addstr($rowoffset,
                        $column,
                        $doshow ? 'V' : ' ');
}


# Move the viewable portion down one line (scroll up)
# returns 1 if it was able to scroll (ie. weren't already at
# the bottom), 0 otherwise
sub LineDown {
my($self) = @_;
  my $currentline = $self->currentline();

  # If we haven't shown the whole thing yet
  if ($currentline < $self->LineCount()) {
    $currentline++;
    $self->window->scrollok(1);
    $self->window->scrl(1);
    $self->window->scrollok(0);

    my $row = $self->height - $self->boxed - 1;
    $self->window->addstr($row,
                          $self->boxed(),
                          " " x ($self->width - ($self->boxed * 2)));
    $self->window->addstr($row,
                          $self->boxed * 2,
                          $self->Lines($currentline));

    # This takes care of the bottom arrow that's scrolled up
    $self->window->addstr($row - 3,
                          $self->width - $self->boxed - 1,
                          " ");
    $self->currentline($currentline);
    return 1;
  } else {
    return 0;
  }
}


sub LineUp {
my($self) = @_;
  my $currentline = $self->currentline();
  my $topline = $self->currentline - $self->height + 1;

  if ($topline > 0 ) {
    $currentline--;
    $topline--;

    $self->window->scrollok(1);
    $self->window->scrl(-1);
    $self->window->scrollok(0);

    $self->window->addstr(0,
                          $self->boxed,
                          " " x ($self->width - ($self->boxed * 2)));
    $self->window->addstr(0,
                          $self->boxed * 2,
                          $self->Lines($topline));
    # this gets rid of the top arrow that's scrolled down 
    $self->window->addstr(3,
                          $self->width - $self->boxed - 1,
                          " ");
    $self->currentline($currentline);
    return 1;
  } else {
    return 0;
  }
}


sub PageDown {
my($self) = @_;
  my $currentline = $self->currentline;

  # If we haven't shown the whole thing yet
  if ($currentline < $self->LineCount()) {
    $currentline -= 1;  # leave 2 of the old lines at the top
    $self->currentline($currentline);

    $self->Draw();
    return 1;
  } else {
    return 0;
  }
} # end PageDown

sub PageUp {
my($self) = @_;
  my $topline = $self->currentline - $self->height + 1;
  
  if ($topline > 0) {
    $topline -= $self->height + 1;  # keep 2 lines
    $topline = 0 if $topline < 0;  # Can't scroll past the "top" :)

    $self->currentline($topline);
    $self->Draw();

    return 1;
  } else {
    return 0;
  }
}


sub do_box {
my $self = shift;
  $self->{'boxed'} = 1;
  $self->window->box(@_);
}

sub boxed {
my($self,$val) = @_;
  if (defined $val) {
    $self->{'boxed'} = $val;
  } else {
    $self->{'boxed'} || 0;
  }
}

# A flag to tell Draw whether to center the text or not
sub center_justify {
my($self,$arg) = @_;
  if (defined $arg) {
    $self->{'center_justify'} = $arg;
  } else {
    $self->{'center_justify'};
  }
}



1;
