#!/usr/bin/env perl
use strict;
use lib "/home/hosting_locumtest/usr/local/lib/perl5";
use Mojolicious::Lite;
use DBI;
use utf8;

open (DBCONF,"< db.conf") || die "Error open dbconfig file";
my @dbconf=<DBCONF>;
close DBCONF;
chomp @dbconf;
our $dbh = DBI->connect($dbconf[0],$dbconf[1],$dbconf[2],
			{ PrintError => 0, RaiseError => 1 });
$dbh->{'mysql_enable_utf8'} = 1;
$dbh->do('SET NAMES utf8');

get '/' => sub{
    my $self=shift;
    $self->render(text=>'Hello storesto! Coming soon!');
};

get 'kitchen'=>sub{
  my $self=shift;
  $self->render('kitchen');
};

app->secret('storestosecret');
app->start;
__DATA__

@@ kitchen.html.ep
% layout 'kitchenarea', title 'My kitchen';
<%= link_to 'Create recipe'=>'recipe' %> / <%= link_to 'Open refrigirator'=>'ingredients' %>

@@ layouts/kitchenarea.html.ep
<title><%= title %></title>
<body><%= content %></body>


















