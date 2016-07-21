$(document).ready(function () {
	if(window.location.href.indexOf("RUN") > -1) {
		setTimeout("location.reload(true);",500);
	}
});

$(function (){
	$(".Memory td").dblclick(function () {
		var OriginalContent = $(this).text();
		var row_index = $(this).parent().index('tr');
		var col_index = $(this).index('tr:eq('+ row_index + ') td');

		$(this).addClass("cellEditing");
		$(this).html("<input type='text' value='" + OriginalContent + "' />");
		$(this).children().first().focus();

		$(this).children().first().keypress(function (e) {
			if (e.which == 13) {
				var newContent = $(this).val();
				$(this).parent().text(newContent);
				$(this).parent().removeClass("cellEditing");

				window.location.href = "Memory?row=" + (row_index - 1) + ";col=" + (col_index - 1) + ";value=" + newContent;}
		});

		$(this).children().first().blur(function(){
			$(this).parent().text(OriginalContent);
			$(this).parent().removeClass("cellEditing");
		});
	});
});

$(function (){
	$(".Registers td").dblclick(function () {
		var OriginalContent = $(this).text();
		var UsefulContent = $(this).parent().find("td:nth-child(1)").text();

		$(this).addClass("cellEditing");
		$(this).html("<input type='text' value='" + OriginalContent + "' />");
		$(this).children().first().focus();

		$(this).children().first().keypress(function (e) {
			if (e.which == 13) {
				var newContent = $(this).val();
				$(this).parent().text(newContent);
				$(this).parent().removeClass("cellEditing");

				window.location.href = "Register?Reg=" + UsefulContent + ";value=" + newContent;}
		});

		$(this).children().first().blur(function(){
			$(this).parent().text(OriginalContent);
			$(this).parent().removeClass("cellEditing");
		});
	});
});

$(function (){
	$(".Debug td").dblclick(function () {
		var UsefulContent = $(this).parent().find("td:nth-child(1)").text();
		window.location.href = "DEBUG?Inst=" + UsefulContent;
	});
});

$(window).bind('keydown', function(event) {
	if (event.ctrlKey || event.metaKey) {
		switch (String.fromCharCode(event.which).toLowerCase()) {
		case 's':
			event.preventDefault();
			alert('ctrl-s');
			break;
		case 'f':
			event.preventDefault();
			alert('ctrl-f');
			break;
		case 'g':
			event.preventDefault();
			alert('ctrl-g');
			break;
		case 'd':
			event.preventDefault();
			alert('ctrol-d');
			break;
		}
	}
});
