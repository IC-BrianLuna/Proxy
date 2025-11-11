package CPL;

=head2

	CRUD for the frontend cpl.

=cut

use Util;
use Template;
use JSON::XS;
use Encode qw(decode_utf8 encode_utf8);
use strict;

my $util     = Util->new();
my $json     = JSON::XS->new->utf8(0);    # Expects Perl strings, outputs Perl strings
my $template = Template->new();

sub new {
	return bless {}, $_[0];
}

sub init {
	my ($self, %args) = @_;

	my $req      = $args{req};
	my $path     = $args{path};
	my $method   = $args{method};
	my $memory   = $args{memory};
	my $req_body = $args{req_body};

	if ($method eq 'GET') {
		my $result = '';
		my $vars   = { rows_json => $json->encode($memory) };
		$template->process('index.tt', $vars, \$result);
		$req->respond([200, 'OK', { 'Content-Type' => 'text/html; charset=utf-8' }, encode_utf8($result)]);
	} elsif ($method eq 'POST') {
		my $result = {};
		my ($id) = $path =~ m#/cpl\?id=(\d+)#;

		# Decode UTF-8 bytes to Perl strings.
		my $decoded_body = eval { decode_utf8($req_body, Encode::FB_CROAK) };

		if ($@) {
			# If decode fails, use the original body.
			print "CPL utf8 decode failed $@\n";
			$decoded_body = $req_body;
		}

		# Save into memory from the front-end cpl.
		if ($id) {
			my $json_error = $util->eval_json(str => $decoded_body);

			if ($json_error) {
				$result->{error} = 1;
				$result->{msg}   = $json_error;
			} else {
				$memory->{$id}{response}{body} = $decoded_body;
				$memory->{$id}{modified}       = 1;
				$result->{error}               = 0;
				$result->{msg}                 = 'memory saved';
			}
		} else {
			$result->{error} = 1;
			$result->{msg}   = 'no id';
		}

		my $body = $json->encode($result);

		$req->respond([
			200, 'OK',
			{
				'Content-Type'   => 'application/json; charset=utf-8',
				'Content-Length' => length(encode_utf8($body))
			},
			encode_utf8($body)
		]);
	} elsif ($method eq 'DELETE') {
		my $result = {};

		# Decode UTF-8 bytes to Perl strings.
		my $decoded_body = eval { decode_utf8($req_body, Encode::FB_CROAK) };

		if ($@) {
			# If decode fails, use the original body.
			$decoded_body = $req_body;
		}

		my $delete_ids = $json->decode($decoded_body);

		if (exists $delete_ids->{ids} && ref $delete_ids->{ids} eq 'ARRAY') {
			for my $id (@{ $delete_ids->{ids} }) {
				delete $memory->{$id};
			}

			$result->{error} = 0;
			$result->{msg}   = 'success';
		} else {
			$result->{error} = 1;
			$result->{msg}   = 'invalid params!';
		}

		my $body = $json->encode($result);

		$req->respond([
			200, 'OK',
			{
				'Content-Type'   => 'application/json; charset=utf-8',
				'Content-Length' => length(encode_utf8($body))
			},
			encode_utf8($body)
		]);
	}
}

1;
