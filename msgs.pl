#!/usr/bin/perl
#
# The msgs back-end library code.  April, 1998
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
$MSGS_PL_VERSION="2.03";
# Written by:
#    Kees Cook             (cook@cpoint.net)
#    Tony Brummet          (tony@blight.com)
#    Ian Cardenas          (agave@blight.com)
#
# The local/remote API for msgs interfacing
#
# InitializeMsgsAPI             must run first!
# ShutdownMsgsAPI		run when quitting
# Post([entire text of post -- headers & body])  returns undef on failure
# GetMessage([msg # you want])  returns all text -- header & body  fail=undef
# GetBounds			returns array ($first,$last) undef on fail
# GetLogname			returns the remote login name
# ReadRC			return the value in ~/.msgsrc, undef on fail
# SetRC(value)			return the value you just sent, undef on fail
# ForcedSetRC(value)		return the value you just sent, undef on fail
# Arg0Client(client name)       must have "msgs" in the string
# Arg0Tagline(tagline)          any cute quote
# Arg0Status(status)            should be one of:
#                                       running
#                                       reading #
#                                       replying to #
#                                       posting

# Global variable "$LOCAL" needs to be defined before require'ing this
# Global variable "$OLDSCHOOL" needs to be defined before require'ing this

$MSGSDIR="/var/msgs/";			# Must end with a "/"
$SERVER="your.server.here";		# For remote msgs
$PORT=7777;

# Arg0 vars
$ARG0_OLD=undef;
$ARG0_CLIENT=undef;
$ARG0_TAGLINE=undef;
$ARG0_STATUS=undef;

# Linux settings (change SOCK_STREAM to 2 if Solaris)
$AF_INET=2;
$SOCK_STREAM=1;
$sockaddr='S n a4 x8';

$LOCK_SH=1; $LOCK_EX=2; $LOCK_UN=8;# flock constants for file locking

sub UnIdle {
    local($now);
    $now=time;
    utime $now, $now, $MSGSRC;
}

sub Arg0Set {
    if (!defined($ARG0_CLIENT) || !defined($ARG0_TAGLINE))
    {
        $0=$ARG0_OLD if (defined($ARG0_OLD));
        return undef;
    }

    $ARG0_OLD=$0 if (!defined($ARG0_OLD));

    $0="$ARG0_CLIENT: $ARG0_TAGLINE";
    $0.=" ($ARG0_STATUS)" if (defined($ARG0_STATUS));

    return 1;
}

sub Arg0Client {
    local($string)=@_;

    return undef if ($string !~ /msgs/i);
    $ARG0_CLIENT=$string;
    Arg0Set();

    return 1;
}

sub Arg0Tagline {
    local($string)=@_;
    $ARG0_TAGLINE=$string;
    Arg0Set();

    return 1;
}

sub Arg0Status {
    local($string)=@_;
    $ARG0_STATUS=$string;
    Arg0Set();
    UnIdle();

    return 1;
}

sub NetLogin {
    local($login,$password,$encrypted) = @_;
    local($hostname,$name,$aliases,$proto,$type,$len,$thisaddr,$thataddr);
    local($this,$that);

    chomp($hostname = `hostname`);
    ($name,$aliases,$proto)=getprotobyname('tcp');
    ($name,$aliases,$type,$len,$thisaddr)=gethostbyname($hostname);
    ($name,$aliases,$type,$len,$thataddr)=gethostbyname($SERVER);

    $this = pack($sockaddr,$AF_INET,0,$thisaddr);
    $that = pack($sockaddr, $AF_INET,$PORT,$thataddr);

    if (socket(REMOTE,$AF_INET,$SOCK_STREAM,$proto)) {
      ; } else { warn "socket: $!\n"; return undef;}
    if (bind(REMOTE,$this)) {
      ; } else { warn "bind: $!\n"; return undef; }
    if (connect(REMOTE,$that)) {
      ; } else { warn "connect: $!\n"; return undef; }

    select(REMOTE);
    $|=1;
    select(STDOUT);

    print REMOTE "logon $login ${password}\n" if ($encrypted != 1);
    print REMOTE "cryptlogon $login ${password}\n" if ($encrypted == 1);

    chomp($encrypted = <REMOTE>);
    print "Bad login (try removing ~/.msgslogin ?)\n" 
	if (!defined($encrypted) || $encrypted =~ /^ERROR:/);
    $LOGIN=$login;
    return undef if ($encrypted =~ /^ERROR:/);
    return $encrypted;
}

sub GetLogname {
   if ($LOCAL == 1) {
	return $ENV{'LOGNAME'};
   }
   else {
	return $LOGIN;
   }
}

sub EndLogin {
    print REMOTE "quit\n";
    close REMOTE;
}

