@echo off
cd /d "D:\school management"
echo Removing stale git lock files...
del /f ".git\HEAD.lock" 2>nul
del /f ".git\index.lock" 2>nul
del /f ".git\objects\maintenance.lock" 2>nul
echo Committing and pushing codemagic.yaml to GitHub...
git add codemagic.yaml
git commit -m "Add SKIP_INSTALL=NO and broader xcarchive app search"
git push
echo.
echo Done! Check above for any errors.
pause
