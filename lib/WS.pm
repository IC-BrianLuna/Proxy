package WS;

use strict;
use warnings;
use JSON::XS;
use AnyEvent::Socket;
use AnyEvent::WebSocket::Server;
use Scalar::Util qw(refaddr);

my $json    = JSON::XS->new->utf8(1)->canonical(1);
my $ws_port = 8002;
my $ws      = AnyEvent::WebSocket::Server->new();

# Keep live connections
my @clients;

sub new {
	return bless {}, $_[0];
}

sub init {
	my ($self, %args) = @_;

	my $memory    = $args{memory};
	my $interface = $args{interface};

	tcp_server $interface, $ws_port, sub {
		my ($fh) = @_;

		$ws->establish($fh)->cb(sub {
			my $conn = eval { shift->recv };
			return if $@ || !$conn;

			push @clients, $conn;

			# Initial snapshot.
			$conn->send($self->memory_json(memory => $memory));

			# On close: drop this exact connection from the list.
			my $id = refaddr($conn);

			$conn->on(
				finish => sub {
					@clients = grep { refaddr($_) != $id } @clients;
				}
			);
		});
	};

	print "Websocket is running on ws://$interface:$ws_port/\n";
}

sub broadcast_memory {
	my ($self, %args) = @_;
	my $memory  = $args{memory};
	my $payload = $self->memory_json(memory => $memory);

	# Try to send; if it throws, prune that client
	my @still_alive;

	for my $c (@clients) {
		my $ok = eval { $c->send($payload); 1 };
		push @still_alive, $c if $ok;
	}

	@clients = @still_alive;
}

sub memory_json {
	my ($self, %args) = @_;
	return $json->encode($args{memory});
}

1;
