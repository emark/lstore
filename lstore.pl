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

get '/kitchen'=>sub{
  my $self=shift;
  $self->render('kitchen');
};

get '/ingredients'=>sub{
  my $self=shift;
  my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID",'ID');
  $self->stash(ingredients=>$ingredients);
  $self->render('ingredients');
};

get '/ingredients/:action/:id'=>sub{
  my $self=shift;
  my $action=$self->param('action');
  my $id=$self->param('id');
  if($action eq 'delete'){
    $dbh->do("DELETE FROM INGREDIENTS WHERE ID=$id");
  }
  my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID",'ID');
  $self->stash(ingredients=>$ingredients);
  $self->render(text=>'Ingredient deleted successfully');
};
post '/ingredients/'=>sub{
  my $self=shift;
  my $ingredient=$self->param('ingredient');
  my $measure=$self->param('measure');
  if($ingredient && $measure){
    $dbh->do("INSERT INTO INGREDIENTS(ID,NAME,MEASUREID) VALUES(NULL,\"$ingredient\",$measure)");
  }
  my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID",'ID');
  $self->stash(ingredients=>$ingredients);
  $self->render('ingrediens');
};

app->secret('storestosecret');
app->start;
__DATA__

@@ kitchen.html.ep
% layout 'default', title 'My kitchen';
<%= link_to 'Create recipe'=>'recipe' %> / <%= link_to 'Open refrigirator'=>'ingredients' %>

@@ ingredients.html.ep
% layout 'default',title 'My refrigirator';
%#	Create new ingredient
<%= form_for 'ingredients'=>(method=>'post')=>begin %>
<%= text_field 'ingredient' %>
<%= select_field measure=>[['pcs'=>1],['g.'=>2],['ml.'=>3],['l.'=>4],['kg.'=>5]]%>
<%= submit_button 'Add' %>
<% end %>
%#	Generate ingredients refs
%foreach my $key(keys %{$ingredients}){
  <%= $ingredients->{$key}{'INGREDIENT'}%>, <i><%= $ingredients->{$key}{'MEASURE'}%></i>, <%= link_to 'Delete'=>"ingredients/delete/$ingredients->{$key}{'ID'}" %><br/>
%}

@@ layouts/default.html.ep
<title><%= title %></title>
<body>
<P><%= link_to 'Back to my kitchen'=>'kitchen'%></P>
<%= content %>
</body>
















