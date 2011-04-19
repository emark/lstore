#!/usr/bin/env perl
use strict;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use Mojolicious::Lite;
use DBI;
use utf8;

open (DBCONF,"< db.conf") || die "Error open dbconfig file";
my $dbconf=<DBCONF>;
close DBCONF;
our $dbh = DBI->connect($dbconf,'locumtes_STORE86', '123456',
			{ PrintError => 0, RaiseError => 1 });
$dbh->{'mysql_enable_utf8'} = 1;
$dbh->do('SET NAMES utf8');

get '/' => sub{
    my $self=shift;
    $self->render(text=>'Hello storesto!');
};

app->secret('storestosecret');
app->start;



















