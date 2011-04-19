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

get '/kitchen' => sub{
  my $self=shift;
  my $recipes=$dbh->selectall_hashref('SELECT RECIPE.ID,RECIPE.NAME,RECIPE.WEIGHT,SUM(ROUTER2.YIELD) AS YIELD FROM RECIPE LEFT JOIN ROUTER2 ON RECIPE.ID=ROUTER2.RECIPEID GROUP BY RECIPE.ID','ID');
  $self->stash(teamail=>'team@storesto.ru',
	       recipes=>$recipes,
	       );  
  $self->render(template=>'kitchen');
};

post '/kitchen' => sub{
  my $self=shift;
  my $recipeid=$self->param('recipeid') || undef;
  my $action=$self->param('action') || undef;
  my $return=$self->param('return') || 'kitchen';
  my %SQL=('add'=>"INSERT INTO ROUTER2(ENTITIESID,RECIPEID,YIELD) VALUES(1,$recipeid,1)",
	   'del'=>"DELETE FROM ROUTER2 WHERE RECIPEID=$recipeid"
	   );
  if($recipeid)
  {
    my $sth=$dbh->prepare($SQL{$action});
    $sth->execute;
  }
  my $recipes=$dbh->selectall_hashref('SELECT RECIPE.ID,RECIPE.NAME,RECIPE.WEIGHT,SUM(ROUTER2.YIELD) AS YIELD FROM RECIPE LEFT JOIN ROUTER2 ON RECIPE.ID=ROUTER2.RECIPEID GROUP BY RECIPE.ID','ID');
  $self->stash(teamail=>'team@storesto.ru',
	       recipes=>$recipes,
	       );  
  $self->render(template=>'kitchen');
};

get '/' => sub {
  my $self = shift;
  $self->stash(teamail=>'team@storesto.ru');
  $self->render('default');
};