# Read user's login and password
sub InitializeMsgsAPI {
   if ($LOCAL != 1) {
	if (!open(FILE,"<${ENV{'HOME'}}/.msgslogin")) {
		print "Lucien login: ";
		chomp($login = <STDIN>);
		`stty -echo`;
		$password = "";
		$again = " ";
		while ($password ne $again) {
			print "Lucien password: ";
			chomp($password = <STDIN>);
			print "\n";
			print "Again: ";
			chomp($again = <STDIN>);
			print "\n";
			print "Does not match.\n" if ($password ne $again);
		}
		`stty echo`;
		$encrypted = &NetLogin($login,$password,0);
	}
	else {
		($login,$password) = split(/\s+/,scalar(<FILE>));
		close FILE;
		chomp($password);
		$encrypted = &NetLogin($login,$password,1);
	}
	die "Cannot connect to msgs server.\n" if (!defined($encrypted));
	open(FILE,">${ENV{'HOME'}}/.msgslogin");
	print FILE "$login $encrypted\n";
	close FILE;
	chmod 0600, "${ENV{'HOME'}}/.msgslogin";
   }
   else {
	$BOUNDS="${MSGSDIR}.bounds";
	$MSGSRC="${ENV{'HOME'}}/.msgsrc"; # build the full pathname for .msgsrc
   }
}

sub ReadRC {
  local($last);

  if ($LOCAL == 1) {
        $last=undef;
        # if a person is just starting msgs, show them the last 10
        local($min,$newlast);
        ($min,$newlast)=GetBounds();
        $newlast-=10;
        $newlast=$min if ($min > $newlast);

        # open .msgsgrc file
        if (open(MSGSRC,"<$MSGSRC")) {
                # read the data & close
                chomp($last = <MSGSRC>);
                close(MSGSRC);
        }
        if ($last < 1)
        {
                $last=$newlast;
        }
  }
  else {
	print REMOTE "rc-read\n";
	chop($last = <REMOTE>);
	return undef if ($last =~ /^ERROR:/);
  }
  $last;  # return the data
}

sub ForcedSetRC {
  local($last)=@_;
  return SetRC($last,1);
}

sub SetRC {
  local($last,$force) = @_;
  local($previous);

  $previous=ReadRC();
  return undef unless (defined($previous));
  return $previous if (!defined($force) && $last < $previous);
  
  if ($LOCAL == 1) {

        # attempt to open .msgsrc
        if (!open(MSGSRC,">$MSGSRC")) {
		undef $last;
        }
        else {
                # write the data and close file
                print MSGSRC "$last\n";
                close(MSGSRC);
        }
  }
  else {
	print REMOTE "rc-set $last\n";
	$last = <REMOTE>;
	return undef if ($last =~ /^ERROR:/);
  }
  $last;
}

sub ShutdownMsgsAPI {
   if ($LOCAL != 1) {
	&EndLogin;
   }
}

# Commit will write text to a file
sub Post {
   local($text) = @_;

   #protocol calls for all .'s that exist on a single line
   #to have an additional . tagged on
   $text =~ s/^(\.+)$/$1./gm;

   chomp($text);
   $text.="\n";
   if ($LOCAL == 1) {
	local($mod,$oldmask,@bounds);

	@bounds = &IncBounds;  # FIXME: we need to hold the bounds file
	die "Cannot open $BOUNDS: $!\n" if (!defined(@bounds));
	(undef,$fname) = @bounds;
	$mod="";
	if ($OLDSCHOOL != 1) {
		$mod = int($fname / 1000);
		$mod = $mod * 1000;
		$mod = 1000 if ($mod == 0);

		if (! -d "${MSGSDIR}${mod}.dir") {
			system("/usr/local/sbin/msgsmkdir $mod");
			$exit_value = $? >> 8;

			if ($exit_value != 0) {
				die "cannot access directory ${MSGSDIR}$mod: $!\n";
			}
		}
		$mod .= ".dir/";
	}

	# attempt to open the file named $fname in $MSGSDIR
	open(FILE,">${MSGSDIR}${mod}${fname}") ||
		return undef;
	print FILE $text;	# write the text to the file
	close(FILE);		# close the file
# was used to remain compatible with old school msgs
#	system("ln ${MSGSDIR}${mod}${fname} ${MSGSDIR}${fname}");
   }
   else {
	local(@text,$line);

	$text .= "\n" if ($text !~ /\n$/);
	print REMOTE "post\n";
	@text = split(/\n/,$text);
	foreach $line (@text) {
		print REMOTE "${line}\n";
	}
	print REMOTE ".\n";
	chomp($fname = <REMOTE>);
	return undef if ($fname =~ /^ERROR:/);
  }
  return $fname;
}

