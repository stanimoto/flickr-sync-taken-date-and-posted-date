#!/usr/bin/env perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/extlib/lib/perl5";
use local::lib "$Bin/extlib";
use Flickr::API;
use YAML;
use Data::Dumper;
use Getopt::Long;
use Time::Local 'timegm';

my $conf = YAML::LoadFile("$Bin/config.yaml")
    or die "Cannot load config file: $!";

my $flickr = flickr_login();

my $page = 0;
while (1) {
    my $res = $flickr->execute_method('flickr.photos.search', {
        auth_token => $flickr->{__auth_token},
        user_id => 'me',
        content_type => 1, # for photos only
        sort => 'date-taken-asc',
        per_page => $conf->{per_page} || 500,
        page => ++$page,
    });

    my $page_info = $res->{tree}{children}[1]{attributes};
    warn Dump $page_info;

    for my $elem (@{ $res->{tree}{children}[1]{children} }) {
        if (($elem->{name} || '') eq 'photo') {
            update_posted_date($elem->{attributes}{id});
        }
    }

    last if $page_info->{page} >= $page_info->{pages};
}

sub update_posted_date {
    my $photo_id = shift;

    my $res_get_info = $flickr->execute_method('flickr.photos.getInfo', {
        auth_token => $flickr->{__auth_token},
        photo_id => $photo_id,
    });

    my $taken;
    for my $elem (@{ $res_get_info->{tree}{children}[1]{children} }) {
        if (($elem->{name} || '') eq 'dates') {
            $taken = $elem->{attributes}{taken};
            last;
        }
    }

    if ($taken) {
        my @date = reverse split /[\-\s:]/, $taken;
        $date[-2] = $date[-2] - 1; # month
        my $time = timegm(@date);

        my $res_set_dates = $flickr->execute_method('flickr.photos.setDates', {
            auth_token => $flickr->{__auth_token},
            photo_id => $photo_id,
            date_posted => $time,
        });
    }
}

sub flickr_login {
    my $api = Flickr::API->new({
        key    => $conf->{apikey},
        secret => $conf->{apikey_secret},
    });
    my $res = $api->execute_method('flickr.auth.getFrob', {});

    my $frob = $res->{tree}{children}[1]{children}[0]{content};
    my $auth_url = $api->request_auth_url('write', $frob);

    while (1) {
        print "Authorize this app at:\n$auth_url\nHit Enter Key: ";
        sleep 2;
        `open "$auth_url"`;
        my $enter = <>;

        $res = $api->execute_method('flickr.auth.getToken', { frob => $frob });
        my $token = $res->{tree}{children}[1]{children}[1]{children}[0]{content};
        if ($token) {
            $api->{__auth_token} = $token;
            last;
        }
    }

    return $api;
}