get '/recipe/:action/:id' => sub{
  my $self=shift;
  my $id=$self->stash('id');
  my $action=$self->stash('action');
  if($action eq 'view')
  {
    my $recipename=$dbh->selectrow_array("SELECT NAME FROM RECIPE WHERE ID=$id");
    my $ingredients=$dbh->selectall_hashref("SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,RECIPE.NAME AS RECIPE, ROUTER1.VALUE FROM RECIPE INNER JOIN ROUTER1 ON RECIPE.ID=ROUTER1.RECIPEID LEFT JOIN INGREDIENTS ON  INGREDIENTS.ID=ROUTER1.INGRIDIENTID LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID WHERE ROUTER1.RECIPEID=$id",'ID');
    my $instructions=$dbh->selectall_hashref("SELECT ROUTER3.ID,INGREDIENTS.NAME AS INGREDIENT,INSTRUCTIONS.STEP,INSTRUCTIONS.WAIT,INSTRUCTIONS.IDESCRIBE,ROUTER3.VALUE,MEASURE.NAME AS MEASURE FROM INSTRUCTIONS RIGHT JOIN ROUTER3 ON INSTRUCTIONS.ID=ROUTER3.INSTRUCTIONID LEFT JOIN INGREDIENTS ON ROUTER3.INGREDIENTID=INGREDIENTS.ID LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID WHERE INSTRUCTIONS.RECIPEID=$id ORDER BY INSTRUCTIONS.STEP",'ID');
    my $ascsort=$dbh->selectall_arrayref("SELECT ROUTER3.ID FROM INSTRUCTIONS RIGHT JOIN ROUTER3 ON INSTRUCTIONS.ID=ROUTER3.INSTRUCTIONID LEFT JOIN INGREDIENTS ON ROUTER3.INGREDIENTID=INGREDIENTS.ID WHERE INSTRUCTIONS.RECIPEID=$id ORDER BY INSTRUCTIONS.STEP");
    $self->stash(ingredients=>$ingredients,
	       recipename=>$recipename,
	       instructions=>$instructions,
	       ascsort=>$ascsort,
	       );
    $self->render('recipelist');
  }elsif($action eq 'add'){
    my $recipeid=0;
    my $instructionid=0;
    my @static=$self->param('static');#Параметры нового рецепта
    my @ingredients=$self->param('ingredients');
    my @value=$self->param('value');
    if($id eq 'recipe'){#Внесение рецепта в БД
      $dbh->do("INSERT INTO RECIPE(NAME,RDESCRIBE,WEIGHT) VALUES(\"$static[0]\",\"$static[1]\",$static[2])");#Создаем рецепт
      $recipeid=$dbh->last_insert_id(undef,undef,'RECIPE','ID');
      for (my $n=0;$n<@ingredients;$n++){#Добавляем ингредиенты к рецепту
	if($value[$n]){
	  $dbh->do("INSERT INTO ROUTER1(INGRIDIENTID,VALUE,RECIPEID) VALUES($ingredients[$n],$value[$n],$recipeid)");
	}
      }
    }elsif($id eq 'instruction'){
      if(@static){#Создаем инструкцию к рецепту
	if(!$static[1]){$static[1]=1};
	$dbh->do("INSERT INTO INSTRUCTIONS(ACTIONID,RECIPEID,STEP,IDESCRIBE,WAIT) VALUES(1,$static[0],$static[1],\"$static[2]\",$static[3])");
	my $instructionid=$dbh->last_insert_id(undef,undef,'INSTRUCTIONS','ID');
	$recipeid=$static[0];
	for (my $n=0;$n<@ingredients;$n++){#Добавляем ингредиенты к инструкции
	  if($value[$n] && $ingredients[$n]){
	    $dbh->do("INSERT INTO ROUTER3(INGREDIENTID,VALUE,INSTRUCTIONID) VALUES($ingredients[$n],$value[$n],$instructionid)");
	  }
	}
      }
    }
    my $ingredients=$dbh->selectall_hashref('SELECT INGREDIENTS.ID,INGREDIENTS.NAME,MEASURE.NAME AS MEASURE FROM INGREDIENTS LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID ORDER BY INGREDIENTS.NAME','ID');
    my $instructions=$dbh->selectall_hashref("SELECT ROUTER3.ID,INGREDIENTS.NAME AS INGREDIENT,INSTRUCTIONS.STEP,INSTRUCTIONS.WAIT,INSTRUCTIONS.IDESCRIBE,ROUTER3.VALUE,MEASURE.NAME AS MEASURE FROM INSTRUCTIONS RIGHT JOIN ROUTER3 ON INSTRUCTIONS.ID=ROUTER3.INSTRUCTIONID LEFT JOIN INGREDIENTS ON ROUTER3.INGREDIENTID=INGREDIENTS.ID LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID WHERE INSTRUCTIONS.RECIPEID=$recipeid ORDER BY INSTRUCTIONS.STEP",'ID');
    my $ascsort=$dbh->selectall_arrayref("SELECT ROUTER3.ID FROM INSTRUCTIONS RIGHT JOIN ROUTER3 ON INSTRUCTIONS.ID=ROUTER3.INSTRUCTIONID LEFT JOIN INGREDIENTS ON ROUTER3.INGREDIENTID=INGREDIENTS.ID WHERE INSTRUCTIONS.RECIPEID=$recipeid ORDER BY INSTRUCTIONS.STEP");
    $self->stash(ingredients=>$ingredients,
		 instructions=>$instructions,
		 ascsort=>$ascsort,
		 recipeid=>$recipeid);
    $self->render('addnewrecipe');  
  }
};

get '/menu' => sub{
  my $self=shift;
  my $recipes=$dbh->selectall_hashref('SELECT RECIPE.ID,RECIPE.NAME,ROUTER2.YIELD FROM RECIPE RIGHT JOIN ROUTER2 ON RECIPE.ID=ROUTER2.RECIPEID GROUP BY RECIPE.ID','ID');
  $self->stash(recipes=>$recipes);
  $self->render(template=>'menu');
};

post '/menu' => sub{
  my $self=shift;
  my @id=$self->param('recipeid');
  my @yield=$self->param('yield');
  my $sql;
  if(@id)
  {
    for(my $n=0;$n<@id;$n++)
    {
      if(!$yield[$n] || $yield[$n]==0)
      {
	$sql="DELETE FROM ROUTER2 WHERE RECIPEID=$id[$n]";
      }else{
	$sql="UPDATE ROUTER2 SET YIELD=$yield[$n] WHERE RECIPEID=$id[$n]";	
      }
      my $sth=$dbh->prepare($sql);
      $self->stash(sql=>$sql,n=>$n);
      $sth->execute;
    }
  }
  my $recipes=$dbh->selectall_hashref('SELECT RECIPE.ID,RECIPE.NAME,ROUTER2.YIELD FROM RECIPE RIGHT JOIN ROUTER2 ON RECIPE.ID=ROUTER2.RECIPEID','ID');
  $self->stash(recipes=>$recipes);
  $self->render(template=>'menu');
};

