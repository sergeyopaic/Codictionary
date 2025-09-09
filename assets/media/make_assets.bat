@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_assets.ps1" ^
  -InputDir "D:\Projects\Codictionary\assets\media" ^
  -OutDir   "D:\Projects\Codictionary\assets\media" ^
  -BaseW 120 -BaseH 120 -Fit cover
pause