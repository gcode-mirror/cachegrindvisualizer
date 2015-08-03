  1. Install [AIR](http://labs.adobe.com/downloads/air.html).
  1. Install CachegrindVisualizer.
  1. Install [Graphviz](http://graphviz.org/).
  1. Install [ZGRViewer](http://zvtm.sourceforge.net/zgrviewer.html).
  1. Configurate ZGRViewer
    1. Open ZGRViewer (windows: run.bat, linux: run.sh).
    1. File -> Preferences -> Directories write paths to programs, usually C:\Program Files\Graphviz\bin\dot.exe (instead of dot for the others accordingly neato, circo, etc.), press "Save" and close window.
    1. By the right key of the mouse it is clicked on a file: context menu — Open with -> Select program -> select ZGRViewer -> ОК. If has opened normally, pass to a following step, if not — fix paths. Who uses windows — edit run.bat and set variable ZGRV = ZGRViewer directory absolute path.
  1. Configurate  xdebug. Set xdebug.profiler\_output\_name = %t.cg, specifier %t can replace with [any another](http://xdebug.org/docs/all_settings#trace_output_name). It is possible to suggest that opening the file by clicking on it (extension "cg" registers CachegrindVisualizer).