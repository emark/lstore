function HSLayer()
{
		document.getElementById("message").style.display = "none";
}
function SelectLayer($div1,$div2)
{
		document.getElementById([$div1]).style.display = "none";
		document.getElementById([$div2]).style.display = "";
}
function HideObject($object)
{
		document.getElementById([$object]).style.display = "none";
}
function ShowObject($object)
{
		document.getElementById([$object]).style.display = "";
}
function ConfirmDelete($object)
{
        if(confirm("Удаляем. Вы уверены? "))
        {
                window.location=$object;
        }
        return false;
}
function SelectOneLayer($div)
{
        if(document.getElementById([$div]).style.display == "none")
        {
                document.getElementById([$div]).style.display = "";
        }else{
                document.getElementById([$div]).style.display = "none"
        }
}