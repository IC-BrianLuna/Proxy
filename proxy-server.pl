#!/usr/bin/perl -w

use lib qw(lib);

use WS;
use URI;
use CPL;
use Util;
use strict;
use JSON::XS;
use AnyEvent;
use YAML::XS;
use MIME::Base64;
use Encode qw(decode_utf8 encode_utf8);
use AnyEvent::HTTPD;
use List::Util     qw(first);
use AnyEvent::HTTP qw(http_request);

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

my $config      = YAML::XS::LoadFile('proxy.yml');
my $memory      = {};
my $memory_idx  = 0;
my $interface   = $config->{Server}{Interface};
my $listen_port = $config->{Server}{'Listen Port'};
my $upstream    = (first { $_->{Name} eq 'Ballast' } @{ $config->{Services} })->{'Upstream'};
my $base        = URI->new($upstream);
my $json        = JSON::XS->new->utf8(0);
my $util        = Util->new();
my $cpl         = CPL->new();
my $ws          = WS->new();

my $httpd = AnyEvent::HTTPD->new(
	host            => $interface,
	port            => $listen_port,
	allowed_methods => [qw(GET HEAD POST OPTIONS PUT PATCH DELETE)]
);

$ws->init(interface => $interface, memory => $memory);

$httpd->reg_cb(
	request => sub {
		my ($httpd, $req) = @_;

		my $method     = $req->method;
		my $path       = $req->url;
		my $req_body   = $req->content // '';
		my $headers_in = { %{ $req->headers // {} } };

		# Wildcard allow origin.
		$headers_in->{'Access-Control-Allow-Origin'} = "*";

		# Set the destination path.
		my $up = $base->clone;
		$up->path_query($path);

		if ($method eq 'OPTIONS') {
			send_options(headers_in => $headers_in, base => $base, req => $req, up => $up);
		} else {
			if ($path =~ /^\/cpl/) {
				$cpl->init(req => $req, method => $method, memory => $memory, req_body => $req_body, path => $path);
			} else {
				my $has_memory = 0;

				my $req_base64 = encode_base64($req_body);

				for my $key (keys %$memory) {
					my %record = %{ $memory->{$key} // {} };

					if ($record{method} eq $method && $record{path} eq $up && $record{request}{base64} eq $req_base64) {
						my $status          = $record{status};
						my $response_header = $record{response}{header};
						my $response_body   = $record{response}{body};

						# Encode Perl strings back to UTF-8 bytes for HTTP response.
						my $encoded_body = eval { encode_utf8($response_body) } || $response_body;

						$response_header->{'content-length'} = length($encoded_body);
						$response_header->{'content-type'}   = 'application/json; charset=utf-8';

						$req->respond([$status, $response_header->{Reason}, $response_header, $encoded_body]);
						$has_memory = 1;

						last;
					}
				}

				# Respond with what came into the request.
				if (!$has_memory) {
					send_response(headers_in => $headers_in, method => $method, body => $req_body, req => $req, up => $up);
				}
			}
		}
	}
);

# Pre-flight CORS.
sub send_options {
	my (%args) = @_;

	my $headers_in = $args{headers_in};
	my $base       = $args{base};
	my $req        = $args{req};
	my $up         = $args{up};

	my %forward = %{$headers_in};
	$forward{'Host'} = $base->host;

	http_request
	  OPTIONS    => "$up",
	  headers    => \%forward,
	  timeout    => 30,
	  persistent => 1,
	  recurse    => 0,
	  body       => '',
	  sub {
		my ($response_body, $response_header) = @_;

		$response_header = ref $response_header eq 'HASH' && %$response_header ? $response_header : {};

		my $status = $response_header->{Status} || 502;
		my $reason = $response_header->{Reason} || 'Bad Gateway';

		$response_body = defined $response_body ? $response_body : '';
		$response_header->{'Vary'} = $response_header->{'Vary'} ? $response_header->{'Vary'} : 'Origin';

		$req->respond([$status, $reason, $response_header, $response_body]);
	  };
}

# Handle request method types.  Save in cache.
sub send_response {
	my (%args) = @_;

	my $headers_in = $args{headers_in};
	my $method     = $args{method};
	my $req_body   = $args{body};
	my $req        = $args{req};
	my $up         = $args{up};

	my %client_options = (
		headers    => $headers_in,
		body       => $req_body,
		persistent => 1
	);

	http_request $method => "$up",
	  %client_options, sub {
		my ($response_body, $response_header) = @_;

		my $status = $response_header->{Status} ? $response_header->{Status} : 502;

		# Save only json with no errors.
		if ($status == 200) {
			$memory_idx++;

			my $decoded_req_body      = eval { decode_utf8($req_body) }      || $req_body;
			my $decoded_response_body = eval { decode_utf8($response_body) } || $response_body;

			$memory->{$memory_idx} = {
				date     => time,
				method   => $method,
				path     => $up->as_string,
				status   => $status,
				length   => length($response_body),
				modified => 0,
				request  => {
					body   => $decoded_req_body,
					base64 => encode_base64($decoded_req_body)
				},
				response => {
					header => $response_header,
					body   => $decoded_response_body
				}
			};

			$ws->broadcast_memory(memory => $memory);
		}

		$req->respond([$status, $response_header->{Reason}, $response_header, $response_body]);
	  };
}

print "Pass though Proxy is running on http://$interface:$listen_port/\n";
$httpd->run;
