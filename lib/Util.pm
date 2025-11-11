package Util;

use strict;
use JSON::XS;

my $json = JSON::XS->new->utf8(0);    # Expects Perl strings, outputs Perl strings

sub new {
	return bless {}, $_[0];
}

sub eval_json {
	my ($self, %args) = @_;

	my $json_error = '';
	my $str        = $args{str};

	$str =~ s/^\s+|\s+$//g;

	eval { $json->decode($str); 1 } or do {
		chomp($json_error = $@ || 'invalid JSON');
	};

	return $json_error;
}

1;
