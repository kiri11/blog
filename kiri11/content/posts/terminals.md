+++
title = "Терминалы воруют ваши деньги"
date = "2011-03-16T23:11:02"
slug = "terminals"
path = "terminals"
description = "На терминалах QIWI обнаружили троян. Вмешиваясь в работу процесса maratl.exe, запущенного в операционной системе терминала Windows, он может подменять номер счета, на который пользователь осуществил платеж."

[taxonomies]
tags = ["говно", "деньги", "полезно"]

[extra]
wordpress_id = 440
author = "Kiri11"
author_login = "Kiri11"
original_url = "https://kiri11.ru/terminals/"
preview = "На терминалах QIWI обнаружили троян. Вмешиваясь в работу процесса maratl.exe, запущенного в операционной системе терминала Windows, он может подменять номер счета, на который пользователь осуществил платеж."
preview_image = "/assets/images/terminals/thief.jpg"
approved_comment_count = 2
+++

<img class="alignnone" title="thief" src="/assets/images/terminals/thief.jpg" alt="" width="440" height="300" />

На терминалах <strong>QIWI</strong> обнаружили троян. Вмешиваясь в работу процесса <strong>maratl.exe</strong>, запущенного в операционной системе терминала <strong>Windows</strong>, он может подменять номер счета, на который пользователь осуществил платеж.

Заражение терминала может происходить через USB-флешку. Как только такая флешка подключается к терминалу (например, обслуживающим персоналом), происходит автозапуск бэкдора <strong>BackDoor.Pushnik</strong>, представляющего собой вредоносную программу в виде исполняемого файла, созданного в среде <strong>Delphi (!!!)</strong>. В дальнейшем BackDoor.Pushnik получает с сервера первого уровня конфигурационную информацию, в которой присутствует адрес управляющего сервера второго уровня. С него, в свою очередь, исходит задача загрузить исполняемый файл (троянскую программу <strong>Trojan.PWS.OSMP</strong>) с третьего сервера.

Чуваки из «Доктор Веба» обещали почистить, но сами знаете...

<strong>Итак, мои рекомендации юзерам терминалов:</strong>
<ol>
	<li>никогда не выкидывайте чек до поступления бабла на счет</li>
	<li>в случае чего качайте права</li>
	<li>после поступления денег чек лучше мелко порвать или сжечь</li>
	<li>уничтожайте всех дельфистов в зоне досягаемости</li>
	<li>???</li>
	<li>PROFIT!</li>
</ol>
<ol></ol>

<section class="historical-comments" aria-labelledby="comments-title">
<h2 id="comments-title">Коменты (2)</h2>
<article class="comment depth-1" id="comment-89">
<div class="comment-meta"><span class="comment-author">ManManson</span> <time datetime="2011-03-16 23:22:22">2011-03-16 23:22:22</time></div>
<div class="comment-content">
Сраные дельфюги, гореть им всем в АДУ, я буду славить дьявола и стучать к ним!
</div>
<article class="comment depth-2" id="comment-93">
<div class="comment-meta"><span class="comment-author">Itlum</span> <time datetime="2011-03-18 18:17:21">2011-03-18 18:17:21</time></div>
<div class="comment-content">
Ну, надо признать, что это очко в их пользу.

Кстати, Кальмар, под линь тоже можно написать вирус. Ну, не на дельфи, конечно :D
</div>
</article>
</article>
</section>
