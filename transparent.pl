#!/usr/bin/env perl

=head1 NAME

transparent.pl - Load a page with a transparent background

=head1 SYNOPSIS

transparent.pl file://$PWD/sample.html

=head1 DESCRIPTION

Loads an URI and displays the page in a transparent window. The page must use
the following CSS rule:

    body {
        background-color: rgba(0,0,0,0);
    }

=cut

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use Gtk2 -init;
use Gtk2::WebKit;
use Data::Dumper;


sub main {
    die "Usage: url\n" unless @ARGV;
    my ($url) = @ARGV;

    my $window = Gtk2::Window->new('toplevel');
    my $screen = $window->get_screen;
    my $rgba = $screen->get_rgba_colormap;
    if ($rgba and $screen->is_composited) {
        Gtk2::Widget->set_default_colormap($rgba);
        $window->set_colormap($rgba);
    }

    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk2->main_quit() });
    $window->set_decorated(FALSE);

    my $view = Gtk2::WebKit::WebView->new();
    $view->set_transparent(TRUE);

    # Pack the widgets together
    $window->add($view);
    $window->show_all();

    $view->load_uri($url);
    $view->grab_focus();

    Gtk2->main;
    return 0;
}


exit main() unless caller;
