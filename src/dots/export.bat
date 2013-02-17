@echo off
for %%D in (*.dot) do "c:\Program Files\Graphviz2.30\bin\neato.exe" -Tpng -o%%D.png %%D > NUL