package Vmsgs::WidgetBase;

sub DEBUG {1;}

# This is a collection of methods used by most of the other Curses Widgets
# Mostly accessor functions 

sub state {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'state'} = $arg;
  } else {
    $self->{'state'};
  }
}

sub window {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'window'} = $arg;
  } else {
    $self->{'window'};
  }
}

sub panel {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'panel'} = $arg;
  } else {
    $self->{'panel'};
  }
}

sub titlebar {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'titlebar'} = $arg;
  } else {
    $self->{'titlebar'};
  }
}

sub titlepanel {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'titlepanel'} = $arg;
  } else {
    $self->{'titlepanel'};
  }
}
 
 
sub bottombar {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'bottombar'} = $arg;
  } else {
    $self->{'bottombar'};
  }
}

sub bottompanel {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'bottompanel'} = $arg;
  } else {
    $self->{'bottompanel'};
  }
}

sub msgsinterface {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'msgsinterface'} = $arg;
  } else {
    $self->{'msgsinterface'};
  }
}

sub msgslist {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'msgslist'} = $arg;
  } else {
    $self->{'msgslist'};
  }
}


# The line the cursor is currently on
sub currentline {
my($self,$arg) = @_;
  if (defined($arg)) {
    $self->{'cursorline'} = $arg;
  } else {
    $self->{'cursorline'};
  }
}


# Return a 5-char-max wide output of the current time
sub _PrintTime {
  my $time = scalar(localtime());

  ($time) = ($time =~ m/\s(\d+\:\d+)\:/);
  $time;
} # end _PrintTime


# Converts a floating-point number to a 3-char wide percentage.
# for 100% returns "ALL"
sub _Percentage {
my($self,$num) = @_;

  $num = int($num*100);

  if ($num >= 100) {
    "ALL";
  } else {
    "$num\%";
  }
} # end _Percentage


sub DESTROY {
my($self) = @_;
 
  $self->panel->del_panel() if ($self->{'panel'});
  $self->window->delwin() if ($self->{'window'});
 
  $self->titlepanel->del_panel() if ($self->{'titlepanel'});
  $self->titlebar->delwin() if ($self->{'titlebar'});
 
  $self->bottompanel->del_panel() if ($self->{'bottompanel'});
  $self->bottombar->delwin() if ($self->{'bottombar'});
}

1;

