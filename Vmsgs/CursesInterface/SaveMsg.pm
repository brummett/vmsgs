package Vmsgs::CursesInterface::SaveMsg;

# Widget for handling saving a msg to a file

use Curses;
use Vmsgs::CursesInterface::InputWindow;
use IO::File;

use strict;

our @ISA = qw ( Vmsgs::CursesInterface::InputWindow );

sub new {
my($class, %args) = @_;
  my($self,$msgid);

  $msgid = $args{'msgid'};

  $self = Vmsgs::CursesInterface::InputWindow::new($class, height => 6,
                             width => 46,
                             inputlen => 30,
                             title => "Save",
                             prompt => "Filename to save msg $msgid into");

  $self->Debug("Created new SaveMsg widget $self");

  $self->{'msgid'} = $args{'msgid'};
  $self->msgsinterface($args{'msgsinterface'});

  $self;
} # end new


sub Run {
my($self) = @_;
  my($input,$fh,$string);

  update_panels();
  doupdate();
  $input = $self->input();

  if (length($input)) {  # If they entered anything
    $self->Debug("attempting to append to filename $input");
    $fh = new IO::File ">>$input";
    if (!$fh) {
      my $win = new Vmsgs::CursesInterface::PromptWindow(height => 5,
                                                         width => 30,
                                                         title => "Error",
                                                         message => "Can't append to $input: $!");
      $win->input();
    } else {
      $string = $self->msgsinterface->Get($self->{'msgid'})->Textify();
      $self->Debug(sprintf("Saving %d bytes to the file", length($string)));
      print $fh $string, "\n";
      close $fh;
    }  
  } # end if

  ("quit", undef);
} # end Run

1;

