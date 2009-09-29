package Vmsgs::CursesInterface::Search;

# widget for the search dialogue box and preparing a new msgslist from the search

use Curses;
use Vmsgs::Debug;
use Vmsgs::CursesInterface::InputWindow;
use Vmsgs::CursesInterface::PromptWindow;

use strict;

our @ISA = qw ( Vmsgs::Debug );

sub new {
my($class,%args) = @_;
  my($self);

  $self = bless {},$class;

#  $self->start_debug(".vmsgs.debug");
  $self->Debug("Creating new Search widget");

  $self->{'window'} = new Vmsgs::CursesInterface::PromptWindow(height => 6,
							width => 40,
							title => "Search",
				message => "Sorry, Search isn't working yet");

  $self;
} # end new


sub Run {
my($self) = @_;

  $self->Debug("In Run");
  $self->{'window'}->input();

  return ("quit", undef);
}

1;
