#!/usr/bin/perl

# Copyright 2012 Marcin Adamowicz <martin.adamowicz@gmail.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


##### Description #####
# This AGI script callects all connected peers and calls them with
# emergency message. Quite usefully in case of fire in the building.


# Include modules.
use Data::Dumper;
use Asterisk::AMI;
use Asterisk::AMI::Common;
use Asterisk::AGI;

# Initiate AGI handler.
my $AGI = new Asterisk::AGI;		
use Thread;
use MIME::Lite; 

# Configuration variables.
my $HOST = "127.0.0.1";
my $PORT = "5038";
my $AMIUSER = "emergency";
my $AMIPASS = "SECRET";
my %input = $AGI->ReadParse();

#################### Main ####################

# Take caller ID given by AGI.
my $CallerID = $ARGV[0];

# Connect to AMI.
my $astman = Asterisk::AMI::Common->new(
        PeerAddr => "$HOST",
	PeerPort => "$PORT",
	Username => "$AMIUSER",
	Secret => "$AMIPASS",
	OriginateHack => '1',
        Events => 'on'); 
		die "Unable to connect to asterisk" unless ($astman);


my $sip_peers = $astman->sip_peers();	# Take SIP peers.
my %HashOfSips = %$sip_peers;		# Convert hash reference to hash.
my $SizeOfHash = keys(%HashOfSips);	# Size of the hash into scalar.

my $Counter = 0;
while (my $key = each(%HashOfSips) ) {
	next if $sip_peers->{$key}->{'IPport'} =~ /^0/;	# Registered peers.
	next if $key !~ /^(softphone|[0-9])/;		# Remove non-users.
	next if $key !~ /^softphone1812/;		# Locker for test.
	next if $key =~ /^$CallerID/;			# Exclude caller.
	my $thr = threads->create(\&CALL,$key);		# Launch thread &CALL
	$Counter++;
}

my $ListRunning = threads->list(threads::running);	# Running threads.

# AMI originate subroutines.
sub CALL {
	
	my $EXTEN = $_[0];				# Number to be called.
	$astman->action( { Action => 'Originate',	# AMI 'Originate'
		Channel => "SIP/$EXTEN",		# Channel name.
		Context => 'users',			# Dialplan Context.
		Exten => "$EXTEN",			# Extension.
		Async => 1,				# Async originate.
		Priority => 1,				# Priority 1.
		Timeout => 15000,			# Answer timeout (ms)	
		Callerid => 'TEST EMERGENCY'});		# Caller ID

	}
# Send to Asterisk console EmeMsg variable.
$AGI->set_variable('EmeMsg', "Emergency launched by: $CallerID. There was/were: $ListRunning thread(s). Number of active peers: $Counter");

$astman->disconnect() unless ($ListRunning eq "0");	# Stop AMI if 0 thread. 

# Send an email.
my $msg = MIME::Lite->new(

	From	=>	'plbypbx01@example.com',
	To	=>	'marcin.adamowicz@example.com', 
	Subject	=>	"Emergency script", 
	Type	=>	'multipart/mixed'

); 
$msg->attach(
	Type => 'TEXT',
	Data	=>	"Emergency called by: $CallerID.
There was/were: $ListRunning thread(s).
Number of active peers which might have answered the call: $Counter"
);
$msg->send;
