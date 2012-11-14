#!/usr/bin/env perl

=head1 NAME

downloads.pl - Track the download of each resource

=head1 SYNOPSIS

Simple usage:

    downloads.pl http://www.google.com/ 

=head1 DESCRIPTION

Tracks all the downloads that are triggered for a starting page.

=cut

use strict;
use warnings;

use Glib ':constants';
use Gtk3 -init;
use Gtk3::WebKit;
use HTTP::Soup;
use Data::Dumper;
use Time::HiRes qw(time);
use Getopt::Long qw(:config auto_help);
use Pod::Usage;

my $TOTAL = 0;
my $START;
my $VERBOSE = 0;

sub main {
    GetOptions(
        'u|user=s'     => \my $user,
        'p|password=s' => \my $password,
        'v|verbose'    => \$VERBOSE,
    ) or pod2usage(1);
    my @urls = @ARGV or pod2usage(1);

    if (defined $user and defined $password) {
        require HTTP::Soup;

        # Remove the default authentication dialog so that we can provide our
        # own authentication method.
        my $session = Gtk3::WebKit->get_default_session();
        $session->remove_feature_by_type('Gtk3::WebKit::SoupAuthDialog');

        my $count = 0;
        $session->signal_connect('authenticate' => sub {
            my ($session, $message, $auth) = @_;
            if ($count++) {
                print "Too many authentication failures\n";
                Gtk3->main_quit();
            }
            $auth->authenticate($user, $password);
        });
    }

    my $loop = Glib::MainLoop->new();

    # Track all downloads
    my $session = Gtk3::WebKit->get_default_session();
    my %resources;
    $session->signal_connect('request-started' => \&tracker_cb, \%resources);

    my $view = Gtk3::WebKit::WebView->new();

    # Track once all downloads are finished
    $view->signal_connect('notify::load-status' => \&load_status_cb, [ $loop, \%resources ]);

    $START = time;
    foreach my $url (@urls) {
        $view->load_uri($url);

        $loop->run();
    }

    return 0;
}


# Called when WebKit is about to download a new resource (document, page, image, etc).
sub tracker_cb {
    my ($session, $message, $socket, $resources) = @_;
    ++$TOTAL;

    my $uri = $message->get_uri->to_string(FALSE);
    my $start = time;
    my $resource = $resources->{$uri} = {};
    $resource->{start} = time;
    $resource->{uri} = $uri;
    $message->signal_connect("finished" => sub {
        my $end = $resource->{end} = time;
        my $elapsed = $resource->{elapsed} = $end - $start;
        my $status_code = $resource->{status_code} = $message->get('status-code') // 'undef';
        #printf "Downloaded %s in %.2f seconds; code: %s\n", $uri, $elapsed, $status_code;

        my $headers = $message->get('response-headers');
        $headers->foreach(sub {
            my ($name, $value) = @_;
            print "Header: $name => $value\n" if $VERBOSE;
        });
    });

    return;
}


# Called when webkit updates it's 'load-status'.
sub load_status_cb {
    my ($loop, $resources) = @{ pop @_ };
    my ($view) = @_;

    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';
    my $end = time;

    my $frame = $view->get_main_frame;
    my $data_source = $frame->get_data_source;
    return if $data_source->is_loading;

    my $bytes = 0;
    foreach my $resource ($data_source->get_main_resource, @{ $data_source->get_subresources }) {
        my $uri = $resource->get_uri;
        next if $uri eq 'about:blank';

        my $data = $resources->{$uri};
        my $time;
        if (! $data) {
            print "Can't find data for $uri\n";
            $time = "???";
        }
        else {
            $time = $resources->{$uri}{elapsed};
            $time = defined $time ? sprintf "%.2f", $time : 'undef';
        }
        my $size = length($resource->get_data // '');
        $bytes += $size;
        my $mime = $resource->get_mime_type // 'No mime-type';
        my $status_code = $data->{status_code} // 'undef';
        printf "%s %d bytes; %s (%s) in %s sec\n", $uri, $size, $mime, $status_code, $time
            if $VERBOSE;
    }

    printf "Downlodaded $TOTAL resources with $bytes bytes in %.2f seconds\n", $end - $START;
    $loop->quit();
}


exit main() unless caller;
