# CachegrindVisualizer #
CachegrindVisualizer is a visualizer for xdebug profiling data (cachegrind compatible file), i. e. frontend for Cachegrind (part of Valgrind).
Supports OS: Windows 2000 SP4, Windows XP SP2, Windows Vista Home and Ultimate Edition, Mac OS 10.4.7 and above (Intel and PowerPC), Mac OS X Leopard.

## Example ##
[![](http://cachegrindvisualizer.googlecode.com/files/p_symfony_graph-gfc1-ru-0.5.2.png)](http://code.google.com/p/cachegrindvisualizer/wiki/ruExamples)

All examples [in Russian](ruExamples.md) or [in English](enExamples.md).

## Screenshot ##
![![](http://cachegrindvisualizer.googlecode.com/files/p_CachegrindVisualizer-0.5.2-screenshot.png)](http://cachegrindvisualizer.googlecode.com/files/CachegrindVisualizer-0.5.2-screenshot.png)

## Описание ##
CachegrindVisualizer — это кроссплатформенная программа для визуализации файлов в формате Callgrind, в частности, его подмножества используемого Cachegrind. Профайлер [Xdebug](http://www.xdebug.org/docs/profiler) является совместимым с Cachegrind.

CachegrindVisualizer строит граф в формате DOT, который с помощью [Graphviz](http://graphviz.org/) можно преобразовать в 18 других форматов (VRML не поддерживается), в том числе, в SVG — самое вкусное. Сам CachegrindVisualizer не визуализирует формат DOT, для просмотра графа как изображения вам необходимо самостоятельно преобразовать его в нужный вам формат. Для удобства работы рекомендую использовать просмотровщик — ничего лучше чем [ZGRViewer](http://zvtm.sourceforge.net/zgrviewer.html) под Windows я не нашел.

Построение графа происходит автоматически после анализа, изменения настроек или выделения ветки дерева, сам граф располагается там же, где и исходный файл профилирования, с тем же именем, но с раширением dot. Граф можно строить как для всей системы в целом, так и для любой из ее подсистем — выделением соответствующей ветки дерева.
Настроить, какой каталог содержит файлы профилирования для использования его по умолчанию в диалоге "Открыть", нельзя — каталогом по умолчанию считается тот, откуда в последний раз брался файл. Настройки построения графа можно сохранять и загружать.
Имя вкладки это имя анализируемого файла с удалением "cachegrind.out.".

При анализе осуществляется корректировка записей о деструкторах — xdebug пишет их так, как оно есть и как оно зависит от внутренних механизмов PHP — но обычному смертному PHP-программисту этих подробностей знать не надо и CachegrindVisualizer в независимости от того, как была завершена программа — сама или ей помогли (например, exit) или был ли присвоен инстанцированный класс какой-либо переменной, размещает эти записи в ветке main, и, таким образом, у вас всегда дерево, а не лес.

Пиктограммы для токенов были взяты из шаблона phpDocumentor earthli и доработаны для прозрачности (разделять на ветка/лист не стал — рябит в глазах). В отличие от WinCacheGrind встроенные классы PHP я считаю не функцией, то есть php::blitz->blitz будет иметь пиктограмму конструктора, а php::blitz->set пиктограмму метода.
Пиктограмма для программы в розыске ;)

Кто работал во flex приложениях, учтите, что все использованные управляющие элементы доработаны для нормального использования: Tree и DataGrid знают о щелчке в пустом месте для снятия выделения; Tree, DataGrid и List поддерживают Ctrl + A; NumericStepper поддерживает колесо мыши и корректно устанавливает курсор ввода; TextInput поддерживает Ctrl + Z/Y.