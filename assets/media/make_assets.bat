@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_assets.ps1" ^
  -InputDir "D:\Projects\Codictionary\assets\media\icons\new_dictionary" ^
  -OutDir   "D:\Projects\Codictionary\assets\media\icons\new_dictionary" ^
  -BaseW 32 -BaseH 32 -Fit cover
pause