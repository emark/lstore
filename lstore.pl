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

get '/icebox'=>sub{
  my $self=shift;
  my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,TAGS.NAME AS TAG FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER2 ON INGREDIENTS.ID=ROUTER2.INGREDIENTID LEFT JOIN TAGS ON ROUTER2.TAGID=TAGS.ID",'ID');
  $self->stash(ingredients=>$ingredients);
  $self->render('icebox');
};

get '/icebox/:action/:id'=>sub{
  my $self=shift;
  my $action=$self->param('action');
  my $id=$self->param('id');
  if($action eq 'delete'){
    $dbh->do("DELETE FROM INGREDIENTS WHERE ID=$id");
  }
  my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,TAGS.NAME AS TAG FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER2 ON INGREDIENTS.ID=ROUTER2.INGREDIENTID LEFT JOIN TAGS ON ROUTER2.TAGID=TAGS.ID",'ID');
  $self->stash(ingredients=>$ingredients);
  $self->render('icebox');
};

post '/icebox'=>sub{
  my $self=shift;
  my $ingredient=$self->param('ingredient');
  my $measure=$self->param('measure');
  my $tag=$self->param('tag');
  my $ingredientid=0;
  my $tagid=0;
  if($ingredient && $measure){
    $dbh->do("INSERT INTO INGREDIENTS(ID,NAME,MEASUREID) VALUES(NULL,\"$ingredient\",$measure)");
    $ingredientid=$dbh->last_insert_id('','','INGREDIENTS','ID');
    $tagid=$dbh->selectrow_array("SELECT ID FROM TAGS WHERE TAGS.NAME=\"$tag\"");
    if(!$tagid){
      $dbh->do("INSERT INTO TAGS(ID,NAME) VALUES(NULL,\"$tag\")");
      $tagid=$dbh->last_insert_id('','','TAGS','ID');
    }
    $dbh->do("INSERT INTO ROUTER2(ID,INGREDIENTID,TAGID) VALUES(NULL,$ingredientid,$tagid)");
  }
  my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,TAGS.NAME AS TAG FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER2 ON INGREDIENTS.ID=ROUTER2.INGREDIENTID LEFT JOIN TAGS ON ROUTER2.TAGID=TAGS.ID",'ID');
  $self->stash(ingredients=>$ingredients);
  $self->render('icebox');
};

get '/recipe'=>sub{
  my $self=shift;
  my $tags=$dbh->selectall_hashref('SELECT TAGS.ID,TAGS.NAME FROM TAGS RIGHT JOIN ROUTER2 ON TAGS.ID=ROUTER2.TAGID','ID');
  $self->stash(tags=>$tags,
	       ingredients=>{},
	       recipe=>'',
	       recipeid=>undef);
  $self->render('recipe');
};

