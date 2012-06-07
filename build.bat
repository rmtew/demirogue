cd src
7z a -tzip ..\demirogue.zip *.* -r
cd ..
del /F demirogue.love
ren demirogue.zip demirogue.love
del /F demirogue.exe
copy /b love.exe+demirogue.love demirogue.exe

