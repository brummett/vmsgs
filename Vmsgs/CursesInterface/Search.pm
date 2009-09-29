package Vmsgs::CursesInterface::Search;

# widget for the search dialogue box and preparing a new msgslist from the search

use Curses;
use Vmsgs::Debug;
use Vmsgs::CursesInterface::InputWindow;
use Vmsgs::CursesInterface::PromptWindow;

use strict;

our @ISA = qw ( Vmsgs::CursesInterface::PromptWindow );

sub new {
my($class,%args) = @_;
  my($self);

  $self = bless {},$class;

  $self->{'window'} = $class->SUPER::new(height => 6,
                                         width => 40,
                                         title => "Search by Criteria",
                                         choices => [["Body","B"],
                                                     ["From","F"],
                                                     ["Subject","S"]]);


  $self;
} # end new

our %CRITERIAS = ('F' => 'From',
                  'B' => 'Body',
                  'S' => 'Subject');

sub Run {
my($self) = @_;

  my $key = $self->{'window'}->input();
  if ($key eq "\033") {  # Escape key
    return ("quit");
  }

  $key = uc $key;
  my $criteria = $CRITERIAS{$key};

  my $win = Vmsgs::CursesInterface::InputWindow->new(height => 6,
                             width => 46,
                             inputlen => 30,
                             title => "Search by $criteria",
                             prompt => "Search expression");

  my $query = $win->input();

  return ("dosearch", ['read',lc($CRITERIAS{$key}),$query]);
}

1;