post '/recipe'=>sub{
  my $self=shift;
  my $recipe=$self->param('recipe');
  my $recipeid=$self->param('recipeid') || 0;
  my $tags={};
  my $ingredients={};
  my $SQL='';
  my @quantity=$self->param('quantity');
  my $quantity_hook=0;
  foreach(@quantity){#Hook for defined quantity
    if($_ && $_>0){
      $quantity_hook=1;
    }
  }
  my @ingredientid=$self->param('ingredientid');
  	  #$self->stash(sql=>$SQL,n=>$n);Test
  my @tagid=$self->param('tagid');
  foreach(@tagid){
    $SQL=$SQL." ROUTER2.TAGID=$_ OR "
  }
	  $self->stash(sql=>$SQL,q=>$quantity_hook);#Test
  if(@tagid){#Select ingredients for recipe
    $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER2 ON INGREDIENTS.ID=ROUTER2.INGREDIENTID WHERE $SQL ROUTER2.TAGID=0",'ID');
  }elsif($quantity_hook && $recipe){#Create recipe,router1 if quantity>0
    $dbh->do("INSERT INTO RECIPES(ID,NAME) VALUES(NULL,\"$recipe\")");
    $recipeid=$dbh->last_insert_id('','','RECIPES','ID');
    for(my $n=0;$n<@ingredientid;$n++){#Create SQL INSERT query for ROUTER1
      if($quantity[$n] && $quantity[$n]!=0){
        $SQL=$SQL."(NULL,$recipeid,$ingredientid[$n],$quantity[$n]),"
      }
    }chop $SQL;#Drop last character ','
	  $self->stash(sql=>$SQL);#Test
    $dbh->do("INSERT INTO ROUTER1(ID,RECIPEID,INGREDIENTID,QUANTITY) VALUES $SQL");
    $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,ROUTER1.QUANTITY AS QUANTITY FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER1 ON INGREDIENTS.ID=ROUTER1.INGREDIENTID WHERE ROUTER1.RECIPEID=$recipeid",'ID');
  }else{#If new recipe,select ingredients tags
    $tags=$dbh->selectall_hashref('SELECT TAGS.ID,TAGS.NAME FROM TAGS RIGHT JOIN ROUTER2 ON TAGS.ID=ROUTER2.TAGID','ID');
  }
  $self->stash(recipe=>$recipe,
	       recipeid=>$recipeid,
	       ingredients=>$ingredients,
	       tags=>$tags);
  $self->render('recipe');
};

app->secret('storestosecret');
app->start;
__DATA__

@@ recipe.html.ep
%layout 'default', title 'My recipe\'s book';
%#	Select ingredients from tags
%#<%= test %>
%if(!%{$ingredients}){
<P>What prepare for?</P>
  <%= form_for 'recipe'=>(method=>'post')=>begin %>
%#	Show ingredients tags
%	foreach (keys %{$tags}){
  <%= check_box 'tagid'=>($tags->{$_}{'ID'})%><%= $tags->{$_}{'NAME'}%><br/>
%	}
  <%= submit_button 'Let\'s start' %>
  <% end %>
%}else{
%#	Show ingredients for recipe
  <%= form_for 'recipe'=>(method=>'post')=>begin %>
  <%= text_field 'recipe' %>
  <%= hidden_field 'recipeid'=>$recipeid %>
<table>
%	foreach (keys %{$ingredients}){
<tr><td><%= hidden_field 'ingredientid'=>($ingredients->{$_}{'ID'}) %><%= $ingredients->{$_}{'INGREDIENT'} %></td><td><input type=textfield size=5 name=quantity value=<%= $ingredients->{$_}{'QUANTITY'} %> ></td><td><%= $ingredients->{$_}{'MEASURE'} %></td></tr>
%	}
</table>
  <%= submit_button 'Save recipe' %>
  <% end %>
%}

@@ kitchen.html.ep
% layout 'default', title 'My kitchen';
<%= link_to 'Create recipe'=>'recipe' %> / <%= link_to 'Open my icebox'=>'icebox' %>

@@ icebox.html.ep
% layout 'default',title 'My refrigirator';
%#	Create new ingredient
<%= form_for 'icebox'=>(method=>'post')=>begin %>
<i>What add?</i><br/>
<%= text_field 'ingredient' %>
<%= select_field measure=>[['pcs'=>1],['g.'=>2],['ml.'=>3],['l.'=>4],['kg.'=>5]]%><br/><i>input tags</i><br/>
<%= text_field 'tag' %>
<%= submit_button 'Add' %>
<% end %>
%#	Generate ingredients refs
%foreach my $key(keys %{$ingredients}){
  <%= $ingredients->{$key}{'INGREDIENT'}%>, <i><%= $ingredients->{$key}{'MEASURE'}%></i>, [<%= $ingredients->{$key}{'TAG'} %>],<a href="<%= url_for "/icebox/delete/$ingredients->{$key}{'ID'}" %>">Delete</a><br/>
%}

@@ layouts/default.html.ep
<title><%= title %></title>
<body>
<P><%= link_to 'Back to my kitchen'=>'kitchen'%></P>
<%= content %>
</body>