@ECHO OFF

SET LOCALE=ru
compc -locale=%LOCALE% -source-path %LOCALE% -include-resource-bundles CachegrindVisualizer CallGraph -output rb_%LOCALE%.swc
SET LOCALE=en_US
compc -locale=%LOCALE% -source-path %LOCALE% -include-resource-bundles CachegrindVisualizer CallGraph -output rb_%LOCALE%.swc