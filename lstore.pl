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

app->hook(before_dispatch => sub {
               my $self = shift;
               $self->req->url->base(Mojo::URL->new(q{http://www.storesto.ru/}))
	       }
	  );

get '/' => sub{
    my $self=shift;
    $self->render(text=>'Hello storesto! Coming soon!');
};

get '/kitchen'=>sub{
  my $self=shift;
  my $recipes=$dbh->selectall_hashref('SELECT RECIPES.ID AS ID,RECIPES.NAME AS RECIPE FROM RECIPES','ID');
  $self->stash(recipes=>$recipes,
	       menu=>'',
	       menuid=>0);
  $self->render('kitchen');
};

get '/kitchen/:action/:id'=>sub{
  my $self=shift;
  my $action=$self->param('action');
  my $recipeid=$self->param('id');
  if($action eq 'delete'){
    $dbh->do("DELETE FROM RECIPES WHERE RECIPES.ID=$recipeid");
  }
  my $recipes=$dbh->selectall_hashref('SELECT RECIPES.ID AS ID,RECIPES.NAME AS RECIPE FROM RECIPES','ID');
  $self->stash(recipes=>$recipes,
	       menu=>'',
	       menuid=>0);
  $self->render('kitchen');
};

post '/kitchen'=>sub{
  my $self=shift;
  my @recipeid=$self->param('recipeid');
  my $SQL;
  foreach(@recipeid){
    $SQL=$SQL."RECIPES.ID=$_ OR ";
  }
  my $recipes=$dbh->selectall_hashref("SELECT RECIPES.ID AS ID,RECIPES.NAME AS RECIPE FROM RECIPES WHERE $SQL RECIPES.ID=0",'ID');
  $self->stash(recipes=>$recipes,
	       menu=>'',
	       menuid=>0);
  $self->render('menu');
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

get '/recipe/:action/:id'=>sub{
  my $self=shift;
  my $recipeid=$self->param('id');
  my $recipe=$dbh->selectrow_array("SELECT RECIPES.NAME FROM RECIPES WHERE RECIPES.ID=$recipeid");
  my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,ROUTER1.QUANTITY AS QUANTITY FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER1 ON INGREDIENTS.ID=ROUTER1.INGREDIENTID WHERE ROUTER1.RECIPEID=$recipeid",'ID');
  $self->stash(tags=>{},
	       ingredients=>$ingredients,
	       recipe=>$recipe,
	       recipeid=>$recipeid);
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
	  #$self->stash(sql=>$SQL,q=>$quantity_hook);#Test
  if(@tagid){#Select ingredients for recipe
    $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER2 ON INGREDIENTS.ID=ROUTER2.INGREDIENTID WHERE $SQL ROUTER2.TAGID=0",'ID');
  }elsif($quantity_hook && $recipe && !$recipeid){#Create recipe,router1 if quantity>0
    $dbh->do("INSERT INTO RECIPES(ID,NAME) VALUES(NULL,\"$recipe\")");
    $recipeid=$dbh->last_insert_id('','','RECIPES','ID');
    for(my $n=0;$n<@ingredientid;$n++){#Create SQL INSERT query for ROUTER1
      if($quantity[$n] && $quantity[$n]!=0){
        $SQL=$SQL."(NULL,$recipeid,$ingredientid[$n],$quantity[$n]),"
      }
    }chop $SQL;#Drop last character ','
	  #$self->stash(sql=>$SQL);#Test
    $dbh->do("INSERT INTO ROUTER1(ID,RECIPEID,INGREDIENTID,QUANTITY) VALUES $SQL");
    $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,ROUTER1.QUANTITY AS QUANTITY FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID LEFT JOIN ROUTER1 ON INGREDIENTS.ID=ROUTER1.INGREDIENTID WHERE ROUTER1.RECIPEID=$recipeid",'ID');
  }elsif($quantity_hook && $recipeid && $recipe){#Update recipe, router1
    $dbh->do("UPDATE RECIPES SET NAME=\"$recipe\" WHERE ID=$recipeid");
    for(my $n=0;$n<@ingredientid;$n++){#Create SQL INSERT query for ROUTER1
      if($quantity[$n] && $quantity[$n]!=0){
	$dbh->do("UPDATE ROUTER1 SET QUANTITY=$quantity[$n] WHERE RECIPEID=$recipeid AND INGREDIENTID=$ingredientid[$n]");
      }
    }
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

get '/menu/:action/:id/:routeid'=>{routeid=>0}=>sub{
  my $self=shift;
  my $action=$self->param('action');
  my $menuid=$self->param('id');
  my $routeid=$self->param('routeid');
  my $menu='';
  my $recipes={};
  if($action eq 'edit'){    
  }elsif($action eq 'cut'){#Cutting recipes from menu
    $dbh->do("DELETE FROM ROUTER3 WHERE ROUTER3.ID=$routeid");
  }
  $menu=$dbh->selectrow_array("SELECT MENU.NAME FROM MENU WHERE MENU.ID=$menuid");
  $recipes=$dbh->selectall_hashref("SELECT ROUTER3.RECIPEID AS ID,ROUTER3.ID AS ROUTEID,ROUTER3.MENUID AS MENUID,RECIPES.NAME AS RECIPE,ROUTER3.AMOUNT AS AMOUNT FROM ROUTER3 LEFT JOIN RECIPES ON RECIPES.ID=ROUTER3.RECIPEID WHERE ROUTER3.MENUID=$menuid",'ID');
  $self->stash(recipes=>$recipes,
	       menu=>$menu,
	       menuid=>$menuid);
  $self->render('menu');
};

post '/menu'=>sub{
  my $self=shift;
  my $menu=$self->param('menu');
  my $menuid=$self->param('menuid');
  my @recipeid=$self->param('recipeid');
  my @amount=$self->param('amount');
  my $recipes={};
  my $SQL='';
  my $amount_hook=0;
  foreach(@amount){#Hook for defined amount
    if($_ && $_>0){
      $amount_hook=1;
    }
  }
  if($amount_hook && $menu && !$menuid){#Create menu,router3 if quantity>0
    $dbh->do("INSERT INTO MENU(ID,NAME) VALUES(NULL,\"$menu\")");
    $menuid=$dbh->last_insert_id('','','MENU','ID');
    for(my $n=0;$n<@recipeid;$n++){#Create SQL INSERT query for ROUTER3
      if($amount[$n] && $amount[$n]!=0){
        $SQL=$SQL."(NULL,$menuid,$recipeid[$n],$amount[$n]),"
    }
  }chop $SQL;#Drop last character ','
	  #$self->stash(sql=>$SQL);#Test
    $dbh->do("INSERT INTO ROUTER3(ID,MENUID,RECIPEID,AMOUNT) VALUES $SQL");
    $recipes=$dbh->selectall_hashref("SELECT ROUTER3.RECIPEID AS ID,ROUTER3.ID AS ROUTEID,ROUTER3.MENUID AS MENUID,RECIPES.NAME AS RECIPE,ROUTER3.AMOUNT AS AMOUNT FROM ROUTER3 LEFT JOIN RECIPES ON RECIPES.ID=ROUTER3.RECIPEID WHERE ROUTER3.MENUID=$menuid",'ID');
  }elsif($amount_hook && $menuid && $menu){#Update menu, router3
    $dbh->do("UPDATE MENU SET NAME=\"$menu\" WHERE ID=$menuid");
    for(my $n=0;$n<@recipeid;$n++){#Create SQL UPDATE query for ROUTER3
      if($amount[$n] && $amount[$n]!=0){
	$dbh->do("UPDATE ROUTER3 SET AMOUNT=$amount[$n] WHERE RECIPEID=$recipeid[$n] AND MENUID=$menuid");
      }
    }
    $recipes=$dbh->selectall_hashref("SELECT ROUTER3.RECIPEID AS ID,ROUTER3.ID AS ROUTEID,ROUTER3.MENUID AS MENUID,RECIPES.NAME AS RECIPE,ROUTER3.AMOUNT AS AMOUNT FROM ROUTER3 LEFT JOIN RECIPES ON RECIPES.ID=ROUTER3.RECIPEID WHERE ROUTER3.MENUID=$menuid",'ID');
  }else{#If new menu,select recipes
    foreach(@recipeid){
    $SQL=$SQL."RECIPES.ID=$_ OR ";
    }
    $recipes=$dbh->selectall_hashref("SELECT RECIPES.ID AS ID,RECIPES.NAME AS RECIPE FROM RECIPES WHERE $SQL RECIPES.ID=0",'ID');
  }
  $self->stash(recipes=>$recipes,
	       menu=>$menu,
	       menuid=>$menuid);
  $self->render('menu');
};

get '/restopub'=>sub{
  my $self=shift;
  my $menus=$dbh->selectall_hashref('SELECT MENU.ID,MENU.NAME AS MENU FROM MENU','ID');
  $self->stash(menus=>$menus,
	       ingredients=>{});
  $self->render('restopub');
};

get '/restopub/:action/:id'=>sub{
  my $self=shift;
  my $action=$self->param('action');
  my $menuid=$self->param('id');
  my $ingredients={};
  if($action eq 'delete'){
    $dbh->do("DELETE FROM MENU WHERE ID=$menuid");
  }elsif($action eq 'buy'){
    $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID, INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,SUM(ROUTER3.AMOUNT*ROUTER1.QUANTITY) AS SUM FROM ROUTER3 LEFT JOIN RECIPES ON ROUTER3.RECIPEID=RECIPES.ID LEFT JOIN ROUTER1 ON RECIPES.ID=ROUTER1.RECIPEID LEFT JOIN INGREDIENTS ON ROUTER1.INGREDIENTID=INGREDIENTS.ID LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID WHERE ROUTER3.MENUID=$menuid GROUP BY INGREDIENTS.ID",'ID');
  }
  my $menus=$dbh->selectall_hashref('SELECT MENU.ID,MENU.NAME AS MENU FROM MENU','ID');
  $self->stash(menus=>$menus,
	       ingredients=>$ingredients);
  $self->render('restopub');
};

app->secret('storestosecret');
app->start;
__DATA__

@@ restopub.html.ep
% layout 'default',title 'Restopub';
<%#= test %>
% if(!%{$ingredients}){
%#	Show menus for my pub
%	foreach (keys %{$menus}){
  <a href="/menu/edit/<%= $menus->{$_}{'ID'} %>"><%= $menus->{$_}{'MENU'} %></a> <a href="/restopub/delete/<%= $menus->{$_}{'ID'} %>"> Delete</a> <a href="/restopub/buy/<%= $menus->{$_}{'ID'} %>">Buy</a><br/>
%	}
% }else{
%	foreach (keys %{$ingredients}){
  <i><%= $ingredients->{$_}{'INGREDIENT'} %></i> <%= $ingredients->{$_}{'SUM'} %> <%= $ingredients->{$_}{'MEASURE'} %><br/>
%	}  
% }

@@ menu.html.ep
% layout 'default',title 'Menu';
<%= link_to 'Create recipe'=>'recipe' %> / <%= link_to 'Open icebox'=>'icebox' %> / <%= link_to 'Go to restopub'=>'restopub'%>
<%= form_for 'menu'=>(method=>'post')=>begin %>
<input type=text name='menu' value="<%= $menu %>">
<input type=hidden name='menuid' value=<%= $menuid %>>
<table>
%foreach my $key(keys %{$recipes}){
  <tr><td><%= hidden_field 'recipeid'=>$recipes->{$key}{'ID'} %><%= $recipes->{$key}{'RECIPE'}%></td><td><input type=textfield size=5 name=amount value=<%=$recipes->{$key}{'AMOUNT'} %>>
%	if($menuid && $recipes){
	  </td><td><a href="/menu/cut/<%=$recipes->{$key}{'MENUID'}%>/<%=$recipes->{$key}{'ROUTEID'}%>">Cut</a>
%	}
  </td></tr>
%}
</table>
<%= submit_button 'Save menu' %>
<% end %>

@@ recipe.html.ep
%layout 'default', title 'Recipes';
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
<input type=text name=recipe value="<%= $recipe %>">
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
% layout 'default', title 'Kitchen';
<%= link_to 'Create recipe'=>'recipe' %> / <%= link_to 'Open icebox'=>'icebox' %> / <%= link_to 'Go to restopub'=>'restopub'%>
<%= form_for 'kitchen'=>(method=>'post')=>begin %>
<table>
%foreach my $key(keys %{$recipes}){
  <tr><td><a href="/recipe/edit/<%= $recipes->{$key}{'ID'} %>"><%= $recipes->{$key}{'RECIPE'}%></a></td><td><%= check_box 'recipeid'=>$recipes->{$key}{'ID'} %></td><td><a href="/kitchen/delete/<%= $recipes->{$key}{'ID'}%>">Delete</a></td></tr>
%}
</table>
<%= submit_button 'Create menu' %>
<% end %>

@@ icebox.html.ep
% layout 'default',title 'Icebox';
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
<P><%= link_to 'My kitchen'=>'kitchen'%></P>
<%= content %>
</body>