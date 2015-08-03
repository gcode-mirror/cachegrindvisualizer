  1. Установить [AIR](http://labs.adobe.com/downloads/air.html).
  1. Установить CachegrindVisualizer.
  1. Установить [Graphviz](http://graphviz.org/).
  1. Установить [ZGRViewer](http://zvtm.sourceforge.net/zgrviewer.html).
  1. Настроить ZGRViewer
    1. Открыли ZGRViewer (в windows это run.bat, в linux run.sh — файл на языке dot кроссплатформен).
    1. File -> Preferences -> Directories пишем пути к программам, обычно это C:\Program Files\Graphviz\bin\dot.exe (вместо dot для остальных соответственно neato, circo и т. д.), нажимаем Save и закрываем окно.
    1. Правой клавишей мыши щелкаем по файлу: появляется контекстное меню — Открыть с помощью -> Выбрать программу -> выбираем ZGRViewer и ставим галку "Использовать выбранную программу для всех файлов такого типа" -> ОК. Если открылось нормально, переходим к следующем шагу, если нет — разбираемся с путями. Тем кто в windows — откройте run.bat и установите переменную ZGRV в абсолютный путь к папке ZGRViewer. Все пути в настройках ZGRViewer должны быть абсолютными, вместе с буквой диска.
  1. Настроить xdebug. Установите xdebug.profiler\_output\_name = %t.cg, спецификатор %t можете заменить на [любой другой](http://xdebug.org/docs/all_settings#trace_output_name). Это рекомендуется сделать для возможности открытия файла путем щелчка по нему (расширение cg регистрирует на себя CachegrindVisualizer).