sub GetMessage {
	local($which) = @_;
	local(@text,$next);

   undef @text;
   if ($LOCAL == 1) {

	$mod = int($which / 1000);
	$mod = $mod * 1000;
	$mod .= ".dir/";

	# try to read the file
	if (-f "${MSGSDIR}${mod}${which}") {
		open(FILE,"<${MSGSDIR}${mod}${which}") ||
			return ();
#		$uid = (stat("${MSGSDIR}${mod}${which}"))[4];
	}
	else {
		open(FILE,"<${MSGSDIR}${which}") ||
			return ();
#		$uid = (stat("$MSGSDIR$which"))[4];
	}

	@text = <FILE>;
	close(FILE);
    }
    else {
	print REMOTE "msg ${which}\n";
	$next = <REMOTE>;
	return () if ($next =~ /^ERROR:/);
        # toss the "OK" line
	while (defined($next = <REMOTE>) && $next !~ /^\.\n$/) {
		push(@text,$next);
	}
    }
    # strip off any additional .'s required by protocol
    grep(s/^\.(\.+\n)$/$1/,@text);

    if (@text) {
       chomp($text[$#text]);
       $text[$#text].="\n";
    }
    @text;
}

sub GetHeader {
	local($which) = @_;
	local(@text,$next);

   undef @text;
   if ($LOCAL == 1) {
        @text = &GetMessage($which);
	return undef if (! scalar(@text));
        $next=0;
        $len=$#text;
        while ($text[$next] ne "\n") {
          last if ($next++ == $#text);
        }
        $#text=$next-1;
    }
    else {
	print REMOTE "header ${which}\n";
	$next = <REMOTE>;
	return undef if ($next =~ /^ERROR:/);
        # toss the "OK" line
	while (defined($next = <REMOTE>) && $next !~ /^\.\n$/) {
		push(@text,$next);
	}
    }

    if (@text) {
       chomp($text[$#text]);
       $text[$#text].="\n";
    }
    @text;
}

sub GetBody {
	local($which) = @_;
	local(@text,$next);

   undef @text;
   if ($LOCAL == 1) {
        @text = &GetMessage($which);
        return undef if (! scalar(@text));
        while (shift(@text) =~ m/\w/) {;}
    }
    else {
	print REMOTE "body ${which}\n";
	$next = <REMOTE>;
	return undef if ($next =~ /^ERROR:/);
        # toss the "OK" line
	while (defined($next = <REMOTE>) && $next !~ /^\.\n$/) {
 		# strip off any additional .'s required by protocol
		$next =~ s/^(\.{2,})\n$/substr($1,0,-1) . "\n"/e;

		push(@text,$next);
	}
    }

    if (@text) {
       chomp($text[$#text]);
       $text[$#text].="\n";
    }
    @text;
}


# write the bounds file
sub IncBounds {
	local($first,$last);

	# try to open for writting
	if (!open(BOUNDS,"+<$BOUNDS")) {
		&GetBounds;
		return undef if (!open(BOUNDS,"+<$BOUNDS"));
	}
	# print & close
	flock(BOUNDS,$LOCK_EX);
	seek(BOUNDS,0,0);
	$first = <BOUNDS>;
	($first,$last) = split(/\s+/,$first);
	$last++;
	seek(BOUNDS,SEEK_SET,0);
	print BOUNDS "$first $last\n";
	flock(BOUNDS,$LOCK_UN);
	close(BOUNDS);
        ($first,$last);
}	

# read the bounds
sub GetBounds {
	local($first,$last,@bounds,$oldmask);


#   print "calling GetBounds\n";
   if ($LOCAL == 1) {
	# try to open the bounds file
	if (!open(BOUNDS,"<$BOUNDS")) {
		$oldmask=umask();
		umask(0000);
		$first=$MSGSDIR;
		chop($first);
		@bounds=split(/\//,$first);
		undef $first;
		while (@bounds) {
			$first.="/".shift @bounds;
			if (! -d "$first" && !mkdir($first,0755)) {
				die "Cannot make directory '$first': $!\n";
			}
		}
		chmod 03777, $first;
		open(BOUNDS,">$BOUNDS");
		flock(BOUNDS,$LOCK_EX);
		seek(BOUNDS,0,0);
		print BOUNDS "1 0\n";
		flock(BOUNDS,$LOCK_UN);
		close(BOUNDS);
		umask($oldmask);
#   		print "new Bounds\n";
		open(BOUNDS,"<$BOUNDS") ||
			return undef;
	}
	flock(BOUNDS,$LOCK_EX);
	seek(BOUNDS,0,0);
	# read and split on the white space
	($first, $last) = split(/\s+/,scalar(<BOUNDS>));
	flock(BOUNDS,$LOCK_UN);
	close(BOUNDS);
#	print "read Bounds\n";
	$bounds[0] = $first;
	$bounds[1] = $last;
   }
   else {
	print REMOTE "bounds\n";
	@bounds = split(/\s+/,scalar(<REMOTE>));
	return undef if ($bounds[0] =~ /^ERROR:/);
   }
#   print "Bounds: $bounds[0] $bounds[1]\n";
   @bounds;	# return both lowest and highest msg number
}	

1;
