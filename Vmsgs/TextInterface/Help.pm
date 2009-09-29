package Vmsgs::TextInterface::Help;

use strict;

sub new {
my($class,%args) = @_;

  bless {},$class;
}

sub Run {
my($self) = @_;

  print "
y	- Read this message (default)
n	- Skip to the next message
r	- Reply to this message
p	- Post a new message
b [#]	- Skip back # messages (default is 1)
|	- Pipe this message through a Unix command
h/?	- This help screen
q	- quit\n";

return ("quit",undef);
} # end Run

1;
