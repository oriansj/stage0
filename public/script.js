/* This file is part of stage0.
 *
 * stage0 is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * stage0 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with stage0.  If not, see <http://www.gnu.org/licenses/>.
 */

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

