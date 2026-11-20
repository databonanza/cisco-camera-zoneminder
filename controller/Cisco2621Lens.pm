package ZoneMinder::Control::Cisco2621Lens;

use strict;
use warnings;
use parent 'ZoneMinder::Control';

use HTTP::Request::Common qw(GET POST);
use IO::Socket::SSL qw(SSL_VERIFY_PEER);
use LWP::UserAgent;
use URI;
use URI::Escape qw(uri_unescape);
use ZoneMinder::Logger qw(Error);

sub open {
    my ($self) = @_;
    $self->loadMonitor();

    my $stream = URI->new($self->{Monitor}->{Path});
    my $fingerprint = $self->{Monitor}->{ControlDevice} // '';
    my $host = $stream->host // '';
    my ($username, $password) = split /:/, ($stream->userinfo // ''), 2;
    if ($host !~ /\A[0-9.]+\z/ || $fingerprint !~ /\A[0-9a-fA-F]{64}\z/
        || !defined($username) || !defined($password)) {
        Error('Cisco lens control requires an authenticated camera address and its certificate fingerprint');
        return;
    }

    $self->{base_url} = 'https://' . $host;
    $self->{username} = uri_unescape($username);
    $self->{password} = uri_unescape($password);
    $self->{ua} = LWP::UserAgent->new(
        timeout => 6,
        max_redirect => 0,
        protocols_allowed => ['https'],
        ssl_opts => {
            verify_hostname => 0,
            SSL_verify_mode => SSL_VERIFY_PEER,
            SSL_fingerprint => 'sha256$' . $fingerprint,
            SSL_version => 'TLSv1',
            SSL_cipher_list => 'DEFAULT:@SECLEVEL=0',
        },
    );
    $self->{state} = 'open';
}

sub close {
    my ($self) = @_;
    $self->{state} = 'closed';
}

sub lens_request {
    my ($self, $request) = @_;
    return unless $self->{ua};
    $request->authorization_basic($self->{username}, $self->{password});
    my $response = $self->{ua}->request($request);
    if (!$response->is_success) {
        Error('Cisco camera rejected a lens request');
        return;
    }
    return $response->decoded_content;
}

sub lens_position {
    my ($self, $axis) = @_;
    return unless $axis eq 'zoom' || $axis eq 'focus';
    my $body = $self->lens_request(GET $self->{base_url} . "/io/query_${axis}.cgi");
    return $1 if defined($body) && $body =~ /\A${axis}_position=(\d{1,4})\s*\z/;
    return;
}

sub move_lens {
    my ($self, $axis, $step) = @_;
    my $position = $self->lens_position($axis);
    return unless defined($position);
    $position += $step;
    $position = 1 if $position < 1;
    $position = 1024 if $position > 1024;
    return $self->set_lens($axis, $position);
}

sub set_lens {
    my ($self, $axis, $position) = @_;
    return $self->lens_request(POST $self->{base_url} . "/io/${axis}ctrl.cgi",
        { "${axis}_position" => $position });
}

sub zoomRelWide  { shift->move_lens('zoom', -5); }
sub zoomRelTele  { shift->move_lens('zoom', 5); }
sub focusRelNear { shift->move_lens('focus', -5); }
sub focusRelFar  { shift->move_lens('focus', 5); }
sub focusAuto    { shift->set_lens('focus', -1); }

1;
