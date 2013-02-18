@echo off
del graph*.png
for %%D in (*.dot) do "c:\Program Files\Graphviz2.30\bin\osage.exe" -Tpng -o%%D.png %%D > NUL