get '/menu/:action' => sub{
  my $self=shift;
  my $action=$self->stash('action');
  if($action eq 'products'){
    my $ingredients=$dbh->selectall_hashref('SELECT INGREDIENTS.ID,INGREDIENTS.NAME,SUM(ROUTER1.VALUE*ROUTER2.YIELD) AS SUM,MEASURE.NAME AS MEASURE FROM ROUTER2 LEFT JOIN ROUTER1 ON ROUTER2.RECIPEID=ROUTER1.RECIPEID INNER JOIN INGREDIENTS ON ROUTER1.INGRIDIENTID=INGREDIENTS.ID LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID GROUP BY INGREDIENTS.NAME','ID');
    $self->stash(ingredients=>$ingredients);
    $self->render(template=>'viewmenu');
  }elsif($action eq 'prepare'){
    my $instructions=$dbh->selectall_hashref("SELECT ROUTER3.ID,RECIPE.ID AS RECIPEID,RECIPE.NAME AS RECIPE,INSTRUCTIONS.STEP,ROUTER2.YIELD,INSTRUCTIONS.IDESCRIBE,INGREDIENTS.NAME AS INGREDIENT,SUM(ROUTER3.VALUE*ROUTER2.YIELD) AS VALUE,INSTRUCTIONS.WAIT,MEASURE.NAME AS MEASURE FROM ROUTER2 LEFT JOIN RECIPE ON ROUTER2.RECIPEID=RECIPE.ID INNER JOIN INSTRUCTIONS ON RECIPE.ID=INSTRUCTIONS.RECIPEID LEFT JOIN ROUTER3 ON INSTRUCTIONS.ID=ROUTER3.INSTRUCTIONID LEFT JOIN INGREDIENTS ON ROUTER3.INGREDIENTID=INGREDIENTS.ID LEFt JOIN MEASURE On INGREDIENTS.MEASUREID=MEASURE.ID GROUP BY RECIPE.ID, ROUTER3.INSTRUCTIONID,ROUTER3.INGREDIENTID",'ID');
    my $ascsort=$dbh->selectall_arrayref('SELECT ROUTER3.ID FROM ROUTER2 LEFT JOIN RECIPE ON ROUTER2.RECIPEID=RECIPE.ID INNER JOIN INSTRUCTIONS ON RECIPE.ID=INSTRUCTIONS.RECIPEID LEFT JOIN ROUTER3 ON INSTRUCTIONS.ID=ROUTER3.INSTRUCTIONID LEFT JOIN INGREDIENTS ON ROUTER3.INGREDIENTID=INGREDIENTS.ID GROUP BY RECIPE.ID, ROUTER3.INSTRUCTIONID,ROUTER3.INGREDIENTID');
    $self->stash(instructions=>$instructions,
		 ascsort=>$ascsort,
		 );
    $self->render(template=>'preparemenu');
  }elsif($action eq 'helptable'){
    my $ingredients=$dbh->selectall_hashref('SELECT INGREDIENTS.ID,INGREDIENTS.NAME AS INGREDIENT,MEASURE.NAME AS MEASURE,SUM(ROUTER1.VALUE*ROUTER2.YIELD) AS TOTAL FROM ROUTER2 LEFT JOIN ROUTER1 ON ROUTER2.RECIPEID=ROUTER1.RECIPEID INNER JOIN INGREDIENTS ON ROUTER1.INGRIDIENTID=INGREDIENTS.ID LEFT JOIN MEASURE ON INGREDIENTS.MEASUREID=MEASURE.ID GROUP BY INGREDIENTS.NAME','ID');
    my $recipes=$dbh->selectall_hashref('SELECT ROUTER1.ID AS ROUTERID,RECIPE.ID AS RECIPEID,RECIPE.NAME AS RECIPE,ROUTER2.YIELD,INGREDIENTS.ID AS INGREDIENTID,SUM(ROUTER1.VALUE*ROUTER2.YIELD) AS VALUE FROM ROUTER2 LEFT JOIN RECIPE ON ROUTER2.RECIPEID=RECIPE.ID LEFT JOIN ROUTER1 ON RECIPE.ID=ROUTER1.RECIPEID LEFT JOIN INGREDIENTS ON ROUTER1.INGRIDIENTID=INGREDIENTS.ID GROUP BY RECIPE.ID, ROUTER1.INGRIDIENTID','ROUTERID');
    my $ascsort=$dbh->selectall_arrayref('SELECT ROUTER1.ID FROM ROUTER2 LEFT JOIN RECIPE ON ROUTER2.RECIPEID=RECIPE.ID LEFT JOIN ROUTER1 ON RECIPE.ID=ROUTER1.RECIPEID ORDER BY RECIPE.ID');
    $self->stash(ingredients=>$ingredients,
		 recipes=>$recipes,
		 ascsort=>$ascsort,
		 );
    $self->render('helptable');
  }
};

app->secret('storestosecret');
app->start;



















